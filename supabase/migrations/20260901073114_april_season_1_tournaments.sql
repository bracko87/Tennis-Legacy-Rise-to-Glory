create temporary table april_tournament_seed (
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

insert into april_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order, is_fictional, continent)
values
  -- April Week 1 / Season Week 14
  ('monte-carlo-masters','Monte Carlo Masters','Monte-Carlo','MC','masters_1000','clay','outdoor',14,'qualification',1,false,'Europe'),
  ('mexico-city-challenger','Mexico City Challenger','Mexico City','MX','challenger_125','clay','outdoor',14,'full',1,false,'North America'),
  ('monza-challenger','Monza Challenger','Monza','IT','challenger_125','clay','outdoor',14,'full',1,false,'Europe'),
  ('campinas-challenger','Campinas Challenger','Campinas','BR','challenger_75','clay','outdoor',14,'full',1,false,'South America'),
  ('madrid-challenger','Madrid Challenger','Madrid','ES','challenger_75','clay','outdoor',14,'full',1,false,'Europe'),
  ('sarasota-challenger','Sarasota Challenger','Sarasota','US','challenger_75','clay','outdoor',14,'full',1,false,'North America'),
  ('wuning-1-challenger','Wuning 1 Challenger','Wuning','CN','challenger_50','hard','outdoor',14,'full',1,false,'Asia'),
  ('bologna-challenger','Bologna Challenger','Bologna','IT','challenger_100','clay','outdoor',14,'full',1,true,'Europe'),
  ('kuala-lumpur-challenger','Kuala Lumpur Challenger','Kuala Lumpur','MY','challenger_75','hard','outdoor',14,'full',1,true,'Asia'),
  ('dakar-challenger','Dakar Challenger','Dakar','SN','challenger_75','hard','outdoor',14,'full',1,true,'Africa'),
  ('calgary-futures','Calgary Futures','Calgary','CA','futures_25','hard','indoor',14,'full',1,true,'North America'),
  ('cordoba-futures','Córdoba Futures','Córdoba','AR','futures_25','clay','outdoor',14,'full',1,true,'South America'),
  ('cairns-futures','Cairns Futures','Cairns','AU','futures_15','hard','outdoor',14,'full',1,true,'Oceania'),

  -- April Week 2 / Season Week 15
  ('monte-carlo-masters','Monte Carlo Masters','Monte-Carlo','MC','masters_1000','clay','outdoor',15,'main_draw',2,false,'Europe'),
  ('barcelona-open','Barcelona Open','Barcelona','ES','tour_500','clay','outdoor',15,'full',1,false,'Europe'),
  ('munich-open','Munich Open','Munich','DE','tour_500','clay','outdoor',15,'full',1,false,'Europe'),
  ('busan-challenger','Busan Challenger','Busan','KR','challenger_125','hard','outdoor',15,'full',1,false,'Asia'),
  ('oeiras-3-challenger','Oeiras 3 Challenger','Oeiras','PT','challenger_125','clay','outdoor',15,'full',1,false,'Europe'),
  ('santa-cruz-de-la-sierra-challenger','Santa Cruz de la Sierra Challenger','Santa Cruz de la Sierra','BO','challenger_75','clay','outdoor',15,'full',1,false,'South America'),
  ('tallahassee-challenger','Tallahassee Challenger','Tallahassee','US','challenger_75','clay','outdoor',15,'full',1,false,'North America'),
  ('wuning-2-challenger','Wuning 2 Challenger','Wuning','CN','challenger_50','hard','outdoor',15,'full',1,false,'Asia'),
  ('bremen-challenger','Bremen Challenger','Bremen','DE','challenger_75','clay','outdoor',15,'full',1,true,'Europe'),
  ('ho-chi-minh-city-futures','Ho Chi Minh City Futures','Ho Chi Minh City','VN','futures_25','hard','outdoor',15,'full',1,true,'Asia'),
  ('windhoek-challenger','Windhoek Challenger','Windhoek','NA','challenger_75','hard','outdoor',15,'full',1,true,'Africa'),
  ('quebec-city-futures','Québec City Futures','Québec City','CA','futures_25','hard','indoor',15,'full',1,true,'North America'),
  ('salta-challenger','Salta Challenger','Salta','AR','challenger_75','clay','outdoor',15,'full',1,true,'South America'),
  ('queenstown-futures','Queenstown Futures','Queenstown','NZ','futures_15','hard','outdoor',15,'full',1,true,'Oceania'),

  -- April Week 3 / Season Week 16
  ('madrid-masters','Madrid Masters','Madrid','ES','masters_1000','clay','outdoor',16,'qualification',1,false,'Europe'),
  ('gwangju-challenger','Gwangju Challenger','Gwangju','KR','challenger_75','hard','outdoor',16,'full',1,false,'Asia'),
  ('rome-challenger','Rome Challenger','Rome','IT','challenger_75','clay','outdoor',16,'full',1,false,'Europe'),
  ('savannah-challenger','Savannah Challenger','Savannah','US','challenger_75','clay','outdoor',16,'full',1,false,'North America'),
  ('abidjan-1-challenger','Abidjan 1 Challenger','Abidjan','CI','challenger_50','hard','outdoor',16,'full',1,false,'Africa'),
  ('shymkent-1-challenger','Shymkent 1 Challenger','Shymkent','KZ','challenger_50','clay','outdoor',16,'full',1,false,'Asia'),
  ('belgrade-challenger','Belgrade Challenger','Belgrade','RS','challenger_100','clay','outdoor',16,'full',1,true,'Europe'),
  ('manila-challenger','Manila Challenger','Manila','PH','challenger_75','hard','outdoor',16,'full',1,true,'Asia'),
  ('harare-futures','Harare Futures','Harare','ZW','futures_25','hard','outdoor',16,'full',1,true,'Africa'),
  ('edmonton-challenger','Edmonton Challenger','Edmonton','CA','challenger_75','hard','indoor',16,'full',1,true,'North America'),
  ('punta-del-este-futures','Punta del Este Futures','Punta del Este','UY','futures_25','clay','outdoor',16,'full',1,true,'South America'),
  ('townsville-futures','Townsville Futures','Townsville','AU','futures_25','hard','outdoor',16,'full',1,true,'Oceania'),

  -- April Week 4 / Season Week 17
  ('madrid-masters','Madrid Masters','Madrid','ES','masters_1000','clay','outdoor',17,'main_draw',2,false,'Europe'),
  ('aix-en-provence-challenger','Aix-en-Provence Challenger','Aix-en-Provence','FR','challenger_125','clay','outdoor',17,'full',1,false,'Europe'),
  ('cagliari-challenger','Cagliari Challenger','Cagliari','IT','challenger_125','clay','outdoor',17,'full',1,false,'Europe'),
  ('mauthausen-challenger','Mauthausen Challenger','Mauthausen','AT','challenger_100','clay','outdoor',17,'full',1,false,'Europe'),
  ('jiujiang-challenger','Jiujiang Challenger','Jiujiang','CN','challenger_75','hard','outdoor',17,'full',1,false,'Asia'),
  ('ostrava-challenger','Ostrava Challenger','Ostrava','CZ','challenger_75','clay','outdoor',17,'full',1,false,'Europe'),
  ('abidjan-2-challenger','Abidjan 2 Challenger','Abidjan','CI','challenger_75','hard','outdoor',17,'full',1,false,'Africa'),
  ('shymkent-2-challenger','Shymkent 2 Challenger','Shymkent','KZ','challenger_50','clay','outdoor',17,'full',1,false,'Asia'),
  ('krakow-challenger','Kraków Challenger','Kraków','PL','challenger_75','clay','outdoor',17,'full',1,true,'Europe'),
  ('tashkent-challenger','Tashkent Challenger','Tashkent','UZ','challenger_100','hard','outdoor',17,'full',1,true,'Asia'),
  ('dar-es-salaam-futures','Dar es Salaam Futures','Dar es Salaam','TZ','futures_25','hard','outdoor',17,'full',1,true,'Africa'),
  ('halifax-futures','Halifax Futures','Halifax','CA','futures_15','hard','indoor',17,'full',1,true,'North America'),
  ('la-paz-challenger','La Paz Challenger','La Paz','BO','challenger_75','clay','outdoor',17,'full',1,true,'South America'),
  ('port-moresby-futures','Port Moresby Futures','Port Moresby','PG','futures_15','hard','outdoor',17,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from april_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'April tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug, city from april_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city)) = lower(btrim(s.city)) and t.slug <> s.slug
  ) then
    raise exception 'April fictional tournament uses a city already used in January-March.';
  end if;

  if (select count(distinct slug) from april_tournament_seed where is_fictional) <> 24 then
    raise exception 'Expected exactly 24 fictional April tournaments.';
  end if;

  if exists (
    select season_week
    from april_tournament_seed
    where is_fictional
    group by season_week
    having count(distinct continent) <> 6 or count(distinct slug) <> 6
  ) then
    raise exception 'Each April week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from april_tournament_seed
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
from april_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from april_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  4,
  greatest(1, least(5, s.season_week - 13))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from april_tournament_seed s
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
  from april_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from april_tournament_seed)
    and sl.season_week between 14 and 17;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from april_tournament_seed);

  if v_series_count <> 51 then
    raise exception 'Expected 51 April tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 53 then
    raise exception 'Expected 53 April schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 102 then
    raise exception 'Expected 102 ATP/WTA April competitions, found %', v_competition_count;
  end if;
end $$;
