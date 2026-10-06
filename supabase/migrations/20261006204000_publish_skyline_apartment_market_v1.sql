-- Publish the 45-city Skyline Apartment market.
-- 30 locations are classified as exclusive skyline markets.
-- 15 locations are classified as major-city skyline markets.
-- City-specific images will be connected in a later migration.

do $$
declare
  v_desired integer;
  v_matched integer;
  v_distinct_prices integer;
begin
  with desired(country_code,city,target_price,market_class) as (
    values
      ('GB','London',2257125::bigint,'exclusive'),
      ('FR','Paris',1986775::bigint,'exclusive'),
      ('CH','Zurich',2571175::bigint,'exclusive'),
      ('CH','Geneva',2405825::bigint,'exclusive'),
      ('IT','Milan',1539325::bigint,'exclusive'),
      ('NL','Amsterdam',1712675::bigint,'exclusive'),
      ('DE','Munich',1748925::bigint,'exclusive'),
      ('ES','Barcelona',1244175::bigint,'exclusive'),
      ('DK','Copenhagen',1780725::bigint,'exclusive'),
      ('NO','Oslo',1843925::bigint,'exclusive'),
      ('US','New York',3161625::bigint,'exclusive'),
      ('US','San Francisco',3066875::bigint,'exclusive'),
      ('US','Los Angeles',2766325::bigint,'exclusive'),
      ('US','Miami',2370725::bigint,'exclusive'),
      ('US','Boston',2237225::bigint,'exclusive'),
      ('US','San Diego',2321125::bigint,'exclusive'),
      ('CA','Toronto',2031525::bigint,'exclusive'),
      ('CA','Vancouver',2460675::bigint,'exclusive'),
      ('SG','Singapore',3456525::bigint,'exclusive'),
      ('HK','Hong Kong',3841875::bigint,'exclusive'),
      ('JP','Tokyo',2524125::bigint,'exclusive'),
      ('KR','Seoul',1900575::bigint,'exclusive'),
      ('AE','Dubai',2301275::bigint,'exclusive'),
      ('AE','Abu Dhabi',1798075::bigint,'exclusive'),
      ('QA','Doha',1645525::bigint,'exclusive'),
      ('MO','Macau',2904425::bigint,'exclusive'),
      ('CN','Shanghai',2135875::bigint,'exclusive'),
      ('CN','Beijing',1958675::bigint,'exclusive'),
      ('AU','Sydney',2541575::bigint,'exclusive'),
      ('AU','Melbourne',1954975::bigint,'exclusive'),

      ('SE','Stockholm',1695375::bigint,'major_city'),
      ('ES','Madrid',1154775::bigint,'major_city'),
      ('US','Chicago',1445475::bigint,'major_city'),
      ('US','Seattle',2091325::bigint,'major_city'),
      ('US','Washington',1956725::bigint,'major_city'),
      ('US','Las Vegas',1176275::bigint,'major_city'),
      ('TW','Taipei',1778825::bigint,'major_city'),
      ('JP','Osaka',1563975::bigint,'major_city'),
      ('CN','Shenzhen',1864325::bigint,'major_city'),
      ('MY','Kuala Lumpur',1093875::bigint,'major_city'),
      ('TH','Bangkok',1248725::bigint,'major_city'),
      ('TR','Istanbul',1092675::bigint,'major_city'),
      ('MX','Mexico City',1138525::bigint,'major_city'),
      ('BR','São Paulo',1047875::bigint,'major_city'),
      ('IN','Mumbai',1589425::bigint,'major_city')
  ),
  matched as (
    select d.*,l.code as location_code
    from desired d
    left join public.private_life_property_locations l
      on upper(l.country_code)=d.country_code
     and lower(l.city)=lower(d.city)
  )
  select
    count(*),
    count(location_code),
    count(distinct target_price)
  into v_desired,v_matched,v_distinct_prices
  from matched;

  if v_desired<>45 or v_matched<>45 or v_distinct_prices<>45 then
    raise exception
      'Skyline Apartment seed validation failed: desired %, matched %, distinct prices %.',
      v_desired,v_matched,v_distinct_prices;
  end if;
end;
$$;

-- Only the approved 45-city set should be active for Skyline Apartment.
update public.private_life_property_catalog_availability
set active=false,
    updated_at=now()
where catalog_code='apt_skyline';

with desired(country_code,city) as (
  values
    ('GB','London'),('FR','Paris'),('CH','Zurich'),('CH','Geneva'),('IT','Milan'),
    ('NL','Amsterdam'),('DE','Munich'),('ES','Barcelona'),('DK','Copenhagen'),('NO','Oslo'),
    ('US','New York'),('US','San Francisco'),('US','Los Angeles'),('US','Miami'),('US','Boston'),
    ('US','San Diego'),('CA','Toronto'),('CA','Vancouver'),('SG','Singapore'),('HK','Hong Kong'),
    ('JP','Tokyo'),('KR','Seoul'),('AE','Dubai'),('AE','Abu Dhabi'),('QA','Doha'),
    ('MO','Macau'),('CN','Shanghai'),('CN','Beijing'),('AU','Sydney'),('AU','Melbourne'),
    ('SE','Stockholm'),('ES','Madrid'),('US','Chicago'),('US','Seattle'),('US','Washington'),
    ('US','Las Vegas'),('TW','Taipei'),('JP','Osaka'),('CN','Shenzhen'),('MY','Kuala Lumpur'),
    ('TH','Bangkok'),('TR','Istanbul'),('MX','Mexico City'),('BR','São Paulo'),('IN','Mumbai')
),
matched as (
  select l.code as location_code
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
)
insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select location_code,'apt_skyline',true
from matched
on conflict (location_code,catalog_code)
do update set active=excluded.active, updated_at=now();

-- Make all approved locations visible in the property marketplace.
update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_skyline'
    and a.active=true
);

with desired(country_code,city,target_price,market_class) as (
  values
    ('GB','London',2257125::bigint,'exclusive'),
    ('FR','Paris',1986775::bigint,'exclusive'),
    ('CH','Zurich',2571175::bigint,'exclusive'),
    ('CH','Geneva',2405825::bigint,'exclusive'),
    ('IT','Milan',1539325::bigint,'exclusive'),
    ('NL','Amsterdam',1712675::bigint,'exclusive'),
    ('DE','Munich',1748925::bigint,'exclusive'),
    ('ES','Barcelona',1244175::bigint,'exclusive'),
    ('DK','Copenhagen',1780725::bigint,'exclusive'),
    ('NO','Oslo',1843925::bigint,'exclusive'),
    ('US','New York',3161625::bigint,'exclusive'),
    ('US','San Francisco',3066875::bigint,'exclusive'),
    ('US','Los Angeles',2766325::bigint,'exclusive'),
    ('US','Miami',2370725::bigint,'exclusive'),
    ('US','Boston',2237225::bigint,'exclusive'),
    ('US','San Diego',2321125::bigint,'exclusive'),
    ('CA','Toronto',2031525::bigint,'exclusive'),
    ('CA','Vancouver',2460675::bigint,'exclusive'),
    ('SG','Singapore',3456525::bigint,'exclusive'),
    ('HK','Hong Kong',3841875::bigint,'exclusive'),
    ('JP','Tokyo',2524125::bigint,'exclusive'),
    ('KR','Seoul',1900575::bigint,'exclusive'),
    ('AE','Dubai',2301275::bigint,'exclusive'),
    ('AE','Abu Dhabi',1798075::bigint,'exclusive'),
    ('QA','Doha',1645525::bigint,'exclusive'),
    ('MO','Macau',2904425::bigint,'exclusive'),
    ('CN','Shanghai',2135875::bigint,'exclusive'),
    ('CN','Beijing',1958675::bigint,'exclusive'),
    ('AU','Sydney',2541575::bigint,'exclusive'),
    ('AU','Melbourne',1954975::bigint,'exclusive'),

    ('SE','Stockholm',1695375::bigint,'major_city'),
    ('ES','Madrid',1154775::bigint,'major_city'),
    ('US','Chicago',1445475::bigint,'major_city'),
    ('US','Seattle',2091325::bigint,'major_city'),
    ('US','Washington',1956725::bigint,'major_city'),
    ('US','Las Vegas',1176275::bigint,'major_city'),
    ('TW','Taipei',1778825::bigint,'major_city'),
    ('JP','Osaka',1563975::bigint,'major_city'),
    ('CN','Shenzhen',1864325::bigint,'major_city'),
    ('MY','Kuala Lumpur',1093875::bigint,'major_city'),
    ('TH','Bangkok',1248725::bigint,'major_city'),
    ('TR','Istanbul',1092675::bigint,'major_city'),
    ('MX','Mexico City',1138525::bigint,'major_city'),
    ('BR','São Paulo',1047875::bigint,'major_city'),
    ('IN','Mumbai',1589425::bigint,'major_city')
),
matched as (
  select
    l.code as location_code,
    d.target_price,
    d.market_class,
    l.apartment_base_price as base_snapshot
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
)
update public.private_life_asset_catalog c
set metadata=(
      coalesce(c.metadata,'{}'::jsonb)
      - 'city_image_urls'
      - 'location_image_urls'
      - 'missing_skyline_apartment_images'
    )
    || jsonb_build_object(
      'city_price_overrides',
      (select jsonb_object_agg(location_code,target_price order by location_code) from matched),
      'city_price_base_snapshots',
      (select jsonb_object_agg(location_code,base_snapshot order by location_code) from matched),
      'city_market_class',
      (select jsonb_object_agg(location_code,market_class order by location_code) from matched),
      'exclusive_city_count',30,
      'major_city_count',15,
      'city_price_status','calibrated_unique',
      'city_price_version','skyline_apartment_v1',
      'city_price_model','baseline_scaled_override_v1',
      'city_price_count',45,
      'city_set_status','database_ready_waiting_for_images',
      'city_set_version','skyline_apartment_v1',
      'planned_city_count',45,
      'image_status','placeholder',
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Skyline Apartment',
      'expected_image_storage_path','Private Life/Skyline Apartment/Skyline Apartment Home Country.png',
      'pricing_currency','USD',
      'pricing_reviewed_at','2026-10-06'
    ),
    updated_at=now()
where c.code='apt_skyline'
  and c.category='apartment';

-- Prepare authenticated access for the city-specific images that will be uploaded later.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_skyline_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_skyline_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Skyline Apartment/%'
      );
  end if;
end $$;

do $$
declare
  v_active integer;
  v_price_count integer;
  v_distinct_prices integer;
  v_exclusive integer;
  v_major integer;
  v_hidden integer;
  v_monaco integer;
begin
  select count(*)
  into v_active
  from public.private_life_property_catalog_availability
  where catalog_code='apt_skyline'
    and active=true;

  select count(*)
  into v_price_count
  from public.private_life_asset_catalog c,
       lateral jsonb_object_keys(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='apt_skyline';

  select count(distinct (value::text)::bigint)
  into v_distinct_prices
  from public.private_life_asset_catalog c,
       lateral jsonb_each(c.metadata->'city_price_overrides')
  where c.code='apt_skyline';

  select count(*)
  into v_exclusive
  from public.private_life_asset_catalog c,
       lateral jsonb_each_text(c.metadata->'city_market_class') e
  where c.code='apt_skyline'
    and e.value='exclusive';

  select count(*)
  into v_major
  from public.private_life_asset_catalog c,
       lateral jsonb_each_text(c.metadata->'city_market_class') e
  where c.code='apt_skyline'
    and e.value='major_city';

  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_skyline'
    and a.active=true
    and (l.active=false or l.marketplace_enabled=false);

  select count(*)
  into v_monaco
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_skyline'
    and a.active=true
    and upper(l.country_code)='MC';

  if v_active<>45
     or v_price_count<>45
     or v_distinct_prices<>45
     or v_exclusive<>30
     or v_major<>15
     or v_hidden<>0
     or v_monaco<>0 then
    raise exception
      'Skyline Apartment validation failed: active %, prices %, distinct %, exclusive %, major %, hidden %, Monaco %.',
      v_active,v_price_count,v_distinct_prices,v_exclusive,v_major,v_hidden,v_monaco;
  end if;
end;
$$;
