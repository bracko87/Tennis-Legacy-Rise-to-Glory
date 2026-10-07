-- Publish the 30-city Luxury Penthouse market.
-- This tier intentionally uses a broader set of famous major cities while preserving
-- the very top trophy markets for the later Signature Penthouse category.
-- City-specific images will be connected in a later migration after upload.

do $$
declare
  v_desired integer;
  v_matched integer;
  v_distinct_prices integer;
begin
  with desired(country_code,city,target_price) as (
    values
      ('IE','Dublin',2437675::bigint),
      ('JP','Yokohama',2186525::bigint),
      ('US','Denver',2146875::bigint),
      ('AU','Brisbane',2097875::bigint),
      ('DE','Frankfurt',2043525::bigint),
      ('US','Austin',2028725::bigint),
      ('AU','Perth',2013725::bigint),
      ('CA','Montreal',1936725::bigint),
      ('DE','Hamburg',1934875::bigint),
      ('DE','Berlin',1892675::bigint),
      ('SA','Riyadh',1864525::bigint),
      ('AT','Vienna',1856725::bigint),
      ('US','Dallas',1784525::bigint),
      ('IN','Delhi',1742875::bigint),
      ('IT','Rome',1674525::bigint),
      ('US','Houston',1621875::bigint),
      ('BE','Brussels',1567525::bigint),
      ('PT','Lisbon',1542875::bigint),
      ('ZA','Cape Town',1496875::bigint),
      ('BR','Rio de Janeiro',1472525::bigint),
      ('CZ','Prague',1426875::bigint),
      ('ID','Jakarta',1318525::bigint),
      ('PA','Panama City',1298525::bigint),
      ('GB','Manchester',1289525::bigint),
      ('VN','Ho Chi Minh City',1284725::bigint),
      ('IN','Bengaluru',1256725::bigint),
      ('PH','Manila',1247875::bigint),
      ('CL','Santiago',1236725::bigint),
      ('PL','Warsaw',1235725::bigint),
      ('AR','Buenos Aires',1124875::bigint)
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

  if v_desired<>30 or v_matched<>30 or v_distinct_prices<>30 then
    raise exception
      'Luxury Penthouse seed validation failed: desired %, matched %, distinct prices %.',
      v_desired,v_matched,v_distinct_prices;
  end if;
end;
$$;

-- Only the approved 30-city set should be active for Luxury Penthouse.
update public.private_life_property_catalog_availability
set active=false,
    updated_at=now()
where catalog_code='apt_penthouse';

with desired(country_code,city) as (
  values
    ('IE','Dublin'),('JP','Yokohama'),('US','Denver'),('AU','Brisbane'),('DE','Frankfurt'),
    ('US','Austin'),('AU','Perth'),('CA','Montreal'),('DE','Hamburg'),('DE','Berlin'),
    ('SA','Riyadh'),('AT','Vienna'),('US','Dallas'),('IN','Delhi'),('IT','Rome'),
    ('US','Houston'),('BE','Brussels'),('PT','Lisbon'),('ZA','Cape Town'),('BR','Rio de Janeiro'),
    ('CZ','Prague'),('ID','Jakarta'),('PA','Panama City'),('GB','Manchester'),('VN','Ho Chi Minh City'),
    ('IN','Bengaluru'),('PH','Manila'),('CL','Santiago'),('PL','Warsaw'),('AR','Buenos Aires')
),
matched as (
  select l.code as location_code
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
)
insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select location_code,'apt_penthouse',true
from matched
on conflict (location_code,catalog_code)
do update set active=excluded.active, updated_at=now();

-- Ensure every selected city is visible in the property marketplace.
update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_penthouse'
    and a.active=true
);

with desired(country_code,city,target_price) as (
  values
    ('IE','Dublin',2437675::bigint),
    ('JP','Yokohama',2186525::bigint),
    ('US','Denver',2146875::bigint),
    ('AU','Brisbane',2097875::bigint),
    ('DE','Frankfurt',2043525::bigint),
    ('US','Austin',2028725::bigint),
    ('AU','Perth',2013725::bigint),
    ('CA','Montreal',1936725::bigint),
    ('DE','Hamburg',1934875::bigint),
    ('DE','Berlin',1892675::bigint),
    ('SA','Riyadh',1864525::bigint),
    ('AT','Vienna',1856725::bigint),
    ('US','Dallas',1784525::bigint),
    ('IN','Delhi',1742875::bigint),
    ('IT','Rome',1674525::bigint),
    ('US','Houston',1621875::bigint),
    ('BE','Brussels',1567525::bigint),
    ('PT','Lisbon',1542875::bigint),
    ('ZA','Cape Town',1496875::bigint),
    ('BR','Rio de Janeiro',1472525::bigint),
    ('CZ','Prague',1426875::bigint),
    ('ID','Jakarta',1318525::bigint),
    ('PA','Panama City',1298525::bigint),
    ('GB','Manchester',1289525::bigint),
    ('VN','Ho Chi Minh City',1284725::bigint),
    ('IN','Bengaluru',1256725::bigint),
    ('PH','Manila',1247875::bigint),
    ('CL','Santiago',1236725::bigint),
    ('PL','Warsaw',1235725::bigint),
    ('AR','Buenos Aires',1124875::bigint)
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
      - 'missing_luxury_penthouse_images'
    )
    || jsonb_build_object(
      'city_price_overrides',
      (select jsonb_object_agg(location_code,target_price order by location_code) from matched),
      'city_price_base_snapshots',
      (select jsonb_object_agg(location_code,base_snapshot order by location_code) from matched),
      'city_price_status','calibrated_unique',
      'city_price_version','luxury_penthouse_v1',
      'city_price_model','curated_unique_override_v1',
      'city_price_count',30,
      'city_set_status','database_ready_waiting_for_images',
      'city_set_version','luxury_penthouse_v1',
      'planned_city_count',30,
      'image_status','placeholder',
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Luxury Penthouse',
      'expected_image_storage_path','Private Life/Luxury Penthouse/Luxury Penthouse Home Country.png',
      'pricing_currency','USD',
      'pricing_reviewed_at','2026-10-07'
    ),
    updated_at=now()
where c.code='apt_penthouse'
  and c.category='apartment';

-- Prepare authenticated read access for the images that will be uploaded later.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_luxury_penthouse_authenticated_read'
  ) then
    create policy "admin_private_life_luxury_penthouse_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Luxury Penthouse/%'
      );
  end if;
end $$;

do $$
declare
  v_active integer;
  v_price_count integer;
  v_distinct_prices integer;
  v_hidden integer;
begin
  select count(*)
  into v_active
  from public.private_life_property_catalog_availability
  where catalog_code='apt_penthouse'
    and active=true;

  select count(*)
  into v_price_count
  from public.private_life_asset_catalog c,
       lateral jsonb_object_keys(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='apt_penthouse';

  select count(distinct (value::text)::bigint)
  into v_distinct_prices
  from public.private_life_asset_catalog c,
       lateral jsonb_each(c.metadata->'city_price_overrides')
  where c.code='apt_penthouse';

  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_penthouse'
    and a.active=true
    and (l.active=false or l.marketplace_enabled=false);

  if v_active<>30
     or v_price_count<>30
     or v_distinct_prices<>30
     or v_hidden<>0 then
    raise exception
      'Luxury Penthouse validation failed: active %, prices %, distinct %, hidden %.',
      v_active,v_price_count,v_distinct_prices,v_hidden;
  end if;
end;
$$;
