-- Public marketing gallery: permit read/signing of exactly the 20 owner-supplied
-- Tennis Legacy screenshots without opening the private Admin bucket generally.
-- Deliberately unapplied during staging development; include in a reviewed release.
DROP POLICY IF EXISTS "public_tennis_home_gallery_20_read" ON storage.objects;
CREATE POLICY "public_tennis_home_gallery_20_read"
ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'Admin'
  AND name IN (
    'Branding/tennis 001.png',
    'Branding/tennis 002.png',
    'Branding/tennis 003.png',
    'Branding/tennis 004.png',
    'Branding/tennis 005.png',
    'Branding/tennis 006.png',
    'Branding/tennis 007.png',
    'Branding/tennis 008.png',
    'Branding/tennis 009.png',
    'Branding/tennis 010.png',
    'Branding/tennis 011.png',
    'Branding/tennis 012.png',
    'Branding/tennis 013.png',
    'Branding/tennis 014.png',
    'Branding/tennis 015.png',
    'Branding/tennis 016.png',
    'Branding/tennis 017.png',
    'Branding/tennis 018.png',
    'Branding/tennis 019.png',
    'Branding/tennis 020.png'
  )
);
