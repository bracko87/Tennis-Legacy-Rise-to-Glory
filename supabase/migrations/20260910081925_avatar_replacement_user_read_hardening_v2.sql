revoke select on public.avatar_replacement_requests from authenticated;

grant select (
  id,
  user_id,
  player_id,
  submission_type,
  original_file_name,
  reason,
  details,
  jersey_type,
  jersey_colors,
  appearance_instructions,
  status,
  review_image_path,
  admin_public_message,
  user_revision_message,
  revision_count,
  ready_for_review_at,
  completed_at,
  rejected_at,
  reference_delete_after,
  reference_deleted_at,
  created_at,
  updated_at
) on public.avatar_replacement_requests to authenticated;
