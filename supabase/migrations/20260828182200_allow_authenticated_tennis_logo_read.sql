create policy admin_branding_tennis_logo_authenticated_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'Admin'
  and name = 'Branding/01e18414-8243-48da-b6b7-6d758a3d59f9.png'
);
