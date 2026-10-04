-- Schedule the static watch-image integrity check so Control Center does not
-- rely on manual execution.

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values(
  'cron:tennis-private-life-watch-image-health-v1',
  'Private Life watch image health schedule',
  'Private Life',
  'Runs the Private Life watch catalog image integrity check every 12 hours.',
  'cron','tennis-private-life-watch-image-health-v1',false,
  'warning',720,1500,false,227
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

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-private-life-watch-image-health-v1'
  limit 1;
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-private-life-watch-image-health-v1',
  '23 */12 * * *',
  $cron$select public.check_private_life_watch_images_v1();$cron$
);

select public.check_private_life_watch_images_v1();
