-- Allow signed image URLs for curated Private Life collectible images.
-- The Admin bucket stays private; only authenticated users can read this folder.
create policy "admin_private_life_collectibles_authenticated_read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'Admin'
  and name like 'PL Collectibles/%'
);
