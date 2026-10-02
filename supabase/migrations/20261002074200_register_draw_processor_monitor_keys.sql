
insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'process:tournament-draw-publication',
  'Tournament draw processor execution',
  'Tournaments',
  'Run-level telemetry for the primary tournament draw publisher, including partial batch failures.',
  'business_check',null,true,'critical',5,15,false,209
),
(
  'process:tournament-draw-auto-repair',
  'Tournament draw recovery execution',
  'Tournaments',
  'Run-level telemetry for the independent tournament draw recovery processor.',
  'business_check',null,true,'critical',5,15,false,210
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
