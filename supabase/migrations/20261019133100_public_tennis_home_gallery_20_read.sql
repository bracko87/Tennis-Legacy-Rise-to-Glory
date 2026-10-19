-- Public marketing gallery: permit read/signing of exactly the 20 owner-supplied
-- Tennis Legacy screenshots, without opening the private Admin bucket generally.
-- Only run through the controlled staging -> main release migration workflow.
DROP POLICY IF EXISTS "public_tennis_home_gallery_20_read" ON storage.objects;
CREATE POLICY "public_tennis_home_gallery_20_read"
ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'Admin'
  AND name ~ '^Branding/tennis 0(0[1-9]|1[0-9]|20)\\.png$'
);
