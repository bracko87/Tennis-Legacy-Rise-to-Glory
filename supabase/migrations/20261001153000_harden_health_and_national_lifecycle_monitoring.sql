-- Monitor and harden the National Association lifecycle and System Health watchdog.

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values(
  'cron:process-national-association-lifecycle',
  'National association lifecycle',
  'National Team',
  'Advances captain elections, renewal windows and other national-association lifecycle state.',
  'cron',
  'process-national-association-lifecycle',
  true,
  'critical',
  5,
  15,
  true,
  235
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

create or replace function public.sync_system_cron_runs_v1()
returns integer
language plpgsql
security definer
set search_path=public,cron,pg_temp
as $$
declare
  v_count integer:=0;
  r record;
  v_key text;
begin
  insert into public.system_monitor_runs(
    process_key,source_run_id,status,started_at,finished_at,duration_ms,summary,error_message,details
  )
  select
    p.process_key,
    d.runid,
    case
      when d.status='succeeded' then 'success'
      when d.status='failed' then 'error'
      else 'running'
    end,
    d.start_time,
    d.end_time,
    case when d.end_time is not null
      then greatest(0,(extract(epoch from (d.end_time-d.start_time))*1000)::bigint)
      else null
    end,
    case
      when d.status='succeeded' then coalesce(nullif(d.return_message,''),'Completed')
      when d.status='failed' then 'Scheduled process failed'
      else 'Scheduled process is running'
    end,
    case when d.status='failed' then coalesce(d.return_message,'Unknown pg_cron failure') else null end,
    jsonb_build_object('cron_status',d.status,'return_message',d.return_message)
  from cron.job_run_details d
  join cron.job j on j.jobid=d.jobid
  join public.system_monitor_processes p
    on p.source_kind='cron'
   and p.source_ref=j.jobname
   and p.is_enabled
  where d.start_time>=now()-interval '48 hours'
  on conflict(process_key,source_run_id) where source_run_id is not null do update
  set status=excluded.status,
      finished_at=excluded.finished_at,
      duration_ms=excluded.duration_ms,
      summary=excluded.summary,
      error_message=excluded.error_message,
      details=excluded.details
  where system_monitor_runs.status is distinct from excluded.status
     or system_monitor_runs.finished_at is distinct from excluded.finished_at
     or system_monitor_runs.duration_ms is distinct from excluded.duration_ms
     or system_monitor_runs.summary is distinct from excluded.summary
     or system_monitor_runs.error_message is distinct from excluded.error_message
     or system_monitor_runs.details is distinct from excluded.details;

  get diagnostics v_count=row_count;

  for r in
    select distinct on (j.jobname)
      j.jobname,d.runid,d.status,d.return_message,d.start_time,d.end_time,
      p.process_key,p.incident_severity
    from cron.job j
    join public.system_monitor_processes p
      on p.source_kind='cron'
     and p.source_ref=j.jobname
     and p.is_enabled
    left join cron.job_run_details d on d.jobid=j.jobid
    order by j.jobname,d.start_time desc nulls last
  loop
    v_key:=r.process_key;

    if r.runid is null then
      continue;
    elsif r.status='failed' then
      perform public.raise_system_incident_v1(
        v_key,
        r.incident_severity,
        'Scheduled process failed',
        format('%s failed at %s. %s',r.jobname,r.start_time,coalesce(r.return_message,'No return message.')),
        'cron-failure:'||r.jobname,
        jsonb_build_object('job_name',r.jobname,'run_id',r.runid,'return_message',r.return_message,'started_at',r.start_time)
      );
    elsif r.status='succeeded' then
      perform public.resolve_system_incident_by_dedupe_v1(
        'cron-failure:'||r.jobname,
        'The latest scheduled run completed successfully.'
      );
    end if;
  end loop;

  return v_count;
end;
$$;

create or replace function public.check_system_health_watchdog_sentinel_v1()
returns void
language plpgsql
security definer
set search_path=public,cron,pg_temp
as $$
declare
  v_job cron.job%rowtype;
  v_run record;
begin
  select * into v_job
  from cron.job
  where jobname='tennis-system-health-watchdog-v1'
  limit 1;

  if v_job.jobid is null or not coalesce(v_job.active,false) then
    perform public.raise_system_incident_v1(
      'watchdog:system-health',
      'critical',
      'System Health watchdog is missing or disabled',
      'The System Health watchdog cron job is missing or disabled, so game-health incidents may not be detected.',
      'watchdog:sentinel',
      jsonb_build_object('job_name','tennis-system-health-watchdog-v1','active',coalesce(v_job.active,false))
    );
    return;
  end if;

  select d.runid,d.status,d.return_message,d.start_time,d.end_time
  into v_run
  from cron.job_run_details d
  where d.jobid=v_job.jobid
  order by d.start_time desc
  limit 1;

  if v_run.runid is null or v_run.start_time < now()-interval '15 minutes' then
    perform public.raise_system_incident_v1(
      'watchdog:system-health',
      'critical',
      'System Health watchdog is overdue',
      'The System Health watchdog has not started within the last 15 minutes.',
      'watchdog:sentinel',
      jsonb_build_object('job_name',v_job.jobname,'last_start_at',v_run.start_time)
    );
  elsif v_run.status='failed' then
    perform public.raise_system_incident_v1(
      'watchdog:system-health',
      'critical',
      'System Health watchdog is failing',
      format('The latest System Health watchdog run failed at %s. %s',v_run.start_time,coalesce(v_run.return_message,'No return message.')),
      'watchdog:sentinel',
      jsonb_build_object('job_name',v_job.jobname,'run_id',v_run.runid,'return_message',v_run.return_message,'started_at',v_run.start_time)
    );
  elsif v_run.status='succeeded' then
    perform public.resolve_system_incident_by_dedupe_v1(
      'watchdog:sentinel',
      'The System Health watchdog is running successfully again.'
    );
  end if;
end;
$$;

revoke all on function public.check_system_health_watchdog_sentinel_v1() from public,anon,authenticated;
grant execute on function public.check_system_health_watchdog_sentinel_v1() to service_role;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='tennis-system-health-sentinel-v1' limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-system-health-sentinel-v1',
  '*/5 * * * *',
  $cron$select public.check_system_health_watchdog_sentinel_v1();$cron$
);

select public.check_system_health_watchdog_sentinel_v1();
