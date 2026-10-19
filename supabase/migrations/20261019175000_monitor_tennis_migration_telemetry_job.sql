-- Register Phase-2 migration telemetry with the game's existing System Health watchdog.
-- The watcher observes scheduled delivery; a successful cron invocation is not a
-- substitute for end-to-end HTTP acceptance (verified separately during rollout).
insert into public.system_monitor_processes (
  process_key,label,category,description,
  source_kind,source_ref,user_sensitive,incident_severity,
  expected_interval_minutes,stale_after_minutes,email_alerts_enabled,is_enabled,sort_order
) values (
  'cron:tennis-season-migration-snapshot-v1',
  'Tennis season migration Control Center feed',
  'Core',
  'Publishes authenticated season-readiness, boundary guard, calendar and sponsor snapshots every 5 real minutes to the standalone Game Control Center.',
  'cron','tennis-season-migration-snapshot-v1',true,'high',
  5,15,true,true,225
)
on conflict (process_key) do update
set label=excluded.label,category=excluded.category,description=excluded.description,
    source_kind=excluded.source_kind,source_ref=excluded.source_ref,
    user_sensitive=excluded.user_sensitive,incident_severity=excluded.incident_severity,
    expected_interval_minutes=excluded.expected_interval_minutes,
    stale_after_minutes=excluded.stale_after_minutes,
    email_alerts_enabled=excluded.email_alerts_enabled,
    is_enabled=excluded.is_enabled,
    sort_order=excluded.sort_order,
    updated_at=now();
