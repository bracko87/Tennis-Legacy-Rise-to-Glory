-- Decouple System Health persistence from Control Center snapshot delivery.
-- Health writes must never fail because telemetry delivery is slow or contended.

drop trigger if exists gcc_live_health_runs on public.system_monitor_runs;
drop trigger if exists gcc_live_health_incidents on public.system_incidents;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='control-center-system-health-snapshot-v1'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'control-center-system-health-snapshot-v1',
  '* * * * *',
  $cron$select control_center_private.push_admin_module_snapshot('system-health');$cron$
);

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values(
  'cron:control-center-system-health-snapshot-v1',
  'Control Center health snapshot delivery',
  'Core',
  'Pushes the System Health snapshot to Game Control Center independently of health-monitor writes.',
  'cron',
  'control-center-system-health-snapshot-v1',
  true,
  'high',
  1,
  5,
  true,
  5
)
on conflict(process_key) do update set
  label=excluded.label,
  category=excluded.category,
  description=excluded.description,
  source_kind=excluded.source_kind,
  source_ref=excluded.source_ref,
  user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,
  expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,
  email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,
  sort_order=excluded.sort_order,
  updated_at=now();
