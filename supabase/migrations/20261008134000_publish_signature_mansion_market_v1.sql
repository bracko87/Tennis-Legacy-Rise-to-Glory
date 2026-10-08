-- Publish Signature Mansion as Houses & Villas tier 8.
-- Ultimate trophy residences in 14 ultra-prime or personally significant locations.

alter table public.private_life_asset_catalog
  drop constraint if exists private_life_asset_catalog_tier_check;

alter table public.private_life_asset_catalog
  add constraint private_life_asset_catalog_tier_check
  check (tier >= 1 and tier <= 8);

create temporary table tmp_signature_mansion_desired (
  ord integer primary key,
  country_code text not null,
  country_name text not null,
  city text not null,
  preferred_location_code text not null,
  target_price bigint not null,
  base_house_price bigint not null
) on commit drop;

insert into tmp_signature_mansion_desired(
  ord,country_code,country_name,city,preferred_location_code,target_price,base_house_price
)
values
  (1,'US','United States','Beverly Hills','us_beverlyhills',45000000::bigint,5000000::bigint),
  (2,'US','United States','Palm Beach','us_palmbeach',55000000::bigint,4500000::bigint),
  (3,'US','United States','New York','us_newyork',42500000::bigint,2864448::bigint),
  (4,'GB','United Kingdom','London','gb_london',48000000::bigint,1785004::bigint),
  (5,'BL','Saint Barthélemy','St. Barts','bl_stbarts',60000000::bigint,5000000::bigint),
  (6,'FR','France','Saint-Tropez','fr_sainttropez',38000000::bigint,2000000::bigint),
  (7,'CH','Switzerland','Geneva','ch_geneva',35000000::bigint,1999347::bigint),
  (8,'AE','United Arab Emirates','Dubai','ae_dubai',50000000::bigint,1858243::bigint),
  (9,'US','United States','The Hamptons','us_thehamptons',52500000::bigint,4500000::bigint),
  (10,'ID','Indonesia','Bali','id_bali',22500000::bigint,662402::bigint),
  (11,'AU','Australia','Sydney','au_sydney',36000000::bigint,1997001::bigint),
  (12,'ES','Spain','Marbella','es_marbella',30000000::bigint,1300000::bigint),
  (13,'IT','Italy','Lake Como','it_lakecomo',32500000::bigint,2000000::bigint),
  (14,'RS','Serbia','Aleksandrovo','rs_aleksandrovo',9500000::bigint,150000::bigint);

do $$
declare
  v_desired integer;
  v_conflicts integer;
begin
  select count(*) into v_desired from tmp_signature_mansion_desired;

  select count(*)
  into v_conflicts
  from tmp_signature_mansion_desired d
  join public.private_life_property_locations l
    on l.code=d.preferred_location_code
  where not (
    l.country_code=d.country_code
    and lower(l.city)=lower(d.city)
  );

  if v_desired<>14 or v_conflicts<>0 then
    raise exception
      'Signature Mansion preflight failed: desired %, location-code conflicts %.',
      v_desired,v_conflicts;
  end if;
end;
$$;

with base as (
  select coalesce(max(sort_order),0) as max_sort
  from public.private_life_property_locations
),
missing as (
  select d.*,b.max_sort
  from tmp_signature_mansion_desired d
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
  preferred_location_code,
  country_code,
  country_name,
  city,
  greatest(
    case when preferred_location_code='rs_aleksandrovo' then 80000::bigint else 200000::bigint end,
    ((base_house_price * 40 / 100 + 2500) / 5000) * 5000
  ),
  base_house_price,
  300,
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
  from tmp_signature_mansion_desired d
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
  from tmp_signature_mansion_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city);

  select count(*)
  into v_nonunique
  from (
    select d.ord
    from tmp_signature_mansion_desired d
    join public.private_life_property_locations l
      on l.country_code=d.country_code
     and lower(l.city)=lower(d.city)
    group by d.ord
    having count(*)<>1
  ) x;

  if v_locations<>14 or v_nonunique<>0 then
    raise exception
      'Signature Mansion location validation failed: matched %, non-unique %.',
      v_locations,v_nonunique;
  end if;
end;
$$;

insert into public.private_life_asset_catalog(
  code,category,name,tier,description,purchase_price,prestige,rarity,
  annual_running_cost,annual_value_rate_bps,resale_discount_bps,
  image_url,active,metadata
)
values(
  'home_trophy_mansion',
  'house_villa',
  'Signature Mansion',
  8,
  'Ultimate trophy residence representing the peak of private residential prestige.',
  35000000,
  50,
  'legendary',
  3500000,
  325,
  700,
  'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82',
  true,
  jsonb_build_object(
    'property_kind','house_villa',
    'location_priced',true,
    'location_availability_enforced',true,
    'market_currency','USD',
    'pricing_currency','USD',
    'catalog_order',8,
    'price_multiplier_bps',10000,
    'running_cost_bps',90,
    'value_rate_adjustment_bps',150,
    'city_price_model','baseline_scaled_override_v1',
    'city_price_version','signature_mansion_v1',
    'city_price_status','curated',
    'pricing_reviewed_at','2026-10-08',
    'planned_city_count',14,
    'city_set_status','database_ready_waiting_for_images',
    'image_status','placeholder',
    'image_storage_bucket','Admin',
    'image_storage_folder','Private Life/Signature Mansion',
    'expected_image_storage_path','Private Life/Signature Mansion/Signature Mansion <City>.png',
    'missing_signature_mansion_images','pending_upload',
    'destination_theme','ultimate_trophy_residence'
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
  active=true,
  metadata=excluded.metadata,
  updated_at=now();

insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select l.code,'home_trophy_mansion',true
from tmp_signature_mansion_desired d
join public.private_life_property_locations l
  on l.country_code=d.country_code
 and lower(l.city)=lower(d.city)
on conflict(location_code,catalog_code) do update set
  active=true,
  updated_at=now();

update public.private_life_property_catalog_availability a
set active=false,
    updated_at=now()
where a.catalog_code='home_trophy_mansion'
  and not exists (
    select 1
    from tmp_signature_mansion_desired d
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
  from tmp_signature_mansion_desired d
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
        'city_price_count',14,
        'city_price_status','curated',
        'city_price_version','signature_mansion_v1',
        'city_price_model','baseline_scaled_override_v1',
        'planned_city_count',14,
        'city_set_status','database_ready_waiting_for_images',
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Signature Mansion',
        'missing_signature_mansion_images','pending_upload'
      ),
    active=true,
    updated_at=now()
from payload
where c.code='home_trophy_mansion'
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
  where catalog_code='home_trophy_mansion'
    and active=true;

  select count(*)
  into v_price_map
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='home_trophy_mansion';

  select count(*)
  into v_bad_prices
  from tmp_signature_mansion_desired d
  join public.private_life_property_locations l
    on l.country_code=d.country_code
   and lower(l.city)=lower(d.city)
  where public.private_life_property_effective_price_v1('home_trophy_mansion',l.code)<>d.target_price;

  select count(*)
  into v_active_house_types
  from public.private_life_asset_catalog
  where category='house_villa'
    and active=true;

  if v_availability<>14 or v_price_map<>14 or v_bad_prices<>0 or v_active_house_types<>8 then
    raise exception
      'Signature Mansion validation failed: availability %, prices %, bad prices %, active house types %.',
      v_availability,v_price_map,v_bad_prices,v_active_house_types;
  end if;
end;
$$;
