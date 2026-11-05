-- Schedule the existing jewelry image integrity routine for continuous Game Control Center coverage.
-- This is metadata-only validation; it does not replace or regenerate images.
-- Its monitor remains push-only, in line with Tennis Legacy's notification policy.

DO $schedule$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname='tennis-private-life-jewelry-image-health-v1'
  ) THEN
    PERFORM cron.schedule(
      'tennis-private-life-jewelry-image-health-v1',
      '31 */12 * * *',
      $job$select public.check_private_life_jewelry_images_v1();$job$
    );
  ELSIF NOT EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname='tennis-private-life-jewelry-image-health-v1'
      AND active AND schedule='31 */12 * * *'
  ) THEN
    RAISE EXCEPTION 'Existing jewelry image health schedule requires review';
  END IF;
END
$schedule$;

INSERT INTO public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,
  user_sensitive,incident_severity,expected_interval_minutes,
  stale_after_minutes,email_alerts_enabled,is_enabled,sort_order
)
VALUES (
  'cron:tennis-private-life-jewelry-image-health-v1',
  'Private Life jewelry image health schedule',
  'Private Life',
  'Checks all active jewelry storage images and placeholders every 12 hours.',
  'cron',
  'tennis-private-life-jewelry-image-health-v1',
  false,'warning',720,1500,false,true,228
)
ON CONFLICT(process_key) DO UPDATE SET
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  is_enabled=true,
  email_alerts_enabled=false,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  updated_at=clock_timestamp();
