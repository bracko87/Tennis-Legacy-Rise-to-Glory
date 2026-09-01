create temporary table july_tournament_seed (
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

insert into july_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order, is_fictional, continent)
values
  -- July Week 1 / Season Week 27
  ('wimbledon-grand-slam','Wimbledon Grand Slam','London','GB','grand_slam_2000','grass','outdoor',27,'main_draw',2,false,'Europe'),
  ('braunschweig-challenger','Braunschweig Challenger','Braunschweig','DE','challenger_125','clay','outdoor',27,'full',1,false,'Europe'),
  ('newport-challenger','Newport Challenger','Newport','US','challenger_125','grass','outdoor',27,'full',1,false,'North America'),
  ('bogota-challenger','Bogotá Challenger','Bogotá','CO','challenger_75','clay','outdoor',27,'full',1,false,'South America'),
  ('trieste-challenger','Trieste Challenger','Trieste','IT','challenger_75','clay','outdoor',27,'full',1,false,'Europe'),
  ('liege-challenger','Liège Challenger','Liège','BE','challenger_50','clay','outdoor',27,'full',1,false,'Europe'),
  ('iasi-challenger','Iași Challenger','Iași','RO','challenger_100','clay','outdoor',27,'full',1,false,'Europe'),
  ('utrecht-challenger','Utrecht Challenger','Utrecht','NL','challenger_75','grass','outdoor',27,'full',1,true,'Europe'),
  ('fukuoka-challenger','Fukuoka Challenger','Fukuoka','JP','challenger_75','hard','outdoor',27,'full',1,true,'Asia'),
  ('banjul-futures','Banjul Futures','Banjul','GM','futures_25','hard','outdoor',27,'full',1,true,'Africa'),
  ('milwaukee-challenger','Milwaukee Challenger','Milwaukee','US','challenger_75','hard','outdoor',27,'full',1,true,'North America'),
  ('valdivia-futures','Valdivia Futures','Valdivia','CL','futures_25','clay','outdoor',27,'full',1,true,'South America'),
  ('palmerston-north-futures','Palmerston North Futures','Palmerston North','NZ','futures_15','hard','outdoor',27,'full',1,true,'Oceania'),

  -- July Week 2 / Season Week 28
  ('bastad-open','Båstad Open','Båstad','SE','tour_250','clay','outdoor',28,'full',1,false,'Europe'),
  ('gstaad-open','Gstaad Open','Gstaad','CH','tour_250','clay','outdoor',28,'full',1,false,'Europe'),
  ('umag-open','Umag Open','Umag','HR','tour_250','clay','outdoor',28,'full',1,false,'Europe'),
  ('iasi-open','Iași Open','Iași','RO','tour_250','clay','outdoor',28,'full',1,false,'Europe'),
  ('bunschoten-challenger','Bunschoten Challenger','Bunschoten','NL','challenger_75','clay','outdoor',28,'full',1,false,'Europe'),
  ('granby-challenger','Granby Challenger','Granby','CA','challenger_75','hard','outdoor',28,'full',1,false,'North America'),
  ('lincoln-challenger','Lincoln Challenger','Lincoln','US','challenger_75','hard','outdoor',28,'full',1,false,'North America'),
  ('pozoblanco-challenger','Pozoblanco Challenger','Pozoblanco','ES','challenger_75','hard','outdoor',28,'full',1,false,'Europe'),
  ('bergen-challenger','Bergen Challenger','Bergen','NO','challenger_75','clay','outdoor',28,'full',1,true,'Europe'),
  ('penang-challenger','Penang Challenger','Penang','MY','challenger_75','hard','outdoor',28,'full',1,true,'Asia'),
  ('kumasi-challenger','Kumasi Challenger','Kumasi','GH','challenger_75','hard','outdoor',28,'full',1,true,'Africa'),
  ('sacramento-challenger','Sacramento Challenger','Sacramento','US','challenger_100','hard','outdoor',28,'full',1,true,'North America'),
  ('santa-fe-challenger','Santa Fe Challenger','Santa Fe','AR','challenger_75','clay','outdoor',28,'full',1,true,'South America'),
  ('wollongong-futures','Wollongong Futures','Wollongong','AU','futures_25','hard','outdoor',28,'full',1,true,'Oceania'),

  -- July Week 3 / Season Week 29
  ('kitzbuhel-open','Kitzbühel Open','Kitzbühel','AT','tour_250','clay','outdoor',29,'full',1,false,'Europe'),
  ('estoril-open','Estoril Open','Estoril','PT','tour_250','clay','outdoor',29,'full',1,false,'Europe'),
  ('prague-open','Prague Open','Prague','CZ','tour_250','hard','outdoor',29,'full',1,false,'Europe'),
  ('bloomfield-hills-challenger','Bloomfield Hills Challenger','Bloomfield Hills','US','challenger_125','hard','outdoor',29,'full',1,false,'North America'),
  ('zug-challenger','Zug Challenger','Zug','CH','challenger_125','clay','outdoor',29,'full',1,false,'Europe'),
  ('segovia-challenger','Segovia Challenger','Segovia','ES','challenger_75','hard','outdoor',29,'full',1,false,'Europe'),
  ('tampere-challenger','Tampere Challenger','Tampere','FI','challenger_75','clay','outdoor',29,'full',1,false,'Europe'),
  ('leipzig-challenger','Leipzig Challenger','Leipzig','DE','challenger_100','clay','outdoor',29,'full',1,true,'Europe'),
  ('guangzhou-challenger','Guangzhou Challenger','Guangzhou','CN','challenger_100','hard','outdoor',29,'full',1,true,'Asia'),
  ('lilongwe-futures','Lilongwe Futures','Lilongwe','MW','futures_25','hard','outdoor',29,'full',1,true,'Africa'),
  ('salt-lake-city-challenger','Salt Lake City Challenger','Salt Lake City','US','challenger_75','hard','outdoor',29,'full',1,true,'North America'),
  ('paramaribo-futures','Paramaribo Futures','Paramaribo','SR','futures_25','hard','outdoor',29,'full',1,true,'South America'),
  ('toowoomba-futures','Toowoomba Futures','Toowoomba','AU','futures_25','hard','outdoor',29,'full',1,true,'Oceania'),

  -- July Week 4 / Season Week 30
  ('washington-open','Washington Open','Washington, D.C.','US','tour_500','hard','outdoor',30,'full',1,false,'North America'),
  ('los-cabos-open','Los Cabos Open','Los Cabos','MX','tour_250','hard','outdoor',30,'full',1,false,'North America'),
  ('san-marino-challenger','San Marino Challenger','San Marino','SM','challenger_125','clay','outdoor',30,'full',1,false,'Europe'),
  ('bonn-challenger','Bonn Challenger','Bonn','DE','challenger_75','clay','outdoor',30,'full',1,false,'Europe'),
  ('liberec-challenger','Liberec Challenger','Liberec','CZ','challenger_75','clay','outdoor',30,'full',1,false,'Europe'),
  ('lausanne-challenger','Lausanne Challenger','Lausanne','CH','challenger_100','clay','outdoor',30,'full',1,true,'Europe'),
  ('bishkek-futures','Bishkek Futures','Bishkek','KG','futures_25','hard','outdoor',30,'full',1,true,'Asia'),
  ('port-louis-challenger','Port Louis Challenger','Port Louis','MU','challenger_75','hard','outdoor',30,'full',1,true,'Africa'),
  ('tulsa-futures','Tulsa Futures','Tulsa','US','futures_25','hard','outdoor',30,'full',1,true,'North America'),
  ('florianopolis-challenger','Florianópolis Challenger','Florianópolis','BR','challenger_75','clay','outdoor',30,'full',1,true,'South America'),
  ('nadi-futures','Nadi Futures','Nadi','FJ','futures_15','hard','outdoor',30,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from july_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'July tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug, city from july_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city)) = lower(btrim(s.city)) and t.slug <> s.slug
  ) then
    raise exception 'July fictional tournament uses a city already used in January-June.';
  end if;

  if (select count(distinct slug) from july_tournament_seed where is_fictional) <> 24 then
    raise exception 'Expected exactly 24 fictional July tournaments.';
  end if;

  if exists (
    select season_week
    from july_tournament_seed
    where is_fictional
    group by season_week
    having count(distinct continent) <> 6 or count(distinct slug) <> 6
  ) then
    raise exception 'Each July week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from july_tournament_seed
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
from july_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from july_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  7,
  greatest(1, least(5, s.season_week - 26))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from july_tournament_seed s
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
  from july_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from july_tournament_seed)
    and sl.season_week between 27 and 30;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from july_tournament_seed);

  if v_series_count <> 51 then
    raise exception 'Expected 51 July tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 51 then
    raise exception 'Expected 51 July schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 102 then
    raise exception 'Expected 102 ATP/WTA July competitions, found %', v_competition_count;
  end if;
end $$;