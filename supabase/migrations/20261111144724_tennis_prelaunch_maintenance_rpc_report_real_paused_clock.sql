-- Report the actual paused game clock even when migration notices are disabled.
-- Deployed to Tennis Legacy Supabase 2026-11-11; no gameplay write or registration change.
CREATE OR REPLACE FUNCTION public.get_tennis_public_maintenance_v1()
RETURNS jsonb
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'control_center_private'
AS $function$
SELECT jsonb_build_object(
  'status',c.status,
  'source_season',CASE WHEN c.status='off' THEN null ELSE c.source_season END,
  'target_season',CASE WHEN c.status='off' THEN null ELSE c.target_season END,
  'starts_at',CASE WHEN c.status='off' THEN null ELSE c.starts_at END,
  'planned_reopen_at',CASE WHEN c.status='off' THEN null ELSE c.planned_reopen_at END,
  'estimated_reopen_at',CASE WHEN c.status='off' THEN null ELSE coalesce(c.revised_reopen_at,c.planned_reopen_at) END,
  'preseason_starts_at',CASE WHEN c.status='preseason' THEN c.preseason_starts_at ELSE null END,
  'preseason_ends_at',CASE WHEN c.status='preseason' THEN c.preseason_ends_at ELSE null END,
  'preseason_active',c.status='preseason',
  'game_clock_paused',coalesce((SELECT gc.is_paused FROM public.game_clock gc WHERE gc.id=1),false)
    OR c.status IN('active','extended','preseason'),
  'maintenance_active',c.status IN('active','extended')
    OR (c.status='announced' AND now()>=c.starts_at),
  'announcement_visible',c.status='announced' AND now()<c.starts_at,
  'reopening_delayed',c.status IN('active','extended') AND now()>=coalesce(c.revised_reopen_at,c.planned_reopen_at),
  'notice',CASE WHEN c.status='off' THEN null ELSE left(coalesce(c.notice,''),500) END,
  'checked_at',now()
)
FROM control_center_private.tennis_season_maintenance_control_v1 c WHERE c.id=true
$function$;