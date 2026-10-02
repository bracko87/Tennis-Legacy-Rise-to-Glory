-- Align the live Full Game Manual runtime contract with the browser-generated
-- PDF download. The PDF is generated from the same English source content as
-- the in-game manual, preventing a stale static document from drifting behind.

update public.game_manual_runtime_settings
set pdf_path='/game/manual?download=pdf',
    pdf_download_enabled=true,
    updated_at=now()
where singleton_id=true;

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
    if v_settings.pdf_path<>'/game/manual?download=pdf' then v_problems:=array_append(v_problems,'pdf_route_mismatch'); end if;
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
      'check:game_manual_publishing','warning',
      'Full Game Manual publishing requires attention',
      format('%s Game Manual publishing configuration issue(s) detected.',v_problem_count),
      'business:game-manual-publishing',v_details
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
    'check:game_manual_publishing','warning',
    'Game Manual health check failed',sqlerrm,
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

select public.check_game_manual_publishing_health_v1();
