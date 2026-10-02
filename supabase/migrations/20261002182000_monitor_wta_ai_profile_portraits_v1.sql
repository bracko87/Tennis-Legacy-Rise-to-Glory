-- Monitor WTA AI portrait references stored in the private Admin bucket.

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'cron:tennis-wta-ai-portrait-health-v1',
  'WTA AI portrait health job',
  'Players',
  'Checks WTA AI portrait references against Admin storage.',
  'cron',
  'tennis-wta-ai-portrait-health-v1',
  false,
  'warning',
  30,
  90,
  false,
  45
),
(
  'check:wta_ai_portraits',
  'WTA AI profile portraits',
  'Players',
  'Verifies every assigned WTA AI portrait path resolves to an object in the private Admin storage bucket.',
  'business_check',
  null,
  false,
  'warning',
  30,
  90,
  false,
  219
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

create or replace function public.check_wta_ai_portrait_health_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','storage','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_assigned integer:=0;
  v_missing integer:=0;
  v_bad_paths integer:=0;
  v_problem_count integer:=0;
  v_details jsonb;
begin
  select count(*) into v_assigned
  from public.players
  where world='WTA'
    and player_type='ai'
    and image_path is not null;

  select count(*) into v_missing
  from public.players p
  where p.world='WTA'
    and p.player_type='ai'
    and p.image_path like 'WTA AI Profiles/%'
    and not exists(
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name=p.image_path
    );

  select count(*) into v_bad_paths
  from public.players p
  where p.world='WTA'
    and p.player_type='ai'
    and p.image_path is not null
    and p.image_path not like 'WTA AI Profiles/%';

  v_problem_count:=v_missing+v_bad_paths;
  v_details:=jsonb_build_object(
    'assigned_wta_ai_portraits',v_assigned,
    'missing_storage_objects',v_missing,
    'unexpected_portrait_paths',v_bad_paths,
    'problem_count',v_problem_count
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:wta_ai_portraits',
      'warning',
      'WTA AI profile portraits require attention',
      format('%s WTA AI portrait integrity issue(s) detected.',v_problem_count),
      'business:wta-ai-portrait-health',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:wta-ai-portrait-health',
      'Assigned WTA AI profile portraits resolve correctly.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:wta_ai_portraits',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s WTA AI portrait integrity issue(s).',v_problem_count)
      else format('%s assigned WTA AI portrait(s) are healthy.',v_assigned)
    end,
    v_details
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'problems',v_problem_count,
    'details',v_details
  );
exception when others then
  perform public.raise_system_incident_v1(
    'check:wta_ai_portraits',
    'warning',
    'WTA AI portrait health check failed',
    sqlerrm,
    'business:wta-ai-portrait-health',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message,details
  ) values(
    'check:wta_ai_portraits','error',
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    'WTA AI portrait health check failed.',
    sqlerrm,
    jsonb_build_object('sqlstate',sqlstate)
  );

  return jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
end;
$$;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-wta-ai-portrait-health-v1'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-wta-ai-portrait-health-v1',
  '11,41 * * * *',
  $cron$select public.check_wta_ai_portrait_health_v1();$cron$
);

select public.check_wta_ai_portrait_health_v1();
