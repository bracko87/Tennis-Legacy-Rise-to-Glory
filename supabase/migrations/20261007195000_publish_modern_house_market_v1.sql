-- Publish the 55-city Modern House market.
-- Modern House focuses on large, popular urban destinations and uses exact
-- curated launch prices. City images will be connected after upload.

create temporary table tmp_modern_house_desired (
  ord integer primary key,
  country_code text not null,
  city text not null,
  target_price bigint not null
) on commit drop;

insert into tmp_modern_house_desired(ord,country_code,city,target_price)
values
  (1,'GB','London',1690000::bigint),
  (2,'FR','Paris',1985000::bigint),
  (3,'DE','Munich',1475000::bigint),
  (4,'DE','Frankfurt',1090000::bigint),
  (5,'DE','Berlin',1065000::bigint),
  (6,'NL','Amsterdam',1525000::bigint),
  (7,'NL','Rotterdam',905000::bigint),
  (8,'CH','Zurich',2735000::bigint),
  (9,'CH','Geneva',2425000::bigint),
  (10,'AT','Vienna',1175000::bigint),
  (11,'DK','Copenhagen',1425000::bigint),
  (12,'SE','Stockholm',1340000::bigint),
  (13,'NO','Oslo',1510000::bigint),
  (14,'FI','Helsinki',995000::bigint),
  (15,'IT','Milan',1160000::bigint),
  (16,'IT','Rome',1090000::bigint),
  (17,'ES','Barcelona',1065000::bigint),
  (18,'ES','Madrid',985000::bigint),
  (19,'PT','Lisbon',825000::bigint),
  (20,'CZ','Prague',855000::bigint),
  (21,'PL','Warsaw',655000::bigint),
  (22,'TR','Istanbul',865000::bigint),
  (23,'GR','Athens',690000::bigint),
  (24,'IE','Dublin',1585000::bigint),
  (25,'BE','Brussels',825000::bigint),
  (26,'US','New York',3150000::bigint),
  (27,'US','Los Angeles',2650000::bigint),
  (28,'US','San Francisco',3325000::bigint),
  (29,'US','Miami',1875000::bigint),
  (30,'US','Boston',1825000::bigint),
  (31,'US','Seattle',1625000::bigint),
  (32,'US','Washington',1495000::bigint),
  (33,'US','Chicago',1395000::bigint),
  (34,'US','Austin',1165000::bigint),
  (35,'CA','Toronto',1895000::bigint),
  (36,'CA','Vancouver',2375000::bigint),
  (37,'MX','Mexico City',675000::bigint),
  (38,'BR','São Paulo',785000::bigint),
  (39,'BR','Rio de Janeiro',825000::bigint),
  (40,'AR','Buenos Aires',515000::bigint),
  (41,'CL','Santiago',625000::bigint),
  (42,'JP','Tokyo',2250000::bigint),
  (43,'JP','Osaka',1425000::bigint),
  (44,'KR','Seoul',1895000::bigint),
  (45,'CN','Beijing',1985000::bigint),
  (46,'CN','Shanghai',2285000::bigint),
  (47,'CN','Shenzhen',1725000::bigint),
  (48,'HK','Hong Kong',3450000::bigint),
  (49,'SG','Singapore',3150000::bigint),
  (50,'TH','Bangkok',875000::bigint),
  (51,'MY','Kuala Lumpur',665000::bigint),
  (52,'AE','Dubai',2095000::bigint),
  (53,'IN','Mumbai',1425000::bigint),
  (54,'AU','Melbourne',1885000::bigint),
  (55,'AU','Sydney',2395000::bigint);

do $$
declare
  v_desired integer;
  v_matched integer;
  v_duplicate_matches integer;
begin
  select count(*) into v_desired from tmp_modern_house_desired;

  select count(*)
  into v_matched
  from tmp_modern_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_duplicate_matches
  from (
    select d.ord
    from tmp_modern_house_desired d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_desired<>55 or v_matched<>55 or v_duplicate_matches<>0 then
    raise exception
      'Modern House preflight failed: desired %, matched %, duplicate/non-unique %.',
      v_desired,v_matched,v_duplicate_matches;
  end if;
end;
$$;

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,image_url,active,metadata
)
values(
  'home_modern_house',
  'house_villa',
  'Modern House',
  3,
  'Contemporary architecture and better finish.',
  1000000,
  3,
  'uncommon',
  120000,
  200,
  950,
  'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82',
  true,
  jsonb_build_object(
    'property_kind','house_villa',
    'location_priced',true,
    'location_availability_enforced',true,
    'market_currency','USD',
    'pricing_currency','USD',
    'catalog_order',3,
    'price_multiplier_bps',10000,
    'running_cost_bps',120,
    'value_rate_adjustment_bps',0,
    'city_price_model','baseline_scaled_override_v1',
    'city_price_version','modern_house_v1',
    'city_price_status','curated',
    'pricing_reviewed_at','2026-10-07',
    'planned_city_count',55,
    'city_set_status','database_ready_waiting_for_images',
    'image_status','placeholder',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Modern House',
    'expected_image_storage_path','Private Life/Modern House/Modern House <City>.png'
  )
)
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
  metadata=coalesce(public.private_life_asset_catalog.metadata,'{}'::jsonb)
    - 'market_status'
    - 'disabled_reason'
    || excluded.metadata,
  updated_at=now();

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_modern_house',true
from tmp_modern_house_desired d
join public.private_life_property_locations l
  on upper(l.country_code)=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_modern_house'
  and not exists (
    select 1
    from tmp_modern_house_desired d
    join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
    where l.code=a.location_code
  );

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from tmp_modern_house_desired d
  where upper(l.country_code)=d.country_code
    and lower(l.city)=lower(d.city)
);

with matched as (
  select
    l.code as location_code,
    d.target_price,
    l.house_base_price as base_snapshot
  from tmp_modern_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
),
payload as (
  select
    jsonb_object_agg(location_code,target_price order by location_code) as price_map,
    jsonb_object_agg(location_code,base_snapshot order by location_code) as snapshot_map
  from matched
)
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'city_price_overrides',payload.price_map,
        'city_price_base_snapshots',payload.snapshot_map,
        'city_price_count',55,
        'city_price_status','curated',
        'city_price_version','modern_house_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',55,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Modern House',
        'missing_modern_house_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_modern_house'
  and c.category='house_villa';

do $$
declare
  v_availability integer;
  v_price_map integer;
  v_bad_prices integer;
  v_active_house_types integer;
begin
  select count(*)
  into v_availability
  from public.private_life_property_catalog_availability
  where catalog_code='home_modern_house'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_modern_house';

  select count(*)
  into v_bad_prices
  from tmp_modern_house_desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_modern_house',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>55 or v_price_map<>55 or v_bad_prices<>0 or v_active_house_types<>3 then
    raise exception
      'Modern House validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
