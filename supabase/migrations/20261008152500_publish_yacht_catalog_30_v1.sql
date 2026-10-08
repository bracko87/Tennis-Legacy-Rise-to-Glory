-- Replace the active yacht marketplace with a curated 30-model progression.
-- Historical yacht catalog rows are retained but deactivated so existing ownership references remain valid.

create temporary table tmp_yacht_catalog_v1 (
  catalog_order integer primary key,
  code text unique not null,
  name text not null,
  length_m integer not null,
  yacht_type text not null,
  purchase_price bigint not null,
  tier integer not null,
  prestige integer not null,
  rarity text not null,
  annual_running_cost bigint not null,
  annual_value_rate_bps integer not null,
  resale_discount_bps integer not null,
  description text not null
) on commit drop;

insert into tmp_yacht_catalog_v1(
  catalog_order,code,name,length_m,yacht_type,purchase_price,tier,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,description
)
values
  (1,'yacht_m7','M7',10,'Compact Motor Yacht',320000::bigint,1,4,'common',30720::bigint,-1600,1100,'Compact Motor Yacht measuring approximately 10 m, positioned at step 1 of the Tennis Legacy yacht progression.'),
  (2,'yacht_ventura','Ventura',12,'Sport Cruiser',475000::bigint,1,5,'uncommon',45600::bigint,-1550,1075,'Sport Cruiser measuring approximately 12 m, positioned at step 2 of the Tennis Legacy yacht progression.'),
  (3,'yacht_cx4','CX-4',13,'Motor Yacht',650000::bigint,1,6,'uncommon',62400::bigint,-1500,1050,'Motor Yacht measuring approximately 13 m, positioned at step 3 of the Tennis Legacy yacht progression.'),
  (4,'yacht_ardent_900','Ardent 900',14,'Sport Yacht',850000::bigint,2,7,'uncommon',81600::bigint,-1475,1025,'Sport Yacht measuring approximately 14 m, positioned at step 4 of the Tennis Legacy yacht progression.'),
  (5,'yacht_bluewave_s','Bluewave S',15,'Flybridge Yacht',1100000::bigint,2,8,'uncommon',105600::bigint,-1450,1000,'Flybridge Yacht measuring approximately 15 m, positioned at step 5 of the Tennis Legacy yacht progression.'),
  (6,'yacht_v52x','V52X',16,'Flybridge Yacht',1450000::bigint,2,10,'rare',139200::bigint,-1425,975,'Flybridge Yacht measuring approximately 16 m, positioned at step 6 of the Tennis Legacy yacht progression.'),
  (7,'yacht_bellagio','Bellagio',17,'Luxury Motor Yacht',1850000::bigint,2,12,'rare',177600::bigint,-1400,950,'Luxury Motor Yacht measuring approximately 17 m, positioned at step 7 of the Tennis Legacy yacht progression.'),
  (8,'yacht_r88','R88',18,'Luxury Flybridge',2250000::bigint,3,14,'rare',216000::bigint,-1375,925,'Luxury Flybridge measuring approximately 18 m, positioned at step 8 of the Tennis Legacy yacht progression.'),
  (9,'yacht_stratos_6','Stratos 6',19,'Performance Yacht',2850000::bigint,3,16,'rare',273600::bigint,-1350,900,'Performance Yacht measuring approximately 19 m, positioned at step 9 of the Tennis Legacy yacht progression.'),
  (10,'yacht_axiom_2000','Axiom 2000',20,'Luxury Motor Yacht',3500000::bigint,3,18,'rare',336000::bigint,-1325,875,'Luxury Motor Yacht measuring approximately 20 m, positioned at step 10 of the Tennis Legacy yacht progression.'),
  (11,'yacht_velaris_gt','Velaris GT',21,'Luxury Yacht',4250000::bigint,3,20,'rare',408000::bigint,-1300,850,'Luxury Yacht measuring approximately 21 m, positioned at step 11 of the Tennis Legacy yacht progression.'),
  (12,'yacht_p9','P9',23,'Flybridge Yacht',5250000::bigint,4,22,'very_rare',504000::bigint,-1275,825,'Flybridge Yacht measuring approximately 23 m, positioned at step 12 of the Tennis Legacy yacht progression.'),
  (13,'yacht_zenith_x','Zenith X',24,'Luxury Yacht',6500000::bigint,4,24,'very_rare',624000::bigint,-1250,800,'Luxury Yacht measuring approximately 24 m, positioned at step 13 of the Tennis Legacy yacht progression.'),
  (14,'yacht_elysium_850','Elysium 850',25,'Luxury Motor Yacht',7750000::bigint,4,26,'very_rare',744000::bigint,-1225,775,'Luxury Motor Yacht measuring approximately 25 m, positioned at step 14 of the Tennis Legacy yacht progression.'),
  (15,'yacht_black_pearl','Black Pearl',27,'Superyacht',9500000::bigint,4,28,'very_rare',912000::bigint,-1200,750,'Superyacht measuring approximately 27 m, positioned at step 15 of the Tennis Legacy yacht progression.'),
  (16,'yacht_l95r','L95R',29,'Superyacht',12000000::bigint,5,31,'very_rare',1152000::bigint,-1175,725,'Superyacht measuring approximately 29 m, positioned at step 16 of the Tennis Legacy yacht progression.'),
  (17,'yacht_solaris_one','Solaris One',32,'Superyacht',15500000::bigint,5,34,'very_rare',1488000::bigint,-1150,700,'Superyacht measuring approximately 32 m, positioned at step 17 of the Tennis Legacy yacht progression.'),
  (18,'yacht_m1150','M1150',35,'Superyacht',19500000::bigint,5,37,'very_rare',1872000::bigint,-1125,675,'Superyacht measuring approximately 35 m, positioned at step 18 of the Tennis Legacy yacht progression.'),
  (19,'yacht_aurelia','Aurelia',38,'Superyacht',25000000::bigint,5,40,'legendary',2400000::bigint,-1100,650,'Superyacht measuring approximately 38 m, positioned at step 19 of the Tennis Legacy yacht progression.'),
  (20,'yacht_titan_g4','Titan G4',41,'Superyacht',32500000::bigint,6,44,'legendary',3120000::bigint,-1050,625,'Superyacht measuring approximately 41 m, positioned at step 20 of the Tennis Legacy yacht progression.'),
  (21,'yacht_s145x','S145X',44,'Large Superyacht',42000000::bigint,6,48,'legendary',4032000::bigint,-1000,600,'Large Superyacht measuring approximately 44 m, positioned at step 21 of the Tennis Legacy yacht progression.'),
  (22,'yacht_neptune','Neptune',47,'Large Superyacht',52500000::bigint,6,52,'legendary',5040000::bigint,-950,575,'Large Superyacht measuring approximately 47 m, positioned at step 22 of the Tennis Legacy yacht progression.'),
  (23,'yacht_ox_500','OX-500',50,'Large Superyacht',65000000::bigint,6,56,'legendary',6240000::bigint,-900,550,'Large Superyacht measuring approximately 50 m, positioned at step 23 of the Tennis Legacy yacht progression.'),
  (24,'yacht_celestia_55r','Celestia 55R',55,'Mega Yacht',82500000::bigint,7,61,'legendary',7920000::bigint,-850,525,'Mega Yacht measuring approximately 55 m, positioned at step 24 of the Tennis Legacy yacht progression.'),
  (25,'yacht_valkyrie','Valkyrie',61,'Mega Yacht',105000000::bigint,7,66,'legendary',10080000::bigint,-800,500,'Mega Yacht measuring approximately 61 m, positioned at step 25 of the Tennis Legacy yacht progression.'),
  (26,'yacht_p7000','P7000',67,'Mega Yacht',135000000::bigint,7,72,'legendary',12960000::bigint,-750,500,'Mega Yacht measuring approximately 67 m, positioned at step 26 of the Tennis Legacy yacht progression.'),
  (27,'yacht_aurora_prime','Aurora Prime',76,'Mega Yacht',175000000::bigint,7,78,'legendary',16800000::bigint,-700,475,'Mega Yacht measuring approximately 76 m, positioned at step 27 of the Tennis Legacy yacht progression.'),
  (28,'yacht_bs_85','BS-85',85,'Mega Yacht',225000000::bigint,8,85,'legendary',21600000::bigint,-650,475,'Mega Yacht measuring approximately 85 m, positioned at step 28 of the Tennis Legacy yacht progression.'),
  (29,'yacht_infinity_x1','Infinity X1',100,'Ultra Mega Yacht',325000000::bigint,8,95,'legendary',31200000::bigint,-575,450,'Ultra Mega Yacht measuring approximately 100 m, positioned at step 29 of the Tennis Legacy yacht progression.'),
  (30,'yacht_leviathan_12k','Leviathan 12K',122,'Ultimate Mega Yacht',475000000::bigint,8,110,'legendary',45600000::bigint,-500,450,'Ultimate Mega Yacht measuring approximately 122 m, positioned at step 30 of the Tennis Legacy yacht progression.');

do $$
declare
  v_count integer;
  v_min bigint;
  v_max bigint;
begin
  select count(*),min(purchase_price),max(purchase_price)
  into v_count,v_min,v_max
  from tmp_yacht_catalog_v1;

  if v_count<>30 or v_min<>320000 or v_max<>475000000 then
    raise exception
      'Yacht catalog preflight failed: count %, min %, max %.',
      v_count,v_min,v_max;
  end if;
end;
$$;

-- Remove the old generic yacht catalogue from the live market without deleting it.
update public.private_life_asset_catalog
set active=false,
    metadata=coalesce(metadata,'{}'::jsonb)
      || jsonb_build_object(
        'market_status','retired_from_market',
        'retired_reason','replaced_by_curated_30_yacht_catalog_v1',
        'retired_at','2026-10-08'
      ),
    updated_at=now()
where category='yacht'
  and code not in ('yacht_m7','yacht_ventura','yacht_cx4','yacht_ardent_900','yacht_bluewave_s','yacht_v52x','yacht_bellagio','yacht_r88','yacht_stratos_6','yacht_axiom_2000','yacht_velaris_gt','yacht_p9','yacht_zenith_x','yacht_elysium_850','yacht_black_pearl','yacht_l95r','yacht_solaris_one','yacht_m1150','yacht_aurelia','yacht_titan_g4','yacht_s145x','yacht_neptune','yacht_ox_500','yacht_celestia_55r','yacht_valkyrie','yacht_p7000','yacht_aurora_prime','yacht_bs_85','yacht_infinity_x1','yacht_leviathan_12k');

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,
  image_url,active,metadata
)
select
  y.code,
  'yacht',
  y.name,
  y.tier,
  y.description,
  y.purchase_price,
  y.prestige,
  y.rarity,
  y.annual_running_cost,
  y.annual_value_rate_bps,
  y.resale_discount_bps,
  'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=1200&q=82',
  true,
  jsonb_build_object(
    'catalog_order',y.catalog_order,
    'market_currency','USD',
    'pricing_currency','USD',
    'base_market_price',y.purchase_price,
    'yacht_length_m',y.length_m,
    'yacht_type',y.yacht_type,
    'yacht_class',
      case
        when y.length_m < 15 then 'compact_cruiser'
        when y.length_m < 24 then 'luxury_yacht'
        when y.length_m < 44 then 'superyacht'
        when y.length_m < 55 then 'large_superyacht'
        when y.length_m < 100 then 'megayacht'
        when y.length_m < 120 then 'ultra_megayacht'
        else 'ultimate_megayacht'
      end,
    'catalog_version','yacht_catalog_30_v1',
    'image_status','placeholder_waiting_for_upload',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Yachts',
    'expected_image_storage_path','Private Life/Yachts/'||y.name||'.png',
    'pricing_reviewed_at','2026-10-08'
  )
from tmp_yacht_catalog_v1 y
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
  v_order_count integer;
begin
  select count(*) into v_active
  from public.private_life_asset_catalog
  where category='yacht' and active=true;

  select count(*)
  into v_exact
  from tmp_yacht_catalog_v1 y
  join public.private_life_asset_catalog c
    on c.code=y.code
   and c.category='yacht'
   and c.active=true;

  select count(*)
  into v_wrong
  from tmp_yacht_catalog_v1 y
  join public.private_life_asset_catalog c on c.code=y.code
  where c.name<>y.name
     or c.purchase_price<>y.purchase_price
     or c.tier<>y.tier
     or c.prestige<>y.prestige
     or c.rarity<>y.rarity
     or c.annual_running_cost<>y.annual_running_cost
     or c.annual_value_rate_bps<>y.annual_value_rate_bps
     or c.resale_discount_bps<>y.resale_discount_bps
     or (c.metadata->>'catalog_order')::integer<>y.catalog_order
     or (c.metadata->>'yacht_length_m')::integer<>y.length_m
     or c.metadata->>'yacht_type'<>y.yacht_type;

  select count(*)
  into v_old_active
  from public.private_life_asset_catalog
  where category='yacht'
    and active=true
    and code not in ('yacht_m7','yacht_ventura','yacht_cx4','yacht_ardent_900','yacht_bluewave_s','yacht_v52x','yacht_bellagio','yacht_r88','yacht_stratos_6','yacht_axiom_2000','yacht_velaris_gt','yacht_p9','yacht_zenith_x','yacht_elysium_850','yacht_black_pearl','yacht_l95r','yacht_solaris_one','yacht_m1150','yacht_aurelia','yacht_titan_g4','yacht_s145x','yacht_neptune','yacht_ox_500','yacht_celestia_55r','yacht_valkyrie','yacht_p7000','yacht_aurora_prime','yacht_bs_85','yacht_infinity_x1','yacht_leviathan_12k');

  select count(distinct (metadata->>'catalog_order')::integer)
  into v_order_count
  from public.private_life_asset_catalog
  where category='yacht'
    and active=true;

  if v_active<>30 or v_exact<>30 or v_wrong<>0 or v_old_active<>0 or v_order_count<>30 then
    raise exception
      'Yacht catalog validation failed: active %, exact %, wrong %, old active %, orders %.',
      v_active,v_exact,v_wrong,v_old_active,v_order_count;
  end if;
end;
$$;
