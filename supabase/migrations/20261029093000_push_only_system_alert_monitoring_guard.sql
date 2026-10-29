-- Tennis Legacy: permanent push-only system-incident monitoring correction.
-- Intentional owner policy (2026-10-27): System incidents use Control Center
-- push notifications, never system-incident emails. Gameplay emails are unchanged.
-- Prevent false "cron missing/disabled" incidents for those deliberately parked
-- jobs without disabling the real watchdog or the direct Control Center push trigger.

DO $guard$
DECLARE
  v_sentinel_job bigint;
BEGIN
  IF (SELECT count(*) FROM public.system_monitor_processes
      WHERE process_key IN (
        'cron:tennis-system-alert-email-dispatch-v1',
        'cron:tennis-critical-incident-reminders-v1'
      ) AND source_kind = 'cron') <> 2
  THEN
    RAISE EXCEPTION 'Expected both incident-email process registry entries';
  END IF;

  -- Fail closed: never quietly run or re-enable incident email dispatch.
  IF EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname IN (
      'tennis-system-alert-email-dispatch-v1',
      'tennis-critical-incident-reminders-v1'
    ) AND active
  ) THEN
    RAISE EXCEPTION 'Incident-email cron unexpectedly active: review before fixing monitoring';
  END IF;

  UPDATE public.system_monitor_processes
     SET is_enabled = false,
         email_alerts_enabled = false,
         updated_at = clock_timestamp()
   WHERE process_key IN (
     'cron:tennis-system-alert-email-dispatch-v1',
     'cron:tennis-critical-incident-reminders-v1'
   );

  -- Offset the sentinel so it checks *after* the watchdog's five-minute run,
  -- instead of racing it at the same minute and leaving an old alert open.
  SELECT jobid INTO v_sentinel_job
    FROM cron.job
   WHERE jobname = 'tennis-system-health-sentinel-v1' AND active
   LIMIT 1;
  IF v_sentinel_job IS NULL THEN
    RAISE EXCEPTION 'Active system-health sentinel cron not found';
  END IF;
  PERFORM cron.alter_job(
    job_id => v_sentinel_job,
    schedule => '2-57/5 * * * *'
  );
END
$guard$;

-- An independent guard makes accidental future re-registration of paused
-- incident-email processes fail visibly, rather than silently restoring
-- misleading monitors or changing the owner-selected notification channel.
DO $policy$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.system_monitor_processes'::regclass
      AND conname = 'tennis_incident_email_push_only_monitor_guard'
  ) THEN
    ALTER TABLE public.system_monitor_processes
      ADD CONSTRAINT tennis_incident_email_push_only_monitor_guard CHECK (
        source_ref NOT IN (
          'tennis-system-alert-email-dispatch-v1',
          'tennis-critical-incident-reminders-v1'
        )
        OR (is_enabled = false AND email_alerts_enabled = false)
      );
  END IF;
END
$policy$;

-- The old sentinel reads the newest pg_cron row, frequently still 'running'
-- because both jobs previously fired at the same minute. This version also
-- checks the most recent *completed* run while preserving failure/staleness
-- detection, so resolved outages clear and actual failures still alert.
CREATE OR REPLACE FUNCTION public.check_system_health_watchdog_sentinel_v1()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'cron', 'pg_temp'
AS $sentinel$
DECLARE
  v_job cron.job%ROWTYPE;
  v_latest record;
  v_completed record;
BEGIN
  SELECT * INTO v_job
    FROM cron.job
   WHERE jobname = 'tennis-system-health-watchdog-v1'
   LIMIT 1;

  IF v_job.jobid IS NULL OR NOT coalesce(v_job.active, false) THEN
    PERFORM public.raise_system_incident_v1(
      'watchdog:system-health',
      'critical',
      'System Health watchdog is missing or disabled',
      'The System Health watchdog cron job is missing or disabled, so game-health incidents may not be detected.',
      'watchdog:sentinel',
      jsonb_build_object('job_name', 'tennis-system-health-watchdog-v1', 'active', coalesce(v_job.active, false))
    );
    RETURN;
  END IF;

  SELECT d.runid, d.status, d.return_message, d.start_time, d.end_time
    INTO v_latest
    FROM cron.job_run_details d
   WHERE d.jobid = v_job.jobid
   ORDER BY d.start_time DESC, d.runid DESC
   LIMIT 1;

  -- A missing, stalled or stale run must still produce a real incident.
  IF v_latest.runid IS NULL OR v_latest.start_time < now() - interval '15 minutes' THEN
    PERFORM public.raise_system_incident_v1(
      'watchdog:system-health',
      'critical',
      'System Health watchdog is overdue',
      'The System Health watchdog has not started within the last 15 minutes.',
      'watchdog:sentinel',
      jsonb_build_object('job_name', v_job.jobname, 'last_start_at', v_latest.start_time)
    );
    RETURN;
  END IF;

  -- The newest row may be "running" at the sentinel's start. Look at the
  -- newest completed result instead of leaving an old failure open forever.
  SELECT d.runid, d.status, d.return_message, d.start_time, d.end_time
    INTO v_completed
    FROM cron.job_run_details d
   WHERE d.jobid = v_job.jobid
     AND d.status IN ('succeeded', 'failed')
   ORDER BY d.start_time DESC, d.runid DESC
   LIMIT 1;

  IF v_completed.runid IS NULL THEN
    -- First execution still running: neither fake success nor fake failure.
    RETURN;
  ELSIF v_completed.status = 'failed' THEN
    PERFORM public.raise_system_incident_v1(
      'watchdog:system-health',
      'critical',
      'System Health watchdog is failing',
      format('The latest completed System Health watchdog run failed at %s. %s',
             v_completed.start_time, coalesce(v_completed.return_message, 'No return message.')),
      'watchdog:sentinel',
      jsonb_build_object('job_name', v_job.jobname,
                         'run_id', v_completed.runid,
                         'return_message', v_completed.return_message,
                         'started_at', v_completed.start_time)
    );
  ELSE
    PERFORM public.resolve_system_incident_by_dedupe_v1(
      'watchdog:sentinel',
      'The System Health watchdog has completed a successful run.'
    );
  END IF;
END
$sentinel$;

-- Validation/invariant checks. Do NOT treat paused email transport as degraded
-- and do NOT touch the independently enabled system incident -> GCC push trigger.
DO $verify$
BEGIN
  IF (SELECT count(*) FROM public.system_monitor_processes
      WHERE process_key IN (
        'cron:tennis-system-alert-email-dispatch-v1',
        'cron:tennis-critical-incident-reminders-v1'
      ) AND is_enabled = false AND email_alerts_enabled = false) <> 2 THEN
    RAISE EXCEPTION 'Push-only process-monitoring invariant failed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM cron.job
     WHERE jobname = 'tennis-system-health-watchdog-v1' AND active
  ) THEN
    RAISE EXCEPTION 'Real system watchdog is not active';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid = 'public.system_incidents'::regclass
      AND tgname = 'gcc_direct_system_issue_push_v1'
      AND tgenabled <> 'D'
  ) THEN
    RAISE EXCEPTION 'Independent Control Center push trigger is missing or disabled';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname = 'tennis-system-health-sentinel-v1'
      AND active AND schedule = '2-57/5 * * * *'
  ) THEN
    RAISE EXCEPTION 'Sentinel schedule did not move off the watchdog tick';
  END IF;
END
$verify$;
