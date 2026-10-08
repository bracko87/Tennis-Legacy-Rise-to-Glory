-- Publish the curated 50-piece Private Life Art catalogue.
-- Historical generic art rows are retained but deactivated for ownership/history safety.

create temporary table tmp_art_catalog_50_v1 (
  catalog_order integer primary key,
  code text unique not null,
  artist text not null,
  title text not null,
  art_type text not null,
  medium text not null,
  artwork_year integer not null,
  dimensions_or_edition text not null,
  purchase_price bigint not null,
  tier integer not null,
  prestige integer not null,
  rarity text not null,
  annual_running_cost bigint not null,
  annual_value_rate_bps integer not null,
  resale_discount_bps integer not null,
  description text not null
) on commit drop;

insert into tmp_art_catalog_50_v1(
  catalog_order,code,artist,title,art_type,medium,artwork_year,dimensions_or_edition,
  purchase_price,tier,prestige,rarity,annual_running_cost,annual_value_rate_bps,
  resale_discount_bps,description
)
values
  (1,'art_01_quiet_morning','Lena Hartwig','Quiet Morning','Fine-art photography','Archival pigment print',2022,'Edition 1/25',10000::bigint,1,5,'common',80::bigint,187,1233,'Quiet Morning by Lena Hartwig, a 2022 fine-art photography work in archival pigment print.'),
  (2,'art_02_tuscan_light','Marco Bellini','Tuscan Light','Painting','Oil on canvas',2021,'80 × 60 cm',14500::bigint,1,7,'common',116::bigint,199,1216,'Tuscan Light by Marco Bellini, a 2021 painting work in oil on canvas.'),
  (3,'art_03_rain_in_kyoto','Hana Mori','Rain in Kyoto','Work on paper','Watercolor on paper',2020,'70 × 50 cm',18000::bigint,1,8,'common',144::bigint,211,1199,'Rain in Kyoto by Hana Mori, a 2020 work on paper work in watercolor on paper.'),
  (4,'art_04_blue_structure_no_4','Adrian Voss','Blue Structure No. 4','Painting','Acrylic on canvas',2023,'90 × 90 cm',24000::bigint,1,10,'uncommon',192::bigint,223,1182,'Blue Structure No. 4 by Adrian Voss, a 2023 painting work in acrylic on canvas.'),
  (5,'art_05_winter_garden','Claire Beaumont','Winter Garden','Painting','Oil on canvas',2019,'100 × 75 cm',31000::bigint,1,12,'uncommon',248::bigint,235,1165,'Winter Garden by Claire Beaumont, a 2019 painting work in oil on canvas.'),
  (6,'art_06_calle_roja','Rafael Serrano','Calle Roja','Mixed media','Mixed media on panel',2022,'100 × 80 cm',39500::bigint,1,14,'uncommon',316::bigint,247,1148,'Calle Roja by Rafael Serrano, a 2022 mixed media work in mixed media on panel.'),
  (7,'art_07_the_dancer','Elisa Romano','The Dancer','Sculpture','Bronze',2020,'62 cm',48000::bigint,1,16,'uncommon',384::bigint,259,1131,'The Dancer by Elisa Romano, a 2020 sculpture work in bronze.'),
  (8,'art_08_northern_silence','Niklas Berg','Northern Silence','Fine-art photography','Archival pigment print',2021,'Edition 2/15',58000::bigint,1,18,'uncommon',464::bigint,271,1114,'Northern Silence by Niklas Berg, a 2021 fine-art photography work in archival pigment print.'),
  (9,'art_09_golden_fields','Sofia Bellini','Golden Fields','Painting','Oil on linen',2018,'120 × 85 cm',72500::bigint,1,20,'uncommon',580::bigint,283,1097,'Golden Fields by Sofia Bellini, a 2018 painting work in oil on linen.'),
  (10,'art_10_city_rhythm','Samuel Okoro','City Rhythm','Painting','Acrylic on canvas',2023,'130 × 100 cm',90000::bigint,1,22,'uncommon',720::bigint,295,1080,'City Rhythm by Samuel Okoro, a 2023 painting work in acrylic on canvas.'),
  (11,'art_11_after_the_storm','Elise Moreau','After the Storm','Painting','Oil on canvas',2017,'140 × 100 cm',115000::bigint,2,24,'rare',1150::bigint,307,1063,'After the Storm by Elise Moreau, a 2017 painting work in oil on canvas.'),
  (12,'art_12_forma_ii','Luca Ferrano','Forma II','Sculpture','Marble',2019,'78 cm',145000::bigint,2,26,'rare',1450::bigint,319,1046,'Forma II by Luca Ferrano, a 2019 sculpture work in marble.'),
  (13,'art_13_banat_afternoon','Mila Petrovic','Banat Afternoon','Painting','Oil on canvas',2020,'150 × 100 cm',175000::bigint,2,27,'rare',1750::bigint,331,1029,'Banat Afternoon by Mila Petrovic, a 2020 painting work in oil on canvas.'),
  (14,'art_14_evening_on_the_seine','Henri Valmont','Evening on the Seine','Painting','Oil on canvas',2015,'160 × 110 cm',210000::bigint,2,29,'rare',2100::bigint,343,1012,'Evening on the Seine by Henri Valmont, a 2015 painting work in oil on canvas.'),
  (15,'art_15_fragmented_memory','Clara Weiss','Fragmented Memory','Work on paper','Charcoal and graphite on paper',2016,'110 × 80 cm',260000::bigint,2,31,'rare',2600::bigint,355,995,'Fragmented Memory by Clara Weiss, a 2016 work on paper work in charcoal and graphite on paper.'),
  (16,'art_16_pacific_horizon','Diego Marquez','Pacific Horizon','Painting','Oil on canvas',2019,'180 × 120 cm',325000::bigint,2,33,'rare',3250::bigint,367,978,'Pacific Horizon by Diego Marquez, a 2019 painting work in oil on canvas.'),
  (17,'art_17_ancestral_line','Amara Okafor','Ancestral Line','Sculpture','Bronze',2018,'110 cm',395000::bigint,2,35,'rare',3950::bigint,379,961,'Ancestral Line by Amara Okafor, a 2018 sculpture work in bronze.'),
  (18,'art_18_neon_tokyo','Yuki Tanaka','Neon Tokyo','Fine-art photography','Archival pigment print',2020,'Edition 1/10',475000::bigint,2,37,'rare',4750::bigint,391,944,'Neon Tokyo by Yuki Tanaka, a 2020 fine-art photography work in archival pigment print.'),
  (19,'art_19_the_red_room','Matteo Caruso','The Red Room','Painting','Oil on canvas',2014,'190 × 140 cm',575000::bigint,3,39,'rare',5750::bigint,403,927,'The Red Room by Matteo Caruso, a 2014 painting work in oil on canvas.'),
  (20,'art_20_white_noise','Ingrid Falk','White Noise','Mixed media','Mixed media on canvas',2017,'200 × 150 cm',690000::bigint,3,41,'rare',6900::bigint,415,910,'White Noise by Ingrid Falk, a 2017 mixed media work in mixed media on canvas.'),
  (21,'art_21_weightless','Pavel Novak','Weightless','Sculpture','Stainless steel',2018,'180 cm',825000::bigint,3,43,'very_rare',8250::bigint,427,893,'Weightless by Pavel Novak, a 2018 sculpture work in stainless steel.'),
  (22,'art_22_jardim_azul','Gabriela Costa','Jardim Azul','Painting','Oil on canvas',2013,'200 × 160 cm',975000::bigint,3,44,'very_rare',9750::bigint,439,876,'Jardim Azul by Gabriela Costa, a 2013 painting work in oil on canvas.'),
  (23,'art_23_paris_04_17','Theo Lambert','Paris, 04:17','Fine-art photography','Archival pigment print',2016,'Edition 1/7',1150000::bigint,3,46,'very_rare',11500::bigint,451,859,'Paris, 04:17 by Theo Lambert, a 2016 fine-art photography work in archival pigment print.'),
  (24,'art_24_desert_crown','Nadia El-Masri','Desert Crown','Painting','Oil and gold leaf on canvas',2015,'210 × 170 cm',1350000::bigint,3,48,'very_rare',13500::bigint,463,842,'Desert Crown by Nadia El-Masri, a 2015 painting work in oil and gold leaf on canvas.'),
  (25,'art_25_black_sun','Viktor Dragan','Black Sun','Painting','Oil on canvas',2012,'220 × 180 cm',1600000::bigint,3,50,'very_rare',16000::bigint,475,825,'Black Sun by Viktor Dragan, a 2012 painting work in oil on canvas.'),
  (26,'art_26_primavera_no_7','Sofia Bellini','Primavera No. 7','Painting','Oil on linen',2011,'230 × 170 cm',1900000::bigint,3,52,'very_rare',20900::bigint,487,808,'Primavera No. 7 by Sofia Bellini, a 2011 painting work in oil on linen.'),
  (27,'art_27_continuum_iii','Amara Okafor','Continuum III','Sculpture','Bronze',2016,'210 cm',2250000::bigint,4,54,'very_rare',24750::bigint,499,791,'Continuum III by Amara Okafor, a 2016 sculpture work in bronze.'),
  (28,'art_28_untitled_no_19','Alexander Reiss','Untitled No. 19','Painting','Oil and pigment on canvas',2010,'240 × 190 cm',2650000::bigint,4,55,'very_rare',29150::bigint,511,774,'Untitled No. 19 by Alexander Reiss, a 2010 painting work in oil and pigment on canvas.'),
  (29,'art_29_seoul_after_midnight','Jun Park','Seoul After Midnight','Painting','Acrylic on canvas',2018,'250 × 180 cm',3100000::bigint,4,57,'very_rare',34100::bigint,523,757,'Seoul After Midnight by Jun Park, a 2018 painting work in acrylic on canvas.'),
  (30,'art_30_revolution_square','Rafael Serrano','Revolution Square','Mixed media','Mixed media on panel',2011,'260 × 200 cm',3650000::bigint,4,59,'very_rare',40150::bigint,535,740,'Revolution Square by Rafael Serrano, a 2011 mixed media work in mixed media on panel.'),
  (31,'art_31_eternal_spring','Lucia Verani','Eternal Spring','Sculpture','Carrara marble',2014,'240 cm',4250000::bigint,4,61,'very_rare',46750::bigint,547,723,'Eternal Spring by Lucia Verani, a 2014 sculpture work in carrara marble.'),
  (32,'art_32_la_nuit_rouge','Henri Valmont','La Nuit Rouge','Painting','Oil on canvas',2008,'250 × 200 cm',4950000::bigint,4,63,'very_rare',54450::bigint,559,706,'La Nuit Rouge by Henri Valmont, a 2008 painting work in oil on canvas.'),
  (33,'art_33_the_crossing','Nikolai Arsenov','The Crossing','Painting','Oil on canvas',2007,'270 × 210 cm',5750000::bigint,4,64,'very_rare',63250::bigint,571,689,'The Crossing by Nikolai Arsenov, a 2007 painting work in oil on canvas.'),
  (34,'art_34_lumiere_no_3','Amelie Laurent','Lumière No. 3','Sculpture','Glass and steel',2015,'260 cm',6600000::bigint,4,66,'very_rare',72600::bigint,583,672,'Lumière No. 3 by Amelie Laurent, a 2015 sculpture work in glass and steel.'),
  (35,'art_35_floating_city','Kaito Nakamura','Floating City','Painting','Oil and acrylic on canvas',2012,'280 × 220 cm',7500000::bigint,5,68,'very_rare',82500::bigint,595,655,'Floating City by Kaito Nakamura, a 2012 painting work in oil and acrylic on canvas.'),
  (36,'art_36_red_kingdom','Viktor Dragan','Red Kingdom','Painting','Oil on canvas',2006,'300 × 230 cm',8750000::bigint,5,70,'legendary',96250::bigint,607,638,'Red Kingdom by Viktor Dragan, a 2006 painting work in oil on canvas.'),
  (37,'art_37_ascension','Amara Okafor','Ascension','Sculpture','Monumental bronze',2012,'4.2 m',10000000::bigint,5,71,'legendary',110000::bigint,619,621,'Ascension by Amara Okafor, a 2012 sculpture work in monumental bronze.'),
  (38,'art_38_the_last_summer','Elise Moreau','The Last Summer','Painting','Oil on linen',2004,'300 × 240 cm',11500000::bigint,5,73,'legendary',126500::bigint,631,604,'The Last Summer by Elise Moreau, a 2004 painting work in oil on linen.'),
  (39,'art_39_geometry_of_silence','Adrian Voss','Geometry of Silence','Painting','Oil and acrylic on canvas',2009,'320 × 240 cm',13250000::bigint,5,75,'legendary',145750::bigint,643,587,'Geometry of Silence by Adrian Voss, a 2009 painting work in oil and acrylic on canvas.'),
  (40,'art_40_imperium','Luca Ferrano','Imperium','Sculpture','Monumental marble',2008,'4.5 m',15000000::bigint,5,76,'legendary',165000::bigint,655,570,'Imperium by Luca Ferrano, a 2008 sculpture work in monumental marble.'),
  (41,'art_41_sakura_forever','Hana Mori','Sakura Forever','Painting','Oil and gold leaf on canvas',2006,'330 × 250 cm',17500000::bigint,5,78,'legendary',210000::bigint,667,553,'Sakura Forever by Hana Mori, a 2006 painting work in oil and gold leaf on canvas.'),
  (42,'art_42_nocturne_de_madrid','Mateo Alvarez','Nocturne de Madrid','Painting','Oil on canvas',2003,'340 × 260 cm',20000000::bigint,6,80,'legendary',240000::bigint,679,536,'Nocturne de Madrid by Mateo Alvarez, a 2003 painting work in oil on canvas.'),
  (43,'art_43_empire_of_winter','Nikolai Arsenov','Empire of Winter','Painting','Oil on canvas',2001,'360 × 270 cm',23500000::bigint,6,82,'legendary',282000::bigint,691,519,'Empire of Winter by Nikolai Arsenov, a 2001 painting work in oil on canvas.'),
  (44,'art_44_infinite_light','Amelie Laurent','Infinite Light','Installation','Light installation',2010,'Room-scale',27500000::bigint,6,84,'legendary',330000::bigint,703,502,'Infinite Light by Amelie Laurent, a 2010 installation work in light installation.'),
  (45,'art_45_garden_of_eternity','Sofia Bellini','Garden of Eternity','Painting','Oil on canvas',1998,'380 × 280 cm',32000000::bigint,6,85,'legendary',384000::bigint,715,485,'Garden of Eternity by Sofia Bellini, a 1998 painting work in oil on canvas.'),
  (46,'art_46_the_last_emperor','Viktor Dragan','The Last Emperor','Painting','Monumental oil on canvas',1997,'400 × 300 cm',38000000::bigint,6,87,'legendary',456000::bigint,727,468,'The Last Emperor by Viktor Dragan, a 1997 painting work in monumental oil on canvas.'),
  (47,'art_47_origin','Amara Okafor','Origin','Installation','Monumental bronze installation',2005,'7 m',45000000::bigint,7,89,'legendary',540000::bigint,739,451,'Origin by Amara Okafor, a 2005 installation work in monumental bronze installation.'),
  (48,'art_48_midnight_in_paris','Henri Valmont','Midnight in Paris','Painting','Oil on canvas',1995,'420 × 310 cm',55000000::bigint,7,91,'legendary',660000::bigint,751,434,'Midnight in Paris by Henri Valmont, a 1995 painting work in oil on canvas.'),
  (49,'art_49_the_silent_century','Alexander Reiss','The Silent Century','Painting','Multi-panel oil painting',1992,'6 panels · 8 m wide',68000000::bigint,8,93,'legendary',816000::bigint,763,417,'The Silent Century by Alexander Reiss, a 1992 painting work in multi-panel oil painting.'),
  (50,'art_50_crown_of_civilization','Viktor Dragan','Crown of Civilization','Installation','Bronze, stone and light',1990,'12 × 8 m',82500000::bigint,8,95,'legendary',990000::bigint,775,400,'Crown of Civilization by Viktor Dragan, a 1990 installation work in bronze, stone and light.');

do $$
declare
  v_count integer;
  v_min bigint;
  v_max bigint;
begin
  select count(*),min(purchase_price),max(purchase_price)
  into v_count,v_min,v_max
  from tmp_art_catalog_50_v1;

  if v_count<>50 or v_min<>10000 or v_max<>82500000 then
    raise exception
      'Art catalogue preflight failed: count %, min %, max %.',
      v_count,v_min,v_max;
  end if;
end;
$$;

update public.private_life_asset_catalog
set active=false,
    metadata=coalesce(metadata,'{}'::jsonb)
      || jsonb_build_object(
        'market_status','retired_from_market',
        'retired_reason','replaced_by_curated_art_catalog_50_v1',
        'retired_at','2026-10-08'
      ),
    updated_at=now()
where category='art'
  and code not in ('art_01_quiet_morning','art_02_tuscan_light','art_03_rain_in_kyoto','art_04_blue_structure_no_4','art_05_winter_garden','art_06_calle_roja','art_07_the_dancer','art_08_northern_silence','art_09_golden_fields','art_10_city_rhythm','art_11_after_the_storm','art_12_forma_ii','art_13_banat_afternoon','art_14_evening_on_the_seine','art_15_fragmented_memory','art_16_pacific_horizon','art_17_ancestral_line','art_18_neon_tokyo','art_19_the_red_room','art_20_white_noise','art_21_weightless','art_22_jardim_azul','art_23_paris_04_17','art_24_desert_crown','art_25_black_sun','art_26_primavera_no_7','art_27_continuum_iii','art_28_untitled_no_19','art_29_seoul_after_midnight','art_30_revolution_square','art_31_eternal_spring','art_32_la_nuit_rouge','art_33_the_crossing','art_34_lumiere_no_3','art_35_floating_city','art_36_red_kingdom','art_37_ascension','art_38_the_last_summer','art_39_geometry_of_silence','art_40_imperium','art_41_sakura_forever','art_42_nocturne_de_madrid','art_43_empire_of_winter','art_44_infinite_light','art_45_garden_of_eternity','art_46_the_last_emperor','art_47_origin','art_48_midnight_in_paris','art_49_the_silent_century','art_50_crown_of_civilization');

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,
  image_url,active,metadata
)
select
  a.code,
  'art',
  a.title,
  a.tier,
  a.description,
  a.purchase_price,
  a.prestige,
  a.rarity,
  a.annual_running_cost,
  a.annual_value_rate_bps,
  a.resale_discount_bps,
  'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',
  true,
  jsonb_build_object(
    'catalog_order',a.catalog_order,
    'artist',a.artist,
    'artist_fictional',true,
    'artwork_title',a.title,
    'art_type',a.art_type,
    'medium',a.medium,
    'artwork_year',a.artwork_year,
    'dimensions_or_edition',a.dimensions_or_edition,
    'full_display_name',a.artist||' · '||a.title,
    'market_currency','USD',
    'pricing_currency','USD',
    'base_market_price',a.purchase_price,
    'catalog_version','curated_art_catalog_50_v1',
    'insurance_and_conservation_cost',true,
    'image_status','placeholder_waiting_for_upload',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Art',
    'expected_image_storage_path','Private Life/Art/Art '||a.catalog_order||' - '||a.title||'.png',
    'pricing_reviewed_at','2026-10-08'
  )
from tmp_art_catalog_50_v1 a
on conflict(code) do update set
  category=excluded.category,
  name=excluded.name,
  tier=excluded.tier,
  description=excluded.description,
  purchase_price=excluded.purchase_price,
  prestige=excluded.prestige,
  rarity=excluded.rarity,
  annual_running_cost=excluded.annual_running_cost,
  annual_value_rate_bps=excluded.annual_value_rate_bps,
  resale_discount_bps=excluded.resale_discount_bps,
  image_url=excluded.image_url,
  active=true,
  metadata=excluded.metadata,
  updated_at=now();

do $$
declare
  v_active integer;
  v_exact integer;
  v_wrong integer;
  v_old_active integer;
  v_orders integer;
begin
  select count(*) into v_active
  from public.private_life_asset_catalog
  where category='art' and active=true;

  select count(*)
  into v_exact
  from tmp_art_catalog_50_v1 a
  join public.private_life_asset_catalog c
    on c.code=a.code
   and c.category='art'
   and c.active=true;

  select count(*)
  into v_wrong
  from tmp_art_catalog_50_v1 a
  join public.private_life_asset_catalog c on c.code=a.code
  where c.name<>a.title
     or c.purchase_price<>a.purchase_price
     or c.tier<>a.tier
     or c.prestige<>a.prestige
     or c.rarity<>a.rarity
     or c.annual_running_cost<>a.annual_running_cost
     or c.annual_value_rate_bps<>a.annual_value_rate_bps
     or c.resale_discount_bps<>a.resale_discount_bps
     or c.metadata->>'artist'<>a.artist
     or c.metadata->>'artwork_title'<>a.title
     or c.metadata->>'art_type'<>a.art_type
     or c.metadata->>'medium'<>a.medium
     or (c.metadata->>'artwork_year')::integer<>a.artwork_year
     or c.metadata->>'dimensions_or_edition'<>a.dimensions_or_edition
     or (c.metadata->>'catalog_order')::integer<>a.catalog_order;

  select count(*) into v_old_active
  from public.private_life_asset_catalog
  where category='art'
    and active=true
    and code not in ('art_01_quiet_morning','art_02_tuscan_light','art_03_rain_in_kyoto','art_04_blue_structure_no_4','art_05_winter_garden','art_06_calle_roja','art_07_the_dancer','art_08_northern_silence','art_09_golden_fields','art_10_city_rhythm','art_11_after_the_storm','art_12_forma_ii','art_13_banat_afternoon','art_14_evening_on_the_seine','art_15_fragmented_memory','art_16_pacific_horizon','art_17_ancestral_line','art_18_neon_tokyo','art_19_the_red_room','art_20_white_noise','art_21_weightless','art_22_jardim_azul','art_23_paris_04_17','art_24_desert_crown','art_25_black_sun','art_26_primavera_no_7','art_27_continuum_iii','art_28_untitled_no_19','art_29_seoul_after_midnight','art_30_revolution_square','art_31_eternal_spring','art_32_la_nuit_rouge','art_33_the_crossing','art_34_lumiere_no_3','art_35_floating_city','art_36_red_kingdom','art_37_ascension','art_38_the_last_summer','art_39_geometry_of_silence','art_40_imperium','art_41_sakura_forever','art_42_nocturne_de_madrid','art_43_empire_of_winter','art_44_infinite_light','art_45_garden_of_eternity','art_46_the_last_emperor','art_47_origin','art_48_midnight_in_paris','art_49_the_silent_century','art_50_crown_of_civilization');

  select count(distinct (metadata->>'catalog_order')::integer)
  into v_orders
  from public.private_life_asset_catalog
  where category='art' and active=true;

  if v_active<>50 or v_exact<>50 or v_wrong<>0 or v_old_active<>0 or v_orders<>50 then
    raise exception
      'Art catalogue validation failed: active %, exact %, wrong %, old active %, orders %.',
      v_active,v_exact,v_wrong,v_old_active,v_orders;
  end if;
end;
$$;
