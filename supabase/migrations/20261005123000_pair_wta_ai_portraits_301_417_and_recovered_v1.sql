-- Pair newly uploaded WTA AI portraits by safe filename/player-name matches.
-- Uses stable Admin storage object paths, never the expiring signed URLs.
-- Also recovers previously missing older portraits that now exist in storage.

with portrait_objects as (
  select
    o.name as image_path,
    regexp_replace(
      regexp_replace(o.name,'^WTA AI Profiles/',''),
      '\.[^.]+$',''
    ) as basename
  from storage.objects o
  where o.bucket_id='Admin'
    and o.name like 'WTA AI Profiles/%'
)
update public.players p
set image_path=o.image_path,
    updated_at=now()
from portrait_objects o
where p.world='WTA'
  and p.player_type='ai'
  and p.image_path is null
  and lower(p.first_name||' '||p.last_name)=lower(o.basename);

-- Safe transliteration-only filename differences. These are exact same names
-- with diacritics removed in the uploaded storage filename.
with transliterations(player_name,image_path) as (
  values
    ('Freyja Magnúsdóttir','WTA AI Profiles/Freyja Magnusdottir.png'),
    ('Aïssatou Ndiaye','WTA AI Profiles/Aissatou Ndiaye.png'),
    ('Sara Jónsdóttir','WTA AI Profiles/Sara Jonsdottir.png'),
    ('Austėja Kazlauskaitė','WTA AI Profiles/Austeja Kazlauskaite.png'),
    ('Lucía Benítez','WTA AI Profiles/Lucia Benitez.png'),
    ('Aminata Traoré','WTA AI Profiles/Aminata Traore.png'),
    ('Milica Vukčević','WTA AI Profiles/Milica Vukcevic.png'),
    ('Elín Sigurðardóttir','WTA AI Profiles/Elin Sigurardottir.png')
)
update public.players p
set image_path=t.image_path,
    updated_at=now()
from transliterations t
where p.world='WTA'
  and p.player_type='ai'
  and p.image_path is null
  and lower(p.first_name||' '||p.last_name)=lower(t.player_name)
  and exists(
    select 1
    from storage.objects o
    where o.bucket_id='Admin'
      and o.name=t.image_path
  );

-- Health now also tracks AI players that still have no portrait mapping.
create or replace function public.check_wta_ai_portrait_health_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','storage','pg_catalog','pg_temp'
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_total integer:=0;
  v_assigned integer:=0;
  v_unassigned integer:=0;
  v_missing integer:=0;
  v_bad_paths integer:=0;
  v_policy_present boolean:=false;
  v_problem_count integer:=0;
  v_unassigned_players jsonb:='[]'::jsonb;
  v_details jsonb;
begin
  select count(*),
         count(*) filter(where image_path is not null),
         count(*) filter(where image_path is null)
  into v_total,v_assigned,v_unassigned
  from public.players
  where world='WTA'
    and player_type='ai';

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'ai_profile_number',p.ai_profile_number,
      'name',p.first_name||' '||p.last_name,
      'country_code',p.country_code
    )
    order by p.ai_profile_number
  ),'[]'::jsonb)
  into v_unassigned_players
  from public.players p
  where p.world='WTA'
    and p.player_type='ai'
    and p.image_path is null;

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
    and p.image_path not like 'WTA Avatars/%'
    and p.image_path not like 'WTA AI Profiles/%';

  select exists(
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_player_avatar_authenticated_read'
      and cmd='SELECT'
      and qual ilike '%WTA Avatars/%'
      and qual ilike '%WTA AI Profiles/%'
  ) into v_policy_present;

  v_problem_count:=v_unassigned+v_missing+v_bad_paths+case when v_policy_present then 0 else 1 end;

  v_details:=jsonb_build_object(
    'wta_ai_players',v_total,
    'assigned_wta_ai_portraits',v_assigned,
    'unassigned_wta_ai_portraits',v_unassigned,
    'unassigned_players',v_unassigned_players,
    'missing_storage_objects',v_missing,
    'unexpected_portrait_paths',v_bad_paths,
    'authenticated_storage_policy_present',v_policy_present,
    'supported_paths',jsonb_build_array('WTA Avatars/','WTA AI Profiles/'),
    'problem_count',v_problem_count
  );

  if v_problem_count>0 then
    perform public.raise_system_incident_v1(
      'check:wta_ai_portraits',
      'warning',
      'WTA AI profile portraits require attention',
      format('%s WTA AI portrait issue(s) detected; %s player(s) still have no portrait.',v_problem_count,v_unassigned),
      'business:wta-ai-portrait-health',
      v_details
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:wta-ai-portrait-health',
      'All WTA AI players have assigned portraits and all mapped storage objects resolve correctly.'
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
      then format('%s WTA AI portrait issue(s); %s/%s portraits assigned.',v_problem_count,v_assigned,v_total)
      else format('%s/%s WTA AI portraits assigned and healthy.',v_assigned,v_total)
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

do $$
declare
  v_total integer;
  v_assigned integer;
  v_unassigned integer;
  v_missing_objects integer;
begin
  select count(*),
         count(*) filter(where image_path is not null),
         count(*) filter(where image_path is null)
  into v_total,v_assigned,v_unassigned
  from public.players
  where world='WTA' and player_type='ai';

  select count(*) into v_missing_objects
  from public.players p
  where p.world='WTA'
    and p.player_type='ai'
    and p.image_path is not null
    and not exists(
      select 1 from storage.objects o
      where o.bucket_id='Admin' and o.name=p.image_path
    );

  if v_total<>417 then
    raise exception 'Expected 417 WTA AI players, found %.',v_total;
  end if;

  if v_assigned<>412 or v_unassigned<>5 then
    raise exception 'Expected 412 assigned / 5 unassigned WTA AI portraits, found % / %.',v_assigned,v_unassigned;
  end if;

  if v_missing_objects<>0 then
    raise exception 'Mapped WTA AI portrait objects missing from storage: %.',v_missing_objects;
  end if;
end;
$$;

select public.check_wta_ai_portrait_health_v1();
