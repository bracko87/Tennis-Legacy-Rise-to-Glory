create temporary table october_tournament_seed (
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

insert into october_tournament_seed
  (slug,name,city,country_code,category_code,surface,environment,season_week,phase,slot_order,is_fictional,continent)
values
  -- October Week 1 / Season Week 40
  ('beijing-masters','Beijing Masters','Beijing','CN','masters_1000','hard','outdoor',40,'main_draw',2,false,'Asia'),
  ('shanghai-masters','Shanghai Masters','Shanghai','CN','masters_1000','hard','outdoor',40,'qualification',1,false,'Asia'),
  ('wuhan-masters','Wuhan Masters','Wuhan','CN','masters_1000','hard','outdoor',40,'qualification',1,false,'Asia'),
  ('villena-challenger','Villena Challenger','Villena','ES','challenger_100','hard','outdoor',40,'full',1,false,'Europe'),
  ('antofagasta-challenger','Antofagasta Challenger','Antofagasta','CL','challenger_75','clay','outdoor',40,'full',1,false,'South America'),
  ('braga-challenger','Braga Challenger','Braga','PT','challenger_75','clay','outdoor',40,'full',1,false,'Europe'),
  ('palermo-challenger','Palermo Challenger','Palermo','IT','challenger_50','clay','outdoor',40,'full',1,false,'Europe'),
  ('dusseldorf-challenger','Düsseldorf Challenger','Düsseldorf','DE','challenger_100','hard','indoor',40,'full',1,true,'Europe'),
  ('kaohsiung-challenger','Kaohsiung Challenger','Kaohsiung','TW','challenger_75','hard','outdoor',40,'full',1,true,'Asia'),
  ('maseru-futures','Maseru Futures','Maseru','LS','futures_25','hard','outdoor',40,'full',1,true,'Africa'),
  ('memphis-challenger','Memphis Challenger','Memphis','US','challenger_75','hard','indoor',40,'full',1,true,'North America'),
  ('salvador-challenger','Salvador Challenger','Salvador','BR','challenger_75','clay','outdoor',40,'full',1,true,'South America'),
  ('coffs-harbour-futures','Coffs Harbour Futures','Coffs Harbour','AU','futures_25','hard','outdoor',40,'full',1,true,'Oceania'),

  -- October Week 2 / Season Week 41
  ('shanghai-masters','Shanghai Masters','Shanghai','CN','masters_1000','hard','outdoor',41,'main_draw',2,false,'Asia'),
  ('wuhan-masters','Wuhan Masters','Wuhan','CN','masters_1000','hard','outdoor',41,'main_draw',2,false,'Asia'),
  ('jinan-challenger','Jinan Challenger','Jinan','CN','challenger_125','hard','outdoor',41,'full',1,false,'Asia'),
  ('olbia-challenger','Olbia Challenger','Olbia','IT','challenger_125','hard','outdoor',41,'full',1,false,'Europe'),
  ('maia-challenger','Maia Challenger','Maia','PT','challenger_100','clay','indoor',41,'full',1,false,'Europe'),
  ('roanne-challenger','Roanne Challenger','Roanne','FR','challenger_100','hard','indoor',41,'full',1,false,'Europe'),
  ('cali-open-challenger','Cali Open Challenger','Cali','CO','challenger_75','clay','outdoor',41,'full',1,false,'South America'),
  ('catania-challenger','Catania Challenger','Catania','IT','challenger_50','clay','outdoor',41,'full',1,false,'Europe'),
  ('uppsala-challenger','Uppsala Challenger','Uppsala','SE','challenger_75','hard','indoor',41,'full',1,true,'Europe'),
  ('taichung-challenger','Taichung Challenger','Taichung','TW','challenger_75','hard','outdoor',41,'full',1,true,'Asia'),
  ('lome-futures','Lomé Futures','Lomé','TG','futures_25','hard','outdoor',41,'full',1,true,'Africa'),
  ('el-paso-challenger','El Paso Challenger','El Paso','US','challenger_75','hard','outdoor',41,'full',1,true,'North America'),
  ('cartagena-challenger','Cartagena Challenger','Cartagena','CO','challenger_75','hard','outdoor',41,'full',1,true,'South America'),
  ('albury-futures','Albury Futures','Albury','AU','futures_25','hard','outdoor',41,'full',1,true,'Oceania'),

  -- October Week 3 / Season Week 42
  ('almaty-open','Almaty Open','Almaty','KZ','tour_250','hard','indoor',42,'full',1,false,'Asia'),
  ('brussels-open','Brussels Open','Brussels','BE','tour_250','hard','indoor',42,'full',1,false,'Europe'),
  ('lyon-open','Lyon Open','Lyon','FR','tour_250','hard','indoor',42,'full',1,false,'Europe'),
  ('ningbo-open','Ningbo Open','Ningbo','CN','tour_500','hard','outdoor',42,'full',1,false,'Asia'),
  ('lisbon-challenger','Lisbon Challenger','Lisbon','PT','challenger_100','clay','outdoor',42,'full',1,false,'Europe'),
  ('torrevieja-challenger','Torrevieja Challenger','Torrevieja','ES','challenger_75','hard','outdoor',42,'full',1,false,'Europe'),
  ('guangzhou-nansha-challenger','Guangzhou Nansha Challenger','Guangzhou','CN','challenger_75','hard','outdoor',42,'full',1,false,'Asia'),
  ('santa-cruz-2-challenger','Santa Cruz 2 Challenger','Santa Cruz de la Sierra','BO','challenger_75','clay','outdoor',42,'full',1,false,'South America'),
  ('gaborone-open-challenger','Gaborone Open Challenger','Gaborone','BW','challenger_50','hard','outdoor',42,'full',1,false,'Africa'),
  ('leuven-challenger','Leuven Challenger','Leuven','BE','challenger_75','hard','indoor',42,'full',1,true,'Europe'),
  ('daegu-challenger','Daegu Challenger','Daegu','KR','challenger_75','hard','outdoor',42,'full',1,true,'Asia'),
  ('freetown-futures','Freetown Futures','Freetown','SL','futures_25','hard','outdoor',42,'full',1,true,'Africa'),
  ('oklahoma-city-challenger','Oklahoma City Challenger','Oklahoma City','US','challenger_75','hard','indoor',42,'full',1,true,'North America'),
  ('maracay-challenger','Maracay Challenger','Maracay','VE','challenger_75','hard','outdoor',42,'full',1,true,'South America'),
  ('wagga-wagga-futures','Wagga Wagga Futures','Wagga Wagga','AU','futures_25','hard','outdoor',42,'full',1,true,'Oceania'),

  -- October Week 4 / Season Week 43
  ('vienna-open','Vienna Open','Vienna','AT','tour_500','hard','indoor',43,'full',1,false,'Europe'),
  ('basel-open','Basel Open','Basel','CH','tour_500','hard','indoor',43,'full',1,false,'Europe'),
  ('pan-pacific-open','Pan Pacific Open','Tokyo','JP','tour_500','hard','outdoor',43,'full',1,false,'Asia'),
  ('seoul-challenger','Seoul Challenger','Seoul','KR','challenger_125','hard','outdoor',43,'full',1,false,'Asia'),
  ('brest-challenger','Brest Challenger','Brest','FR','challenger_100','hard','indoor',43,'full',1,false,'Europe'),
  ('sioux-falls-challenger','Sioux Falls Challenger','Sioux Falls','US','challenger_100','hard','indoor',43,'full',1,false,'North America'),
  ('guayaquil-open-challenger','Guayaquil Open Challenger','Guayaquil','EC','challenger_75','clay','outdoor',43,'full',1,false,'South America'),
  ('ningbo-challenger','Ningbo Challenger','Ningbo','CN','challenger_75','hard','outdoor',43,'full',1,false,'Asia'),
  ('odense-challenger','Odense Challenger','Odense','DK','challenger_75','hard','indoor',43,'full',1,true,'Europe'),
  ('matsumoto-challenger','Matsumoto Challenger','Matsumoto','JP','challenger_75','hard','outdoor',43,'full',1,true,'Asia'),
  ('kisumu-futures','Kisumu Futures','Kisumu','KE','futures_25','hard','outdoor',43,'full',1,true,'Africa'),
  ('nashville-challenger','Nashville Challenger','Nashville','US','challenger_75','hard','indoor',43,'full',1,true,'North America'),
  ('iquique-futures','Iquique Futures','Iquique','CL','futures_25','clay','outdoor',43,'full',1,true,'South America'),
  ('mildura-futures','Mildura Futures','Mildura','AU','futures_25','hard','outdoor',43,'full',1,true,'Oceania');

do $$
begin
  if exists (
    select 1
    from (select distinct slug,name from october_tournament_seed) s
    join public.tournament_series t on lower(btrim(t.name))=lower(btrim(s.name)) and t.slug<>s.slug
  ) then
    raise exception 'October tournament name conflicts with an existing tournament series.';
  end if;

  if exists (
    select 1
    from (select distinct slug,city from october_tournament_seed where is_fictional) s
    join public.tournament_series t on lower(btrim(t.city))=lower(btrim(s.city)) and t.slug<>s.slug
  ) then
    raise exception 'October fictional tournament uses a city already used in January-September.';
  end if;

  if (select count(distinct slug) from october_tournament_seed where is_fictional) <> 24 then
    raise exception 'Expected exactly 24 fictional October tournaments.';
  end if;

  if exists (
    select season_week from october_tournament_seed where is_fictional
    group by season_week
    having count(distinct continent)<>6 or count(distinct slug)<>6
  ) then
    raise exception 'Each October week must have exactly one fictional tournament per continent.';
  end if;
end $$;

insert into public.tournament_series (slug,name,city,country_code,category_code,surface,environment)
select distinct slug,name,city,country_code,category_code,surface,environment from october_tournament_seed
on conflict (slug) do update set
  name=excluded.name,
  city=excluded.city,
  country_code=excluded.country_code,
  category_code=excluded.category_code,
  surface=excluded.surface,
  environment=excluded.environment,
  is_active=true;

insert into public.tournament_editions (tournament_series_id,season_number)
select distinct ts.id,1
from october_tournament_seed s join public.tournament_series ts on ts.slug=s.slug
on conflict (tournament_series_id,season_number) do nothing;

insert into public.tournament_world_competitions (tournament_edition_id,world)
select distinct e.id,w.world
from october_tournament_seed s
join public.tournament_series ts on ts.slug=s.slug
join public.tournament_editions e on e.tournament_series_id=ts.id and e.season_number=1
cross join (values ('ATP'),('WTA')) as w(world)
on conflict (tournament_edition_id,world) do nothing;

insert into public.tournament_schedule_slots
  (tournament_edition_id,calendar_month,month_week,season_week,phase,slot_order)
select e.id,10,greatest(1,least(5,s.season_week-39))::smallint,s.season_week,s.phase,s.slot_order
from october_tournament_seed s
join public.tournament_series ts on ts.slug=s.slug
join public.tournament_editions e on e.tournament_series_id=ts.id and e.season_number=1
on conflict (tournament_edition_id,season_week,phase) do update set
  calendar_month=excluded.calendar_month,
  month_week=excluded.month_week,
  slot_order=excluded.slot_order;

do $$
declare
  v_series_count integer;
  v_slot_count integer;
  v_competition_count integer;
begin
  select count(distinct ts.id) into v_series_count
  from october_tournament_seed s join public.tournament_series ts on ts.slug=s.slug;

  select count(*) into v_slot_count
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id=sl.tournament_edition_id and e.season_number=1
  join public.tournament_series ts on ts.id=e.tournament_series_id
  where ts.slug in (select distinct slug from october_tournament_seed)
    and sl.season_week between 40 and 43;

  select count(*) into v_competition_count
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id and e.season_number=1
  join public.tournament_series ts on ts.id=e.tournament_series_id
  where ts.slug in (select distinct slug from october_tournament_seed);

  if v_series_count <> 54 then
    raise exception 'Expected 54 October tournament series, found %',v_series_count;
  end if;
  if v_slot_count <> 56 then
    raise exception 'Expected 56 October schedule entries, found %',v_slot_count;
  end if;
  if v_competition_count <> 108 then
    raise exception 'Expected 108 ATP/WTA October competitions, found %',v_competition_count;
  end if;
end $$;