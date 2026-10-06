-- Publish the prepared Large City Apartment market in all 60 approved cities.
-- City-specific images will be connected in a later migration.
--
-- This migration:
-- 1) validates the prepared 60-city set,
-- 2) activates Large City Apartment availability,
-- 3) makes every approved destination visible in the property marketplace,
-- 4) records the image folder/status for the upcoming image pass,
-- 5) pre-authorizes authenticated reads from the future image folder.

do $$
declare
  v_count integer;
begin
  select count(*)
  into v_count
  from public.private_life_property_catalog_availability
  where catalog_code='apt_luxury_residence';

  if v_count <> 60 then
    raise exception 'Expected 60 Large City Apartment destinations, found %.', v_count;
  end if;
end;
$$;

update public.private_life_property_catalog_availability
set active=true,
    updated_at=now()
where catalog_code='apt_luxury_residence';

update public.private_life_property_locations l
set marketplace_enabled=true,
    active=true,
    updated_at=now()
where exists (
  select 1
  from public.private_life_property_catalog_availability a
  where a.location_code=l.code
    and a.catalog_code='apt_luxury_residence'
    and a.active=true
);

update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      - 'city_image_urls'
      - 'missing_standard_city_images'
      || jsonb_build_object(
        'city_set_status','database_ready_waiting_for_images',
        'city_set_version','large_city_apartment_v1',
        'planned_city_count',60,
        'image_status','placeholder',
        'image_storage_bucket','Admin',
        'image_storage_folder','Private Life/Large City Apartment',
        'expected_image_storage_path','Private Life/Large City Apartment/Large City Apartment Home Country.png'
      ),
    updated_at=now()
where c.code='apt_luxury_residence'
  and c.category='apartment';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_large_city_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_large_city_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Large City Apartment/%'
      );
  end if;
end $$;

do $$
declare
  v_hidden integer;
begin
  select count(*)
  into v_hidden
  from public.private_life_property_catalog_availability a
  join public.private_life_property_locations l
    on l.code=a.location_code
  where a.catalog_code='apt_luxury_residence'
    and (a.active=false or l.active=false or l.marketplace_enabled=false);

  if v_hidden <> 0 then
    raise exception 'Large City Apartment still has % hidden destination(s).', v_hidden;
  end if;
end;
$$;
