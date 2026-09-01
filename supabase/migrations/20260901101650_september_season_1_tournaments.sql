create temporary table september_tournament_seed (
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

insert into september_tournament_seed
  (slug, name, city, country_code, category_code, surface, environment, season_week, phase, slot_order, is_fictional, continent)
values
  -- September Week 1 / Season Week 35
  ('us-open','US Open','New York','US','grand_slam_2000','hard','outdoor',35,'main_draw',2,false,'North America'),
  ('como-lake-challenger','Como Lake Challenger','Como','IT','challenger_75','clay','outdoor',35,'full',1,false,'Europe'),
  ('manacor-challenger','Manacor Challenger','Manacor','ES','challenger_75','hard','outdoor',35,'full',1,false,'Europe'),
  ('ct-porto-cup','CT Porto Cup','Porto','PT','challenger_75','clay','outdoor',35,'full',1,false,'Europe'),
  ('zhangjiagang-challenger','Zhangjiagang Challenger','Zhangjiagang','CN','challenger_75','hard','outdoor',35,'full',1,false,'Asia'),
  ('plovdiv-3-challenger','Plovdiv 3 Challenger','Plovdiv','BG','challenger_75','clay','outdoor',35,'full',1,false,'Europe'),
  ('eindhoven-challenger','Eindhoven Challenger','Eindhoven','NL','challenger_75','hard','outdoor',35,'full',1,true,'Europe'),
  ('hanoi-challenger','Hanoi Challenger','Hanoi','VN','challenger_75','hard','outdoor',35,'full',1,true,'Asia'),
  ('yaounde-challenger','Yaoundé Challenger','Yaoundé','CM','challenger_75','hard','outdoor',35,'full',1,true,'Africa'),
  ('minneapolis-challenger','Minneapolis Challenger','Minneapolis','US','challenger_75','hard','outdoor',35,'full',1,true,'North America'),
  ('san-juan-challenger','San Juan Challenger','San Juan','AR','challenger_75','clay','outdoor',35,'full',1,true,'South America'),
  ('mackay-futures','Mackay Futures','Mackay','AU','futures_25','hard','outdoor',35,'full',1,true,'Oceania'),

  -- September Week 2 / Season Week 36
  ('genoa-valletta-challenger','Genoa Valletta Challenger','Genoa','IT','challenger_125','clay','outdoor',36,'full',1,false,'Europe'),
  ('seville-challenger','Seville Challenger','Seville','ES','challenger_125','clay','outdoor',36,'full',1,false,'Europe'),
  ('shanghai-road-challenger','Shanghai Road Challenger','Shanghai','CN','challenger_100','hard','outdoor',36,'full',1,false,'Asia'),
  ('tulln-challenger','Tulln Challenger','Tulln','AT','challenger_100','clay','outdoor',36,'full',1,false,'Europe'),
  ('cassis-challenger','Cassis Challenger','Cassis','FR','challenger_50','clay','outdoor',36,'full',1,false,'Europe'),
  ('istanbul-ted-open','Istanbul TED Open','Istanbul','TR','challenger_75','hard','outdoor',36,'full',1,false,'Asia'),
  ('phan-thiet-3-challenger','Phan Thiết 3 Challenger','Phan Thiết','VN','challenger_50','hard','outdoor',36,'full',1,false,'Asia'),
  ('sarajevo-challenger','Sarajevo Challenger','Sarajevo','BA','challenger_75','clay','outdoor',36,'full',1,true,'Europe'),
  ('chiang-rai-futures','Chiang Rai Futures','Chiang Rai','TH','futures_25','hard','outdoor',36,'full',1,true,'Asia'),
  ('bujumbura-futures','Bujumbura Futures','Bujumbura','BI','futures_25','hard','outdoor',36,'full',1,true,'Africa'),
  ('albuquerque-challenger','Albuquerque Challenger','Albuquerque','US','challenger_75','hard','outdoor',36,'full',1,true,'North America'),
  ('pereira-challenger','Pereira Challenger','Pereira','CO','challenger_75','clay','outdoor',36,'full',1,true,'South America'),
  ('bendigo-futures','Bendigo Futures','Bendigo','AU','futures_25','hard','outdoor',36,'full',1,true,'Oceania'),

  -- September Week 3 / Season Week 37
  ('guadalajara-open','Guadalajara Open','Guadalajara','MX','tour_500','hard','outdoor',37,'full',1,false,'North America'),
  ('sao-paulo-open','São Paulo Open','São Paulo','BR','tour_250','hard','outdoor',37,'full',1,false,'South America'),
  ('szczecin-challenger','Szczecin Challenger','Szczecin','PL','challenger_125','clay','outdoor',37,'full',1,false,'Europe'),
  ('tiburon-challenger','Tiburon Challenger','Tiburon','US','challenger_125','hard','outdoor',37,'full',1,false,'North America'),
  ('guangzhou-huangpu-challenger','Guangzhou Huangpu Challenger','Guangzhou','CN','challenger_100','hard','outdoor',37,'full',1,false,'Asia'),
  ('rennes-challenger','Rennes Challenger','Rennes','FR','challenger_100','hard','indoor',37,'full',1,false,'Europe'),
  ('biella-challenger','Biella Challenger','Biella','IT','challenger_50','clay','outdoor',37,'full',1,false,'Europe'),
  ('phan-thiet-4-challenger','Phan Thiết 4 Challenger','Phan Thiết','VN','challenger_50','hard','outdoor',37,'full',1,false,'Asia'),
  ('gothenburg-challenger','Gothenburg Challenger','Gothenburg','SE','challenger_75','hard','outdoor',37,'full',1,true,'Europe'),
  ('kobe-challenger','Kobe Challenger','Kobe','JP','challenger_75','hard','outdoor',37,'full',1,true,'Asia'),
  ('mbabane-futures','Mbabane Futures','Mbabane','SZ','futures_25','hard','outdoor',37,'full',1,true,'Africa'),
  ('baltimore-challenger','Baltimore Challenger','Baltimore','US','challenger_75','hard','outdoor',37,'full',1,true,'North America'),
  ('trujillo-challenger','Trujillo Challenger','Trujillo','PE','challenger_75','clay','outdoor',37,'full',1,true,'South America'),
  ('ballarat-futures','Ballarat Futures','Ballarat','AU','futures_25','hard','outdoor',37,'full',1,true,'Oceania'),

  -- September Week 4 / Season Week 38
  ('chengdu-open','Chengdu Open','Chengdu','CN','tour_250','hard','outdoor',38,'full',1,false,'Asia'),
  ('hangzhou-open','Hangzhou Open','Hangzhou','CN','tour_250','hard','outdoor',38,'full',1,false,'Asia'),
  ('korea-open','Korea Open','Seoul','KR','tour_250','hard','outdoor',38,'full',1,false,'Asia'),
  ('saint-tropez-challenger','Saint-Tropez Challenger','Saint-Tropez','FR','challenger_125','hard','outdoor',38,'full',1,false,'Europe'),
  ('buenos-aires-tennis-challenger','Buenos Aires Tennis Challenger','Buenos Aires','AR','challenger_75','clay','outdoor',38,'full',1,false,'South America'),
  ('genoa-open-challenger','Genoa Open Challenger','Genoa','IT','challenger_50','clay','outdoor',38,'full',1,false,'Europe'),
  ('nantes-challenger','Nantes Challenger','Nantes','FR','challenger_75','hard','outdoor',38,'full',1,true,'Europe'),
  ('bandung-challenger','Bandung Challenger','Bandung','ID','challenger_75','hard','outdoor',38,'full',1,true,'Asia'),
  ('nouakchott-challenger','Nouakchott Challenger','Nouakchott','MR','challenger_75','hard','outdoor',38,'full',1,true,'Africa'),
  ('louisville-challenger','Louisville Challenger','Louisville','US','challenger_75','hard','outdoor',38,'full',1,true,'North America'),
  ('barquisimeto-challenger','Barquisimeto Challenger','Barquisimeto','VE','challenger_75','clay','outdoor',38,'full',1,true,'South America'),
  ('tauranga-futures','Tauranga Futures','Tauranga','NZ','futures_25','hard','outdoor',38,'full',1,true,'Oceania'),

  -- September Week 5 / Season Week 39
  ('tokyo-open','Tokyo Open','Tokyo','JP','tour_500','hard','outdoor',39,'full',1,false,'Asia'),
  ('beijing-masters','Beijing Masters','Beijing','CN','masters_1000','hard','outdoor',39,'qualification',1,false,'Asia'),
  ('porto-open','Porto Open','Porto','PT','challenger_125','hard','outdoor',39,'full',1,false,'Europe'),
  ('jingshan-challenger','Jingshan Challenger','Jingshan','CN','challenger_100','hard','outdoor',39,'full',1,false,'Asia'),
  ('columbus-challenger','Columbus Challenger','Columbus','US','challenger_75','hard','indoor',39,'full',1,false,'North America'),
  ('copa-curitiba-challenger','Copa Curitiba Challenger','Curitiba','BR','challenger_75','clay','outdoor',39,'full',1,false,'South America'),
  ('mouilleron-challenger','Mouilleron Challenger','Mouilleron-le-Captif','FR','challenger_75','hard','indoor',39,'full',1,false,'Europe'),
  ('bari-open-challenger','Bari Open Challenger','Bari','IT','challenger_50','clay','outdoor',39,'full',1,false,'Europe'),
  ('luxembourg-challenger','Luxembourg Challenger','Luxembourg','LU','challenger_100','hard','indoor',39,'full',1,true,'Europe'),
  ('lahore-futures','Lahore Futures','Lahore','PK','futures_25','hard','outdoor',39,'full',1,true,'Asia'),
  ('antsirabe-futures','Antsirabe Futures','Antsirabe','MG','futures_25','hard','outdoor',39,'full',1,true,'Africa'),
  ('fresno-futures','Fresno Futures','Fresno','US','futures_25','hard','outdoor',39,'full',1,true,'North America'),
  ('rancagua-futures','Rancagua Futures','Rancagua','CL','futures_25','clay','outdoor',39,'full',1,true,'South America'),
  ('nelson-futures','Nelson Futures','Nelson','NZ','futures_15','hard','outdoor',39,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug, name from september_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name)) = lower(btrim(s.name)) and t.slug <> s.slug
  ) then
    raise exception 'September tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug, city from september_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city)) = lower(btrim(s.city)) and t.slug <> s.slug
  ) then
    raise exception 'September fictional tournament uses a city already used in January-August.';
  end if;

  if (select count(distinct slug) from september_tournament_seed where is_fictional) <> 30 then
    raise exception 'Expected exactly 30 fictional September tournaments.';
  end if;

  if exists (
    select season_week
    from september_tournament_seed
    where is_fictional
    group by season_week
    having count(distinct continent) <> 6 or count(distinct slug) <> 6
  ) then
    raise exception 'Each September week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment)
select distinct slug, name, city, country_code, category_code, surface, environment
from september_tournament_seed
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
from september_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
on conflict (tournament_series_id, season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id, world)
select distinct e.id, w.world
from september_tournament_seed s
join public.tournament_series ts on ts.slug = s.slug
join public.tournament_editions e on e.tournament_series_id = ts.id and e.season_number = 1
cross join (values ('ATP'), ('WTA')) as w(world)
on conflict (tournament_edition_id, world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, season_week, phase, slot_order)
select
  e.id,
  9,
  greatest(1, least(5, s.season_week - 34))::smallint,
  s.season_week,
  s.phase,
  s.slot_order
from september_tournament_seed s
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
  from september_tournament_seed s
  join public.tournament_series ts on ts.slug = s.slug;

  select count(*)
  into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from september_tournament_seed)
    and sl.season_week between 35 and 39;

  select count(*)
  into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug in (select distinct slug from september_tournament_seed);

  if v_series_count <> 65 then
    raise exception 'Expected 65 September tournament series, found %', v_series_count;
  end if;
  if v_slot_count <> 65 then
    raise exception 'Expected 65 September schedule entries, found %', v_slot_count;
  end if;
  if v_competition_count <> 130 then
    raise exception 'Expected 130 ATP/WTA September competitions, found %', v_competition_count;
  end if;
end $$;