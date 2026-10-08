-- Publish the 25-city Private Villa market.
-- Private Villa is tier 6: exclusive metropolitan and elite-area villas,
-- distinct from the resort-focused Luxury House tier.

create temporary table tmp_private_villa_desired (
  ord integer primary key,
  country_code text not null,
  city text not null,
  target_price bigint not null
) on commit drop;

insert into tmp_private_villa_desired(ord,country_code,city,target_price)
values
  (1,'RU','Moscow',7250000::bigint),
  (2,'RU','Saint Petersburg',5750000::bigint),
  (3,'SA','Riyadh',6250000::bigint),
  (4,'SA','Jeddah',5450000::bigint),
  (5,'QA','Doha',7750000::bigint),
  (6,'TW','Taipei',6850000::bigint),
  (7,'IN','Delhi',5250000::bigint),
  (8,'PH','Manila',4350000::bigint),
  (9,'ID','Jakarta',4150000::bigint),
  (10,'MY','Kuala Lumpur',4650000::bigint),
  (11,'ZA','Johannesburg',3850000::bigint),
  (12,'KE','Nairobi',3250000::bigint),
  (13,'NG','Lagos',3950000::bigint),
  (14,'EG','Cairo',3350000::bigint),
  (15,'MA','Casablanca',3750000::bigint),
  (16,'TR','Istanbul',5250000::bigint),
  (17,'AZ','Baku',3650000::bigint),
  (18,'GE','Tbilisi',2850000::bigint),
  (19,'KZ','Astana',3250000::bigint),
  (20,'UZ','Tashkent',2750000::bigint),
  (21,'AR','Buenos Aires',3950000::bigint),
  (22,'CL','Santiago',4250000::bigint),
  (23,'PE','Lima',3250000::bigint),
  (24,'CO','Bogota',3150000::bigint),
  (25,'MX','Mexico City',5150000::bigint);

do $$
declare
  v_desired integer;
  v_matched integer;
  v_nonunique integer;
begin
  select count(*) into v_desired from tmp_private_villa_desired;

  select count(*)
  into v_matched
  from tmp_private_villa_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_nonunique
  from (
    select d.ord
    from tmp_private_villa_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_desired<>25 or v_matched<>25 or v_nonunique<>0 then
    raise exception
      'Private Villa preflight failed: desired %, matched %, non-unique %.',
      v_desired,v_matched,v_nonunique;
  end if;
end;
$$;

update public.private_life_asset_catalog
set name='Private Villa',
    category='house_villa',
    tier=6,
    description='Exclusive private villa in metropolitan, coastal/resort or elite residential areas.',
    purchase_price=4500000,
    prestige=20,
    rarity='very_rare',
    annual_running_cost=600000,
    annual_value_rate_bps=275,
    resale_discount_bps=800,
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
        'catalog_order',6,
        'price_multiplier_bps',10000,
        'running_cost_bps',110,
        'value_rate_adjustment_bps',100,
        'city_price_model','baseline_scaled_override_v1',
        'city_price_version','private_villa_v1',
        'city_price_status','curated',
        'pricing_reviewed_at','2026-10-08',
        'planned_city_count',25,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Private Villa',
        'expected_image_storage_path','Private Life/Private Villa/Private Villa <City>.png',
        'missing_private_villa_images','pending_upload',
        'destination_theme','metropolitan_elite_villa'
      ),
    updated_at=now()
where code='home_grand_estate';

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_grand_estate',true
from tmp_private_villa_desired d
join public.private_life_property_locations l
  on l.country_code=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_grand_estate'
  and not exists (
    select 1
    from tmp_private_villa_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and lower(l.city)=lower(d.city)
    where l.code=a.location_code
  );

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from tmp_private_villa_desired d
  where d.country_code=l.country_code
    and lower(d.city)=lower(l.city)
);

with matched as (
  select
    l.code as location_code,
    d.target_price,
    l.house_base_price as base_snapshot
  from tmp_private_villa_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
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
        'city_price_count',25,
        'city_price_status','curated',
        'city_price_version','private_villa_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',25,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Private Villa',
        'missing_private_villa_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_grand_estate'
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
  where catalog_code='home_grand_estate'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_grand_estate';

  select count(*)
  into v_bad_prices
  from tmp_private_villa_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_grand_estate',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>25 or v_price_map<>25 or v_bad_prices<>0 or v_active_house_types<>6 then
    raise exception
      'Private Villa validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
