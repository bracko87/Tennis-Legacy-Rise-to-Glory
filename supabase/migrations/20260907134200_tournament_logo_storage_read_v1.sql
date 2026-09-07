-- Tournament pages refresh private Admin-bucket signed URLs at runtime and can
-- recover an already-uploaded logo when an older series row lost logo_url.
-- Authenticated players therefore need SELECT access to Tournament Logos only.
drop policy if exists tournament_logo_authenticated_read on storage.objects;
create policy tournament_logo_authenticated_read
on storage.objects
for select
to authenticated
using (
  bucket_id='Admin'
  and name like 'Tournament Logos/%'
);
