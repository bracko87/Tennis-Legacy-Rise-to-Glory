create temporary table june_tournament_seed (
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

insert into june_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order, is_fictional, continent)
values
  -- June Week 1 / Season Week 22
  ('perugia-challenger','Perugia Challenger','Perugia','IT','challenger_125','clay','outdoor',22,'full',1,false,'Europe'),
  ('birmingham-challenger','Birmingham Challenger','Birmingham','GB','challenger_125','grass','outdoor',22,'full',1,false,'Europe'),
  ('heilbronn-challenger','Heilbronn Challenger','Heilbronn','DE','challenger_125','clay','outdoor',22,'full',1,false,'Europe'),
  ('prostejov-challenger','Prostějov Challenger','Prostějov','CZ','challenger_100','clay','outdoor',22,'full',1,false,'Europe'),
  ('tyler-challenger','Tyler Challenger','Tyler','US','challenger_75','hard','outdoor',22,'full',1,false,'North America'),
  ('centurion-open','Centurion Open','Centurion','ZA','challenger_75','hard','outdoor',22,'full',1,false,'Africa'),
  ('manchester-challenger','Manchester Challenger','Manchester','GB','challenger_100','grass','outdoor',22,'full',1,true,'Europe'),
  ('taipei-challenger','Taipei Challenger','Taipei','TW','challenger_75','hard','outdoor',22,'full',1,true,'Asia'),
  ('rabat-challenger','Rabat Challenger','Rabat','MA','challenger_75','clay','outdoor',22,'full',1,true,'Africa'),
  ('winnipeg-futures','Winnipeg Futures','Winnipeg','CA','futures_25','hard','outdoor',22,'full',1,true,'North America'),
  ('mendoza-challenger','Mendoza Challenger','Mendoza','AR','challenger_75','clay','outdoor',22,'full',1,true,'South America'),
  ('gold-coast-futures','Gold Coast Futures','Gold Coast','AU','futures_25','hard','outdoor',22,'full',1,true,'Oceania'),

  -- June Week 2 / Season Week 23
  ('stuttgart-open','Stuttgart Open','Stuttgart','DE','tour_250','grass','outdoor',23,'full',1,false,'Europe'),
  ('s-hertogenbosch-open','’s-Hertogenbosch Open','’s-Hertogenbosch','NL','tour_250','grass','outdoor',23,'full',1,false,'Europe'),
  ('ilkley-challenger','Ilkley Challenger','Ilkley','GB','challenger_125','grass','outdoor',23,'full',1,false,'Europe'),
  ('bratislava-challenger','Bratislava Challenger','Bratislava','SK','challenger_100','clay','outdoor',23,'full',1,false,'Europe'),
  ('lyon-challenger','Lyon Challenger','Lyon','FR','challenger_100','clay','outdoor',23,'full',1,false,'Europe'),
  ('cattolica-challenger','Cattolica Challenger','Cattolica','IT','challenger_75','clay','outdoor',23,'full',1,false,'Europe'),
  ('san-miguel-de-tucuman-challenger','San Miguel de Tucumán Challenger','San Miguel de Tucumán','AR','challenger_75','clay','outdoor',23,'full',1,false,'South America'),
  ('aarhus-challenger','Aarhus Challenger','Aarhus','DK','challenger_75','grass','outdoor',23,'full',1,true,'Europe'),
  ('ulaanbaatar-futures','Ulaanbaatar Futures','Ulaanbaatar','MN','futures_25','hard','outdoor',23,'full',1,true,'Asia'),
  ('pretoria-challenger','Pretoria Challenger','Pretoria','ZA','challenger_75','hard','outdoor',23,'full',1,true,'Africa'),
  ('kansas-city-futures','Kansas City Futures','Kansas City','US','futures_25','hard','outdoor',23,'full',1,true,'North America'),
  ('recife-challenger','Recife Challenger','Recife','BR','challenger_75','clay','outdoor',23,'full',1,true,'South America'),
  ('dunedin-futures','Dunedin Futures','Dunedin','NZ','futures_15','hard','outdoor',23,'full',1,true,'Oceania'),

  -- June Week 3 / Season Week 24
  ('halle-open','Halle Open','Halle','DE','tour_500','grass','outdoor',24,'full',1,false,'Europe'),
  ('queens-club-open','Queen''s Club Open','London','GB','tour_500','grass','outdoor',24,'full',1,false,'Europe'),
  ('berlin-open','Berlin Open','Berlin','DE','tour_500','grass','outdoor',24,'full',1,false,'Europe'),
  ('nottingham-open','Nottingham Open','Nottingham','GB','tour_250','grass','outdoor',24,'full',1,false,'Europe'),
  ('parma-challenger','Parma Challenger','Parma','IT','challenger_125','clay','outdoor',24,'full',1,false,'Europe'),
  ('poznan-challenger','Poznań Challenger','Poznań','PL','challenger_100','clay','outdoor',24,'full',1,false,'Europe'),
  ('dublin-challenger','Dublin Challenger','Dublin','IE','challenger_100','grass','outdoor',24,'full',1,false,'Europe'),
  ('royan-challenger','Royan Challenger','Royan','FR','challenger_75','clay','outdoor',24,'full',1,false,'Europe'),
  ('dresden-challenger','Dresden Challenger','Dresden','DE','challenger_100','grass','outdoor',24,'full',1,true,'Europe'),
  ('nanjing-challenger','Nanjing Challenger','Nanjing','CN','challenger_75','hard','outdoor',24,'full',1,true,'Asia'),
  ('lagos-challenger','Lagos Challenger','Lagos','NG','challenger_75','hard','outdoor',24,'full',1,true,'Africa'),
  ('monterrey-challenger','Monterrey Challenger','Monterrey','MX','challenger_100','hard','outdoor',24,'full',1,true,'North America'),
  ('cuenca-futures','Cuenca Futures','Cuenca','EC','futures_25','clay','outdoor',24,'full',1,true,'South America'),
  ('geelong-futures','Geelong Futures','Geelong','AU','futures_25','hard','outdoor',24,'full',1,true,'Oceania'),

  -- June Week 4 / Season Week 25
  ('mallorca-open','Mallorca Open','Mallorca','ES','tour_250','grass','outdoor',25,'full',1,false,'Europe'),
  ('eastbourne-open','Eastbourne Open','Eastbourne','GB','tour_250','grass','outdoor',25,'full',1,false,'Europe'),
  ('bad-homburg-open','Bad Homburg Open','Bad Homburg','DE','tour_500','grass','outdoor',25,'full',1,false,'Europe'),
  ('targu-mures-challenger','Târgu Mureș Challenger','Târgu Mureș','RO','challenger_75','clay','outdoor',25,'full',1,false,'Europe'),
  ('piracicaba-challenger','Piracicaba Challenger','Piracicaba','BR','challenger_75','clay','outdoor',25,'full',1,false,'South America'),
  ('plovdiv-challenger','Plovdiv Challenger','Plovdiv','BG','challenger_75','clay','outdoor',25,'full',1,false,'Europe'),
  ('ghent-challenger','Ghent Challenger','Ghent','BE','challenger_75','grass','outdoor',25,'full',1,true,'Europe'),
  ('daejeon-futures','Daejeon Futures','Daejeon','KR','futures_25','hard','outdoor',25,'full',1,true,'Asia'),
  ('antananarivo-challenger','Antananarivo Challenger','Antananarivo','MG','challenger_75','clay','outdoor',25,'full',1,true,'Africa'),
  ('detroit-futures','Detroit Futures','Detroit','US','futures_25','hard','outdoor',25,'full',1,true,'North America'),
  ('barranquilla-challenger','Barranquilla Challenger','Barranquilla','CO','challenger_75','hard','outdoor',25,'full',1,true,'South America'),
  ('rotorua-futures','Rotorua Futures','Rotorua','NZ','futures_15','hard','outdoor',25,'full',1,true,'Oceania'),

  -- June Week 5 / Season Week 26
  ('wimbledon-grand-slam','Wimbledon Grand Slam','London','GB','grand_slam_2000','grass','outdoor',26,'qualification',1,false,'Europe'),
  ('cary-challenger','Cary Challenger','Cary','US','challenger_75','hard','outdoor',26,'full',1,false,'North America'),
  ('milan-challenger','Milan Challenger','Milan','IT','challenger_75','clay','outdoor',26,'full',1,false,'Europe'),
  ('brasov-challenger','Brașov Challenger','Brașov','RO','challenger_75','clay','outdoor',26,'full',1,false,'Europe'),
  ('quito-challenger','Quito Challenger','Quito','EC','challenger_75','clay','outdoor',26,'full',1,false,'South America'),
  ('troyes-challenger','Troyes Challenger','Troyes','FR','challenger_50','clay','outdoor',26,'full',1,false,'Europe'),
  ('tokyo-futures','Tokyo Futures','Tokyo','JP','futures_15','hard','outdoor',26,'full',1,false,'Asia'),
  ('leeds-challenger','Leeds Challenger','Leeds','GB','challenger_100','grass','outdoor',26,'full',1,true,'Europe'),
  ('osaka-challenger','Osaka Challenger','Osaka','JP','challenger_75','hard','outdoor',26,'full',1,true,'Asia'),
  ('gqeberha-challenger','Gqeberha Challenger','Gqeberha','ZA','challenger_75','hard','outdoor',26,'full',1,true,'Africa'),
  ('victoria-challenger','Victoria Challenger','Victoria','CA','challenger_75','hard','outdoor',26,'full',1,true,'North America'),
  ('valparaiso-futures','Valparaíso Futures','Valparaíso','CL','futures_25','clay','outdoor',26,'full',1,true,'South America'),
  ('alice-springs-futures','Alice Springs Futures','Alice Springs','AU','futures_15','hard','outdoor',26,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from june_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'June tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug, city from june_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city)) = lower(btrim(s.city)) and t.slug <> s.slug
  ) then
    raise exception 'June fictional tournament uses a city already used in January-May.';
  end if;

  if (select count(distinct slug) from june_tournament_seed where is_fictional) <> 30 then
    raise exception 'Expected exactly 30 fictional June tournaments.';
  end if;

  if exists (
    select season_week
    from june_tournament_seed
    where is_fictional
    group by season_week
    having count(distinct continent) <> 6 or count(distinct slug) <> 6
  ) then
    raise exception 'Each June week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from june_tournament_seed
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
from june_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from june_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  6,
  greatest(1, least(5, s.season_week - 21))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from june_tournament_seed s
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
  from june_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from june_tournament_seed)
    and sl.season_week between 22 and 26;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from june_tournament_seed);

  if v_series_count <> 64 then
    raise exception 'Expected 64 June tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 64 then
    raise exception 'Expected 64 June schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 128 then
    raise exception 'Expected 128 ATP/WTA June competitions, found %', v_competition_count;
  end if;
end $$;