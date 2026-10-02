-- Point the 19 WTA AI players at the already-supported WTA Avatars path.
-- The binary objects were copied from Admin/WTA AI Profiles to Admin/WTA Avatars.
-- This avoids a separate frontend/storage path for WTA AI portraits.

with portraits(player_id,image_path) as (
  values
  ('90f09c40-af0f-488e-91ed-6cd3cc251621'::uuid,'WTA Avatars/Lejla Hadzic.png'),
  ('d44d8e02-fa1a-4686-8852-d0f2e0157a38'::uuid,'WTA Avatars/Lucy Coleman.png'),
  ('4320c3d9-f92f-4754-b6c6-0d906424606b'::uuid,'WTA Avatars/Nora Solberg.png'),
  ('f2479b22-d405-49f1-aa25-9f56fd9fd435'::uuid,'WTA Avatars/Sanne van Dijk.png'),
  ('86fb317a-dd65-410c-8a4f-fffcd11d7344'::uuid,'WTA Avatars/Brooke Lawson.png'),
  ('b664128a-a6e8-4700-87ce-9eace564460c'::uuid,'WTA Avatars/Camille Lefevre.png'),
  ('766071c5-de47-42a5-b108-77a020110cce'::uuid,'WTA Avatars/Ioana Popescu.png'),
  ('fa17d9df-c2e8-46bb-a8cc-c87972407621'::uuid,'WTA Avatars/Camila Moura.png'),
  ('0fcf3659-f882-4e64-b7ff-32ccebb68ee5'::uuid,'WTA Avatars/Manon Mercier.png'),
  ('39a60500-c14c-48b1-8db7-937d715e1bcf'::uuid,'WTA Avatars/Lucia Acosta.png'),
  ('bdf84f73-3bdf-4c7d-9af4-c37ff9164b26'::uuid,'WTA Avatars/Mio Okada.png'),
  ('8c764e4c-f941-4c1f-82db-336744e0e773'::uuid,'WTA Avatars/Laura Steiner.png'),
  ('f26c7e83-b114-480a-94e1-bd4b393d6063'::uuid,'WTA Avatars/Hannah Palmer.png'),
  ('1a441420-9ef9-45ad-ab53-389d34795939'::uuid,'WTA Avatars/Natalie Sullivan.png'),
  ('dd8a505c-251b-4007-8558-8990c1602392'::uuid,'WTA Avatars/Sophie Lavoie.png'),
  ('6136dbc1-31c3-48d4-9f7a-64d83a8be44e'::uuid,'WTA Avatars/Brooke Foster.png'),
  ('d96f31e4-61d6-4124-bcff-0f06d659f7be'::uuid,'WTA Avatars/Eleni Karalis.png'),
  ('5f03b1b0-4119-47c9-8700-c14d6d08c9fd'::uuid,'WTA Avatars/Martina Lombardi.png'),
  ('20a612f4-5e01-4aec-8294-aead7193e173'::uuid,'WTA Avatars/Manon Garnier.png')
)
update public.players p
set image_path=x.image_path,
    updated_at=now()
from portraits x
where p.id=x.player_id
  and p.world='WTA'
  and p.player_type='ai';

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.players p
  where p.id=any(array[
    '90f09c40-af0f-488e-91ed-6cd3cc251621'::uuid,
    'd44d8e02-fa1a-4686-8852-d0f2e0157a38'::uuid,
    '4320c3d9-f92f-4754-b6c6-0d906424606b'::uuid,
    'f2479b22-d405-49f1-aa25-9f56fd9fd435'::uuid,
    '86fb317a-dd65-410c-8a4f-fffcd11d7344'::uuid,
    'b664128a-a6e8-4700-87ce-9eace564460c'::uuid,
    '766071c5-de47-42a5-b108-77a020110cce'::uuid,
    'fa17d9df-c2e8-46bb-a8cc-c87972407621'::uuid,
    '0fcf3659-f882-4e64-b7ff-32ccebb68ee5'::uuid,
    '39a60500-c14c-48b1-8db7-937d715e1bcf'::uuid,
    'bdf84f73-3bdf-4c7d-9af4-c37ff9164b26'::uuid,
    '8c764e4c-f941-4c1f-82db-336744e0e773'::uuid,
    'f26c7e83-b114-480a-94e1-bd4b393d6063'::uuid,
    '1a441420-9ef9-45ad-ab53-389d34795939'::uuid,
    'dd8a505c-251b-4007-8558-8990c1602392'::uuid,
    '6136dbc1-31c3-48d4-9f7a-64d83a8be44e'::uuid,
    'd96f31e4-61d6-4124-bcff-0f06d659f7be'::uuid,
    '5f03b1b0-4119-47c9-8700-c14d6d08c9fd'::uuid,
    '20a612f4-5e01-4aec-8294-aead7193e173'::uuid
  ])
    and p.image_path like 'WTA Avatars/%'
    and exists(
      select 1
      from storage.objects o
      where o.bucket_id='Admin'
        and o.name=p.image_path
    );

  if v_count<>19 then
    raise exception 'Expected 19 WTA AI portraits on WTA Avatars path, found %.',v_count;
  end if;
end;
$$;

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
    and p.image_path is not null
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
    and p.image_path not like 'WTA Avatars/%';

  select exists(
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_player_avatar_authenticated_read'
      and cmd='SELECT'
      and qual ilike '%WTA Avatars/%'
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
      'Assigned WTA AI profile portraits on WTA Avatars resolve correctly.'
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
      else format('%s assigned WTA AI portrait(s) are healthy on WTA Avatars.',v_assigned)
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
    'check:wta_ai_portraits','warning',
    'WTA AI portrait health check failed',sqlerrm,
    'business:wta-ai-portrait-health',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message,details
  ) values(
    'check:wta_ai_portraits','error',
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    'WTA AI portrait health check failed.',sqlerrm,
    jsonb_build_object('sqlstate',sqlstate)
  );

  return jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
end;
$$;

select public.check_wta_ai_portrait_health_v1();
