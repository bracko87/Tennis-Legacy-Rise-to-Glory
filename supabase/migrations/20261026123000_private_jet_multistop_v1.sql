-- Private-jet multi-stop routing, sourced from approved nine-aircraft fleet.
-- Synthetic game refuelling network: airport operations, permissions, weather,
-- visas, and actual runway suitability are NOT certified or modeled here.
-- Source-only until full isolated database and gameplay release gates are met.

create table if not exists public.private_jet_refuel_hubs (
 code text primary key,
 airport_name text not null,
 city text not null,
 country_code text not null,
 latitude numeric(9,5) not null check(latitude between -90 and 90),
 longitude numeric(9,5) not null check(longitude between -180 and 180),
 enabled boolean not null default true
);
alter table public.private_jet_refuel_hubs enable row level security;
revoke all on public.private_jet_refuel_hubs from public,anon,authenticated;

insert into public.private_jet_refuel_hubs
(code,airport_name,city,country_code,latitude,longitude) values
('LHR','Heathrow','London','GB',51.4700,-0.4543),
('CDG','Charles de Gaulle','Paris','FR',49.0097,2.5479),
('LIS','Humberto Delgado','Lisbon','PT',38.7742,-9.1342),
('MAD','Barajas','Madrid','ES',40.4983,-3.5676),
('FCO','Fiumicino','Rome','IT',41.8003,12.2389),
('ATH','Athens International','Athens','GR',37.9364,23.9445),
('BEG','Nikola Tesla','Belgrade','RS',44.8184,20.3091),
('IST','Istanbul Airport','Istanbul','TR',41.2753,28.7519),
('CAI','Cairo International','Cairo','EG',30.1219,31.4056),
('ALG','Houari Boumediene','Algiers','DZ',36.6910,3.2154),
('CMN','Mohammed V','Casablanca','MA',33.3675,-7.5899),
('DKR','Blaise Diagne','Dakar','SN',14.6709,-17.0733),
('ACC','Kotoka','Accra','GH',5.6052,-0.1668),
('LOS','Murtala Muhammed','Lagos','NG',6.5774,3.3212),
('ADD','Bole','Addis Ababa','ET',8.9779,38.7993),
('NBO','Jomo Kenyatta','Nairobi','KE',-1.3192,36.9278),
('DAR','Julius Nyerere','Dar es Salaam','TZ',-6.8781,39.2026),
('JNB','O. R. Tambo','Johannesburg','ZA',-26.1367,28.2411),
('CPT','Cape Town International','Cape Town','ZA',-33.9715,18.6021),
('JED','King Abdulaziz','Jeddah','SA',21.6796,39.1565),
('RUH','King Khalid','Riyadh','SA',24.9576,46.6988),
('DXB','Dubai International','Dubai','AE',25.2532,55.3657),
('MCT','Muscat International','Muscat','OM',23.5933,58.2844),
('KHI','Jinnah International','Karachi','PK',24.9065,67.1608),
('DEL','Indira Gandhi','New Delhi','IN',28.5562,77.1000),
('BOM','Chhatrapati Shivaji Maharaj','Mumbai','IN',19.0896,72.8656),
('BLR','Kempegowda','Bengaluru','IN',13.1986,77.7066),
('MAA','Chennai International','Chennai','IN',12.9941,80.1709),
('CMB','Bandaranaike','Colombo','LK',7.1808,79.8841),
('BKK','Suvarnabhumi','Bangkok','TH',13.6900,100.7501),
('RGN','Yangon International','Yangon','MM',16.9073,96.1332),
('KUL','Kuala Lumpur International','Kuala Lumpur','MY',2.7456,101.7072),
('SIN','Changi','Singapore','SG',1.3644,103.9915),
('CGK','Soekarno-Hatta','Jakarta','ID',-6.1256,106.6559),
('DPS','Ngurah Rai','Denpasar','ID',-8.7482,115.1672),
('DVO','Francisco Bangoy','Davao','PH',7.1255,125.6458),
('MNL','Ninoy Aquino','Manila','PH',14.5086,121.0198),
('HKG','Hong Kong International','Hong Kong','HK',22.3080,113.9185),
('CAN','Baiyun','Guangzhou','CN',23.3924,113.2988),
('PVG','Pudong','Shanghai','CN',31.1443,121.8083),
('ICN','Incheon','Seoul','KR',37.4602,126.4407),
('NRT','Narita','Tokyo','JP',35.7720,140.3929),
('KIX','Kansai','Osaka','JP',34.4347,135.2440),
('DRW','Darwin International','Darwin','AU',-12.4147,130.8767),
('CNS','Cairns Airport','Cairns','AU',-16.8858,145.7553),
('BNE','Brisbane Airport','Brisbane','AU',-27.3842,153.1175),
('SYD','Kingsford Smith','Sydney','AU',-33.9399,151.1753),
('MEL','Melbourne Airport','Melbourne','AU',-37.6733,144.8433),
('PER','Perth Airport','Perth','AU',-31.9403,115.9672),
('ADL','Adelaide Airport','Adelaide','AU',-34.9450,138.5306),
('AKL','Auckland Airport','Auckland','NZ',-37.0082,174.7850),
('CHC','Christchurch Airport','Christchurch','NZ',-43.4894,172.5322),
('KEF','Keflavik','Reykjavik','IS',63.9850,-22.6056),
('GOH','Nuuk Airport','Nuuk','GL',64.1909,-51.6781),
('YYT','St Johns','St Johns','CA',47.6186,-52.7519),
('YHZ','Halifax Stanfield','Halifax','CA',44.8808,-63.5086),
('JFK','John F Kennedy','New York','US',40.6413,-73.7781),
('BOS','Logan','Boston','US',42.3656,-71.0096),
('ORD','OHare','Chicago','US',41.9742,-87.9073),
('DEN','Denver International','Denver','US',39.8561,-104.6737),
('SFO','San Francisco International','San Francisco','US',37.6213,-122.3790),
('LAX','Los Angeles International','Los Angeles','US',33.9416,-118.4085),
('MIA','Miami International','Miami','US',25.7954,-80.2901),
('MEX','Benito Juarez','Mexico City','MX',19.4361,-99.0719),
('PTY','Tocumen','Panama City','PA',9.0714,-79.3835),
('BOG','El Dorado','Bogota','CO',4.7016,-74.1469),
('LIM','Jorge Chavez','Lima','PE',-12.0219,-77.1143),
('GRU','Guarulhos','Sao Paulo','BR',-23.4356,-46.4731),
('GIG','Galeao','Rio de Janeiro','BR',-22.8090,-43.2506),
('EZE','Ezeiza','Buenos Aires','AR',-34.8222,-58.5358),
('SCL','Arturo Merino Benitez','Santiago','CL',-33.3928,-70.7858),
('HNL','Honolulu International','Honolulu','US',21.3245,-157.9251),
('ANC','Ted Stevens Anchorage','Anchorage','US',61.1744,-149.9964)
on conflict(code) do nothing;

create or replace function public.private_jet_refuel_route_v1(
 p_source_city text,p_source_country text,p_dest_city text,p_dest_country text,
 p_aircraft_range_km integer,p_max_stops integer default 18
) returns jsonb language plpgsql stable security definer
set search_path='public','pg_temp' as $route$
declare
 v_source jsonb;v_dest jsonb;
 v_nodes jsonb[]:=array[]::jsonb[];
 v_scores numeric[]:=array[]::numeric[];
 v_previous integer[]:=array[]::integer[];
 v_seen boolean[]:=array[]::boolean[];
 v_count integer;v_dest_idx integer;v_best_idx integer;
 v_best_score numeric;v_best_candidate numeric;v_leg numeric;
 v_i integer;v_j integer;v_k integer;v_prev integer;
 v_max_leg integer;v_route_distance integer:=0;v_legs_count integer:=0;
 v_legs jsonb:='[]'::jsonb;v_stops jsonb:='[]'::jsonb;
 h record;
begin
 if coalesce(p_aircraft_range_km,0)<500 or coalesce(p_max_stops,0)<0 then
  return jsonb_build_object('active',false,'reason','invalid_aircraft_range');
 end if;
 v_source:=public.resolve_travel_location_v1(p_source_city,p_source_country,null,null);
 v_dest:=public.resolve_travel_location_v1(p_dest_city,p_dest_country,null,null);
 if v_source->>'latitude' is null or v_source->>'longitude' is null or
    v_dest->>'latitude' is null or v_dest->>'longitude' is null then
  return jsonb_build_object('active',false,'reason','unresolved_airport_coordinates');
 end if;
 v_nodes:=array_append(v_nodes,jsonb_build_object(
    'code','ORIGIN','city',p_source_city,'country_code',p_source_country,
    'latitude',(v_source->>'latitude')::numeric,'longitude',(v_source->>'longitude')::numeric));
 for h in select * from public.private_jet_refuel_hubs where enabled order by code loop
  v_nodes:=array_append(v_nodes,jsonb_build_object(
    'code',h.code,'city',h.city,'country_code',h.country_code,
    'latitude',h.latitude,'longitude',h.longitude));
 end loop;
 v_nodes:=array_append(v_nodes,jsonb_build_object(
    'code','DESTINATION','city',p_dest_city,'country_code',p_dest_country,
    'latitude',(v_dest->>'latitude')::numeric,'longitude',(v_dest->>'longitude')::numeric));
 v_count:=array_length(v_nodes,1);v_dest_idx:=v_count;
 -- Reserve 6% of an aircraft's stated maximum range for routing margin.
 v_max_leg:=floor(p_aircraft_range_km*0.94)::integer;
 for v_i in 1..v_count loop
  v_scores:=array_append(v_scores,case when v_i=1 then 0::numeric else 1000000000::numeric end);
  v_previous:=array_append(v_previous,0);
  v_seen:=array_append(v_seen,false);
 end loop;
 -- Dijkstra over a bounded airport graph; penalty favors fewer fuel stops.
 for v_i in 1..v_count loop
  v_best_score:=1000000000;v_best_idx:=0;
  for v_j in 1..v_count loop
   if not v_seen[v_j] and v_scores[v_j]<v_best_score then
    v_best_score:=v_scores[v_j];v_best_idx:=v_j;
   end if;
  end loop;
  exit when v_best_idx=0 or v_best_idx=v_dest_idx;
  v_seen[v_best_idx]:=true;
  for v_j in 2..v_count loop
   if v_j=v_best_idx or v_seen[v_j] then continue;end if;
   v_leg:=public.great_circle_km_v1(
    (v_nodes[v_best_idx]->>'latitude')::numeric,
    (v_nodes[v_best_idx]->>'longitude')::numeric,
    (v_nodes[v_j]->>'latitude')::numeric,
    (v_nodes[v_j]->>'longitude')::numeric);
   if v_leg>v_max_leg then continue;end if;
   -- Include ground handling on each extra stop in equivalent distance.
   v_best_candidate:=v_scores[v_best_idx]+greatest(0,v_leg)
     +case when v_j=v_dest_idx then 0 else 250 end;
   if v_best_candidate<v_scores[v_j] then
    v_scores[v_j]:=v_best_candidate;
    v_previous[v_j]:=v_best_idx;
   end if;
  end loop;
 end loop;
 if v_previous[v_dest_idx]=0 then
  return jsonb_build_object('active',false,'reason','no_refuelling_route_within_range');
 end if;
 v_k:=v_dest_idx;
 while v_k<>1 loop
  v_prev:=v_previous[v_k];v_legs_count:=v_legs_count+1;
  if v_prev=0 or v_legs_count>least(30,p_max_stops+1) then
   return jsonb_build_object('active',false,'reason','too_many_refuelling_stops');
  end if;
  v_leg:=public.great_circle_km_v1(
   (v_nodes[v_prev]->>'latitude')::numeric,
   (v_nodes[v_prev]->>'longitude')::numeric,
   (v_nodes[v_k]->>'latitude')::numeric,
   (v_nodes[v_k]->>'longitude')::numeric);
  v_route_distance:=v_route_distance+round(v_leg)::integer;
  v_legs:=jsonb_build_array(jsonb_build_object(
   'from',v_nodes[v_prev]->>'city','to',v_nodes[v_k]->>'city',
   'from_code',v_nodes[v_prev]->>'code','to_code',v_nodes[v_k]->>'code',
   'distance_km',round(v_leg)::integer))||v_legs;
  if v_k<>v_dest_idx then
   v_stops:=jsonb_build_array(jsonb_build_object(
    'airport_code',v_nodes[v_k]->>'code','city',v_nodes[v_k]->>'city',
    'country_code',v_nodes[v_k]->>'country_code'))||v_stops;
  end if;
  v_k:=v_prev;
 end loop;
 return jsonb_build_object('active',true,
  'leg_count',v_legs_count,'stop_count',greatest(0,v_legs_count-1),
  'route_distance_km',v_route_distance,'legs',v_legs,'refuel_stops',v_stops,
  'range_margin_percent',6);
end;$route$;
revoke all on function public.private_jet_refuel_route_v1(text,text,text,text,integer,integer) from public,anon,authenticated;


-- Override the same booking quote signature consumed by selection, itinerary,
-- staff fare, finance, player fatigue and UI. No new payment path is created.
create or replace function public.quote_private_jet_leg_v1(
 p_player_id uuid,p_source_city text,p_source_country text,
 p_destination_city text,p_destination_country text,
 p_distance_km integer,p_staff_count integer default 0,
 p_requested_asset_id uuid default null,p_departure_day integer default null
) returns jsonb language plpgsql stable security definer
set search_path='public','pg_temp' as $multistop_quote$
declare
 v_jet record;v_home jsonb;v_last record;v_route jsonb;v_reposition_route jsonb;
 v_aircraft_city text;v_aircraft_country text;v_reposition_quote jsonb;
 v_range integer;v_capacity integer;v_base integer;v_rate numeric;
 v_comfort_bps integer;v_effective_bps integer;
 v_speed numeric;v_handling numeric;v_hours numeric;v_days integer;
 v_leg_distance integer;v_stop_count integer:=0;v_route_distance integer;
 v_reposition_distance integer:=0;v_reposition_stops integer:=0;v_reposition_cost integer:=0;
 v_route_legs jsonb:='[]'::jsonb;v_refuel_stops jsonb:='[]'::jsonb;
begin
 if coalesce(p_distance_km,0)<1 then
  return jsonb_build_object('active',false,'reason','no_flight');
 end if;
 if p_staff_count<0 or p_staff_count>6 then
  return jsonb_build_object('active',false,'reason','invalid_staff_count');
 end if;
 select a.id,c.name,c.code,c.metadata,a.purchase_price into v_jet
 from public.private_life_player_assets a
 join public.private_life_asset_catalog c on c.code=a.catalog_code
 where a.player_id=p_player_id and a.sold_absolute_day is null
   and c.category='private_jet'
   and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false)
   and (p_requested_asset_id is null or a.id=p_requested_asset_id)
 order by coalesce((c.metadata->>'travel_fatigue_reduction_bps')::integer,0) desc,
          a.purchase_price desc limit 1;
 if v_jet.id is null then
  return jsonb_build_object('active',false,'reason','no_approved_owned_jet');
 end if;
 v_range:=coalesce((v_jet.metadata->>'max_range_km')::integer,0);
 v_capacity:=coalesce((v_jet.metadata->>'passenger_capacity')::integer,0);
 if v_capacity<1+coalesce(p_staff_count,0) then
  return jsonb_build_object('active',false,'reason','insufficient_passenger_seats',
   'required_seats',1+coalesce(p_staff_count,0),'passenger_capacity',v_capacity);
 end if;
 v_base:=coalesce((v_jet.metadata->>'base_trip_cost')::integer,0);
 v_rate:=coalesce((v_jet.metadata->>'cost_per_km')::numeric,0);
 v_speed:=greatest(400,coalesce((v_jet.metadata->>'cruise_speed_kmh')::numeric,750));
 v_handling:=greatest(0,coalesce((v_jet.metadata->>'airport_handling_hours')::numeric,1.5));
 v_comfort_bps:=least(5000,greatest(0,coalesce((v_jet.metadata->>'travel_fatigue_reduction_bps')::integer,0)));
 if v_range<500 or v_base<1 or v_rate<=0 then
  return jsonb_build_object('active',false,'reason','invalid_jet_specification');
 end if;

 if p_distance_km<=floor(v_range*0.94) then
  -- For known direct routes retain existing game distance/pricing exactly.
  v_route_distance:=p_distance_km;
  v_stop_count:=0;
  v_route_legs:=jsonb_build_array(jsonb_build_object(
   'from',p_source_city,'to',p_destination_city,'distance_km',p_distance_km));
 else
  v_route:=public.private_jet_refuel_route_v1(
    p_source_city,p_source_country,p_destination_city,p_destination_country,v_range,18);
  if not coalesce((v_route->>'active')::boolean,false) then
   return jsonb_build_object('active',false,'reason',coalesce(v_route->>'reason','no_refuel_route'),
    'aircraft',v_jet.name,'max_range_km',v_range);
  end if;
  v_route_distance:=(v_route->>'route_distance_km')::integer;
  v_stop_count:=(v_route->>'stop_count')::integer;
  v_route_legs:=v_route->'legs';
  v_refuel_stops:=v_route->'refuel_stops';
 end if;
 -- A few short legs can be longer than a straight-line distance; charging by
 -- actual planned distance prevents a very small jet becoming a cheap shortcut.
 v_effective_bps:=greatest(500,v_comfort_bps-v_stop_count*350);
 v_hours:=round(v_route_distance::numeric/v_speed+v_handling+v_stop_count*1.8,1);
 -- Cap of 18 flight/handling hours in one game day; longer routes need days.
 v_days:=greatest(1,ceil(v_hours/18.0)::integer);

 select pos.city,pos.country_code into v_aircraft_city,v_aircraft_country
 from public.player_private_jet_positions pos where pos.owned_asset_id=v_jet.id;
 if p_departure_day is not null then
  select destination_city,destination_country_code into v_last
  from public.player_travel_legs
  where jet_asset_id=v_jet.id and status='planned'
    and departure_absolute_day<=p_departure_day
  order by departure_absolute_day desc,created_at desc limit 1;
  if v_last.destination_city is not null then
   v_aircraft_city:=v_last.destination_city;
   v_aircraft_country:=v_last.destination_country_code;
  end if;
 end if;
 if v_aircraft_city is null then
  v_home:=public.get_player_home_base_v1(p_player_id);
  v_aircraft_city:=v_home->>'city';
  v_aircraft_country:=v_home->>'country_code';
 end if;
 if lower(coalesce(v_aircraft_city,''))<>lower(coalesce(p_source_city,'')) or
    upper(coalesce(v_aircraft_country,''))<>upper(coalesce(p_source_country,'')) then
  v_reposition_quote:=public.quote_travel_v2(
    v_aircraft_city,v_aircraft_country,null,null,
    p_source_city,p_source_country,null,null,'Economy','one_way');
  v_leg_distance:=coalesce((v_reposition_quote->>'distance_km')::integer,0);
  if v_leg_distance>floor(v_range*0.94) then
   v_reposition_route:=public.private_jet_refuel_route_v1(
    v_aircraft_city,v_aircraft_country,p_source_city,p_source_country,v_range,18);
   if not coalesce((v_reposition_route->>'active')::boolean,false) then
    return jsonb_build_object('active',false,'reason','jet_reposition_route_unavailable');
   end if;
   v_reposition_distance:=(v_reposition_route->>'route_distance_km')::integer;
   v_reposition_stops:=(v_reposition_route->>'stop_count')::integer;
  else
   v_reposition_distance:=v_leg_distance;
  end if;
  -- Same existing base + distance fee for repositioning, plus stop fees.
  v_reposition_cost:=v_base+ceil(v_reposition_distance*v_rate)::integer
       +v_reposition_stops*1800;
 end if;

 return jsonb_build_object(
  'active',true,'owned_asset_id',v_jet.id,'catalog_code',v_jet.code,
  'name',v_jet.name,'max_range_km',v_range,'distance_km',p_distance_km,
  'route_distance_km',v_route_distance,'leg_count',v_stop_count+1,
  'stop_count',v_stop_count,'refuel_stops',v_refuel_stops,'route_legs',v_route_legs,
  'passenger_capacity',v_capacity,'party_size',1+coalesce(p_staff_count,0),
  'staff_on_jet',coalesce(p_staff_count,0),'staff_commercial',0,
  'base_fatigue_reduction_bps',v_comfort_bps,
  'reduction_bps',v_effective_bps,'reduction_percent',round(v_effective_bps::numeric/100),
  'refuel_fatigue_penalty_bps',v_comfort_bps-v_effective_bps,
  'base_trip_cost',v_base,'cost_per_km',v_rate,
  'refuel_stop_cost',v_stop_count*1800,'reposition_cost',v_reposition_cost,
  'reposition_distance_km',v_reposition_distance,
  'reposition_stop_count',v_reposition_stops,
  'cost_one_way',v_base+ceil(v_route_distance*v_rate)::integer+1000+
      v_stop_count*1800+v_reposition_cost,
  'estimated_hours',v_hours,'estimated_travel_days',v_days,
  'overnight_transfer_possible',v_days=1 and v_hours<=10,
  'single_party_charge',true);
end;$multistop_quote$;
revoke all on function public.quote_private_jet_leg_v1(uuid,text,text,text,text,integer,integer,uuid,integer)
 from public,anon,authenticated;

-- Time-aware jet scheduling: same existing public RPC signature.
CREATE OR REPLACE FUNCTION public.sync_player_tournament_travel_timing_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_jet_days integer;
  v_current_game_day integer;
  v_daily_absolute integer;
  v_last_travel_day integer;
begin
  select public.game_day_absolute_v1(season,month,day) into v_current_game_day
  from public.get_current_game_day_internal_v1();
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
    if l.travel_mode='private_jet'
       and coalesce((l.jet_quote->>'active')::boolean,false) then
      -- Multi-stop jets consume their actual estimated flight + refuelling
      -- duration, not the old commercial-flight estimate.
      v_travel:=greatest(30,ceil(coalesce((l.jet_quote->>'estimated_hours')::numeric,1)*60)::integer);
      v_jet_days:=greatest(1,coalesce((l.jet_quote->>'estimated_travel_days')::integer,1));
      -- Start the trip early enough for all required game travel days.
      v_depart:=least(v_depart,(v_first_day-v_jet_days)::bigint*1440+540);
      v_depart:=greatest(v_depart,v_current_game_day::bigint*1440+540);
      if pm.match_id is not null then
        -- A previous match is a hard earliest possible departure; a clash
        -- remains at_risk rather than silently teleporting the player.
        v_prev_end:=pm.abs_day::bigint*1440+coalesce(pm.scheduled_start_minute,600)
          +pm.duration_minutes+coalesce(rule.post_match_departure_buffer_minutes,60);
        v_depart:=greatest(v_depart,v_prev_end);
      end if;
    end if;
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
      -- Reserve every multi-stop travel day, not just the first departure day.
      -- Never overwrite matches, camps or other non-home commitments.
      v_last_travel_day:=least((v_arrive/1440)::integer,v_first_day-1);
      if (v_depart/1440)::integer<=v_last_travel_day then
       for v_daily_absolute in (v_depart/1440)::integer..v_last_travel_day loop
        select * into gd from public.absolute_game_day_v1(v_daily_absolute);
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
            format('Travel to %s%s',coalesce(l.destination_city,l.destination_country_code),
               case when l.travel_mode='private_jet' then ' · refuelling flight' else '' end)
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
       end loop;
      end if;
    end if;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object('status','synced','tournament_legs',v_count);
end;
$function$


-- Server-enforced travel-day availability for multi-stop private journeys.
create or replace function public.set_private_life_tournament_travel_v1(
 p_competition_id uuid,p_mode text,p_owned_jet_asset_id uuid default null)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_player uuid; v_exists boolean; v_preparation jsonb; v_route_jet jsonb;
 v_staff_count integer:=0; v_arrive integer;
 v_days integer:=1;v_today integer;v_prior_end integer;v_first_available integer;v_available integer;v_connection text;
begin
 v_player:=public.private_life_current_player_v1();
 if p_mode not in ('commercial','private_jet') then raise exception 'Invalid travel mode.'; end if;
 if not exists(select 1 from public.tournament_entries where player_id=v_player and competition_id=p_competition_id)
 then raise exception 'This tournament is not entered.'; end if;
 if p_mode='private_jet' then
  select exists(select 1 from public.private_life_player_assets a
   join public.private_life_asset_catalog c on c.code=a.catalog_code
   where a.id=p_owned_jet_asset_id and a.player_id=v_player and a.sold_absolute_day is null
   and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false)) into v_exists;
  if not v_exists then raise exception 'Select an owned travel-capable private jet.'; end if;
  -- Server-authoritative range, booked location and repositioning check.
  v_preparation:=public.quote_tournament_preparation_v1(v_player,p_competition_id);
  select coalesce(array_length(selected_staff_contract_ids,1),0)
    into v_staff_count from public.player_tournament_preparation_plans
    where player_id=v_player and competition_id=p_competition_id;
  v_arrive:=coalesce((v_preparation->>'arrival_absolute_day')::integer,0);
  v_route_jet:=public.quote_private_jet_leg_v1(
    v_player,v_preparation->'origin'->>'city',v_preparation->'origin'->>'country_code',
    v_preparation->'destination'->>'city',v_preparation->'destination'->>'country_code',
    coalesce((v_preparation->'player_travel'->>'distance_km')::integer,0),
    coalesce(v_staff_count,0),p_owned_jet_asset_id,v_arrive-1);
  if not coalesce((v_route_jet->>'active')::boolean,false) then
    raise exception 'Selected private jet is unavailable for this itinerary: %.',
      coalesce(v_route_jet->>'reason','range or repositioning restriction');
  end if;
  -- Refuelling routes may need several days. Require a real free window
  -- after the previous commitment and before tournament arrival.
  v_days:=greatest(1,coalesce((v_route_jet->>'estimated_travel_days')::integer,1));
  select public.game_day_absolute_v1(season,month,day) into v_today
    from public.get_current_game_day_internal_v1();
  select max(x.end_absolute_day) into v_prior_end
    from public.player_commitment_locations_v1(v_player) x
    where x.end_absolute_day<=v_arrive
      and x.end_absolute_day>=v_today
      and coalesce(x.reference_id,'')<>p_competition_id::text;
  v_first_available:=greatest(v_today,coalesce(v_prior_end+1,v_today));
  v_available:=greatest(0,v_arrive-v_first_available+1);
  if v_days>v_available then
    raise exception 'Jet journey needs % travel days, only % are available before this tournament.',
      v_days,v_available;
  end if;
 end if;
 insert into public.player_tournament_travel_selection(player_id,competition_id,travel_mode,owned_jet_asset_id)
 values(v_player,p_competition_id,p_mode,case when p_mode='private_jet' then p_owned_jet_asset_id else null end)
 on conflict(player_id,competition_id) do update set travel_mode=excluded.travel_mode,
 owned_jet_asset_id=excluded.owned_jet_asset_id,updated_at=now();
 perform public.rebuild_player_travel_plan_v1(v_player);
 if p_mode='private_jet' then
  select l.connection_status into v_connection
  from public.player_travel_legs l
  where l.player_id=v_player and l.status='planned'
    and l.destination_location_type='tournament'
    and l.destination_reference_id=p_competition_id::text
  order by l.departure_absolute_day desc limit 1;
  if v_connection='at_risk' then
   raise exception 'Jet flight cannot arrive before the next match; choose a faster route or commercial travel.';
  end if;
 end if;
 return jsonb_build_object('status','saved','travel_mode',p_mode,'owned_jet_asset_id',
 case when p_mode='private_jet' then p_owned_jet_asset_id else null end);
end; $$;
revoke all on function public.set_private_life_tournament_travel_v1(uuid,text,uuid) from public,anon;
grant execute on function public.set_private_life_tournament_travel_v1(uuid,text,uuid) to authenticated;

