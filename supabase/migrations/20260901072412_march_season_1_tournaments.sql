create temporary table march_tournament_seed (
  slug text not null,
  name text not null,
  city text not null,
  country_code text not null,
  category_code text not null,
  surface text not null,
  environment text not null,
  season_week smallint not null,
  phase text not null,
  slot_order smallint not null
) on commit drop;

insert into march_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order)
values
  -- March Week 1 / Season Week 9
  ('indian-wells-masters','Indian Wells Masters','Indian Wells','US','masters_1000','hard','outdoor',9,'qualification',1),
  ('thionville-challenger','Thionville Challenger','Thionville','FR','challenger_100','hard','indoor',9,'full',1),
  ('brasilia-challenger','Brasília Challenger','Brasília','BR','challenger_75','clay','outdoor',9,'full',1),
  ('rwanda-challenger','Rwanda Challenger','Kigali','RW','challenger_75','clay','outdoor',9,'full',1),
  ('fujairah-open','Fujairah Open','Fujairah','AE','challenger_50','hard','outdoor',9,'full',1),
  ('hersonissos-challenger','Hersonissos Challenger','Hersonissos','GR','challenger_50','hard','outdoor',9,'full',1),
  ('brno-challenger','Brno Challenger','Brno','CZ','challenger_75','hard','indoor',9,'full',1),
  ('jaipur-futures','Jaipur Futures','Jaipur','IN','futures_25','hard','outdoor',9,'full',1),
  ('accra-challenger','Accra Challenger','Accra','GH','challenger_75','hard','outdoor',9,'full',1),
  ('kingston-futures','Kingston Futures','Kingston','JM','futures_25','hard','outdoor',9,'full',1),
  ('montevideo-challenger','Montevideo Challenger','Montevideo','UY','challenger_75','clay','outdoor',9,'full',1),
  ('suva-futures','Suva Futures','Suva','FJ','futures_15','hard','outdoor',9,'full',1),

  -- March Week 2 / Season Week 10
  ('indian-wells-masters','Indian Wells Masters','Indian Wells','US','masters_1000','hard','outdoor',10,'main_draw',2),
  ('phoenix-challenger','Phoenix Challenger','Phoenix','US','challenger_125','hard','outdoor',10,'full',1),
  ('cap-cana-challenger','Cap Cana Challenger','Punta Cana','DO','challenger_125','hard','outdoor',10,'full',1),
  ('cherbourg-challenger','Cherbourg Challenger','Cherbourg-en-Cotentin','FR','challenger_75','hard','indoor',10,'full',1),
  ('santiago-challenger','Santiago Challenger','Santiago','CL','challenger_75','clay','outdoor',10,'full',1),
  ('graz-challenger','Graz Challenger','Graz','AT','challenger_75','hard','indoor',10,'full',1),
  ('da-nang-futures','Da Nang Futures','Da Nang','VN','futures_25','hard','outdoor',10,'full',1),
  ('lusaka-challenger','Lusaka Challenger','Lusaka','ZM','challenger_75','hard','outdoor',10,'full',1),
  ('nassau-futures','Nassau Futures','Nassau','BS','futures_25','hard','outdoor',10,'full',1),
  ('curitiba-challenger','Curitiba Challenger','Curitiba','BR','challenger_100','clay','outdoor',10,'full',1),
  ('perth-futures','Perth Futures','Perth','AU','futures_25','hard','outdoor',10,'full',1),

  -- March Week 3 / Season Week 11
  ('miami-masters','Miami Masters','Miami','US','masters_1000','hard','outdoor',11,'qualification',1),
  ('morelos-open','Morelos Open','Cuernavaca','MX','challenger_75','hard','outdoor',11,'full',1),
  ('asuncion-challenger','Asunción Challenger','Asunción','PY','challenger_75','clay','outdoor',11,'full',1),
  ('murcia-challenger','Murcia Challenger','Murcia','ES','challenger_75','clay','outdoor',11,'full',1),
  ('zadar-challenger','Zadar Challenger','Zadar','HR','challenger_75','clay','outdoor',11,'full',1),
  ('ljubljana-challenger','Ljubljana Challenger','Ljubljana','SI','challenger_75','hard','indoor',11,'full',1),
  ('cebu-futures','Cebu Futures','Cebu','PH','futures_15','hard','outdoor',11,'full',1),
  ('gaborone-futures','Gaborone Futures','Gaborone','BW','futures_25','hard','outdoor',11,'full',1),
  ('leon-challenger','León Challenger','León','MX','challenger_75','hard','outdoor',11,'full',1),
  ('guayaquil-challenger','Guayaquil Challenger','Guayaquil','EC','challenger_100','clay','outdoor',11,'full',1),
  ('wellington-futures','Wellington Futures','Wellington','NZ','futures_25','hard','outdoor',11,'full',1),

  -- March Week 4 / Season Week 12
  ('miami-masters','Miami Masters','Miami','US','masters_1000','hard','outdoor',12,'main_draw',2),
  ('morelia-challenger','Morelia Challenger','Morelia','MX','challenger_125','hard','outdoor',12,'full',1),
  ('naples-challenger','Naples Challenger','Naples','IT','challenger_125','clay','outdoor',12,'full',1),
  ('alicante-challenger','Alicante Challenger','Alicante','ES','challenger_100','clay','outdoor',12,'full',1),
  ('sao-paulo-challenger','São Paulo Challenger','São Paulo','BR','challenger_100','clay','outdoor',12,'full',1),
  ('bucaramanga-challenger','Bucaramanga Challenger','Bucaramanga','CO','challenger_50','clay','outdoor',12,'full',1),
  ('split-challenger','Split Challenger','Split','HR','challenger_50','clay','outdoor',12,'full',1),
  ('yokkaichi-challenger','Yokkaichi Challenger','Yokkaichi','JP','challenger_50','hard','outdoor',12,'full',1),
  ('tallinn-challenger','Tallinn Challenger','Tallinn','EE','challenger_100','hard','indoor',12,'full',1),
  ('nagoya-challenger','Nagoya Challenger','Nagoya','JP','challenger_75','hard','outdoor',12,'full',1),
  ('durban-challenger','Durban Challenger','Durban','ZA','challenger_75','hard','outdoor',12,'full',1),
  ('vancouver-challenger','Vancouver Challenger','Vancouver','CA','challenger_100','hard','indoor',12,'full',1),
  ('arequipa-futures','Arequipa Futures','Arequipa','PE','futures_25','clay','outdoor',12,'full',1),
  ('darwin-futures','Darwin Futures','Darwin','AU','futures_25','hard','outdoor',12,'full',1),

  -- March Week 5 / Season Week 13
  ('bucharest-open','Bucharest Open','Bucharest','RO','tour_250','clay','outdoor',13,'full',1),
  ('houston-open','Houston Open','Houston','US','tour_250','clay','outdoor',13,'full',1),
  ('marrakech-open','Marrakech Open','Marrakech','MA','tour_250','clay','outdoor',13,'full',1),
  ('menorca-challenger','Menorca Challenger','Menorca','ES','challenger_100','clay','outdoor',13,'full',1),
  ('barletta-challenger','Barletta Challenger','Barletta','IT','challenger_75','clay','outdoor',13,'full',1),
  ('san-luis-potosi-challenger','San Luis Potosí Challenger','San Luis Potosí','MX','challenger_75','clay','outdoor',13,'full',1),
  ('sao-leopoldo-challenger','São Leopoldo Challenger','São Leopoldo','BR','challenger_75','clay','outdoor',13,'full',1),
  ('miyazaki-challenger','Miyazaki Challenger','Miyazaki','JP','challenger_50','hard','outdoor',13,'full',1),
  ('bari-challenger','Bari Challenger','Bari','IT','challenger_75','clay','outdoor',13,'full',1),
  ('kochi-futures','Kochi Futures','Kochi','IN','futures_25','hard','outdoor',13,'full',1),
  ('maputo-futures','Maputo Futures','Maputo','MZ','futures_25','hard','outdoor',13,'full',1),
  ('san-jose-challenger','San José Challenger','San José','CR','challenger_75','hard','outdoor',13,'full',1),
  ('medellin-challenger','Medellín Challenger','Medellín','CO','challenger_100','clay','outdoor',13,'full',1),
  ('hamilton-futures','Hamilton Futures','Hamilton','NZ','futures_15','hard','outdoor',13,'full',1);

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from march_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'March tournament name conflicts with an existing tournament series.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from march_tournament_seed
on conflict (slug) do update set
  name = excluded.name,
  city = excluded.city,
  country_code = excluded.country_code,
  category_code = excluded.category_code,
  surface = excluded.surface,
  environment = excluded.environment,
  is_active = true;

insert into public.tournament_editions (tournament_series_id, season_number)
select distinct ts.id, 1
from march_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from march_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  3,
  greatest(1, least(5, s.season_week - 8))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from march_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
on conflict (tournament_edition_id, season_week, phase) do update set
  slot_order = excluded.slot_order;

do $$
declare
  v_series_count integer;
  v_slot_count integer;
  v_competition_count integer;
begin
  select count(distinct ts.id)
  into v_series_count
  from march_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from march_tournament_seed)
    and sl.season_week between 9 and 13;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from march_tournament_seed);

  if v_series_count <> 60 then
    raise exception 'Expected 60 March tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 62 then
    raise exception 'Expected 62 March schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 120 then
    raise exception 'Expected 120 ATP/WTA March competitions, found %', v_competition_count;
  end if;
end $$;