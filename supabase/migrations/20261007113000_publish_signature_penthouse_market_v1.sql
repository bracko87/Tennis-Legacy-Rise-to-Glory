-- Publish the 20-city Signature Penthouse market.
-- This is the final apartment tier and is reserved for the strongest trophy locations.
-- City-specific images will be connected after upload; the Home Country image is already available.

do $$
declare
  v_desired integer;
  v_matched integer;
  v_distinct_prices integer;
begin
  with desired(country_code,city,target_price) as (
    values
      ('MC','Monaco',14389775::bigint),
      ('US','New York',5652175::bigint),
      ('HK','Hong Kong',7097025::bigint),
      ('SG','Singapore',6658925::bigint),
      ('GB','London',4189825::bigint),
      ('AE','Dubai',4026175::bigint),
      ('CA','Toronto',3924225::bigint),
      ('FR','Paris',3604875::bigint),
      ('CA','Vancouver',4659825::bigint),
      ('US','Los Angeles',5301325::bigint),
      ('NL','Amsterdam',3308525::bigint),
      ('CN','Beijing',3591775::bigint),
      ('AU','Sydney',4543175::bigint),
      ('US','Miami',4309325::bigint),
      ('US','Boston',4225000::bigint),
      ('CN','Shanghai',3904875::bigint),
      ('US','Washington',3900000::bigint),
      ('AE','Abu Dhabi',3202725::bigint),
      ('QA','Doha',3010125::bigint),
      ('AU','Melbourne',3522225::bigint)
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

  if v_desired<>20 or v_matched<>20 or v_distinct_prices<>20 then
    raise exception
      'Signature Penthouse seed validation failed: desired %, matched %, distinct prices %.',
      v_desired,v_matched,v_distinct_prices;
  end if;
end;
$$;

-- Only the approved 20-city trophy set should be active.
update public.private_life_property_catalog_availability
set active=false,
    updated_at=now()
where catalog_code='apt_trophy_residence';

with desired(country_code,city) as (
  values
    ('MC','Monaco'),('US','New York'),('HK','Hong Kong'),('SG','Singapore'),('GB','London'),
    ('AE','Dubai'),('CA','Toronto'),('FR','Paris'),('CA','Vancouver'),('US','Los Angeles'),
    ('NL','Amsterdam'),('CN','Beijing'),('AU','Sydney'),('US','Miami'),('US','Boston'),
    ('CN','Shanghai'),('US','Washington'),('AE','Abu Dhabi'),('QA','Doha'),('AU','Melbourne')
),
matched as (
  select l.code as location_code
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
)
insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select location_code,'apt_trophy_residence',true
from matched
on conflict (location_code,catalog_code)
do update set active=excluded.active, updated_at=now();

-- Ensure every selected location is visible in the marketplace.
update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_trophy_residence'
    and a.active=true
);

with desired(country_code,city,target_price) as (
  values
    ('MC','Monaco',14389775::bigint),
    ('US','New York',5652175::bigint),
    ('HK','Hong Kong',7097025::bigint),
    ('SG','Singapore',6658925::bigint),
    ('GB','London',4189825::bigint),
    ('AE','Dubai',4026175::bigint),
    ('CA','Toronto',3924225::bigint),
    ('FR','Paris',3604875::bigint),
    ('CA','Vancouver',4659825::bigint),
    ('US','Los Angeles',5301325::bigint),
    ('NL','Amsterdam',3308525::bigint),
    ('CN','Beijing',3591775::bigint),
    ('AU','Sydney',4543175::bigint),
    ('US','Miami',4309325::bigint),
    ('US','Boston',4225000::bigint),
    ('CN','Shanghai',3904875::bigint),
    ('US','Washington',3900000::bigint),
    ('AE','Abu Dhabi',3202725::bigint),
    ('QA','Doha',3010125::bigint),
    ('AU','Melbourne',3522225::bigint)
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
set image_url='storage://Admin/Private Life/Signature Penthouse/Signature Penthouse Home Country.png',
    metadata=(
      coalesce(c.metadata,'{}'::jsonb)
      - 'city_image_urls'
      - 'location_image_urls'
      - 'missing_signature_penthouse_images'
    )
    || jsonb_build_object(
      'city_price_overrides',
      (select jsonb_object_agg(location_code,target_price order by location_code) from matched),
      'city_price_base_snapshots',
      (select jsonb_object_agg(location_code,base_snapshot order by location_code) from matched),
      'city_price_status','calibrated_unique',
      'city_price_version','signature_penthouse_v1',
      'city_price_model','curated_unique_override_v1',
      'city_price_count',20,
      'city_set_status','database_ready_waiting_for_images',
      'city_set_version','signature_penthouse_v1',
      'planned_city_count',20,
      'image_status','fallback_ready',
      'city_image_count',0,
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Signature Penthouse',
      'expected_image_storage_path','Private Life/Signature Penthouse/Signature Penthouse Home Country.png',
      'missing_signature_penthouse_images',
      (select jsonb_agg(location_code order by location_code) from matched),
      'pricing_currency','USD',
      'pricing_reviewed_at','2026-10-07'
    ),
    updated_at=now()
where c.code='apt_trophy_residence'
  and c.category='apartment';

-- Prepare authenticated read access for the Signature Penthouse image folder.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_signature_penthouse_authenticated_read'
  ) then
    create policy "admin_private_life_signature_penthouse_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Signature Penthouse/%'
      );
  end if;
end $$;

do $$
declare
  v_active integer;
  v_price_count integer;
  v_distinct_prices integer;
  v_hidden integer;
  v_home integer;
begin
  select count(*)
  into v_active
  from public.private_life_property_catalog_availability
  where catalog_code='apt_trophy_residence'
    and active=true;

  select count(*)
  into v_price_count
  from public.private_life_asset_catalog c,
       lateral jsonb_object_keys(coalesce(c.metadata->'city_price_overrides','{}'::jsonb))
  where c.code='apt_trophy_residence';

  select count(distinct (value::text)::bigint)
  into v_distinct_prices
  from public.private_life_asset_catalog c,
       lateral jsonb_each(c.metadata->'city_price_overrides')
  where c.code='apt_trophy_residence';

  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_trophy_residence'
    and a.active=true
    and (l.active=false or l.marketplace_enabled=false);

  select count(*)
  into v_home
  from storage.objects
  where bucket_id='Admin'
    and name='Private Life/Signature Penthouse/Signature Penthouse Home Country.png';

  if v_active<>20
     or v_price_count<>20
     or v_distinct_prices<>20
     or v_hidden<>0
     or v_home<>1 then
    raise exception
      'Signature Penthouse validation failed: active %, prices %, distinct %, hidden %, home %.',
      v_active,v_price_count,v_distinct_prices,v_hidden,v_home;
  end if;
end;
$$;
