-- Publish the curated 51-item Collectibles catalogue.
-- Historical collectible rows are retained but deactivated for ownership/history safety.

create temporary table tmp_collectibles_51_v1 (
  catalog_order integer primary key,
  code text unique not null,
  name text not null,
  collectible_type text not null,
  era_or_year text not null,
  collectible_details text not null,
  purchase_price bigint not null,
  tier integer not null,
  prestige integer not null,
  rarity text not null,
  annual_running_cost bigint not null,
  annual_value_rate_bps integer not null,
  resale_discount_bps integer not null,
  description text not null
) on commit drop;

insert into tmp_collectibles_51_v1(
  catalog_order,code,name,collectible_type,era_or_year,collectible_details,
  purchase_price,tier,prestige,rarity,annual_running_cost,
  annual_value_rate_bps,resale_discount_bps,description
)
values
  (1,'collectible_01_silver_ace_rookie_card','Silver Ace Rookie Card','Sports trading card','2024','Limited rookie issue, 1/500',300::bigint,1,4,'common',0::bigint,150,1400,'Silver Ace Rookie Card, a sports trading card collectible from 2024. Limited rookie issue, 1/500.'),
  (2,'collectible_02_continental_open_match_ball','Continental Open Match Ball','Tennis memorabilia','2023','Tournament-used display ball',450::bigint,1,5,'common',0::bigint,150,1400,'Continental Open Match Ball, a tennis memorabilia collectible from 2023. Tournament-used display ball.'),
  (3,'collectible_03_alpine_rally_miniature','Alpine Rally Miniature','Scale model','1998','Hand-finished 1:18 collector model',650::bigint,1,7,'common',0::bigint,150,1400,'Alpine Rally Miniature, a scale model collectible from 1998. Hand-finished 1:18 collector model.'),
  (4,'collectible_04_moonlight_comics_1','Moonlight Comics #1','Comic book','2007','First issue, high-grade copy',900::bigint,1,8,'common',0::bigint,150,1400,'Moonlight Comics #1, a comic book collectible from 2007. First issue, high-grade copy.'),
  (5,'collectible_05_victory_series_player_card','Victory Series Player Card','Sports trading card','2018','Foil parallel, 1/100',1200::bigint,1,10,'common',0::bigint,150,1400,'Victory Series Player Card, a sports trading card collectible from 2018. Foil parallel, 1/100.'),
  (6,'collectible_06_royal_crest_silver_coin','Royal Crest Silver Coin','Coin','1965','Proof silver commemorative',1600::bigint,1,11,'common',0::bigint,150,1400,'Royal Crest Silver Coin, a coin collectible from 1965. Proof silver commemorative.'),
  (7,'collectible_07_grand_slam_signed_cap','Grand Slam Signed Cap','Sports memorabilia','2022','Signed by fictional champion Adrian Vale',2100::bigint,2,13,'uncommon',0::bigint,200,1250,'Grand Slam Signed Cap, a sports memorabilia collectible from 2022. Signed by fictional champion Adrian Vale.'),
  (8,'collectible_08_aero_racer_tin_toy','Aero Racer Tin Toy','Vintage toy','1956','Original lithographed tin racer',2750::bigint,2,14,'uncommon',0::bigint,200,1250,'Aero Racer Tin Toy, a vintage toy collectible from 1956. Original lithographed tin racer.'),
  (9,'collectible_09_continental_postage_sheet','Continental Postage Sheet','Stamps','1948','Complete mint sheet',3500::bigint,2,16,'uncommon',0::bigint,200,1250,'Continental Postage Sheet, a stamps collectible from 1948. Complete mint sheet.'),
  (10,'collectible_10_golden_serve_racket','Golden Serve Racket','Tennis memorabilia','2016','Match-used racket, authenticated',4500::bigint,2,17,'uncommon',0::bigint,200,1250,'Golden Serve Racket, a tennis memorabilia collectible from 2016. Match-used racket, authenticated.'),
  (11,'collectible_11_aurora_comics_1','Aurora Comics #1','Comic book','1984','Near-mint first appearance',5800::bigint,2,19,'uncommon',0::bigint,200,1250,'Aurora Comics #1, a comic book collectible from 1984. Near-mint first appearance.'),
  (12,'collectible_12_crown_eagle_gold_coin','Crown Eagle Gold Coin','Coin','1912','Historic gold sovereign-style coin',7250::bigint,2,20,'uncommon',0::bigint,200,1250,'Crown Eagle Gold Coin, a coin collectible from 1912. Historic gold sovereign-style coin.'),
  (13,'collectible_13_champion_series_card_no_7','Champion Series Card No. 7','Sports trading card','2001','Autographed card, 1/50',9000::bigint,2,22,'uncommon',0::bigint,200,1250,'Champion Series Card No. 7, a sports trading card collectible from 2001. Autographed card, 1/50.'),
  (14,'collectible_14_imperial_red_stamp_pair','Imperial Red Stamp Pair','Stamps','1910','Rare unused pair',11500::bigint,3,23,'rare',29::bigint,275,1100,'Imperial Red Stamp Pair, a stamps collectible from 1910. Rare unused pair.'),
  (15,'collectible_15_grand_prix_driver_helmet','Grand Prix Driver Helmet','Motorsports memorabilia','2019','Race-used helmet from fictional driver Luca Moretti',14000::bigint,3,25,'rare',35::bigint,275,1100,'Grand Prix Driver Helmet, a motorsports memorabilia collectible from 2019. Race-used helmet from fictional driver Luca Moretti.'),
  (16,'collectible_16_star_voyager_figure_set','Star Voyager Figure Set','Vintage toy','1979','Complete boxed first-edition set',17500::bigint,3,26,'rare',44::bigint,275,1100,'Star Voyager Figure Set, a vintage toy collectible from 1979. Complete boxed first-edition set.'),
  (17,'collectible_17_masters_final_match_ball','Masters Final Match Ball','Tennis memorabilia','2014','Championship-point ball in display case',21000::bigint,3,27,'rare',53::bigint,275,1100,'Masters Final Match Ball, a tennis memorabilia collectible from 2014. Championship-point ball in display case.'),
  (18,'collectible_18_liberty_head_gold_piece','Liberty Head Gold Piece','Coin','1886','High-grade 19th-century gold coin',26000::bigint,3,29,'rare',65::bigint,275,1100,'Liberty Head Gold Piece, a coin collectible from 1886. High-grade 19th-century gold coin.'),
  (19,'collectible_19_crimson_detective_1','Crimson Detective #1','Comic book','1963','Key silver-age issue',32000::bigint,3,30,'rare',80::bigint,275,1100,'Crimson Detective #1, a comic book collectible from 1963. Key silver-age issue.'),
  (20,'collectible_20_first_flight_postal_cover','First Flight Postal Cover','Postal collectible','1931','Historic inaugural flight cover',39000::bigint,3,32,'rare',98::bigint,275,1100,'First Flight Postal Cover, a postal collectible collectible from 1931. Historic inaugural flight cover.'),
  (21,'collectible_21_world_champion_jersey','World Champion Jersey','Sports memorabilia','2008','Signed championship jersey',47500::bigint,3,33,'rare',119::bigint,275,1100,'World Champion Jersey, a sports memorabilia collectible from 2008. Signed championship jersey.'),
  (22,'collectible_22_empire_crown_stamp','Empire Crown Stamp','Stamp','1872','Rare single with certificate',57500::bigint,4,35,'rare',144::bigint,350,950,'Empire Crown Stamp, a stamp collectible from 1872. Rare single with certificate.'),
  (23,'collectible_23_meteorite_slice_orion','Meteorite Slice “Orion”','Natural collectible','Ancient','Polished iron meteorite section',69000::bigint,4,36,'rare',173::bigint,350,950,'Meteorite Slice “Orion”, a natural collectible collectible from Ancient. Polished iron meteorite section.'),
  (24,'collectible_24_heritage_grand_slam_racket','Heritage Grand Slam Racket','Tennis memorabilia','1996','Title-winning racket from fictional legend Viktor Marek',82500::bigint,4,37,'rare',206::bigint,350,950,'Heritage Grand Slam Racket, a tennis memorabilia collectible from 1996. Title-winning racket from fictional legend Viktor Marek.'),
  (25,'collectible_25_atlas_gold_proof_set','Atlas Gold Proof Set','Coins','1935','Complete five-coin proof set',98000::bigint,4,39,'rare',245::bigint,350,950,'Atlas Gold Proof Set, a coins collectible from 1935. Complete five-coin proof set.'),
  (26,'collectible_26_the_navigator_first_edition','The Navigator — First Edition','Rare book','1814','Leather-bound first printing',120000::bigint,4,40,'very_rare',480::bigint,350,950,'The Navigator — First Edition, a rare book collectible from 1814. Leather-bound first printing.'),
  (27,'collectible_27_silver_screen_hero_costume','Silver Screen Hero Costume','Film memorabilia','1987','Screen-used costume from fictional classic',145000::bigint,4,41,'very_rare',580::bigint,350,950,'Silver Screen Hero Costume, a film memorabilia collectible from 1987. Screen-used costume from fictional classic.'),
  (28,'collectible_28_diamond_ace_rookie_card','Diamond Ace Rookie Card','Sports trading card','1992','Gem-mint rookie, 1/25',175000::bigint,5,43,'very_rare',700::bigint,425,800,'Diamond Ace Rookie Card, a sports trading card collectible from 1992. Gem-mint rookie, 1/25.'),
  (29,'collectible_29_imperial_blue_error_stamp','Imperial Blue Error Stamp','Stamp','1904','Major printing-error example',210000::bigint,5,44,'very_rare',840::bigint,425,800,'Imperial Blue Error Stamp, a stamp collectible from 1904. Major printing-error example.'),
  (30,'collectible_30_grand_slam_championship_trophy_replica','Grand Slam Championship Trophy Replica','Tennis memorabilia','1989','Official presentation replica, unique issue',250000::bigint,5,46,'very_rare',1000::bigint,425,800,'Grand Slam Championship Trophy Replica, a tennis memorabilia collectible from 1989. Official presentation replica, unique issue.'),
  (31,'collectible_31_lunar_mission_prototype_camera','Lunar Mission Prototype Camera','Scientific collectible','1968','Aerospace development prototype',295000::bigint,5,47,'very_rare',1180::bigint,425,800,'Lunar Mission Prototype Camera, a scientific collectible collectible from 1968. Aerospace development prototype.'),
  (32,'collectible_32_monarch_gold_ten_crown','Monarch Gold Ten-Crown','Coin','1795','Extremely rare royal gold issue',350000::bigint,5,48,'very_rare',1400::bigint,425,800,'Monarch Gold Ten-Crown, a coin collectible from 1795. Extremely rare royal gold issue.'),
  (33,'collectible_33_midnight_vigil_1','Midnight Vigil #1','Comic book','1949','Exceptional high-grade copy',410000::bigint,5,50,'very_rare',1640::bigint,425,800,'Midnight Vigil #1, a comic book collectible from 1949. Exceptional high-grade copy.'),
  (34,'collectible_34_world_finals_match_jersey','World Finals Match Jersey','Sports memorabilia','1994','Championship-worn jersey',475000::bigint,5,51,'very_rare',1900::bigint,425,800,'World Finals Match Jersey, a sports memorabilia collectible from 1994. Championship-worn jersey.'),
  (35,'collectible_35_explorers_polar_journal','Explorer’s Polar Journal','Historical manuscript','1909','Original expedition diary',550000::bigint,6,52,'very_rare',2750::bigint,500,700,'Explorer’s Polar Journal, a historical manuscript collectible from 1909. Original expedition diary.'),
  (36,'collectible_36_imperial_dragon_stamp_block','Imperial Dragon Stamp Block','Stamps','1868','Block of four, unused',625000::bigint,6,53,'very_rare',3125::bigint,500,700,'Imperial Dragon Stamp Block, a stamps collectible from 1868. Block of four, unused.'),
  (37,'collectible_37_champion_one_of_one_card','Champion One-of-One Card','Sports trading card','2003','Unique signed 1/1 card',700000::bigint,6,55,'very_rare',3500::bigint,500,700,'Champion One-of-One Card, a sports trading card collectible from 2003. Unique signed 1/1 card.'),
  (38,'collectible_38_meteorite_celestial_crown','Meteorite “Celestial Crown”','Natural collectible','Ancient','Museum-grade extraterrestrial specimen',800000::bigint,6,56,'very_rare',4000::bigint,500,700,'Meteorite “Celestial Crown”, a natural collectible collectible from Ancient. Museum-grade extraterrestrial specimen.'),
  (39,'collectible_39_royal_mint_presentation_set','Royal Mint Presentation Set','Coins','1837','Unique presentation coin set',900000::bigint,6,57,'very_rare',4500::bigint,500,700,'Royal Mint Presentation Set, a coins collectible from 1837. Unique presentation coin set.'),
  (40,'collectible_40_continental_final_championship_racket','Continental Final Championship Racket','Tennis memorabilia','1982','Historic final-winning racket',1000000::bigint,7,58,'legendary',6000::bigint,575,600,'Continental Final Championship Racket, a tennis memorabilia collectible from 1982. Historic final-winning racket.'),
  (41,'collectible_41_the_golden_falcon_manuscript','The Golden Falcon Manuscript','Rare manuscript','1712','Illustrated handwritten volume',1125000::bigint,7,59,'legendary',6750::bigint,575,600,'The Golden Falcon Manuscript, a rare manuscript collectible from 1712. Illustrated handwritten volume.'),
  (42,'collectible_42_pioneer_motion_picture_camera','Pioneer Motion-Picture Camera','Film history','1915','Early professional cinema camera',1250000::bigint,7,61,'legendary',7500::bigint,575,600,'Pioneer Motion-Picture Camera, a film history collectible from 1915. Early professional cinema camera.'),
  (43,'collectible_43_black_crown_error_coin','Black Crown Error Coin','Coin','1811','Famous double-strike minting error',1400000::bigint,7,62,'legendary',8400::bigint,575,600,'Black Crown Error Coin, a coin collectible from 1811. Famous double-strike minting error.'),
  (44,'collectible_44_titan_comics_no_1','Titan Comics No. 1','Comic book','1939','Extremely rare high-grade first issue',1550000::bigint,7,63,'legendary',9300::bigint,575,600,'Titan Comics No. 1, a comic book collectible from 1939. Extremely rare high-grade first issue.'),
  (45,'collectible_45_first_world_championship_trophy','First World Championship Trophy','Sports memorabilia','1953','Historic trophy from fictional international championship',1700000::bigint,7,64,'legendary',10200::bigint,575,600,'First World Championship Trophy, a sports memorabilia collectible from 1953. Historic trophy from fictional international championship.'),
  (46,'collectible_46_royal_scarlet_one_cent_stamp','Royal Scarlet One-Cent Stamp','Stamp','1851','Legendary unused rarity',1900000::bigint,7,65,'legendary',11400::bigint,575,600,'Royal Scarlet One-Cent Stamp, a stamp collectible from 1851. Legendary unused rarity.'),
  (47,'collectible_47_grand_slam_legend_collection','Grand Slam Legend Collection','Tennis memorabilia','1970–1990','Rackets, balls, apparel and signed documents',2100000::bigint,8,66,'legendary',15750::bigint,650,500,'Grand Slam Legend Collection, a tennis memorabilia collectible from 1970–1990. Rackets, balls, apparel and signed documents.'),
  (48,'collectible_48_imperial_double_eagle_gold_coin','Imperial Double Eagle Gold Coin','Coin','1788','Unique surviving presentation strike',2350000::bigint,8,68,'legendary',17625::bigint,650,500,'Imperial Double Eagle Gold Coin, a coin collectible from 1788. Unique surviving presentation strike.'),
  (49,'collectible_49_genesis_champion_card','Genesis Champion Card','Sports trading card','1952','Only known mint-condition example',2600000::bigint,8,69,'legendary',19500::bigint,650,500,'Genesis Champion Card, a sports trading card collectible from 1952. Only known mint-condition example.'),
  (50,'collectible_50_the_emperors_atlas','The Emperor’s Atlas','Rare book / manuscript','1684','Hand-painted maps, unique royal copy',2800000::bigint,8,70,'legendary',21000::bigint,650,500,'The Emperor’s Atlas, a rare book / manuscript collectible from 1684. Hand-painted maps, unique royal copy.'),
  (51,'collectible_51_crown_collection_of_sporting_history','Crown Collection of Sporting History','Museum-grade collection','1900–2000','Unique archive of historic sporting memorabilia',3000000::bigint,8,71,'legendary',22500::bigint,650,500,'Crown Collection of Sporting History, a museum-grade collection collectible from 1900–2000. Unique archive of historic sporting memorabilia.');

do $$
declare
  v_count integer;
  v_min bigint;
  v_max bigint;
  v_bad_order integer;
begin
  select count(*),min(purchase_price),max(purchase_price)
  into v_count,v_min,v_max
  from tmp_collectibles_51_v1;

  select count(*)
  into v_bad_order
  from (
    select purchase_price,
           lag(purchase_price) over(order by catalog_order) as prev_price
    from tmp_collectibles_51_v1
  ) x
  where prev_price is not null
    and purchase_price <= prev_price;

  if v_count<>51 or v_min<>300 or v_max<>3000000 or v_bad_order<>0 then
    raise exception
      'Collectibles preflight failed: count %, min %, max %, nonmonotonic %.',
      v_count,v_min,v_max,v_bad_order;
  end if;
end;
$$;

update public.private_life_asset_catalog
set active=false,
    metadata=coalesce(metadata,'{}'::jsonb)
      || jsonb_build_object(
        'market_status','retired_from_market',
        'retired_reason','replaced_by_curated_collectibles_51_v1',
        'retired_at','2026-10-08'
      ),
    updated_at=now()
where category='collectible'
  and code not in ('collectible_01_silver_ace_rookie_card','collectible_02_continental_open_match_ball','collectible_03_alpine_rally_miniature','collectible_04_moonlight_comics_1','collectible_05_victory_series_player_card','collectible_06_royal_crest_silver_coin','collectible_07_grand_slam_signed_cap','collectible_08_aero_racer_tin_toy','collectible_09_continental_postage_sheet','collectible_10_golden_serve_racket','collectible_11_aurora_comics_1','collectible_12_crown_eagle_gold_coin','collectible_13_champion_series_card_no_7','collectible_14_imperial_red_stamp_pair','collectible_15_grand_prix_driver_helmet','collectible_16_star_voyager_figure_set','collectible_17_masters_final_match_ball','collectible_18_liberty_head_gold_piece','collectible_19_crimson_detective_1','collectible_20_first_flight_postal_cover','collectible_21_world_champion_jersey','collectible_22_empire_crown_stamp','collectible_23_meteorite_slice_orion','collectible_24_heritage_grand_slam_racket','collectible_25_atlas_gold_proof_set','collectible_26_the_navigator_first_edition','collectible_27_silver_screen_hero_costume','collectible_28_diamond_ace_rookie_card','collectible_29_imperial_blue_error_stamp','collectible_30_grand_slam_championship_trophy_replica','collectible_31_lunar_mission_prototype_camera','collectible_32_monarch_gold_ten_crown','collectible_33_midnight_vigil_1','collectible_34_world_finals_match_jersey','collectible_35_explorers_polar_journal','collectible_36_imperial_dragon_stamp_block','collectible_37_champion_one_of_one_card','collectible_38_meteorite_celestial_crown','collectible_39_royal_mint_presentation_set','collectible_40_continental_final_championship_racket','collectible_41_the_golden_falcon_manuscript','collectible_42_pioneer_motion_picture_camera','collectible_43_black_crown_error_coin','collectible_44_titan_comics_no_1','collectible_45_first_world_championship_trophy','collectible_46_royal_scarlet_one_cent_stamp','collectible_47_grand_slam_legend_collection','collectible_48_imperial_double_eagle_gold_coin','collectible_49_genesis_champion_card','collectible_50_the_emperors_atlas','collectible_51_crown_collection_of_sporting_history');

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,
  image_url,active,metadata
)
select
  x.code,
  'collectible',
  x.name,
  x.tier,
  x.description,
  x.purchase_price,
  x.prestige,
  x.rarity,
  x.annual_running_cost,
  x.annual_value_rate_bps,
  x.resale_discount_bps,
  'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',
  true,
  jsonb_build_object(
    'catalog_order',x.catalog_order,
    'collectible_type',x.collectible_type,
    'era_or_year',x.era_or_year,
    'collectible_details',x.collectible_details,
    'market_currency','USD',
    'pricing_currency','USD',
    'base_market_price',x.purchase_price,
    'catalog_version','curated_collectibles_51_v1',
    'insurance_and_storage_cost',x.annual_running_cost > 0,
    'image_status','placeholder_waiting_for_upload',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Collectibles',
    'expected_image_storage_path','Private Life/Collectibles/Collectible '||x.catalog_order||' - '||x.name||'.png',
    'pricing_reviewed_at','2026-10-08'
  )
from tmp_collectibles_51_v1 x
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
  where category='collectible' and active=true;

  select count(*)
  into v_exact
  from tmp_collectibles_51_v1 x
  join public.private_life_asset_catalog c
    on c.code=x.code
   and c.category='collectible'
   and c.active=true;

  select count(*)
  into v_wrong
  from tmp_collectibles_51_v1 x
  join public.private_life_asset_catalog c on c.code=x.code
  where c.name<>x.name
     or c.purchase_price<>x.purchase_price
     or c.tier<>x.tier
     or c.prestige<>x.prestige
     or c.rarity<>x.rarity
     or c.annual_running_cost<>x.annual_running_cost
     or c.annual_value_rate_bps<>x.annual_value_rate_bps
     or c.resale_discount_bps<>x.resale_discount_bps
     or c.metadata->>'collectible_type'<>x.collectible_type
     or c.metadata->>'era_or_year'<>x.era_or_year
     or c.metadata->>'collectible_details'<>x.collectible_details
     or (c.metadata->>'catalog_order')::integer<>x.catalog_order;

  select count(*) into v_old_active
  from public.private_life_asset_catalog
  where category='collectible'
    and active=true
    and code not in ('collectible_01_silver_ace_rookie_card','collectible_02_continental_open_match_ball','collectible_03_alpine_rally_miniature','collectible_04_moonlight_comics_1','collectible_05_victory_series_player_card','collectible_06_royal_crest_silver_coin','collectible_07_grand_slam_signed_cap','collectible_08_aero_racer_tin_toy','collectible_09_continental_postage_sheet','collectible_10_golden_serve_racket','collectible_11_aurora_comics_1','collectible_12_crown_eagle_gold_coin','collectible_13_champion_series_card_no_7','collectible_14_imperial_red_stamp_pair','collectible_15_grand_prix_driver_helmet','collectible_16_star_voyager_figure_set','collectible_17_masters_final_match_ball','collectible_18_liberty_head_gold_piece','collectible_19_crimson_detective_1','collectible_20_first_flight_postal_cover','collectible_21_world_champion_jersey','collectible_22_empire_crown_stamp','collectible_23_meteorite_slice_orion','collectible_24_heritage_grand_slam_racket','collectible_25_atlas_gold_proof_set','collectible_26_the_navigator_first_edition','collectible_27_silver_screen_hero_costume','collectible_28_diamond_ace_rookie_card','collectible_29_imperial_blue_error_stamp','collectible_30_grand_slam_championship_trophy_replica','collectible_31_lunar_mission_prototype_camera','collectible_32_monarch_gold_ten_crown','collectible_33_midnight_vigil_1','collectible_34_world_finals_match_jersey','collectible_35_explorers_polar_journal','collectible_36_imperial_dragon_stamp_block','collectible_37_champion_one_of_one_card','collectible_38_meteorite_celestial_crown','collectible_39_royal_mint_presentation_set','collectible_40_continental_final_championship_racket','collectible_41_the_golden_falcon_manuscript','collectible_42_pioneer_motion_picture_camera','collectible_43_black_crown_error_coin','collectible_44_titan_comics_no_1','collectible_45_first_world_championship_trophy','collectible_46_royal_scarlet_one_cent_stamp','collectible_47_grand_slam_legend_collection','collectible_48_imperial_double_eagle_gold_coin','collectible_49_genesis_champion_card','collectible_50_the_emperors_atlas','collectible_51_crown_collection_of_sporting_history');

  select count(distinct (metadata->>'catalog_order')::integer)
  into v_orders
  from public.private_life_asset_catalog
  where category='collectible' and active=true;

  if v_active<>51 or v_exact<>51 or v_wrong<>0 or v_old_active<>0 or v_orders<>51 then
    raise exception
      'Collectibles validation failed: active %, exact %, wrong %, old active %, orders %.',
      v_active,v_exact,v_wrong,v_old_active,v_orders;
  end if;
end;
$$;
