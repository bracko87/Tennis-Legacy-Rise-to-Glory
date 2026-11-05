-- Tennis Legacy: Game Control Center reliability and cross-product webhook isolation.
-- Reconciles the production hotfix with the version-controlled schema.
-- Avoids full cron-history scans, skips pre-start rows, and keeps retention bounded.
-- Foreign subscriptions require correlated independent evidence and never
-- grant Tennis Legacy coins or change subscription state.
-- Preserve the deliberately disabled incident-email jobs: GCC push-only policy.

CREATE OR REPLACE FUNCTION public.sync_system_cron_runs_v1()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'cron', 'pg_temp'
AS $function$
declare
  v_count integer:=0;
  r record;
  v_key text;
begin
  insert into public.system_monitor_runs(
    process_key,source_run_id,status,started_at,finished_at,duration_ms,summary,error_message,details
  )
  select
    p.process_key,
    d.runid,
    case
      when d.status='succeeded' then 'success'
      when d.status='failed' then 'error'
      else 'running'
    end,
    d.start_time,
    d.end_time,
    case when d.end_time is not null
      then greatest(0,(extract(epoch from (d.end_time-d.start_time))*1000)::bigint)
      else null
    end,
    case
      when d.status='succeeded' then coalesce(nullif(d.return_message,''),'Completed')
      when d.status='failed' then 'Scheduled process failed'
      else 'Scheduled process is running'
    end,
    case when d.status='failed' then coalesce(d.return_message,'Unknown pg_cron failure') else null end,
    jsonb_build_object('cron_status',d.status,'return_message',d.return_message)
  from cron.job_run_details d
  join cron.job j on j.jobid=d.jobid
  join public.system_monitor_processes p
    on p.source_kind='cron'
   and p.source_ref=j.jobname
   and p.is_enabled
  where d.runid >= greatest(0, (select max(runid) from cron.job_run_details) - 5000)
    and d.start_time is not null
  on conflict(process_key,source_run_id) where source_run_id is not null do update
  set status=excluded.status,
      finished_at=excluded.finished_at,
      duration_ms=excluded.duration_ms,
      summary=excluded.summary,
      error_message=excluded.error_message,
      details=excluded.details
  where system_monitor_runs.status is distinct from excluded.status
     or system_monitor_runs.finished_at is distinct from excluded.finished_at
     or system_monitor_runs.duration_ms is distinct from excluded.duration_ms
     or system_monitor_runs.summary is distinct from excluded.summary
     or system_monitor_runs.error_message is distinct from excluded.error_message
     or system_monitor_runs.details is distinct from excluded.details;

  get diagnostics v_count=row_count;

  -- Incident state follows the latest completed run. A run in progress at
  -- this same cron minute must not mask an already successful recovery.
  for r in
    select
      j.jobname,d.runid,d.status,d.return_message,d.start_time,d.end_time,
      p.process_key,p.incident_severity
    from cron.job j
    join public.system_monitor_processes p
      on p.source_kind='cron'
     and p.source_ref=j.jobname
     and p.is_enabled
    left join lateral (
      select m.source_run_id as runid,
             case when m.status='success' then 'succeeded' else 'failed' end as status,
             m.details->>'return_message' as return_message,
             m.started_at as start_time,
             m.finished_at as end_time
      from public.system_monitor_runs m
      where m.process_key=p.process_key
        and m.source_run_id is not null
        and m.status in ('success','error')
      order by m.started_at desc
      limit 1
    ) d on true
  loop
    v_key:=r.process_key;

    if r.runid is null then
      continue;
    elsif r.status='failed' then
      perform public.raise_system_incident_v1(
        v_key,
        r.incident_severity,
        'Scheduled process failed',
        format('%s failed at %s. %s',r.jobname,r.start_time,coalesce(r.return_message,'No return message.')),
        'cron-failure:'||r.jobname,
        jsonb_build_object('job_name',r.jobname,'run_id',r.runid,'return_message',r.return_message,'started_at',r.start_time)
      );
    elsif r.status='succeeded' then
      perform public.resolve_system_incident_by_dedupe_v1(
        'cron-failure:'||r.jobname,
        'The latest scheduled run completed successfully.'
      );
    end if;
  end loop;

  return v_count;
end;
$function$
;

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

      select m.started_at into v_latest
      from public.system_monitor_runs m
      where m.process_key=p.process_key
        and m.source_run_id is not null
      order by m.started_at desc
      limit 1;

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
$function$
;

CREATE OR REPLACE FUNCTION public.try_process_tennis_stripe_event_v2(p_event_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_event record;
  v_obj jsonb;
  v_user uuid;
  v_intent uuid;
  v_intent_status text;
  v_kind text;
  v_meta_kind text;
  v_coins integer;
  v_meta_coins integer;
  v_expected integer;
  v_amount integer;
  v_balance bigint;
  v_subscription text;
  v_customer text;
  v_invoice text;
  v_session text;
  v_catalog text;
  v_status text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_price_id text;
  v_period_months integer:=1;
  v_monthly_equivalent integer:=329;
  v_monthly_reward integer:=30;
begin
  select * into v_event
  from public.stripe_webhook_events
  where event_id=p_event_id
  for update;

  if not found or v_event.processed then return true; end if;
  v_obj:=v_event.payload->'data'->'object';

  -- Ignore only demonstrably external subscriptions; never infer ownership
  -- from amount alone. Genuine Tennis events still wait for account mapping.
  if v_event.event_type in (
    'invoice.paid',
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted'
  ) then
    v_subscription:=case when v_event.event_type like 'customer.subscription.%'
      then v_obj->>'id'
      else coalesce(v_obj->>'subscription',
                    v_obj#>>'{parent,subscription_details,subscription}')
    end;
    v_price_id:=coalesce(
      v_obj#>>'{lines,data,0,pricing,price_details,price}',
      v_obj#>>'{lines,data,0,price,id}',
      v_obj#>>'{lines,data,0,plan,id}',
      v_obj#>>'{items,data,0,price,id}',
      v_obj#>>'{items,data,0,plan,id}'
    );
    if v_subscription is not null
       and v_price_id is not null
       and coalesce(v_obj#>>'{metadata,game}','') <> 'tennis_legacy'
       and not exists(
         select 1 from public.commerce_catalog_items c
         where c.stripe_price_id=v_price_id
       )
       and not exists(
         select 1 from public.premium_memberships pm
         where pm.stripe_subscription_id=v_subscription
            or pm.stripe_customer_id=v_obj->>'customer'
       )
       and exists(
         select 1 from public.stripe_webhook_events source
         where source.event_type in (
           'customer.subscription.created','customer.subscription.updated'
         )
           and source.payload#>>'{data,object,id}'=v_subscription
           and coalesce(source.payload#>>'{data,object,metadata,game}','') <> 'tennis_legacy'
           and nullif(source.payload#>>'{data,object,metadata,user_id}','') is not null
           and coalesce(
             source.payload#>>'{data,object,items,data,0,price,id}',
             source.payload#>>'{data,object,items,data,0,plan,id}'
           )=v_price_id
           and not exists(
             select 1 from auth.users u
             where u.id::text=source.payload#>>'{data,object,metadata,user_id}'
           )
       )
    then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),
          process_note='ignored_external_subscription'
      where event_id=p_event_id;
      return true;
    end if;
  end if;


  if v_event.event_type in ('checkout.session.completed','checkout.session.async_payment_succeeded') then
    if coalesce(v_obj->'metadata'->>'game','')<>'tennis_legacy' then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='ignored_non_tennis'
      where event_id=p_event_id;
      return true;
    end if;

    begin
      v_intent:=(v_obj->>'client_reference_id')::uuid;
    exception when others then
      v_intent:=null;
    end;

    if v_intent is null then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='invalid_checkout_intent_reference'
      where event_id=p_event_id;
      return true;
    end if;

    select user_id,catalog_code,status
    into v_user,v_catalog,v_intent_status
    from public.commerce_checkout_intents
    where id=v_intent
    for update;

    if v_user is null then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='unknown_checkout_intent'
      where event_id=p_event_id;
      return true;
    end if;

    v_session:=v_obj->>'id';
    v_customer:=v_obj->>'customer';
    v_subscription:=v_obj->>'subscription';
    v_meta_kind:=v_obj->'metadata'->>'kind';

    if v_intent_status='completed' then
      if exists(
        select 1 from public.commerce_checkout_intents
        where id=v_intent and stripe_checkout_session_id=v_session
      ) then
        update public.stripe_webhook_events
        set processed=true,processed_at=now(),process_note='already_fulfilled'
        where event_id=p_event_id;
        return true;
      end if;

      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='checkout_intent_already_used'
      where event_id=p_event_id;
      return true;
    end if;

    select kind,coins,price_eur_cents,stripe_price_id
    into v_kind,v_coins,v_expected,v_price_id
    from public.commerce_catalog_items
    where code=v_catalog and is_active;

    if v_kind is null then
      raise exception 'Inactive or missing commerce catalog item for Stripe event %',p_event_id;
    end if;

    v_amount:=coalesce((v_obj->>'amount_total')::integer,0);
    begin
      v_meta_coins:=coalesce((v_obj->'metadata'->>'coins')::integer,0);
    exception when others then
      v_meta_coins:=0;
    end;

    if v_kind='coin_pack' then
      if v_meta_kind<>'coin_pack'
         or v_meta_coins<>v_coins
         or v_amount<>v_expected
      then
        raise exception 'Stripe coin pack validation failed for event %',p_event_id;
      end if;

      if coalesce(v_obj->>'payment_status','')<>'paid' then
        update public.stripe_webhook_events
        set processed=true,processed_at=now(),process_note='awaiting_async_payment_succeeded'
        where event_id=p_event_id;
        return true;
      end if;

      if exists(select 1 from public.billing_transactions where stripe_checkout_session_id=v_session) then
        update public.commerce_checkout_intents
        set status='completed',stripe_checkout_session_id=v_session,completed_at=coalesce(completed_at,now())
        where id=v_intent;
        update public.stripe_webhook_events
        set processed=true,processed_at=now(),process_note='already_fulfilled'
        where event_id=p_event_id;
        return true;
      end if;

      insert into public.user_wallets(user_id)
      values(v_user)
      on conflict(user_id) do nothing;

      update public.user_wallets
      set coins_balance=coins_balance+v_coins,
          lifetime_coins_earned=lifetime_coins_earned+v_coins,
          updated_at=now()
      where user_id=v_user
      returning coins_balance into v_balance;

      insert into public.coin_ledger(
        user_id,amount,balance_after,entry_type,description,reference_id
      )
      values(
        v_user,v_coins,v_balance,'coin_purchase',v_coins||' Coin Pack','stripe_session:'||v_session
      );

      insert into public.billing_transactions(
        user_id,kind,status,amount_eur_cents,coins_amount,description,
        stripe_checkout_session_id,stripe_payment_intent_id,stripe_customer_id,catalog_code
      )
      values(
        v_user,'coin_pack_purchase','paid',v_amount,v_coins,v_coins||' Coin Pack',
        v_session,v_obj->>'payment_intent',v_customer,v_catalog
      );

      update public.commerce_checkout_intents
      set status='completed',stripe_checkout_session_id=v_session,completed_at=now()
      where id=v_intent;

    elsif v_kind='premium' then
      if v_meta_kind<>'premium'
         or v_catalog not in ('premium_monthly','premium_quarterly','premium_yearly')
         or v_amount<>v_expected
      then
        raise exception 'Stripe Premium validation failed for event %',p_event_id;
      end if;

      v_period_months:=case v_catalog
        when 'premium_quarterly' then 3
        when 'premium_yearly' then 12
        else 1
      end;
      v_monthly_equivalent:=round(v_expected::numeric/v_period_months)::integer;

      insert into public.premium_memberships(
        user_id,plan_code,status,started_at,monthly_price_eur_cents,monthly_coin_reward,
        stripe_customer_id,stripe_subscription_id,billing_plan_code,billing_period_months,
        billing_amount_eur_cents,coins_per_payment,stripe_price_id
      )
      values(
        v_user,'premium','active',now(),v_monthly_equivalent,30,
        v_customer,v_subscription,v_catalog,v_period_months,v_expected,v_coins,v_price_id
      )
      on conflict(user_id) do update set
        plan_code='premium',
        status='active',
        monthly_price_eur_cents=v_monthly_equivalent,
        monthly_coin_reward=30,
        stripe_customer_id=coalesce(excluded.stripe_customer_id,premium_memberships.stripe_customer_id),
        stripe_subscription_id=coalesce(excluded.stripe_subscription_id,premium_memberships.stripe_subscription_id),
        billing_plan_code=v_catalog,
        billing_period_months=v_period_months,
        billing_amount_eur_cents=v_expected,
        coins_per_payment=v_coins,
        stripe_price_id=v_price_id,
        cancel_at_period_end=false,
        updated_at=now();

      update public.commerce_checkout_intents
      set status='completed',stripe_checkout_session_id=v_session,completed_at=now()
      where id=v_intent;
    end if;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  if v_event.event_type='invoice.paid' then
    v_invoice:=v_obj->>'id';
    v_customer:=v_obj->>'customer';
    v_subscription:=coalesce(
      v_obj->>'subscription',
      v_obj#>>'{parent,subscription_details,subscription}'
    );

    select user_id into v_user
    from public.premium_memberships
    where stripe_subscription_id=v_subscription
       or (v_subscription is null and stripe_customer_id=v_customer and plan_code='premium')
    limit 1;

    if v_user is null then
      update public.stripe_webhook_events
      set process_note='waiting_for_subscription_mapping'
      where event_id=p_event_id;
      return false;
    end if;

    v_price_id:=coalesce(
      v_obj#>>'{lines,data,0,pricing,price_details,price}',
      v_obj#>>'{lines,data,0,price,id}',
      v_obj#>>'{lines,data,0,plan,id}'
    );

    select code,coins,price_eur_cents
    into v_catalog,v_coins,v_expected
    from public.commerce_catalog_items
    where kind='premium'
      and is_active
      and stripe_price_id=v_price_id
    limit 1;

    if v_catalog is null then
      select billing_plan_code,coins_per_payment,billing_amount_eur_cents,stripe_price_id
      into v_catalog,v_coins,v_expected,v_price_id
      from public.premium_memberships
      where user_id=v_user;
    end if;

    if v_catalog not in ('premium_monthly','premium_quarterly','premium_yearly') then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='ignored_unknown_premium_invoice'
      where event_id=p_event_id;
      return true;
    end if;

    v_amount:=coalesce((v_obj->>'amount_paid')::integer,0);

    if v_amount<>v_expected then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='ignored_non_current_premium_invoice'
      where event_id=p_event_id;
      return true;
    end if;

    if exists(select 1 from public.billing_transactions where stripe_invoice_id=v_invoice) then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='already_fulfilled'
      where event_id=p_event_id;
      return true;
    end if;

    v_period_months:=case v_catalog
      when 'premium_quarterly' then 3
      when 'premium_yearly' then 12
      else 1
    end;
    v_monthly_equivalent:=round(v_expected::numeric/v_period_months)::integer;
    v_coins:=coalesce(v_coins,30*v_period_months);

    insert into public.user_wallets(user_id)
    values(v_user)
    on conflict(user_id) do nothing;

    update public.user_wallets
    set coins_balance=coins_balance+v_coins,
        lifetime_coins_earned=lifetime_coins_earned+v_coins,
        updated_at=now()
    where user_id=v_user
    returning coins_balance into v_balance;

    insert into public.coin_ledger(
      user_id,amount,balance_after,entry_type,description,reference_id
    )
    values(
      v_user,v_coins,v_balance,'premium_reward',
      case
        when v_period_months=12 then 'Annual Premium coin reward'
        when v_period_months=3 then '3-month Premium coin reward'
        else 'Monthly Premium coin reward'
      end,
      'stripe_invoice:'||v_invoice
    );

    insert into public.billing_transactions(
      user_id,kind,status,amount_eur_cents,coins_amount,description,
      stripe_invoice_id,stripe_subscription_id,stripe_customer_id,catalog_code
    )
    values(
      v_user,'premium_invoice','paid',v_amount,v_coins,
      case
        when v_period_months=12 then 'Tennis Legacy Premium · 12 Months'
        when v_period_months=3 then 'Tennis Legacy Premium · 3 Months'
        else 'Tennis Legacy Premium · Monthly'
      end,
      v_invoice,v_subscription,v_customer,v_catalog
    );

    update public.premium_memberships
    set plan_code='premium',
        status='active',
        monthly_price_eur_cents=v_monthly_equivalent,
        monthly_coin_reward=30,
        billing_plan_code=v_catalog,
        billing_period_months=v_period_months,
        billing_amount_eur_cents=v_expected,
        coins_per_payment=v_coins,
        stripe_price_id=v_price_id,
        updated_at=now()
    where user_id=v_user;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  if v_event.event_type in (
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted'
  ) then
    v_subscription:=v_obj->>'id';
    v_customer:=v_obj->>'customer';

    select user_id into v_user
    from public.premium_memberships
    where stripe_subscription_id=v_subscription
       or (stripe_subscription_id is null and stripe_customer_id=v_customer)
    limit 1;

    if v_user is null then
      update public.stripe_webhook_events
      set process_note='waiting_for_subscription_mapping'
      where event_id=p_event_id;
      return false;
    end if;

    v_status:=case
      when v_event.event_type='customer.subscription.deleted' then 'canceled'
      when coalesce(v_obj->>'status','') in ('active','trialing') then 'active'
      when coalesce(v_obj->>'status','') in ('past_due','unpaid') then 'past_due'
      else 'incomplete'
    end;

    begin
      v_period_start:=to_timestamp((v_obj->>'current_period_start')::double precision);
    exception when others then
      v_period_start:=null;
    end;

    begin
      v_period_end:=to_timestamp((v_obj->>'current_period_end')::double precision);
    exception when others then
      v_period_end:=null;
    end;

    v_price_id:=coalesce(
      v_obj#>>'{items,data,0,price,id}',
      v_obj#>>'{items,data,0,plan,id}',
      v_obj#>>'{items,data,0,pricing,price_details,price}'
    );

    select code,coins,price_eur_cents
    into v_catalog,v_coins,v_expected
    from public.commerce_catalog_items
    where kind='premium' and is_active and stripe_price_id=v_price_id
    limit 1;

    if v_catalog is null then
      select billing_plan_code,coins_per_payment,billing_amount_eur_cents
      into v_catalog,v_coins,v_expected
      from public.premium_memberships
      where user_id=v_user;
    end if;

    v_period_months:=case v_catalog
      when 'premium_quarterly' then 3
      when 'premium_yearly' then 12
      else 1
    end;
    v_expected:=coalesce(v_expected,329);
    v_coins:=coalesce(v_coins,30*v_period_months);
    v_monthly_equivalent:=round(v_expected::numeric/v_period_months)::integer;

    update public.premium_memberships
    set plan_code=case when v_status='canceled' then 'free' else 'premium' end,
        status=v_status,
        current_period_start=coalesce(v_period_start,current_period_start),
        current_period_end=coalesce(v_period_end,current_period_end),
        cancel_at_period_end=coalesce((v_obj->>'cancel_at_period_end')::boolean,false),
        stripe_customer_id=coalesce(v_customer,stripe_customer_id),
        stripe_subscription_id=coalesce(v_subscription,stripe_subscription_id),
        monthly_price_eur_cents=v_monthly_equivalent,
        monthly_coin_reward=30,
        billing_plan_code=coalesce(v_catalog,billing_plan_code,'premium_monthly'),
        billing_period_months=v_period_months,
        billing_amount_eur_cents=v_expected,
        coins_per_payment=v_coins,
        stripe_price_id=coalesce(v_price_id,stripe_price_id),
        updated_at=now()
    where user_id=v_user;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  if v_event.event_type='invoice.payment_failed' then
    v_customer:=v_obj->>'customer';
    v_subscription:=coalesce(
      v_obj->>'subscription',
      v_obj#>>'{parent,subscription_details,subscription}'
    );

    update public.premium_memberships
    set status='past_due',updated_at=now()
    where stripe_subscription_id=v_subscription
       or (v_subscription is null and stripe_customer_id=v_customer and plan_code='premium');

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  update public.stripe_webhook_events
  set processed=true,processed_at=now(),process_note='ignored_event_type'
  where event_id=p_event_id;
  return true;

exception when unique_violation then
  update public.stripe_webhook_events
  set processed=true,processed_at=now(),process_note='idempotent_duplicate'
  where event_id=p_event_id;
  return true;
end;
$function$
;


DO $retention$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname='tennis-cron-history-retention-v1') THEN
    PERFORM cron.schedule(
      'tennis-cron-history-retention-v1',
      '47 * * * *',
      $job$
        DELETE FROM cron.job_run_details
        WHERE runid IN (
          SELECT runid FROM cron.job_run_details
          WHERE end_time < now() - interval '30 days'
            AND status IN ('succeeded','failed')
          ORDER BY runid
          LIMIT 5000
        );
      $job$
    );
  END IF;
END
$retention$;
