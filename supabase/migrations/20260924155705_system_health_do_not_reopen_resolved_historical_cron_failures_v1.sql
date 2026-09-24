CREATE OR REPLACE FUNCTION public.sync_system_cron_runs_v1()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'cron', 'pg_temp'
AS $function$
declare
  r record;
  v_key text;
  v_count integer:=0;
begin
  for r in
    select j.jobname,d.runid,d.status,d.return_message,d.start_time,d.end_time
    from cron.job_run_details d
    join cron.job j on j.jobid=d.jobid
    where d.start_time>=now()-interval '48 hours'
    order by d.start_time
  loop
    v_key:='cron:'||r.jobname;

    if not exists(select 1 from public.system_monitor_processes where process_key=v_key) then
      continue;
    end if;

    insert into public.system_monitor_runs(
      process_key,source_run_id,status,started_at,finished_at,duration_ms,summary,error_message,details
    )
    values(
      v_key,
      r.runid,
      case when r.status='succeeded' then 'success' when r.status='failed' then 'error' else 'running' end,
      r.start_time,
      r.end_time,
      case when r.end_time is not null then greatest(0,(extract(epoch from (r.end_time-r.start_time))*1000)::bigint) else null end,
      case
        when r.status='succeeded' then coalesce(nullif(r.return_message,''),'Completed')
        when r.status='failed' then 'Scheduled process failed'
        else 'Scheduled process is running'
      end,
      case when r.status='failed' then coalesce(r.return_message,'Unknown pg_cron failure') else null end,
      jsonb_build_object('cron_status',r.status,'return_message',r.return_message)
    )
    on conflict(process_key,source_run_id) where source_run_id is not null do update
    set status=excluded.status,
        finished_at=excluded.finished_at,
        duration_ms=excluded.duration_ms,
        summary=excluded.summary,
        error_message=excluded.error_message,
        details=excluded.details;

    if found then v_count:=v_count+1; end if;

    if r.status='failed' then
      if not exists(
        select 1
        from public.system_incidents i
        where i.dedupe_key='cron-failure:'||r.jobname
          and i.status='resolved'
          and i.resolved_at is not null
          and i.resolved_at>=r.start_time
      ) then
        perform public.raise_system_incident_v1(
          v_key,
          (select incident_severity from public.system_monitor_processes where process_key=v_key),
          'Scheduled process failed',
          format('%s failed at %s. %s',r.jobname,r.start_time,coalesce(r.return_message,'No return message.')),
          'cron-failure:'||r.jobname,
          jsonb_build_object('job_name',r.jobname,'run_id',r.runid,'return_message',r.return_message,'started_at',r.start_time)
        );
      end if;
    elsif r.status='succeeded' then
      perform public.resolve_system_incident_by_dedupe_v1('cron-failure:'||r.jobname,'A later scheduled run completed successfully.');
    end if;
  end loop;

  return v_count;
end;
$function$;

select public.resolve_system_incident_by_dedupe_v1(
  'cron-failure:tennis_legacy_ai_training_progression',
  'AI training health guard fixed. A full current-day batch completed successfully with medically restricted players skipped rather than aborting the batch.'
);

select public.run_system_health_watchdog_v1();