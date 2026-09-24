
create table if not exists public.system_monitor_processes (
  process_key text primary key,
  label text not null,
  category text not null,
  description text not null default '',
  source_kind text not null check (source_kind in ('cron','watchdog','business_check','external')),
  source_ref text,
  user_sensitive boolean not null default false,
  incident_severity text not null default 'high' check (incident_severity in ('warning','high','critical')),
  expected_interval_minutes integer,
  stale_after_minutes integer,
  email_alerts_enabled boolean not null default true,
  is_enabled boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.system_monitor_runs (
  id uuid primary key default gen_random_uuid(),
  process_key text not null references public.system_monitor_processes(process_key) on delete cascade,
  source_run_id bigint,
  status text not null check (status in ('running','success','warning','error','stalled')),
  started_at timestamptz not null,
  finished_at timestamptz,
  duration_ms bigint,
  summary text,
  error_message text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists system_monitor_runs_source_uidx
  on public.system_monitor_runs(process_key,source_run_id)
  where source_run_id is not null;
create index if not exists system_monitor_runs_process_started_idx
  on public.system_monitor_runs(process_key,started_at desc);
create index if not exists system_monitor_runs_status_started_idx
  on public.system_monitor_runs(status,started_at desc);

create table if not exists public.system_incidents (
  id uuid primary key default gen_random_uuid(),
  process_key text not null references public.system_monitor_processes(process_key) on delete restrict,
  severity text not null check (severity in ('warning','high','critical')),
  status text not null default 'open' check (status in ('open','acknowledged','resolved')),
  title text not null,
  message text not null,
  dedupe_key text not null,
  details jsonb not null default '{}'::jsonb,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  occurrence_count integer not null default 1,
  last_emailed_at timestamptz,
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users(id) on delete set null,
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists system_incidents_active_dedupe_uidx
  on public.system_incidents(dedupe_key)
  where status in ('open','acknowledged');
create index if not exists system_incidents_status_severity_idx
  on public.system_incidents(status,severity,last_seen_at desc);

create table if not exists public.system_incident_admin_reads (
  incident_id uuid not null references public.system_incidents(id) on delete cascade,
  admin_user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(incident_id,admin_user_id)
);

create table if not exists public.system_alert_email_outbox (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.system_incidents(id) on delete cascade,
  recipient_user_id uuid references auth.users(id) on delete set null,
  recipient_email text not null,
  subject text not null,
  text_body text not null,
  html_body text not null,
  status text not null default 'pending' check(status in ('pending','sending','sent','failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  provider_message_id text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists system_alert_email_outbox_pending_idx
  on public.system_alert_email_outbox(status,next_attempt_at)
  where status in ('pending','failed');

alter table public.system_monitor_processes enable row level security;
alter table public.system_monitor_runs enable row level security;
alter table public.system_incidents enable row level security;
alter table public.system_incident_admin_reads enable row level security;
alter table public.system_alert_email_outbox enable row level security;

revoke all on public.system_monitor_processes from public,anon,authenticated;
revoke all on public.system_monitor_runs from public,anon,authenticated;
revoke all on public.system_incidents from public,anon,authenticated;
revoke all on public.system_incident_admin_reads from public,anon,authenticated;
revoke all on public.system_alert_email_outbox from public,anon,authenticated;

insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
('cron:tennis-match-replay-clock-v1','Match engine / replay clock','Matches','Processes due match replay progression and completion.','cron','tennis-match-replay-clock-v1',true,'critical',1,5,true,10),
('cron:tennis-entry-lifecycle-v2','Tournament entry lifecycle','Tournaments','Processes tournament application deadlines, field locks and draw readiness.','cron','tennis-entry-lifecycle-v2',true,'critical',5,15,true,20),
('cron:tennis-draw-publication-v1','Tournament draw publication','Tournaments','Publishes due tournament draws.','cron','tennis-draw-publication-v1',true,'critical',60,120,true,30),
('cron:tennis-human-career-days-v1','Human career day processing','Player state','Processes human training, recovery, travel and daily career effects to current game day.','cron','tennis-human-career-days-v1',true,'critical',5,15,true,40),
('cron:process-human-finance-hourly-v1','Human finance processing','Finance','Processes due player finance, tax and recurring financial events.','cron','process-human-finance-hourly-v1',true,'critical',60,120,true,50),
('cron:tennis-weekly-rankings-v1','Weekly rankings','Rankings','Publishes due singles rankings and downstream doubles rankings.','cron','tennis-weekly-rankings-v1',true,'critical',60,120,true,60),
('cron:tennis_legacy_staff_market_maintenance','Staff market / contracts','Staff','Maintains staff salaries, expiries and available staff market.','cron','tennis_legacy_staff_market_maintenance',true,'high',60,120,true,70),
('cron:tennis-injury-recovery-hourly','Injury recovery','Health','Processes due injury recovery for players.','cron','tennis-injury-recovery-hourly',true,'high',60,120,true,80),
('cron:process-sponsor-objectives-hourly-v1','Sponsor objectives','Finance','Processes human sponsor objectives and progress.','cron','process-sponsor-objectives-hourly-v1',true,'high',60,120,true,90),
('cron:tennis-private-life-costs-v1','Private-life recurring costs','Private Life','Processes recurring ownership and lifestyle costs.','cron','tennis-private-life-costs-v1',true,'high',5,15,true,100),
('cron:tennis-private-life-sales-v1','Private-life asset sales','Private Life','Settles due player asset sales.','cron','tennis-private-life-sales-v1',true,'high',5,15,true,110),
('cron:tennis-private-life-asset-market-v1','Private-life asset market','Private Life','Advances asset-market values to current game time.','cron','tennis-private-life-asset-market-v1',true,'high',5,15,true,120),
('cron:tennis-private-life-property-market-v1','Private-life property market','Private Life','Advances property-market values to current game time.','cron','tennis-private-life-property-market-v1',true,'high',5,15,true,130),
('cron:tennis-birthday-rewards-v1','Birthday reward processing','Messaging','Creates real-birthday rewards and corresponding email jobs.','cron','tennis-birthday-rewards-v1',true,'high',60,120,true,140),
('cron:tennis-birthday-email-dispatch-v1','Birthday email dispatch','Messaging','Dispatches queued birthday emails through Resend.','cron','tennis-birthday-email-dispatch-v1',true,'high',60,120,true,150),
('check:tournament_matches_overdue','Overdue singles matches','Matches','Detects scheduled/in-progress singles matches that passed their expected processing time.','business_check',null,true,'critical',5,10,true,200),
('check:doubles_matches_overdue','Overdue doubles matches','Matches','Detects scheduled/in-progress doubles matches that passed their expected processing time.','business_check',null,true,'critical',5,10,true,210),
('check:travel_overdue','Overdue travel legs','Travel','Detects player travel legs still planned after their arrival day.','business_check',null,true,'critical',5,10,true,220),
('check:ranking_stale','Ranking publication freshness','Rankings','Detects when ranking publication has fallen materially behind game time.','business_check',null,true,'critical',60,120,true,230),
('check:national_team_deadlines','National-team lifecycle deadlines','National Team','Detects overdue elections, renewal funds or national fixtures.','business_check',null,true,'high',5,10,true,240),
('check:email_outbox','System email delivery','Messaging','Detects email jobs repeatedly failing or stuck in sending state.','business_check',null,true,'high',5,10,true,250),
('check:game_clock','Game clock sanity','Core','Detects invalid clock anchors or invalid running speed values.','business_check',null,true,'critical',5,10,true,260),
('watchdog:system-health','System health watchdog','Core','Synchronizes scheduler history and evaluates business-state health checks.','watchdog','tennis-system-health-watchdog-v1',true,'critical',5,15,true,1)
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

create or replace function public.queue_system_incident_email_v1(p_incident_id uuid)
returns integer
language plpgsql
security definer
set search_path=public,auth,pg_temp
as $$
declare
  v_inc public.system_incidents%rowtype;
  v_process public.system_monitor_processes%rowtype;
  v_count integer:=0;
  r record;
  v_subject text;
  v_text text;
  v_html text;
begin
  select * into v_inc from public.system_incidents where id=p_incident_id;
  if not found then return 0; end if;

  select * into v_process from public.system_monitor_processes where process_key=v_inc.process_key;
  if not found or not v_process.email_alerts_enabled then return 0; end if;

  v_subject:=format('[Tennis Legacy] %s system incident: %s',upper(v_inc.severity),v_inc.title);
  v_text:=format(
    E'Tennis Legacy detected a system problem.\n\nSeverity: %s\nProcess: %s\nCategory: %s\nFirst seen: %s\nLast seen: %s\n\n%s\n\nOpen the administrator System Health page for diagnostics.',
    upper(v_inc.severity),v_process.label,v_process.category,v_inc.first_seen_at,v_inc.last_seen_at,v_inc.message
  );
  v_html:=format(
    '<div style="font-family:Arial,sans-serif;color:#173149"><h2 style="margin:0 0 14px">Tennis Legacy system incident</h2><p><strong>Severity:</strong> %s<br><strong>Process:</strong> %s<br><strong>Category:</strong> %s<br><strong>First seen:</strong> %s<br><strong>Last seen:</strong> %s</p><p>%s</p><p><a href="https://www.tennislegacygame.com/game/admin/system-health">Open System Health</a></p></div>',
    upper(v_inc.severity),v_process.label,v_process.category,v_inc.first_seen_at,v_inc.last_seen_at,
    replace(replace(v_inc.message,'&','&amp;'),'<','&lt;')
  );

  for r in
    select u.id,u.email
    from auth.users u
    where u.email is not null
      and public.is_app_admin_v1(u.id)
  loop
    insert into public.system_alert_email_outbox(
      incident_id,recipient_user_id,recipient_email,subject,text_body,html_body,status
    )
    values(p_incident_id,r.id,r.email,v_subject,v_text,v_html,'pending');
    v_count:=v_count+1;
  end loop;

  update public.system_incidents
  set last_emailed_at=now(),updated_at=now()
  where id=p_incident_id;

  return v_count;
end;
$$;

create or replace function public.raise_system_incident_v1(
  p_process_key text,
  p_severity text,
  p_title text,
  p_message text,
  p_dedupe_key text,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_id uuid;
  v_previous_email timestamptz;
  v_previous_severity text;
  v_should_email boolean:=false;
  v_severity text:=lower(coalesce(p_severity,'high'));
begin
  if v_severity not in ('warning','high','critical') then v_severity:='high'; end if;

  select id,last_emailed_at,severity
  into v_id,v_previous_email,v_previous_severity
  from public.system_incidents
  where dedupe_key=p_dedupe_key
    and status in ('open','acknowledged')
  order by created_at desc
  limit 1
  for update;

  if v_id is null then
    insert into public.system_incidents(
      process_key,severity,status,title,message,dedupe_key,details
    )
    values(
      p_process_key,v_severity,'open',p_title,p_message,p_dedupe_key,coalesce(p_details,'{}'::jsonb)
    )
    returning id into v_id;
    v_should_email:=true;
  else
    update public.system_incidents
    set severity=case
          when severity='critical' then severity
          when severity='high' and v_severity='warning' then severity
          else v_severity
        end,
        status=case when status='acknowledged' then 'acknowledged' else 'open' end,
        title=p_title,
        message=p_message,
        details=coalesce(p_details,'{}'::jsonb),
        last_seen_at=now(),
        occurrence_count=occurrence_count+1,
        updated_at=now()
    where id=v_id;

    v_should_email :=
      v_previous_email is null
      or v_previous_email < now()-interval '6 hours'
      or (v_previous_severity='warning' and v_severity in ('high','critical'))
      or (v_previous_severity='high' and v_severity='critical');
  end if;

  if v_should_email then
    perform public.queue_system_incident_email_v1(v_id);
  end if;

  return v_id;
end;
$$;

create or replace function public.resolve_system_incident_by_dedupe_v1(
  p_dedupe_key text,
  p_note text default 'Recovered automatically.'
)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare v_count integer;
begin
  update public.system_incidents
  set status='resolved',
      resolved_at=coalesce(resolved_at,now()),
      resolution_note=coalesce(nullif(p_note,''),'Recovered automatically.'),
      updated_at=now()
  where dedupe_key=p_dedupe_key
    and status in ('open','acknowledged');
  get diagnostics v_count=row_count;
  return v_count;
end;
$$;

create or replace function public.sync_system_cron_runs_v1()
returns integer
language plpgsql
security definer
set search_path=public,cron,pg_temp
as $$
declare
  r record;
  v_key text;
  v_count integer:=0;
begin
  for r in
    select j.jobname,d.runid,d.status,d.return_message,d.start_time,d.end_time
    from cron.job_run_details d
    join cron.job j on j.jobid=d.jobid
    where d.start_time>=now()-interval '48 hours'
    order by d.start_time
  loop
    v_key:='cron:'||r.jobname;

    if not exists(select 1 from public.system_monitor_processes where process_key=v_key) then
      continue;
    end if;

    insert into public.system_monitor_runs(
      process_key,source_run_id,status,started_at,finished_at,duration_ms,summary,error_message,details
    )
    values(
      v_key,
      r.runid,
      case when r.status='succeeded' then 'success' else 'error' end,
      r.start_time,
      r.end_time,
      case when r.end_time is not null then greatest(0,(extract(epoch from (r.end_time-r.start_time))*1000)::bigint) else null end,
      case when r.status='succeeded' then coalesce(nullif(r.return_message,''),'Completed') else 'Scheduled process failed' end,
      case when r.status='succeeded' then null else coalesce(r.return_message,'Unknown pg_cron failure') end,
      jsonb_build_object('cron_status',r.status,'return_message',r.return_message)
    )
    on conflict(process_key,source_run_id) where source_run_id is not null do nothing;

    if found then v_count:=v_count+1; end if;

    if r.status<>'succeeded' then
      perform public.raise_system_incident_v1(
        v_key,
        (select incident_severity from public.system_monitor_processes where process_key=v_key),
        'Scheduled process failed',
        format('%s failed at %s. %s',r.jobname,r.start_time,coalesce(r.return_message,'No return message.')),
        'cron-failure:'||r.jobname,
        jsonb_build_object('job_name',r.jobname,'run_id',r.runid,'return_message',r.return_message,'started_at',r.start_time)
      );
    else
      perform public.resolve_system_incident_by_dedupe_v1('cron-failure:'||r.jobname,'A later scheduled run completed successfully.');
    end if;
  end loop;

  return v_count;
end;
$$;

create or replace function public.run_system_health_watchdog_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,cron,pg_temp
as $$
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
  where l.status='planned'
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
$$;

create or replace function public.get_admin_system_incident_unread_count_v1()
returns integer
language sql
stable
security definer
set search_path=public
as $$
  select case
    when auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then 0
    else (
      select count(*)::integer
      from public.system_incidents i
      where i.status in ('open','acknowledged')
        and not exists(
          select 1 from public.system_incident_admin_reads r
          where r.incident_id=i.id and r.admin_user_id=auth.uid()
        )
    )
  end;
$$;

create or replace function public.get_admin_system_health_overview_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,cron,pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  with process_rows as (
    select
      p.*,
      lr.status latest_status,
      lr.started_at latest_started_at,
      lr.finished_at latest_finished_at,
      lr.duration_ms latest_duration_ms,
      lr.summary latest_summary,
      lr.error_message latest_error_message,
      cj.active cron_active,
      (
        select count(*)::integer
        from public.system_incidents i
        where i.process_key=p.process_key and i.status in ('open','acknowledged')
      ) open_incidents
    from public.system_monitor_processes p
    left join lateral (
      select r.*
      from public.system_monitor_runs r
      where r.process_key=p.process_key
      order by r.started_at desc
      limit 1
    ) lr on true
    left join cron.job cj on p.source_kind='cron' and cj.jobname=p.source_ref
    where p.is_enabled
  )
  select jsonb_build_object(
    'summary',jsonb_build_object(
      'open_incidents',(select count(*) from public.system_incidents where status in ('open','acknowledged')),
      'critical_incidents',(select count(*) from public.system_incidents where status in ('open','acknowledged') and severity='critical'),
      'high_incidents',(select count(*) from public.system_incidents where status in ('open','acknowledged') and severity='high'),
      'warning_incidents',(select count(*) from public.system_incidents where status in ('open','acknowledged') and severity='warning'),
      'monitored_processes',(select count(*) from public.system_monitor_processes where is_enabled),
      'user_sensitive_processes',(select count(*) from public.system_monitor_processes where is_enabled and user_sensitive)
    ),
    'processes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'process_key',process_key,'label',label,'category',category,'description',description,
        'source_kind',source_kind,'source_ref',source_ref,'user_sensitive',user_sensitive,
        'incident_severity',incident_severity,'expected_interval_minutes',expected_interval_minutes,
        'stale_after_minutes',stale_after_minutes,'latest_status',latest_status,
        'latest_started_at',latest_started_at,'latest_finished_at',latest_finished_at,
        'latest_duration_ms',latest_duration_ms,'latest_summary',latest_summary,
        'latest_error_message',latest_error_message,'cron_active',cron_active,
        'open_incidents',open_incidents
      ) order by sort_order,label)
      from process_rows
    ),'[]'::jsonb),
    'incidents',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',i.id,'process_key',i.process_key,'process_label',p.label,'category',p.category,
        'severity',i.severity,'status',i.status,'title',i.title,'message',i.message,
        'details',i.details,'first_seen_at',i.first_seen_at,'last_seen_at',i.last_seen_at,
        'occurrence_count',i.occurrence_count,'last_emailed_at',i.last_emailed_at,
        'acknowledged_at',i.acknowledged_at,'resolved_at',i.resolved_at,
        'is_unread',not exists(
          select 1 from public.system_incident_admin_reads rr
          where rr.incident_id=i.id and rr.admin_user_id=auth.uid()
        )
      ) order by
        case i.severity when 'critical' then 1 when 'high' then 2 else 3 end,
        i.last_seen_at desc)
      from public.system_incidents i
      join public.system_monitor_processes p on p.process_key=i.process_key
      where i.status in ('open','acknowledged')
    ),'[]'::jsonb),
    'recent_runs',coalesce((
      select jsonb_agg(x.obj order by x.started_at desc)
      from (
        select jsonb_build_object(
          'id',r.id,'process_key',r.process_key,'process_label',p.label,'category',p.category,
          'status',r.status,'started_at',r.started_at,'finished_at',r.finished_at,
          'duration_ms',r.duration_ms,'summary',r.summary,'error_message',r.error_message,
          'details',r.details
        ) obj,r.started_at
        from public.system_monitor_runs r
        join public.system_monitor_processes p on p.process_key=r.process_key
        order by r.started_at desc
        limit 100
      ) x
    ),'[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.get_admin_system_runs_v1(
  p_process_key text default null,
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,'process_key',x.process_key,'process_label',x.label,'category',x.category,
    'status',x.status,'started_at',x.started_at,'finished_at',x.finished_at,
    'duration_ms',x.duration_ms,'summary',x.summary,'error_message',x.error_message,
    'details',x.details
  ) order by x.started_at desc),'[]'::jsonb)
  into v_result
  from (
    select r.*,p.label,p.category
    from public.system_monitor_runs r
    join public.system_monitor_processes p on p.process_key=r.process_key
    where p_process_key is null or r.process_key=p_process_key
    order by r.started_at desc
    limit greatest(1,least(coalesce(p_limit,200),1000))
  ) x;

  return v_result;
end;
$$;

create or replace function public.mark_admin_system_incident_read_v1(p_incident_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;
  insert into public.system_incident_admin_reads(incident_id,admin_user_id,read_at)
  values(p_incident_id,auth.uid(),now())
  on conflict(incident_id,admin_user_id) do update set read_at=excluded.read_at;
end;
$$;

create or replace function public.admin_update_system_incident_v1(
  p_incident_id uuid,
  p_action text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_action text:=lower(trim(coalesce(p_action,'')));
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if v_action='acknowledge' then
    update public.system_incidents
    set status='acknowledged',acknowledged_at=now(),acknowledged_by=auth.uid(),updated_at=now()
    where id=p_incident_id and status='open';
  elsif v_action='resolve' then
    update public.system_incidents
    set status='resolved',resolved_at=now(),resolved_by=auth.uid(),
        resolution_note=coalesce(nullif(trim(p_note),''),'Resolved by administrator.'),updated_at=now()
    where id=p_incident_id and status in ('open','acknowledged');
  elsif v_action='reopen' then
    update public.system_incidents
    set status='open',resolved_at=null,resolved_by=null,resolution_note=null,updated_at=now()
    where id=p_incident_id and status='resolved';
  else
    raise exception 'Invalid incident action.';
  end if;

  if not found then raise exception 'Incident not found or action is not valid for its current status.'; end if;

  perform public.mark_admin_system_incident_read_v1(p_incident_id);
  return jsonb_build_object('id',p_incident_id,'action',v_action);
end;
$$;

create or replace function public.claim_system_alert_email_outbox_v1(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare v_rows jsonb;
begin
  with candidates as (
    select o.id
    from public.system_alert_email_outbox o
    where o.status in ('pending','failed')
      and o.next_attempt_at<=now()
      and o.attempts<10
    order by o.created_at
    for update skip locked
    limit greatest(1,least(coalesce(p_limit,20),50))
  ), claimed as (
    update public.system_alert_email_outbox o
    set status='sending',attempts=o.attempts+1,last_attempt_at=now(),last_error=null,updated_at=now()
    from candidates c
    where o.id=c.id
    returning o.id,o.incident_id,o.recipient_user_id,o.recipient_email,o.subject,o.text_body,o.html_body,o.attempts
  )
  select coalesce(jsonb_agg(to_jsonb(claimed)),'[]'::jsonb) into v_rows from claimed;
  return v_rows;
end;
$$;

create schema if not exists private;
revoke all on schema private from public,anon,authenticated;

insert into private.internal_job_secrets(job_name)
values('system_alert_dispatch_v1')
on conflict(job_name) do nothing;

create or replace function public.validate_system_alert_cron_token_v1(p_token text)
returns boolean
language sql
stable
security definer
set search_path=public,private,pg_temp
as $$
  select exists(
    select 1 from private.internal_job_secrets s
    where s.job_name='system_alert_dispatch_v1' and s.secret=p_token
  );
$$;

revoke all on function public.queue_system_incident_email_v1(uuid) from public,anon,authenticated;
revoke all on function public.raise_system_incident_v1(text,text,text,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.resolve_system_incident_by_dedupe_v1(text,text) from public,anon,authenticated;
revoke all on function public.sync_system_cron_runs_v1() from public,anon,authenticated;
revoke all on function public.run_system_health_watchdog_v1() from public,anon,authenticated;
revoke all on function public.get_admin_system_incident_unread_count_v1() from public,anon,authenticated;
revoke all on function public.get_admin_system_health_overview_v1() from public,anon,authenticated;
revoke all on function public.get_admin_system_runs_v1(text,integer) from public,anon,authenticated;
revoke all on function public.mark_admin_system_incident_read_v1(uuid) from public,anon,authenticated;
revoke all on function public.admin_update_system_incident_v1(uuid,text,text) from public,anon,authenticated;
revoke all on function public.claim_system_alert_email_outbox_v1(integer) from public,anon,authenticated;
revoke all on function public.validate_system_alert_cron_token_v1(text) from public,anon,authenticated;

grant execute on function public.get_admin_system_incident_unread_count_v1() to authenticated;
grant execute on function public.get_admin_system_health_overview_v1() to authenticated;
grant execute on function public.get_admin_system_runs_v1(text,integer) to authenticated;
grant execute on function public.mark_admin_system_incident_read_v1(uuid) to authenticated;
grant execute on function public.admin_update_system_incident_v1(uuid,text,text) to authenticated;
grant execute on function public.claim_system_alert_email_outbox_v1(integer) to service_role;
grant execute on function public.validate_system_alert_cron_token_v1(text) to service_role;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='system_incidents'
  ) then
    alter publication supabase_realtime add table public.system_incidents;
  end if;
end $$;

do $$
declare v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname='tennis-system-health-watchdog-v1' limit 1;
  if v_jobid is not null then perform cron.unschedule(v_jobid); end if;
end $$;

select cron.schedule(
  'tennis-system-health-watchdog-v1',
  '*/5 * * * *',
  $$select public.run_system_health_watchdog_v1();$$
);

do $$
declare v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname='tennis-system-alert-email-dispatch-v1' limit 1;
  if v_jobid is not null then perform cron.unschedule(v_jobid); end if;
end $$;

select cron.schedule(
  'tennis-system-alert-email-dispatch-v1',
  '*/2 * * * *',
  $$select net.http_post(
    url := 'https://cwfznmroiqcyhfkfcrow.supabase.co/functions/v1/send-system-alerts',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := jsonb_build_object(
      'cron_token',
      (select secret from private.internal_job_secrets where job_name='system_alert_dispatch_v1')
    )
  );$$
);

select public.run_system_health_watchdog_v1();
