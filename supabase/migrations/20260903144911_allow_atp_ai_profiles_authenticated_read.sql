alter policy "admin_player_avatar_authenticated_read"
on storage.objects
using (
  bucket_id = 'Admin'
  and (
    name like 'ATP Avatars/%'
    or name like 'WTA Avatars/%'
    or name like 'ATP AI Profils/%'
  )
);
