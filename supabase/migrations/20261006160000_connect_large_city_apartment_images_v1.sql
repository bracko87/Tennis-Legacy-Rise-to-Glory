-- Connect the uploaded Large City Apartment images to all 60 approved city entries.
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
  where catalog_code='apt_luxury_residence';

  select count(*)
  into v_matched
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  join storage.objects o
    on o.bucket_id='Admin'
   and o.name='Private Life/Large City Apartment/Large City Apartment '||l.city||'.png'
  where a.catalog_code='apt_luxury_residence';

  select count(*)
  into v_home
  from storage.objects
  where bucket_id='Admin'
    and name='Private Life/Large City Apartment/Large City Apartment Home Country.png';

  if v_expected<>60 or v_matched<>60 or v_home<>1 then
    raise exception 'Large City Apartment image validation failed: expected %, matched %, home %.',
      v_expected,v_matched,v_home;
  end if;
end;
$$;

with city_images as (
  select jsonb_object_agg(
           l.country_code||'|'||l.city,
           'storage://Admin/Private Life/Large City Apartment/Large City Apartment '||l.city||'.png'
           order by l.country_code,l.city
         ) as image_map
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_luxury_residence'
    and a.active=true
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Large City Apartment/Large City Apartment Home Country.png',
    metadata=coalesce(c.metadata,'{}'::jsonb) || jsonb_build_object(
      'city_image_urls',city_images.image_map,
      'image_status','curated',
      'city_set_status','ready',
      'city_image_count',60,
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Large City Apartment',
      'expected_image_storage_path','Private Life/Large City Apartment/Large City Apartment Home Country.png',
      'missing_large_city_images','[]'::jsonb
    ),
    updated_at=now()
from city_images
where c.code='apt_luxury_residence'
  and c.category='apartment';

do $$
declare
  v_map_count integer;
begin
  select count(*)
  into v_map_count
  from public.private_life_asset_catalog c,
       lateral jsonb_each(coalesce(c.metadata->'city_image_urls','{}'::jsonb))
  where c.code='apt_luxury_residence';

  if v_map_count<>60 then
    raise exception 'Large City Apartment image map contains % entries instead of 60.',v_map_count;
  end if;
end;
$$;
