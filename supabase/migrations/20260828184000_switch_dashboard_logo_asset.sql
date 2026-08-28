drop policy if exists admin_branding_tennis_logo_authenticated_read on storage.objects;

create policy admin_branding_tennis_logo_authenticated_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'Admin'
  and name = 'Branding/logo 333.png'
);
