-- Doubles Ticket 2: entry allocation, waitlist, automatic lifecycle,
-- withdrawal semantics, draw publication and doubles hub read API.

create or replace function public.expire_doubles_partner_invitations_v1(
  p_competition_id uuid,
  p_now_game_second bigint default null
)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_now bigint:=coalesce(p_now_game_second,public.current_game_second_v1());
  v_tournament text;
  v_city text;
  v_route text;
  r record;
  v_count integer:=0;
begin
  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;

  v_route:=format('/game/tournaments/%s/doubles',p_competition_id);

  for r in
    select i.*,
           trim(pi.first_name||' '||pi.last_name) inviter_name,
           trim(pe.first_name||' '||pe.last_name) invitee_name
    from public.tournament_doubles_partner_invitations i
    join public.players pi on pi.id=i.inviter_player_id
    join public.players pe on pe.id=i.invitee_player_id
    where i.competition_id=p_competition_id
      and i.status='pending'
      and i.expires_game_second<=v_now
    for update of i
  loop
    update public.tournament_doubles_partner_invitations
    set status='expired',responded_at=now(),updated_at=now()
    where id=r.id;

    perform public.emit_notification_v1(
      r.inviter_user_id,r.inviter_player_id,
      'doubles.invitation.expired',
      'Doubles invitation expired · '||v_tournament,
      format('Your doubles invitation to %s expired at the partnership deadline.',r.invitee_name),
      v_route,
      jsonb_build_object(
        'competition_id',p_competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_name',r.invitee_name,'action_url',v_route
      ),
      format('doubles-invite:%s:expired:inviter',r.id)
    );

    perform public.emit_notification_v1(
      r.invitee_user_id,r.invitee_player_id,
      'doubles.invitation.expired',
      'Doubles invitation expired · '||v_tournament,
      format('The doubles invitation from %s expired at the partnership deadline.',r.inviter_name),
      v_route,
      jsonb_build_object(
        'competition_id',p_competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_name',r.inviter_name,'action_url',v_route
      ),
      format('doubles-invite:%s:expired:invitee',r.id)
    );

    v_count:=v_count+1;
  end loop;

  return v_count;
end;
$$;
revoke all on function public.expire_doubles_partner_invitations_v1(uuid,bigint) from public,anon,authenticated;
grant execute on function public.expire_doubles_partner_invitations_v1(uuid,bigint) to service_role;

create or replace function public.notify_doubles_team_entry_v1(
  p_team_id uuid,
  p_code text,
  p_status_label text
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_team public.tournament_doubles_teams%rowtype;
  v_tournament text;
  v_city text;
  v_route text;
  v_p1 record;
  v_p2 record;
  v_title text;
  v_message text;
begin
  select * into v_team
  from public.tournament_doubles_teams
  where id=p_team_id;

  if v_team.id is null then return; end if;

  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=v_team.competition_id;

  select owner_user_id,id,trim(first_name||' '||last_name) name
  into v_p1
  from public.players
  where id=v_team.player1_id;

  select owner_user_id,id,trim(first_name||' '||last_name) name
  into v_p2
  from public.players
  where id=v_team.player2_id;

  v_route:=format('/game/tournaments/%s/doubles',v_team.competition_id);
  v_title:=case
    when p_code='doubles.entry.accepted' then 'Doubles entry accepted · '||v_tournament
    else 'Doubles waitlist · '||v_tournament
  end;
  v_message:=case
    when p_code='doubles.entry.accepted'
      then format('Your team with %s received a place in the doubles draw.',v_p2.name)
    else format('Your team with %s is currently on the doubles alternate list.',v_p2.name)
  end;

  if v_p1.owner_user_id is not null then
    perform public.emit_notification_v1(
      v_p1.owner_user_id,v_p1.id,p_code,v_title,v_message,v_route,
      jsonb_build_object(
        'competition_id',v_team.competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_name',v_p2.name,'team_id',v_team.id,'entry_status',p_status_label,'action_url',v_route
      ),
      format('doubles-team:%s:%s:%s',v_team.id,p_code,v_p1.id)
    );
  end if;

  v_message:=case
    when p_code='doubles.entry.accepted'
      then format('Your team with %s received a place in the doubles draw.',v_p1.name)
    else format('Your team with %s is currently on the doubles alternate list.',v_p1.name)
  end;

  if v_p2.owner_user_id is not null then
    perform public.emit_notification_v1(
      v_p2.owner_user_id,v_p2.id,p_code,v_title,v_message,v_route,
      jsonb_build_object(
        'competition_id',v_team.competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_name',v_p1.name,'team_id',v_team.id,'entry_status',p_status_label,'action_url',v_route
      ),
      format('doubles-team:%s:%s:%s',v_team.id,p_code,v_p2.id)
    );
  end if;
end;
$$;

create or replace function public.allocate_doubles_entries_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_draw_size integer;
  v_minimum integer;
  v_valid integer:=0;
  v_active integer:=0;
  v_alternate integer:=0;
  v_processed_at timestamptz:=clock_timestamp();
  r record;
  v_a jsonb;
  v_b jsonb;
  v_doubles_points integer;
  v_strength integer;
begin
  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if not coalesce((v_timeline->>'enabled')::boolean,false) then
    return jsonb_build_object('status','doubles_disabled');
  end if;

  if v_now<(v_timeline->>'partnership_deadline_game_second')::bigint then
    return jsonb_build_object('status','not_due');
  end if;

  if exists(
    select 1
    from public.tournament_doubles_entry_lifecycle
    where competition_id=p_competition_id
      and allocation_processed_at is not null
  ) then
    return jsonb_build_object('status','already_allocated');
  end if;

  select ds.draw_size,ds.minimum_teams
  into v_draw_size,v_minimum
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id;

  for r in
    select *
    from public.tournament_doubles_teams
    where competition_id=p_competition_id
      and status='confirmed'
    for update
  loop
    v_a:=public.check_player_competition_availability_v1(r.player1_id,p_competition_id);
    v_b:=public.check_player_competition_availability_v1(r.player2_id,p_competition_id);

    if not coalesce((v_a->>'available')::boolean,false)
       or not coalesce((v_b->>'available')::boolean,false) then
      update public.tournament_doubles_teams
      set status='withdrawn',withdrawn_at=now(),entry_decided_at=v_processed_at,updated_at=now()
      where id=r.id;
      continue;
    end if;

    select coalesce(sum(dr.ranking_points),0)::integer
    into v_doubles_points
    from public.player_doubles_rankings dr
    where dr.player_id in (r.player1_id,r.player2_id);

    v_strength:=
      public.get_doubles_player_entry_strength_v1(r.player1_id,p_competition_id)
      +public.get_doubles_player_entry_strength_v1(r.player2_id,p_competition_id);

    update public.tournament_doubles_teams
    set combined_ranking_points_snapshot=coalesce(v_doubles_points,0),
        entry_strength_snapshot=coalesce(v_strength,0),
        updated_at=now()
    where id=r.id;

    v_valid:=v_valid+1;
  end loop;

  if v_valid<v_minimum then
    return jsonb_build_object(
      'status','insufficient_teams',
      'teams',v_valid,
      'minimum_teams',v_minimum
    );
  end if;

  with ranked as (
    select id,
           row_number() over(
             order by entry_strength_snapshot desc,
                      combined_ranking_points_snapshot desc,
                      created_at,
                      id
           ) rn
    from public.tournament_doubles_teams
    where competition_id=p_competition_id
      and status='confirmed'
  )
  update public.tournament_doubles_teams t
  set status=case when ranked.rn<=v_draw_size then 'active' else 'alternate' end,
      entry_decided_at=v_processed_at,
      updated_at=now()
  from ranked
  where ranked.id=t.id;

  select count(*) filter(where status='active'),
         count(*) filter(where status='alternate')
  into v_active,v_alternate
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and entry_decided_at=v_processed_at;

  insert into public.tournament_doubles_entry_lifecycle(
    competition_id,partnership_closed_at,allocation_processed_at,updated_at
  )
  values(p_competition_id,now(),v_processed_at,now())
  on conflict(competition_id) do update
  set partnership_closed_at=coalesce(public.tournament_doubles_entry_lifecycle.partnership_closed_at,excluded.partnership_closed_at),
      allocation_processed_at=excluded.allocation_processed_at,
      updated_at=now();

  for r in
    select id,status
    from public.tournament_doubles_teams
    where competition_id=p_competition_id
      and entry_decided_at=v_processed_at
      and status in ('active','alternate')
  loop
    if r.status='active' then
      perform public.notify_doubles_team_entry_v1(r.id,'doubles.entry.accepted','accepted');
    else
      perform public.notify_doubles_team_entry_v1(r.id,'doubles.entry.waitlisted','waitlisted');
    end if;
  end loop;

  return jsonb_build_object(
    'status','allocated',
    'accepted_teams',v_active,
    'waitlisted_teams',v_alternate,
    'draw_capacity',v_draw_size
  );
end;
$$;
revoke all on function public.allocate_doubles_entries_v1(uuid) from public,anon,authenticated;
grant execute on function public.allocate_doubles_entries_v1(uuid) to service_role;

create or replace function public.promote_doubles_alternate_v1(p_competition_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_capacity integer;
  v_active integer;
  v_team uuid;
begin
  if exists(
    select 1 from public.tournament_doubles_draw_publications
    where competition_id=p_competition_id
  ) then return null; end if;

  select ds.draw_size
  into v_capacity
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id;

  select count(*) into v_active
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status='active';

  if v_active>=coalesce(v_capacity,0) then return null; end if;

  select id into v_team
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status='alternate'
  order by entry_strength_snapshot desc,combined_ranking_points_snapshot desc,created_at,id
  limit 1
  for update;

  if v_team is null then return null; end if;

  update public.tournament_doubles_teams
  set status='active',entry_decided_at=now(),updated_at=now()
  where id=v_team;

  perform public.notify_doubles_team_entry_v1(v_team,'doubles.entry.accepted','accepted_from_alternate');

  return v_team;
end;
$$;
revoke all on function public.promote_doubles_alternate_v1(uuid) from public,anon,authenticated;
grant execute on function public.promote_doubles_alternate_v1(uuid) to service_role;

create or replace function public.publish_doubles_draw_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_series uuid;
  v_enabled boolean;
  v_draw_max smallint;
  v_bracket smallint:=4;
  v_min smallint;
  v_count integer;
  v_selected integer;
  v_start_week integer;
  v_team record;
  v_ready record;
  v_rank integer:=0;
  v_match integer;
  v_id uuid;
  v_created integer:=0;
  v_seed_limit integer;
  v_timeline jsonb;
  v_alloc jsonb;
begin
  if exists(
    select 1
    from public.tournament_doubles_draw_publications
    where competition_id=p_competition_id
  ) then
    return jsonb_build_object('status','already_published');
  end if;

  select e.tournament_series_id,ds.is_enabled,ds.draw_size,ds.minimum_teams,min(ss.season_week)
  into v_series,v_enabled,v_draw_max,v_min,v_start_week
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=e.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by e.tournament_series_id,ds.is_enabled,ds.draw_size,ds.minimum_teams;

  if not coalesce(v_enabled,false) then
    raise exception 'Doubles is not enabled for this tournament.';
  end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if public.current_game_second_v1()<(v_timeline->>'draw_lock_game_second')::bigint then
    return jsonb_build_object('status','draw_not_due');
  end if;

  if not exists(
    select 1
    from public.tournament_doubles_entry_lifecycle
    where competition_id=p_competition_id
      and allocation_processed_at is not null
  ) then
    v_alloc:=public.allocate_doubles_entries_v1(p_competition_id);
    if coalesce(v_alloc->>'status','') not in ('allocated','already_allocated') then
      return v_alloc;
    end if;
  end if;

  select count(*) into v_count
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status='active';

  if v_count<v_min then
    return jsonb_build_object(
      'status','insufficient_teams',
      'team_count',v_count,
      'minimum_teams',v_min
    );
  end if;

  v_selected:=least(v_count,v_draw_max);

  while v_bracket<v_selected loop
    v_bracket:=(v_bracket*2)::smallint;
  end loop;
  v_bracket:=least(v_bracket,v_draw_max)::smallint;
  v_seed_limit:=least(8,greatest(1,v_bracket/4));

  update public.tournament_doubles_teams
  set seed_number=null,bracket_slot=null,updated_at=now()
  where competition_id=p_competition_id
    and status='active';

  for v_team in
    select id
    from public.tournament_doubles_teams
    where competition_id=p_competition_id
      and status='active'
    order by
      entry_strength_snapshot desc,
      combined_ranking_points_snapshot desc,
      created_at,
      id
    limit v_selected
  loop
    v_rank:=v_rank+1;
    update public.tournament_doubles_teams
    set seed_number=case when v_rank<=v_seed_limit then v_rank::smallint else null end,
        bracket_slot=case
          when v_rank<=v_bracket/2 then (v_rank*2-1)::smallint
          else ((v_bracket-v_rank+1)*2)::smallint
        end,
        updated_at=now()
    where id=v_team.id;
  end loop;

  insert into public.tournament_doubles_draw_publications(
    competition_id,bracket_size,team_count
  )
  values(p_competition_id,v_bracket,v_selected);

  for v_match in 1..(v_bracket/2) loop
    insert into public.tournament_doubles_matches(
      competition_id,round_number,round_label,match_number,bracket_size,
      scheduled_season_week,scheduled_day,team1_id,team2_id,status
    )
    values(
      p_competition_id,
      1,
      public.doubles_round_label_v1(v_bracket,1),
      v_match,
      v_bracket,
      v_start_week,
      1,
      (
        select id
        from public.tournament_doubles_teams
        where competition_id=p_competition_id
          and status='active'
          and bracket_slot=v_match*2-1
      ),
      (
        select id
        from public.tournament_doubles_teams
        where competition_id=p_competition_id
          and status='active'
          and bracket_slot=v_match*2
      ),
      'scheduled'
    )
    returning id into v_id;
    v_created:=v_created+1;
  end loop;

  update public.tournament_doubles_matches
  set status=case when team1_id is null and team2_id is null then 'cancelled' else 'bye' end,
      winner_team_id=case
        when (team1_id is null)<>(team2_id is null) then coalesce(team1_id,team2_id)
        else null
      end,
      completion_reason=case
        when (team1_id is null)<>(team2_id is null) then 'draw_bye'
        else 'empty_draw_slot'
      end,
      completed_at=now(),
      updated_at=now()
  where competition_id=p_competition_id
    and round_number=1
    and status='scheduled'
    and (team1_id is null or team2_id is null);

  for v_ready in
    select id
    from public.tournament_doubles_matches
    where competition_id=p_competition_id
      and round_number=1
      and status='scheduled'
      and team1_id is not null
      and team2_id is not null
  loop
    perform public.schedule_doubles_match_v1(v_ready.id);
  end loop;

  insert into public.tournament_doubles_entry_lifecycle(
    competition_id,draw_processed_at,updated_at
  )
  values(p_competition_id,now(),now())
  on conflict(competition_id) do update
  set draw_processed_at=excluded.draw_processed_at,
      updated_at=now();

  return jsonb_build_object(
    'status','published',
    'teams',v_selected,
    'bracket_size',v_bracket,
    'maximum_draw_size',v_draw_max,
    'first_round_matches',v_created,
    'byes',greatest(v_bracket-v_selected,0)
  );
end;
$$;

create or replace function public.notify_doubles_draw_published_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_tournament text;
  v_city text;
  v_route text;
  r record;
begin
  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;

  v_route:=format('/game/tournaments/%s/doubles',new.competition_id);

  for r in
    select distinct p.owner_user_id,p.id player_id
    from public.tournament_doubles_teams t
    cross join lateral (values(t.player1_id),(t.player2_id)) x(player_id)
    join public.players p on p.id=x.player_id
    where t.competition_id=new.competition_id
      and t.status='active'
      and p.owner_user_id is not null
  loop
    perform public.emit_notification_v1(
      r.owner_user_id,r.player_id,
      'doubles.draw.published',
      'Doubles draw published · '||v_tournament,
      'The official doubles draw is available. Open the tournament Doubles page to see your bracket and schedule.',
      v_route,
      jsonb_build_object(
        'competition_id',new.competition_id,'tournament_name',v_tournament,'city',v_city,
        'bracket_size',new.bracket_size,'team_count',new.team_count,'action_url',v_route
      ),
      format('doubles-draw:%s:%s',new.competition_id,r.player_id)
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_doubles_draw_published_v1
on public.tournament_doubles_draw_publications;
create trigger trg_notify_doubles_draw_published_v1
after insert on public.tournament_doubles_draw_publications
for each row execute function public.notify_doubles_draw_published_v1();

create or replace function public.withdraw_from_doubles_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_team public.tournament_doubles_teams%rowtype;
  v_match public.tournament_doubles_matches%rowtype;
  v_other uuid;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_draw_published boolean;
  v_tournament text;
  v_city text;
  v_route text;
  v_p1 record;
  v_p2 record;
  v_promoted uuid;
  v_mode text;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if v_player is null then raise exception 'A player profile is required.'; end if;

  select * into v_team
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status in ('confirmed','active','alternate')
    and (player1_id=v_player or player2_id=v_player)
  order by created_at desc
  limit 1
  for update;

  if v_team.id is null then
    raise exception 'No active doubles team found for this tournament.';
  end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  select exists(
    select 1 from public.tournament_doubles_draw_publications
    where competition_id=p_competition_id
  ) into v_draw_published;

  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;

  select owner_user_id,id,trim(first_name||' '||last_name) name
  into v_p1 from public.players where id=v_team.player1_id;
  select owner_user_id,id,trim(first_name||' '||last_name) name
  into v_p2 from public.players where id=v_team.player2_id;

  v_route:=format('/game/tournaments/%s/doubles',p_competition_id);

  update public.tournament_doubles_teams
  set status='withdrawn',withdrawn_at=now(),updated_at=now()
  where id=v_team.id;

  update public.tournament_doubles_partner_invitations
  set status='cancelled',responded_at=now(),updated_at=now()
  where competition_id=p_competition_id
    and status='pending'
    and (
      inviter_player_id in (v_team.player1_id,v_team.player2_id)
      or invitee_player_id in (v_team.player1_id,v_team.player2_id)
    );

  if not v_draw_published then
    if v_now<(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_mode:='partnership_dissolved';
    else
      v_mode:='entry_withdrawn';
      if v_team.status='active' then
        v_promoted:=public.promote_doubles_alternate_v1(p_competition_id);
      end if;
    end if;
  else
    v_mode:='draw_withdrawal';
  end if;

  if v_p1.owner_user_id is not null then
    perform public.emit_notification_v1(
      v_p1.owner_user_id,v_p1.id,
      'doubles.team.withdrawn',
      'Doubles team withdrawn · '||v_tournament,
      format('Your doubles team with %s has been withdrawn. Your singles participation is unchanged.',v_p2.name),
      v_route,
      jsonb_build_object(
        'competition_id',p_competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_name',v_p2.name,'team_id',v_team.id,'withdrawal_mode',v_mode,'action_url',v_route
      ),
      format('doubles-team:%s:withdrawn:%s',v_team.id,v_p1.id)
    );
  end if;

  if v_p2.owner_user_id is not null then
    perform public.emit_notification_v1(
      v_p2.owner_user_id,v_p2.id,
      'doubles.team.withdrawn',
      'Doubles team withdrawn · '||v_tournament,
      format('Your doubles team with %s has been withdrawn. Your singles participation is unchanged.',v_p1.name),
      v_route,
      jsonb_build_object(
        'competition_id',p_competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_name',v_p1.name,'team_id',v_team.id,'withdrawal_mode',v_mode,'action_url',v_route
      ),
      format('doubles-team:%s:withdrawn:%s',v_team.id,v_p2.id)
    );
  end if;

  if not v_draw_published then
    return jsonb_build_object(
      'status',v_mode,
      'team_id',v_team.id,
      'can_find_new_partner',v_now<(v_timeline->>'partnership_deadline_game_second')::bigint,
      'promoted_alternate_team_id',v_promoted,
      'singles_unchanged',true
    );
  end if;

  select * into v_match
  from public.tournament_doubles_matches
  where competition_id=p_competition_id
    and status='scheduled'
    and (team1_id=v_team.id or team2_id=v_team.id)
  order by round_number,match_number
  limit 1
  for update;

  if v_match.id is null then
    return jsonb_build_object(
      'status','withdrawn',
      'team_id',v_team.id,
      'walkover_created',false,
      'singles_unchanged',true
    );
  end if;

  v_other:=case
    when v_match.team1_id=v_team.id then v_match.team2_id
    else v_match.team1_id
  end;

  if v_other is not null then
    update public.tournament_doubles_matches
    set status='walkover',
        winner_team_id=v_other,
        completion_reason='team_withdrawal',
        completed_at=now(),
        updated_at=now()
    where id=v_match.id;

    return jsonb_build_object(
      'status','withdrawn',
      'team_id',v_team.id,
      'walkover_created',true,
      'match_id',v_match.id,
      'singles_unchanged',true
    );
  end if;

  return jsonb_build_object(
    'status','withdrawn',
    'team_id',v_team.id,
    'walkover_created',false,
    'waiting_for_opponent',true,
    'singles_unchanged',true
  );
end;
$$;

create or replace function public.process_due_doubles_entry_lifecycle_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_now bigint:=public.current_game_second_v1();
  r record;
  v_timeline jsonb;
  v_expired integer:=0;
  v_allocated integer:=0;
  v_drawn integer:=0;
  v_result jsonb;
  v_n integer;
begin
  for r in
    select wc.id competition_id
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_doubles_settings ds
      on ds.tournament_series_id=ed.tournament_series_id
     and ds.is_enabled
    where wc.status<>'canceled'
      and ed.status<>'canceled'
  loop
    v_timeline:=public.get_tournament_doubles_entry_timeline_v1(r.competition_id);

    insert into public.tournament_doubles_entry_lifecycle(competition_id,updated_at)
    values(r.competition_id,now())
    on conflict(competition_id) do nothing;

    if v_now>=(v_timeline->>'registration_deadline_game_second')::bigint then
      update public.tournament_doubles_entry_lifecycle
      set registration_closed_at=coalesce(registration_closed_at,now()),updated_at=now()
      where competition_id=r.competition_id;
    end if;

    if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.expire_doubles_partner_invitations_v1(r.competition_id,v_now);
      v_expired:=v_expired+coalesce(v_n,0);

      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=r.competition_id
        and status='active';

      update public.tournament_doubles_entry_lifecycle
      set partnership_closed_at=coalesce(partnership_closed_at,now()),updated_at=now()
      where competition_id=r.competition_id;

      if not exists(
        select 1
        from public.tournament_doubles_entry_lifecycle
        where competition_id=r.competition_id
          and allocation_processed_at is not null
      ) then
        v_result:=public.allocate_doubles_entries_v1(r.competition_id);
        if v_result->>'status'='allocated' then
          v_allocated:=v_allocated+1;
        end if;
      end if;
    end if;

    if v_now>=(v_timeline->>'draw_lock_game_second')::bigint
       and not exists(
         select 1
         from public.tournament_doubles_draw_publications
         where competition_id=r.competition_id
       ) then
      v_result:=public.publish_doubles_draw_v1(r.competition_id);
      if v_result->>'status'='published' then
        v_drawn:=v_drawn+1;
      end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'invitations_expired',v_expired,
    'competitions_allocated',v_allocated,
    'draws_published',v_drawn
  );
end;
$$;
revoke all on function public.process_due_doubles_entry_lifecycle_v1() from public,anon,authenticated;
grant execute on function public.process_due_doubles_entry_lifecycle_v1() to service_role;

create or replace function public.process_match_replay_clock_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  l jsonb;
  e jsonb;
  a jsonb;
  b jsonb;
  d jsonb;
begin
  l:=public.process_due_doubles_entry_lifecycle_v1();
  e:=public.process_due_match_engine_v1();
  a:=public.start_due_match_replays_v1();
  b:=public.finalize_due_match_replays_v1();
  d:=public.process_due_doubles_matches_v1();

  return jsonb_build_object(
    'prepared',coalesce((e->>'prepared')::int,0),
    'started',coalesce((a->>'started')::int,0),
    'completed',coalesce((b->>'completed')::int,0),
    'doubles_processed',coalesce((d->>'processed')::int,0),
    'doubles_invitations_expired',coalesce((l->>'invitations_expired')::int,0),
    'doubles_competitions_allocated',coalesce((l->>'competitions_allocated')::int,0),
    'doubles_draws_published',coalesce((l->>'draws_published')::int,0)
  );
end;
$$;

create or replace function public.get_tournament_doubles_hub_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_core jsonb;
  v_timeline jsonb;
  v_availability jsonb;
  v_tournament jsonb;
  v_listing jsonb;
  v_my_team jsonb;
  v_market jsonb;
  v_incoming jsonb;
  v_outgoing jsonb;
  v_teams jsonb;
  v_status text;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if v_player.id is null then raise exception 'A player profile is required.'; end if;

  v_core:=public.get_tournament_doubles_core_v1(p_competition_id);
  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  v_availability:=public.check_player_competition_availability_v1(v_player.id,p_competition_id);

  select jsonb_build_object(
    'competition_id',wc.id,
    'world',wc.world,
    'name',ts.name,
    'city',ts.city,
    'country_code',ts.country_code,
    'surface',ts.surface,
    'category_code',ts.category_code
  )
  into v_tournament
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;

  select jsonb_build_object(
    'id',l.id,'status',l.status,'created_at',l.created_at
  )
  into v_listing
  from public.tournament_doubles_partner_listings l
  where l.competition_id=p_competition_id
    and l.player_id=v_player.id
  order by l.updated_at desc
  limit 1;

  select jsonb_build_object(
    'id',t.id,
    'status',t.status,
    'entry_strength',t.entry_strength_snapshot,
    'seed_number',t.seed_number,
    'partner_id',case when t.player1_id=v_player.id then t.player2_id else t.player1_id end,
    'partner_name',case
      when t.player1_id=v_player.id then trim(p2.first_name||' '||p2.last_name)
      else trim(p1.first_name||' '||p1.last_name)
    end,
    'partner_country_code',case
      when t.player1_id=v_player.id then p2.country_code else p1.country_code
    end,
    'partner_doubles_points',case
      when t.player1_id=v_player.id then coalesce(d2.ranking_points,0)
      else coalesce(d1.ranking_points,0)
    end
  )
  into v_my_team
  from public.tournament_doubles_teams t
  join public.players p1 on p1.id=t.player1_id
  join public.players p2 on p2.id=t.player2_id
  left join public.player_doubles_rankings d1 on d1.player_id=t.player1_id
  left join public.player_doubles_rankings d2 on d2.player_id=t.player2_id
  where t.competition_id=p_competition_id
    and (t.player1_id=v_player.id or t.player2_id=v_player.id)
  order by
    case t.status
      when 'active' then 1
      when 'alternate' then 2
      when 'confirmed' then 3
      when 'champion' then 4
      when 'eliminated' then 5
      else 6
    end,
    t.created_at desc
  limit 1;

  with doubles_ranked as (
    select dr.player_id,dr.ranking_points,
           row_number() over(
             partition by dr.world
             order by dr.ranking_points desc,dr.seed_rating desc,dr.player_id
           )::integer rank_position
    from public.player_doubles_rankings dr
  ),
  singles_ranked as (
    select p.id player_id,coalesce(pr.ranking_points,0) ranking_points,
           row_number() over(
             partition by p.world
             order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.id
           )::integer rank_position
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.moderation_status<>'rejected'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'listing_id',l.id,
    'player_id',p.id,
    'first_name',p.first_name,
    'last_name',p.last_name,
    'country_code',p.country_code,
    'preferred_surface',p.preferred_surface,
    'surface_match',lower(coalesce(p.preferred_surface,''))=lower(coalesce(v_tournament->>'surface','')),
    'playing_style',p.playing_style,
    'doubles_rank',dr.rank_position,
    'doubles_points',coalesce(dr.ranking_points,0),
    'singles_rank',sr.rank_position,
    'singles_points',coalesce(sr.ranking_points,0),
    'singles_participation',coalesce(
      (
        select case
          when te.entry_status='active' then te.draw_type
          else null
        end
        from public.tournament_entries te
        where te.competition_id=p_competition_id
          and te.player_id=p.id
        order by te.updated_at desc
        limit 1
      ),
      (
        select case
          when a.status='applied' then 'applied'
          when a.status='accepted_main_draw' then 'main_draw'
          when a.status='accepted_qualification' then 'qualification'
          else null
        end
        from public.tournament_applications a
        where a.competition_id=p_competition_id
          and a.player_id=p.id
          and a.status<>'withdrawn'
        order by a.updated_at desc
        limit 1
      ),
      'none'
    ),
    'doubles_events',(
      select count(*)
      from public.player_doubles_tournament_results r
      where r.player_id=p.id
    ),
    'doubles_titles',(
      select count(*)
      from public.player_doubles_tournament_results r
      where r.player_id=p.id
        and r.result_stage_code='winner'
    ),
    'is_me',p.id=v_player.id
  ) order by
    coalesce(dr.rank_position,2147483647),
    coalesce(sr.rank_position,2147483647),
    p.last_name,p.first_name),'[]'::jsonb)
  into v_market
  from public.tournament_doubles_partner_listings l
  join public.players p on p.id=l.player_id
  left join doubles_ranked dr on dr.player_id=p.id
  left join singles_ranked sr on sr.player_id=p.id
  where l.competition_id=p_competition_id
    and l.status='active'
    and p.world=v_player.world
    and not exists(
      select 1
      from public.tournament_doubles_teams t
      where t.competition_id=p_competition_id
        and t.status in ('confirmed','active','alternate')
        and (t.player1_id=p.id or t.player2_id=p.id)
    )
    and coalesce(
      (public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,
      false
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,
    'status',i.status,
    'partner_id',p.id,
    'partner_name',trim(p.first_name||' '||p.last_name),
    'country_code',p.country_code,
    'created_at',i.created_at,
    'expires_game_second',i.expires_game_second,
    'expires_at_game',public.game_moment_json_v1(i.expires_game_second),
    'doubles_points',coalesce(dr.ranking_points,0)
  ) order by i.created_at desc),'[]'::jsonb)
  into v_incoming
  from public.tournament_doubles_partner_invitations i
  join public.players p on p.id=i.inviter_player_id
  left join public.player_doubles_rankings dr on dr.player_id=p.id
  where i.competition_id=p_competition_id
    and i.invitee_player_id=v_player.id
    and i.status='pending';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,
    'status',i.status,
    'partner_id',p.id,
    'partner_name',trim(p.first_name||' '||p.last_name),
    'country_code',p.country_code,
    'created_at',i.created_at,
    'expires_game_second',i.expires_game_second,
    'expires_at_game',public.game_moment_json_v1(i.expires_game_second),
    'doubles_points',coalesce(dr.ranking_points,0)
  ) order by i.created_at desc),'[]'::jsonb)
  into v_outgoing
  from public.tournament_doubles_partner_invitations i
  join public.players p on p.id=i.invitee_player_id
  left join public.player_doubles_rankings dr on dr.player_id=p.id
  where i.competition_id=p_competition_id
    and i.inviter_player_id=v_player.id
    and i.status='pending';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',t.id,
    'status',t.status,
    'player1_id',p1.id,
    'player1_name',trim(p1.first_name||' '||p1.last_name),
    'player1_country_code',p1.country_code,
    'player2_id',p2.id,
    'player2_name',trim(p2.first_name||' '||p2.last_name),
    'player2_country_code',p2.country_code,
    'combined_doubles_points',t.combined_ranking_points_snapshot,
    'entry_strength',t.entry_strength_snapshot,
    'seed_number',t.seed_number
  ) order by
    case t.status when 'active' then 1 when 'confirmed' then 2 when 'alternate' then 3 when 'champion' then 4 else 5 end,
    t.entry_strength_snapshot desc,
    t.created_at),'[]'::jsonb)
  into v_teams
  from public.tournament_doubles_teams t
  join public.players p1 on p1.id=t.player1_id
  join public.players p2 on p2.id=t.player2_id
  where t.competition_id=p_competition_id
    and t.status<>'withdrawn';

  if v_my_team is not null then
    v_status:=case v_my_team->>'status'
      when 'confirmed' then 'partnership_confirmed'
      when 'active' then 'entry_accepted'
      when 'alternate' then 'waitlisted'
      when 'champion' then 'champion'
      when 'eliminated' then 'eliminated'
      else 'withdrawn'
    end;
  elsif coalesce(v_listing->>'status','')='active' then
    v_status:='looking_for_partner';
  elsif jsonb_array_length(v_incoming)>0 then
    v_status:='invitation_received';
  elsif not coalesce((v_availability->>'available')::boolean,false) then
    v_status:='unavailable';
  elsif coalesce(v_timeline->>'phase','')='not_open' then
    v_status:='not_open';
  elsif coalesce((v_timeline->>'entry_locked')::boolean,false) then
    v_status:='entry_locked';
  else
    v_status:='available';
  end if;

  return jsonb_build_object(
    'competition_id',p_competition_id,
    'tournament',v_tournament,
    'core',v_core,
    'timeline',v_timeline,
    'availability',v_availability,
    'player_status',v_status,
    'my_listing',v_listing,
    'my_team',v_my_team,
    'marketplace',v_market,
    'incoming_invitations',v_incoming,
    'outgoing_invitations',v_outgoing,
    'teams',v_teams
  );
end;
$$;
revoke all on function public.get_tournament_doubles_hub_v1(uuid) from public,anon;
grant execute on function public.get_tournament_doubles_hub_v1(uuid) to authenticated;