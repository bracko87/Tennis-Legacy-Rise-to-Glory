
alter table public.national_team_fixtures
  add column if not exists window_tie_slot smallint;

alter table public.national_team_fixtures
  drop constraint if exists national_team_fixtures_window_tie_slot_check;
alter table public.national_team_fixtures
  add constraint national_team_fixtures_window_tie_slot_check
  check(window_tie_slot is null or window_tie_slot between 1 and 3);

create table if not exists public.national_team_friendly_listings(
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  window_id uuid not null references public.national_team_windows(id) on delete cascade,
  tie_slot smallint not null check(tie_slot between 1 and 2),
  captain_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check(status in ('active','matched','cancelled','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  unique(association_id,window_id,tie_slot)
);

create table if not exists public.national_team_friendly_invitations(
  id uuid primary key default gen_random_uuid(),
  window_id uuid not null references public.national_team_windows(id) on delete cascade,
  tie_slot smallint not null check(tie_slot between 1 and 2),
  inviter_association_id uuid not null references public.national_associations(id) on delete cascade,
  invitee_association_id uuid not null references public.national_associations(id) on delete cascade,
  inviter_user_id uuid not null references auth.users(id) on delete cascade,
  invitee_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled','expired')),
  pairing_deadline_absolute_day integer not null,
  fixture_id uuid references public.national_team_fixtures(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz,
  check(inviter_association_id<>invitee_association_id)
);

create unique index if not exists national_team_friendly_pending_pair_uidx
on public.national_team_friendly_invitations(
  window_id,tie_slot,
  least(inviter_association_id::text,invitee_association_id::text),
  greatest(inviter_association_id::text,invitee_association_id::text)
)
where status='pending';

alter table public.national_team_friendly_listings enable row level security;
alter table public.national_team_friendly_invitations enable row level security;
revoke all on public.national_team_friendly_listings from public,anon,authenticated;
revoke all on public.national_team_friendly_invitations from public,anon,authenticated;

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,
  source_name,title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
)
values
('national.friendly.invitation','national_team','National friendly invitation',
 'Tell a national captain that another association wants to arrange a friendly.',
 'A captain invites another listed association for a national-window friendly.',
 'Both associations are active and the pairing deadline has not passed.',
 'captain_action','public.send_national_team_friendly_invitation_v1',
 'National friendly invitation','Another national association wants to arrange a friendly.',
 '/game/national-team?tab=competition','info',true,false,false,true,true),
('national.friendly.accepted','national_team','National friendly accepted',
 'Confirm that a friendly invitation was accepted.',
 'The invited captain accepts a friendly proposal.',
 'The window slot is still available for both associations.',
 'captain_action','public.respond_national_team_friendly_invitation_v1',
 'National friendly confirmed','Your national-team friendly has been confirmed.',
 '/game/national-team?tab=competition','success',true,false,false,true,true),
('national.friendly.declined','national_team','National friendly declined',
 'Tell the inviting captain that a friendly proposal was declined.',
 'The invited captain declines a friendly proposal.',
 'The invitation was still pending.',
 'captain_action','public.respond_national_team_friendly_invitation_v1',
 'National friendly declined','Your national-team friendly proposal was declined.',
 '/game/national-team?tab=competition','info',true,false,false,true,true)
on conflict(code) do update
set category=excluded.category,label=excluded.label,reason=excluded.reason,
trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,
trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,
title_template=excluded.title_template,message_template=excluded.message_template,
default_route=excluded.default_route,severity=excluded.severity,
default_in_app=excluded.default_in_app,default_email=excluded.default_email,
default_push=excluded.default_push,is_user_configurable=excluded.is_user_configurable,
is_active=excluded.is_active,updated_at=now();

create or replace function public.national_team_captain_for_association_v1(p_association_id uuid)
returns table(user_id uuid,player_id uuid)
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select t.user_id,t.player_id
  from public.national_captain_terms t
  where t.association_id=p_association_id
    and t.status='active'
    and t.term_start_game_day<=public.national_team_current_abs_day_v1()
    and t.term_end_game_day>=public.national_team_current_abs_day_v1()
  order by t.created_at desc
  limit 1;
$$;

create or replace function public.national_team_friendly_pairing_deadline_v1(p_window_id uuid)
returns integer
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select greatest((season_number-1)*366,start_absolute_day-6)
  from public.national_team_windows
  where id=p_window_id;
$$;

create or replace function public.national_team_friendly_slot_available_v1(
  p_association_id uuid,p_window_id uuid,p_tie_slot integer
)
returns boolean
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  w public.national_team_windows%rowtype;
begin
  select * into w from public.national_team_windows where id=p_window_id;
  if not found or not w.allows_friendlies or p_tie_slot not between 1 and 2 then return false; end if;

  if exists(
    select 1 from public.national_team_fixtures f
    where f.window_id=p_window_id
      and f.status<>'cancelled'
      and p_association_id in (f.home_association_id,f.away_association_id)
      and coalesce(
        f.window_tie_slot,
        case
          when f.tie_start_absolute_day<=w.start_absolute_day+2 then 1
          else 2
        end
      )=p_tie_slot
  ) then return false; end if;

  return true;
end;
$$;

create or replace function public.set_national_team_friendly_listing_v1(
  p_window_id uuid,p_tie_slot integer,p_looking boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  v_window public.national_team_windows%rowtype;
  v_deadline integer;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_listing public.national_team_friendly_listings%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if p_tie_slot not between 1 and 2 then raise exception 'Invalid friendly tie slot.'; end if;

  select t.association_id into v_assoc
  from public.national_captain_terms t
  where t.user_id=v_uid and t.status='active'
    and t.term_start_game_day<=v_day and t.term_end_game_day>=v_day
  order by t.created_at desc limit 1;

  if v_assoc is null then raise exception 'Only the active national captain may arrange friendlies.'; end if;

  select * into v_window from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;
  if not v_window.allows_friendlies then raise exception 'This national window does not allow friendlies.'; end if;

  v_deadline:=public.national_team_friendly_pairing_deadline_v1(p_window_id);

  if coalesce(p_looking,false) then
    if v_day>v_deadline then raise exception 'The friendly pairing deadline has passed.'; end if;
    if not public.national_team_friendly_slot_available_v1(v_assoc,p_window_id,p_tie_slot) then
      raise exception 'Your national team already has a tie in this slot.';
    end if;

    insert into public.national_team_friendly_listings(
      association_id,window_id,tie_slot,captain_user_id,status,created_at,updated_at,closed_at
    )
    values(v_assoc,p_window_id,p_tie_slot,v_uid,'active',now(),now(),null)
    on conflict(association_id,window_id,tie_slot) do update
    set captain_user_id=excluded.captain_user_id,status='active',updated_at=now(),closed_at=null
    returning * into v_listing;

    return jsonb_build_object('status','looking','listing_id',v_listing.id);
  end if;

  update public.national_team_friendly_listings
  set status='cancelled',closed_at=now(),updated_at=now()
  where association_id=v_assoc and window_id=p_window_id and tie_slot=p_tie_slot and status='active'
  returning * into v_listing;

  return jsonb_build_object('status',case when v_listing.id is null then 'not_looking' else 'cancelled' end);
end;
$$;

create or replace function public.send_national_team_friendly_invitation_v1(
  p_window_id uuid,p_tie_slot integer,p_invitee_association_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_inviter uuid;
  v_inviter_name text;
  v_invitee_name text;
  v_invitee_uid uuid;
  v_invitee_player uuid;
  v_window public.national_team_windows%rowtype;
  v_deadline integer;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_inv public.national_team_friendly_invitations%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select t.association_id into v_inviter
  from public.national_captain_terms t
  where t.user_id=v_uid and t.status='active'
    and t.term_start_game_day<=v_day and t.term_end_game_day>=v_day
  order by t.created_at desc limit 1;

  if v_inviter is null then raise exception 'Only the active national captain may arrange friendlies.'; end if;
  if v_inviter=p_invitee_association_id then raise exception 'You cannot invite your own association.'; end if;

  select * into v_window from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;

  v_deadline:=public.national_team_friendly_pairing_deadline_v1(p_window_id);
  if v_day>v_deadline then raise exception 'The friendly pairing deadline has passed.'; end if;

  if not public.national_team_friendly_slot_available_v1(v_inviter,p_window_id,p_tie_slot) then
    raise exception 'Your national team already has a tie in this slot.';
  end if;
  if not public.national_team_friendly_slot_available_v1(p_invitee_association_id,p_window_id,p_tie_slot) then
    raise exception 'That national team already has a tie in this slot.';
  end if;

  if not exists(
    select 1 from public.national_team_friendly_listings l
    join public.national_associations a on a.id=l.association_id
    where l.association_id=p_invitee_association_id
      and l.window_id=p_window_id
      and l.tie_slot=p_tie_slot
      and l.status='active'
      and a.world=v_window.world
      and a.status in ('active','renewal_required')
  ) then
    raise exception 'That association is no longer looking for a friendly in this slot.';
  end if;

  select a.name into v_inviter_name from public.national_associations a where a.id=v_inviter;
  select a.name into v_invitee_name from public.national_associations a where a.id=p_invitee_association_id;
  select c.user_id,c.player_id into v_invitee_uid,v_invitee_player
  from public.national_team_captain_for_association_v1(p_invitee_association_id) c;

  if v_invitee_uid is null then raise exception 'That association does not currently have an active captain.'; end if;

  insert into public.national_team_friendly_invitations(
    window_id,tie_slot,inviter_association_id,invitee_association_id,
    inviter_user_id,invitee_user_id,status,pairing_deadline_absolute_day
  )
  values(
    p_window_id,p_tie_slot,v_inviter,p_invitee_association_id,
    v_uid,v_invitee_uid,'pending',v_deadline
  )
  returning * into v_inv;

  perform public.emit_notification_v1(
    v_invitee_uid,v_invitee_player,'national.friendly.invitation',
    'National friendly invitation · '||v_inviter_name,
    format('%s invited %s to play a friendly during %s, tie slot %s. Respond by %s.',
      v_inviter_name,v_invitee_name,v_window.label,p_tie_slot,v_deadline),
    '/game/national-team?tab=competition',
    jsonb_build_object(
      'invitation_id',v_inv.id,'window_id',p_window_id,'tie_slot',p_tie_slot,
      'inviter_association_id',v_inviter,'inviter_association_name',v_inviter_name,
      'pairing_deadline_absolute_day',v_deadline,
      'action_url','/game/national-team?tab=competition'
    ),
    format('national-friendly-invite:%s:created',v_inv.id)
  );

  return jsonb_build_object('status','pending','invitation_id',v_inv.id);
end;
$$;

create or replace function public.respond_national_team_friendly_invitation_v1(
  p_invitation_id uuid,p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_inv public.national_team_friendly_invitations%rowtype;
  v_window public.national_team_windows%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_inviter_player uuid;
  v_inviter_name text;
  v_invitee_name text;
  v_country text;
  v_city text;
  v_lat double precision;
  v_lon double precision;
  v_fixture uuid;
  v_tie_start integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_inv
  from public.national_team_friendly_invitations
  where id=p_invitation_id and invitee_user_id=v_uid
  for update;

  if not found then raise exception 'Friendly invitation not found.'; end if;
  if v_inv.status<>'pending' then return jsonb_build_object('status',v_inv.status,'invitation_id',v_inv.id); end if;

  select * into v_window from public.national_team_windows where id=v_inv.window_id;

  if v_day>v_inv.pairing_deadline_absolute_day then
    update public.national_team_friendly_invitations
    set status='expired',responded_at=now(),updated_at=now()
    where id=v_inv.id;
    return jsonb_build_object('status','expired','invitation_id',v_inv.id);
  end if;

  select a.name into v_inviter_name from public.national_associations a where a.id=v_inv.inviter_association_id;
  select a.name into v_invitee_name from public.national_associations a where a.id=v_inv.invitee_association_id;
  select c.player_id into v_inviter_player
  from public.national_team_captain_for_association_v1(v_inv.inviter_association_id) c;

  if not coalesce(p_accept,false) then
    update public.national_team_friendly_invitations
    set status='declined',responded_at=now(),updated_at=now()
    where id=v_inv.id;

    perform public.emit_notification_v1(
      v_inv.inviter_user_id,v_inviter_player,'national.friendly.declined',
      'National friendly declined · '||v_invitee_name,
      format('%s declined your friendly proposal for %s.',v_invitee_name,v_window.label),
      '/game/national-team?tab=competition',
      jsonb_build_object('invitation_id',v_inv.id,'window_id',v_inv.window_id,'action_url','/game/national-team?tab=competition'),
      format('national-friendly-invite:%s:declined',v_inv.id)
    );

    return jsonb_build_object('status','declined','invitation_id',v_inv.id);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    format('national-friendly:%s:%s:%s',v_inv.window_id,v_inv.tie_slot,
      least(v_inv.inviter_association_id::text,v_inv.invitee_association_id::text)),0
  ));

  if not public.national_team_friendly_slot_available_v1(v_inv.inviter_association_id,v_inv.window_id,v_inv.tie_slot)
     or not public.national_team_friendly_slot_available_v1(v_inv.invitee_association_id,v_inv.window_id,v_inv.tie_slot) then
    raise exception 'One of the national teams now has another tie in this slot.';
  end if;

  select country_code into v_country
  from public.national_associations where id=v_inv.inviter_association_id;

  select h.city,h.latitude,h.longitude
  into v_city,v_lat,v_lon
  from public.player_home_city_options h
  where h.country_code=v_country and h.is_active
  order by h.sort_order,h.city limit 1;

  if v_city is null then
    select l.city,l.latitude,l.longitude
    into v_city,v_lat,v_lon
    from public.travel_locations l
    where l.country_code=v_country and l.is_active
    order by l.city limit 1;
  end if;

  if v_city is null then select name into v_city from public.countries where code=v_country; end if;

  v_tie_start:=case when v_inv.tie_slot=1 then v_window.start_absolute_day+1 else v_window.start_absolute_day+4 end;

  v_fixture:=public.create_national_team_fixture_v1(
    v_inv.window_id,
    v_inv.inviter_association_id,
    v_inv.invitee_association_id,
    null,
    v_inv.inviter_association_id,
    null,
    v_city,v_country,v_lat,v_lon,
    'hard','indoor',
    v_tie_start,
    'five_match_standard'
  );

  update public.national_team_fixtures
  set fixture_kind='friendly',window_tie_slot=v_inv.tie_slot,updated_at=now()
  where id=v_fixture;

  update public.national_team_friendly_invitations
  set status='accepted',fixture_id=v_fixture,responded_at=now(),updated_at=now()
  where id=v_inv.id;

  update public.national_team_friendly_listings
  set status='matched',closed_at=now(),updated_at=now()
  where window_id=v_inv.window_id
    and tie_slot=v_inv.tie_slot
    and association_id in (v_inv.inviter_association_id,v_inv.invitee_association_id)
    and status='active';

  update public.national_team_friendly_invitations
  set status='cancelled',responded_at=now(),updated_at=now()
  where window_id=v_inv.window_id
    and tie_slot=v_inv.tie_slot
    and id<>v_inv.id
    and status='pending'
    and (
      inviter_association_id in (v_inv.inviter_association_id,v_inv.invitee_association_id)
      or invitee_association_id in (v_inv.inviter_association_id,v_inv.invitee_association_id)
    );

  perform public.emit_notification_v1(
    v_inv.inviter_user_id,v_inviter_player,'national.friendly.accepted',
    'National friendly confirmed · '||v_invitee_name,
    format('%s accepted your friendly proposal for %s.',v_invitee_name,v_window.label),
    '/game/national-team?tab=competition',
    jsonb_build_object('invitation_id',v_inv.id,'fixture_id',v_fixture,'window_id',v_inv.window_id,'tie_slot',v_inv.tie_slot,'action_url','/game/national-team?tab=competition'),
    format('national-friendly-invite:%s:accepted',v_inv.id)
  );

  return jsonb_build_object('status','accepted','fixture_id',v_fixture,'invitation_id',v_inv.id);
end;
$$;

create or replace function public.get_my_national_team_friendlies_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  v_world text;
  v_is_captain boolean:=false;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_data jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select m.association_id,a.world
  into v_assoc,v_world
  from public.national_association_memberships m
  join public.national_associations a on a.id=m.association_id
  where m.user_id=v_uid and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_assoc is null then return jsonb_build_object('available',false); end if;

  v_is_captain:=exists(
    select 1 from public.national_captain_terms t
    where t.association_id=v_assoc and t.user_id=v_uid and t.status='active'
      and t.term_start_game_day<=v_day and t.term_end_game_day>=v_day
  );

  with windows as (
    select w.*
    from public.national_team_windows w
    where w.world=v_world
      and w.allows_friendlies
      and w.end_absolute_day>=v_day
    order by w.season_number,w.start_absolute_day
    limit 8
  )
  select jsonb_build_object(
    'available',true,
    'association_id',v_assoc,
    'is_captain',v_is_captain,
    'windows',coalesce(jsonb_agg(
      jsonb_build_object(
        'window_id',w.id,
        'label',w.label,
        'season_number',w.season_number,
        'season_week',w.season_week,
        'start_absolute_day',w.start_absolute_day,
        'end_absolute_day',w.end_absolute_day,
        'pairing_deadline_absolute_day',public.national_team_friendly_pairing_deadline_v1(w.id),
        'tie_slots',jsonb_build_array(
          jsonb_build_object(
            'slot',1,
            'label','Tie slot 1 · Tue–Wed',
            'available',public.national_team_friendly_slot_available_v1(v_assoc,w.id,1),
            'my_listing',(
              select jsonb_build_object('id',l.id,'status',l.status)
              from public.national_team_friendly_listings l
              where l.association_id=v_assoc and l.window_id=w.id and l.tie_slot=1
              order by l.updated_at desc limit 1
            ),
            'market',coalesce((
              select jsonb_agg(jsonb_build_object(
                'listing_id',l.id,'association_id',a.id,'association_name',a.name,'country_code',a.country_code
              ) order by a.name)
              from public.national_team_friendly_listings l
              join public.national_associations a on a.id=l.association_id
              where l.window_id=w.id and l.tie_slot=1 and l.status='active'
                and l.association_id<>v_assoc and a.status in ('active','renewal_required')
            ),'[]'::jsonb)
          ),
          jsonb_build_object(
            'slot',2,
            'label','Tie slot 2 · Fri–Sat',
            'available',public.national_team_friendly_slot_available_v1(v_assoc,w.id,2),
            'my_listing',(
              select jsonb_build_object('id',l.id,'status',l.status)
              from public.national_team_friendly_listings l
              where l.association_id=v_assoc and l.window_id=w.id and l.tie_slot=2
              order by l.updated_at desc limit 1
            ),
            'market',coalesce((
              select jsonb_agg(jsonb_build_object(
                'listing_id',l.id,'association_id',a.id,'association_name',a.name,'country_code',a.country_code
              ) order by a.name)
              from public.national_team_friendly_listings l
              join public.national_associations a on a.id=l.association_id
              where l.window_id=w.id and l.tie_slot=2 and l.status='active'
                and l.association_id<>v_assoc and a.status in ('active','renewal_required')
            ),'[]'::jsonb)
          )
        ),
        'incoming_invitations',coalesce((
          select jsonb_agg(jsonb_build_object(
            'id',i.id,'tie_slot',i.tie_slot,'status',i.status,
            'inviter_association_id',a.id,'inviter_association_name',a.name,'country_code',a.country_code,
            'pairing_deadline_absolute_day',i.pairing_deadline_absolute_day
          ) order by i.created_at desc)
          from public.national_team_friendly_invitations i
          join public.national_associations a on a.id=i.inviter_association_id
          where i.window_id=w.id and i.invitee_association_id=v_assoc and i.status='pending'
        ),'[]'::jsonb),
        'outgoing_invitations',coalesce((
          select jsonb_agg(jsonb_build_object(
            'id',i.id,'tie_slot',i.tie_slot,'status',i.status,
            'invitee_association_id',a.id,'invitee_association_name',a.name,'country_code',a.country_code,
            'pairing_deadline_absolute_day',i.pairing_deadline_absolute_day
          ) order by i.created_at desc)
          from public.national_team_friendly_invitations i
          join public.national_associations a on a.id=i.invitee_association_id
          where i.window_id=w.id and i.inviter_association_id=v_assoc and i.status='pending'
        ),'[]'::jsonb)
      )
    ),'[]'::jsonb)
  )
  into v_data
  from windows w;

  return coalesce(v_data,jsonb_build_object('available',true,'association_id',v_assoc,'is_captain',v_is_captain,'windows','[]'::jsonb));
end;
$$;

-- Season 1 friendlies are now captain-arranged through the marketplace, not auto-paired.
create or replace function public.schedule_national_window_pairings_v1(p_window_id uuid)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  w public.national_team_windows%rowtype;
  cfg public.national_team_competition_config%rowtype;
  d record;
  team record;
  pending uuid:=null;
  v_count integer:=0;
  v_country text;
  v_city text;
  v_lat double precision;
  v_lon double precision;
  v_fixture uuid;
begin
  select * into w from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;
  select * into cfg from public.national_team_competition_config where id=1;

  if w.season_number<cfg.official_launch_season or w.window_mode='friendly_only' then
    return 0;
  end if;

  for d in
    select id,region_code,tier_level
    from public.national_team_divisions
    where world=w.world
      and is_active
      and (
        (w.window_number=1 and region_code='GLOBAL' and tier_level between 3 and 5)
        or (w.window_number=2 and region_code<>'GLOBAL')
        or (w.window_number=3 and region_code='GLOBAL' and tier_level between 2 and 5)
        or (w.window_number=4 and region_code='GLOBAL' and tier_level=1)
      )
    order by tier_level,sort_order,division_code
  loop
    pending:=null;

    for team in
      select e.association_id
      from public.national_team_division_entries e
      join public.national_associations a on a.id=e.association_id
      where e.division_id=d.id and e.season_number=w.season_number
        and e.status='active' and a.status in ('active','renewal_required')
      order by a.country_code
    loop
      if pending is null then
        pending:=team.association_id;
      else
        if not exists(
          select 1 from public.national_team_fixtures f
          where f.window_id=w.id and f.status<>'cancelled'
            and (
              (f.home_association_id=pending and f.away_association_id=team.association_id)
              or (f.home_association_id=team.association_id and f.away_association_id=pending)
            )
        ) then
          select country_code into v_country from public.national_associations where id=pending;

          select h.city,h.latitude,h.longitude into v_city,v_lat,v_lon
          from public.player_home_city_options h
          where h.country_code=v_country and h.is_active
          order by h.sort_order,h.city limit 1;

          if v_city is null then
            select l.city,l.latitude,l.longitude into v_city,v_lat,v_lon
            from public.travel_locations l
            where l.country_code=v_country and l.is_active order by l.city limit 1;
          end if;
          if v_city is null then select name into v_city from public.countries where code=v_country; end if;

          v_fixture:=public.create_national_team_fixture_v1(
            w.id,pending,team.association_id,d.id,pending,null,
            v_city,v_country,v_lat,v_lon,'hard','indoor',
            w.start_absolute_day+1,'five_match_standard'
          );

          update public.national_team_fixtures
          set fixture_kind='official',window_tie_slot=1,updated_at=now()
          where id=v_fixture;

          v_count:=v_count+1;
        end if;
        pending:=null;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

-- Fix projected entry in competition context to use the bootstrap helper.
create or replace function public.get_my_national_team_competition_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  base jsonb;
  cfg public.national_team_competition_config%rowtype;
  v_world text;
  v_season integer;
  v_display_season integer;
  v_windows jsonb;
  v_pyramid jsonb;
  v_assoc uuid;
  v_projected_entry jsonb;
  v_division uuid;
begin
  base:=public.get_my_national_team_competition_v1();
  if not coalesce((base->>'available')::boolean,false) then return base; end if;

  select * into cfg from public.national_team_competition_config where id=1;
  v_world:=base->>'world';
  v_season:=(base->>'season_number')::integer;
  v_assoc:=(base->>'association_id')::uuid;
  v_display_season:=greatest(v_season,cfg.official_launch_season);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',w.id,'season_number',w.season_number,'window_code',w.window_code,'label',w.label,
      'season_week',w.season_week,'start_absolute_day',w.start_absolute_day,'end_absolute_day',w.end_absolute_day,
      'announcement_absolute_day',w.announcement_absolute_day,'callup_deadline_absolute_day',w.callup_deadline_absolute_day,
      'squad_deadline_absolute_day',w.squad_deadline_absolute_day,'status',w.status,
      'window_number',w.window_number,'window_mode',w.window_mode,'competition_phase',w.competition_phase,
      'official_from_season',w.official_from_season,'allows_friendlies',w.allows_friendlies
    ) order by w.season_number,w.start_absolute_day
  ),'[]'::jsonb)
  into v_windows
  from public.national_team_windows w
  where w.world=v_world and w.season_number in (v_season,v_season+1) and w.status<>'cancelled';

  v_pyramid:=public.get_national_team_pyramid_v1(v_world,v_display_season);

  select e.division_id into v_division
  from public.national_team_division_entries e
  where e.association_id=v_assoc and e.season_number=v_display_season
    and e.status in ('active','completed')
  order by e.created_at desc limit 1;

  if v_division is null then
    v_division:=public.national_team_bootstrap_division_v1(v_assoc,v_display_season);
  end if;

  select jsonb_build_object(
    'division_id',d.id,'division_code',d.division_code,'label',d.label,
    'region_code',d.region_code,'tier_level',d.tier_level,'season_number',v_display_season,
    'placement_state',case when exists(
      select 1 from public.national_team_division_entries e
      where e.association_id=v_assoc and e.season_number=v_display_season and e.division_id=d.id
    ) then 'official' else 'projected' end
  )
  into v_projected_entry
  from public.national_team_divisions d
  where d.id=v_division;

  return base || jsonb_build_object(
    'windows',v_windows,'official_launch_season',cfg.official_launch_season,
    'season_mode',case when v_season<cfg.official_launch_season then 'association_building' else 'official' end,
    'competition_label',case when v_world='WTA' then 'Women''s National Team Championship' else 'Men''s National Team Championship' end,
    'pyramid_display_season',v_display_season,'pyramid',v_pyramid,
    'projected_entry',coalesce(v_projected_entry,'{}'::jsonb),
    'season_notice',case
      when v_season<cfg.official_launch_season then
        'Season 1 is an association-building season. There are no official standings, promotions or relegations yet. National windows are reserved for captain-arranged friendly ties. Official competition begins in Season 2.'
      else
        'Official national-team competition is active. Results feed division standings, promotion and relegation.'
    end
  );
end;
$$;

revoke all on function public.national_team_captain_for_association_v1(uuid) from public,anon,authenticated;
revoke all on function public.national_team_friendly_pairing_deadline_v1(uuid) from public,anon,authenticated;
revoke all on function public.national_team_friendly_slot_available_v1(uuid,uuid,integer) from public,anon,authenticated;
revoke all on function public.set_national_team_friendly_listing_v1(uuid,integer,boolean) from public,anon,authenticated;
revoke all on function public.send_national_team_friendly_invitation_v1(uuid,integer,uuid) from public,anon,authenticated;
revoke all on function public.respond_national_team_friendly_invitation_v1(uuid,boolean) from public,anon,authenticated;
revoke all on function public.get_my_national_team_friendlies_v1() from public,anon,authenticated;

grant execute on function public.set_national_team_friendly_listing_v1(uuid,integer,boolean) to authenticated;
grant execute on function public.send_national_team_friendly_invitation_v1(uuid,integer,uuid) to authenticated;
grant execute on function public.respond_national_team_friendly_invitation_v1(uuid,boolean) to authenticated;
grant execute on function public.get_my_national_team_friendlies_v1() to authenticated;
