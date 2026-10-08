-- Publish the 20-location Grand Estate market as Houses & Villas tier 7.
-- Grand Estate represents very large private estates and compounds.
-- Reuse the currently inactive home_signature_mansion catalog slot.

alter table public.private_life_asset_catalog
  drop constraint if exists private_life_asset_catalog_tier_check;

alter table public.private_life_asset_catalog
  add constraint private_life_asset_catalog_tier_check
  check (tier >= 1 and tier <= 7);

create temporary table tmp_grand_estate_desired (
  ord integer primary key,
  country_code text not null,
  country_name text not null,
  city text not null,
  target_price bigint not null,
  base_house_price bigint not null
) on commit drop;

insert into tmp_grand_estate_desired(
  ord,country_code,country_name,city,target_price,base_house_price
)
values
  (1,'US','United States','Los Angeles',18500000::bigint,2650661::bigint),
  (2,'US','United States','New York',22500000::bigint,2864448::bigint),
  (3,'GB','United Kingdom','London',21500000::bigint,1785004::bigint),
  (4,'FR','France','Paris',17500000::bigint,1613361::bigint),
  (5,'CH','Switzerland','Geneva',19500000::bigint,1999347::bigint),
  (6,'FR','France','Saint-Nazaire',9750000::bigint,750000::bigint),
  (7,'AE','United Arab Emirates','Dubai',20500000::bigint,1858243::bigint),
  (8,'FR','France','Nice',14250000::bigint,1320000::bigint),
  (9,'QA','Qatar','Doha',14750000::bigint,1234928::bigint),
  (10,'BS','Bahamas','Nassau',12500000::bigint,1200000::bigint),
  (11,'RU','Russia','Moscow',15250000::bigint,400000::bigint),
  (12,'TR','Türkiye','Istanbul',10750000::bigint,712861::bigint),
  (13,'IN','India','Delhi',11500000::bigint,1115996::bigint),
  (14,'SG','Singapore','Singapore',24500000::bigint,3073343::bigint),
  (15,'US','United States','Miami',19250000::bigint,2039904::bigint),
  (16,'AU','Australia','Sydney',17250000::bigint,1997001::bigint),
  (17,'PR','Puerto Rico','San Juan',9500000::bigint,850000::bigint),
  (18,'ZA','South Africa','Johannesburg',8750000::bigint,493788::bigint),
  (19,'ES','Spain','Marbella',11750000::bigint,1300000::bigint),
  (20,'MX','Mexico','Mexico City',10250000::bigint,710463::bigint);

do $$
declare
  v_desired integer;
begin
  select count(*) into v_desired from tmp_grand_estate_desired;
  if v_desired<>20 then
    raise exception 'Grand Estate preflight failed: desired count %.',v_desired;
  end if;
end;
$$;

with base as (
  select coalesce(max(sort_order),0) as max_sort
  from public.private_life_property_locations
),
missing as (
  select d.*,b.max_sort
  from tmp_grand_estate_desired d
  cross join base b
  left join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  where l.code is null
)
insert into public.private_life_property_locations(
  code,country_code,country_name,city,
  apartment_base_price,house_base_price,
  annual_value_rate_bps,marketplace_enabled,active,sort_order
)
select
  lower(country_code)||'_'||
    regexp_replace(
      translate(
        lower(city),
        'áàâäãåéèêëíìîïóòôöõúùûüçñžšđčćýÿ',
        'aaaaaaeeeeiiiiooooouuuucnzsdccyy'
      ),
      '[^a-z0-9]+','','g'
    ),
  country_code,
  country_name,
  city,
  greatest(200000::bigint, ((base_house_price * 40 / 100 + 2500) / 5000) * 5000),
  base_house_price,
  275,
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
  from tmp_grand_estate_desired d
  where d.country_code=l.country_code
    and lower(d.city)=lower(l.city)
);

do $$
declare
  v_locations integer;
  v_nonunique integer;
begin
  select count(*)
  into v_locations
  from tmp_grand_estate_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_nonunique
  from (
    select d.ord
    from tmp_grand_estate_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_locations<>20 or v_nonunique<>0 then
    raise exception
      'Grand Estate location validation failed: matched %, non-unique %.',
      v_locations,v_nonunique;
  end if;
end;
$$;

update public.private_life_asset_catalog
set name='Grand Estate',
    category='house_villa',
    tier=7,
    description='Very large private estate or compound in a prestigious location.',
    purchase_price=15000000,
    prestige=32,
    rarity='legendary',
    annual_running_cost=1800000,
    annual_value_rate_bps=300,
    resale_discount_bps=750,
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
        'catalog_order',7,
        'price_multiplier_bps',10000,
        'running_cost_bps',100,
        'value_rate_adjustment_bps',125,
        'city_price_model','baseline_scaled_override_v1',
        'city_price_version','grand_estate_v1',
        'city_price_status','curated',
        'pricing_reviewed_at','2026-10-08',
        'planned_city_count',20,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Grand Estate',
        'expected_image_storage_path','Private Life/Grand Estate/Grand Estate <City>.png',
        'missing_grand_estate_images','pending_upload',
        'destination_theme','prestige_estate_compound'
      ),
    updated_at=now()
where code='home_signature_mansion';

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_signature_mansion',true
from tmp_grand_estate_desired d
join public.private_life_property_locations l
  on l.country_code=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_signature_mansion'
  and not exists (
    select 1
    from tmp_grand_estate_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and lower(l.city)=lower(d.city)
    where l.code=a.location_code
  );

with matched as (
  select
    l.code as location_code,
    d.target_price,
    l.house_base_price as base_snapshot
  from tmp_grand_estate_desired d
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
        'city_price_count',20,
        'city_price_status','curated',
        'city_price_version','grand_estate_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',20,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Grand Estate',
        'missing_grand_estate_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_signature_mansion'
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
  where catalog_code='home_signature_mansion'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_signature_mansion';

  select count(*)
  into v_bad_prices
  from tmp_grand_estate_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_signature_mansion',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>20 or v_price_map<>20 or v_bad_prices<>0 or v_active_house_types<>7 then
    raise exception
      'Grand Estate validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
