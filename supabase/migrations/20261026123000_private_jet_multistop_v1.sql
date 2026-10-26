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
