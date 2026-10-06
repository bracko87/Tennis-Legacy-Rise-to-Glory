-- Connect the uploaded Executive Apartment images to all 55 approved city entries.
-- The Home Country image remains the generic fallback for non-standard/home locations.

do $$
declare
  v_expected integer;
  v_matched integer;
  v_home integer;
begin
  select count(*)
  into v_expected
  from public.private_life_property_catalog_availability
  where catalog_code='apt_executive'
    and active=true;

  select count(*)
  into v_matched
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Executive Apartment/Executive Apartment '||l.city||'.png'
  where a.catalog_code='apt_executive'
    and a.active=true;

  select count(*)
  into v_home
  from storage.objects
  where bucket_id='Admin'
    and name='Private Life/Executive Apartment/Executive Apartment Home Country.png';

  if v_expected<>55 or v_matched<>55 or v_home<>1 then
    raise exception 'Executive Apartment image validation failed: expected %, matched %, home %.',
      v_expected,v_matched,v_home;
  end if;
end;
$$;

with city_images as (
  select jsonb_object_agg(
           l.country_code||'|'||l.city,
           'storage://Admin/Private Life/Executive Apartment/Executive Apartment '||l.city||'.png'
           order by l.country_code,l.city
         ) as image_map
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_executive'
    and a.active=true
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Executive Apartment/Executive Apartment Home Country.png',
    metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'missing_standard_city_images'
      - 'missing_large_city_images'
      || jsonb_build_object(
        'city_image_urls',city_images.image_map,
        'image_status','curated',
        'city_set_status','ready',
        'city_image_count',55,
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Executive Apartment',
        'expected_image_storage_path','Private Life/Executive Apartment/Executive Apartment Home Country.png',
        'missing_executive_apartment_images','[]'::jsonb
      ),
    updated_at=now()
from city_images
where c.code='apt_executive'
  and c.category='apartment';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_executive_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_executive_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Executive Apartment/%'
      );
  end if;
end $$;

do $$
declare
  v_map_count integer;
begin
  select count(*)
  into v_map_count
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='apt_executive';

  if v_map_count<>55 then
    raise exception 'Executive Apartment image map contains % entries instead of 55.',v_map_count;
  end if;
end;
$$;
