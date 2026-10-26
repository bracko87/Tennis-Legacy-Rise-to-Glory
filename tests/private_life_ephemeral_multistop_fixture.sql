-- Runtime test fixtures for the actual refuelling route migration.
-- The existing disposable PostgreSQL database already has all nine approved
-- catalog models and the original owned-jet quote functions installed.
create or replace function public.great_circle_km_v1(
 p_lat1 numeric,p_lon1 numeric,p_lat2 numeric,p_lon2 numeric)
returns numeric language sql immutable as $haversine$
 select round((6371.0*acos(least(1.0,greatest(-1.0,
  sin(radians(p_lat1::double precision))*sin(radians(p_lat2::double precision))+
  cos(radians(p_lat1::double precision))*cos(radians(p_lat2::double precision))*
  cos(radians((p_lon2-p_lon1)::double precision))
 ))))::numeric,0)
$haversine$;

create or replace function public.resolve_travel_location_v1(
 p_city text,p_country text,p_lat double precision default null,p_lon double precision default null)
returns jsonb language sql stable as $coords$
 select jsonb_build_object(
  'city',p_city,'country_code',p_country,
  'latitude',case lower(coalesce(p_city,''))
   when 'belgrade' then 44.8184 when 'sydney' then -33.9399
   when 'honolulu' then 21.3245 when 'paris' then 49.0097
   when 'madrid' then 40.4983 else null end,
  'longitude',case lower(coalesce(p_city,''))
   when 'belgrade' then 20.3091 when 'sydney' then 151.1753
   when 'honolulu' then -157.9251 when 'paris' then 2.5479
   when 'madrid' then -3.5676 else null end,
  'coordinate_basis','exact')
$coords$;

insert into public.private_life_player_assets(id,player_id,catalog_code,acquisition_type,purchase_absolute_day)
values ('55555555-5555-5555-5555-555555555555',
 '11111111-1111-1111-1111-111111111111',
 'air_cessaro_citation_m3','purchase',391);

-- Production scheduling routine uses this rowtype; the synthetic DB models only the columns it accesses.
create table public.tournament_match_scheduling_rules (
 category_code text primary key,
 pre_match_arrival_buffer_minutes integer default 90,
 post_match_departure_buffer_minutes integer default 60
);
