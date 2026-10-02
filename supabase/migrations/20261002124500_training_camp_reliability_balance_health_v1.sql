-- Training Camp reliability, UX, balance review and System Health integration.
-- 2026-10-02
--
-- Goals:
-- * booking is atomic and concurrency-safe
-- * quotes expose real affordability and ISO country codes for shared flag UI
-- * invalid locations/staff are rejected explicitly
-- * tournament, health and calendar conflicts are blocked
-- * future cancellation refunds 100% because cancellation is only allowed pre-start
-- * cancellation gets an in-app notification
-- * camp lifecycle completes even when the final camp day is medically blocked
-- * hotel fatigue mitigation is applied exactly once
-- * Training Camp integrity is monitored in System Health / Control Center

-- ---------------------------------------------------------------------------
-- Notification catalog
-- ---------------------------------------------------------------------------

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,
  source_name,title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
)
values(
  'training.camp.cancelled',
  'training',
  'Training camp cancelled',
  'Confirm that a future training-camp reservation was cancelled and refunded.',
  'Training camp booking cancelled',
  'A booked training camp is cancelled before its starting day.',
  'Server-side cancellation RPC',
  'player_training_camp_bookings',
  'Training camp cancelled',
  '{{camp_name}} was cancelled. {{refund_amount}} was returned to Career Cash.',
  '/game/training',
  'info',
  true,false,false,true,true
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
  default_in_app=excluded.default_in_app,
  is_user_configurable=excluded.is_user_configurable,
  is_active=true,
  updated_at=now();

-- ---------------------------------------------------------------------------
-- Quote v2: preserve existing price engine, return ISO codes (not emoji) and
-- fail clearly on unavailable location.
-- ---------------------------------------------------------------------------

create or replace function public.quote_training_camp_v2(
  p_program_id uuid,
  p_start_season integer,
  p_start_week smallint,
  p_duration_weeks smallint,
  p_accommodation_slug text default 'standard-3-star'
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_user uuid:=auth.uid();
  v_player public.players%rowtype;
  v_program public.training_camp_programs%rowtype;
  v_location public.training_camp_locations%rowtype;
  v_hotel public.training_camp_accommodation_tiers%rowtype;
  v_start_abs integer;
  v_end_abs integer;
  v_current_abs integer;
  v_start record;
  v_end record;
  v_training_total integer;
  v_hotel_weekly integer;
  v_hotel_total integer;
  v_travel integer;
  v_total integer;
  v_origin jsonb;
  v_travel_quote jsonb;
  v_accommodation_quote jsonb;
  v_origin_city text;
  v_origin_country text;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_user and player_type='human';

  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into v_program
  from public.training_camp_programs
  where id=p_program_id and is_active;

  if v_program.id is null then raise exception 'Training camp program not found.'; end if;

  select * into v_location
  from public.training_camp_locations
  where id=v_program.location_id and is_active;

  if v_location.id is null then raise exception 'Training camp location is unavailable.'; end if;

  select * into v_hotel
  from public.training_camp_accommodation_tiers
  where slug=p_accommodation_slug and is_active;

  if v_hotel.id is null then raise exception 'Accommodation option not found.'; end if;
  if p_duration_weeks not between 1 and 4 then raise exception 'Training camp duration must be between 1 and 4 weeks.'; end if;
  if p_start_week not between 1 and 52 then raise exception 'Start week must be between 1 and 52.'; end if;
  if p_start_week+p_duration_weeks-1>52 then raise exception 'Training camp cannot extend beyond Season Week 52.'; end if;

  v_start_abs:=public.training_camp_week_start_absolute_v1(p_start_season,p_start_week);
  v_end_abs:=v_start_abs+p_duration_weeks*7-1;

  select public.game_day_absolute_v1(season,month,day)
  into v_current_abs
  from public.get_current_game_day_internal_v1();

  if v_start_abs<v_current_abs then
    raise exception 'Training camp must begin at the start of a current or future competition week.';
  end if;

  select * into v_start from public.absolute_game_day_v1(v_start_abs);
  select * into v_end from public.absolute_game_day_v1(v_end_abs);

  v_origin:=public.resolve_player_origin_before_day_v1(v_player.id,v_start_abs);
  v_origin_city:=nullif(v_origin->>'city','');
  v_origin_country:=v_origin->>'country_code';

  v_training_total:=v_program.weekly_cost*p_duration_weeks;
  v_accommodation_quote:=public.quote_accommodation_v1(
    v_location.city,v_location.country_code,v_hotel.base_weekly_cost,p_duration_weeks,1,'week'
  );
  v_hotel_weekly:=(v_accommodation_quote->>'adjusted_unit_cost')::integer;
  v_hotel_total:=(v_accommodation_quote->>'total')::integer;

  v_travel_quote:=public.training_camp_travel_quote_v2(
    v_origin_city,v_origin_country,v_location.city,v_location.country_code
  );
  v_travel:=(v_travel_quote->>'cost')::integer;
  v_total:=v_training_total+v_hotel_total+v_travel;

  return jsonb_build_object(
    'program_id',v_program.id,
    'camp_name',v_program.name,
    'training_quality',jsonb_build_object('tier',v_program.quality_tier,'multiplier',v_program.quality_multiplier),
    'quality_tier',v_program.quality_tier,
    'facility_rating',v_program.rating,
    'quality_multiplier',v_program.quality_multiplier,
    'start_season',p_start_season,
    'start_week',p_start_week,
    'start_absolute_day',v_start_abs,
    'end_absolute_day',v_end_abs,
    'start',jsonb_build_object('season',v_start.season,'month',v_start.month,'day',v_start.day),
    'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),
    'duration_weeks',p_duration_weeks,
    'origin',(v_origin-'city'-'country_code')||jsonb_build_object(
      'city',coalesce(v_origin_city,'Home base not set'),
      'country_code',v_origin_country,
      'country_flag',public.country_flag_emoji_v1(v_origin_country),
      'raw_city',v_origin_city,
      'raw_country_code',v_origin_country
    ),
    'destination',jsonb_build_object(
      'city',v_location.city,
      'country',v_location.country,
      'country_code',v_location.country_code,
      'country_flag',public.country_flag_emoji_v1(v_location.country_code),
      'raw_country_code',v_location.country_code,
      'continent',v_location.continent,
      'cost_index',(v_accommodation_quote->>'destination_cost_index')::numeric
    ),
    'training_fee_weekly',v_program.weekly_cost,
    'training_fee_total',v_training_total,
    'accommodation',jsonb_build_object(
      'id',v_hotel.id,
      'slug',v_hotel.slug,
      'name',v_hotel.name,
      'stars',v_hotel.star_rating,
      'base_weekly_cost',v_hotel.base_weekly_cost,
      'destination_cost_index',(v_accommodation_quote->>'destination_cost_index')::numeric,
      'weekly_cost',v_hotel_weekly,
      'total',v_hotel_total,
      'rest_quality',v_hotel.rest_quality,
      'fatigue_mitigation',v_hotel.fatigue_mitigation,
      'weekly_morale_bonus',v_hotel.weekly_morale_bonus,
      'weekly_focus_bonus',v_hotel.weekly_focus_bonus,
      'description',v_hotel.description,
      'cost_tier',v_accommodation_quote->>'cost_tier'
    ),
    'travel',v_travel_quote,
    'travel_cost',v_travel,
    'travel_type','Round-trip estimate',
    'staff_count',0,
    'staff_cost',0,
    'grand_total',v_total,
    'engine','universal_travel_stay_v1'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Quote v3: validate duplicate staff and expose affordability.
-- ---------------------------------------------------------------------------

create or replace function public.quote_training_camp_v3(
  p_program_id uuid,
  p_start_season integer,
  p_start_week smallint,
  p_duration_weeks smallint,
  p_accommodation_slug text default 'standard-3-star',
  p_staff_contract_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_base jsonb;
  v_player uuid;
  v_count integer;
  v_distinct_count integer;
  v_travel_each integer;
  v_hotel_total integer;
  v_staff_travel integer;
  v_staff_hotel integer;
  v_staff_total integer;
  v_staff jsonb;
  v_invalid integer;
  v_balance bigint;
  v_grand_total integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';

  if v_player is null then raise exception 'Player not found.'; end if;

  v_base:=public.quote_training_camp_v2(
    p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug
  );

  select count(*),count(distinct x)
  into v_count,v_distinct_count
  from unnest(coalesce(p_staff_contract_ids,'{}'::uuid[])) x;

  if v_count<>v_distinct_count then
    raise exception 'The same staff member cannot be selected more than once.';
  end if;

  select count(*) into v_invalid
  from unnest(coalesce(p_staff_contract_ids,'{}'::uuid[])) x
  left join public.player_staff_contracts c
    on c.id=x and c.player_id=v_player and c.status='active'
  where c.id is null;

  if v_invalid>0 then raise exception 'One or more selected staff contracts are unavailable.'; end if;
  if v_count>6 then raise exception 'A maximum of six staff members can travel.'; end if;

  v_travel_each:=(v_base->>'travel_cost')::integer;
  v_hotel_total:=(v_base->'accommodation'->>'total')::integer;
  v_staff_travel:=v_travel_each*v_count;
  v_staff_hotel:=v_hotel_total*v_count;
  v_staff_total:=v_staff_travel+v_staff_hotel;
  v_grand_total:=(v_base->>'grand_total')::integer+v_staff_total;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'contract_id',c.id,
      'staff_id',s.id,
      'role',c.role,
      'role_label',public.staff_role_label_v1(c.role),
      'first_name',s.first_name,
      'last_name',s.last_name,
      'country_code',s.country_code,
      'travel_cost',v_travel_each,
      'accommodation_cost',v_hotel_total,
      'total_cost',v_travel_each+v_hotel_total
    ) order by c.role
  ),'[]'::jsonb)
  into v_staff
  from unnest(coalesce(p_staff_contract_ids,'{}'::uuid[])) x
  join public.player_staff_contracts c on c.id=x
  join public.staff_members s on s.id=c.staff_id;

  select balance into v_balance
  from public.player_career_finance_accounts
  where player_id=v_player;

  return v_base || jsonb_build_object(
    'staff_count',v_count,
    'staff_travel_cost',v_staff_travel,
    'staff_accommodation_cost',v_staff_hotel,
    'staff_cost',v_staff_total,
    'staff',v_staff,
    'grand_total',v_grand_total,
    'available_balance',coalesce(v_balance,0),
    'affordable',coalesce(v_balance,0)>=v_grand_total
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Booking v2: concurrency lock + complete conflict validation.
-- ---------------------------------------------------------------------------

create or replace function public.book_training_camp_v2(
  p_program_id uuid,
  p_start_season integer,
  p_start_week smallint,
  p_duration_weeks smallint,
  p_accommodation_slug text default 'standard-3-star'
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_user uuid:=auth.uid();
  v_player_id uuid;
  v_program public.training_camp_programs%rowtype;
  v_location public.training_camp_locations%rowtype;
  v_quote jsonb;
  v_hotel_id uuid;
  v_start_abs integer;
  v_end_abs integer;
  v_current_abs integer;
  v_start record;
  v_end record;
  v_booking public.player_training_camp_bookings%rowtype;
  d record;
  v_fin jsonb;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;

  select id into v_player_id
  from public.players
  where owner_user_id=v_user and player_type='human';

  if v_player_id is null then raise exception 'Player not found.'; end if;

  -- Serializes booking attempts for the same player and closes the concurrent
  -- double-click / duplicate request race.
  perform pg_advisory_xact_lock(hashtextextended('training-camp-book:'||v_player_id::text,0));

  select * into v_program
  from public.training_camp_programs
  where id=p_program_id and is_active;

  if v_program.id is null then raise exception 'Training camp program not found.'; end if;

  select * into v_location
  from public.training_camp_locations
  where id=v_program.location_id and is_active;

  if v_location.id is null then raise exception 'Training camp location is unavailable.'; end if;

  v_quote:=public.quote_training_camp_v2(
    p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug
  );
  v_start_abs:=(v_quote->>'start_absolute_day')::integer;
  v_end_abs:=(v_quote->>'end_absolute_day')::integer;
  v_hotel_id:=(v_quote->'accommodation'->>'id')::uuid;

  select public.game_day_absolute_v1(season,month,day)
  into v_current_abs
  from public.get_current_game_day_internal_v1();

  if v_start_abs<v_current_abs then raise exception 'Training camp cannot start in the past.'; end if;

  if exists(
    select 1
    from public.player_training_camp_bookings b
    where b.player_id=v_player_id
      and b.status in ('booked','active')
      and int4range(b.start_absolute_day,b.end_absolute_day,'[]')
          && int4range(v_start_abs,v_end_abs,'[]')
  ) then
    raise exception 'Another training camp overlaps the selected weeks.';
  end if;

  if exists(
    select 1
    from generate_series(v_start_abs,v_end_abs) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    join public.player_daily_activity a
      on a.player_id=v_player_id
     and a.season=gd.season and a.month=gd.month and a.day=gd.day
    where (
      (a.activity_type<>'home'
       and not (a.activity_type='travel' and a.source='travel_plan' and a.effects_applied_at is null))
      or a.effects_applied_at is not null
    )
  ) then
    raise exception 'The selected weeks contain travel, tournament, injury, another camp, or an already processed activity.';
  end if;

  if exists(
    select 1
    from generate_series(v_start_abs,v_end_abs) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    join public.player_training_sessions s
      on s.player_id=v_player_id
     and s.season=gd.season and s.month=gd.month and s.day=gd.day
  ) then
    raise exception 'Regular training has already been processed during one of the selected weeks.';
  end if;

  if exists(
    select 1
    from generate_series(v_start_abs,v_end_abs) g(abs_day)
    where public.player_training_blocked_by_health_v1(v_player_id,g.abs_day)
  ) then
    raise exception 'A medical restriction overlaps the selected camp weeks.';
  end if;

  if exists(
    select 1
    from public.player_calendar_commitments c
    where c.player_id=v_player_id
      and c.status='committed'
      and int4range(c.starts_absolute_day,c.ends_absolute_day,'[]')
          && int4range(v_start_abs,v_end_abs,'[]')
  ) then
    raise exception 'Another calendar commitment overlaps the selected camp weeks.';
  end if;

  -- Applications block booking even before allocation.
  if exists(
    select 1
    from generate_series(v_start_abs,v_end_abs) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    join public.tournament_editions te on te.season_number=gd.season
    join public.tournament_schedule_slots ss
      on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week
    join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id
    join public.tournament_applications ta
      on ta.competition_id=wc.id and ta.player_id=v_player_id
    where gd.season_week>0
      and wc.status<>'canceled'
      and te.status<>'canceled'
      and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')
  ) then
    raise exception 'A tournament application or commitment overlaps the selected camp weeks.';
  end if;

  -- Accepted entries are checked independently so a missing/stale application
  -- row can never allow a camp to overwrite a real tournament commitment.
  if exists(
    select 1
    from generate_series(v_start_abs,v_end_abs) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    join public.tournament_editions te on te.season_number=gd.season
    join public.tournament_schedule_slots ss
      on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week
    join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id
    join public.tournament_entries e
      on e.competition_id=wc.id
     and e.player_id=v_player_id
     and e.entry_status='active'
    where gd.season_week>0
      and wc.status<>'canceled'
      and te.status<>'canceled'
  ) then
    raise exception 'An accepted tournament entry overlaps the selected camp weeks.';
  end if;

  select * into v_start from public.absolute_game_day_v1(v_start_abs);
  select * into v_end from public.absolute_game_day_v1(v_end_abs);

  insert into public.player_training_camp_bookings(
    player_id,program_id,start_absolute_day,end_absolute_day,
    start_season,start_month,start_day,end_season,end_month,end_day,
    duration_weeks,weekly_cost,total_cost,status,start_season_week,accommodation_tier_id,
    training_fee_total,accommodation_weekly_cost,accommodation_total,travel_cost,
    staff_count,staff_travel_cost,staff_accommodation_cost,staff_total_cost,
    origin_city,origin_country_code,origin_continent,
    travel_distance_km,travel_round_trip_km,travel_band,travel_basis,travel_arrival_fatigue
  ) values(
    v_player_id,v_program.id,v_start_abs,v_end_abs,
    v_start.season,v_start.month,v_start.day,v_end.season,v_end.month,v_end.day,
    p_duration_weeks,v_program.weekly_cost,(v_quote->>'grand_total')::integer,'booked',
    p_start_week,v_hotel_id,
    (v_quote->>'training_fee_total')::integer,
    (v_quote->'accommodation'->>'weekly_cost')::integer,
    (v_quote->'accommodation'->>'total')::integer,
    (v_quote->>'travel_cost')::integer,
    0,0,0,0,
    nullif(v_quote->'origin'->>'raw_city',''),
    v_quote->'origin'->>'raw_country_code',
    v_quote->'origin'->>'continent',
    nullif(v_quote->'travel'->>'one_way_km','')::integer,
    nullif(v_quote->'travel'->>'round_trip_km','')::integer,
    v_quote->'travel'->>'band',
    v_quote->'travel'->>'basis',
    nullif(v_quote->'travel'->>'arrival_fatigue','')::smallint
  )
  returning * into v_booking;

  -- This finance call is in the same database transaction as the booking.
  -- If funds are insufficient, the booking/activity/travel changes roll back.
  v_fin:=public.post_career_finance_transaction_v1(
    v_player_id,
    -v_booking.total_cost,
    'training',
    'training_camp',
    format('%s — %s',v_program.name,v_location.city),
    'training_camp_booking',
    v_booking.id::text,
    'training-camp-base:'||v_booking.id::text,
    jsonb_build_object(
      'program_id',v_program.id,
      'city',v_location.city,
      'duration_weeks',p_duration_weeks,
      'quote',v_quote
    ),
    true,
    v_current_abs
  );

  for d in
    select gd.*
    from generate_series(v_start_abs,v_end_abs) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
  loop
    insert into public.player_daily_activity(
      player_id,season,month,day,activity_type,source,reference_id,note
    )
    values(
      v_player_id,d.season,d.month,d.day,
      'training_camp','training_camp_booking',v_booking.id::text,v_program.name
    )
    on conflict(player_id,season,month,day) do update set
      activity_type='training_camp',
      source='training_camp_booking',
      reference_id=v_booking.id::text,
      note=v_program.name,
      updated_at=now();
  end loop;

  perform public.emit_notification_v1(
    v_user,v_player_id,
    'training.camp.booked',
    'Training camp booked',
    format(
      '%s in %s is booked for Season Week %s for %s week%s.',
      v_program.name,v_location.city,p_start_week,p_duration_weeks,
      case when p_duration_weeks=1 then '' else 's' end
    ),
    '/game/training',
    jsonb_build_object(
      'booking_id',v_booking.id,
      'program_id',v_program.id,
      'camp_name',v_program.name,
      'city',v_location.city,
      'start_week',p_start_week,
      'duration_weeks',p_duration_weeks,
      'total_cost',v_booking.total_cost,
      'finance',v_fin
    ),
    'training-camp-booked:'||v_booking.id::text
  );

  return jsonb_build_object(
    'status','booked',
    'booking_id',v_booking.id,
    'camp_name',v_program.name,
    'start_week',p_start_week,
    'duration_weeks',p_duration_weeks,
    'total_cost',v_booking.total_cost,
    'quote',v_quote,
    'finance',v_fin
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Booking v3: fail affordability before any booking work.
-- ---------------------------------------------------------------------------

create or replace function public.book_training_camp_v3(
  p_program_id uuid,
  p_start_season integer,
  p_start_week smallint,
  p_duration_weeks smallint,
  p_accommodation_slug text default 'standard-3-star',
  p_staff_contract_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_quote jsonb;
  v_base jsonb;
  v_booking uuid;
  v_player uuid;
  r record;
  v_extra integer;
  v_fin jsonb:='{}'::jsonb;
  v_abs integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';

  if v_player is null then raise exception 'Player not found.'; end if;

  v_quote:=public.quote_training_camp_v3(
    p_program_id,p_start_season,p_start_week,p_duration_weeks,
    p_accommodation_slug,p_staff_contract_ids
  );

  if not coalesce((v_quote->>'affordable')::boolean,false) then
    raise exception 'Insufficient career funds. Available: $%, required: $%.',
      coalesce((v_quote->>'available_balance')::bigint,0),
      (v_quote->>'grand_total')::integer;
  end if;

  v_base:=public.book_training_camp_v2(
    p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug
  );
  v_booking:=(v_base->>'booking_id')::uuid;
  v_extra:=(v_quote->>'grand_total')::integer-(v_base->>'total_cost')::integer;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  if v_extra>0 then
    v_fin:=public.post_career_finance_transaction_v1(
      v_player,-v_extra,
      'training','training_camp_staff',
      'Travelling staff — training camp',
      'training_camp_booking',
      v_booking::text,
      'training-camp-staff:'||v_booking::text,
      jsonb_build_object(
        'staff_contract_ids',to_jsonb(coalesce(p_staff_contract_ids,'{}'::uuid[])),
        'extra_cost',v_extra
      ),
      true,
      v_abs
    );
  end if;

  update public.player_training_camp_bookings
  set staff_count=(v_quote->>'staff_count')::smallint,
      staff_travel_cost=(v_quote->>'staff_travel_cost')::integer,
      staff_accommodation_cost=(v_quote->>'staff_accommodation_cost')::integer,
      staff_total_cost=(v_quote->>'staff_cost')::integer,
      total_cost=(v_quote->>'grand_total')::integer,
      updated_at=now()
  where id=v_booking and player_id=v_player;

  for r in
    select c.id contract_id,c.staff_id,c.role
    from unnest(coalesce(p_staff_contract_ids,'{}'::uuid[])) x
    join public.player_staff_contracts c on c.id=x
    where c.player_id=v_player and c.status='active'
  loop
    insert into public.player_training_camp_staff(
      booking_id,contract_id,staff_id,role,travel_cost,accommodation_cost,total_cost
    )
    values(
      v_booking,r.contract_id,r.staff_id,r.role,
      (v_quote->'travel'->>'cost')::integer,
      (v_quote->'accommodation'->>'total')::integer,
      (v_quote->'travel'->>'cost')::integer+(v_quote->'accommodation'->>'total')::integer
    );
  end loop;

  return v_base || jsonb_build_object(
    'total_cost',(v_quote->>'grand_total')::integer,
    'quote',v_quote,
    'staff_finance',v_fin
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Future cancellation: 100% refund, atomic + idempotent.
-- ---------------------------------------------------------------------------

create or replace function public.cancel_training_camp_v1(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_user uuid:=auth.uid();
  v_player_id uuid;
  v_booking public.player_training_camp_bookings%rowtype;
  v_program public.training_camp_programs%rowtype;
  v_location public.training_camp_locations%rowtype;
  v_current_abs integer;
  v_refund jsonb;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;

  select id into v_player_id
  from public.players
  where owner_user_id=v_user and player_type='human';

  select * into v_booking
  from public.player_training_camp_bookings
  where id=p_booking_id and player_id=v_player_id
  for update;

  if v_booking.id is null then raise exception 'Training camp booking not found.'; end if;

  select public.game_day_absolute_v1(season,month,day)
  into v_current_abs
  from public.get_current_game_day_internal_v1();

  if v_booking.status<>'booked' or v_current_abs>=v_booking.start_absolute_day then
    raise exception 'Only a future camp that has not started can be cancelled.';
  end if;

  select * into v_program from public.training_camp_programs where id=v_booking.program_id;
  select * into v_location from public.training_camp_locations where id=v_program.location_id;

  update public.player_training_camp_bookings
  set status='cancelled',cancelled_at=coalesce(cancelled_at,now()),updated_at=now()
  where id=v_booking.id;

  delete from public.player_daily_activity
  where player_id=v_player_id
    and source='training_camp_booking'
    and reference_id=v_booking.id::text
    and effects_applied_at is null;

  v_refund:=public.post_career_finance_transaction_v1(
    v_player_id,
    v_booking.total_cost,
    'training',
    'training_camp_refund',
    format('Training camp cancellation refund — %s',v_program.name),
    'training_camp_booking',
    v_booking.id::text,
    'training-camp-cancel-refund:'||v_booking.id::text,
    jsonb_build_object(
      'booking_id',v_booking.id,
      'program_id',v_program.id,
      'refund_policy','full_pre_start_refund'
    ),
    false,
    v_current_abs
  );

  perform public.emit_notification_v1(
    v_user,v_player_id,
    'training.camp.cancelled',
    'Training camp cancelled',
    format(
      '%s in %s was cancelled. $%s was returned to Career Cash.',
      v_program.name,coalesce(v_location.city,'the selected destination'),v_booking.total_cost
    ),
    '/game/training',
    jsonb_build_object(
      'booking_id',v_booking.id,
      'program_id',v_program.id,
      'camp_name',v_program.name,
      'city',v_location.city,
      'refund_amount',v_booking.total_cost,
      'finance',v_refund
    ),
    'training-camp-cancelled:'||v_booking.id::text
  );

  return jsonb_build_object(
    'status','cancelled',
    'booking_id',v_booking.id,
    'refunded_amount',v_booking.total_cost,
    'finance',v_refund
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Hotel effects: fatigue mitigation is already included in the training-day
-- formula for tennis/physical camps. Apply it here only to recovery camps.
-- This removes the previous double application on development camps.
-- ---------------------------------------------------------------------------

create or replace function public.apply_training_camp_accommodation_effects_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_tier public.training_camp_accommodation_tiers%rowtype;
  v_category text;
  v_fatigue_before smallint;
  v_fatigue_after smallint;
  v_morale_bonus smallint:=0;
  v_focus_bonus smallint:=0;
  v_trigger_fatigue_mitigation smallint:=0;
begin
  select t.*
  into v_tier
  from public.player_training_camp_bookings b
  join public.training_camp_accommodation_tiers t on t.id=b.accommodation_tier_id
  where b.id=new.booking_id;

  select p.category
  into v_category
  from public.player_training_camp_bookings b
  join public.training_camp_programs p on p.id=b.program_id
  where b.id=new.booking_id;

  if v_tier.id is null then return new; end if;

  -- tennis_skills / physical already subtract this value inside
  -- process_training_camp_day_v1. Recovery camps do not, so apply it here.
  v_trigger_fatigue_mitigation:=
    case when v_category='recovery_mindset' then v_tier.fatigue_mitigation else 0 end;

  select fatigue into v_fatigue_before
  from public.player_skills
  where player_id=new.player_id;

  if mod(new.camp_day_number,7)=0 then
    v_morale_bonus:=v_tier.weekly_morale_bonus;
    v_focus_bonus:=v_tier.weekly_focus_bonus;
  end if;

  update public.player_skills
  set fatigue=greatest(0,fatigue-v_trigger_fatigue_mitigation),
      morale=least(100,morale+v_morale_bonus),
      focus=least(100,focus+v_focus_bonus),
      updated_at=now()
  where player_id=new.player_id;

  select fatigue into v_fatigue_after
  from public.player_skills
  where player_id=new.player_id;

  update public.player_training_camp_days
  set condition_changes=coalesce(condition_changes,'{}'::jsonb)
      || jsonb_build_object(
        'accommodation',
        jsonb_build_object(
          'tier',v_tier.slug,
          'stars',v_tier.star_rating,
          'fatigue_mitigation',v_tier.fatigue_mitigation,
          'fatigue_mitigation_applied_here',v_trigger_fatigue_mitigation,
          'fatigue_before_hotel',v_fatigue_before,
          'fatigue_after_hotel',v_fatigue_after,
          'morale_bonus',v_morale_bonus,
          'focus_bonus',v_focus_bonus
        )
      )
  where id=new.id;

  update public.player_daily_activity
  set effect_summary=coalesce(effect_summary,'{}'::jsonb)
      || jsonb_build_object(
        'accommodation_effects',
        jsonb_build_object(
          'tier',v_tier.slug,
          'stars',v_tier.star_rating,
          'fatigue_mitigation',v_tier.fatigue_mitigation,
          'fatigue_mitigation_applied_here',v_trigger_fatigue_mitigation,
          'morale_bonus',v_morale_bonus,
          'focus_bonus',v_focus_bonus
        )
      ),
      updated_at=now()
  where player_id=new.player_id
    and season=new.season and month=new.month and day=new.day;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lifecycle finalizer: a camp must close even if its final day is converted to
-- a medically blocked / injured activity instead of a normal camp-day row.
-- ---------------------------------------------------------------------------

create or replace function public.finalize_training_camp_booking_v1(
  p_booking_id uuid,
  p_reason text default 'period_complete'
)
returns boolean
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_booking public.player_training_camp_bookings%rowtype;
  v_program public.training_camp_programs%rowtype;
  v_location public.training_camp_locations%rowtype;
  v_user uuid;
begin
  select * into v_booking
  from public.player_training_camp_bookings
  where id=p_booking_id
  for update;

  if v_booking.id is null then return false; end if;
  if v_booking.status='cancelled' then return false; end if;
  if v_booking.status='completed' then return true; end if;

  select * into v_program
  from public.training_camp_programs
  where id=v_booking.program_id;

  select * into v_location
  from public.training_camp_locations
  where id=v_program.location_id;

  select owner_user_id into v_user
  from public.players
  where id=v_booking.player_id;

  update public.player_training_camp_bookings
  set status='completed',
      started_at=coalesce(started_at,now()),
      completed_at=coalesce(completed_at,now()),
      updated_at=now()
  where id=v_booking.id;

  if v_user is not null then
    perform public.emit_notification_v1(
      v_user,v_booking.player_id,
      'training.camp.completed',
      'Training camp completed',
      format('%s in %s is complete.',v_program.name,v_location.city),
      '/game/training',
      jsonb_build_object(
        'booking_id',v_booking.id,
        'program_id',v_program.id,
        'camp_name',v_program.name,
        'city',v_location.city,
        'completion_reason',p_reason
      ),
      'training-camp-completed:'||v_booking.id::text
    );
  end if;

  return true;
end;
$$;

create or replace function public.sync_training_camp_status_from_activity_v1()
returns trigger
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  v_booking_id uuid;
  v_abs integer;
  v_booking public.player_training_camp_bookings%rowtype;
begin
  if new.source<>'training_camp_booking'
     or new.reference_id is null
     or new.effects_applied_at is null then
    return new;
  end if;

  begin
    v_booking_id:=new.reference_id::uuid;
  exception when others then
    return new;
  end;

  select * into v_booking
  from public.player_training_camp_bookings
  where id=v_booking_id and player_id=new.player_id;

  if v_booking.id is null or v_booking.status in ('completed','cancelled') then
    return new;
  end if;

  v_abs:=public.game_day_absolute_v1(new.season,new.month,new.day);

  if v_abs>=v_booking.start_absolute_day and v_abs<v_booking.end_absolute_day
     and v_booking.status='booked' then
    update public.player_training_camp_bookings
    set status='active',started_at=coalesce(started_at,now()),updated_at=now()
    where id=v_booking.id;
  elsif v_abs>=v_booking.end_absolute_day then
    perform public.finalize_training_camp_booking_v1(
      v_booking.id,
      case when new.activity_type='injured' then 'final_day_health_blocked' else 'final_day_processed' end
    );
  end if;

  return new;
end;
$$;

drop trigger if exists sync_training_camp_status_from_activity on public.player_daily_activity;
create trigger sync_training_camp_status_from_activity
after insert or update of activity_type,effects_applied_at
on public.player_daily_activity
for each row
execute function public.sync_training_camp_status_from_activity_v1();

-- ---------------------------------------------------------------------------
-- System Health / Control Center
-- ---------------------------------------------------------------------------

create table if not exists public.training_camp_health_config(
  singleton_id boolean primary key default true check(singleton_id),
  enforced_from_at timestamptz not null,
  updated_at timestamptz not null default now()
);

insert into public.training_camp_health_config(singleton_id,enforced_from_at)
values(true,now())
on conflict(singleton_id) do update set
  enforced_from_at=least(public.training_camp_health_config.enforced_from_at,excluded.enforced_from_at),
  updated_at=now();

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'cron:tennis-training-camp-health-v1',
  'Training camp lifecycle health job',
  'Training',
  'Runs Training Camp configuration, finance and lifecycle integrity checks every 5 minutes.',
  'cron',
  'tennis-training-camp-health-v1',
  true,
  'critical',
  5,
  15,
  true,
  43
),
(
  'check:training_camp_lifecycle',
  'Training camp lifecycle',
  'Training',
  'Verifies Training Camp booking, payment, calendar ownership, completion and configuration integrity.',
  'business_check',
  null,
  true,
  'critical',
  5,
  10,
  true,
  216
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

create or replace function public.check_training_camp_health_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_current_abs integer;
  v_enforced_from timestamptz;
  v_config_issues integer:=0;
  v_overdue integer:=0;
  v_overlaps integer:=0;
  v_missing_activity integer:=0;
  v_unprocessed_past_days integer:=0;
  v_bad_finance integer:=0;
  v_bad_cancel_refunds integer:=0;
  v_repaired integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
  r record;
begin
  select public.game_day_absolute_v1(season,month,day)
  into v_current_abs
  from public.get_current_game_day_internal_v1();

  select enforced_from_at into v_enforced_from
  from public.training_camp_health_config
  where singleton_id=true;

  -- Active catalog must match the central pricing rules.
  select count(*) into v_config_issues
  from public.training_camp_programs p
  left join public.training_camp_locations l on l.id=p.location_id and l.is_active
  left join public.training_camp_pricing_rules r
    on r.quality_tier=p.quality_tier and r.category=p.category
  where p.is_active
    and (
      l.id is null
      or r.quality_tier is null
      or p.weekly_cost<>r.weekly_training_fee
      or p.quality_multiplier<>r.quality_multiplier
      or p.rating<>r.facility_rating
      or (
        p.category='tennis_skills'
        and (p.surface not in ('hard','clay','grass') or p.development_profile='{}'::jsonb)
      )
      or (
        p.category='physical'
        and p.development_profile='{}'::jsonb
      )
      or (
        p.category='recovery_mindset'
        and p.condition_profile='{}'::jsonb
      )
    );

  v_config_issues:=v_config_issues + (
    select case when count(*)=4 then 0 else 1 end
    from public.training_camp_accommodation_tiers
    where is_active
      and base_weekly_cost>0
      and rest_quality between 0.80 and 1.30
  );

  -- Safe automatic completion repair: only close overdue camps when every
  -- scheduled day already has either a camp-day result or an applied activity.
  for r in
    select b.id
    from public.player_training_camp_bookings b
    where b.status in ('booked','active')
      and b.end_absolute_day<v_current_abs
      and not exists(
        select 1
        from generate_series(b.start_absolute_day,b.end_absolute_day) g(abs_day)
        cross join lateral public.absolute_game_day_v1(g.abs_day) gd
        where not exists(
          select 1 from public.player_training_camp_days d
          where d.booking_id=b.id and d.absolute_day=g.abs_day
        )
        and not exists(
          select 1 from public.player_daily_activity a
          where a.player_id=b.player_id
            and a.season=gd.season and a.month=gd.month and a.day=gd.day
            and a.effects_applied_at is not null
        )
      )
  loop
    if public.finalize_training_camp_booking_v1(r.id,'health_auto_repair') then
      v_repaired:=v_repaired+1;
    end if;
  end loop;

  select count(*) into v_overdue
  from public.player_training_camp_bookings
  where status in ('booked','active')
    and end_absolute_day<v_current_abs;

  select count(*) into v_overlaps
  from public.player_training_camp_bookings a
  join public.player_training_camp_bookings b
    on b.player_id=a.player_id
   and b.id>a.id
   and b.status in ('booked','active')
   and a.status in ('booked','active')
   and int4range(a.start_absolute_day,a.end_absolute_day,'[]')
       && int4range(b.start_absolute_day,b.end_absolute_day,'[]');

  select count(*) into v_missing_activity
  from public.player_training_camp_bookings b
  where b.status in ('booked','active')
    and b.booked_at>=v_enforced_from
    and (
      select count(*)
      from public.player_daily_activity a
      where a.player_id=b.player_id
        and a.source='training_camp_booking'
        and a.reference_id=b.id::text
        and public.game_day_absolute_v1(a.season,a.month,a.day)
            between b.start_absolute_day and b.end_absolute_day
    )<>b.duration_weeks*7;

  select count(*) into v_unprocessed_past_days
  from public.player_training_camp_bookings b
  join lateral generate_series(
    b.start_absolute_day,
    least(b.end_absolute_day,v_current_abs-1)
  ) g(abs_day) on b.start_absolute_day<=v_current_abs-1
  cross join lateral public.absolute_game_day_v1(g.abs_day) gd
  where b.status in ('booked','active','completed')
    and b.booked_at>=v_enforced_from
    and not exists(
      select 1 from public.player_training_camp_days d
      where d.booking_id=b.id and d.absolute_day=g.abs_day
    )
    and not exists(
      select 1 from public.player_daily_activity a
      where a.player_id=b.player_id
        and a.season=gd.season and a.month=gd.month and a.day=gd.day
        and a.effects_applied_at is not null
    );

  select count(*) into v_bad_finance
  from public.player_training_camp_bookings b
  where b.booked_at>=v_enforced_from
    and b.status in ('booked','active','completed','cancelled')
    and coalesce((
      select -sum(t.amount)
      from public.career_finance_transactions t
      where t.player_id=b.player_id
        and t.source_type='training_camp_booking'
        and t.source_id=b.id::text
        and t.amount<0
    ),0)<>b.total_cost;

  select count(*) into v_bad_cancel_refunds
  from public.player_training_camp_bookings b
  where b.booked_at>=v_enforced_from
    and b.status='cancelled'
    and coalesce((
      select sum(t.amount)
      from public.career_finance_transactions t
      where t.player_id=b.player_id
        and t.idempotency_key='training-camp-cancel-refund:'||b.id::text
        and t.amount>0
    ),0)<>b.total_cost;

  v_problem_count:=v_config_issues+v_overdue+v_overlaps+v_missing_activity+
                   v_unprocessed_past_days+v_bad_finance+v_bad_cancel_refunds;

  v_details:=jsonb_build_object(
    'current_absolute_day',v_current_abs,
    'enforced_from_at',v_enforced_from,
    'configuration_issues',v_config_issues,
    'overdue_bookings',v_overdue,
    'overlapping_live_bookings',v_overlaps,
    'bookings_missing_calendar_ownership',v_missing_activity,
    'unprocessed_past_camp_days',v_unprocessed_past_days,
    'booking_finance_mismatches',v_bad_finance,
    'cancellation_refund_mismatches',v_bad_cancel_refunds,
    'automatic_completions_repaired',v_repaired,
    'problem_count',v_problem_count
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:training_camp_lifecycle',
      'critical',
      'Training Camp operations require attention',
      format('%s Training Camp integrity issue(s) require attention.',v_problem_count),
      'business:training-camp-lifecycle',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:training-camp-lifecycle',
      'Training Camp booking, finance and lifecycle integrity is healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  )
  values(
    'check:training_camp_lifecycle',
    case when v_problem_count>0 then 'error' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s Training Camp integrity issue(s).',v_problem_count)
      else 'Training Camp booking and lifecycle are healthy.'
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
    'check:training_camp_lifecycle',
    'critical',
    'Training Camp health check failed',
    sqlerrm,
    'business:training-camp-lifecycle',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message,details
  )
  values(
    'check:training_camp_lifecycle',
    'error',
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    'Training Camp health check failed.',
    sqlerrm,
    jsonb_build_object('sqlstate',sqlstate)
  );

  return jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
end;
$$;

do $$
declare v_job_id bigint;
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
  $cron$select public.check_training_camp_health_v1();$cron$
);

-- First run now so Control Center immediately has a health state.
select public.check_training_camp_health_v1();
