-- Publish the curated Standard City Apartment market after all 65 city images
-- were uploaded to the Admin storage bucket.
--
-- The earlier curated-city restriction intentionally kept locations visible only
-- when Compact City Flat or One-Bedroom Apartment was available. That left 36
-- Standard City Apartment destinations hidden even after their own availability
-- rows were activated. This migration makes the Standard City Apartment city set
-- a first-class marketplace set and records the city-specific image mapping.

do $$
declare
  v_count integer;
begin
  select count(*)
  into v_count
  from public.private_life_property_catalog_availability
  where catalog_code='apt_modern_residence';

  if v_count <> 65 then
    raise exception 'Expected 65 Standard City Apartment destinations, found %.', v_count;
  end if;
end;
$$;

-- The approved set is already locked by
-- 20261006114500_lock_standard_city_apartment_market_v1.sql.
update public.private_life_property_catalog_availability
set active=true,
    updated_at=now()
where catalog_code='apt_modern_residence';

-- A location must itself be a marketplace destination or the dashboard RPC
-- excludes it before the client can inspect available_apartment_codes.
update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_modern_residence'
    and a.active=true
);

with city_images as (
  select jsonb_object_agg(
           l.country_code || '|' || l.city,
           'storage://Admin/Private Life/Standard City Apartment/Standard City Apartment ' || l.city || '.png'
           order by l.country_code,l.city
         ) as image_map
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_modern_residence'
    and a.active=true
)
update public.private_life_asset_catalog c
set image_url='storage://Admin/Private Life/Standard City Apartment/Standard City Apartment Home Country.png',
    metadata=coalesce(c.metadata,'{}'::jsonb) || jsonb_build_object(
      'city_image_urls',city_images.image_map,
      'image_status','curated',
      'city_set_status','ready',
      'city_set_version','standard_city_apartment_v1',
      'planned_city_count',65,
      'image_storage_bucket','Admin',
      'image_storage_folder','Private Life/Standard City Apartment',
      'expected_image_storage_path','Private Life/Standard City Apartment/Standard City Apartment Home Country.png',
      'missing_standard_city_images','[]'::jsonb
    ),
    updated_at=now()
from city_images
where c.code='apt_modern_residence'
  and c.category='apartment';

-- Regression guard: every Standard City Apartment destination must now be both
-- available for this category and visible as a marketplace location.
do $$
declare
  v_hidden integer;
begin
  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_modern_residence'
    and (a.active=false or l.active=false or l.marketplace_enabled=false);

  if v_hidden <> 0 then
    raise exception 'Standard City Apartment still has % hidden destination(s).', v_hidden;
  end if;
end;
$$;
