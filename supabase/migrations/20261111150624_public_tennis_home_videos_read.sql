-- The Admin storage bucket remains private. Only these two owner-approved
-- promotional MP4s may be signed and played by homepage visitors.
CREATE POLICY "public_tennis_home_videos_read"
ON storage.objects FOR SELECT TO anon, authenticated
USING (
  bucket_id = 'Admin'
  AND name IN (
    'Branding/Tennis Legacy Rise to Glory  Official Intro Trailer.mp4',
    'Branding/Tennis Legacy Rise to Glory  Official Gameplay Preview.mp4'
  )
);
