
-- Premium ranking protection + AI doubles marketplace support.

create or replace function public.has_active_premium_v1()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1 from public.premium_memberships pm
    where pm.user_id=auth.uid()
      and pm.plan_code='premium'
      and pm.status='active'
      and (pm.current_period_end is null or pm.current_period_end>now())
  );
$$;
revoke all on function public.has_active_premium_v1() from public,anon;
grant execute on function public.has_active_premium_v1() to authenticated,service_role;

create or replace function public.get_premium_ranking_protection_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_payload jsonb;
  v_items jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if not public.has_active_premium_v1() then
    return jsonb_build_object('premium',false,'locked',true,'contributions','[]'::jsonb);
  end if;

  v_payload:=public.get_player_ranking_expirations_v1();
  select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb)
  into v_items
  from jsonb_array_elements(coalesce(v_payload->'contributions','[]'::jsonb)) with ordinality
  where ordinality<=5;

  return v_payload || jsonb_build_object('premium',true,'locked',false,'contributions',v_items);
end;
$$;
revoke all on function public.get_premium_ranking_protection_v1() from public,anon;
grant execute on function public.get_premium_ranking_protection_v1() to authenticated,service_role;

alter table public.tournament_doubles_partner_listings
  alter column owner_user_id drop not null;

create or replace function public.seed_ai_doubles_partner_marketplace_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_world text;
  v_draw_size integer;
  v_target integer;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_inserted integer:=0;
begin
  select wc.world,ds.draw_size
  into v_world,v_draw_size
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id and ds.is_enabled;

  if v_world is null then return 0; end if;
  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if v_now<(v_timeline->>'registration_open_game_second')::bigint
     or v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    return 0;
  end if;

  v_target:=greatest(12,coalesce(v_draw_size,16)*2);

  with ranked as (
    select p.id,
           coalesce(pr.ranking_points,0) singles_points,
           exists(
             select 1 from public.tournament_entries te
             where te.competition_id=p_competition_id and te.player_id=p.id and te.entry_status='active'
           ) same_event_entry,
           exists(
             select 1 from public.tournament_entries te
             where te.competition_id=p_competition_id and te.player_id=p.id
               and te.entry_status='active' and te.draw_type='qualification'
           ) same_event_qual,
           ((hashtextextended(p.id::text||':'||p_competition_id::text,0)%100)+100)%100 hash_bucket
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world
      and p.player_type='ai'
      and p.moderation_status<>'rejected'
      and coalesce((public.check_player_competition_availability_v1(p.id,p_competition_id)->>'available')::boolean,false)
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
  ),
  candidates as (
    select *
    from ranked
    where same_event_qual or hash_bucket<50
    order by
      case when same_event_qual then 0 when same_event_entry then 1 else 2 end,
      singles_points asc,
      hash_bucket,
      id
    limit v_target
  )
  insert into public.tournament_doubles_partner_listings(
    competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
  )
  select p_competition_id,id,null,'active',now(),now(),null
  from candidates
  on conflict(competition_id,player_id) do update
  set owner_user_id=null,
      status=case
        when public.tournament_doubles_partner_listings.status in ('matched') then public.tournament_doubles_partner_listings.status
        else 'active'
      end,
      updated_at=now(),
      closed_at=case
        when public.tournament_doubles_partner_listings.status='matched' then public.tournament_doubles_partner_listings.closed_at
        else null
      end;

  get diagnostics v_inserted=row_count;
  return v_inserted;
end;
$$;
revoke all on function public.seed_ai_doubles_partner_marketplace_v1(uuid) from public,anon,authenticated;
grant execute on function public.seed_ai_doubles_partner_marketplace_v1(uuid) to service_role;

create or replace function public.pair_ai_doubles_teams_v1(p_competition_id uuid)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
  v_draw_size integer;
  v_existing integer;
  v_needed integer;
  v_p1 uuid;
  v_p2 uuid;
  v_team uuid;
  v_created integer:=0;
begin
  select ds.draw_size into v_draw_size
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id and ds.is_enabled;

  if v_draw_size is null then return 0; end if;

  select count(*) into v_existing
  from public.tournament_doubles_teams
  where competition_id=p_competition_id
    and status in ('confirmed','active','alternate');

  v_needed:=greatest(0,v_draw_size-v_existing);

  while v_needed>0 loop
    select l.player_id into v_p1
    from public.tournament_doubles_partner_listings l
    join public.players p on p.id=l.player_id
    where l.competition_id=p_competition_id
      and l.status='active'
      and p.player_type='ai'
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by public.get_doubles_player_entry_strength_v1(p.id,p_competition_id) desc,p.id
    limit 1;

    exit when v_p1 is null;

    select l.player_id into v_p2
    from public.tournament_doubles_partner_listings l
    join public.players p on p.id=l.player_id
    where l.competition_id=p_competition_id
      and l.status='active'
      and p.player_type='ai'
      and l.player_id<>v_p1
      and not exists(
        select 1 from public.tournament_doubles_teams t
        where t.competition_id=p_competition_id
          and t.status in ('confirmed','active','alternate')
          and (t.player1_id=p.id or t.player2_id=p.id)
      )
    order by public.get_doubles_player_entry_strength_v1(p.id,p_competition_id) desc,p.id
    limit 1;

    exit when v_p2 is null;

    begin
      v_team:=public.create_doubles_team_internal_v1(
        p_competition_id,v_p1,v_p2,'ai_marketplace'
      );
      update public.tournament_doubles_partner_listings
      set status='matched',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id
        and player_id in (v_p1,v_p2)
        and status='active';
      v_created:=v_created+1;
      v_needed:=v_needed-1;
    exception when others then
      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=p_competition_id and player_id in (v_p1,v_p2) and status='active';
    end;

    v_p1:=null;v_p2:=null;
  end loop;

  return v_created;
end;
$$;
revoke all on function public.pair_ai_doubles_teams_v1(uuid) from public,anon,authenticated;
grant execute on function public.pair_ai_doubles_teams_v1(uuid) to service_role;

create or replace function public.send_doubles_partner_invitation_v1(p_competition_id uuid, p_invitee_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_inviter uuid;
  v_inviter_name text;
  v_invitee_name text;
  v_invitee_uid uuid;
  v_invitee_type text;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_a jsonb;
  v_b jsonb;
  v_invitation public.tournament_doubles_partner_invitations%rowtype;
  v_tournament text;
  v_city text;
  v_route text;
  v_team_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id,trim(first_name||' '||last_name)
  into v_inviter,v_inviter_name
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if v_inviter is null then raise exception 'A player profile is required.'; end if;
  if v_inviter=p_invitee_player_id then raise exception 'You cannot invite yourself.'; end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if not coalesce((v_timeline->>'enabled')::boolean,false) then raise exception 'Doubles is not enabled for this tournament.'; end if;
  if v_now<(v_timeline->>'registration_open_game_second')::bigint then raise exception 'Doubles registration is not open yet.'; end if;
  if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then raise exception 'The doubles partnership deadline has passed.'; end if;

  select p.owner_user_id,p.player_type,trim(p.first_name||' '||p.last_name)
  into v_invitee_uid,v_invitee_type,v_invitee_name
  from public.players p
  join public.tournament_doubles_partner_listings l
    on l.player_id=p.id and l.competition_id=p_competition_id and l.status='active'
  where p.id=p_invitee_player_id;

  if v_invitee_name is null then raise exception 'This player is no longer available in the partner marketplace.'; end if;

  if exists(
    select 1 from public.tournament_doubles_teams t
    where t.competition_id=p_competition_id
      and t.status in ('confirmed','active','alternate')
      and (t.player1_id in (v_inviter,p_invitee_player_id) or t.player2_id in (v_inviter,p_invitee_player_id))
  ) then raise exception 'One of these players already has a doubles team for this tournament.'; end if;

  v_a:=public.check_player_competition_availability_v1(v_inviter,p_competition_id);
  v_b:=public.check_player_competition_availability_v1(p_invitee_player_id,p_competition_id);
  if not coalesce((v_a->>'available')::boolean,false) then raise exception 'You have a conflicting tournament or calendar commitment.'; end if;
  if not coalesce((v_b->>'available')::boolean,false) then raise exception 'The selected player now has a conflicting tournament or calendar commitment.'; end if;

  select ts.name,ts.city into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;
  v_route:=format('/game/tournaments/%s/doubles',p_competition_id);

  if v_invitee_type='ai' then
    v_team_id:=public.create_doubles_team_internal_v1(
      p_competition_id,v_inviter,p_invitee_player_id,'human_ai_marketplace'
    );

    update public.tournament_doubles_partner_listings
    set status='matched',closed_at=now(),updated_at=now()
    where competition_id=p_competition_id
      and player_id in (v_inviter,p_invitee_player_id)
      and status='active';

    update public.tournament_doubles_partner_invitations
    set status='cancelled',responded_at=now(),updated_at=now()
    where competition_id=p_competition_id
      and status='pending'
      and (
        inviter_player_id=v_inviter or invitee_player_id=v_inviter
      );

    perform public.emit_notification_v1(
      v_uid,v_inviter,'doubles.partnership.confirmed',
      'Doubles partnership confirmed · '||v_tournament,
      format('%s has joined you for doubles in %s.',v_invitee_name,v_city),
      v_route,
      jsonb_build_object(
        'competition_id',p_competition_id,'tournament_name',v_tournament,'city',v_city,
        'partner_id',p_invitee_player_id,'partner_name',v_invitee_name,'team_id',v_team_id,
        'ai_partner',true,'action_url',v_route
      ),
      format('doubles-team:%s:confirmed:%s',v_team_id,v_inviter)
    );

    return jsonb_build_object(
      'status','partnership_confirmed',
      'team_id',v_team_id,
      'invitee_player_id',p_invitee_player_id,
      'invitee_name',v_invitee_name,
      'ai_partner',true
    );
  end if;

  if v_invitee_uid is null then raise exception 'This player cannot receive a doubles invitation.'; end if;

  if exists(
    select 1 from public.tournament_doubles_partner_invitations i
    where i.competition_id=p_competition_id and i.status='pending'
      and i.inviter_player_id=p_invitee_player_id and i.invitee_player_id=v_inviter
  ) then raise exception 'This player has already invited you. Respond to the incoming invitation instead.'; end if;

  select * into v_invitation
  from public.tournament_doubles_partner_invitations
  where competition_id=p_competition_id
    and inviter_player_id=v_inviter and invitee_player_id=p_invitee_player_id and status='pending'
  limit 1;

  if v_invitation.id is null then
    insert into public.tournament_doubles_partner_invitations(
      competition_id,inviter_player_id,invitee_player_id,inviter_user_id,invitee_user_id,status,expires_game_second
    )
    values(
      p_competition_id,v_inviter,p_invitee_player_id,v_uid,v_invitee_uid,'pending',
      (v_timeline->>'partnership_deadline_game_second')::bigint
    )
    returning * into v_invitation;
  end if;

  perform public.emit_notification_v1(
    v_invitee_uid,p_invitee_player_id,'doubles.partner.invitation',
    'Doubles invitation · '||v_tournament,
    format('%s invited you to play doubles in %s. Respond before the partnership deadline.',v_inviter_name,v_city),
    v_route,
    jsonb_build_object(
      'competition_id',p_competition_id,'tournament_name',v_tournament,'city',v_city,
      'proposed_partner_id',v_inviter,'proposed_partner_name',v_inviter_name,
      'partnership_deadline',v_timeline->'partnership_deadline',
      'tournament_start',v_timeline->'tournament_start',
      'tournament_end',v_timeline->'tournament_end','action_url',v_route
    ),
    format('doubles-invite:%s:created',v_invitation.id)
  );

  return jsonb_build_object(
    'status','pending','invitation_id',v_invitation.id,'invitee_player_id',p_invitee_player_id,
    'invitee_name',v_invitee_name,'expires_game_second',v_invitation.expires_game_second
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
  v_ai_listed integer:=0;
  v_ai_paired integer:=0;
  v_result jsonb;
  v_n integer;
begin
  for r in
    select wc.id competition_id
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id and ds.is_enabled
    where wc.status<>'canceled' and ed.status<>'canceled'
  loop
    v_timeline:=public.get_tournament_doubles_entry_timeline_v1(r.competition_id);

    insert into public.tournament_doubles_entry_lifecycle(competition_id,updated_at)
    values(r.competition_id,now())
    on conflict(competition_id) do nothing;

    if v_now>=(v_timeline->>'registration_open_game_second')::bigint
       and v_now<(v_timeline->>'registration_deadline_game_second')::bigint then
      v_n:=public.seed_ai_doubles_partner_marketplace_v1(r.competition_id);
      v_ai_listed:=v_ai_listed+coalesce(v_n,0);
    end if;

    if v_now>=(v_timeline->>'registration_deadline_game_second')::bigint then
      update public.tournament_doubles_entry_lifecycle
      set registration_closed_at=coalesce(registration_closed_at,now()),updated_at=now()
      where competition_id=r.competition_id;
    end if;

    if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
      v_n:=public.expire_doubles_partner_invitations_v1(r.competition_id,v_now);
      v_expired:=v_expired+coalesce(v_n,0);

      v_n:=public.pair_ai_doubles_teams_v1(r.competition_id);
      v_ai_paired:=v_ai_paired+coalesce(v_n,0);

      update public.tournament_doubles_partner_listings
      set status='expired',closed_at=now(),updated_at=now()
      where competition_id=r.competition_id and status='active';

      update public.tournament_doubles_entry_lifecycle
      set partnership_closed_at=coalesce(partnership_closed_at,now()),updated_at=now()
      where competition_id=r.competition_id;

      if not exists(
        select 1 from public.tournament_doubles_entry_lifecycle
        where competition_id=r.competition_id and allocation_processed_at is not null
      ) then
        v_result:=public.allocate_doubles_entries_v1(r.competition_id);
        if v_result->>'status'='allocated' then v_allocated:=v_allocated+1; end if;
      end if;
    end if;

    if v_now>=(v_timeline->>'draw_lock_game_second')::bigint
       and not exists(select 1 from public.tournament_doubles_draw_publications where competition_id=r.competition_id) then
      v_result:=public.publish_doubles_draw_v1(r.competition_id);
      if v_result->>'status'='published' then v_drawn:=v_drawn+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'invitations_expired',v_expired,
    'ai_marketplace_listings',v_ai_listed,
    'ai_teams_created',v_ai_paired,
    'competitions_allocated',v_allocated,
    'draws_published',v_drawn
  );
end;
$$;
revoke all on function public.process_due_doubles_entry_lifecycle_v1() from public,anon,authenticated;
grant execute on function public.process_due_doubles_entry_lifecycle_v1() to service_role;

