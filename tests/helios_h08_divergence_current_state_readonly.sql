-- Helios H08: metadata ONLY. No user, billing, staff, or game rows.
-- Current-state evidence does NOT approve historical migration replay.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout='30s';
DO $audit$
DECLARE
 v_premium char;
 v_disk char;
 v_training boolean;
 v_avatar_policy boolean;
 v_gallery_policy boolean;
BEGIN
 SELECT p.provolatile INTO v_premium
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='get_premium_statistics_intelligence_v1'
   AND p.pronargs=2;
 SELECT p.provolatile INTO v_disk
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='control_center_disk_capacity_bytes_v1'
   AND p.pronargs=0;
 SELECT EXISTS(
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='check_training_camp_health_v1'
 ) INTO v_training;
 SELECT EXISTS(
  SELECT 1 FROM pg_policies WHERE schemaname='storage'
   AND tablename='objects' AND policyname='admin_player_avatar_authenticated_read'
 ) INTO v_avatar_policy;
 SELECT EXISTS(
  SELECT 1 FROM pg_policies WHERE schemaname='storage'
   AND tablename='objects' AND policyname='public_tennis_home_gallery_20_read'
 ) INTO v_gallery_policy;
 IF v_premium IS DISTINCT FROM 'v' OR v_disk IS DISTINCT FROM 's'
    OR v_training IS DISTINCT FROM true
    OR v_avatar_policy IS DISTINCT FROM true
    OR v_gallery_policy IS DISTINCT FROM true
 THEN RAISE EXCEPTION
    'Helios divergence current-state drift: premium=%, disk=%, training=%, avatar=%, gallery=%',
    v_premium,v_disk,v_training,v_avatar_policy,v_gallery_policy;
 END IF;
 RAISE NOTICE 'PASS current-state metadata for 4 migration follow-ups and 2 storage policies. All nine historical replay blockers remain REVIEW_REQUIRED.';
END;
$audit$;
ROLLBACK;
