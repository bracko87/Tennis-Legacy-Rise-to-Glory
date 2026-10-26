-- Runtime test of the real booked-flight creation and travel-day processing.
-- Applied only after the earlier synthetic foundation/jet/whitelist assertions.
-- No production Supabase connection or real player data.
alter table public.player_skills add column fatigue smallint not null default 0;
alter table public.player_location_state
  add column current_continent text,
  add column source_reference_id text,
  add column location_since_absolute_day integer,
  add column updated_at timestamptz default now();
alter table public.player_daily_activity
  add column source text,
  add column reference_id text,
  add column note text,
  add column updated_at timestamptz default now(),
  add column effects_applied_at timestamptz,
  add column effect_summary jsonb;
alter table public.player_daily_activity
  add constraint test_unique_daily_activity unique(player_id,season,month,day);
alter table public.player_travel_legs alter column id set default gen_random_uuid();
alter table public.player_travel_legs
  add column purpose text,
  add column source_location_type text,
  add column source_city text,
  add column source_country_code text,
  add column source_continent text,
  add column source_latitude double precision,
  add column source_longitude double precision,
  add column destination_location_type text,
  add column destination_continent text,
  add column destination_latitude double precision,
  add column destination_longitude double precision,
  add column source_reference_id text,
  add column destination_reference_id text,
  add column arrival_absolute_day integer,
  add column distance_km integer,
  add column estimated_cost integer,
  add column gross_arrival_fatigue smallint,
  add column travel_day_recovery smallint,
  add column arrival_fatigue smallint,
  add column travel_band text,
  add column travel_basis text,
  add column embedded_transition boolean not null default false,
  add column travel_class text,
  add column base_estimated_cost integer,
  add column price_multiplier numeric,
  add column base_arrival_fatigue smallint,
  add column fatigue_multiplier numeric,
  add column travel_mode text,
  add column jet_quote jsonb,
  add column processed_at timestamptz,
  add column updated_at timestamptz default now();

create or replace function public.country_continent_v1(p_country text)
returns text language sql immutable as $country$
 select case p_country when 'RS' then 'EU' when 'FR' then 'EU' when 'AU' then 'OC' else 'other' end
$country$;
create or replace function public.absolute_game_day_v1(p_absolute integer)
returns table(season integer,month integer,day integer)
language sql immutable as $absolute_day$
 select 1::integer, 1::integer, (p_absolute-390)::integer
$absolute_day$;
create or replace function public.post_tournament_hotel_night_v1(
 p_player uuid,p_competition uuid,p_day integer)
returns jsonb language sql as $hotel$
 select jsonb_build_object('status','fixture-no-hotel')
$hotel$;
create or replace function public.emit_notification_v1(
 p_owner uuid,p_player uuid,p_event_type text,p_title text,p_message text,
 p_url text,p_metadata jsonb,p_key text)
returns jsonb language sql as $notify$
 select jsonb_build_object('status','fixture-notification')
$notify$;

-- Synthetic travel quote, with distinct realistic prices and fatigue.
-- The actual inserted travel/finance/fatigue function bodies come from the migration.
create or replace function public.quote_travel_v2(
 p_source_city text,p_source_country text,p_source_lat double precision,
 p_source_lon double precision,p_dest_city text,p_dest_country text,
 p_dest_lat double precision,p_dest_lon double precision,
 p_class text default 'Economy',p_trip_mode text default 'one_way')
returns jsonb language sql stable as $quote_lifecycle$
 select jsonb_build_object(
   'distance_km',case when p_dest_city='Sydney' then 16000 when p_source_city=p_dest_city then 0 else 1600 end,
   'cost',case when p_trip_mode='round_trip' then 1000 else 500 end,
   'base_cost_one_way',500,'price_multiplier',1,
   'gross_arrival_fatigue',20,'base_arrival_fatigue',20,
   'travel_day_recovery',3,'arrival_fatigue',17,'fatigue_multiplier',1,
   'band',case when p_source_city=p_dest_city then 'same_city' else 'long' end,
   'basis','fixture-quote')
$quote_lifecycle$;

-- All six selected coaches accompany the player. No extra jet air tickets.
update public.player_tournament_preparation_plans
 set selected_staff_contract_ids=array[
  '10101010-1010-1010-1010-101010101001'::uuid,
  '10101010-1010-1010-1010-101010101002'::uuid,
  '10101010-1010-1010-1010-101010101003'::uuid,
  '10101010-1010-1010-1010-101010101004'::uuid,
  '10101010-1010-1010-1010-101010101005'::uuid,
  '10101010-1010-1010-1010-101010101006'::uuid]
 where player_id='11111111-1111-1111-1111-111111111111';

-- Previous test uses a future synthetic leg to check projection; remove it
-- before the journey lifecycle to avoid modeling two simultaneous trips.
delete from public.player_travel_legs
where id='33333333-3333-3333-3333-333333333333';
