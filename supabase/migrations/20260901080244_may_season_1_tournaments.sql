create temporary table may_tournament_seed (
  slug text not null,
  name text not null,
  city text not null,
  country_code text not null,
  category_code text not null,
  surface text not null,
  environment text not null,
  season_week smallint not null,
  phase text not null,
  slot_order smallint not null,
  is_fictional boolean not null,
  continent text not null
) on commit drop;

insert into may_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order, is_fictional, continent)
values
  -- May Week 1 / Season Week 18
  ('rome-masters','Rome Masters','Rome','IT','masters_1000','clay','outdoor',18,'qualification',1,false,'Europe'),
  ('wuxi-challenger','Wuxi Challenger','Wuxi','CN','challenger_100','hard','outdoor',18,'full',1,false,'Asia'),
  ('francavilla-al-mare-challenger','Francavilla al Mare Challenger','Francavilla al Mare','IT','challenger_75','clay','outdoor',18,'full',1,false,'Europe'),
  ('brazzaville-challenger','Brazzaville Challenger','Brazzaville','CG','challenger_50','clay','outdoor',18,'full',1,false,'Africa'),
  ('santos-challenger','Santos Challenger','Santos','BR','challenger_50','clay','outdoor',18,'full',1,false,'South America'),
  ('prague-challenger','Prague Challenger','Prague','CZ','challenger_100','clay','outdoor',18,'full',1,true,'Europe'),
  ('sapporo-futures','Sapporo Futures','Sapporo','JP','futures_25','hard','outdoor',18,'full',1,true,'Asia'),
  ('kampala-challenger','Kampala Challenger','Kampala','UG','challenger_75','clay','outdoor',18,'full',1,true,'Africa'),
  ('ottawa-futures','Ottawa Futures','Ottawa','CA','futures_25','hard','outdoor',18,'full',1,true,'North America'),
  ('mar-del-plata-challenger','Mar del Plata Challenger','Mar del Plata','AR','challenger_75','clay','outdoor',18,'full',1,true,'South America'),
  ('napier-futures','Napier Futures','Napier','NZ','futures_15','hard','outdoor',18,'full',1,true,'Oceania'),

  -- May Week 2 / Season Week 19
  ('rome-masters','Rome Masters','Rome','IT','masters_1000','clay','outdoor',19,'main_draw',2,false,'Europe'),
  ('bordeaux-challenger','Bordeaux Challenger','Bordeaux','FR','challenger_125','clay','outdoor',19,'full',1,false,'Europe'),
  ('valencia-challenger','Valencia Challenger','Valencia','ES','challenger_125','clay','outdoor',19,'full',1,false,'Europe'),
  ('oeiras-4-challenger','Oeiras 4 Challenger','Oeiras','PT','challenger_100','clay','outdoor',19,'full',1,false,'Europe'),
  ('tunis-challenger','Tunis Challenger','Tunis','TN','challenger_75','clay','outdoor',19,'full',1,false,'Africa'),
  ('zagreb-challenger','Zagreb Challenger','Zagreb','HR','challenger_75','clay','outdoor',19,'full',1,false,'Europe'),
  ('bengaluru-2-challenger','Bengaluru 2 Challenger','Bengaluru','IN','challenger_50','hard','outdoor',19,'full',1,false,'Asia'),
  ('cordoba-challenger','Córdoba Challenger','Córdoba','AR','challenger_50','clay','outdoor',19,'full',1,false,'South America'),
  ('vienna-challenger','Vienna Challenger','Vienna','AT','challenger_100','clay','outdoor',19,'full',1,true,'Europe'),
  ('surabaya-futures','Surabaya Futures','Surabaya','ID','futures_25','hard','outdoor',19,'full',1,true,'Asia'),
  ('addis-ababa-challenger','Addis Ababa Challenger','Addis Ababa','ET','challenger_75','hard','outdoor',19,'full',1,true,'Africa'),
  ('charlotte-futures','Charlotte Futures','Charlotte','US','futures_25','hard','outdoor',19,'full',1,true,'North America'),
  ('cali-challenger','Cali Challenger','Cali','CO','challenger_75','clay','outdoor',19,'full',1,true,'South America'),
  ('launceston-futures','Launceston Futures','Launceston','AU','futures_15','hard','outdoor',19,'full',1,true,'Oceania'),

  -- May Week 3 / Season Week 20
  ('french-grand-slam','French Grand Slam','Paris','FR','grand_slam_2000','clay','outdoor',20,'qualification',1,false,'Europe'),
  ('hamburg-open','Hamburg Open','Hamburg','DE','tour_500','clay','outdoor',20,'full',1,false,'Europe'),
  ('geneva-open','Geneva Open','Geneva','CH','tour_250','clay','outdoor',20,'full',1,false,'Europe'),
  ('istanbul-challenger','Istanbul Challenger','Istanbul','TR','challenger_75','clay','outdoor',20,'full',1,false,'Asia'),
  ('bengaluru-3-challenger','Bengaluru 3 Challenger','Bengaluru','IN','challenger_50','hard','outdoor',20,'full',1,false,'Asia'),
  ('cervia-challenger','Cervia Challenger','Cervia','IT','challenger_50','clay','outdoor',20,'full',1,false,'Europe'),
  ('sofia-challenger','Sofia Challenger','Sofia','BG','challenger_100','clay','outdoor',20,'full',1,true,'Europe'),
  ('kathmandu-futures','Kathmandu Futures','Kathmandu','NP','futures_25','hard','outdoor',20,'full',1,true,'Asia'),
  ('luanda-challenger','Luanda Challenger','Luanda','AO','challenger_75','hard','outdoor',20,'full',1,true,'Africa'),
  ('santo-domingo-futures','Santo Domingo Futures','Santo Domingo','DO','futures_25','hard','outdoor',20,'full',1,true,'North America'),
  ('manaus-challenger','Manaus Challenger','Manaus','BR','challenger_75','clay','outdoor',20,'full',1,true,'South America'),
  ('newcastle-futures','Newcastle Futures','Newcastle','AU','futures_25','hard','outdoor',20,'full',1,true,'Oceania'),

  -- May Week 4 / Season Week 21
  ('french-grand-slam','French Grand Slam','Paris','FR','grand_slam_2000','clay','outdoor',21,'main_draw',2,false,'Europe'),
  ('chisinau-challenger','Chisinau Challenger','Chisinau','MD','challenger_100','clay','outdoor',21,'full',1,false,'Europe'),
  ('little-rock-challenger','Little Rock Challenger','Little Rock','US','challenger_75','hard','outdoor',21,'full',1,false,'North America'),
  ('vicenza-challenger','Vicenza Challenger','Vicenza','IT','challenger_75','clay','outdoor',21,'full',1,false,'Europe'),
  ('centurion-challenger','Centurion Challenger','Centurion','ZA','challenger_50','hard','outdoor',21,'full',1,false,'Africa'),
  ('kosice-challenger','Košice Challenger','Košice','SK','challenger_50','clay','outdoor',21,'full',1,false,'Europe'),
  ('malmo-challenger','Malmö Challenger','Malmö','SE','challenger_75','clay','outdoor',21,'full',1,true,'Europe'),
  ('almaty-challenger','Almaty Challenger','Almaty','KZ','challenger_100','clay','outdoor',21,'full',1,true,'Asia'),
  ('mombasa-futures','Mombasa Futures','Mombasa','KE','futures_25','hard','outdoor',21,'full',1,true,'Africa'),
  ('guatemala-city-challenger','Guatemala City Challenger','Guatemala City','GT','challenger_75','hard','outdoor',21,'full',1,true,'North America'),
  ('cochabamba-futures','Cochabamba Futures','Cochabamba','BO','futures_25','clay','outdoor',21,'full',1,true,'South America'),
  ('apia-futures','Apia Futures','Apia','WS','futures_15','hard','outdoor',21,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from may_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'May tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug, city from may_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city)) = lower(btrim(s.city)) and t.slug <> s.slug
  ) then
    raise exception 'May fictional tournament uses a city already used in January-April.';
  end if;

  if (select count(distinct slug) from may_tournament_seed where is_fictional) <> 24 then
    raise exception 'Expected exactly 24 fictional May tournaments.';
  end if;

  if exists (
    select season_week
    from may_tournament_seed
    where is_fictional
    group by season_week
    having count(distinct continent) <> 6 or count(distinct slug) <> 6
  ) then
    raise exception 'Each May week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from may_tournament_seed
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
from may_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from may_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  5,
  greatest(1, least(5, s.season_week - 17))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from may_tournament_seed s
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
  from may_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from may_tournament_seed)
    and sl.season_week between 18 and 21;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from may_tournament_seed);

  if v_series_count <> 47 then
    raise exception 'Expected 47 May tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 49 then
    raise exception 'Expected 49 May schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 94 then
    raise exception 'Expected 94 ATP/WTA May competitions, found %', v_competition_count;
  end if;
end $$;