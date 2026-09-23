-- Doubles Ticket 2: user marketplace actions and strongest shared availability validation.

create or replace function public.check_player_competition_availability_v1(p_player_id uuid,p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  t record;
  v_player_world text;
  v_block_comp uuid;
  v_block_name text;
  v_block_city text;
begin
  select * into t from public.get_competition_window_v1(p_competition_id);
  if t.competition_id is null then return jsonb_build_object('available',false,'reason','competition_unavailable'); end if;

  select world into v_player_world
  from public.players
  where id=p_player_id and moderation_status<>'rejected';

  if v_player_world is null then return jsonb_build_object('available',false,'reason','player_unavailable'); end if;
  if v_player_world<>t.world then return jsonb_build_object('available',false,'reason','different_world'); end if;

  v_block_comp:=null;v_block_name:=null;v_block_city:=null;
  select te.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(te.competition_id) w
  where te.player_id=p_player_id
    and te.entry_status='active'
    and te.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,'reason','singles_entry_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  v_block_comp:=null;v_block_name:=null;v_block_city:=null;
  select a.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id=a.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) w
  where a.player_id=p_player_id
    and a.status in ('applied','accepted_main_draw','accepted_qualification')
    and a.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by
    case a.status when 'accepted_main_draw' then 1 when 'accepted_qualification' then 2 else 3 end,
    w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','singles_application_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  v_block_comp:=null;v_block_name:=null;v_block_city:=null;
  select dt.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_doubles_teams dt
  join public.tournament_world_competitions wc on wc.id=dt.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(dt.competition_id) w
  where (dt.player1_id=p_player_id or dt.player2_id=p_player_id)
    and dt.status in ('confirmed','active','alternate')
    and dt.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,'reason','doubles_entry_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  if exists(
    select 1
    from public.player_calendar_commitments c
    where c.player_id=p_player_id
      and c.status='committed'
      and (c.competition_id is null or c.competition_id<>p_competition_id)
      and c.starts_absolute_day<=t.end_absolute_day
      and c.ends_absolute_day>=t.start_absolute_day
  ) then
    return jsonb_build_object('available',false,'reason','calendar_commitment_overlap');
  end if;

  return jsonb_build_object(
    'available',true,
    'reason','available',
    'start_absolute_day',t.start_absolute_day,
    'end_absolute_day',t.end_absolute_day,
    'location_key',t.location_key
  );
end;
$$;

create or replace function public.get_doubles_player_entry_strength_v1(p_player_id uuid,p_competition_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_doubles integer:=0;
  v_singles integer:=0;
  v_weight numeric:=0.350;
begin
  select coalesce(dr.ranking_points,0),coalesce(sr.ranking_points,0)
  into v_doubles,v_singles
  from public.players p
  left join public.player_doubles_rankings dr on dr.player_id=p.id
  left join public.player_rankings sr on sr.player_id=p.id
  where p.id=p_player_id;

  select coalesce(ds.fallback_singles_points_weight,0.350)
  into v_weight
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id;

  if coalesce(v_doubles,0)>0 then
    return v_doubles;
  end if;

  return greatest(0,round(coalesce(v_singles,0)*coalesce(v_weight,0.350))::integer);
end;
$$;

create or replace function public.set_doubles_partner_listing_v1(
  p_competition_id uuid,
  p_looking boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_availability jsonb;
  v_listing public.tournament_doubles_partner_listings%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if v_player is null then raise exception 'A player profile is required.'; end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(p_competition_id);
  if not coalesce((v_timeline->>'enabled')::boolean,false) then
    raise exception 'Doubles is not enabled for this tournament.';
  end if;

  if coalesce(p_looking,false) then
    if v_now<(v_timeline->>'registration_open_game_second')::bigint then
      raise exception 'Doubles registration is not open yet.';
    end if;
    if v_now>=(v_timeline->>'registration_deadline_game_second')::bigint then
      raise exception 'The deadline to enter the partner marketplace has passed.';
    end if;
    if exists(
      select 1
      from public.tournament_doubles_teams t
      where t.competition_id=p_competition_id
        and t.status in ('confirmed','active','alternate')
        and (t.player1_id=v_player or t.player2_id=v_player)
    ) then
      raise exception 'You already have a doubles team for this tournament.';
    end if;

    v_availability:=public.check_player_competition_availability_v1(v_player,p_competition_id);
    if not coalesce((v_availability->>'available')::boolean,false) then
      raise exception 'You cannot enter this doubles marketplace because of a conflicting commitment: %',
        coalesce(v_availability->>'blocking_tournament',v_availability->>'reason','unavailable');
    end if;

    insert into public.tournament_doubles_partner_listings(
      competition_id,player_id,owner_user_id,status,created_at,updated_at,closed_at
    )
    values(p_competition_id,v_player,v_uid,'active',now(),now(),null)
    on conflict(competition_id,player_id) do update
    set owner_user_id=excluded.owner_user_id,
        status='active',
        updated_at=now(),
        closed_at=null
    returning * into v_listing;

    return jsonb_build_object(
      'status','looking',
      'listing_id',v_listing.id,
      'competition_id',p_competition_id,
      'player_id',v_player
    );
  end if;

  select * into v_listing
  from public.tournament_doubles_partner_listings
  where competition_id=p_competition_id
    and player_id=v_player
    and owner_user_id=v_uid
    and status='active'
  for update;

  if v_listing.id is null then
    return jsonb_build_object('status','not_looking');
  end if;

  if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    raise exception 'The doubles partnership deadline has passed.';
  end if;

  update public.tournament_doubles_partner_listings
  set status='cancelled',closed_at=now(),updated_at=now()
  where id=v_listing.id;

  return jsonb_build_object('status','cancelled','listing_id',v_listing.id);
end;
$$;
revoke all on function public.set_doubles_partner_listing_v1(uuid,boolean) from public,anon;
grant execute on function public.set_doubles_partner_listing_v1(uuid,boolean) to authenticated;

create or replace function public.send_doubles_partner_invitation_v1(
  p_competition_id uuid,
  p_invitee_player_id uuid
)
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
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_a jsonb;
  v_b jsonb;
  v_invitation public.tournament_doubles_partner_invitations%rowtype;
  v_tournament text;
  v_city text;
  v_route text;
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
  if not coalesce((v_timeline->>'enabled')::boolean,false) then
    raise exception 'Doubles is not enabled for this tournament.';
  end if;
  if v_now<(v_timeline->>'registration_open_game_second')::bigint then
    raise exception 'Doubles registration is not open yet.';
  end if;
  if v_now>=(v_timeline->>'partnership_deadline_game_second')::bigint then
    raise exception 'The doubles partnership deadline has passed.';
  end if;

  select p.owner_user_id,trim(p.first_name||' '||p.last_name)
  into v_invitee_uid,v_invitee_name
  from public.players p
  join public.tournament_doubles_partner_listings l
    on l.player_id=p.id
   and l.competition_id=p_competition_id
   and l.status='active'
  where p.id=p_invitee_player_id
    and p.owner_user_id is not null;

  if v_invitee_uid is null then
    raise exception 'This player is no longer available in the partner marketplace.';
  end if;

  if exists(
    select 1
    from public.tournament_doubles_teams t
    where t.competition_id=p_competition_id
      and t.status in ('confirmed','active','alternate')
      and (
        t.player1_id in (v_inviter,p_invitee_player_id)
        or t.player2_id in (v_inviter,p_invitee_player_id)
      )
  ) then
    raise exception 'One of these players already has a doubles team for this tournament.';
  end if;

  if exists(
    select 1
    from public.tournament_doubles_partner_invitations i
    where i.competition_id=p_competition_id
      and i.status='pending'
      and i.inviter_player_id=p_invitee_player_id
      and i.invitee_player_id=v_inviter
  ) then
    raise exception 'This player has already invited you. Respond to the incoming invitation instead.';
  end if;

  v_a:=public.check_player_competition_availability_v1(v_inviter,p_competition_id);
  v_b:=public.check_player_competition_availability_v1(p_invitee_player_id,p_competition_id);

  if not coalesce((v_a->>'available')::boolean,false) then
    raise exception 'You have a conflicting tournament or calendar commitment.';
  end if;
  if not coalesce((v_b->>'available')::boolean,false) then
    raise exception 'The selected player now has a conflicting tournament or calendar commitment.';
  end if;

  select * into v_invitation
  from public.tournament_doubles_partner_invitations
  where competition_id=p_competition_id
    and inviter_player_id=v_inviter
    and invitee_player_id=p_invitee_player_id
    and status='pending'
  limit 1;

  if v_invitation.id is null then
    insert into public.tournament_doubles_partner_invitations(
      competition_id,inviter_player_id,invitee_player_id,
      inviter_user_id,invitee_user_id,status,expires_game_second
    )
    values(
      p_competition_id,v_inviter,p_invitee_player_id,
      v_uid,v_invitee_uid,'pending',
      (v_timeline->>'partnership_deadline_game_second')::bigint
    )
    returning * into v_invitation;
  end if;

  select ts.name,ts.city
  into v_tournament,v_city
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=p_competition_id;

  v_route:=format('/game/tournaments/%s/doubles',p_competition_id);

  perform public.emit_notification_v1(
    v_invitee_uid,
    p_invitee_player_id,
    'doubles.partner.invitation',
    'Doubles invitation · '||v_tournament,
    format('%s invited you to play doubles in %s. Respond before the partnership deadline.',v_inviter_name,v_city),
    v_route,
    jsonb_build_object(
      'competition_id',p_competition_id,
      'tournament_name',v_tournament,
      'city',v_city,
      'proposed_partner_id',v_inviter,
      'proposed_partner_name',v_inviter_name,
      'partnership_deadline',v_timeline->'partnership_deadline',
      'tournament_start',v_timeline->'tournament_start',
      'tournament_end',v_timeline->'tournament_end',
      'action_url',v_route
    ),
    format('doubles-invite:%s:created',v_invitation.id)
  );

  return jsonb_build_object(
    'status','pending',
    'invitation_id',v_invitation.id,
    'invitee_player_id',p_invitee_player_id,
    'invitee_name',v_invitee_name,
    'expires_game_second',v_invitation.expires_game_second
  );
end;
$$;
revoke all on function public.send_doubles_partner_invitation_v1(uuid,uuid) from public,anon;
grant execute on function public.send_doubles_partner_invitation_v1(uuid,uuid) to authenticated;

create or replace function public.cancel_doubles_partner_invitation_v1(p_invitation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_inv public.tournament_doubles_partner_invitations%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_inv
  from public.tournament_doubles_partner_invitations
  where id=p_invitation_id
    and inviter_user_id=v_uid
    and status='pending'
  for update;

  if v_inv.id is null then raise exception 'Pending invitation not found.'; end if;

  update public.tournament_doubles_partner_invitations
  set status='cancelled',responded_at=now(),updated_at=now()
  where id=v_inv.id;

  return jsonb_build_object('status','cancelled','invitation_id',v_inv.id);
end;
$$;
revoke all on function public.cancel_doubles_partner_invitation_v1(uuid) from public,anon;
grant execute on function public.cancel_doubles_partner_invitation_v1(uuid) to authenticated;

create or replace function public.respond_doubles_partner_invitation_v1(
  p_invitation_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_inv public.tournament_doubles_partner_invitations%rowtype;
  v_timeline jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_a jsonb;
  v_b jsonb;
  v_team uuid;
  v_tournament text;
  v_city text;
  v_inviter_name text;
  v_invitee_name text;
  v_route text;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_inv
  from public.tournament_doubles_partner_invitations
  where id=p_invitation_id
    and invitee_user_id=v_uid
  for update;

  if v_inv.id is null then raise exception 'Invitation not found.'; end if;
  if v_inv.status<>'pending' then
    return jsonb_build_object('status',v_inv.status,'invitation_id',v_inv.id);
  end if;

  v_timeline:=public.get_tournament_doubles_entry_timeline_v1(v_inv.competition_id);

  select ts.name,ts.city,
         trim(pi.first_name||' '||pi.last_name),
         trim(pe.first_name||' '||pe.last_name)
  into v_tournament,v_city,v_inviter_name,v_invitee_name
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.players pi on pi.id=v_inv.inviter_player_id
  join public.players pe on pe.id=v_inv.invitee_player_id
  where wc.id=v_inv.competition_id;

  v_route:=format('/game/tournaments/%s/doubles',v_inv.competition_id);

  if v_now>=least(
    v_inv.expires_game_second,
    (v_timeline->>'partnership_deadline_game_second')::bigint
  ) then
    update public.tournament_doubles_partner_invitations
    set status='expired',responded_at=now(),updated_at=now()
    where id=v_inv.id;

    perform public.emit_notification_v1(
      v_inv.inviter_user_id,v_inv.inviter_player_id,
      'doubles.invitation.expired',
      'Doubles invitation expired · '||v_tournament,
      format('Your doubles invitation to %s expired at the partnership deadline.',v_invitee_name),
      v_route,
      jsonb_build_object('competition_id',v_inv.competition_id,'tournament_name',v_tournament,'city',v_city,'partner_name',v_invitee_name,'action_url',v_route),
      format('doubles-invite:%s:expired:inviter',v_inv.id)
    );
    perform public.emit_notification_v1(
      v_inv.invitee_user_id,v_inv.invitee_player_id,
      'doubles.invitation.expired',
      'Doubles invitation expired · '||v_tournament,
      format('The doubles invitation from %s expired at the partnership deadline.',v_inviter_name),
      v_route,
      jsonb_build_object('competition_id',v_inv.competition_id,'tournament_name',v_tournament,'city',v_city,'partner_name',v_inviter_name,'action_url',v_route),
      format('doubles-invite:%s:expired:invitee',v_inv.id)
    );

    return jsonb_build_object('status','expired','invitation_id',v_inv.id);
  end if;

  if not coalesce(p_accept,false) then
    update public.tournament_doubles_partner_invitations
    set status='declined',responded_at=now(),updated_at=now()
    where id=v_inv.id;

    perform public.emit_notification_v1(
      v_inv.inviter_user_id,v_inv.inviter_player_id,
      'doubles.invitation.declined',
      'Doubles invitation declined · '||v_tournament,
      format('%s declined your doubles invitation.',v_invitee_name),
      v_route,
      jsonb_build_object('competition_id',v_inv.competition_id,'tournament_name',v_tournament,'city',v_city,'partner_name',v_invitee_name,'action_url',v_route),
      format('doubles-invite:%s:declined',v_inv.id)
    );

    return jsonb_build_object('status','declined','invitation_id',v_inv.id);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    format('doubles-partnership:%s:%s:%s',v_inv.competition_id,least(v_inv.inviter_player_id::text,v_inv.invitee_player_id::text),greatest(v_inv.inviter_player_id::text,v_inv.invitee_player_id::text)),0
  ));

  if exists(
    select 1
    from public.tournament_doubles_teams t
    where t.competition_id=v_inv.competition_id
      and t.status in ('confirmed','active','alternate')
      and (
        t.player1_id in (v_inv.inviter_player_id,v_inv.invitee_player_id)
        or t.player2_id in (v_inv.inviter_player_id,v_inv.invitee_player_id)
      )
  ) then
    raise exception 'One of the players already has a doubles team for this tournament.';
  end if;

  v_a:=public.check_player_competition_availability_v1(v_inv.inviter_player_id,v_inv.competition_id);
  v_b:=public.check_player_competition_availability_v1(v_inv.invitee_player_id,v_inv.competition_id);

  if not coalesce((v_a->>'available')::boolean,false) then
    raise exception 'The proposed partner now has a conflicting tournament or calendar commitment.';
  end if;
  if not coalesce((v_b->>'available')::boolean,false) then
    raise exception 'You now have a conflicting tournament or calendar commitment.';
  end if;

  v_team:=public.create_doubles_team_internal_v1(
    v_inv.competition_id,
    v_inv.inviter_player_id,
    v_inv.invitee_player_id,
    'marketplace_invitation'
  );

  update public.tournament_doubles_partner_invitations
  set status='accepted',responded_at=now(),updated_at=now()
  where id=v_inv.id;

  update public.tournament_doubles_partner_listings
  set status='matched',closed_at=now(),updated_at=now()
  where competition_id=v_inv.competition_id
    and player_id in (v_inv.inviter_player_id,v_inv.invitee_player_id)
    and status='active';

  update public.tournament_doubles_partner_invitations
  set status='cancelled',responded_at=now(),updated_at=now()
  where competition_id=v_inv.competition_id
    and id<>v_inv.id
    and status='pending'
    and (
      inviter_player_id in (v_inv.inviter_player_id,v_inv.invitee_player_id)
      or invitee_player_id in (v_inv.inviter_player_id,v_inv.invitee_player_id)
    );

  perform public.emit_notification_v1(
    v_inv.inviter_user_id,v_inv.inviter_player_id,
    'doubles.invitation.accepted',
    'Doubles invitation accepted · '||v_tournament,
    format('%s accepted your doubles invitation.',v_invitee_name),
    v_route,
    jsonb_build_object('competition_id',v_inv.competition_id,'tournament_name',v_tournament,'city',v_city,'partner_name',v_invitee_name,'team_id',v_team,'action_url',v_route),
    format('doubles-invite:%s:accepted',v_inv.id)
  );

  perform public.emit_notification_v1(
    v_inv.inviter_user_id,v_inv.inviter_player_id,
    'doubles.partnership.confirmed',
    'Doubles partnership confirmed · '||v_tournament,
    format('You and %s are confirmed as a doubles team for this tournament.',v_invitee_name),
    v_route,
    jsonb_build_object('competition_id',v_inv.competition_id,'tournament_name',v_tournament,'city',v_city,'partner_name',v_invitee_name,'team_id',v_team,'action_url',v_route),
    format('doubles-team:%s:confirmed:%s',v_team,v_inv.inviter_player_id)
  );

  perform public.emit_notification_v1(
    v_inv.invitee_user_id,v_inv.invitee_player_id,
    'doubles.partnership.confirmed',
    'Doubles partnership confirmed · '||v_tournament,
    format('You and %s are confirmed as a doubles team for this tournament.',v_inviter_name),
    v_route,
    jsonb_build_object('competition_id',v_inv.competition_id,'tournament_name',v_tournament,'city',v_city,'partner_name',v_inviter_name,'team_id',v_team,'action_url',v_route),
    format('doubles-team:%s:confirmed:%s',v_team,v_inv.invitee_player_id)
  );

  return jsonb_build_object(
    'status','accepted',
    'invitation_id',v_inv.id,
    'team_id',v_team,
    'partner_id',v_inv.inviter_player_id,
    'partner_name',v_inviter_name
  );
end;
$$;
revoke all on function public.respond_doubles_partner_invitation_v1(uuid,boolean) from public,anon;
grant execute on function public.respond_doubles_partner_invitation_v1(uuid,boolean) to authenticated;