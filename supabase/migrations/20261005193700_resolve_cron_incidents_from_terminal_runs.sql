-- Resolve cron failures against the latest terminal run even when the next run has just started.
CREATE OR REPLACE FUNCTION public.sync_system_cron_runs_v1()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'cron', 'pg_temp'
AS $function$
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

  -- Incident state follows the latest completed run. A run in progress at
  -- this same cron minute must not mask an already successful recovery.
  for r in
    select distinct on (j.jobname)
      j.jobname,d.runid,d.status,d.return_message,d.start_time,d.end_time,
      p.process_key,p.incident_severity
    from cron.job j
    join public.system_monitor_processes p
      on p.source_kind='cron'
     and p.source_ref=j.jobname
     and p.is_enabled
    left join cron.job_run_details d
      on d.jobid=j.jobid and d.status in ('succeeded','failed')
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
$function$
;
