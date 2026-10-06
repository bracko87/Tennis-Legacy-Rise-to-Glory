-- Connect all uploaded Skyline Apartment images to the 45 active city entries.
-- Two uploaded filenames intentionally differ from the canonical city label:
-- Geneva -> "geneva" and São Paulo -> "Sao Paolo".
-- The Home Country image remains the generic fallback.

do $$
declare
  v_active integer;
  v_matched integer;
  v_distinct_files integer;
  v_home integer;
begin
  with active_cities as (
    select
      l.country_code,
      l.city,
      case
        when l.city='Geneva' then 'Private Life/Skyline Apartment/Skyline Apartment geneva.png'
        when l.city='São Paulo' then 'Private Life/Skyline Apartment/Skyline Apartment Sao Paolo.png'
        else 'Private Life/Skyline Apartment/Skyline Apartment '||l.city||'.png'
      end as storage_name
    from public.private_life_property_catalog_availability a
    join public.private_life_property_locations l
      on l.code=a.location_code
    where a.catalog_code='apt_skyline'
      and a.active=true
  ),
  matched as (
    select c.country_code,c.city,c.storage_name,o.name
    from active_cities c
    left join storage.objects o
      on o.bucket_id='Admin'
     and o.name=c.storage_name
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
    and name='Private Life/Skyline Apartment/Skyline Apartment Home Country.png';

  if v_active<>45 or v_matched<>45 or v_distinct_files<>45 or v_home<>1 then
    raise exception
      'Skyline Apartment image validation failed: active %, matched %, distinct files %, home %.',
      v_active,v_matched,v_distinct_files,v_home;
  end if;
end;
$$;

with active_cities as (
  select
    l.country_code,
    l.city,
    case
      when l.city='Geneva' then 'Private Life/Skyline Apartment/Skyline Apartment geneva.png'
      when l.city='São Paulo' then 'Private Life/Skyline Apartment/Skyline Apartment Sao Paolo.png'
      else 'Private Life/Skyline Apartment/Skyline Apartment '||l.city||'.png'
    end as storage_name
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_skyline'
    and a.active=true
),
city_images as (
  select jsonb_object_agg(
           c.country_code||'|'||c.city,
           'storage://Admin/'||c.storage_name
           order by c.country_code,c.city
         ) as image_map
  from active_cities c
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=c.storage_name
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Skyline Apartment/Skyline Apartment Home Country.png',
    metadata=(
      coalesce(c.metadata,'{}'::jsonb)
      - 'missing_skyline_apartment_images'
    )
    || jsonb_build_object(
      'city_image_urls',city_images.image_map,
      'image_status','curated',
      'city_set_status','ready',
      'city_image_count',45,
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Skyline Apartment',
      'expected_image_storage_path','Private Life/Skyline Apartment/Skyline Apartment Home Country.png',
      'missing_skyline_apartment_images','[]'::jsonb
    ),
    updated_at=now()
from city_images
where c.code='apt_skyline'
  and c.category='apartment';

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
  v_map_count integer;
  v_existing integer;
begin
  select count(*)
  into v_map_count
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='apt_skyline';

  select count(*)
  into v_existing
  from public.private_life_asset_catalog c,
       lateral jsonb_each_text(coalesce(c.metadata->'city_image_urls','{}'::jsonb)) e
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=replace(e.value,'storage://Admin/','')
  where c.code='apt_skyline';

  if v_map_count<>45 or v_existing<>45 then
    raise exception
      'Skyline Apartment image map validation failed: mapped %, existing %.',
      v_map_count,v_existing;
  end if;
end;
$$;
