-- Tournament entry lifecycle hardening:
-- 1) do not rebuild expensive travel plans for AI application churn
-- 2) never cancel for minimum field unless the entry pipeline explicitly completed
-- 3) independently monitor incomplete entry pipelines and cancellation spikes
-- 4) re-enable administrator System Health email dispatch

create or replace function public.sync_travel_plan_from_commitment_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_player uuid;
  v_is_human_owned boolean:=false;
begin
  v_player:=case when tg_op='DELETE' then old.player_id else new.player_id end;

  select exists(
    select 1
    from public.players p
    where p.id=v_player
      and p.player_type='human'
      and p.owner_user_id is not null
  ) into v_is_human_owned;

  if not v_is_human_owned then
    return case when tg_op='DELETE' then old else new end;
  end if;

  perform public.rebuild_player_travel_plan_v1(v_player);
  return case when tg_op='DELETE' then old else new end;
end;
$$;

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
(
  'check:tournament_entry_pipeline',
  'Tournament entry pipeline',
  'Tournaments',
  'Detects tournaments reaching field lock without allocation, AI late-fill and field-lock completion.',
  'business_check',
  null,
  true,
  'critical',
  5,
  10,
  true,
  205
),
(
  'check:tournament_cancellation_spike',
  'Tournament cancellation spike',
  'Tournaments',
  'Detects unusual bursts of minimum-field tournament cancellations.',
  'business_check',
  null,
  true,
  'critical',
  5,
  10,
  true,
  206
),
(
  'cron:tennis-tournament-entry-pipeline-health-v1',
  'Tournament entry pipeline health job',
  'Tournaments',
  'Runs independent entry-pipeline and cancellation-spike checks.',
  'cron',
  'tennis-tournament-entry-pipeline-health-v1',
  true,
  'critical',
  5,
  15,
  true,
  25
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

create or replace function public.check_tournament_entry_pipeline_health_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_now bigint:=public.current_game_second_v1();
  v_now_abs integer:=floor(v_now::numeric/86400)::integer;
  r record;
  c public.tournament_competition_entry_cycles%rowtype;
  v_due bigint;
  v_apps integer;
  v_entries integer;
  v_issues integer:=0;
  v_key text;
  i record;
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
             between v_now_abs and v_now_abs+14
  loop
    v_due:=((r.start_abs-8)::bigint*86400)+(18*3600);
    v_key:='business:tournament-entry-pipeline:'||r.competition_id::text;

    select * into c
    from public.tournament_competition_entry_cycles
    where competition_id=r.competition_id;

    if v_now>=v_due and (
      c.competition_id is null
      or c.normal_allocation_processed_at is null
      or c.ai_late_fill_processed_at is null
      or c.field_locked_at is null
    ) then
      select count(*) into v_apps
      from public.tournament_applications
      where competition_id=r.competition_id and status='applied';

      select count(*) into v_entries
      from public.tournament_entries
      where competition_id=r.competition_id and entry_status='active';

      perform public.raise_system_incident_v1(
        'check:tournament_entry_pipeline',
        'critical',
        'Tournament entry pipeline did not complete',
        format(
          '%s · %s reached its field-lock deadline but allocation/AI late-fill/field lock did not complete. Automatic minimum-field cancellation is blocked until the entry pipeline finishes.',
          r.tournament_name,r.world
        ),
        v_key,
        jsonb_build_object(
          'competition_id',r.competition_id,
          'tournament_name',r.tournament_name,
          'world',r.world,
          'start_absolute_day',r.start_abs,
          'field_lock_deadline_game_second',v_due,
          'current_game_second',v_now,
          'normal_allocation_processed_at',c.normal_allocation_processed_at,
          'ai_late_fill_processed_at',c.ai_late_fill_processed_at,
          'field_locked_at',c.field_locked_at,
          'applied_applications',v_apps,
          'active_entries',v_entries
        )
      );
      v_issues:=v_issues+1;
    else
      perform public.resolve_system_incident_by_dedupe_v1(
        v_key,
        'Tournament entry pipeline completed or is not yet due.'
      );
    end if;
  end loop;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  )
  values(
    'check:tournament_entry_pipeline',
    case when v_issues>0 then 'error' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_issues>0
      then format('%s tournament entry pipeline(s) are incomplete past field lock.',v_issues)
      else 'Tournament entry pipelines due for locking are healthy.'
    end,
    jsonb_build_object('issues',v_issues,'current_game_second',v_now,'current_absolute_day',v_now_abs)
  );

  return jsonb_build_object('status',case when v_issues>0 then 'error' else 'success' end,'issues',v_issues);
end;
$$;

create or replace function public.check_tournament_cancellation_spike_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_count integer:=0;
begin
  select count(*)::integer into v_count
  from public.tournament_cancellations c
  where c.reason_code='minimum_field_not_met'
    and c.canceled_at>=now()-interval '30 minutes';

  if v_count>=3 then
    perform public.raise_system_incident_v1(
      'check:tournament_cancellation_spike',
      'critical',
      'Multiple tournaments were cancelled for minimum field',
      format('%s tournament competition(s) were cancelled for insufficient field within the last 30 minutes. This may indicate an upstream entry-lifecycle failure.',v_count),
      'business:tournament-cancellation-spike',
      jsonb_build_object('count',v_count,'window_minutes',30,'reason_code','minimum_field_not_met')
    );
  else
    perform public.resolve_system_incident_by_dedupe_v1(
      'business:tournament-cancellation-spike',
      'No unusual minimum-field cancellation burst is active.'
    );
  end if;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  )
  values(
    'check:tournament_cancellation_spike',
    case when v_count>=3 then 'error' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
    case when v_count>=3
      then format('%s minimum-field cancellations in 30 minutes.',v_count)
      else 'No tournament cancellation spike detected.'
    end,
    jsonb_build_object('count',v_count,'window_minutes',30)
  );

  return jsonb_build_object('status',case when v_count>=3 then 'error' else 'success' end,'count',v_count);
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
  v_count integer:=0;
  v_blocked integer:=0;
  v_result jsonb;
  v_cycle public.tournament_competition_entry_cycles%rowtype;
  v_due bigint;
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

    if v_game_seconds<v_due then
      continue;
    end if;

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
        'Minimum-field cancellation blocked by incomplete entry pipeline',
        format('%s · %s reached minimum-field enforcement before its entry pipeline completed. Tournament cancellation was blocked.',r.tournament_name,r.world),
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

    perform public.resolve_system_incident_by_dedupe_v1(
      'business:tournament-entry-pipeline:'||r.id::text,
      'Entry pipeline completed before minimum-field enforcement.'
    );

    v_result:=public.cancel_tournament_for_minimum_field_v1(r.id);
    if v_result->>'status'='canceled_minimum_field' then
      v_count:=v_count+1;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'canceled_tournaments',v_count,
    'blocked_incomplete_pipelines',v_blocked,
    'game_absolute_day',v_abs,
    'game_total_seconds',v_game_seconds
  );
end;
$$;

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-tournament-entry-pipeline-health-v1'
  limit 1;
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
end;
$$;

select cron.schedule(
  'tennis-tournament-entry-pipeline-health-v1',
  '*/5 * * * *',
  $cron$
    select public.check_tournament_entry_pipeline_health_v1();
    select public.check_tournament_cancellation_spike_v1();
  $cron$
);

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='tennis-system-alert-email-dispatch-v1'
  limit 1;
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'tennis-system-alert-email-dispatch-v1',
  '*/2 * * * *',
  $cron$
    select net.http_post(
      url := 'https://cwfznmroiqcyhfkfcrow.supabase.co/functions/v1/send-system-alerts',
      headers := '{"Content-Type":"application/json"}'::jsonb,
      body := jsonb_build_object(
        'cron_token',
        (select secret from private.internal_job_secrets where job_name='system_alert_dispatch_v1')
      )
    );
  $cron$
);

delete from public.system_alert_email_outbox o
using public.system_incidents i
where o.incident_id=i.id
  and o.status in ('pending','failed')
  and i.status='resolved';

select public.check_tournament_entry_pipeline_health_v1();
select public.check_tournament_cancellation_spike_v1();
