
insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
('cron:tennis_legacy_ai_training_progression','AI training progression','Simulation','Advances AI player training so the competitive population develops with game time.','cron','tennis_legacy_ai_training_progression',false,'high',60,120,true,160),
('cron:tennis-ai-weekly-short-injuries-v1','AI injury simulation','Health','Processes short AI injuries that affect tournament fields and competitive balance.','cron','tennis-ai-weekly-short-injuries-v1',false,'high',60,120,true,170),
('cron:tennis-injury-risk-proactive-v1','Proactive injury notifications','Health','Evaluates human injury risk and creates due warnings.','cron','tennis-injury-risk-proactive-v1',true,'high',10,30,true,180),
('cron:tennis-minimum-field-v1','Tournament minimum-field enforcement','Tournaments','Cancels or resolves tournaments that fail minimum field requirements.','cron','tennis-minimum-field-v1',true,'critical',60,120,true,190),
('cron:tennis-private-life-stock-quotes-v1','Stock quote refresh','Private Life','Refreshes player investment stock quotes during configured market hours.','cron','tennis-private-life-stock-quotes-v1',true,'high',15,90,true,195),
('cron:tennis-private-life-crypto-quotes-v1','Crypto quote refresh','Private Life','Refreshes player investment crypto quotes.','cron','tennis-private-life-crypto-quotes-v1',true,'high',15,45,true,196),
('check:admin_alert_email','Administrator alert email delivery','Core','Detects repeated failures in the system-alert email channel. This check is in-app only to avoid recursive email failures.','business_check',null,true,'critical',5,10,false,255)
on conflict(process_key) do update set
  label=excluded.label,category=excluded.category,description=excluded.description,
  source_kind=excluded.source_kind,source_ref=excluded.source_ref,user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,sort_order=excluded.sort_order,updated_at=now();

create or replace function public.log_system_business_checks_v1()
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_started timestamptz:=clock_timestamp();
  v_now_day integer:=public.national_team_current_abs_day_v1();
  v_now_second bigint:=public.current_game_second_v1();
  v_count integer;
  v_latest_day integer;
  v_rows integer:=0;
  v_clock jsonb;
begin
  select count(*) into v_count
  from public.tournament_matches m
  where m.status in ('scheduled','in_progress')
    and m.player1_id is not null and m.player2_id is not null
    and public.tournament_match_game_second_v1(m.id) < v_now_second-21600;
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:tournament_matches_overdue',case when v_count>0 then 'error' else 'success' end,v_started,clock_timestamp(),
         greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_count>0 then format('%s overdue singles match(es).',v_count) else 'No overdue singles matches.' end,
         jsonb_build_object('count',v_count,'current_game_second',v_now_second));
  v_rows:=v_rows+1;

  select count(*) into v_count
  from public.tournament_doubles_matches m
  where m.status in ('scheduled','in_progress')
    and m.team1_id is not null and m.team2_id is not null
    and public.doubles_match_game_second_v1(m.id) < v_now_second-21600;
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:doubles_matches_overdue',case when v_count>0 then 'error' else 'success' end,v_started,clock_timestamp(),
         greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_count>0 then format('%s overdue doubles match(es).',v_count) else 'No overdue doubles matches.' end,
         jsonb_build_object('count',v_count,'current_game_second',v_now_second));
  v_rows:=v_rows+1;

  select count(*) into v_count
  from public.player_travel_legs l
  join public.players plr on plr.id=l.player_id
  where plr.owner_user_id is not null
    and l.status='planned'
    and l.arrival_absolute_day < v_now_day-1;
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:travel_overdue',case when v_count>0 then 'error' else 'success' end,v_started,clock_timestamp(),
         greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_count>0 then format('%s overdue human travel leg(s).',v_count) else 'No overdue human travel legs.' end,
         jsonb_build_object('count',v_count,'current_absolute_day',v_now_day));
  v_rows:=v_rows+1;

  select max(game_absolute_day) into v_latest_day from public.ranking_publication_runs;
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:ranking_stale',
         case when v_latest_day is not null and v_latest_day<v_now_day-8 then 'error' else 'success' end,
         v_started,clock_timestamp(),greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_latest_day is not null and v_latest_day<v_now_day-8
              then format('Ranking publication is behind: latest day %s, current day %s.',v_latest_day,v_now_day)
              else 'Ranking publication freshness is within the expected window.' end,
         jsonb_build_object('latest_ranking_day',v_latest_day,'current_absolute_day',v_now_day));
  v_rows:=v_rows+1;

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
      where f.status='open' and f.deadline_game_day is not null and f.deadline_game_day<v_now_day-1)
    +
    (select count(*) from public.national_team_fixtures f
      where f.status not in ('completed','cancelled') and f.tie_end_absolute_day<v_now_day-1)
  into v_count;
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:national_team_deadlines',case when v_count>0 then 'warning' else 'success' end,v_started,clock_timestamp(),
         greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_count>0 then format('%s overdue national-team lifecycle item(s).',v_count) else 'National-team deadlines are healthy.' end,
         jsonb_build_object('count',v_count,'current_absolute_day',v_now_day));
  v_rows:=v_rows+1;

  select count(*) into v_count
  from public.birthday_email_outbox b
  where (b.status='failed' and b.attempts>=3)
     or (b.status='sending' and b.last_attempt_at<now()-interval '20 minutes');
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:email_outbox',case when v_count>0 then 'warning' else 'success' end,v_started,clock_timestamp(),
         greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_count>0 then format('%s birthday email job(s) repeatedly failing/stuck.',v_count) else 'Birthday email queue is healthy.' end,
         jsonb_build_object('count',v_count));
  v_rows:=v_rows+1;

  select jsonb_build_object('speed_multiplier',g.speed_multiplier,'real_anchor_at',g.real_anchor_at,'is_paused',g.is_paused)
  into v_clock
  from public.game_clock g where g.id=1;
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:game_clock',
         case when coalesce((v_clock->>'speed_multiplier')::numeric,0)<=0
                    or (v_clock->>'real_anchor_at')::timestamptz>now()+interval '5 minutes'
              then 'error' else 'success' end,
         v_started,clock_timestamp(),greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when coalesce((v_clock->>'speed_multiplier')::numeric,0)<=0
                    or (v_clock->>'real_anchor_at')::timestamptz>now()+interval '5 minutes'
              then 'Game clock configuration is invalid.' else 'Game clock configuration is valid.' end,
         coalesce(v_clock,'{}'::jsonb));
  v_rows:=v_rows+1;

  select count(*) into v_count
  from public.system_alert_email_outbox o
  join public.system_incidents i on i.id=o.incident_id
  where i.status in ('open','acknowledged')
    and ((o.status='failed' and o.attempts>=3)
      or (o.status='sending' and o.last_attempt_at<now()-interval '20 minutes'));
  insert into public.system_monitor_runs(process_key,status,started_at,finished_at,duration_ms,summary,details)
  values('check:admin_alert_email',case when v_count>0 then 'error' else 'success' end,v_started,clock_timestamp(),
         greatest(0,(extract(epoch from(clock_timestamp()-v_started))*1000)::bigint),
         case when v_count>0 then format('%s administrator alert email job(s) repeatedly failing/stuck.',v_count) else 'Administrator alert email channel is healthy.' end,
         jsonb_build_object('count',v_count));
  v_rows:=v_rows+1;

  return v_rows;
end;
$$;

revoke all on function public.log_system_business_checks_v1() from public,anon,authenticated;

CREATE OR REPLACE FUNCTION public.run_system_health_watchdog_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'cron', 'pg_temp'
AS $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_now_day integer:=public.national_team_current_abs_day_v1();
  v_now_second bigint:=public.current_game_second_v1();
  v_synced integer:=0;
  v_issues integer:=0;
  v_count integer;
  v_latest timestamptz;
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
      perform public.resolve_system_incident_by_dedupe_v1('cron-disabled:'||p.source_ref,'The scheduled job is active again.');
    end if;

    if p.stale_after_minutes is not null then
      select max(d.start_time) into v_latest
      from cron.job_run_details d
      join cron.job j on j.jobid=d.jobid
      where j.jobname=p.source_ref;

      if v_latest is null or v_latest < now()-(p.stale_after_minutes||' minutes')::interval then
        perform public.raise_system_incident_v1(
          p.process_key,p.incident_severity,'Scheduled process is overdue',
          format('No run of "%s" has started within the expected %s-minute health window.',p.label,p.stale_after_minutes),
          'cron-stale:'||p.source_ref,
          jsonb_build_object('job_name',p.source_ref,'last_run_at',v_latest,'stale_after_minutes',p.stale_after_minutes)
        );
        v_issues:=v_issues+1;
      else
        perform public.resolve_system_incident_by_dedupe_v1('cron-stale:'||p.source_ref,'Scheduler activity returned to the expected cadence.');
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
      (o.status='failed' and o.attempts>=3)
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

select public.run_system_health_watchdog_v1();
