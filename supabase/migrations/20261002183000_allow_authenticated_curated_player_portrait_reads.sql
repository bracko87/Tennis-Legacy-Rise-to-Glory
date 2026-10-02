-- Allow authenticated Tennis Legacy players to request signed URLs for
-- curated player portraits stored in the private Admin bucket.
-- This does NOT expose the rest of the Admin bucket.

drop policy if exists "Authenticated users can read curated player portraits" on storage.objects;

drop policy if exists admin_player_avatar_authenticated_read on storage.objects;

create policy admin_player_avatar_authenticated_read
on storage.objects
for select
to authenticated
using (
  bucket_id='Admin'
  and (
    name like 'ATP Avatars/%'
    or name like 'WTA Avatars/%'
    or name like 'ATP AI Profils/%'
    or name like 'WTA AI Profiles/%'
  )
);

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
  v_policy_present boolean:=false;
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

  select exists(
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_player_avatar_authenticated_read'
      and cmd='SELECT'
      and qual ilike '%WTA AI Profiles/%'
  ) into v_policy_present;

  v_problem_count:=v_missing+v_bad_paths+case when v_policy_present then 0 else 1 end;

  v_details:=jsonb_build_object(
    'assigned_wta_ai_portraits',v_assigned,
    'missing_storage_objects',v_missing,
    'unexpected_portrait_paths',v_bad_paths,
    'authenticated_storage_policy_present',v_policy_present,
    'problem_count',v_problem_count
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:wta_ai_portraits',
      'warning',
      'WTA AI profile portraits require attention',
      format('%s WTA AI portrait integrity/access issue(s) detected.',v_problem_count),
      'business:wta-ai-portrait-health',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:wta-ai-portrait-health',
      'Assigned WTA AI profile portraits and authenticated storage access are healthy.'
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
      then format('%s WTA AI portrait integrity/access issue(s).',v_problem_count)
      else format('%s assigned WTA AI portrait(s) and storage access are healthy.',v_assigned)
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

select public.check_wta_ai_portrait_health_v1();
