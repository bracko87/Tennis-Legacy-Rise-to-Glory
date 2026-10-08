-- Publish the 35-destination Luxury House market.
-- Luxury House is intentionally destination-driven: elite islands, beaches,
-- ski resorts, lakes and mountain resorts rather than ordinary metropolitan cities.
-- Reuse the inactive home_mountain_chalet catalog slot.

create temporary table tmp_luxury_house_desired (
  ord integer primary key,
  location_code text not null,
  country_code text not null,
  country_name text not null,
  city text not null,
  target_price bigint not null,
  base_house_price bigint not null
) on commit drop;

insert into tmp_luxury_house_desired(
  ord,location_code,country_code,country_name,city,target_price,base_house_price
)
values
  (1,'es_mallorca','ES','Spain','Mallorca',2950000::bigint,1200000::bigint),
  (2,'es_ibiza','ES','Spain','Ibiza',4250000::bigint,1500000::bigint),
  (3,'es_marbella','ES','Spain','Marbella',3350000::bigint,1300000::bigint),
  (4,'fr_sainttropez','FR','France','Saint-Tropez',6750000::bigint,2000000::bigint),
  (5,'fr_cannes','FR','France','Cannes',4850000::bigint,1600000::bigint),
  (6,'mc_monaco','MC','Monaco','Monaco',12500000::bigint,8050233::bigint),
  (7,'it_lakecomo','IT','Italy','Lake Como',5250000::bigint,2000000::bigint),
  (8,'it_capri','IT','Italy','Capri',4950000::bigint,1800000::bigint),
  (9,'it_amalficoast','IT','Italy','Amalfi Coast',4250000::bigint,1500000::bigint),
  (10,'gr_mykonos','GR','Greece','Mykonos',3950000::bigint,1400000::bigint),
  (11,'gr_santorini','GR','Greece','Santorini',3250000::bigint,1200000::bigint),
  (12,'pt_algarve','PT','Portugal','Algarve',2650000::bigint,1000000::bigint),
  (13,'hr_dubrovnik','HR','Croatia','Dubrovnik',2350000::bigint,900000::bigint),
  (14,'hr_hvar','HR','Croatia','Hvar',2550000::bigint,950000::bigint),
  (15,'th_phuket','TH','Thailand','Phuket',1850000::bigint,577500::bigint),
  (16,'id_bali','ID','Indonesia','Bali',1950000::bigint,662402::bigint),
  (17,'mv_maldives','MV','Maldives','Maldives',4750000::bigint,1500000::bigint),
  (18,'mu_mauritius','MU','Mauritius','Mauritius',2250000::bigint,900000::bigint),
  (19,'sc_seychelles','SC','Seychelles','Seychelles',3450000::bigint,1200000::bigint),
  (20,'do_puntacana','DO','Dominican Republic','Punta Cana',1650000::bigint,600000::bigint),
  (21,'mx_cancun','MX','Mexico','Cancun',2150000::bigint,577500::bigint),
  (22,'mx_tulum','MX','Mexico','Tulum',1850000::bigint,650000::bigint),
  (23,'bs_nassau','BS','Bahamas','Nassau',3750000::bigint,1200000::bigint),
  (24,'us_maui','US','United States','Maui',5250000::bigint,2000000::bigint),
  (25,'us_aspen','US','United States','Aspen',7250000::bigint,2800000::bigint),
  (26,'us_vail','US','United States','Vail',4850000::bigint,1800000::bigint),
  (27,'ca_whistler','CA','Canada','Whistler',4250000::bigint,1600000::bigint),
  (28,'ca_banff','CA','Canada','Banff',3350000::bigint,1300000::bigint),
  (29,'ch_zermatt','CH','Switzerland','Zermatt',5750000::bigint,2000000::bigint),
  (30,'ch_stmoritz','CH','Switzerland','St. Moritz',7250000::bigint,2500000::bigint),
  (31,'ch_gstaad','CH','Switzerland','Gstaad',8500000::bigint,3000000::bigint),
  (32,'ch_interlaken','CH','Switzerland','Interlaken',3650000::bigint,1500000::bigint),
  (33,'at_kitzbuhel','AT','Austria','Kitzbühel',4250000::bigint,1600000::bigint),
  (34,'fr_courchevel','FR','France','Courchevel',7750000::bigint,2700000::bigint),
  (35,'nz_queenstown','NZ','New Zealand','Queenstown',3150000::bigint,880000::bigint);

do $$
declare
  v_desired integer;
  v_code_conflicts integer;
begin
  select count(*) into v_desired from tmp_luxury_house_desired;

  select count(*)
  into v_code_conflicts
  from tmp_luxury_house_desired d
  join public.private_life_property_locations l
    on l.code=d.location_code
  where l.country_code<>d.country_code
     or l.city<>d.city;

  if v_desired<>35 or v_code_conflicts<>0 then
    raise exception
      'Luxury House destination preflight failed: desired %, code conflicts %.',
      v_desired,v_code_conflicts;
  end if;
end;
$$;

with base as (
  select coalesce(max(sort_order),0) as max_sort
  from public.private_life_property_locations
),
missing as (
  select d.*, b.max_sort
  from tmp_luxury_house_desired d
  cross join base b
  left join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city
  where l.code is null
)
insert into public.private_life_property_locations(
  code,country_code,country_name,city,
  apartment_base_price,house_base_price,
  annual_value_rate_bps,marketplace_enabled,active,sort_order
)
select
  location_code,
  country_code,
  country_name,
  city,
  greatest(150000::bigint, ((base_house_price * 40 / 100 + 2500) / 5000) * 5000),
  base_house_price,
  250,
  true,
  true,
  max_sort + ord
from missing;

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from tmp_luxury_house_desired d
  where d.country_code=l.country_code
    and d.city=l.city
);

do $$
declare
  v_locations integer;
  v_nonunique integer;
begin
  select count(*)
  into v_locations
  from tmp_luxury_house_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city;

  select count(*)
  into v_nonunique
  from (
    select d.ord
    from tmp_luxury_house_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and l.city=d.city
    group by d.ord
    having count(*)<>1
  ) x;

  if v_locations<>35 or v_nonunique<>0 then
    raise exception
      'Luxury House location creation failed: matched %, non-unique %.',
      v_locations,v_nonunique;
  end if;
end;
$$;

update public.private_life_asset_catalog
set name='Luxury House',
    category='house_villa',
    tier=5,
    description='Large high-end home in a desirable tourist or resort destination.',
    purchase_price=3000000,
    prestige=12,
    rarity='very_rare',
    annual_running_cost=360000,
    annual_value_rate_bps=250,
    resale_discount_bps=850,
    active=true,
    metadata=coalesce(metadata,'{}'::jsonb)
      - 'market_status'
      - 'disabled_reason'
      - 'city_image_urls'
      - 'city_image_count'
      - 'fallback_image_city'
      - 'images_connected_at'
      || jsonb_build_object(
        'property_kind','house_villa',
        'location_priced',true,
        'location_availability_enforced',true,
        'market_currency','USD',
        'pricing_currency','USD',
        'catalog_order',5,
        'price_multiplier_bps',10000,
        'running_cost_bps',120,
        'value_rate_adjustment_bps',75,
        'city_price_model','baseline_scaled_override_v1',
        'city_price_version','luxury_house_v1',
        'city_price_status','curated',
        'pricing_reviewed_at','2026-10-08',
        'planned_city_count',35,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Luxury House',
        'expected_image_storage_path','Private Life/Luxury House/Luxury House <City>.png',
        'missing_luxury_house_images','pending_upload',
        'destination_theme','tourist_resort_luxury'
      ),
    updated_at=now()
where code='home_mountain_chalet';

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_mountain_chalet',true
from tmp_luxury_house_desired d
join public.private_life_property_locations l
  on l.country_code=d.country_code
 and l.city=d.city
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_mountain_chalet'
  and not exists (
    select 1
    from tmp_luxury_house_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and l.city=d.city
    where l.code=a.location_code
  );

with matched as (
  select
    l.code as location_code,
    d.target_price,
    l.house_base_price as base_snapshot
  from tmp_luxury_house_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city
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
        'city_price_count',35,
        'city_price_status','curated',
        'city_price_version','luxury_house_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',35,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Luxury House',
        'missing_luxury_house_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_mountain_chalet'
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
  where catalog_code='home_mountain_chalet'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_mountain_chalet';

  select count(*)
  into v_bad_prices
  from tmp_luxury_house_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and l.city=d.city
  where public.private_life_property_effective_price_v1('home_mountain_chalet',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>35 or v_price_map<>35 or v_bad_prices<>0 or v_active_house_types<>5 then
    raise exception
      'Luxury House validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
