create temporary table august_tournament_seed (
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

insert into august_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order, is_fictional, continent)
values
  -- August Week 1 / Season Week 31
  ('montreal-masters','Montreal Masters','Montreal','CA','masters_1000','hard','outdoor',31,'qualification',1,false,'North America'),
  ('hagen-challenger','Hagen Challenger','Hagen','DE','challenger_100','clay','outdoor',31,'full',1,false,'Europe'),
  ('grodzisk-mazowiecki-challenger','Grodzisk Mazowiecki Challenger','Grodzisk Mazowiecki','PL','challenger_75','hard','outdoor',31,'full',1,false,'Europe'),
  ('lexington-challenger','Lexington Challenger','Lexington','US','challenger_75','hard','outdoor',31,'full',1,false,'North America'),
  ('gauteng-challenger','Gauteng Challenger','Centurion','ZA','challenger_75','hard','outdoor',31,'full',1,false,'Africa'),
  ('istanbul-bosphorus-challenger','Istanbul Bosphorus Challenger','Istanbul','TR','challenger_50','hard','outdoor',31,'full',1,false,'Asia'),
  ('boostedt-challenger','Boostedt Challenger','Boostedt','DE','challenger_75','hard','outdoor',31,'full',1,true,'Europe'),
  ('sendai-challenger','Sendai Challenger','Sendai','JP','challenger_75','hard','outdoor',31,'full',1,true,'Asia'),
  ('kano-challenger','Kano Challenger','Kano','NG','challenger_75','hard','outdoor',31,'full',1,true,'Africa'),
  ('omaha-challenger','Omaha Challenger','Omaha','US','challenger_75','hard','outdoor',31,'full',1,true,'North America'),
  ('temuco-challenger','Temuco Challenger','Temuco','CL','challenger_75','clay','outdoor',31,'full',1,true,'South America'),
  ('sunshine-coast-futures','Sunshine Coast Futures','Sunshine Coast','AU','futures_25','hard','outdoor',31,'full',1,true,'Oceania'),

  -- August Week 2 / Season Week 32
  ('montreal-masters','Montreal Masters','Montreal','CA','masters_1000','hard','outdoor',32,'main_draw',2,false,'North America'),
  ('cincinnati-masters','Cincinnati Masters','Cincinnati','US','masters_1000','hard','outdoor',32,'qualification',1,false,'North America'),
  ('brownsburg-challenger','Brownsburg Challenger','Brownsburg','US','challenger_75','hard','outdoor',32,'full',1,false,'North America'),
  ('hamburg-challenger','Hamburg Challenger','Hamburg','DE','challenger_75','clay','outdoor',32,'full',1,false,'Europe'),
  ('todi-challenger','Todi Challenger','Todi','IT','challenger_75','clay','outdoor',32,'full',1,false,'Europe'),
  ('astana-challenger','Astana Challenger','Astana','KZ','challenger_50','hard','outdoor',32,'full',1,false,'Asia'),
  ('turku-challenger','Turku Challenger','Turku','FI','challenger_75','hard','outdoor',32,'full',1,true,'Europe'),
  ('chiang-mai-challenger','Chiang Mai Challenger','Chiang Mai','TH','challenger_75','hard','outdoor',32,'full',1,true,'Asia'),
  ('fes-challenger','Fes Challenger','Fes','MA','challenger_75','clay','outdoor',32,'full',1,true,'Africa'),
  ('boise-challenger','Boise Challenger','Boise','US','challenger_75','hard','outdoor',32,'full',1,true,'North America'),
  ('neuquen-challenger','Neuquén Challenger','Neuquén','AR','challenger_75','clay','outdoor',32,'full',1,true,'South America'),
  ('invercargill-futures','Invercargill Futures','Invercargill','NZ','futures_15','hard','outdoor',32,'full',1,true,'Oceania'),

  -- August Week 3 / Season Week 33
  ('cincinnati-masters','Cincinnati Masters','Cincinnati','US','masters_1000','hard','outdoor',33,'main_draw',2,false,'North America'),
  ('cancun-challenger','Cancún Challenger','Cancún','MX','challenger_125','hard','outdoor',33,'full',1,false,'North America'),
  ('quebec-city-challenger','Québec City Challenger','Québec City','CA','challenger_125','hard','outdoor',33,'full',1,false,'North America'),
  ('kingston-challenger','Kingston Challenger','Kingston','JM','challenger_75','hard','outdoor',33,'full',1,false,'North America'),
  ('czech-challenger','Czech Challenger','Prague','CZ','challenger_75','clay','outdoor',33,'full',1,false,'Europe'),
  ('roehampton-challenger','Roehampton Challenger','Roehampton','GB','challenger_50','hard','outdoor',33,'full',1,false,'Europe'),
  ('sion-challenger','Sion Challenger','Sion','CH','challenger_50','clay','outdoor',33,'full',1,false,'Europe'),
  ('uzbekistan-challenger','Uzbekistan Challenger','Tashkent','UZ','challenger_50','hard','outdoor',33,'full',1,false,'Asia'),
  ('aleksandrovo-challenger','Aleksandrovo Challenger','Aleksandrovo','RS','challenger_75','clay','outdoor',33,'full',1,true,'Europe'),
  ('medan-challenger','Medan Challenger','Medan','ID','challenger_75','hard','outdoor',33,'full',1,true,'Asia'),
  ('blantyre-futures','Blantyre Futures','Blantyre','MW','futures_25','hard','outdoor',33,'full',1,true,'Africa'),
  ('reno-challenger','Reno Challenger','Reno','US','challenger_75','hard','outdoor',33,'full',1,true,'North America'),
  ('santa-marta-challenger','Santa Marta Challenger','Santa Marta','CO','challenger_75','hard','outdoor',33,'full',1,true,'South America'),
  ('rockhampton-futures','Rockhampton Futures','Rockhampton','AU','futures_25','hard','outdoor',33,'full',1,true,'Oceania'),

  -- August Week 4 / Season Week 34
  ('us-open','US Open','New York','US','grand_slam_2000','hard','outdoor',34,'qualification',1,false,'North America'),
  ('winston-salem-open','Winston-Salem Open','Winston-Salem','US','tour_250','hard','outdoor',34,'full',1,false,'North America'),
  ('kingston-2-challenger','Kingston 2 Challenger','Kingston','JM','challenger_75','hard','outdoor',34,'full',1,false,'North America'),
  ('augsburg-challenger','Augsburg Challenger','Augsburg','DE','challenger_50','clay','outdoor',34,'full',1,false,'Europe'),
  ('roehampton-2-challenger','Roehampton 2 Challenger','Roehampton','GB','challenger_50','hard','outdoor',34,'full',1,false,'Europe'),
  ('reykjavik-challenger','Reykjavik Challenger','Reykjavik','IS','challenger_75','hard','outdoor',34,'full',1,true,'Europe'),
  ('nagano-futures','Nagano Futures','Nagano','JP','futures_25','hard','outdoor',34,'full',1,true,'Asia'),
  ('bamako-challenger','Bamako Challenger','Bamako','ML','challenger_75','hard','outdoor',34,'full',1,true,'Africa'),
  ('richmond-challenger','Richmond Challenger','Richmond','US','challenger_75','hard','outdoor',34,'full',1,true,'North America'),
  ('georgetown-futures','Georgetown Futures','Georgetown','GY','futures_25','hard','outdoor',34,'full',1,true,'South America'),
  ('palmerston-futures','Palmerston Futures','Palmerston','AU','futures_15','hard','outdoor',34,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from august_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'August tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug, city from august_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city)) = lower(btrim(s.city)) and t.slug <> s.slug
  ) then
    raise exception 'August fictional tournament uses a city already used in January-July.';
  end if;

  if (select count(distinct slug) from august_tournament_seed where is_fictional) <> 24 then
    raise exception 'Expected exactly 24 fictional August tournaments.';
  end if;

  if exists (
    select season_week
    from august_tournament_seed
    where is_fictional
    group by season_week
    having count(distinct continent) <> 6 or count(distinct slug) <> 6
  ) then
    raise exception 'Each August week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from august_tournament_seed
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
from august_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from august_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  8,
  greatest(1, least(5, s.season_week - 30))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from august_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
on conflict (tournament_edition_id, season_week, phase) do update set
  calendar_month = excluded.calendar_month,
  month_week = excluded.month_week,
  slot_order = excluded.slot_order;

do $$
declare
  v_series_count integer;
  v_slot_count integer;
  v_competition_count integer;
begin
  select count(distinct ts.id)
  into v_series_count
  from august_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from august_tournament_seed)
    and sl.season_week between 31 and 34;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from august_tournament_seed);

  if v_series_count <> 47 then
    raise exception 'Expected 47 August tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 49 then
    raise exception 'Expected 49 August schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 94 then
    raise exception 'Expected 94 ATP/WTA August competitions, found %', v_competition_count;
  end if;
end $$;