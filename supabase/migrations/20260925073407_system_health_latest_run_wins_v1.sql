
create or replace function public.system_monitor_cron_field_matches_v1(
  p_field text,
  p_value integer,
  p_min integer,
  p_max integer
)
returns boolean
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare
  v_part text;
  v_a integer;
  v_b integer;
  v_step integer;
begin
  if p_field is null or btrim(p_field)='' then return false; end if;

  foreach v_part in array string_to_array(p_field,',') loop
    v_part:=btrim(v_part);

    if v_part='*' then return true; end if;

    if v_part ~ '^\*/[0-9]+$' then
      v_step:=split_part(v_part,'/',2)::integer;
      if v_step>0 and mod(p_value-p_min,v_step)=0 then return true; end if;
      continue;
    end if;

    if v_part ~ '^[0-9]+-[0-9]+$' then
      v_a:=split_part(v_part,'-',1)::integer;
      v_b:=split_part(v_part,'-',2)::integer;
      if p_value between v_a and v_b then return true; end if;
      continue;
    end if;

    if v_part ~ '^[0-9]+$' then
      v_a:=v_part::integer;
      if v_a between p_min and p_max and p_value=v_a then return true; end if;
      if p_max=6 and v_a=7 and p_value=0 then return true; end if;
    end if;
  end loop;

  return false;
end;
$$;

create or replace function public.system_monitor_cron_matches_at_v1(
  p_schedule text,
  p_at timestamptz
)
returns boolean
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare
  v_parts text[];
  v_dow integer;
begin
  v_parts:=regexp_split_to_array(btrim(p_schedule),'\s+');
  if coalesce(array_length(v_parts,1),0)<>5 then
    return false;
  end if;

  v_dow:=extract(dow from p_at at time zone 'UTC')::integer;

  return
    public.system_monitor_cron_field_matches_v1(v_parts[1],extract(minute from p_at at time zone 'UTC')::integer,0,59)
    and public.system_monitor_cron_field_matches_v1(v_parts[2],extract(hour from p_at at time zone 'UTC')::integer,0,23)
    and public.system_monitor_cron_field_matches_v1(v_parts[3],extract(day from p_at at time zone 'UTC')::integer,1,31)
    and public.system_monitor_cron_field_matches_v1(v_parts[4],extract(month from p_at at time zone 'UTC')::integer,1,12)
    and public.system_monitor_cron_field_matches_v1(v_parts[5],v_dow,0,6);
end;
$$;

create or replace function public.system_monitor_cron_missed_threshold_v1(
  p_schedule text,
  p_last_run_at timestamptz,
  p_expected_interval_minutes integer,
  p_stale_after_minutes integer,
  p_now timestamptz default now()
)
returns boolean
language plpgsql
stable
set search_path=public,pg_temp
as $$
declare
  v_required integer;
  v_since timestamptz;
  v_count integer;
begin
  if p_stale_after_minutes is null or p_stale_after_minutes<=0 then return false; end if;
  if p_expected_interval_minutes is null or p_expected_interval_minutes<=0 then
    p_expected_interval_minutes:=p_stale_after_minutes;
  end if;

  v_required:=greatest(1,ceil(p_stale_after_minutes::numeric/p_expected_interval_minutes::numeric)::integer);

  v_since:=greatest(
    coalesce(date_trunc('minute',p_last_run_at)+interval '1 minute',p_now-interval '7 days'),
    p_now-interval '7 days'
  );

  select count(*)::integer
  into v_count
  from generate_series(
    date_trunc('minute',v_since),
    date_trunc('minute',p_now),
    interval '1 minute'
  ) g(ts)
  where public.system_monitor_cron_matches_at_v1(p_schedule,g.ts)
  limit v_required;

  return coalesce(v_count,0)>=v_required;
end;
$$;

create or replace function public.sync_system_cron_runs_v1()
returns integer
language plpgsql
security definer
set search_path=public,cron,pg_temp
as $$
declare
  r record;
  p record;
  v_key text;
  v_count integer:=0;
  v_latest record;
begin
  -- Persist execution history only. Old failures remain visible in Process Logs.
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
  end loop;

  -- Active incident state comes only from the newest terminal execution.
  for p in
    select process_key,source_ref,incident_severity
    from public.system_monitor_processes
    where is_enabled and source_kind='cron'
  loop
    v_latest:=null;

    select d.runid,d.status,d.return_message,d.start_time,d.end_time
    into v_latest
    from cron.job_run_details d
    join cron.job j on j.jobid=d.jobid
    where j.jobname=p.source_ref
      and d.status in ('succeeded','failed')
    order by d.start_time desc,d.runid desc
    limit 1;

    if v_latest.runid is null then
      continue;
    end if;

    if v_latest.status='failed' then
      perform public.raise_system_incident_v1(
        p.process_key,
        p.incident_severity,
        'Scheduled process failed',
        format('%s failed at %s. %s',p.source_ref,v_latest.start_time,coalesce(v_latest.return_message,'No return message.')),
        'cron-failure:'||p.source_ref,
        jsonb_build_object(
          'job_name',p.source_ref,
          'run_id',v_latest.runid,
          'return_message',v_latest.return_message,
          'started_at',v_latest.start_time
        )
      );
    else
      perform public.resolve_system_incident_by_dedupe_v1(
        'cron-failure:'||p.source_ref,
        'A newer scheduled run completed successfully.'
      );
    end if;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.system_monitor_cron_field_matches_v1(text,integer,integer,integer) from public,anon,authenticated;
revoke all on function public.system_monitor_cron_matches_at_v1(text,timestamptz) from public,anon,authenticated;
revoke all on function public.system_monitor_cron_missed_threshold_v1(text,timestamptz,integer,integer,timestamptz) from public,anon,authenticated;
revoke all on function public.sync_system_cron_runs_v1() from public,anon,authenticated;
