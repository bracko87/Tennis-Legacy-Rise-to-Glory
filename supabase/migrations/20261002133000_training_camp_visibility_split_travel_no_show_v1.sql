-- Training Camp visibility + home-routed split travel transitions + travel no-show matches.
-- 2026-10-02
--
-- Rules:
-- * A booked/active camp is visible from Regular Training as well as Training Camps.
-- * Tournament -> Camp and Camp -> Tournament transitions route through the player's home city.
-- * If only one transition day exists, both journeys share that day (first half / second half).
-- * If a previous tournament consumes the normal pre-camp travel day, the first camp day
--   becomes the split travel day and the camp loses one training day.
-- * If a next tournament's first match is on the split travel day, the player is not at the
--   venue in time and misses that match by travel no-show.
-- * Transition integrity is monitored in System Health / Control Center.

alter table public.player_training_camp_bookings
  add column if not exists shortened_days smallint not null default 0;

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.player_training_camp_bookings'::regclass
      and conname='player_training_camp_bookings_shortened_days_check'
  ) then
    alter table public.player_training_camp_bookings
      add constraint player_training_camp_bookings_shortened_days_check
      check(shortened_days between 0 and 28);
  end if;
end;
$$;

alter table public.player_travel_legs
  add column if not exists split_day_transition boolean not null default false,
  add column if not exists split_day_sequence smallint,
  add column if not exists transition_group_id uuid;

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conrelid='public.player_travel_legs'::regclass
      and conname='player_travel_legs_split_sequence_check'
  ) then
    alter table public.player_travel_legs
      add constraint player_travel_legs_split_sequence_check
      check(
        (split_day_transition=false and split_day_sequence is null and transition_group_id is null)
        or
        (split_day_transition=true and split_day_sequence in (1,2) and transition_group_id is not null)
      );
  end if;
end;
$$;

create index if not exists player_travel_legs_split_transition_idx
on public.player_travel_legs(player_id,departure_absolute_day,transition_group_id)
where split_day_transition=true;

-- ---------------------------------------------------------------------------
-- Notification for travel-caused missed matches.
-- ---------------------------------------------------------------------------

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,
  source_name,title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
)
values(
  'tournament.match.travel_no_show',
  'tournament',
  'Match missed because of travel',
  'Tell the player that the travel itinerary made them unavailable at match time.',
  'Scheduled tournament match reached while player is not yet ready at the venue',
  'Travel readiness is impossible at scheduled match time.',
  'Match preparation engine',
  'tournament_matches',
  'Match missed — travel conflict',
  'You missed this match because your travel itinerary did not get you to the tournament venue before the scheduled start.',
  '/game/calendar?tab=tournament-calendar',
  'warning',
  true,false,true,true,true
)
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  severity=excluded.severity,
  default_in_app=true,
  default_push=true,
  is_user_configurable=true,
  is_active=true,
  updated_at=now();

-- Allow travel no-show as an explicit non-played match completion reason.
alter table public.tournament_matches
  drop constraint if exists tournament_matches_completion_reason_check;

alter table public.tournament_matches
  add constraint tournament_matches_completion_reason_check
  check(
    completion_reason is null
    or completion_reason in ('health_walkover','health_surrender','travel_no_show')
  );

-- ---------------------------------------------------------------------------
-- Build home-routed camp transitions.
-- ---------------------------------------------------------------------------

create or replace function public.apply_training_camp_split_travel_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_player public.players%rowtype;
  v_current integer;
  v_home jsonb;
  v_home_lat double precision;
  v_home_lon double precision;
  b record;
  l record;
  v_prev_end integer;
  v_next_start integer;
  v_gap integer;
  v_day1 integer;
  v_day2 integer;
  v_split_day integer;
  v_shortened smallint;
  v_leg1 uuid;
  v_leg2 uuid;
  v_group uuid;
  gd record;
  v_inbound_split integer:=0;
  v_outbound_split integer:=0;
  v_home_routes integer:=0;
begin
  select * into v_player
  from public.players
  where id=p_player_id;

  if v_player.id is null then
    raise exception 'Player not found.';
  end if;

  select public.game_day_absolute_v1(season,month,day)
  into v_current
  from public.get_current_game_day_internal_v1();

  v_home:=public.resolve_location_coordinates_v1(
    v_player.home_city,v_player.country_code,null,null
  );
  v_home_lat:=nullif(v_home->>'latitude','')::double precision;
  v_home_lon:=nullif(v_home->>'longitude','')::double precision;

  for b in
    select
      x.*,
      p.name as program_name,
      loc.city as camp_city,
      loc.country_code as camp_country,
      loc.latitude as camp_latitude,
      loc.longitude as camp_longitude
    from public.player_training_camp_bookings x
    join public.training_camp_programs p on p.id=x.program_id
    join public.training_camp_locations loc on loc.id=p.location_id
    where x.player_id=p_player_id
      and x.status in ('booked','active')
      and x.end_absolute_day>=v_current
    order by x.start_absolute_day
  loop
    v_shortened:=0;

    -- Restore unprocessed camp-owned days before calculating transition overrides.
    for gd in
      select d.*
      from generate_series(greatest(v_current,b.start_absolute_day),b.end_absolute_day) g(abs_day)
      cross join lateral public.absolute_game_day_v1(g.abs_day) d
    loop
      insert into public.player_daily_activity(
        player_id,season,month,day,activity_type,source,reference_id,note
      )
      values(
        p_player_id,gd.season,gd.month,gd.day,
        'training_camp','training_camp_booking',b.id::text,b.program_name
      )
      on conflict(player_id,season,month,day) do update set
        activity_type='training_camp',
        source='training_camp_booking',
        reference_id=b.id::text,
        note=b.program_name,
        updated_at=now()
      where public.player_daily_activity.effects_applied_at is null
        and (
          public.player_daily_activity.activity_type='home'
          or public.player_daily_activity.source in ('travel_plan','training_camp_booking')
        );
    end loop;

    -- Previous tournament -> home -> camp.
    select pl.* into l
    from public.player_travel_legs pl
    where pl.player_id=p_player_id
      and pl.status='planned'
      and pl.source_location_type='tournament'
      and pl.destination_location_type='training_camp'
      and pl.destination_reference_id=b.id::text
    order by pl.departure_absolute_day,pl.created_at
    limit 1;

    if l.id is not null then
      select c.end_absolute_day into v_prev_end
      from public.player_commitment_locations_v1(p_player_id) c
      where c.commitment_type='tournament'
        and c.reference_id=l.source_reference_id
      order by c.end_absolute_day desc
      limit 1;

      v_prev_end:=coalesce(v_prev_end,l.departure_absolute_day);

      update public.player_daily_activity
      set activity_type='home',source=null,reference_id=null,note=null,updated_at=now()
      where player_id=p_player_id
        and source='travel_plan'
        and reference_id=l.id::text
        and effects_applied_at is null;

      delete from public.player_travel_legs where id=l.id;

      v_gap:=b.start_absolute_day-v_prev_end-1;

      if v_gap>=2 then
        v_day1:=v_prev_end+1;
        v_day2:=b.start_absolute_day-1;

        v_leg1:=public.insert_planned_travel_leg_v1(
          p_player_id,'return_home',
          'tournament',l.source_city,l.source_country_code,l.source_latitude,l.source_longitude,l.source_reference_id,
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          v_day1,v_day1,false
        );
        v_leg2:=public.insert_planned_travel_leg_v1(
          p_player_id,'training_camp',
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          'training_camp',b.camp_city,b.camp_country,b.camp_latitude,b.camp_longitude,b.id::text,
          v_day2,v_day2,false
        );
        v_home_routes:=v_home_routes+1;
      else
        -- One free day => split that day. No free day => use camp day one,
        -- which deliberately shortens the camp by one training day.
        v_split_day:=case when v_gap=1 then b.start_absolute_day-1 else b.start_absolute_day end;
        v_group:=gen_random_uuid();

        v_leg1:=public.insert_planned_travel_leg_v1(
          p_player_id,'return_home',
          'tournament',l.source_city,l.source_country_code,l.source_latitude,l.source_longitude,l.source_reference_id,
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          v_split_day,v_split_day,true
        );
        v_leg2:=public.insert_planned_travel_leg_v1(
          p_player_id,'training_camp',
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          'training_camp',b.camp_city,b.camp_country,b.camp_latitude,b.camp_longitude,b.id::text,
          v_split_day,v_split_day,true
        );

        update public.player_travel_legs
        set split_day_transition=true,
            split_day_sequence=1,
            transition_group_id=v_group,
            departure_minute_of_day=0,
            arrival_minute_of_day=720,
            estimated_travel_minutes=720,
            connection_status='tight',
            embedded_transition=true,
            updated_at=now()
        where id=v_leg1;

        update public.player_travel_legs
        set split_day_transition=true,
            split_day_sequence=2,
            transition_group_id=v_group,
            departure_minute_of_day=720,
            arrival_minute_of_day=1439,
            estimated_travel_minutes=719,
            connection_status='tight',
            embedded_transition=true,
            updated_at=now()
        where id=v_leg2;

        select * into gd from public.absolute_game_day_v1(v_split_day);
        insert into public.player_daily_activity(
          player_id,season,month,day,activity_type,source,reference_id,note
        )
        values(
          p_player_id,gd.season,gd.month,gd.day,
          'travel','training_camp_booking',b.id::text,
          format(
            'Split travel via home: %s → %s → %s',
            coalesce(l.source_city,l.source_country_code),
            coalesce(v_player.home_city,v_player.country_code),
            coalesce(b.camp_city,b.camp_country)
          )
        )
        on conflict(player_id,season,month,day) do update set
          activity_type='travel',
          source='training_camp_booking',
          reference_id=b.id::text,
          note=excluded.note,
          updated_at=now()
        where public.player_daily_activity.effects_applied_at is null
          and (
            public.player_daily_activity.activity_type='home'
            or public.player_daily_activity.source in ('travel_plan','training_camp_booking')
          );

        if v_split_day between b.start_absolute_day and b.end_absolute_day then
          v_shortened:=1;
        end if;
        v_inbound_split:=v_inbound_split+1;
      end if;
    end if;

    -- Camp -> home -> next tournament.
    select pl.* into l
    from public.player_travel_legs pl
    where pl.player_id=p_player_id
      and pl.status='planned'
      and pl.source_location_type='training_camp'
      and pl.source_reference_id=b.id::text
      and pl.destination_location_type='tournament'
      and pl.destination_reference_id is not null
    order by pl.departure_absolute_day,pl.created_at
    limit 1;

    if l.id is not null then
      select c.start_absolute_day into v_next_start
      from public.player_commitment_locations_v1(p_player_id) c
      where c.commitment_type='tournament'
        and c.reference_id=l.destination_reference_id
      order by c.start_absolute_day
      limit 1;

      v_next_start:=coalesce(v_next_start,l.arrival_absolute_day);

      update public.player_daily_activity
      set activity_type='home',source=null,reference_id=null,note=null,updated_at=now()
      where player_id=p_player_id
        and source='travel_plan'
        and reference_id=l.id::text
        and effects_applied_at is null;

      delete from public.player_travel_legs where id=l.id;

      v_gap:=v_next_start-b.end_absolute_day-1;

      if v_gap>=2 then
        v_day1:=b.end_absolute_day+1;
        v_day2:=v_next_start-1;

        v_leg1:=public.insert_planned_travel_leg_v1(
          p_player_id,'return_home',
          'training_camp',b.camp_city,b.camp_country,b.camp_latitude,b.camp_longitude,b.id::text,
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          v_day1,v_day1,false
        );
        v_leg2:=public.insert_planned_travel_leg_v1(
          p_player_id,'tournament',
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          'tournament',l.destination_city,l.destination_country_code,l.destination_latitude,l.destination_longitude,l.destination_reference_id,
          v_day2,v_day2,false
        );
        v_home_routes:=v_home_routes+1;
      else
        -- With one or zero free days, both legs share the day immediately
        -- after camp. If the first match is that same day, readiness becomes
        -- impossible and the match engine resolves a travel no-show.
        v_split_day:=b.end_absolute_day+1;
        v_group:=gen_random_uuid();

        v_leg1:=public.insert_planned_travel_leg_v1(
          p_player_id,'return_home',
          'training_camp',b.camp_city,b.camp_country,b.camp_latitude,b.camp_longitude,b.id::text,
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          v_split_day,v_split_day,true
        );
        v_leg2:=public.insert_planned_travel_leg_v1(
          p_player_id,'tournament',
          'home',v_player.home_city,v_player.country_code,v_home_lat,v_home_lon,null,
          'tournament',l.destination_city,l.destination_country_code,l.destination_latitude,l.destination_longitude,l.destination_reference_id,
          v_split_day,v_split_day,true
        );

        update public.player_travel_legs
        set split_day_transition=true,
            split_day_sequence=1,
            transition_group_id=v_group,
            departure_minute_of_day=0,
            arrival_minute_of_day=720,
            estimated_travel_minutes=720,
            connection_status='tight',
            embedded_transition=true,
            updated_at=now()
        where id=v_leg1;

        update public.player_travel_legs
        set split_day_transition=true,
            split_day_sequence=2,
            transition_group_id=v_group,
            departure_minute_of_day=720,
            arrival_minute_of_day=1439,
            estimated_travel_minutes=719,
            connection_status='tight',
            embedded_transition=true,
            updated_at=now()
        where id=v_leg2;

        select * into gd from public.absolute_game_day_v1(v_split_day);
        insert into public.player_daily_activity(
          player_id,season,month,day,activity_type,source,reference_id,note
        )
        values(
          p_player_id,gd.season,gd.month,gd.day,
          'travel','travel_plan',v_leg2::text,
          format(
            'Split travel via home: %s → %s → %s',
            coalesce(b.camp_city,b.camp_country),
            coalesce(v_player.home_city,v_player.country_code),
            coalesce(l.destination_city,l.destination_country_code)
          )
        )
        on conflict(player_id,season,month,day) do update set
          activity_type='travel',
          source='travel_plan',
          reference_id=v_leg2::text,
          note=excluded.note,
          updated_at=now()
        where public.player_daily_activity.effects_applied_at is null
          and (
            public.player_daily_activity.activity_type='home'
            or public.player_daily_activity.source in ('travel_plan','training_camp_booking')
          );

        v_outbound_split:=v_outbound_split+1;
      end if;
    end if;

    update public.player_training_camp_bookings
    set shortened_days=v_shortened,
        updated_at=now()
    where id=b.id
      and shortened_days is distinct from v_shortened;
  end loop;

  return jsonb_build_object(
    'status','applied',
    'inbound_split_days',v_inbound_split,
    'outbound_split_days',v_outbound_split,
    'home_routed_transitions',v_home_routes
  );
end;
$$;

-- Mark a split travel calendar day as processed and activate a camp when the
-- inbound second half arrives on the camp's first scheduled day.
create or replace function public.sync_split_travel_activity_completion_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  gd record;
  v_booking uuid;
begin
  if new.status<>'completed'
     or old.status='completed'
     or not new.split_day_transition then
    return new;
  end if;

  select * into gd from public.absolute_game_day_v1(new.departure_absolute_day);

  update public.player_daily_activity
  set effects_applied_at=coalesce(effects_applied_at,now()),
      effect_summary=coalesce(effect_summary,'{}'::jsonb)
        || jsonb_build_object(
          'split_day_travel',true,
          'transition_group_id',new.transition_group_id,
          'last_completed_leg_id',new.id,
          'split_leg_sequence',new.split_day_sequence
        ),
      updated_at=now()
  where player_id=new.player_id
    and season=gd.season and month=gd.month and day=gd.day
    and activity_type='travel';

  if new.split_day_sequence=2
     and new.destination_location_type='training_camp'
     and coalesce(new.destination_reference_id,'')~*'^[0-9a-f-]{36}$' then
    v_booking:=new.destination_reference_id::uuid;
    update public.player_training_camp_bookings
    set status=case when status='booked' then 'active' else status end,
        started_at=coalesce(started_at,now()),
        updated_at=now()
    where id=v_booking
      and new.departure_absolute_day between start_absolute_day and end_absolute_day;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_split_travel_activity_completion on public.player_travel_legs;
create trigger sync_split_travel_activity_completion
after update of status
on public.player_travel_legs
for each row
execute function public.sync_split_travel_activity_completion_v1();

-- ---------------------------------------------------------------------------
-- Wrap the existing travel-plan builder so every rebuild receives the camp
-- transition rules without duplicating the mature generic travel engine.
-- ---------------------------------------------------------------------------

alter function public.rebuild_player_travel_plan_v1(uuid)
  rename to rebuild_player_travel_plan_core_v1;

create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_core jsonb;
  v_camp jsonb;
  v_timing jsonb;
begin
  v_core:=public.rebuild_player_travel_plan_core_v1(p_player_id);
  v_camp:=public.apply_training_camp_split_travel_v1(p_player_id);
  v_timing:=public.sync_player_tournament_travel_timing_v1(p_player_id);

  return coalesce(v_core,'{}'::jsonb)
    || jsonb_build_object(
      'training_camp_transitions',v_camp,
      'tournament_timing_after_camp_transitions',v_timing
    );
end;
$$;

-- Preserve split-day times when syncing tournament travel timing.
create or replace function public.sync_player_tournament_travel_timing_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  l record;
  fm record;
  pm record;
  rule public.tournament_match_scheduling_rules%rowtype;
  q jsonb;
  v_first_day integer;
  v_first_abs bigint;
  v_pref_day integer;
  v_depart bigint;
  v_prev_end bigint;
  v_travel integer;
  v_arrive bigint;
  v_ready bigint;
  v_status text;
  v_count integer:=0;
  gd record;
  v_existing text;
begin
  for l in
    select *
    from public.player_travel_legs
    where player_id=p_player_id
      and status='planned'
      and destination_location_type='tournament'
      and destination_reference_id~*'^[0-9a-f-]{36}$'
    order by departure_absolute_day,id
  loop
    select
      m.id,m.competition_id,m.scheduled_start_minute,m.scheduled_season_week,m.scheduled_day,
      ed.season_number,s.category_code
    into fm
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=ed.tournament_series_id
    where m.competition_id=l.destination_reference_id::uuid
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
    order by ed.season_number,m.scheduled_season_week,m.scheduled_day,
             coalesce(m.scheduled_start_minute,600),m.match_number
    limit 1;

    if fm.id is null then continue; end if;

    v_first_day:=(((fm.season_number-1)*366)+2+((fm.scheduled_season_week-1)*7)+(fm.scheduled_day-1))::integer;
    v_first_abs:=v_first_day::bigint*1440+coalesce(fm.scheduled_start_minute,600);

    if l.split_day_transition then
      v_arrive:=l.arrival_absolute_day::bigint*1440+coalesce(l.arrival_minute_of_day,1439);
      select * into rule
      from public.tournament_match_scheduling_rules
      where category_code=fm.category_code;
      v_ready:=v_arrive+coalesce(rule.pre_match_arrival_buffer_minutes,90);
      v_status:=case when v_ready>v_first_abs then 'at_risk' else 'tight' end;

      update public.player_travel_legs
      set first_match_id=fm.id,
          connection_status=v_status,
          updated_at=now()
      where id=l.id;

      v_count:=v_count+1;
      continue;
    end if;

    select * into rule
    from public.tournament_match_scheduling_rules
    where category_code=fm.category_code;

    v_pref_day:=v_first_day-1;
    v_depart:=v_pref_day::bigint*1440+540;

    select
      m.id match_id,m.scheduled_start_minute,
      coalesce(m.actual_duration_minutes,m.estimated_duration_minutes,150) duration_minutes,
      (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day
    into pm
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where m.competition_id<>fm.competition_id
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
      and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*1440
           +coalesce(m.scheduled_start_minute,600))<v_first_abs
    order by abs_day desc,coalesce(m.scheduled_start_minute,600) desc
    limit 1;

    if pm.match_id is not null and pm.abs_day>=v_pref_day then
      v_prev_end:=pm.abs_day::bigint*1440+coalesce(pm.scheduled_start_minute,600)
        +pm.duration_minutes+coalesce(rule.post_match_departure_buffer_minutes,60);
      v_depart:=greatest(v_depart,v_prev_end);
    end if;

    q:=public.quote_travel_v2(
      l.source_city,l.source_country_code,l.source_latitude,l.source_longitude,
      l.destination_city,l.destination_country_code,l.destination_latitude,l.destination_longitude,
      l.travel_class,'one_way'
    );
    v_travel:=greatest(30,ceil(coalesce((q->>'estimated_hours_one_way')::numeric,1)*60)::integer);
    v_arrive:=v_depart+v_travel;
    v_ready:=v_arrive+coalesce(rule.pre_match_arrival_buffer_minutes,90);
    v_status:=case
      when v_ready>v_first_abs then 'at_risk'
      when (v_arrive/1440)::integer>=v_first_day
        or v_depart>v_pref_day::bigint*1440+540 then 'tight'
      else 'normal'
    end;

    update public.player_travel_legs
    set departure_absolute_day=(v_depart/1440)::integer,
        departure_minute_of_day=(v_depart%1440)::smallint,
        arrival_absolute_day=(v_arrive/1440)::integer,
        arrival_minute_of_day=(v_arrive%1440)::smallint,
        estimated_travel_minutes=v_travel,
        connection_status=v_status,
        first_match_id=fm.id,
        embedded_transition=(pm.match_id is not null and pm.abs_day>=v_pref_day),
        updated_at=now()
    where id=l.id;

    delete from public.player_daily_activity
    where player_id=p_player_id
      and source='travel_plan'
      and reference_id=l.id::text
      and effects_applied_at is null;

    if not (pm.match_id is not null and pm.abs_day>=v_pref_day) then
      select * into gd from public.absolute_game_day_v1((v_depart/1440)::integer);
      select activity_type into v_existing
      from public.player_daily_activity
      where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;

      if v_existing is null or v_existing='home' then
        insert into public.player_daily_activity(
          player_id,season,month,day,activity_type,source,reference_id,note
        )
        values(
          p_player_id,gd.season,gd.month,gd.day,
          'travel','travel_plan',l.id::text,
          format('Travel to %s',coalesce(l.destination_city,l.destination_country_code))
        )
        on conflict(player_id,season,month,day) do update set
          activity_type='travel',
          source='travel_plan',
          reference_id=l.id::text,
          note=excluded.note,
          updated_at=now()
        where public.player_daily_activity.effects_applied_at is null
          and public.player_daily_activity.activity_type='home';
      end if;
    end if;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object('status','synced','tournament_legs',v_count);
end;
$$;

-- ---------------------------------------------------------------------------
-- Match no-show when travel readiness is impossible.
-- ---------------------------------------------------------------------------

create or replace function public.resolve_tournament_travel_no_show_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  m public.tournament_matches%rowtype;
  v_p1_human boolean:=false;
  v_p2_human boolean:=false;
  v_p1_ready jsonb:='{}'::jsonb;
  v_p2_ready jsonb:='{}'::jsonb;
  v_p1_block boolean:=false;
  v_p2_block boolean:=false;
  v_winner uuid;
  v_owner uuid;
  v_blocked uuid;
  v_day integer;
  v_r1 bigint;
  v_r2 bigint;
begin
  select * into m
  from public.tournament_matches
  where id=p_match_id
  for update;

  if m.id is null
     or m.status<>'scheduled'
     or m.player1_id is null
     or m.player2_id is null then
    return jsonb_build_object('status','no_action');
  end if;

  select exists(
    select 1 from public.players p
    where p.id=m.player1_id and p.player_type='human' and p.owner_user_id is not null
  ) into v_p1_human;

  select exists(
    select 1 from public.players p
    where p.id=m.player2_id and p.player_type='human' and p.owner_user_id is not null
  ) into v_p2_human;

  if v_p1_human then
    v_p1_ready:=public.player_ready_for_tournament_match_v1(m.player1_id,p_match_id);
    v_p1_block:=coalesce(v_p1_ready->>'status','normal')='impossible';
  end if;

  if v_p2_human then
    v_p2_ready:=public.player_ready_for_tournament_match_v1(m.player2_id,p_match_id);
    v_p2_block:=coalesce(v_p2_ready->>'status','normal')='impossible';
  end if;

  if not v_p1_block and not v_p2_block then
    return jsonb_build_object('status','no_action');
  end if;

  if v_p1_block and not v_p2_block then
    v_winner:=m.player2_id;
  elsif v_p2_block and not v_p1_block then
    v_winner:=m.player1_id;
  else
    -- Both are late: advance the player whose itinerary becomes ready first.
    v_r1:=coalesce((v_p1_ready->>'ready_absolute_minute')::bigint,9223372036854775807);
    v_r2:=coalesce((v_p2_ready->>'ready_absolute_minute')::bigint,9223372036854775807);
    v_winner:=case when v_r1<=v_r2 then m.player1_id else m.player2_id end;
  end if;

  v_day:=public.tournament_match_absolute_day_v2(p_match_id);

  update public.tournament_matches
  set status='completed',
      winner_id=v_winner,
      started_at=coalesce(started_at,now()),
      completed_at=now(),
      actual_duration_minutes=null,
      completion_reason='travel_no_show',
      updated_at=now()
  where id=p_match_id;

  for v_blocked in
    select x.pid
    from (values (m.player1_id,v_p1_block),(m.player2_id,v_p2_block)) x(pid,blocked)
    where x.blocked
  loop
    select owner_user_id into v_owner
    from public.players
    where id=v_blocked;

    if v_owner is not null then
      perform public.emit_notification_v1(
        v_owner,v_blocked,
        'tournament.match.travel_no_show',
        'Match missed — travel conflict',
        'You missed this match because your travel itinerary did not get you to the tournament venue before the scheduled start.',
        '/game/calendar?tab=tournament-calendar',
        jsonb_build_object(
          'match_id',p_match_id,
          'completion_reason','travel_no_show',
          'match_absolute_day',v_day,
          'travel_readiness',case when v_blocked=m.player1_id then v_p1_ready else v_p2_ready end
        ),
        'travel-no-show:'||p_match_id::text||':'||v_blocked::text
      );
    end if;
  end loop;

  return jsonb_build_object(
    'status','walkover',
    'reason','travel_no_show',
    'match_id',p_match_id,
    'winner_id',v_winner,
    'player1_travel_blocked',v_p1_block,
    'player2_travel_blocked',v_p2_block,
    'player1_readiness',v_p1_ready,
    'player2_readiness',v_p2_ready
  );
end;
$$;

alter function public.prepare_tournament_match_simulation_v1(uuid)
  rename to prepare_tournament_match_simulation_core_v1;

create or replace function public.prepare_tournament_match_simulation_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_travel jsonb;
begin
  v_travel:=public.resolve_tournament_travel_no_show_v1(p_match_id);
  if v_travel->>'status'='walkover' then
    return v_travel;
  end if;

  return public.prepare_tournament_match_simulation_core_v1(p_match_id);
end;
$$;

-- No match was played for a health/travel walkover, therefore equipment must
-- not lose durability.
create or replace function public.apply_equipment_wear_on_completed_match_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_surface text:='hard';
begin
  if new.completion_reason in ('health_walkover','health_surrender','travel_no_show') then
    return new;
  end if;

  select s.surface into v_surface
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  where wc.id=new.competition_id;

  if new.player1_id is not null
     and exists(select 1 from public.players p where p.id=new.player1_id and p.owner_user_id is not null) then
    perform public.apply_equipment_match_wear_v1(new.player1_id,new.id,coalesce(v_surface,'hard'));
  end if;

  if new.player2_id is not null
     and exists(select 1 from public.players p where p.id=new.player2_id and p.owner_user_id is not null) then
    perform public.apply_equipment_match_wear_v1(new.player2_id,new.id,coalesce(v_surface,'hard'));
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Regular Training dashboard: expose booked/active camp.
-- ---------------------------------------------------------------------------

create or replace function public.get_training_dashboard_v1()
returns jsonb
language plpgsql
stable security definer
set search_path='public'
as $$
declare
  v_player_id uuid;
  d record;
  v_activity text;
  v_plan jsonb;
  v_skills jsonb;
  v_progress jsonb;
  v_today jsonb;
  v_recent jsonb;
  v_eligible boolean;
  v_reason text;
  v_abs integer;
  v_day_info record;
  v_week_start integer;
  v_weekday integer:=0;
  v_scheduled_role text;
  v_health jsonb;
  v_staff jsonb;
  v_camp jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select id into v_player_id
  from public.players
  where owner_user_id=auth.uid();

  if v_player_id is null then raise exception 'Player not found.'; end if;

  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  select coalesce((
    select activity_type
    from public.player_daily_activity
    where player_id=v_player_id and season=d.season and month=d.month and day=d.day
  ),'home') into v_activity;

  if v_activity='home'
     and public.player_has_confirmed_tournament_match_on_day_v1(v_player_id,v_abs) then
    v_activity:='tournament';
  end if;

  v_health:=public.get_player_health_summary_v1(v_player_id,v_abs);
  v_staff:=public.get_player_staff_effects_v2(v_player_id);
  v_eligible:=v_activity='home' and coalesce((v_health->>'can_train')::boolean,true);

  v_reason:=case
    when v_activity='home' and not coalesce((v_health->>'can_train')::boolean,true)
      then format('Health restriction — %s. Normal training is unavailable until medically cleared.',coalesce(v_health->>'label','unavailable'))
    when v_activity='home' then null
    when v_activity='travel' then 'Travel day — regular training is unavailable.'
    when v_activity='tournament' then 'Confirmed tournament match — regular training is unavailable.'
    when v_activity='training_camp' then 'Training camp active — camp training replaces regular training.'
    when v_activity='injured' then 'Health recovery day — regular training is unavailable.'
    else 'Regular training is unavailable.'
  end;

  select * into v_day_info from public.absolute_game_day_v1(v_abs);
  if v_day_info.season_week between 1 and 52 then
    v_week_start:=public.training_camp_week_start_absolute_v1(d.season,v_day_info.season_week);
    v_weekday:=v_abs-v_week_start+1;
  end if;

  v_scheduled_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);

  select to_jsonb(x) into v_plan
  from (
    select training_type,focus_attribute,intensity,focus_share,is_active,updated_at
    from public.player_training_plans
    where player_id=v_player_id
  ) x;

  if v_plan is null or v_plan='null'::jsonb then
    v_plan:=jsonb_build_object(
      'training_type','day_off','focus_attribute',null,'intensity','standard',
      'focus_share',0.85,'is_active',true
    );
  end if;

  select to_jsonb(x) into v_skills
  from (
    select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,
           fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus
    from public.player_skills
    where player_id=v_player_id
  ) x;

  select to_jsonb(x) into v_progress
  from (
    select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,
           fitness,stamina,recovery,movement
    from public.player_training_progress
    where player_id=v_player_id
  ) x;

  if v_progress is null or v_progress='null'::jsonb then
    v_progress:=jsonb_build_object(
      'serve',0,'forehand',0,'backhand',0,'return_skill',0,'volley',0,'slice',0,
      'drop_shot',0,'lob',0,'smash',0,'fitness',0,'stamina',0,'recovery',0,'movement',0
    );
  end if;

  select to_jsonb(x) into v_today
  from (
    select id,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,
           fatigue_before,fatigue_after,sharpness_before,sharpness_after,
           morale_before,morale_after,focus_before,focus_after,processed_by,
           session_role,staff_effects_snapshot,created_at
    from public.player_training_sessions
    where player_id=v_player_id and season=d.season and month=d.month and day=d.day
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.absolute_day desc,x.created_at desc),'[]'::jsonb)
  into v_recent
  from (
    select id,season,month,day,training_type,focus_attribute,intensity,efficiency,
           development_gains,level_ups,fatigue_before,fatigue_after,
           sharpness_before,sharpness_after,morale_before,morale_after,
           focus_before,focus_after,session_role,staff_effects_snapshot,created_at,
           public.game_day_absolute_v1(season,month,day) as absolute_day
    from public.player_training_sessions
    where player_id=v_player_id
      and public.game_day_absolute_v1(season,month,day)<=v_abs
    order by public.game_day_absolute_v1(season,month,day) desc,created_at desc
    limit 3
  ) x;

  select jsonb_build_object(
    'id',b.id,
    'status',b.status,
    'name',p.name,
    'city',l.city,
    'country',l.country,
    'country_code',l.country_code,
    'start_absolute_day',b.start_absolute_day,
    'end_absolute_day',b.end_absolute_day,
    'start_season',b.start_season,
    'start_season_week',b.start_season_week,
    'start_month',b.start_month,
    'start_day',b.start_day,
    'end_season',b.end_season,
    'end_month',b.end_month,
    'end_day',b.end_day,
    'duration_weeks',b.duration_weeks,
    'shortened_days',b.shortened_days,
    'effective_training_days',greatest(0,b.duration_weeks*7-b.shortened_days),
    'total_cost',b.total_cost
  )
  into v_camp
  from public.player_training_camp_bookings b
  join public.training_camp_programs p on p.id=b.program_id
  join public.training_camp_locations l on l.id=p.location_id
  where b.player_id=v_player_id
    and b.status in ('booked','active')
    and b.end_absolute_day>=v_abs
  order by b.start_absolute_day
  limit 1;

  return jsonb_build_object(
    'game_day',jsonb_build_object(
      'season',d.season,'month',d.month,'day',d.day,
      'season_week',v_day_info.season_week,
      'weekday_in_training_week',v_weekday,
      'scheduled_role',v_scheduled_role
    ),
    'activity_type',v_activity,
    'eligible',v_eligible,
    'block_reason',v_reason,
    'health_summary',v_health,
    'plan',v_plan,
    'skills',v_skills,
    'progress',v_progress,
    'staff_effects',v_staff,
    'today_session',coalesce(v_today,'null'::jsonb),
    'recent_sessions',v_recent,
    'current_or_planned_camp',coalesce(v_camp,'null'::jsonb),
    'rules',jsonb_build_object(
      'focus_share',0.85,
      'other_share',0.15,
      'travel_fatigue_only',false,
      'travel_day_recovery_offset',3,
      'regular_training_states',jsonb_build_array('home'),
      'blocked_states',jsonb_build_array('travel','tournament','training_camp','injured'),
      'automatic_scheduler_enabled',true,
      'staff_effects_visible',true,
      'weekly_rhythm',jsonb_build_object(
        'automatic_recovery_days',0,
        'day_off_user_controlled',true,
        'active_recovery_days',0,
        'full_rest_days',0
      ),
      'camp_weekly_rhythm',jsonb_build_object('development_days',6,'recovery_days',1),
      'attribute_development_multiplier',jsonb_build_object(
        '1-59',1.00,'60-69',0.90,'70-79',0.75,
        '80-89',0.55,'90-94',0.35,'95-99',0.20
      ),
      'age_modifier_used',false
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- System Health for split transitions.
-- ---------------------------------------------------------------------------

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values(
  'check:training_camp_transition_travel',
  'Training camp transition travel',
  'Training',
  'Verifies tournament/camp home-routed transitions, split-day pairs and shortened-camp ownership.',
  'business_check',
  null,
  true,
  'critical',
  5,
  10,
  true,
  217
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();

create or replace function public.check_training_camp_transition_health_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_bad_groups integer:=0;
  v_bad_shortened integer:=0;
  v_direct_links integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  select count(*) into v_bad_groups
  from (
    select transition_group_id
    from public.player_travel_legs
    where status='planned'
      and split_day_transition=true
    group by transition_group_id
    having count(*)<>2
       or min(split_day_sequence)<>1
       or max(split_day_sequence)<>2
       or min(departure_absolute_day)<>max(departure_absolute_day)
  ) x;

  select count(*) into v_bad_shortened
  from public.player_training_camp_bookings b
  where b.status in ('booked','active')
    and b.shortened_days>0
    and not exists(
      select 1
      from public.player_daily_activity a
      where a.player_id=b.player_id
        and a.source='training_camp_booking'
        and a.reference_id=b.id::text
        and a.activity_type='travel'
        and public.game_day_absolute_v1(a.season,a.month,a.day)
            between b.start_absolute_day and b.end_absolute_day
    );

  -- Direct tournament<->camp planned legs are not allowed after the home-route
  -- transition pass. They indicate the special transition step was skipped.
  select count(*) into v_direct_links
  from public.player_travel_legs l
  where l.status='planned'
    and (
      (l.source_location_type='tournament' and l.destination_location_type='training_camp')
      or
      (l.source_location_type='training_camp' and l.destination_location_type='tournament')
    );

  v_problem_count:=v_bad_groups+v_bad_shortened+v_direct_links;

  v_details:=jsonb_build_object(
    'invalid_split_groups',v_bad_groups,
    'shortened_camps_missing_split_travel_day',v_bad_shortened,
    'direct_tournament_camp_links_remaining',v_direct_links,
    'problem_count',v_problem_count
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:training_camp_transition_travel',
      'critical',
      'Training Camp transition travel requires attention',
      format('%s Training Camp transition integrity issue(s) require attention.',v_problem_count),
      'business:training-camp-transition-travel',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:training-camp-transition-travel',
      'Training Camp home-routed transition travel is healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:training_camp_transition_travel',
    case when v_problem_count>0 then 'error' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s Training Camp transition issue(s).',v_problem_count)
      else 'Training Camp transition travel is healthy.'
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'error' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
exception when others then
  perform public.raise_system_incident_v1(
    'check:training_camp_transition_travel',
    'critical',
    'Training Camp transition health check failed',
    sqlerrm,
    'business:training-camp-transition-travel',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message,details
  ) values(
    'check:training_camp_transition_travel',
    'error',
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    'Training Camp transition health check failed.',
    sqlerrm,
    jsonb_build_object('sqlstate',sqlstate)
  );

  return jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
end;
$$;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-training-camp-health-v1'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-training-camp-health-v1',
  '4-59/5 * * * *',
  $cron$
    select public.check_training_camp_health_v1();
    select public.check_training_camp_transition_health_v1();
  $cron$
);

select public.check_training_camp_health_v1();
select public.check_training_camp_transition_health_v1();
