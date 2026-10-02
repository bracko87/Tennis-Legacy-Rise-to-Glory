-- Prevent newly registered pg_cron monitors from being marked overdue
-- before they have had a legitimate first-run/staleness window.
--
-- Root cause: when no cron.job_run_details row existed yet, the watchdog passed
-- NULL as last_run_at. system_monitor_cron_missed_threshold_v1 then assumed
-- "now - 7 days", immediately counting historical schedule slots that happened
-- before the job/process was created.
--
-- Use the latest real run when available; otherwise use the monitor registration
-- timestamp as the freshness baseline. updated_at is included so a re-enabled or
-- reconfigured process receives a fresh first-run grace window.

create or replace function public.run_system_health_watchdog_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','cron','pg_temp'
as $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_now_day integer:=public.national_team_current_abs_day_v1();
  v_now_second bigint:=public.current_game_second_v1();
  v_synced integer:=0;
  v_issues integer:=0;
  v_count integer;
  v_latest timestamptz;
  v_freshness_baseline timestamptz;
  v_schedule text;
  p record;
  v_details jsonb;
begin
  v_synced:=public.sync_system_cron_runs_v1();

  -- Scheduler presence/freshness.
  for p in
    select *
    from public.system_monitor_processes
    where is_enabled and source_kind='cron'
  loop
    if not exists(select 1 from cron.job j where j.jobname=p.source_ref and j.active) then
      perform public.raise_system_incident_v1(
        p.process_key,p.incident_severity,'Scheduled job missing or disabled',
        format('The required pg_cron job "%s" is missing or disabled.',p.source_ref),
        'cron-disabled:'||p.source_ref,
        jsonb_build_object('job_name',p.source_ref)
      );
      v_issues:=v_issues+1;
      continue;
    else
      perform public.resolve_system_incident_by_dedupe_v1(
        'cron-disabled:'||p.source_ref,
        'The scheduled job is active again.'
      );
    end if;

    if p.stale_after_minutes is not null then
      select j.schedule into v_schedule
      from cron.job j
      where j.jobname=p.source_ref and j.active
      limit 1;

      select max(d.start_time) into v_latest
      from cron.job_run_details d
      join cron.job j on j.jobid=d.jobid
      where j.jobname=p.source_ref;

      -- A brand-new monitor has no historical pg_cron run yet. Do not treat
      -- schedule slots from before the process existed as "missed".
      v_freshness_baseline:=coalesce(
        v_latest,
        greatest(
          coalesce(p.created_at,now()),
          coalesce(p.updated_at,p.created_at,now())
        )
      );

      if public.system_monitor_cron_missed_threshold_v1(
        v_schedule,
        v_freshness_baseline,
        p.expected_interval_minutes,
        p.stale_after_minutes,
        now()
      ) then
        perform public.raise_system_incident_v1(
          p.process_key,p.incident_severity,'Scheduled process is overdue',
          format('"%s" has missed enough scheduled executions to exceed its %s-minute health window.',p.label,p.stale_after_minutes),
          'cron-stale:'||p.source_ref,
          jsonb_build_object(
            'job_name',p.source_ref,
            'last_run_at',v_latest,
            'freshness_baseline',v_freshness_baseline,
            'first_run_grace_active',v_latest is null,
            'schedule',v_schedule,
            'expected_interval_minutes',p.expected_interval_minutes,
            'stale_after_minutes',p.stale_after_minutes
          )
        );
        v_issues:=v_issues+1;
      else
        perform public.resolve_system_incident_by_dedupe_v1(
          'cron-stale:'||p.source_ref,
          case
            when v_latest is null then 'The newly registered job is within its first-run grace window.'
            else 'The job is within its actual cron schedule and missed-run threshold.'
          end
        );
      end if;
    end if;
  end loop;

  -- Singles matches substantially overdue.
  select count(*) into v_count
  from public.tournament_matches m
  where m.status in ('scheduled','in_progress')
    and m.player1_id is not null and m.player2_id is not null
    and public.tournament_match_game_second_v1(m.id) < v_now_second-21600;

  if v_count>0 then
    perform public.raise_system_incident_v1(
      'check:tournament_matches_overdue','critical','Singles matches are overdue',
      format('%s tournament match(es) are still scheduled/in progress more than 6 game-hours after their expected start.',v_count),
      'business:tournament-matches-overdue',
      jsonb_build_object('count',v_count,'current_game_second',v_now_second)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:tournament-matches-overdue','No overdue singles matches remain.');
  end if;

  -- Doubles matches substantially overdue.
  select count(*) into v_count
  from public.tournament_doubles_matches m
  where m.status in ('scheduled','in_progress')
    and m.team1_id is not null and m.team2_id is not null
    and public.doubles_match_game_second_v1(m.id) < v_now_second-21600;

  if v_count>0 then
    perform public.raise_system_incident_v1(
      'check:doubles_matches_overdue','critical','Doubles matches are overdue',
      format('%s doubles match(es) are still scheduled/in progress more than 6 game-hours after their expected start.',v_count),
      'business:doubles-matches-overdue',
      jsonb_build_object('count',v_count,'current_game_second',v_now_second)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:doubles-matches-overdue','No overdue doubles matches remain.');
  end if;

  -- Travel legs overdue after arrival date.
  select count(*) into v_count
  from public.player_travel_legs l
  join public.players plr on plr.id=l.player_id
  where plr.owner_user_id is not null
    and l.status='planned'
    and l.arrival_absolute_day < v_now_day-1;

  if v_count>0 then
    perform public.raise_system_incident_v1(
      'check:travel_overdue','critical','Player travel processing is overdue',
      format('%s travel leg(s) are still planned after their arrival day.',v_count),
      'business:travel-overdue',
      jsonb_build_object('count',v_count,'current_absolute_day',v_now_day)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:travel-overdue','No overdue travel legs remain.');
  end if;

  -- Rankings should never lag more than 8 game days once publication exists.
  select max(game_absolute_day) into v_count from public.ranking_publication_runs;
  if v_count is not null and v_count < v_now_day-8 then
    perform public.raise_system_incident_v1(
      'check:ranking_stale','critical','Ranking publication is behind game time',
      format('Latest singles ranking publication is game day %s while the game is on day %s.',v_count,v_now_day),
      'business:ranking-stale',
      jsonb_build_object('latest_ranking_day',v_count,'current_absolute_day',v_now_day)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:ranking-stale','Ranking publication is within the expected game-time window.');
  end if;

  -- National-team elections/funds/fixtures that passed objective deadlines.
  select
    (select count(*) from public.national_captain_elections e
      where e.status not in ('completed','cancelled')
        and case
          when e.status='candidate_registration' then e.registration_end_game_day
          when e.status in ('campaign','voting') then e.voting_end_game_day
          when e.status='runoff' then coalesce(e.runoff_end_game_day,e.voting_end_game_day)
          else greatest(e.registration_end_game_day,e.voting_end_game_day,coalesce(e.runoff_end_game_day,e.voting_end_game_day))
        end < v_now_day-1)
    +
    (select count(*) from public.national_association_funds f
      where f.status='open' and f.deadline_game_day is not null and f.deadline_game_day < v_now_day-1)
    +
    (select count(*) from public.national_team_fixtures f
      where f.status not in ('completed','cancelled') and f.tie_end_absolute_day < v_now_day-1)
  into v_count;

  if v_count>0 then
    perform public.raise_system_incident_v1(
      'check:national_team_deadlines','high','National-team lifecycle item is overdue',
      format('%s national-team election, renewal or fixture item(s) remain unresolved past their deadline.',v_count),
      'business:national-team-deadlines',
      jsonb_build_object('count',v_count,'current_absolute_day',v_now_day)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:national-team-deadlines','National-team lifecycle deadlines are currently healthy.');
  end if;

  -- Email queue failures.
  select count(*) into v_count
  from public.birthday_email_outbox b
  where (b.status='failed' and b.attempts>=3)
     or (b.status='sending' and b.last_attempt_at<now()-interval '20 minutes');

  if v_count>0 then
    perform public.raise_system_incident_v1(
      'check:email_outbox','high','Email delivery queue has failures',
      format('%s birthday email job(s) are repeatedly failing or stuck in sending state.',v_count),
      'business:email-outbox',
      jsonb_build_object('count',v_count)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:email-outbox','Email queue has no repeated/stuck delivery failures.');
  end if;

  -- Clock sanity only; pause is allowed.
  select jsonb_build_object(
    'speed_multiplier',g.speed_multiplier,
    'real_anchor_at',g.real_anchor_at,
    'is_paused',g.is_paused
  )
  into v_details
  from public.game_clock g
  where g.id=1;

  if coalesce((v_details->>'speed_multiplier')::numeric,0)<=0
     or (v_details->>'real_anchor_at')::timestamptz > now()+interval '5 minutes' then
    perform public.raise_system_incident_v1(
      'check:game_clock','critical','Game clock configuration is invalid',
      'The game clock has an invalid running speed or a future real-time anchor.',
      'business:game-clock',
      coalesce(v_details,'{}'::jsonb)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:game-clock','Game clock configuration is valid.');
  end if;

  -- Administrator alert channel must be observable without recursively emailing itself.
  select count(*) into v_count
  from public.system_alert_email_outbox o
  join public.system_incidents i on i.id=o.incident_id
  where i.status in ('open','acknowledged')
    and (
      (o.status='failed' and (
        o.attempts>=3
        or lower(coalesce(o.last_error,'')) like '%domain%'
        or lower(coalesce(o.last_error,'')) like '%api key%'
      ))
      or (o.status='sending' and o.last_attempt_at<now()-interval '20 minutes')
    );

  if v_count>0 then
    perform public.raise_system_incident_v1(
      'check:admin_alert_email','critical','Administrator alert email channel is failing',
      format('%s administrator alert email job(s) are repeatedly failing or stuck in sending state.',v_count),
      'business:admin-alert-email',
      jsonb_build_object('count',v_count)
    );
    v_issues:=v_issues+1;
  else
    perform public.resolve_system_incident_by_dedupe_v1('business:admin-alert-email','Administrator alert email channel is healthy.');
  end if;

  perform public.log_system_business_checks_v1();

  perform public.resolve_system_incident_by_dedupe_v1(
    'watchdog:self-failure',
    'The system health watchdog completed successfully.'
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  )
  values(
    'watchdog:system-health',
    case when v_issues>0 then 'warning' else 'success' end,
    v_started,clock_timestamp(),
    greatest(0,(extract(epoch from (clock_timestamp()-v_started))*1000)::bigint),
    format('Watchdog completed: %s cron runs synchronized, %s active issue(s).',v_synced,v_issues),
    jsonb_build_object('cron_runs_synced',v_synced,'issues',v_issues,'absolute_game_day',v_now_day)
  );

  return jsonb_build_object('status','completed','cron_runs_synced',v_synced,'active_checks_failed',v_issues);
exception when others then
  perform public.raise_system_incident_v1(
    'watchdog:system-health','critical','System health watchdog failed',
    sqlerrm,
    'watchdog:self-failure',
    jsonb_build_object('sqlstate',sqlstate)
  );

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,error_message
  )
  values(
    'watchdog:system-health','error',v_started,clock_timestamp(),
    greatest(0,(extract(epoch from (clock_timestamp()-v_started))*1000)::bigint),
    'System health watchdog failed.',sqlerrm
  );

  return jsonb_build_object('status','error','error',sqlerrm);
end;
$function$;

-- Re-evaluate immediately so any false "new job overdue" incident is resolved.
select public.run_system_health_watchdog_v1();
