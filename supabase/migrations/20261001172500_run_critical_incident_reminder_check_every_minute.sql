update public.system_monitor_processes
set expected_interval_minutes=1,
    stale_after_minutes=5,
    updated_at=now()
where process_key='cron:tennis-critical-incident-reminders-v1';

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-critical-incident-reminders-v1'
  limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-critical-incident-reminders-v1',
  '* * * * *',
  $cron$select public.queue_open_critical_incident_reminders_v1();$cron$
);
