-- Connect all uploaded Signature Penthouse city images to the 20 active city entries.
-- Home Country remains the generic fallback image.

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
      'Private Life/Signature Penthouse/Signature Penthouse ' || l.city || '.png' as storage_name
    from public.private_life_property_catalog_availability a
    join public.private_life_property_locations l
      on l.code = a.location_code
    where a.catalog_code = 'apt_trophy_residence'
      and a.active = true
  ),
  matched as (
    select
      c.country_code,
      c.city,
      c.storage_name,
      o.name
    from active_cities c
    left join storage.objects o
      on o.bucket_id = 'Admin'
     and o.name = c.storage_name
  )
  select
    count(*),
    count(name),
    count(distinct name)
  into v_active, v_matched, v_distinct_files
  from matched;

  select count(*)
  into v_home
  from storage.objects
  where bucket_id = 'Admin'
    and name = 'Private Life/Signature Penthouse/Signature Penthouse Home Country.png';

  if v_active <> 20
     or v_matched <> 20
     or v_distinct_files <> 20
     or v_home <> 1 then
    raise exception
      'Signature Penthouse image validation failed: active %, matched %, distinct files %, home %.',
      v_active, v_matched, v_distinct_files, v_home;
  end if;
end;
$$;

with active_cities as (
  select
    l.country_code,
    l.city,
    'Private Life/Signature Penthouse/Signature Penthouse ' || l.city || '.png' as storage_name
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code = a.location_code
  where a.catalog_code = 'apt_trophy_residence'
    and a.active = true
),
city_images as (
  select jsonb_object_agg(
           c.country_code || '|' || c.city,
           'storage://Admin/' || c.storage_name
           order by c.country_code, c.city
         ) as image_map
  from active_cities c
  join storage.objects o
    on o.bucket_id = 'Admin'
   and o.name = c.storage_name
)
update public.private_life_asset_catalog c
set image_url = 'storage://Admin/Private Life/Signature Penthouse/Signature Penthouse Home Country.png',
    metadata = (
      coalesce(c.metadata, '{}'::jsonb)
      - 'location_image_urls'
      - 'missing_signature_penthouse_images'
    )
    || jsonb_build_object(
      'city_image_urls', city_images.image_map,
      'image_status', 'curated',
      'city_set_status', 'ready',
      'city_image_count', 20,
      'image_storage_bucket', 'Admin',
      'image_storage_folder', 'Private Life/Signature Penthouse',
      'expected_image_storage_path', 'Private Life/Signature Penthouse/Signature Penthouse Home Country.png',
      'missing_signature_penthouse_images', '[]'::jsonb
    ),
    updated_at = now()
from city_images
where c.code = 'apt_trophy_residence'
  and c.category = 'apartment';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'admin_private_life_signature_penthouse_authenticated_read'
  ) then
    create policy "admin_private_life_signature_penthouse_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id = 'Admin'
        and name like 'Private Life/Signature Penthouse/%'
      );
  end if;
end;
$$;

do $$
declare
  v_map_count integer;
  v_existing integer;
  v_active_mapped integer;
begin
  select count(*)
  into v_map_count
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls', '{}'::jsonb))
  where c.code = 'apt_trophy_residence';

  select count(*)
  into v_existing
  from public.private_life_asset_catalog c,
       lateral jsonb_each_text(coalesce(c.metadata->'city_image_urls', '{}'::jsonb)) e
  join storage.objects o
    on o.bucket_id = 'Admin'
   and o.name = replace(e.value, 'storage://Admin/', '')
  where c.code = 'apt_trophy_residence';

  select count(*)
  into v_active_mapped
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code = a.location_code
  join public.private_life_asset_catalog c
    on c.code = a.catalog_code
  where a.catalog_code = 'apt_trophy_residence'
    and a.active = true
    and (c.metadata->'city_image_urls') ? (l.country_code || '|' || l.city);

  if v_map_count <> 20
     or v_existing <> 20
     or v_active_mapped <> 20 then
    raise exception
      'Signature Penthouse image map validation failed: mapped %, existing %, active mapped %.',
      v_map_count, v_existing, v_active_mapped;
  end if;
end;
$$;
