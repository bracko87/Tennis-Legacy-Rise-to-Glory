-- Publish the curated 18-model Private Airplanes catalogue.
-- Internal category remains 'private_jet' for backwards compatibility.
-- Historical generic jet rows are retained but deactivated.

create temporary table tmp_private_airplanes_v1 (
  catalog_order integer primary key,
  code text unique not null,
  manufacturer text not null,
  model_name text not null,
  aircraft_class text not null,
  seats integer not null,
  propulsion text not null,
  purchase_price bigint not null,
  tier integer not null,
  prestige integer not null,
  rarity text not null,
  annual_running_cost bigint not null,
  annual_value_rate_bps integer not null,
  resale_discount_bps integer not null,
  description text not null
) on commit drop;

insert into tmp_private_airplanes_v1(
  catalog_order,code,manufacturer,model_name,aircraft_class,seats,propulsion,
  purchase_price,tier,prestige,rarity,annual_running_cost,
  annual_value_rate_bps,resale_discount_bps,description
)
values
  (1,'air_cessaro_c180','Cessaro','Skyhawk C180','Single-Engine Piston',4,'piston',420000::bigint,1,2,'common',60000::bigint,-1500,1200,'Single-Engine Piston by Cessaro, configured for approximately 4 passengers and positioned at step 1 of the Tennis Legacy private-airplane progression.'),
  (2,'air_pipera_archer_lx','Pipera','Archer LX','Single-Engine Piston',4,'piston',575000::bigint,1,3,'common',75000::bigint,-1450,1180,'Single-Engine Piston by Pipera, configured for approximately 4 passengers and positioned at step 2 of the Tennis Legacy private-airplane progression.'),
  (3,'air_cirron_sr6_vision','Cirron','SR6 Vision','Premium Single-Engine',4,'piston',850000::bigint,1,4,'uncommon',100000::bigint,-1400,1150,'Premium Single-Engine by Cirron, configured for approximately 4 passengers and positioned at step 3 of the Tennis Legacy private-airplane progression.'),
  (4,'air_beechmore_baron_b60','Beechmore','Baron B60','Twin-Engine Piston',6,'piston',1450000::bigint,2,6,'uncommon',160000::bigint,-1350,1125,'Twin-Engine Piston by Beechmore, configured for approximately 6 passengers and positioned at step 4 of the Tennis Legacy private-airplane progression.'),
  (5,'air_cessaro_grand_caravan_ex','Cessaro','Grand Caravan EX','Utility Turboprop',9,'turboprop',2850000::bigint,2,9,'uncommon',320000::bigint,-1300,1100,'Utility Turboprop by Cessaro, configured for approximately 9 passengers and positioned at step 5 of the Tennis Legacy private-airplane progression.'),
  (6,'air_daherion_tbm_980','Daherion','TBM 980','High-Speed Turboprop',6,'turboprop',4250000::bigint,2,12,'rare',450000::bigint,-1250,1075,'High-Speed Turboprop by Daherion, configured for approximately 6 passengers and positioned at step 6 of the Tennis Legacy private-airplane progression.'),
  (7,'air_pilara_pc14','Pilara','PC-14','Executive Turboprop',8,'turboprop',5750000::bigint,3,15,'rare',600000::bigint,-1200,1050,'Executive Turboprop by Pilara, configured for approximately 8 passengers and positioned at step 7 of the Tennis Legacy private-airplane progression.'),
  (8,'air_beechmore_kingair_x360','Beechmore','KingAir X360','Twin Turboprop',9,'turboprop',7500000::bigint,3,18,'rare',750000::bigint,-1150,1025,'Twin Turboprop by Beechmore, configured for approximately 9 passengers and positioned at step 8 of the Tennis Legacy private-airplane progression.'),
  (9,'air_hondara_hj_one','Hondara Aviation','HJ-One','Very Light Jet',5,'jet',6750000::bigint,3,20,'rare',850000::bigint,-1100,1000,'Very Light Jet by Hondara Aviation, configured for approximately 5 passengers and positioned at step 9 of the Tennis Legacy private-airplane progression.'),
  (10,'air_cessaro_citation_m3','Cessaro','Citation M3','Light Jet',7,'jet',9250000::bigint,4,24,'rare',1050000::bigint,-1050,975,'Light Jet by Cessaro, configured for approximately 7 passengers and positioned at step 10 of the Tennis Legacy private-airplane progression.'),
  (11,'air_emborgier_phenom_350e','Emborgier','Phenom 350E','Light Executive Jet',8,'jet',12500000::bigint,4,28,'very_rare',1350000::bigint,-1000,950,'Light Executive Jet by Emborgier, configured for approximately 8 passengers and positioned at step 11 of the Tennis Legacy private-airplane progression.'),
  (12,'air_bombara_challenger_420','Bombara','Challenger 420','Super-Light Jet',9,'jet',17500000::bigint,4,33,'very_rare',1800000::bigint,-950,925,'Super-Light Jet by Bombara, configured for approximately 9 passengers and positioned at step 12 of the Tennis Legacy private-airplane progression.'),
  (13,'air_cessaro_citation_latitude_x','Cessaro','Citation Latitude X','Midsize Jet',9,'jet',22500000::bigint,5,38,'very_rare',2200000::bigint,-900,900,'Midsize Jet by Cessaro, configured for approximately 9 passengers and positioned at step 13 of the Tennis Legacy private-airplane progression.'),
  (14,'air_emborgier_praetor_680','Emborgier','Praetor 680','Super-Midsize Jet',10,'jet',29500000::bigint,5,45,'very_rare',2800000::bigint,-850,875,'Super-Midsize Jet by Emborgier, configured for approximately 10 passengers and positioned at step 14 of the Tennis Legacy private-airplane progression.'),
  (15,'air_dassier_falcon_9x','Dassier','Falcon 9X','Large Business Jet',14,'jet',44000000::bigint,6,55,'legendary',4000000::bigint,-800,850,'Large Business Jet by Dassier, configured for approximately 14 passengers and positioned at step 15 of the Tennis Legacy private-airplane progression.'),
  (16,'air_gulfstar_g650_lx','Gulfstar','G650 LX','Long-Range Business Jet',16,'jet',58000000::bigint,6,65,'legendary',5200000::bigint,-750,800,'Long-Range Business Jet by Gulfstar, configured for approximately 16 passengers and positioned at step 16 of the Tennis Legacy private-airplane progression.'),
  (17,'air_bombara_global_8000x','Bombara','Global 8000X','Ultra-Long-Range Jet',17,'jet',72500000::bigint,7,75,'legendary',6500000::bigint,-700,750,'Ultra-Long-Range Jet by Bombara, configured for approximately 17 passengers and positioned at step 17 of the Tennis Legacy private-airplane progression.'),
  (18,'air_gulfstar_g900_sovereign','Gulfstar','G900 Sovereign','Flagship Private Jet',19,'jet',89000000::bigint,8,90,'legendary',8000000::bigint,-650,700,'Flagship Private Jet by Gulfstar, configured for approximately 19 passengers and positioned at step 18 of the Tennis Legacy private-airplane progression.');

do $$
declare
  v_count integer;
  v_min bigint;
  v_max bigint;
begin
  select count(*),min(purchase_price),max(purchase_price)
  into v_count,v_min,v_max
  from tmp_private_airplanes_v1;

  if v_count<>18 or v_min<>420000 or v_max<>89000000 then
    raise exception
      'Private Airplanes preflight failed: count %, min %, max %.',
      v_count,v_min,v_max;
  end if;
end;
$$;

update public.private_life_asset_catalog
set active=false,
    metadata=coalesce(metadata,'{}'::jsonb)
      || jsonb_build_object(
        'market_status','retired_from_market',
        'retired_reason','replaced_by_private_airplanes_18_v1',
        'retired_at','2026-10-08'
      ),
    updated_at=now()
where category='private_jet'
  and code not in ('air_cessaro_c180','air_pipera_archer_lx','air_cirron_sr6_vision','air_beechmore_baron_b60','air_cessaro_grand_caravan_ex','air_daherion_tbm_980','air_pilara_pc14','air_beechmore_kingair_x360','air_hondara_hj_one','air_cessaro_citation_m3','air_emborgier_phenom_350e','air_bombara_challenger_420','air_cessaro_citation_latitude_x','air_emborgier_praetor_680','air_dassier_falcon_9x','air_gulfstar_g650_lx','air_bombara_global_8000x','air_gulfstar_g900_sovereign');

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,
  image_url,active,metadata
)
select
  p.code,
  'private_jet',
  p.model_name,
  p.tier,
  p.description,
  p.purchase_price,
  p.prestige,
  p.rarity,
  p.annual_running_cost,
  p.annual_value_rate_bps,
  p.resale_discount_bps,
  'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',
  true,
  jsonb_build_object(
    'catalog_order',p.catalog_order,
    'manufacturer',p.manufacturer,
    'aircraft_builder',p.manufacturer,
    'model_name',p.model_name,
    'full_display_name',p.manufacturer||' · '||p.model_name,
    'aircraft_class',p.aircraft_class,
    'aircraft_seats',p.seats,
    'propulsion',p.propulsion,
    'market_currency','USD',
    'pricing_currency','USD',
    'base_market_price',p.purchase_price,
    'catalog_version','private_airplanes_18_v1',
    'travel_fatigue_reduction_bps',9000,
    'image_status','placeholder_waiting_for_upload',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Private Airplanes',
    'expected_image_storage_path','Private Life/Private Airplanes/Airplane '||p.model_name||'.png',
    'pricing_reviewed_at','2026-10-08'
  )
from tmp_private_airplanes_v1 p
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
  select count(*)
  into v_active
  from public.private_life_asset_catalog
  where category='private_jet' and active=true;

  select count(*)
  into v_exact
  from tmp_private_airplanes_v1 p
  join public.private_life_asset_catalog c
    on c.code=p.code
   and c.category='private_jet'
   and c.active=true;

  select count(*)
  into v_wrong
  from tmp_private_airplanes_v1 p
  join public.private_life_asset_catalog c on c.code=p.code
  where c.name<>p.model_name
     or c.purchase_price<>p.purchase_price
     or c.tier<>p.tier
     or c.prestige<>p.prestige
     or c.rarity<>p.rarity
     or c.annual_running_cost<>p.annual_running_cost
     or c.annual_value_rate_bps<>p.annual_value_rate_bps
     or c.resale_discount_bps<>p.resale_discount_bps
     or c.metadata->>'manufacturer'<>p.manufacturer
     or c.metadata->>'model_name'<>p.model_name
     or c.metadata->>'aircraft_class'<>p.aircraft_class
     or (c.metadata->>'aircraft_seats')::integer<>p.seats
     or c.metadata->>'propulsion'<>p.propulsion
     or (c.metadata->>'catalog_order')::integer<>p.catalog_order;

  select count(*)
  into v_old_active
  from public.private_life_asset_catalog
  where category='private_jet'
    and active=true
    and code not in ('air_cessaro_c180','air_pipera_archer_lx','air_cirron_sr6_vision','air_beechmore_baron_b60','air_cessaro_grand_caravan_ex','air_daherion_tbm_980','air_pilara_pc14','air_beechmore_kingair_x360','air_hondara_hj_one','air_cessaro_citation_m3','air_emborgier_phenom_350e','air_bombara_challenger_420','air_cessaro_citation_latitude_x','air_emborgier_praetor_680','air_dassier_falcon_9x','air_gulfstar_g650_lx','air_bombara_global_8000x','air_gulfstar_g900_sovereign');

  select count(distinct (metadata->>'catalog_order')::integer)
  into v_orders
  from public.private_life_asset_catalog
  where category='private_jet' and active=true;

  if v_active<>18 or v_exact<>18 or v_wrong<>0 or v_old_active<>0 or v_orders<>18 then
    raise exception
      'Private Airplanes validation failed: active %, exact %, wrong %, old active %, orders %.',
      v_active,v_exact,v_wrong,v_old_active,v_orders;
  end if;
end;
$$;
