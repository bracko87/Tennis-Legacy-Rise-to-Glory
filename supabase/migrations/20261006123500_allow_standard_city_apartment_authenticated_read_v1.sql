-- Allow authenticated Tennis Legacy players to read the curated
-- Standard City Apartment images from the private Admin bucket.
--
-- The frontend resolves storage:// image references by calling createSignedUrl().
-- Because the Admin bucket is private, the authenticated role needs SELECT access
-- to this exact folder on storage.objects before a signed URL can be created.

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_standard_city_apartment_authenticated_read'
  ) then
    create policy "admin_private_life_standard_city_apartment_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Standard City Apartment/%'
      );
  end if;
end $$;
