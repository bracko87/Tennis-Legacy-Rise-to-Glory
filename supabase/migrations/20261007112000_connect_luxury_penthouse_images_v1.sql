-- Connect all uploaded Luxury Penthouse images to the 30 active city entries.
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
      'Private Life/Luxury Penthouse/Luxury Penthouse '||l.city||'.png' as storage_name
    from public.private_life_property_catalog_availability a
    join public.private_life_property_locations l
      on l.code=a.location_code
    where a.catalog_code='apt_penthouse'
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
    and name='Private Life/Luxury Penthouse/Luxury Penthouse Home Country.png';

  if v_active<>30 or v_matched<>30 or v_distinct_files<>30 or v_home<>1 then
    raise exception
      'Luxury Penthouse image validation failed: active %, matched %, distinct files %, home %.',
      v_active,v_matched,v_distinct_files,v_home;
  end if;
end;
$$;

with active_cities as (
  select
    l.country_code,
    l.city,
    'Private Life/Luxury Penthouse/Luxury Penthouse '||l.city||'.png' as storage_name
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_penthouse'
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
set image_url='storage://Admin/Private Life/Luxury Penthouse/Luxury Penthouse Home Country.png',
    metadata=(
      coalesce(c.metadata,'{}'::jsonb)
      - 'missing_luxury_penthouse_images'
      - 'location_image_urls'
    )
    || jsonb_build_object(
      'city_image_urls',city_images.image_map,
      'image_status','curated',
      'city_set_status','ready',
      'city_image_count',30,
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Luxury Penthouse',
      'expected_image_storage_path','Private Life/Luxury Penthouse/Luxury Penthouse Home Country.png',
      'missing_luxury_penthouse_images','[]'::jsonb
    ),
    updated_at=now()
from city_images
where c.code='apt_penthouse'
  and c.category='apartment';

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
  v_map_count integer;
  v_existing integer;
begin
  select count(*)
  into v_map_count
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='apt_penthouse';

  select count(*)
  into v_existing
  from public.private_life_asset_catalog c,
       lateral jsonb_each_text(coalesce(c.metadata->'city_image_urls','{}'::jsonb)) e
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name=replace(e.value,'storage://Admin/','')
  where c.code='apt_penthouse';

  if v_map_count<>30 or v_existing<>30 then
    raise exception
      'Luxury Penthouse image map validation failed: mapped %, existing %.',
      v_map_count,v_existing;
  end if;
end;
$$;
