-- Final tournament resilience layer added after the Season 1 week-11
-- false-cancellation incident.
--
-- Goals:
-- * preserve an audit trail for repairs
-- * allow controlled reopening of false minimum-field cancellations
-- * rebalance AI entries to protect minimum viable fields
-- * provide an independent fallback processor
-- * block destructive cancellation while the entry pipeline is unhealthy
-- * raise Control Center incidents and repeat critical admin alerts every 15 minutes

create table if not exists public.tournament_cancellation_repair_audit (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null,
  tournament_name text not null,
  world text not null,
  original_reason_code text,
  original_reason_message text,
  original_canceled_at timestamptz,
  original_metadata jsonb not null default '{}'::jsonb,
  repair_reason text not null,
  repair_status text not null default 'started',
  repair_details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists tournament_cancellation_repair_audit_comp_idx
  on public.tournament_cancellation_repair_audit(competition_id,started_at desc);

create table if not exists public.tournament_entry_auto_repair_attempts (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null,
  attempted_at timestamptz not null default now(),
  status text not null,
  details jsonb not null default '{}'::jsonb
);

create index if not exists tournament_entry_auto_repair_attempts_comp_idx
  on public.tournament_entry_auto_repair_attempts(competition_id,attempted_at desc);

create or replace function public.rebalance_tournament_minimum_field_v1(
  p_competition_id uuid,
  p_minimum integer default 8
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_world text;
  v_season integer;
  v_week smallint;
  v_target_count integer:=0;
  v_needed integer:=0;
  v_moved integer:=0;
  v_direct_cap integer:=0;
  v_qcap integer:=0;
  v_main_count integer:=0;
  v_q_count integer:=0;
  v_donor_comp uuid;
  v_player uuid;
  v_rank integer;
  v_points integer;
  v_draw_type text;
begin
  if p_minimum<2 then p_minimum:=2; end if;

  select wc.world,ed.season_number,
         public.tournament_application_target_week_v1(wc.id),
         c.main_draw_capacity-c.default_qualifier_slots,
         c.qualifying_capacity_max
  into v_world,v_season,v_week,v_direct_cap,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories c on c.code=ts.category_code
  where wc.id=p_competition_id
    and wc.status<>'canceled'
    and ed.status<>'canceled';

  if v_world is null then
    return jsonb_build_object('status','unavailable');
  end if;

  if exists(select 1 from public.tournament_draw_publications where competition_id=p_competition_id)
     or exists(select 1 from public.tournament_matches where competition_id=p_competition_id) then
    return jsonb_build_object('status','draw_exists');
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(format('tournament-min-field-rebalance:%s:%s:%s',v_season,v_week,v_world),0)
  );

  select count(*) into v_target_count
  from public.tournament_entries
  where competition_id=p_competition_id and entry_status='active';

  if v_target_count>=p_minimum then
    return jsonb_build_object('status','already_valid','active_entries',v_target_count,'minimum',p_minimum);
  end if;

  v_needed:=p_minimum-v_target_count;

  while v_needed>0 loop
    v_donor_comp:=null;
    v_player:=null;

    with week_comps as (
      select wc.id
      from public.tournament_world_competitions wc
      join public.tournament_editions ed on ed.id=wc.tournament_edition_id
      where wc.world=v_world
        and ed.season_number=v_season
        and wc.status<>'canceled'
        and ed.status<>'canceled'
        and public.tournament_application_target_week_v1(wc.id)=v_week
        and wc.id<>p_competition_id
        and not exists(select 1 from public.tournament_draw_publications d where d.competition_id=wc.id)
        and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
    ),
    donor_counts as (
      select wc.id competition_id,
             count(*) filter(where te.entry_status='active')::integer active_count
      from week_comps wc
      join public.tournament_entries te on te.competition_id=wc.id
      group by wc.id
      having count(*) filter(where te.entry_status='active')>p_minimum
    ),
    candidates as (
      select dc.competition_id,te.player_id,
             coalesce(te.ranking_position_snapshot,2147483647) rank_pos,
             dc.active_count
      from donor_counts dc
      join public.tournament_entries te
        on te.competition_id=dc.competition_id
       and te.entry_status='active'
      join public.players p on p.id=te.player_id
      where p.player_type='ai'
        and p.moderation_status<>'rejected'
      order by dc.active_count desc,
               coalesce(te.ranking_position_snapshot,2147483647) desc,
               te.player_id
      limit 1
    )
    select competition_id,player_id,rank_pos
    into v_donor_comp,v_player,v_rank
    from candidates;

    if v_player is null then exit; end if;

    select coalesce(pr.ranking_points,0)::integer
    into v_points
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.id=v_player;

    delete from public.tournament_entries
    where competition_id=v_donor_comp and player_id=v_player;

    update public.tournament_applications
    set status='superseded',
        decision_reason='repair_rebalanced_to_protect_minimum_field',
        decided_at=coalesce(decided_at,now()),
        updated_at=now()
    where competition_id=v_donor_comp
      and player_id=v_player
      and status in ('applied','accepted_main_draw','accepted_qualification');

    select count(*) filter(where draw_type='main_draw' and entry_status='active'),
           count(*) filter(where draw_type='qualification' and entry_status='active')
    into v_main_count,v_q_count
    from public.tournament_entries
    where competition_id=p_competition_id;

    v_draw_type:=case
      when v_main_count<v_direct_cap then 'main_draw'
      when v_q_count<v_qcap then 'qualification'
      else null
    end;

    if v_draw_type is null then exit; end if;

    insert into public.tournament_entries(
      competition_id,player_id,world,draw_type,entry_status,entry_source,ranking_position_snapshot
    )
    values(p_competition_id,v_player,v_world,v_draw_type,'active','application',v_rank)
    on conflict(competition_id,player_id) do update
    set draw_type=excluded.draw_type,
        entry_status='active',
        entry_source='application',
        ranking_position_snapshot=excluded.ranking_position_snapshot,
        updated_at=now();

    insert into public.tournament_applications(
      competition_id,player_id,owner_user_id,world,status,
      ranking_position_snapshot,ranking_points_snapshot,priority,accept_qualification,
      application_source,target_season_week,decision_reason,decided_at,created_at,updated_at
    )
    values(
      p_competition_id,v_player,null,v_world,
      case when v_draw_type='main_draw' then 'accepted_main_draw' else 'accepted_qualification' end,
      v_rank,coalesce(v_points,0),null,true,
      'ai_late_fill',v_week,'repair_rebalanced_minimum_field',now(),now(),now()
    )
    on conflict(competition_id,player_id) do update
    set status=excluded.status,
        ranking_position_snapshot=excluded.ranking_position_snapshot,
        ranking_points_snapshot=excluded.ranking_points_snapshot,
        priority=null,
        accept_qualification=true,
        application_source='ai_late_fill',
        target_season_week=excluded.target_season_week,
        decision_reason='repair_rebalanced_minimum_field',
        decided_at=now(),
        updated_at=now();

    v_moved:=v_moved+1;
    v_needed:=v_needed-1;
  end loop;

  select count(*) into v_target_count
  from public.tournament_entries
  where competition_id=p_competition_id and entry_status='active';

  return jsonb_build_object(
    'status',case when v_target_count>=p_minimum then 'rebalanced' else 'insufficient_pool' end,
    'active_entries',v_target_count,
    'minimum',p_minimum,
    'players_moved',v_moved,
    'world',v_world,
    'season',v_season,
    'target_week',v_week
  );
end;
$$;

create or replace function public.auto_repair_due_tournament_entry_pipelines_v1(p_limit integer default 6)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_now bigint:=public.current_game_second_v1();
  v_abs integer:=floor(v_now::numeric/86400)::integer;
  r record;
  v_cycle public.tournament_competition_entry_cycles%rowtype;
  v_alloc jsonb;
  v_fill jsonb;
  v_lock jsonb;
  v_rebalance jsonb;
  v_entries integer;
  v_fixed integer:=0;
  v_failed integer:=0;
  v_attempts integer:=0;
  v_details jsonb;
begin
  for r in
    select
      wc.id competition_id,
      ts.name tournament_name,
      wc.world,
      ed.season_number,
      min(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint))::integer start_abs
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and not exists(select 1 from public.tournament_draw_publications d where d.competition_id=wc.id)
      and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
    group by wc.id,ts.name,wc.world,ed.season_number
    having min(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint))::integer
             between v_abs and v_abs+14
       and v_now >= (
         (min(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint))::bigint-8)*86400
         + 18*3600
       )
    order by start_abs,wc.world,ts.name,wc.id
    limit greatest(1,least(coalesce(p_limit,6),12))
  loop
    select * into v_cycle
    from public.tournament_competition_entry_cycles
    where competition_id=r.competition_id;

    select count(*) into v_entries
    from public.tournament_entries
    where competition_id=r.competition_id and entry_status='active';

    if v_cycle.normal_allocation_processed_at is not null
       and v_cycle.ai_late_fill_processed_at is not null
       and v_cycle.field_locked_at is not null
       and v_entries>=8 then
      perform public.resolve_system_incident_by_dedupe_v1(
        'business:tournament-entry-pipeline:'||r.competition_id::text,
        'Tournament entry pipeline is healthy.'
      );
      continue;
    end if;

    v_attempts:=v_attempts+1;
    v_alloc:=null; v_fill:=null; v_lock:=null; v_rebalance:=null;

    begin
      if v_cycle.normal_allocation_processed_at is null then
        v_alloc:=public.allocate_tournament_applications_v3(r.competition_id);
      end if;
    exception when others then
      v_alloc:=jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
    end;

    select * into v_cycle
    from public.tournament_competition_entry_cycles
    where competition_id=r.competition_id;

    begin
      if v_cycle.ai_late_fill_processed_at is null then
        v_fill:=public.fill_ai_late_tournament_vacancies_v1(r.competition_id);
      end if;
    exception when others then
      v_fill:=jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
    end;

    select * into v_cycle
    from public.tournament_competition_entry_cycles
    where competition_id=r.competition_id;

    begin
      if v_cycle.field_locked_at is null then
        v_lock:=public.lock_tournament_field_v1(r.competition_id);
      end if;
    exception when others then
      v_lock:=jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
    end;

    select count(*) into v_entries
    from public.tournament_entries
    where competition_id=r.competition_id and entry_status='active';

    if v_entries<8 then
      begin
        v_rebalance:=public.rebalance_tournament_minimum_field_v1(r.competition_id,8);
      exception when others then
        v_rebalance:=jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
      end;
    end if;

    select * into v_cycle
    from public.tournament_competition_entry_cycles
    where competition_id=r.competition_id;

    select count(*) into v_entries
    from public.tournament_entries
    where competition_id=r.competition_id and entry_status='active';

    v_details:=jsonb_build_object(
      'competition_id',r.competition_id,
      'tournament_name',r.tournament_name,
      'world',r.world,
      'start_absolute_day',r.start_abs,
      'allocation',coalesce(v_alloc,'{}'::jsonb),
      'late_fill',coalesce(v_fill,'{}'::jsonb),
      'field_lock',coalesce(v_lock,'{}'::jsonb),
      'minimum_field_rebalance',coalesce(v_rebalance,'{}'::jsonb),
      'active_entries',v_entries,
      'normal_allocation_processed_at',v_cycle.normal_allocation_processed_at,
      'ai_late_fill_processed_at',v_cycle.ai_late_fill_processed_at,
      'field_locked_at',v_cycle.field_locked_at
    );

    if v_cycle.normal_allocation_processed_at is not null
       and v_cycle.ai_late_fill_processed_at is not null
       and v_cycle.field_locked_at is not null
       and v_entries>=8 then
      v_fixed:=v_fixed+1;
      insert into public.tournament_entry_auto_repair_attempts(competition_id,status,details)
      values(r.competition_id,'repaired',v_details);
      perform public.resolve_system_incident_by_dedupe_v1(
        'business:tournament-entry-pipeline:'||r.competition_id::text,
        'Automatic fallback repaired the tournament entry pipeline.'
      );
    else
      v_failed:=v_failed+1;
      insert into public.tournament_entry_auto_repair_attempts(competition_id,status,details)
      values(r.competition_id,'failed',v_details);
      perform public.raise_system_incident_v1(
        'check:tournament_entry_pipeline',
        'critical',
        'Tournament entry automatic recovery failed',
        format('%s · %s is still not safe after automatic recovery. The tournament is protected from cancellation and recovery will retry.',r.tournament_name,r.world),
        'business:tournament-entry-pipeline:'||r.competition_id::text,
        v_details
      );
    end if;
  end loop;

  return jsonb_build_object(
    'status',case when v_failed>0 then 'warning' else 'success' end,
    'attempted',v_attempts,
    'repaired',v_fixed,
    'failed',v_failed,
    'current_absolute_day',v_abs
  );
end;
$$;

create or replace function public.check_tournament_entry_processor_degradation_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,cron,pg_temp
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_failed_last3 integer:=0;
  v_latest_status text;
  v_latest_start timestamptz;
  v_latest_duration_ms bigint;
begin
  with recent as (
    select d.status,d.start_time,d.end_time,
           row_number() over(order by d.start_time desc) rn
    from cron.job_run_details d
    join cron.job j on j.jobid=d.jobid
    where j.jobname='tennis-entry-lifecycle-v2'
    order by d.start_time desc
    limit 3
  )
  select count(*) filter(where status='failed'),
         (array_agg(status order by rn))[1],
         (array_agg(start_time order by rn))[1],
         (array_agg(
           case when end_time is null then null
                else round(extract(epoch from(end_time-start_time))*1000)::bigint end
           order by rn
         ))[1]
  into v_failed_last3,v_latest_status,v_latest_start,v_latest_duration_ms
  from recent;

  if v_latest_status='failed'
     or v_failed_last3>=2
     or coalesce(v_latest_duration_ms,0)>=110000 then
    perform public.raise_system_incident_v1(
      'check:tournament_entry_processor_degraded',
      'critical',
      'Tournament entry processor is degraded',
      format(
        'The primary tournament entry lifecycle is unhealthy: %s failed run(s) among the last 3; latest status %s; latest runtime %s ms. Independent automatic recovery remains active.',
        v_failed_last3,coalesce(v_latest_status,'none'),coalesce(v_latest_duration_ms,0)
      ),
      'business:tournament-entry-processor-degraded',
      jsonb_build_object(
        'failed_last_3',v_failed_last3,
        'latest_status',v_latest_status,
        'latest_start_at',v_latest_start,
        'latest_duration_ms',v_latest_duration_ms
      )
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:tournament-entry-processor-degraded',
      'Tournament entry processor is back within the healthy execution window.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  )
  values(
    'check:tournament_entry_processor_degraded',
    case when v_latest_status='failed' or v_failed_last3>=2 or coalesce(v_latest_duration_ms,0)>=110000 then 'error' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_latest_status='failed' or v_failed_last3>=2 or coalesce(v_latest_duration_ms,0)>=110000
      then 'Primary tournament entry processor is degraded; fallback recovery is active.'
      else 'Primary tournament entry processor is healthy.'
    end,
    jsonb_build_object(
      'failed_last_3',v_failed_last3,
      'latest_status',v_latest_status,
      'latest_start_at',v_latest_start,
      'latest_duration_ms',v_latest_duration_ms
    )
  );

  return jsonb_build_object(
    'status',case when v_latest_status='failed' or v_failed_last3>=2 or coalesce(v_latest_duration_ms,0)>=110000 then 'error' else 'success' end,
    'failed_last_3',v_failed_last3,
    'latest_status',v_latest_status,
    'latest_duration_ms',v_latest_duration_ms
  );
end;
$$;

create or replace function public.queue_open_critical_incident_reminders_v1()
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  r record;
  v_count integer:=0;
begin
  for r in
    select i.id
    from public.system_incidents i
    join public.system_monitor_processes p on p.process_key=i.process_key
    where i.status in ('open','acknowledged')
      and i.severity='critical'
      and p.email_alerts_enabled
      and (i.last_emailed_at is null or i.last_emailed_at<=now()-interval '15 minutes')
    order by i.first_seen_at
  loop
    v_count:=v_count+public.queue_system_incident_email_v1(r.id);
  end loop;
  return v_count;
end;
$$;

create or replace function public.process_minimum_tournament_fields_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  d record;
  r record;
  v_abs integer;
  v_game_seconds bigint;
  v_blocked integer:=0;
  v_rebalanced integer:=0;
  v_entries integer;
  v_cycle public.tournament_competition_entry_cycles%rowtype;
  v_due bigint;
  v_rebalance jsonb;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select gc.game_total_seconds::bigint into v_game_seconds from public.get_game_clock_v1() gc;

  for r in
    select
      wc.id,
      ts.name tournament_name,
      wc.world,
      min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer start_abs
    from public.tournament_world_competitions wc
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    join public.tournament_schedule_slots sl on sl.tournament_edition_id=ed.id
    where wc.status<>'canceled'
      and ed.status<>'canceled'
      and not exists(select 1 from public.tournament_draw_publications dp where dp.competition_id=wc.id)
      and not exists(select 1 from public.tournament_matches tm where tm.competition_id=wc.id)
    group by wc.id,ts.name,wc.world
    having min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer>=v_abs
       and min(public.training_camp_week_start_absolute_v1(ed.season_number,sl.season_week::smallint))::integer<=v_abs+14
  loop
    v_due:=((r.start_abs-8)::bigint*86400)+(18*3600);
    if v_game_seconds<v_due then continue; end if;

    select * into v_cycle
    from public.tournament_competition_entry_cycles
    where competition_id=r.id;

    if v_cycle.competition_id is null
       or v_cycle.normal_allocation_processed_at is null
       or v_cycle.ai_late_fill_processed_at is null
       or v_cycle.field_locked_at is null then
      perform public.raise_system_incident_v1(
        'check:tournament_entry_pipeline',
        'critical',
        'Minimum-field action blocked by incomplete entry pipeline',
        format('%s · %s reached minimum-field enforcement before its entry pipeline completed. Cancellation is blocked and automatic recovery will retry.',r.tournament_name,r.world),
        'business:tournament-entry-pipeline:'||r.id::text,
        jsonb_build_object(
          'competition_id',r.id,
          'tournament_name',r.tournament_name,
          'world',r.world,
          'start_absolute_day',r.start_abs,
          'current_game_second',v_game_seconds,
          'normal_allocation_processed_at',v_cycle.normal_allocation_processed_at,
          'ai_late_fill_processed_at',v_cycle.ai_late_fill_processed_at,
          'field_locked_at',v_cycle.field_locked_at
        )
      );
      v_blocked:=v_blocked+1;
      continue;
    end if;

    select count(*) into v_entries
    from public.tournament_entries
    where competition_id=r.id and entry_status='active';

    if v_entries<8 then
      begin
        v_rebalance:=public.rebalance_tournament_minimum_field_v1(r.id,8);
      exception when others then
        v_rebalance:=jsonb_build_object('status','error','error',sqlerrm,'sqlstate',sqlstate);
      end;

      select count(*) into v_entries
      from public.tournament_entries
      where competition_id=r.id and entry_status='active';

      if v_entries>=8 then
        v_rebalanced:=v_rebalanced+1;
        perform public.resolve_system_incident_by_dedupe_v1(
          'business:tournament-entry-pipeline:'||r.id::text,
          'Tournament minimum field restored automatically.'
        );
      else
        perform public.raise_system_incident_v1(
          'check:tournament_entry_pipeline',
          'critical',
          'Tournament minimum field cannot be restored automatically',
          format('%s · %s remains below 8 players. Cancellation is blocked; automatic recovery will continue and administrators will be reminded every 15 minutes.',r.tournament_name,r.world),
          'business:tournament-entry-pipeline:'||r.id::text,
          jsonb_build_object(
            'competition_id',r.id,
            'tournament_name',r.tournament_name,
            'world',r.world,
            'active_entries',v_entries,
            'minimum_players',8,
            'rebalance',v_rebalance
          )
        );
        v_blocked:=v_blocked+1;
      end if;
    else
      perform public.resolve_system_incident_by_dedupe_v1(
        'business:tournament-entry-pipeline:'||r.id::text,
        'Tournament field is valid.'
      );
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'automatic_cancellations',0,
    'minimum_fields_rebalanced',v_rebalanced,
    'protected_for_recovery',v_blocked,
    'game_absolute_day',v_abs,
    'game_total_seconds',v_game_seconds
  );
end;
$$;

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'cron:tennis-tournament-entry-auto-repair-v1',
  'Tournament entry automatic recovery',
  'Tournaments',
  'Fallback processor that repairs due allocation, AI fill, field lock and minimum fields independently of the primary entry lifecycle.',
  'cron','tennis-tournament-entry-auto-repair-v1',true,'critical',5,15,true,22
),
(
  'check:tournament_entry_processor_degraded',
  'Tournament entry processor degradation',
  'Tournaments',
  'Detects repeated recent failures or timeout-like runtimes in the primary tournament entry lifecycle.',
  'business_check',null,true,'critical',5,10,true,207
),
(
  'cron:tennis-critical-incident-reminders-v1',
  'Critical incident reminder delivery',
  'Core',
  'Queues administrator reminders every 15 minutes while a critical incident remains unresolved.',
  'cron','tennis-critical-incident-reminders-v1',true,'critical',15,30,true,8
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

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='tennis-tournament-entry-auto-repair-v1' limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-tournament-entry-auto-repair-v1',
  '1-56/5 * * * *',
  $cron$
    select public.auto_repair_due_tournament_entry_pipelines_v1(6);
    select public.check_tournament_entry_processor_degradation_v1();
  $cron$
);

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='tennis-tournament-entry-pipeline-health-v1' limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-tournament-entry-pipeline-health-v1',
  '2-57/5 * * * *',
  $cron$
    select public.check_tournament_entry_pipeline_health_v1();
    select public.check_tournament_cancellation_spike_v1();
  $cron$
);

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='tennis-critical-incident-reminders-v1' limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-critical-incident-reminders-v1',
  '4,19,34,49 * * * *',
  $cron$select public.queue_open_critical_incident_reminders_v1();$cron$
);
