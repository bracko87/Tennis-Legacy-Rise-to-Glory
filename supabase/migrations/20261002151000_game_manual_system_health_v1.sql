-- Full Game Manual publication registry + System Health integration.
-- Static front-end assets cannot be introspected directly from Postgres, so this
-- health check validates the published manual contract/version that the deployed
-- UI is expected to expose. Build/deploy health remains responsible for static
-- asset availability.

create table if not exists public.game_manual_runtime_settings (
  singleton_id boolean primary key default true check (singleton_id),
  manual_version text not null,
  source_locale text not null,
  chapter_count integer not null check (chapter_count > 0),
  manual_route text not null,
  help_route text not null,
  pdf_path text not null,
  pdf_download_enabled boolean not null default true,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.game_manual_runtime_settings(
  singleton_id,manual_version,source_locale,chapter_count,
  manual_route,help_route,pdf_path,pdf_download_enabled,is_active
)
values(
  true,'1.0','en',33,
  '/game/manual','/game/help','/manual/Tennis-Legacy-Full-Game-Manual-EN.pdf',true,true
)
on conflict(singleton_id) do update set
  manual_version=excluded.manual_version,
  source_locale=excluded.source_locale,
  chapter_count=excluded.chapter_count,
  manual_route=excluded.manual_route,
  help_route=excluded.help_route,
  pdf_path=excluded.pdf_path,
  pdf_download_enabled=excluded.pdf_download_enabled,
  is_active=true,
  updated_at=now();

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'cron:tennis-game-manual-health-v1',
  'Game Manual publishing health job',
  'Help & Documentation',
  'Runs the Full Game Manual publication contract check every 15 minutes.',
  'cron',
  'tennis-game-manual-health-v1',
  false,
  'warning',
  15,
  45,
  false,
  44
),
(
  'check:game_manual_publishing',
  'Full Game Manual publishing',
  'Help & Documentation',
  'Verifies the active English manual version, chapter count, in-game route, Help Center route and PDF download contract.',
  'business_check',
  null,
  false,
  'warning',
  15,
  45,
  false,
  218
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

create or replace function public.check_game_manual_publishing_health_v1()
returns jsonb
language plpgsql
security definer
set search_path='public','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_settings public.game_manual_runtime_settings%rowtype;
  v_problems text[]:='{}'::text[];
  v_problem_count integer:=0;
  v_details jsonb;
begin
  select * into v_settings
  from public.game_manual_runtime_settings
  where singleton_id=true;

  if v_settings.singleton_id is null then
    v_problems:=array_append(v_problems,'runtime_settings_missing');
  else
    if not v_settings.is_active then v_problems:=array_append(v_problems,'manual_inactive'); end if;
    if v_settings.manual_version<>'1.0' then v_problems:=array_append(v_problems,'unexpected_version'); end if;
    if v_settings.source_locale<>'en' then v_problems:=array_append(v_problems,'source_locale_not_english'); end if;
    if v_settings.chapter_count<33 then v_problems:=array_append(v_problems,'chapter_count_below_expected'); end if;
    if v_settings.manual_route<>'/game/manual' then v_problems:=array_append(v_problems,'manual_route_mismatch'); end if;
    if v_settings.help_route<>'/game/help' then v_problems:=array_append(v_problems,'help_route_mismatch'); end if;
    if v_settings.pdf_path<>'/manual/Tennis-Legacy-Full-Game-Manual-EN.pdf' then v_problems:=array_append(v_problems,'pdf_path_mismatch'); end if;
    if not v_settings.pdf_download_enabled then v_problems:=array_append(v_problems,'pdf_download_disabled'); end if;
  end if;

  v_problem_count:=coalesce(array_length(v_problems,1),0);
  v_details:=jsonb_build_object(
    'manual_version',v_settings.manual_version,
    'source_locale',v_settings.source_locale,
    'chapter_count',v_settings.chapter_count,
    'manual_route',v_settings.manual_route,
    'help_route',v_settings.help_route,
    'pdf_path',v_settings.pdf_path,
    'pdf_download_enabled',v_settings.pdf_download_enabled,
    'is_active',v_settings.is_active,
    'problems',to_jsonb(v_problems)
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:game_manual_publishing',
      'warning',
      'Full Game Manual publishing requires attention',
      format('%s Game Manual publishing configuration issue(s) detected.',v_problem_count),
      'business:game-manual-publishing',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:game-manual-publishing',
      'Full Game Manual publication contract is healthy.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  ) values(
    'check:game_manual_publishing',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_problem_count>0
      then format('%s Game Manual publishing issue(s).',v_problem_count)
      else 'Full Game Manual publishing contract is healthy.'
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
    'check:game_manual_publishing',
    'warning',
    'Game Manual health check failed',
    sqlerrm,
    'business:game-manual-publishing',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message,details
  ) values(
    'check:game_manual_publishing','error',
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    'Full Game Manual health check failed.',sqlerrm,
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
  where jobname='tennis-game-manual-health-v1'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-game-manual-health-v1',
  '7-52/15 * * * *',
  $cron$select public.check_game_manual_publishing_health_v1();$cron$
);

select public.check_game_manual_publishing_health_v1();
