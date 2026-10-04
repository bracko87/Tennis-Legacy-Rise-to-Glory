-- Expand the live WTA AI population by the user-approved 117-player country allocation.
-- Existing WTA records/ranking points are not modified.
-- New entrants start with 0 ranking points and balanced AI strength tiers; their
-- ranking positions are therefore derived by the normal world-ranking rules.

-- Kosovo is now an approved Tennis Legacy country.
insert into public.player_home_city_options(country_code,city,sort_order,latitude,longitude,is_active)
values
  ('XK','Pristina',1,42.6629,21.1655,true),
  ('XK','Prizren',2,42.2139,20.7397,true),
  ('XK','Peja',3,42.6591,20.2883,true),
  ('XK','Gjakova',4,42.3803,20.4308,true),
  ('XK','Ferizaj',5,42.3702,21.1483,true)
on conflict(country_code,city) do update
set sort_order=excluded.sort_order,
    latitude=excluded.latitude,
    longitude=excluded.longitude,
    is_active=true,
    updated_at=now();

create or replace function public.get_player_creation_countries_v1()
returns table(code text,name text)
language sql
stable
security definer
set search_path to 'public'
as $$
  select c.code,c.name
  from public.countries c
  where c.is_active
    and c.code = any(array['AF','AL','DZ','AD','AO','AG','AR','AM','AU','AT','AZ','BS','BH','BD','BB','BY','BE','BZ','BJ','BT','BO','BA','BW','BR','BN','BG','BF','BI','CV','KH','CM','CA','CF','TD','CL','CN','CO','KM','CG','CD','CR','CI','HR','CU','CY','CZ','DK','DJ','DM','DO','EC','EG','SV','GQ','ER','EE','SZ','ET','FJ','FI','FR','GA','GM','GE','DE','GH','GR','GD','GT','GN','GW','GY','HT','VA','HN','HU','IS','IN','ID','IR','IQ','IE','IL','IT','JM','JP','JO','KZ','KE','KI','KP','KR','KW','KG','LA','LV','LB','LS','LR','LY','LI','LT','LU','MG','MW','MY','MV','ML','MT','MH','MR','MU','MX','FM','MD','MC','MN','ME','MA','MZ','MM','NA','NR','NP','NL','NZ','NI','NE','NG','MK','NO','OM','PK','PW','PA','PG','PY','PE','PH','PL','PT','QA','RO','RU','RW','KN','LC','VC','WS','SM','ST','SA','SN','RS','SC','SL','SG','SK','SI','SB','SO','ZA','SS','ES','LK','SD','SR','SE','CH','SY','TJ','TZ','TH','TL','TG','TO','TT','TN','TR','TM','TV','UG','UA','AE','GB','US','UY','UZ','VU','VE','VN','YE','ZM','ZW','XK']::text[])
    and exists(
      select 1
      from public.player_home_city_options h
      where h.country_code=c.code
        and h.is_active
    )
  order by c.name;
$$;

grant execute on function public.get_player_creation_countries_v1() to authenticated;

-- Allow the WTA expansion beyond the original 300 AI profile slots.
alter table public.players drop constraint if exists players_ai_profile_number_check;
alter table public.players add constraint players_ai_profile_number_check check (
  ((player_type='human')
    and ai_profile_number is null
    and ai_starting_technical_total is null
    and ai_starting_physical_total is null)
  or
  ((player_type='ai')
    and ai_profile_number between 1 and 1000
    and ai_starting_technical_total between 350 and 480
    and ai_starting_physical_total between 176 and 212)
);

-- Keep the original top-36 legacy tier mapping unchanged. New AI profile slots
-- may explicitly carry balanced tiers for future world expansion.
create or replace function public.assign_ai_skill_tier_defaults_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
begin
  if new.player_type='ai' then
    if new.ai_profile_number between 1 and 12 then
      new.ai_skill_tier:='elite';
      new.ai_starting_technical_total:=468;
      new.ai_starting_physical_total:=208;
    elsif new.ai_profile_number between 13 and 24 then
      new.ai_skill_tier:='human_equivalent';
      new.ai_starting_technical_total:=450;
      new.ai_starting_physical_total:=200;
    elsif new.ai_profile_number between 25 and 36 then
      new.ai_skill_tier:='competitive';
      new.ai_starting_technical_total:=423;
      new.ai_starting_physical_total:=196;
    elsif new.ai_profile_number>300 then
      new.ai_skill_tier:=case
        when new.ai_skill_tier in ('elite','human_equivalent','competitive','standard') then new.ai_skill_tier
        else 'standard'
      end;

      if new.ai_skill_tier='elite' then
        new.ai_starting_technical_total:=468;
        new.ai_starting_physical_total:=208;
      elsif new.ai_skill_tier='human_equivalent' then
        new.ai_starting_technical_total:=450;
        new.ai_starting_physical_total:=200;
      elsif new.ai_skill_tier='competitive' then
        new.ai_starting_technical_total:=423;
        new.ai_starting_physical_total:=196;
      else
        new.ai_starting_technical_total:=coalesce(new.ai_starting_technical_total,350+mod(new.ai_profile_number*7,43));
        new.ai_starting_physical_total:=coalesce(new.ai_starting_physical_total,180+mod(new.ai_profile_number*5,15));
      end if;
    else
      new.ai_skill_tier:='standard';
    end if;
  else
    new.ai_skill_tier:=null;
  end if;

  return new;
end;
$$;

-- Guard against accidental duplicate application or name collisions.
do $$
declare
  v_existing integer;
  v_name_conflicts integer;
begin
  select count(*) into v_existing
  from public.players
  where world='WTA' and player_type='ai' and ai_profile_number between 301 and 417;

  if v_existing<>0 then
    raise exception 'WTA expansion slots 301-417 are already occupied (% rows).',v_existing;
  end if;

  with proposed(seq,country_code,first_name,last_name,skill_tier) as (
    values
    (1,'AL','Elira','Hoxha','standard'),
    (2,'AL','Arta','Kola','standard'),
    (3,'DZ','Ines','Bensaid','standard'),
    (4,'AD','Laia','Pujol','standard'),
    (5,'AO','Neusa','Manuel','competitive'),
    (6,'AM','Anahit','Sargsyan','standard'),
    (7,'AM','Mariam','Petrosyan','standard'),
    (8,'AZ','Aysel','Mammadova','standard'),
    (9,'BH','Fatima','Al Doseri','elite'),
    (10,'BD','Nusrat','Rahman','standard'),
    (11,'BB','Aaliyah','Clarke','standard'),
    (12,'BY','Alina','Kovalenko','standard'),
    (13,'BY','Darya','Hryshkevich','standard'),
    (14,'BO','Valeria','Mamani','competitive'),
    (15,'BW','Naledi','Molefe','standard'),
    (16,'CM','Amina','Njoya','standard'),
    (17,'CG','Mireille','Moukoko','standard'),
    (18,'CR','Sofia','Quesada','human_equivalent'),
    (19,'CI','Awa','Kouassi','standard'),
    (20,'CU','Daniela','Valdes','standard'),
    (21,'CY','Eleni','Christodoulou','standard'),
    (22,'CY','Andriana','Ioannou','standard'),
    (23,'DM','Shania','Laurent','standard'),
    (24,'DO','Camila','Rosario','competitive'),
    (25,'EC','Martina','Cevallos','standard'),
    (26,'EE','Kadri','Saar','standard'),
    (27,'ET','Hana','Bekele','standard'),
    (28,'ET','Selam','Tesfaye','standard'),
    (29,'FJ','Litia','Naivalu','standard'),
    (30,'GE','Nino','Beridze','standard'),
    (31,'GH','Abena','Mensah','competitive'),
    (32,'GW','Fatima','Embalo','standard'),
    (33,'GY','Priya','Persaud','standard'),
    (34,'HT','Nadine','Joseph','standard'),
    (35,'HN','Andrea','Zelaya','standard'),
    (36,'IS','Sara','Jónsdóttir','standard'),
    (37,'IS','Elín','Sigurðardóttir','standard'),
    (38,'IS','Freyja','Magnúsdóttir','elite'),
    (39,'ID','Putri','Wulandari','standard'),
    (40,'ID','Ayu','Pratiwi','standard'),
    (41,'IR','Nika','Rahimi','standard'),
    (42,'IE','Aoife','Murphy','competitive'),
    (43,'IE','Niamh','O''Sullivan','standard'),
    (44,'IL','Noa','Cohen','human_equivalent'),
    (45,'IL','Yael','Levi','standard'),
    (46,'JM','Shanice','Campbell','standard'),
    (47,'JO','Lina','Al-Khatib','standard'),
    (48,'KW','Dana','Al-Mutairi','standard'),
    (49,'LV','Elīna','Ozoliņa','standard'),
    (50,'LV','Marta','Bērziņa','standard'),
    (51,'LB','Maya','Khoury','standard'),
    (52,'LI','Lea','Beck','competitive'),
    (53,'LT','Austėja','Kazlauskaitė','standard'),
    (54,'LU','Claire','Schmit','standard'),
    (55,'MY','Nur Aisyah','Rahman','standard'),
    (56,'MY','Mei Ling','Tan','standard'),
    (57,'MV','Aishath','Rasheed','standard'),
    (58,'ML','Aminata','Traoré','standard'),
    (59,'MT','Elisa','Borg','standard'),
    (60,'MU','Anoushka','Ramdin','standard'),
    (61,'MD','Irina','Rusu','standard'),
    (62,'MN','Enkhjin','Batbayar','standard'),
    (63,'ME','Milica','Vukčević','standard'),
    (64,'ME','Jelena','Radović','competitive'),
    (65,'MZ','Celina','Mucavele','standard'),
    (66,'NE','Amina','Issoufou','standard'),
    (67,'OM','Salma','Al-Harthy','standard'),
    (68,'PK','Ayesha','Khan','standard'),
    (69,'PK','Mahnoor','Ahmed','human_equivalent'),
    (70,'PA','Isabella','Tejada','standard'),
    (71,'PY','Lucía','Benítez','standard'),
    (72,'PH','Bianca','Santos','standard'),
    (73,'PH','Alyssa','Mendoza','competitive'),
    (74,'PH','Camille','Reyes','standard'),
    (75,'QA','Hessa','Al-Kuwari','standard'),
    (76,'RU','Anastasia','Volkova','standard'),
    (77,'RU','Daria','Morozova','elite'),
    (78,'RU','Polina','Sokolova','standard'),
    (79,'RU','Ekaterina','Orlova','standard'),
    (80,'RU','Sofia','Lebedeva','standard'),
    (81,'RU','Alina','Makarova','standard'),
    (82,'RU','Veronika','Belova','standard'),
    (83,'RU','Ksenia','Fedorova','competitive'),
    (84,'SM','Giulia','Casadei','standard'),
    (85,'ST','Joana','da Costa','standard'),
    (86,'SA','Reem','Al-Qahtani','standard'),
    (87,'SN','Aïssatou','Ndiaye','human_equivalent'),
    (88,'SG','Jia En','Lim','standard'),
    (89,'SG','Nurul Huda','Hassan','standard'),
    (90,'LK','Kavindi','Perera','standard'),
    (91,'LK','Nethmi','Fernando','standard'),
    (92,'SD','Sara','Elhassan','competitive'),
    (93,'TJ','Madina','Rahmonova','standard'),
    (94,'TZ','Neema','Mushi','standard'),
    (95,'TG','Ama','Lawson','standard'),
    (96,'TO','Mele','Taufa','standard'),
    (97,'TT','Kiara','Mohammed','standard'),
    (98,'TR','Elif','Yılmaz','standard'),
    (99,'TR','Zeynep','Kaya','standard'),
    (100,'TR','Ece','Demir','standard'),
    (101,'TR','Selin','Aydın','competitive'),
    (102,'UG','Patricia','Namusoke','standard'),
    (103,'UA','Oksana','Melnyk','standard'),
    (104,'UA','Iryna','Kovalenko','elite'),
    (105,'UA','Mariia','Shevchenko','standard'),
    (106,'UA','Alina','Kovalchuk','standard'),
    (107,'VE','Valentina','Herrera','standard'),
    (108,'VE','Mariana','Salazar','standard'),
    (109,'VE','Gabriela','Rojas','standard'),
    (110,'VN','Minh Anh','Nguyen','standard'),
    (111,'VN','Thu Ha','Tran','standard'),
    (112,'VN','Bao Ngoc','Le','human_equivalent'),
    (113,'YE','Amal','Al-Hakimi','standard'),
    (114,'ZM','Chipo','Phiri','standard'),
    (115,'ZW','Tariro','Moyo','standard'),
    (116,'XK','Arta','Krasniqi','competitive'),
    (117,'XK','Era','Gashi','standard')
  )
  select count(*) into v_name_conflicts
  from proposed x
  join public.players p
    on p.world='WTA'
   and lower(p.first_name)=lower(x.first_name)
   and lower(p.last_name)=lower(x.last_name);

  if v_name_conflicts<>0 then
    raise exception 'WTA expansion name collision count: %.',v_name_conflicts;
  end if;
end;
$$;

with proposed(seq,country_code,first_name,last_name,skill_tier) as (
  values
    (1,'AL','Elira','Hoxha','standard'),
    (2,'AL','Arta','Kola','standard'),
    (3,'DZ','Ines','Bensaid','standard'),
    (4,'AD','Laia','Pujol','standard'),
    (5,'AO','Neusa','Manuel','competitive'),
    (6,'AM','Anahit','Sargsyan','standard'),
    (7,'AM','Mariam','Petrosyan','standard'),
    (8,'AZ','Aysel','Mammadova','standard'),
    (9,'BH','Fatima','Al Doseri','elite'),
    (10,'BD','Nusrat','Rahman','standard'),
    (11,'BB','Aaliyah','Clarke','standard'),
    (12,'BY','Alina','Kovalenko','standard'),
    (13,'BY','Darya','Hryshkevich','standard'),
    (14,'BO','Valeria','Mamani','competitive'),
    (15,'BW','Naledi','Molefe','standard'),
    (16,'CM','Amina','Njoya','standard'),
    (17,'CG','Mireille','Moukoko','standard'),
    (18,'CR','Sofia','Quesada','human_equivalent'),
    (19,'CI','Awa','Kouassi','standard'),
    (20,'CU','Daniela','Valdes','standard'),
    (21,'CY','Eleni','Christodoulou','standard'),
    (22,'CY','Andriana','Ioannou','standard'),
    (23,'DM','Shania','Laurent','standard'),
    (24,'DO','Camila','Rosario','competitive'),
    (25,'EC','Martina','Cevallos','standard'),
    (26,'EE','Kadri','Saar','standard'),
    (27,'ET','Hana','Bekele','standard'),
    (28,'ET','Selam','Tesfaye','standard'),
    (29,'FJ','Litia','Naivalu','standard'),
    (30,'GE','Nino','Beridze','standard'),
    (31,'GH','Abena','Mensah','competitive'),
    (32,'GW','Fatima','Embalo','standard'),
    (33,'GY','Priya','Persaud','standard'),
    (34,'HT','Nadine','Joseph','standard'),
    (35,'HN','Andrea','Zelaya','standard'),
    (36,'IS','Sara','Jónsdóttir','standard'),
    (37,'IS','Elín','Sigurðardóttir','standard'),
    (38,'IS','Freyja','Magnúsdóttir','elite'),
    (39,'ID','Putri','Wulandari','standard'),
    (40,'ID','Ayu','Pratiwi','standard'),
    (41,'IR','Nika','Rahimi','standard'),
    (42,'IE','Aoife','Murphy','competitive'),
    (43,'IE','Niamh','O''Sullivan','standard'),
    (44,'IL','Noa','Cohen','human_equivalent'),
    (45,'IL','Yael','Levi','standard'),
    (46,'JM','Shanice','Campbell','standard'),
    (47,'JO','Lina','Al-Khatib','standard'),
    (48,'KW','Dana','Al-Mutairi','standard'),
    (49,'LV','Elīna','Ozoliņa','standard'),
    (50,'LV','Marta','Bērziņa','standard'),
    (51,'LB','Maya','Khoury','standard'),
    (52,'LI','Lea','Beck','competitive'),
    (53,'LT','Austėja','Kazlauskaitė','standard'),
    (54,'LU','Claire','Schmit','standard'),
    (55,'MY','Nur Aisyah','Rahman','standard'),
    (56,'MY','Mei Ling','Tan','standard'),
    (57,'MV','Aishath','Rasheed','standard'),
    (58,'ML','Aminata','Traoré','standard'),
    (59,'MT','Elisa','Borg','standard'),
    (60,'MU','Anoushka','Ramdin','standard'),
    (61,'MD','Irina','Rusu','standard'),
    (62,'MN','Enkhjin','Batbayar','standard'),
    (63,'ME','Milica','Vukčević','standard'),
    (64,'ME','Jelena','Radović','competitive'),
    (65,'MZ','Celina','Mucavele','standard'),
    (66,'NE','Amina','Issoufou','standard'),
    (67,'OM','Salma','Al-Harthy','standard'),
    (68,'PK','Ayesha','Khan','standard'),
    (69,'PK','Mahnoor','Ahmed','human_equivalent'),
    (70,'PA','Isabella','Tejada','standard'),
    (71,'PY','Lucía','Benítez','standard'),
    (72,'PH','Bianca','Santos','standard'),
    (73,'PH','Alyssa','Mendoza','competitive'),
    (74,'PH','Camille','Reyes','standard'),
    (75,'QA','Hessa','Al-Kuwari','standard'),
    (76,'RU','Anastasia','Volkova','standard'),
    (77,'RU','Daria','Morozova','elite'),
    (78,'RU','Polina','Sokolova','standard'),
    (79,'RU','Ekaterina','Orlova','standard'),
    (80,'RU','Sofia','Lebedeva','standard'),
    (81,'RU','Alina','Makarova','standard'),
    (82,'RU','Veronika','Belova','standard'),
    (83,'RU','Ksenia','Fedorova','competitive'),
    (84,'SM','Giulia','Casadei','standard'),
    (85,'ST','Joana','da Costa','standard'),
    (86,'SA','Reem','Al-Qahtani','standard'),
    (87,'SN','Aïssatou','Ndiaye','human_equivalent'),
    (88,'SG','Jia En','Lim','standard'),
    (89,'SG','Nurul Huda','Hassan','standard'),
    (90,'LK','Kavindi','Perera','standard'),
    (91,'LK','Nethmi','Fernando','standard'),
    (92,'SD','Sara','Elhassan','competitive'),
    (93,'TJ','Madina','Rahmonova','standard'),
    (94,'TZ','Neema','Mushi','standard'),
    (95,'TG','Ama','Lawson','standard'),
    (96,'TO','Mele','Taufa','standard'),
    (97,'TT','Kiara','Mohammed','standard'),
    (98,'TR','Elif','Yılmaz','standard'),
    (99,'TR','Zeynep','Kaya','standard'),
    (100,'TR','Ece','Demir','standard'),
    (101,'TR','Selin','Aydın','competitive'),
    (102,'UG','Patricia','Namusoke','standard'),
    (103,'UA','Oksana','Melnyk','standard'),
    (104,'UA','Iryna','Kovalenko','elite'),
    (105,'UA','Mariia','Shevchenko','standard'),
    (106,'UA','Alina','Kovalchuk','standard'),
    (107,'VE','Valentina','Herrera','standard'),
    (108,'VE','Mariana','Salazar','standard'),
    (109,'VE','Gabriela','Rojas','standard'),
    (110,'VN','Minh Anh','Nguyen','standard'),
    (111,'VN','Thu Ha','Tran','standard'),
    (112,'VN','Bao Ngoc','Le','human_equivalent'),
    (113,'YE','Amal','Al-Hakimi','standard'),
    (114,'ZM','Chipo','Phiri','standard'),
    (115,'ZW','Tariro','Moyo','standard'),
    (116,'XK','Arta','Krasniqi','competitive'),
    (117,'XK','Era','Gashi','standard')
),
prepared as (
  select
    x.*,
    (300+x.seq)::smallint as ai_no,
    case
      when x.skill_tier='elite' then 468
      when x.skill_tier='human_equivalent' then 450
      when x.skill_tier='competitive' then 423
      else 350+mod(x.seq*7,43)
    end::smallint as technical_total,
    case
      when x.skill_tier='elite' then 208
      when x.skill_tier='human_equivalent' then 200
      when x.skill_tier='competitive' then 196
      else 180+mod(x.seq*5,15)
    end::smallint as physical_total,
    case mod(x.seq*7,20)
      when 0 then 'Grass' when 1 then 'Grass' when 2 then 'Grass'
      when 3 then 'Clay' when 4 then 'Clay' when 5 then 'Clay'
      when 6 then 'Clay' when 7 then 'Clay' when 8 then 'Clay'
      else 'Hard'
    end as preferred_surface,
    case
      when mod(x.seq*11,10)<4 then 'All-court'
      when mod(x.seq*11,10)<7 then 'Aggressive Baseliner'
      when mod(x.seq*11,10)<9 then 'Defensive Baseliner'
      else 'Serve & Volley'
    end as playing_style
  from proposed x
),
with_city as (
  select p.*,
         h.home_city
  from prepared p
  join lateral (
    select (array_agg(city order by sort_order))[mod(p.seq-1,count(*))::integer+1] as home_city
    from public.player_home_city_options
    where country_code=p.country_code
      and is_active
  ) h on h.home_city is not null
)
insert into public.players(
  owner_user_id,world,first_name,last_name,country_code,home_city,image_path,
  moderation_status,preferred_surface,playing_style,player_type,ai_profile_number,
  ai_starting_technical_total,ai_starting_physical_total,ai_skill_tier
)
select
  null,'WTA',first_name,last_name,country_code,home_city,null,
  'approved',preferred_surface,playing_style,'ai',ai_no,
  technical_total,physical_total,skill_tier
from with_city
order by seq;

do $$
declare
  v_batch integer;
  v_world integer;
  v_rankings integer;
  v_skills integer;
  v_dups integer;
  v_alloc_mismatch integer;
  v_elite integer;
  v_human_eq integer;
  v_competitive integer;
  v_standard integer;
begin
  select count(*) into v_batch
  from public.players
  where world='WTA' and player_type='ai' and ai_profile_number between 301 and 417;

  select count(*) into v_world
  from public.players
  where world='WTA' and player_type='ai';

  select count(*) into v_rankings
  from public.players p
  join public.player_rankings r on r.player_id=p.id
  where p.world='WTA' and p.player_type='ai' and p.ai_profile_number between 301 and 417;

  select count(*) into v_skills
  from public.players p
  join public.player_skills s on s.player_id=p.id
  where p.world='WTA' and p.player_type='ai' and p.ai_profile_number between 301 and 417;

  select count(*) into v_dups
  from (
    select lower(first_name),lower(last_name),count(*)
    from public.players
    where world='WTA'
    group by lower(first_name),lower(last_name)
    having count(*)>1
  ) d;

  with expected(country_code,expected_count) as (
    values
      ('AL',2),
      ('DZ',1),
      ('AD',1),
      ('AO',1),
      ('AM',2),
      ('AZ',1),
      ('BH',1),
      ('BD',1),
      ('BB',1),
      ('BY',2),
      ('BO',1),
      ('BW',1),
      ('CM',1),
      ('CG',1),
      ('CR',1),
      ('CI',1),
      ('CU',1),
      ('CY',2),
      ('DM',1),
      ('DO',1),
      ('EC',1),
      ('EE',1),
      ('ET',2),
      ('FJ',1),
      ('GE',1),
      ('GH',1),
      ('GW',1),
      ('GY',1),
      ('HT',1),
      ('HN',1),
      ('IS',3),
      ('ID',2),
      ('IR',1),
      ('IE',2),
      ('IL',2),
      ('JM',1),
      ('JO',1),
      ('KW',1),
      ('LV',2),
      ('LB',1),
      ('LI',1),
      ('LT',1),
      ('LU',1),
      ('MY',2),
      ('MV',1),
      ('ML',1),
      ('MT',1),
      ('MU',1),
      ('MD',1),
      ('MN',1),
      ('ME',2),
      ('MZ',1),
      ('NE',1),
      ('OM',1),
      ('PK',2),
      ('PA',1),
      ('PY',1),
      ('PH',3),
      ('QA',1),
      ('RU',8),
      ('SM',1),
      ('ST',1),
      ('SA',1),
      ('SN',1),
      ('SG',2),
      ('LK',2),
      ('SD',1),
      ('TJ',1),
      ('TZ',1),
      ('TG',1),
      ('TO',1),
      ('TT',1),
      ('TR',4),
      ('UG',1),
      ('UA',4),
      ('VE',3),
      ('VN',3),
      ('YE',1),
      ('ZM',1),
      ('ZW',1),
      ('XK',2)
  ),
  actual as (
    select country_code,count(*)::integer actual_count
    from public.players
    where world='WTA' and player_type='ai' and ai_profile_number between 301 and 417
    group by country_code
  )
  select count(*) into v_alloc_mismatch
  from expected e
  left join actual a using(country_code)
  where coalesce(a.actual_count,0)<>e.expected_count;

  select
    count(*) filter(where ai_skill_tier='elite'),
    count(*) filter(where ai_skill_tier='human_equivalent'),
    count(*) filter(where ai_skill_tier='competitive'),
    count(*) filter(where ai_skill_tier='standard')
  into v_elite,v_human_eq,v_competitive,v_standard
  from public.players
  where world='WTA' and player_type='ai' and ai_profile_number between 301 and 417;

  if v_batch<>117 or v_world<>417 or v_rankings<>117 or v_skills<>117
     or v_dups<>0 or v_alloc_mismatch<>0
     or v_elite<>4 or v_human_eq<>5 or v_competitive<>12 or v_standard<>96 then
    raise exception 'WTA expansion validation failed: batch %, world %, rankings %, skills %, duplicates %, allocation mismatch %, tiers %/%/%/%',
      v_batch,v_world,v_rankings,v_skills,v_dups,v_alloc_mismatch,v_elite,v_human_eq,v_competitive,v_standard;
  end if;
end;
$$;

-- System Health / Control Center monitoring for the permanent population expansion.
insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'check:wta_ai_population_expansion',
  'WTA AI population expansion',
  'Players & Tactics',
  'Validates the 117-player WTA expansion, country allocation, rankings, skills and Kosovo availability.',
  'business_check',null,false,'warning',360,1440,true,224
),
(
  'cron:tennis-wta-ai-population-health-v1',
  'WTA AI population health schedule',
  'Players & Tactics',
  'Runs the WTA AI population integrity check every six hours.',
  'cron','tennis-wta-ai-population-health-v1',false,'warning',360,780,true,225
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();

create or replace function public.check_wta_ai_population_expansion_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_total integer:=0;
  v_batch integer:=0;
  v_rankings integer:=0;
  v_skills integer:=0;
  v_dups integer:=0;
  v_alloc_mismatch integer:=0;
  v_kosovo_ok boolean:=false;
  v_portraits_assigned integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  select count(*) into v_total
  from public.players
  where world='WTA' and player_type='ai' and moderation_status='approved';

  select count(*) into v_batch
  from public.players
  where world='WTA' and player_type='ai'
    and moderation_status='approved'
    and ai_profile_number between 301 and 417;

  select count(*) into v_rankings
  from public.players p
  join public.player_rankings r on r.player_id=p.id
  where p.world='WTA' and p.player_type='ai'
    and p.ai_profile_number between 301 and 417;

  select count(*) into v_skills
  from public.players p
  join public.player_skills s on s.player_id=p.id
  where p.world='WTA' and p.player_type='ai'
    and p.ai_profile_number between 301 and 417;

  select count(*) into v_dups
  from (
    select lower(first_name),lower(last_name),count(*)
    from public.players
    where world='WTA'
    group by lower(first_name),lower(last_name)
    having count(*)>1
  ) d;

  with expected(country_code,expected_count) as (
    values
      ('AL',2),
      ('DZ',1),
      ('AD',1),
      ('AO',1),
      ('AM',2),
      ('AZ',1),
      ('BH',1),
      ('BD',1),
      ('BB',1),
      ('BY',2),
      ('BO',1),
      ('BW',1),
      ('CM',1),
      ('CG',1),
      ('CR',1),
      ('CI',1),
      ('CU',1),
      ('CY',2),
      ('DM',1),
      ('DO',1),
      ('EC',1),
      ('EE',1),
      ('ET',2),
      ('FJ',1),
      ('GE',1),
      ('GH',1),
      ('GW',1),
      ('GY',1),
      ('HT',1),
      ('HN',1),
      ('IS',3),
      ('ID',2),
      ('IR',1),
      ('IE',2),
      ('IL',2),
      ('JM',1),
      ('JO',1),
      ('KW',1),
      ('LV',2),
      ('LB',1),
      ('LI',1),
      ('LT',1),
      ('LU',1),
      ('MY',2),
      ('MV',1),
      ('ML',1),
      ('MT',1),
      ('MU',1),
      ('MD',1),
      ('MN',1),
      ('ME',2),
      ('MZ',1),
      ('NE',1),
      ('OM',1),
      ('PK',2),
      ('PA',1),
      ('PY',1),
      ('PH',3),
      ('QA',1),
      ('RU',8),
      ('SM',1),
      ('ST',1),
      ('SA',1),
      ('SN',1),
      ('SG',2),
      ('LK',2),
      ('SD',1),
      ('TJ',1),
      ('TZ',1),
      ('TG',1),
      ('TO',1),
      ('TT',1),
      ('TR',4),
      ('UG',1),
      ('UA',4),
      ('VE',3),
      ('VN',3),
      ('YE',1),
      ('ZM',1),
      ('ZW',1),
      ('XK',2)
  ),
  actual as (
    select country_code,count(*)::integer actual_count
    from public.players
    where world='WTA' and player_type='ai'
      and ai_profile_number between 301 and 417
    group by country_code
  )
  select count(*) into v_alloc_mismatch
  from expected e
  left join actual a using(country_code)
  where coalesce(a.actual_count,0)<>e.expected_count;

  select exists(
    select 1
    from public.get_player_creation_countries_v1()
    where code='XK'
  ) and exists(
    select 1 from public.player_home_city_options
    where country_code='XK' and is_active
  ) into v_kosovo_ok;

  select count(*) into v_portraits_assigned
  from public.players
  where world='WTA' and player_type='ai'
    and ai_profile_number between 301 and 417
    and image_path is not null;

  v_problem_count :=
    case when v_total<417 then 1 else 0 end
    +case when v_batch<>117 then 1 else 0 end
    +case when v_rankings<>117 then 1 else 0 end
    +case when v_skills<>117 then 1 else 0 end
    +v_dups
    +v_alloc_mismatch
    +case when v_kosovo_ok then 0 else 1 end;

  v_details:=jsonb_build_object(
    'approved_wta_ai_total',v_total,
    'expansion_batch_players',v_batch,
    'expansion_ranking_rows',v_rankings,
    'expansion_skill_rows',v_skills,
    'duplicate_wta_names',v_dups,
    'country_allocation_mismatches',v_alloc_mismatch,
    'kosovo_approved_and_selectable',v_kosovo_ok,
    'expansion_portraits_assigned',v_portraits_assigned,
    'expansion_portraits_pending',greatest(0,117-v_portraits_assigned)
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:wta_ai_population_expansion',
      'warning',
      'WTA AI population expansion requires attention',
      format('%s WTA AI population integrity issue(s) detected.',v_problem_count),
      'business:wta-ai-population-expansion',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:wta-ai-population-expansion',
      'The 117-player WTA AI population expansion is structurally healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:wta_ai_population_expansion',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s WTA AI population integrity issue(s).',v_problem_count)
      else format('%s approved WTA AI players; expansion batch 117/117 healthy.',v_total)
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
end;
$$;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-wta-ai-population-health-v1'
  limit 1;
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-wta-ai-population-health-v1',
  '17 */6 * * *',
  $cron$select public.check_wta_ai_population_expansion_v1();$cron$
);

select public.check_wta_ai_population_expansion_v1();
