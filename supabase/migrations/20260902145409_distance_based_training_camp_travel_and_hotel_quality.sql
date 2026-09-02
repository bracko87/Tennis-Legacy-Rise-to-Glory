create table if not exists public.training_travel_country_reference (
  country_code text primary key,
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  updated_at timestamptz not null default now()
);

alter table public.training_travel_country_reference enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='training_travel_country_reference' and policyname='training_travel_country_reference_read'
  ) then
    create policy training_travel_country_reference_read on public.training_travel_country_reference
      for select to authenticated using (true);
  end if;
end $$;

insert into public.training_travel_country_reference(country_code, latitude, longitude) values
('AE', 24.000000, 54.000000),('AL', 41.000000, 20.000000),('AR', -34.000000, -64.000000),('AT', 47.333333, 13.333333),('AU', -27.000000, 133.000000),
('BA', 44.000000, 18.000000),('BD', 24.000000, 90.000000),('BE', 50.833333, 4.000000),('BG', 43.000000, 25.000000),('BO', -17.000000, -65.000000),
('BR', -10.000000, -55.000000),('BS', 24.250000, -76.000000),('CA', 60.000000, -95.000000),('CH', 47.000000, 8.000000),('CI', 8.000000, -5.000000),
('CL', -30.000000, -71.000000),('CN', 35.000000, 105.000000),('CO', 4.000000, -72.000000),('CR', 10.000000, -84.000000),('CZ', 49.750000, 15.500000),
('DE', 51.000000, 9.000000),('DK', 56.000000, 10.000000),('DO', 19.000000, -70.666667),('EC', -2.000000, -77.500000),('EE', 59.000000, 26.000000),
('EG', 27.000000, 30.000000),('ES', 40.000000, -4.000000),('ET', 8.000000, 38.000000),('FI', 64.000000, 26.000000),('FJ', -18.000000, 175.000000),
('FR', 46.000000, 2.000000),('GB', 54.000000, -2.000000),('GF', 4.000000, -53.000000),('GH', 8.000000, -2.000000),('GR', 39.000000, 22.000000),
('GT', 15.500000, -90.250000),('GY', 5.000000, -59.000000),('HK', 22.250000, 114.166667),('HR', 45.166667, 15.500000),('HU', 47.000000, 20.000000),
('ID', -5.000000, 120.000000),('IE', 53.000000, -8.000000),('IL', 31.500000, 34.750000),('IN', 20.000000, 77.000000),('IT', 42.833333, 12.833333),
('JM', 18.250000, -77.500000),('JP', 36.000000, 138.000000),('KE', 1.000000, 38.000000),('KG', 41.000000, 75.000000),('KR', 37.000000, 127.500000),
('KZ', 48.000000, 68.000000),('LT', 56.000000, 24.000000),('LU', 49.750000, 6.166667),('LV', 57.000000, 25.000000),('MA', 32.000000, -5.000000),
('MK', 41.600000, 21.700000),('MU', -20.283333, 57.550000),('MX', 23.000000, -102.000000),('MY', 2.500000, 112.500000),('NA', -22.000000, 17.000000),
('NC', -21.500000, 165.500000),('NG', 10.000000, 8.000000),('NL', 52.500000, 5.750000),('NO', 62.000000, 10.000000),('NP', 28.000000, 84.000000),
('NZ', -41.000000, 174.000000),('OM', 21.000000, 57.000000),('PA', 9.000000, -80.000000),('PE', -10.000000, -76.000000),('PG', -6.000000, 147.000000),
('PH', 13.000000, 122.000000),('PK', 30.000000, 70.000000),('PL', 52.000000, 20.000000),('PR', 18.250000, -66.500000),('PT', 39.500000, -8.000000),
('PY', -23.000000, -58.000000),('QA', 25.500000, 51.250000),('RO', 46.000000, 25.000000),('RS', 44.130502, 16.428418),('RU', 60.000000, 100.000000),
('RW', -2.000000, 30.000000),('SA', 25.000000, 45.000000),('SC', -4.583333, 55.666667),('SE', 62.000000, 15.000000),('SG', 1.366667, 103.800000),
('SI', 46.116667, 14.816667),('SK', 48.666667, 19.500000),('SN', 14.000000, -14.000000),('SR', 4.000000, -56.000000),('TH', 15.000000, 100.000000),
('TN', 34.000000, 9.000000),('TR', 39.000000, 35.000000),('TW', 23.500000, 121.000000),('UA', 49.000000, 32.000000),('US', 38.000000, -97.000000),
('UY', -33.000000, -56.000000),('UZ', 41.000000, 64.000000),('VE', 8.000000, -66.000000),('VN', 16.166667, 107.833333),('ZA', -29.000000, 24.000000),('ZM', -15.000000, 30.000000)
on conflict(country_code) do update set latitude=excluded.latitude, longitude=excluded.longitude, updated_at=now();

create or replace function public.great_circle_km_v1(p_lat1 numeric, p_lon1 numeric, p_lat2 numeric, p_lon2 numeric)
returns numeric language sql immutable as $$
  select round((6371.0 * acos(least(1.0, greatest(-1.0,
    sin(radians(p_lat1::double precision)) * sin(radians(p_lat2::double precision)) +
    cos(radians(p_lat1::double precision)) * cos(radians(p_lat2::double precision)) *
    cos(radians((p_lon2-p_lon1)::double precision))
  ))))::numeric, 0);
$$;

create or replace function public.training_camp_travel_quote_v2(p_origin_city text,p_origin_country_code text,p_destination_city text,p_destination_country_code text)
returns jsonb language plpgsql stable set search_path to 'public' as $$
declare
  v_origin public.training_travel_country_reference%rowtype; v_destination public.training_travel_country_reference%rowtype;
  v_origin_continent text; v_destination_continent text; v_km numeric; v_round_trip numeric; v_cost integer; v_fatigue integer;
begin
  if upper(coalesce(p_origin_country_code,''))=upper(coalesce(p_destination_country_code,'')) then
    if lower(trim(coalesce(p_origin_city,'')))<>'' and lower(trim(coalesce(p_origin_city,'')))=lower(trim(coalesce(p_destination_city,''))) then
      return jsonb_build_object('cost',40,'one_way_km',0,'round_trip_km',0,'band','same_city','basis','exact_city_match','arrival_fatigue',1,'formula','Same-city local transfer');
    end if;
    return jsonb_build_object('cost',90,'one_way_km',null,'round_trip_km',null,'band','domestic','basis','same_country_estimate','arrival_fatigue',2,'formula','Domestic country estimate');
  end if;
  select * into v_origin from public.training_travel_country_reference where country_code=upper(p_origin_country_code);
  select * into v_destination from public.training_travel_country_reference where country_code=upper(p_destination_country_code);
  v_origin_continent:=public.country_continent_v1(upper(p_origin_country_code));
  v_destination_continent:=public.country_continent_v1(upper(p_destination_country_code));
  if v_origin.country_code is not null and v_destination.country_code is not null then
    v_km:=public.great_circle_km_v1(v_origin.latitude,v_origin.longitude,v_destination.latitude,v_destination.longitude); v_round_trip:=v_km*2;
    if v_origin_continent=v_destination_continent then
      v_cost:=(round((greatest(180::numeric,least(700::numeric,80::numeric+v_km*0.11)))/10.0)*10)::integer;
      v_fatigue:=least(6,greatest(2,2+round(v_km/1800.0)::integer));
      return jsonb_build_object('cost',v_cost,'one_way_km',v_km::integer,'round_trip_km',v_round_trip::integer,'band','regional','basis','country_centroid_distance','arrival_fatigue',v_fatigue,'formula','Regional fare = $80 + 0.11 × one-way km, capped $180–$700');
    end if;
    v_cost:=(round((greatest(500::numeric,least(2400::numeric,220::numeric+v_km*0.10)))/10.0)*10)::integer;
    v_fatigue:=least(14,greatest(5,5+round(v_km/2200.0)::integer));
    return jsonb_build_object('cost',v_cost,'one_way_km',v_km::integer,'round_trip_km',v_round_trip::integer,'band','intercontinental','basis','country_centroid_distance','arrival_fatigue',v_fatigue,'formula','Long-haul fare = $220 + 0.10 × one-way km, capped $500–$2,400');
  end if;
  v_cost:=public.training_camp_travel_cost_v1(p_origin_city,p_origin_country_code,v_origin_continent,p_destination_city,p_destination_country_code,v_destination_continent);
  return jsonb_build_object('cost',v_cost,'one_way_km',null,'round_trip_km',null,'band',case when v_origin_continent=v_destination_continent then 'regional' else 'intercontinental' end,'basis','continent_fallback','arrival_fatigue',case when v_origin_continent=v_destination_continent then 4 else 9 end,'formula','Fallback continent estimate because geographic reference data is unavailable');
end; $$;

alter table public.player_training_camp_bookings add column if not exists travel_distance_km integer, add column if not exists travel_round_trip_km integer, add column if not exists travel_band text, add column if not exists travel_basis text, add column if not exists travel_arrival_fatigue smallint;

create or replace function public.quote_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star'::text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_user uuid:=auth.uid(); v_player public.players%rowtype; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_hotel public.training_camp_accommodation_tiers%rowtype; v_state public.player_location_state%rowtype;
  v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_training_total integer; v_hotel_weekly integer; v_hotel_total integer; v_travel integer; v_total integer;
  v_origin_city text; v_origin_country text; v_origin_continent text; v_origin_precision text; v_travel_quote jsonb;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where owner_user_id=v_user; if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if;
  select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active;
  select * into v_hotel from public.training_camp_accommodation_tiers where slug=p_accommodation_slug and is_active; if v_hotel.id is null then raise exception 'Accommodation option not found.'; end if;
  if p_duration_weeks not between 1 and 4 then raise exception 'Training camp duration must be between 1 and 4 weeks.'; end if;
  if p_start_week not between 1 and 52 then raise exception 'Start week must be between 1 and 52.'; end if;
  if p_start_week+p_duration_weeks-1>52 then raise exception 'Training camp cannot extend beyond Season Week 52.'; end if;
  v_start_abs:=public.training_camp_week_start_absolute_v1(p_start_season,p_start_week); v_end_abs:=v_start_abs+p_duration_weeks*7-1;
  select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs<v_current_abs then raise exception 'Training camp must begin at the start of a current or future competition week.'; end if;
  select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);
  select * into v_state from public.player_location_state where player_id=v_player.id;
  v_origin_city:=coalesce(nullif(v_state.current_city,''),nullif(v_player.home_city,''),'Home base'); v_origin_country:=coalesce(nullif(v_state.current_country_code,''),v_player.country_code); v_origin_continent:=coalesce(nullif(v_state.current_continent,''),public.country_continent_v1(v_origin_country)); v_origin_precision:=case when coalesce(nullif(v_state.current_city,''),nullif(v_player.home_city,'')) is null then 'country' else 'city_label' end;
  v_training_total:=v_program.weekly_cost*p_duration_weeks; v_hotel_weekly:=round((v_hotel.base_weekly_cost*v_location.cost_index)/10.0)::integer*10; v_hotel_total:=v_hotel_weekly*p_duration_weeks;
  v_travel_quote:=public.training_camp_travel_quote_v2(v_origin_city,v_origin_country,v_location.city,v_location.country_code); v_travel:=(v_travel_quote->>'cost')::integer; v_total:=v_training_total+v_hotel_total+v_travel;
  return jsonb_build_object('program_id',v_program.id,'camp_name',v_program.name,'training_quality',jsonb_build_object('tier',v_program.quality_tier,'multiplier',v_program.quality_multiplier),'quality_tier',v_program.quality_tier,'facility_rating',v_program.rating,'quality_multiplier',v_program.quality_multiplier,'start_season',p_start_season,'start_week',p_start_week,'start_absolute_day',v_start_abs,'end_absolute_day',v_end_abs,'start',jsonb_build_object('season',v_start.season,'month',v_start.month,'day',v_start.day),'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),'duration_weeks',p_duration_weeks,'origin',jsonb_build_object('city',v_origin_city,'country_code',v_origin_country,'continent',v_origin_continent,'precision',v_origin_precision),'destination',jsonb_build_object('city',v_location.city,'country',v_location.country,'country_code',v_location.country_code,'continent',v_location.continent,'cost_index',v_location.cost_index),'training_fee_weekly',v_program.weekly_cost,'training_fee_total',v_training_total,'accommodation',jsonb_build_object('id',v_hotel.id,'slug',v_hotel.slug,'name',v_hotel.name,'stars',v_hotel.star_rating,'base_weekly_cost',v_hotel.base_weekly_cost,'destination_cost_index',v_location.cost_index,'weekly_cost',v_hotel_weekly,'total',v_hotel_total,'rest_quality',v_hotel.rest_quality,'fatigue_mitigation',v_hotel.fatigue_mitigation,'weekly_morale_bonus',v_hotel.weekly_morale_bonus,'weekly_focus_bonus',v_hotel.weekly_focus_bonus,'description',v_hotel.description),'travel',v_travel_quote,'travel_cost',v_travel,'travel_type','Round-trip estimate','staff_count',0,'staff_cost',0,'grand_total',v_total);
end; $$;

create or replace function public.book_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star'::text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_user uuid:=auth.uid(); v_player_id uuid; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_quote jsonb; v_hotel_id uuid; v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_booking public.player_training_camp_bookings%rowtype; d record;
begin
  if v_user is null then raise exception 'Authentication required.'; end if; select id into v_player_id from public.players where owner_user_id=v_user; if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if; select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active;
  v_quote:=public.quote_training_camp_v2(p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug); v_start_abs:=(v_quote->>'start_absolute_day')::integer; v_end_abs:=(v_quote->>'end_absolute_day')::integer; v_hotel_id:=(v_quote->'accommodation'->>'id')::uuid;
  select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs<v_current_abs then raise exception 'Training camp cannot start in the past.'; end if;
  if exists(select 1 from public.player_training_camp_bookings b where b.player_id=v_player_id and b.status in ('booked','active') and int4range(b.start_absolute_day,b.end_absolute_day,'[]') && int4range(v_start_abs,v_end_abs,'[]')) then raise exception 'Another training camp overlaps the selected weeks.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_daily_activity a on a.player_id=v_player_id and a.season=gd.season and a.month=gd.month and a.day=gd.day where a.activity_type<>'home' or a.effects_applied_at is not null) then raise exception 'The selected weeks contain travel, tournament, injury, another camp, or an already processed activity.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_training_sessions s on s.player_id=v_player_id and s.season=gd.season and s.month=gd.month and s.day=gd.day) then raise exception 'Regular training has already been processed during one of the selected weeks.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.tournament_editions te on te.season_number=gd.season join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id join public.tournament_applications ta on ta.competition_id=wc.id and ta.player_id=v_player_id where gd.season_week>0 and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')) then raise exception 'A tournament application or commitment overlaps the selected camp weeks.'; end if;
  select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);
  insert into public.player_training_camp_bookings(player_id,program_id,start_absolute_day,end_absolute_day,start_season,start_month,start_day,end_season,end_month,end_day,duration_weeks,weekly_cost,total_cost,status,start_season_week,accommodation_tier_id,training_fee_total,accommodation_weekly_cost,accommodation_total,travel_cost,staff_count,staff_travel_cost,staff_accommodation_cost,staff_total_cost,origin_city,origin_country_code,origin_continent,travel_distance_km,travel_round_trip_km,travel_band,travel_basis,travel_arrival_fatigue)
  values(v_player_id,v_program.id,v_start_abs,v_end_abs,v_start.season,v_start.month,v_start.day,v_end.season,v_end.month,v_end.day,p_duration_weeks,v_program.weekly_cost,(v_quote->>'grand_total')::integer,'booked',p_start_week,v_hotel_id,(v_quote->>'training_fee_total')::integer,(v_quote->'accommodation'->>'weekly_cost')::integer,(v_quote->'accommodation'->>'total')::integer,(v_quote->>'travel_cost')::integer,0,0,0,0,v_quote->'origin'->>'city',v_quote->'origin'->>'country_code',v_quote->'origin'->>'continent',nullif(v_quote->'travel'->>'one_way_km','')::integer,nullif(v_quote->'travel'->>'round_trip_km','')::integer,v_quote->'travel'->>'band',v_quote->'travel'->>'basis',nullif(v_quote->'travel'->>'arrival_fatigue','')::smallint) returning * into v_booking;
  for d in select gd.* from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd loop insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note) values(v_player_id,d.season,d.month,d.day,'training_camp','training_camp_booking',v_booking.id::text,v_program.name) on conflict(player_id,season,month,day) do update set activity_type='training_camp',source='training_camp_booking',reference_id=v_booking.id::text,note=v_program.name,updated_at=now(); end loop;
  perform public.emit_notification_v1(v_user,v_player_id,'training.camp.booked','Training camp booked',format('%s in %s is booked for Season Week %s for %s week%s.',v_program.name,v_location.city,p_start_week,p_duration_weeks,case when p_duration_weeks=1 then '' else 's' end),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost),'training-camp-booked:'||v_booking.id::text);
  return jsonb_build_object('status','booked','booking_id',v_booking.id,'camp_name',v_program.name,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost,'quote',v_quote);
end; $$;