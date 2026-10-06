-- Connect all uploaded Luxury City Apartment images to the 50 active city entries.
-- Uses normalized filename matching so minor upload naming inconsistencies
-- (spacing/case) do not block the correct city-to-image mapping.

do $$
declare
  v_active integer;
  v_matched integer;
  v_distinct_files integer;
  v_home integer;
begin
  with active_cities as (
    select l.country_code,l.city
    from public.private_life_property_catalog_availability a
    join public.private_life_property_locations l on l.code=a.location_code
    where a.catalog_code='apt_luxury_city'
      and a.active=true
  ),
  files as (
    select
      name,
      regexp_replace(
        lower(
          regexp_replace(
            regexp_replace(
              name,
              '^Private Life/Luxury City Apartment/Luxury City Apartment',
              ''
            ),
            '\.png$',
            ''
          )
        ),
        '[[:space:]]+',
        '',
        'g'
      ) as normalized_city
    from storage.objects
    where bucket_id='Admin'
      and name like 'Private Life/Luxury City Apartment/Luxury City Apartment%.png'
      and name <> 'Private Life/Luxury City Apartment/Luxury City Apartment Home Country.png'
  ),
  matched as (
    select c.country_code,c.city,f.name
    from active_cities c
    left join files f
      on f.normalized_city=regexp_replace(lower(c.city),'[[:space:]]+','','g')
  )
  select
    count(*),
    count(name),
    count(distinct name)
  into v_active,v_matched,v_distinct_files
  from matched;

  select count(*)
  into v_home
  from storage.objects
  where bucket_id='Admin'
    and name='Private Life/Luxury City Apartment/Luxury City Apartment Home Country.png';

  if v_active<>50 or v_matched<>50 or v_distinct_files<>50 or v_home<>1 then
    raise exception
      'Luxury City Apartment image validation failed: active %, matched %, distinct files %, home %.',
      v_active,v_matched,v_distinct_files,v_home;
  end if;
end;
$$;

with active_cities as (
  select l.country_code,l.city
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l on l.code=a.location_code
  where a.catalog_code='apt_luxury_city'
    and a.active=true
),
files as (
  select
    name,
    regexp_replace(
      lower(
        regexp_replace(
          regexp_replace(
            name,
            '^Private Life/Luxury City Apartment/Luxury City Apartment',
            ''
          ),
          '\.png$',
          ''
        )
      ),
      '[[:space:]]+',
      '',
      'g'
    ) as normalized_city
  from storage.objects
  where bucket_id='Admin'
    and name like 'Private Life/Luxury City Apartment/Luxury City Apartment%.png'
    and name <> 'Private Life/Luxury City Apartment/Luxury City Apartment Home Country.png'
),
city_images as (
  select jsonb_object_agg(
           c.country_code||'|'||c.city,
           'storage://Admin/'||f.name
           order by c.country_code,c.city
         ) as image_map
  from active_cities c
  join files f
    on f.normalized_city=regexp_replace(lower(c.city),'[[:space:]]+','','g')
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Luxury City Apartment/Luxury City Apartment Home Country.png',
    metadata=(
      coalesce(c.metadata,'{}'::jsonb)
      - 'missing_luxury_city_apartment_images'
    )
    || jsonb_build_object(
      'city_image_urls',city_images.image_map,
      'image_status','curated',
      'city_set_status','ready',
      'city_image_count',50,
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Luxury City Apartment',
      'expected_image_storage_path','Private Life/Luxury City Apartment/Luxury City Apartment Home Country.png',
      'missing_luxury_city_apartment_images','[]'::jsonb
    ),
    updated_at=now()
from city_images
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
  v_map_count integer;
  v_existing integer;
begin
  select count(*)
  into v_map_count
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='apt_luxury_city';

  select count(*)
  into v_existing
  from public.private_life_asset_catalog c,
       lateral jsonb_each_text(coalesce(c.metadata->'city_image_urls','{}'::jsonb)) e
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=replace(e.value,'storage://Admin/','')
  where c.code='apt_luxury_city';

  if v_map_count<>50 or v_existing<>50 then
    raise exception
      'Luxury City Apartment image map validation failed: mapped %, existing %.',
      v_map_count,v_existing;
  end if;
end;
$$;
