-- Publish and calibrate the 50-city Luxury City Apartment market.
-- Curated toward globally attractive premium/luxury destinations.
-- Monaco is intentionally excluded from this tier and Florence is included instead.
-- City-specific images will be connected in a later migration.

do $$
declare
  v_desired integer;
  v_matched integer;
  v_distinct_prices integer;
begin
  with desired(country_code,city,target_price) as (
    values
      ('IT','Florence',947625::bigint),
      ('GB','London',1684350::bigint),
      ('FR','Paris',1493775::bigint),
      ('CH','Zurich',1947825::bigint),
      ('CH','Geneva',1836450::bigint),
      ('IT','Milan',1148725::bigint),
      ('NL','Amsterdam',1287650::bigint),
      ('DE','Munich',1324875::bigint),
      ('AT','Vienna',1037425::bigint),
      ('DK','Copenhagen',1348950::bigint),
      ('SE','Stockholm',1274650::bigint),
      ('NO','Oslo',1396875::bigint),
      ('IE','Dublin',1423575::bigint),
      ('ES','Barcelona',928450::bigint),
      ('ES','Madrid',861725::bigint),
      ('PT','Lisbon',814350::bigint),
      ('FR','Nice',1336725::bigint),
      ('LU','Luxembourg',1985450::bigint),
      ('IT','Rome',824675::bigint),
      ('IT','Venice',1267325::bigint),
      ('US','New York',2341875::bigint),
      ('US','San Francisco',2288650::bigint),
      ('US','Los Angeles',2064375::bigint),
      ('US','Miami',1782450::bigint),
      ('US','Boston',1694825::bigint),
      ('US','Seattle',1584275::bigint),
      ('US','Washington',1493650::bigint),
      ('CA','Toronto',1527425::bigint),
      ('CA','Vancouver',1836275::bigint),
      ('US','Chicago',1078650::bigint),
      ('US','San Diego',1745925::bigint),
      ('US','Las Vegas',884375::bigint),
      ('SG','Singapore',2579450::bigint),
      ('HK','Hong Kong',2845775::bigint),
      ('JP','Tokyo',1883625::bigint),
      ('KR','Seoul',1428950::bigint),
      ('AE','Dubai',1717325::bigint),
      ('AE','Abu Dhabi',1351875::bigint),
      ('QA','Doha',1246550::bigint),
      ('MO','Macau',2167425::bigint),
      ('CN','Shanghai',1593875::bigint),
      ('CN','Beijing',1472650::bigint),
      ('TW','Taipei',1337425::bigint),
      ('JP','Osaka',1184775::bigint),
      ('AU','Sydney',1896650::bigint),
      ('AU','Melbourne',1469875::bigint),
      ('AU','Gold Coast',1386425::bigint),
      ('NZ','Auckland',1318650::bigint),
      ('BR','Rio de Janeiro',893775::bigint),
      ('ZA','Cape Town',928625::bigint)
  )
  select count(*), count(distinct target_price)
  into v_desired, v_distinct_prices
  from desired;

  with desired(country_code,city) as (
    values
      ('IT','Florence'),('GB','London'),('FR','Paris'),('CH','Zurich'),('CH','Geneva'),
      ('IT','Milan'),('NL','Amsterdam'),('DE','Munich'),('AT','Vienna'),('DK','Copenhagen'),
      ('SE','Stockholm'),('NO','Oslo'),('IE','Dublin'),('ES','Barcelona'),('ES','Madrid'),
      ('PT','Lisbon'),('FR','Nice'),('LU','Luxembourg'),('IT','Rome'),('IT','Venice'),
      ('US','New York'),('US','San Francisco'),('US','Los Angeles'),('US','Miami'),('US','Boston'),
      ('US','Seattle'),('US','Washington'),('CA','Toronto'),('CA','Vancouver'),('US','Chicago'),
      ('US','San Diego'),('US','Las Vegas'),('SG','Singapore'),('HK','Hong Kong'),('JP','Tokyo'),
      ('KR','Seoul'),('AE','Dubai'),('AE','Abu Dhabi'),('QA','Doha'),('MO','Macau'),
      ('CN','Shanghai'),('CN','Beijing'),('TW','Taipei'),('JP','Osaka'),('AU','Sydney'),
      ('AU','Melbourne'),('AU','Gold Coast'),('NZ','Auckland'),('BR','Rio de Janeiro'),('ZA','Cape Town')
  )
  select count(*)
  into v_matched
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city);

  if v_desired<>50 or v_matched<>50 or v_distinct_prices<>50 then
    raise exception 'Luxury City Apartment seed validation failed: desired %, matched %, distinct prices %.',
      v_desired,v_matched,v_distinct_prices;
  end if;
end;
$$;

-- Retain existing availability rows for history/configuration, but make the approved
-- 50-city set the only active Luxury City Apartment market.
update public.private_life_property_catalog_availability
set active=false,
    updated_at=now()
where catalog_code='apt_luxury_city';

with desired(country_code,city) as (
  values
    ('IT','Florence'),('GB','London'),('FR','Paris'),('CH','Zurich'),('CH','Geneva'),
    ('IT','Milan'),('NL','Amsterdam'),('DE','Munich'),('AT','Vienna'),('DK','Copenhagen'),
    ('SE','Stockholm'),('NO','Oslo'),('IE','Dublin'),('ES','Barcelona'),('ES','Madrid'),
    ('PT','Lisbon'),('FR','Nice'),('LU','Luxembourg'),('IT','Rome'),('IT','Venice'),
    ('US','New York'),('US','San Francisco'),('US','Los Angeles'),('US','Miami'),('US','Boston'),
    ('US','Seattle'),('US','Washington'),('CA','Toronto'),('CA','Vancouver'),('US','Chicago'),
    ('US','San Diego'),('US','Las Vegas'),('SG','Singapore'),('HK','Hong Kong'),('JP','Tokyo'),
    ('KR','Seoul'),('AE','Dubai'),('AE','Abu Dhabi'),('QA','Doha'),('MO','Macau'),
    ('CN','Shanghai'),('CN','Beijing'),('TW','Taipei'),('JP','Osaka'),('AU','Sydney'),
    ('AU','Melbourne'),('AU','Gold Coast'),('NZ','Auckland'),('BR','Rio de Janeiro'),('ZA','Cape Town')
),
matched as (
  select l.code as location_code
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
)
insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select location_code,'apt_luxury_city',true
from matched
on conflict (location_code,catalog_code)
do update set active=excluded.active, updated_at=now();

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_luxury_city'
    and a.active=true
);

with desired(country_code,city,target_price) as (
  values
    ('IT','Florence',947625::bigint),
    ('GB','London',1684350::bigint),
    ('FR','Paris',1493775::bigint),
    ('CH','Zurich',1947825::bigint),
    ('CH','Geneva',1836450::bigint),
    ('IT','Milan',1148725::bigint),
    ('NL','Amsterdam',1287650::bigint),
    ('DE','Munich',1324875::bigint),
    ('AT','Vienna',1037425::bigint),
    ('DK','Copenhagen',1348950::bigint),
    ('SE','Stockholm',1274650::bigint),
    ('NO','Oslo',1396875::bigint),
    ('IE','Dublin',1423575::bigint),
    ('ES','Barcelona',928450::bigint),
    ('ES','Madrid',861725::bigint),
    ('PT','Lisbon',814350::bigint),
    ('FR','Nice',1336725::bigint),
    ('LU','Luxembourg',1985450::bigint),
    ('IT','Rome',824675::bigint),
    ('IT','Venice',1267325::bigint),
    ('US','New York',2341875::bigint),
    ('US','San Francisco',2288650::bigint),
    ('US','Los Angeles',2064375::bigint),
    ('US','Miami',1782450::bigint),
    ('US','Boston',1694825::bigint),
    ('US','Seattle',1584275::bigint),
    ('US','Washington',1493650::bigint),
    ('CA','Toronto',1527425::bigint),
    ('CA','Vancouver',1836275::bigint),
    ('US','Chicago',1078650::bigint),
    ('US','San Diego',1745925::bigint),
    ('US','Las Vegas',884375::bigint),
    ('SG','Singapore',2579450::bigint),
    ('HK','Hong Kong',2845775::bigint),
    ('JP','Tokyo',1883625::bigint),
    ('KR','Seoul',1428950::bigint),
    ('AE','Dubai',1717325::bigint),
    ('AE','Abu Dhabi',1351875::bigint),
    ('QA','Doha',1246550::bigint),
    ('MO','Macau',2167425::bigint),
    ('CN','Shanghai',1593875::bigint),
    ('CN','Beijing',1472650::bigint),
    ('TW','Taipei',1337425::bigint),
    ('JP','Osaka',1184775::bigint),
    ('AU','Sydney',1896650::bigint),
    ('AU','Melbourne',1469875::bigint),
    ('AU','Gold Coast',1386425::bigint),
    ('NZ','Auckland',1318650::bigint),
    ('BR','Rio de Janeiro',893775::bigint),
    ('ZA','Cape Town',928625::bigint)
),
matched as (
  select
    l.code as location_code,
    d.target_price,
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
      - 'missing_standard_city_images'
      - 'missing_large_city_images'
      - 'missing_executive_apartment_images'
    )
    || jsonb_build_object(
      'city_price_overrides',
      (select jsonb_object_agg(location_code,target_price order by location_code) from matched),
      'city_price_base_snapshots',
      (select jsonb_object_agg(location_code,base_snapshot order by location_code) from matched),
      'city_price_status','calibrated_unique',
      'city_price_version','luxury_city_apartment_v1',
      'city_price_model','baseline_scaled_override_v1',
      'city_price_count',50,
      'city_set_status','database_ready_waiting_for_images',
      'city_set_version','luxury_city_apartment_v1',
      'planned_city_count',50,
      'image_status','placeholder',
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Luxury City Apartment',
      'expected_image_storage_path','Private Life/Luxury City Apartment/Luxury City Apartment Home Country.png',
      'pricing_currency','USD',
      'pricing_reviewed_at','2026-10-06'
    ),
    updated_at=now()
where c.code='apt_luxury_city'
  and c.category='apartment';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_luxury_city_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_luxury_city_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Luxury City Apartment/%'
      );
  end if;
end $$;

do $$
declare
  v_active integer;
  v_price_count integer;
  v_distinct_prices integer;
  v_hidden integer;
  v_monaco integer;
  v_florence integer;
begin
  select count(*)
  into v_active
  from public.private_life_property_catalog_availability
  where catalog_code='apt_luxury_city'
    and active=true;

  select count(*)
  into v_price_count
  from public.private_life_asset_catalog c,
       lateral jsonb_object_keys(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='apt_luxury_city';

  select count(distinct (value::text)::bigint)
  into v_distinct_prices
  from public.private_life_asset_catalog c,
       lateral jsonb_each(c.metadata->'city_price_overrides')
  where c.code='apt_luxury_city';

  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_luxury_city'
    and a.active=true
    and (l.active=false or l.marketplace_enabled=false);

  select count(*)
  into v_monaco
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_luxury_city'
    and a.active=true
    and upper(l.country_code)='MC'
    and lower(l.city)='monaco';

  select count(*)
  into v_florence
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_luxury_city'
    and a.active=true
    and upper(l.country_code)='IT'
    and lower(l.city)='florence';

  if v_active<>50 or v_price_count<>50 or v_distinct_prices<>50 or v_hidden<>0 or v_monaco<>0 or v_florence<>1 then
    raise exception 'Luxury City Apartment validation failed: active %, price count %, distinct %, hidden %, Monaco %, Florence %.',
      v_active,v_price_count,v_distinct_prices,v_hidden,v_monaco,v_florence;
  end if;
end;
$$;
