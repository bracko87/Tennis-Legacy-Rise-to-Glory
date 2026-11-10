-- TENNIS LEGACY SEASON 1 -> SEASON 2 CANDIDATE ROUTINES
-- SNAPSHOT FROM LIVE DATABASE, updated 2026-11-10.
-- REVIEW / ISOLATED TEST ONLY. NOT AN AUTHORIZED PRODUCTION MIGRATION.
-- A separate set of migrations created the private run/step/baseline/contract tables.
-- DO NOT remove the fail-closed release gate or execute the cutover on production
-- without a verified backup/restore test, isolated two-season rehearsal and final approval.
-- Clock speed remains positive (2x configured) even when the new season is PAUSED.
-- There is no direct live-season transition in this file.

-- assert_tennis_season1_to2_release_gate_v1
CREATE OR REPLACE FUNCTION control_center_private.assert_tennis_season1_to2_release_gate_v1(p_run_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
  v_check jsonb;
begin
  v_check:=control_center_private.check_tennis_season1_to2_release_gate_v1(p_run_id);
  if (v_check->>'approved_for_cutover')::boolean is distinct from true then
    raise exception 'Season 1->2 migration is blocked: % independent approval/preflight requirements remain.',
       coalesce((v_check->>'blocking_issue_count')::integer,1)
       using errcode='P0001';
  end if;
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.assert_tennis_season1_to2_release_gate_v1(uuid) FROM PUBLIC, anon, authenticated;

-- build_tennis_season2_migration_preflight_v1
CREATE OR REPLACE FUNCTION control_center_private.build_tennis_season2_migration_preflight_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
  v_clock record;
  v_guard record;
  v_calendar jsonb;
  v_draws jsonb;
  v_closeout record;
  v_tech_due integer;
  v_tech_carry integer;
  v_main_due integer;
  v_main_carry integer;
  v_singles integer;
  v_doubles integer;
  v_runs integer;
  v_calendar_core boolean;
  v_ready_to_run boolean:=false;
begin
  select * into v_clock from public.get_game_clock_v1();
  select * into v_guard from public.season_transition_boundary_guard_v1 where id=true;
  select * into v_closeout
    from control_center_private.tennis_season1_final_closeout_v1 where season_number=1;
  v_calendar:=control_center_private.verify_tennis_season2_calendar_v1();
  v_draws:=control_center_private.verify_tennis_season2_early_preparations_v1();

  v_calendar_core:=(
    (v_calendar#>>'{source,editions}')::integer=597 and
    (v_calendar#>>'{target,editions}')::integer=597 and
    (v_calendar#>>'{source,slots}')::integer=613 and
    (v_calendar#>>'{target,slots}')::integer=613 and
    (v_calendar#>>'{source,competitions}')::integer=1194 and
    (v_calendar#>>'{target,competitions}')::integer=1194 and
    (v_calendar#>>'{target,weeks}')::integer=52 and
    (v_calendar#>>'{target,categories}')::integer=10 and
    (v_calendar#>>'{issues,slot_mismatches}')::integer=0 and
    (v_calendar#>>'{issues,world_mismatches}')::integer=0 and
    (v_calendar#>>'{issues,bad_edition_statuses}')::integer=0 and
    (v_calendar#>>'{issues,bad_competition_statuses}')::integer=0
  );

  select count(*) filter(where end_absolute_day<=366),
         count(*) filter(where end_absolute_day>366)
    into v_tech_due,v_tech_carry
  from public.player_technical_sponsor_contracts where status='active';

  select count(*) filter(where end_absolute_day<=366),
         count(*) filter(where end_absolute_day>366)
    into v_main_due,v_main_carry
  from public.player_sponsor_contracts where status='active';

  select count(*) into v_singles from public.player_ranking_contributions
    where is_active and expires_absolute_day>366;
  select count(*) into v_doubles from public.player_doubles_ranking_contributions
    where is_active and expires_absolute_day>366;
  select count(*) into v_runs from control_center_private.tennis_season_transition_runs_v1;

  return jsonb_build_object(
    'as_of',clock_timestamp(),
    'source_season',1,'target_season',2,
    'game_clock_held',coalesce(
      v_guard.enabled and v_guard.source_season=1
      and v_clock.game_total_seconds=v_guard.stop_at_total_seconds
      and v_clock.speed_multiplier=0,false),
    'season1_closeout',jsonb_build_object(
      'completed',coalesce(v_closeout.final_matches=12 and v_closeout.ranking_cycles_processed=12,false),
      'final_matches',v_closeout.final_matches,
      'published_ranking_results',v_closeout.ranking_results_published),
    'season2_calendar',jsonb_build_object(
      'core_parity_verified',coalesce(v_calendar_core,false),
      'full_eligibility_certified',false,
      'details',v_calendar),
    'early_draws',v_draws,
    'sponsorships',jsonb_build_object(
      'technical_due_at_boundary',v_tech_due,'technical_carryover',v_tech_carry,
      'main_due_at_boundary',v_main_due,'main_carryover',v_main_carry,
      'verified_for_automatic_rollover',false),
    'ranking_carryover',jsonb_build_object(
      'active_singles_contributions_past_boundary',v_singles,
      'active_doubles_contributions_past_boundary',v_doubles,
      'automatic_rollover_certified',false),
    'migration',jsonb_build_object(
      'planned_or_historical_runs',v_runs,
      'step_runner_verified',false,'backup_and_restore_verified',false,
      'two_season_dry_run_verified',false,
      'player_finance_rollover_verified',false,
      'operator_approved',false,'execution_enabled',v_ready_to_run),
    'release_blockers',jsonb_build_array(
      'Full tournament draw eligibility and integration testing',
      'Verified migration step runner and crash-safe replay',
      'Full backup and restore test',
      'Sponsorship and financial rollover certification',
      'Isolated Season 1 to 2 and Season 2 to 3 dry runs',
      'Operator approval'
    )
  );
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.build_tennis_season2_migration_preflight_v1() FROM PUBLIC, anon, authenticated;

-- check_tennis_season1_to2_release_gate_v1
CREATE OR REPLACE FUNCTION control_center_private.check_tennis_season1_to2_release_gate_v1(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
  r record;
  c record;
  g record;
  v_baseline jsonb;
  v_preflight jsonb;
  v_draws jsonb;
  v_blockers jsonb:='[]'::jsonb;
  v_steps integer;
  v_incorrect_step_status integer;
  v_unguarded_jobs integer;
  v_finance_bad integer;
  v_season2_finance integer;
  v_season2_rankings integer;
begin
  select * into r from control_center_private.tennis_season_transition_runs_v1
  where run_id=p_run_id;
  if not found or (r.source_season,r.target_season) is distinct from (1,2) then
    return jsonb_build_object('approved_for_cutover',false,'blockers',
       jsonb_build_array('A valid Season 1 to Season 2 migration plan was not found.'));
  end if;

  select * into c from public.get_game_clock_v1();
  select * into g from public.season_transition_boundary_guard_v1 where id=true;

  if not coalesce(g.enabled and g.source_season=1 and
    g.stop_at_total_seconds=31622399 and
    c.game_total_seconds=g.stop_at_total_seconds and c.speed_multiplier=0,false) then
    v_blockers:=v_blockers||jsonb_build_array('Season 1 clock is not held at the verified boundary.');
  end if;

  if r.status<>'planned' or r.execution_enabled is not true then
    v_blockers:=v_blockers||jsonb_build_array('Migration has not been approved/enabled for execution.');
  end if;
  if not (r.backup_verified and r.restore_test_verified) then
    v_blockers:=v_blockers||jsonb_build_array('Full backup and independent restore validation are missing.');
  end if;
  if not r.two_season_dry_run_verified then
    v_blockers:=v_blockers||jsonb_build_array('Two-season isolated migration dry run is missing.');
  end if;
  if not (r.contracts_verified and r.finance_verified) then
    v_blockers:=v_blockers||jsonb_build_array('Contract and financial rollover certification are missing.');
  end if;
  if not r.operator_approved then
    v_blockers:=v_blockers||jsonb_build_array('Final operator approval is missing.');
  end if;

  v_baseline:=control_center_private.verify_tennis_season1_transition_baselines_v1(p_run_id);
  if coalesce((v_baseline->>'all_unchanged')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Player, ranking, contract, wallet or calendar baselines have changed.');
  end if;

  v_preflight:=control_center_private.build_tennis_season2_migration_preflight_v1();
  v_draws:=v_preflight->'early_draws';
  if coalesce((v_preflight#>>'{season1_closeout,completed}')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Season 1 closeout is not certified.');
  end if;
  if coalesce((v_preflight#>>'{season2_calendar,core_parity_verified}')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Season 2 calendar parity has failed.');
  end if;
  if coalesce((v_draws->>'structural_preflight_passed')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Existing Season 2 applications and draws failed structural validation.');
  end if;
  if coalesce((v_draws->>'full_draw_eligibility_certified')::boolean,false) is not true then
    v_blockers:=v_blockers||jsonb_build_array('Season 2 draws and player eligibility require integration certification.');
  end if;

  select count(*), count(*) filter(where status<>'waiting')
    into v_steps,v_incorrect_step_status
  from control_center_private.tennis_season_transition_steps_v1
  where run_id=p_run_id;
  if v_steps<>13 or v_incorrect_step_status<>0 then
    v_blockers:=v_blockers||jsonb_build_array('The migration step journal is incomplete or not in its initial state.');
  end if;

  select count(*) into v_unguarded_jobs from cron.job
   where jobid in (7,44,52,53,55) and
     (not active or position('get_game_clock_v1()' in command)=0 or
      position('not (select is_paused from public.game_clock where id=1)' in command)=0);
  if v_unguarded_jobs>0 or
     (select count(*) from cron.job where jobid in (7,44,52,53,55))<>5 then
    v_blockers:=v_blockers||jsonb_build_array('Tournament processing jobs are missing safety-stop/pause guards.');
  end if;

  with latest as (
    select distinct on (tx.player_id) tx.player_id,tx.balance_after
      from public.career_finance_transactions tx
      order by tx.player_id,tx.created_at desc,tx.id desc
  )
  select count(*) into v_finance_bad
    from public.player_career_finance_accounts a
    left join latest l on l.player_id=a.player_id
    where l.player_id is null or a.balance is distinct from l.balance_after;
  if v_finance_bad<>0 then
    v_blockers:=v_blockers||jsonb_build_array('Player account balance does not match the financial ledger.');
  end if;

  select count(*) into v_season2_finance from public.career_finance_transactions where season=2;
  select count(*) into v_season2_rankings from public.ranking_publication_runs where season=2;
  if v_season2_finance>0 or v_season2_rankings>0 then
    v_blockers:=v_blockers||jsonb_build_array('Season 2 finance or ranking publication occurred before release.');
  end if;

  -- No executable cutover implementation has been approved or certified yet.
  v_blockers:=v_blockers||jsonb_build_array(
    'The atomic season-switch implementation and crash/replay tests are not certified.'
  );

  return jsonb_build_object(
    'run_id',p_run_id,'approved_for_cutover',false,
    'clock_held',coalesce(g.enabled and c.game_total_seconds=g.stop_at_total_seconds and c.speed_multiplier=0,false),
    'baseline_unchanged',coalesce((v_baseline->>'all_unchanged')::boolean,false),
    'draw_structure_passed',coalesce((v_draws->>'structural_preflight_passed')::boolean,false),
    'blocking_issue_count',jsonb_array_length(v_blockers),
    'blockers',v_blockers
  );
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.check_tennis_season1_to2_release_gate_v1(uuid) FROM PUBLIC, anon, authenticated;

-- execute_tennis_season1_to2_atomic_v1
CREATE OR REPLACE FUNCTION control_center_private.execute_tennis_season1_to2_atomic_v1(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
 v_run record;
 v_clock public.game_clock%rowtype;
 v_game record;
 v_reg record;
 v_player record;
 v_after record;
 v_drift jsonb;
 v_tech_synced integer:=0;
 v_start timestamptz;
 v_missing integer;
 v_output jsonb;
begin
 -- The release gate is intentionally NOT certified at present and always denies
 -- execution. This routine is an implementation candidate, not production-approved.
 -- A transaction either completes every step or rolls back everything.
 perform pg_advisory_xact_lock(2026,1202);

 select * into v_run
 from control_center_private.tennis_season_transition_runs_v1
 where run_id=p_run_id for update;

 if not found or (v_run.source_season,v_run.target_season) is distinct from (1,2) then
   raise exception 'Unknown source/target season transition';
 end if;
 if v_run.status='completed' then
   raise exception 'This migration has already completed; cannot rerun';
 end if;

 perform control_center_private.assert_tennis_season1_to2_release_gate_v1(p_run_id);

 -- A future approved release gate must have just checked the actual backup,
 -- restore, finance, sponsors, eligibility and two-season rehearsal evidence.
 -- This lock prevents a competing invocation from cutting over simultaneously.
 select * into v_clock from public.game_clock where id=1 for update;
 if not found or v_clock.season<>1 or v_clock.is_paused=true then
   raise exception 'Source game clock is not in expected Season 1 safety-held state';
 end if;
 select * into v_game from public.get_game_clock_v1();
 if v_game.game_total_seconds<>31622399 or v_game.speed_multiplier<>0 then
   raise exception 'Season 1 boundary not held';
 end if;

 v_drift:=control_center_private.verify_tennis_season1_transition_baselines_v1(p_run_id);
 if (v_drift->>'all_unchanged')::boolean is distinct from true then
   raise exception 'Pre-transition snapshot baseline drift detected';
 end if;

 select count(*) into v_missing from control_center_private.tennis_season_transition_steps_v1
 where run_id=p_run_id;
 if v_missing<>13 then
   raise exception '13 journal steps required';
 end if;
 v_start:=clock_timestamp();

 update control_center_private.tennis_season_transition_runs_v1
 set status='running',started_at=v_start,
     preflight=control_center_private.build_tennis_season2_migration_preflight_v1()
 where run_id=p_run_id and status='planned' and execution_enabled=true;
 if not found then
   raise exception 'Execution not enabled in the journal';
 end if;

 -- Season 1 has already closed and final ranking publication is committed.
 -- Season 2 ranking contributions are handled by the existing per-tournament
 -- defence/expiry engine; they must not reset at midnight.
 -- Player identity, skills, career balances, coin wallets and equipment remain.
 update control_center_private.tennis_season_transition_steps_v1
    set status='completed',updated_at=clock_timestamp(),
        details=details||jsonb_build_object('transaction','atomic','mode','verified_no_carryover_reset')
 where run_id=p_run_id
   and step_key in ('discover','lock','settle','snapshot','rankings',
                    'finance','development','identity','calendar');

 -- Resolve due technical sponsorships through the game's existing contract
 -- synchronizer using absolute day 366, preserving contracts crossing that day.
 -- Any failure or unintended change rolls back the entire transaction.
 for v_player in
   select distinct reg.player_id
   from control_center_private.tennis_season_transition_technical_contract_registry_v1 reg
   where reg.run_id=p_run_id
 loop
   perform public.sync_player_technical_sponsor_contracts_v1(v_player.player_id,366);
   v_tech_synced:=v_tech_synced+1;
 end loop;

 for v_reg in
  select reg.*,c.status as current_status,to_jsonb(c) as current_contract
  from control_center_private.tennis_season_transition_technical_contract_registry_v1 reg
  left join public.player_technical_sponsor_contracts c on c.id=reg.contract_id
  where reg.run_id=p_run_id
 loop
   if v_reg.handling='carryover_unchanged' and
      (v_reg.current_status is distinct from v_reg.original_status or
       v_reg.current_contract is distinct from v_reg.original_contract) then
     raise exception 'Protected crossing contract changed unexpectedly';
   end if;
   if v_reg.handling='complete_after_expiry' and v_reg.current_status<>'completed' then
     raise exception 'A due technical sponsorship was not settled';
   end if;
 end loop;

 update control_center_private.tennis_season_transition_steps_v1
   set status='completed',updated_at=clock_timestamp(),
       details=details||jsonb_build_object('contract_sync_players',v_tech_synced,
          'crossing_agreements_preserved',true)
 where run_id=p_run_id and step_key='contracts';

 -- Set the new season PAUSED at midnight (no live simulation or user action).
 -- Arm the next season's 23:59:59 guard BEFORE releasing the transaction.
 update public.game_clock set
    season=2,month=1,day=1,minute_of_day=0,
    real_anchor_at=clock_timestamp(),speed_multiplier=v_clock.speed_multiplier,
    is_paused=true,updated_at=clock_timestamp()
 where id=1 and season=1;
 if not found then
   raise exception 'Game clock season 1 cutover failed';
 end if;

 update public.season_transition_boundary_guard_v1 set
   source_season=2,stop_at_total_seconds=63244799,
   enabled=true,updated_at=clock_timestamp()
 where id=true and enabled and source_season=1
   and stop_at_total_seconds=31622399;
 if not found then
   raise exception 'Could not arm Season 2 boundary protection';
 end if;

 select * into v_after from public.get_game_clock_v1();
 if v_after.game_total_seconds<>31622400 then
    raise exception 'Post-cutover game clock did not hold Season 2 midnight';
 end if;
 if not exists(select 1 from public.game_clock where id=1 and season=2 and is_paused and speed_multiplier>0) then
    raise exception 'New game clock is not paused';
 end if;
 if (select count(*) from public.tournament_editions where season_number=2)<>597
   or (select count(*) from public.tournament_world_competitions wc
       join public.tournament_editions e on e.id=wc.tournament_edition_id
       where e.season_number=2)<>1194 then
    raise exception 'Season 2 calendar changed during cutover';
 end if;

 update control_center_private.tennis_season_transition_steps_v1
 set status='completed',updated_at=clock_timestamp(),
     details=details||jsonb_build_object('season_2_paused',true,'effective_speed',0)
 where run_id=p_run_id and step_key in ('switch','postcheck','close');

 select count(*) into v_missing
 from control_center_private.tennis_season_transition_steps_v1
 where run_id=p_run_id and status<>'completed';
 if v_missing<>0 then
    raise exception 'Not all journal steps reached completed state';
 end if;

 update control_center_private.tennis_season_transition_runs_v1
    set status='completed',finished_at=clock_timestamp()
 where run_id=p_run_id;

 v_output:=jsonb_build_object(
   'status','completed_paused','source_season',1,'target_season',2,
   'season_2_time','January 1 00:00',
   'game_clock_running',false,
   'stored_speed_multiplier',v_clock.speed_multiplier,
   'tech_sponsor_players_synced',v_tech_synced,
   'steps_completed',13,
   'requires_separate_approved_resume',true
 );
 return v_output;
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.execute_tennis_season1_to2_atomic_v1(uuid) FROM PUBLIC, anon, authenticated;

-- verify_tennis_season1_transition_baselines_v1
CREATE OR REPLACE FUNCTION control_center_private.verify_tennis_season1_transition_baselines_v1(p_run_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
declare
  v_run record;
  v_current jsonb;
  v_count integer:=0;
  v_missing integer:=0;
  v_drifted integer:=0;
  v_contract_mismatches integer:=0;
  v_metrics jsonb:='[]'::jsonb;
  v_baseline record;
  v_unchanged boolean;
begin
  select * into v_run
    from control_center_private.tennis_season_transition_runs_v1 where run_id=p_run_id;
  if not found or v_run.source_season<>1 or v_run.target_season<>2 then
    raise exception 'Unknown Season 1->2 migration plan';
  end if;
  for v_baseline in
    select metric_key,metric_value from control_center_private.tennis_season_transition_baselines_v1
    where run_id=p_run_id order by metric_key
  loop
    v_count:=v_count+1;
    case v_baseline.metric_key
      when 'human_finance_accounts' then
        select jsonb_build_object(
          'count',count(*),'total_balance',coalesce(sum(balance),0),
          'account_fingerprint',md5(coalesce(string_agg(
            player_id::text||':'||balance::text||':'||coalesce(processed_through_absolute_day::text,'null'),
            ',' order by player_id::text),''))
        ) into v_current from public.player_career_finance_accounts;
      when 'coin_wallets' then
        select jsonb_build_object(
          'count',count(*),'total_coins',coalesce(sum(coins_balance),0),
          'fingerprint',md5(coalesce(string_agg(
            user_id::text||':'||coins_balance::text,',' order by user_id::text),''))
        ) into v_current from public.user_wallets;
      when 'technical_contracts' then
        select jsonb_build_object(
          'active_count',count(*) filter(where status='active'),
          'due_count',count(*) filter(where status='active' and end_absolute_day<=366),
          'carryover_count',count(*) filter(where status='active' and end_absolute_day>366),
          'fingerprint',md5(coalesce(string_agg(
            id::text||':'||status||':'||end_absolute_day::text,',' order by id::text),''))
        ) into v_current from public.player_technical_sponsor_contracts;
      when 'rankings' then
        select jsonb_build_object(
          'singles_active',(select count(*) from public.player_ranking_contributions where is_active),
          'singles_points',(select coalesce(sum(ranking_points),0) from public.player_ranking_contributions where is_active),
          'doubles_active',(select count(*) from public.player_doubles_ranking_contributions where is_active),
          'doubles_points',(select coalesce(sum(ranking_points),0) from public.player_doubles_ranking_contributions where is_active)
        ) into v_current;
      when 'player_population' then
        select jsonb_build_object('players',count(*),
          'human_players',count(*) filter(where player_type='human'),
          'atp_players',count(*) filter(where world='ATP'),
          'wta_players',count(*) filter(where world='WTA')
        ) into v_current from public.players;
      when 'season2_calendar' then
        select jsonb_build_object(
          'editions',(select count(*) from public.tournament_editions where season_number=2),
          'slots',(select count(*) from public.tournament_schedule_slots sl join public.tournament_editions ed on ed.id=sl.tournament_edition_id where ed.season_number=2),
          'competitions',(select count(*) from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id where ed.season_number=2)
        ) into v_current;
      else
        raise exception 'Unknown baseline metric: %', v_baseline.metric_key;
    end case;
    v_unchanged := (v_baseline.metric_value=v_current);
    if not v_unchanged then v_drifted:=v_drifted+1; end if;
    v_metrics:=v_metrics||jsonb_build_array(jsonb_build_object('metric',v_baseline.metric_key,'unchanged',v_unchanged));
  end loop;

  v_missing:=greatest(0,6-v_count);
  select count(*) into v_contract_mismatches
    from control_center_private.tennis_season_transition_technical_contract_registry_v1 reg
    left join public.player_technical_sponsor_contracts c on c.id=reg.contract_id
    where reg.run_id=p_run_id and (
      c.id is null or c.player_id is distinct from reg.player_id
      or to_jsonb(c) is distinct from reg.original_contract
    );

  if (select count(*) from control_center_private.tennis_season_transition_technical_contract_registry_v1
      where run_id=p_run_id)<>3 then
    v_contract_mismatches:=v_contract_mismatches+1;
  end if;

  return jsonb_build_object(
    'run_id',p_run_id,'baseline_metric_count',v_count,
    'missing_baselines',v_missing,
    'drifted_baselines',v_drifted,
    'contract_mismatches',v_contract_mismatches,
    'all_unchanged',v_count=6 and v_missing=0 and v_drifted=0 and v_contract_mismatches=0,
    'metrics',v_metrics
  );
end
$function$;
REVOKE ALL ON FUNCTION control_center_private.verify_tennis_season1_transition_baselines_v1(uuid) FROM PUBLIC, anon, authenticated;

-- verify_tennis_season2_calendar_v1
CREATE OR REPLACE FUNCTION control_center_private.verify_tennis_season2_calendar_v1()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
with
s1e as (select id,tournament_series_id from public.tournament_editions where season_number=1),
s2e as (select id,tournament_series_id,status from public.tournament_editions where season_number=2),
counts as (
  select
    (select count(*) from s1e) source_editions,
    (select count(*) from s2e) target_editions,
    (select count(*) from public.tournament_schedule_slots sl join s1e e on e.id=sl.tournament_edition_id) source_slots,
    (select count(*) from public.tournament_schedule_slots sl join s2e e on e.id=sl.tournament_edition_id) target_slots,
    (select count(*) from public.tournament_world_competitions wc join s1e e on e.id=wc.tournament_edition_id) source_competitions,
    (select count(*) from public.tournament_world_competitions wc join s2e e on e.id=wc.tournament_edition_id) target_competitions,
    (select count(distinct sl.season_week) from public.tournament_schedule_slots sl join s2e e on e.id=sl.tournament_edition_id) target_weeks,
    (select count(distinct ts.category_code) from s2e e join public.tournament_series ts on ts.id=e.tournament_series_id) target_categories,
    (select count(*) from s2e e where e.status<>'scheduled') bad_edition_statuses,
    (select count(*) from public.tournament_world_competitions wc join s2e e on e.id=wc.tournament_edition_id where wc.status<>'scheduled') bad_competition_statuses,
    (select count(*) from public.tournament_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join s2e e on e.id=wc.tournament_edition_id) existing_singles_matches,
    (select count(*) from public.tournament_doubles_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join s2e e on e.id=wc.tournament_edition_id) existing_doubles_matches,
    (select count(*) from public.player_tournament_results r join public.tournament_world_competitions wc on wc.id=r.competition_id join s2e e on e.id=wc.tournament_edition_id) existing_results
),
source_slots as (
  select e.tournament_series_id,sl.season_week,sl.phase,sl.slot_order,sl.calendar_month,sl.month_week
    from s1e e join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
),
target_slots as (
  select e.tournament_series_id,sl.season_week,sl.phase,sl.slot_order,sl.calendar_month,sl.month_week
    from s2e e join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
),
slot_differences as (
  (select * from source_slots except select * from target_slots)
  union all
  (select * from target_slots except select * from source_slots)
),
source_worlds as (
  select e.tournament_series_id,wc.world from s1e e join public.tournament_world_competitions wc on wc.tournament_edition_id=e.id
),
target_worlds as (
  select e.tournament_series_id,wc.world from s2e e join public.tournament_world_competitions wc on wc.tournament_edition_id=e.id
),
world_differences as (
  (select * from source_worlds except select * from target_worlds)
  union all
  (select * from target_worlds except select * from source_worlds)
),
checks as (
 select c.*,
   (select count(*) from slot_differences) slot_mismatches,
   (select count(*) from world_differences) world_mismatches
 from counts c
),
readiness as (
 select *,
 source_editions>0
 and source_editions=target_editions
 and source_slots=target_slots
 and source_competitions=target_competitions
 and target_weeks=52
 and target_categories=10
 and bad_edition_statuses=0
 and bad_competition_statuses=0
 and existing_singles_matches=0
 and existing_doubles_matches=0
 and existing_results=0
 and slot_mismatches=0
 and world_mismatches=0 as coverage_verified
 from checks
)
select jsonb_build_object(
 'coverage_verified',coverage_verified,
 'source',jsonb_build_object('editions',source_editions,'slots',source_slots,'competitions',source_competitions),
 'target',jsonb_build_object('season',2,'editions',target_editions,'slots',target_slots,'competitions',target_competitions,'weeks',target_weeks,'categories',target_categories),
 'issues',jsonb_build_object('slot_mismatches',slot_mismatches,'world_mismatches',world_mismatches,
 'bad_edition_statuses',bad_edition_statuses,'bad_competition_statuses',bad_competition_statuses,
 'existing_singles_matches',existing_singles_matches,'existing_doubles_matches',existing_doubles_matches,
 'existing_results',existing_results),
 'note','Calendar parity against Season 1; does not certify live migration, recovery or calendar availability for a signed-in player'
) from readiness
$function$;
REVOKE ALL ON FUNCTION control_center_private.verify_tennis_season2_calendar_v1() FROM PUBLIC, anon, authenticated;

-- verify_tennis_season2_early_preparations_v1
CREATE OR REPLACE FUNCTION control_center_private.verify_tennis_season2_early_preparations_v1()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
with s2 as (
  select wc.id competition_id,wc.world
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  where ed.season_number=2
),
applications as (
  select a.*, s2.world competition_world,p.player_type,p.world as player_world
  from public.tournament_applications a join s2 on s2.competition_id=a.competition_id
  left join public.players p on p.id=a.player_id
),
entries as (
  select en.*,s2.world competition_world,p.player_type,p.world as player_world
  from public.tournament_entries en join s2 on s2.competition_id=en.competition_id
  left join public.players p on p.id=en.player_id
),
draws as (
  select d.*, ed.season_number, sl.season_week
  from public.tournament_draw_publications d
  join s2 on s2.competition_id=d.competition_id
  join public.tournament_world_competitions wc on wc.id=d.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id=ed.id
),
matches as (
  select m.*,s2.world competition_world,p1.world p1_world,p2.world p2_world
  from public.tournament_matches m join s2 on s2.competition_id=m.competition_id
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
),
closeout as (select max(completed_at) as completed_at from control_center_private.tennis_season1_final_closeout_v1 where season_number=1),
totals as (
 select
 (select count(*) from applications) app_count,
 (select count(*) from entries) entry_count,
 (select count(*) from draws) draw_count,
 (select count(*) from matches) match_count,
 (select count(*) from matches where status='scheduled') scheduled_matches,
 (select count(*) from matches where status='bye') bye_matches,
 (select count(*) from matches where status='cancelled') cancelled_matches,
 (select count(*) from applications where
    player_type is distinct from 'ai' or player_world is distinct from competition_world
    or owner_user_id is not null or ranking_position_snapshot is null
    or target_season_week not between 1 and 52) bad_applications,
 (select count(*) from applications)-(select count(distinct (competition_id,player_id)) from applications) duplicate_applications,
 (select count(*) from entries where player_type is distinct from 'ai' or
   player_world is distinct from competition_world or ranking_position_snapshot is null) bad_entries,
 (select count(*) from entries)-(select count(distinct (competition_id,player_id)) from entries) duplicate_entries,
 (select count(*) from draws where ranking_snapshot_absolute_day<>365
   or season_week<>1 or published_at < (select completed_at from closeout)) bad_draw_snapshots,
 (select count(*) from matches where
    scheduled_season_week<>1 or status not in ('scheduled','bye','cancelled')
    or (status='scheduled' and (winner_id is not null or started_at is not null or completed_at is not null))
    or (status='bye' and winner_id is null)
    or (player1_id is not null and p1_world is distinct from competition_world)
    or (player2_id is not null and p2_world is distinct from competition_world)) bad_matches,
 (select count(*) from public.player_tournament_results r join s2 on s2.competition_id=r.competition_id) existing_singles_results,
 (select count(*) from public.player_doubles_tournament_results r join s2 on s2.competition_id=r.competition_id) existing_doubles_results,
 (select completed_at from closeout) closeout_completed_at
),
outcome as (
  select *,
    closeout_completed_at is not null
    and bad_applications=0 and duplicate_applications=0
    and bad_entries=0 and duplicate_entries=0
    and bad_draw_snapshots=0 and bad_matches=0
    and existing_singles_results=0 and existing_doubles_results=0 as structural_passed
  from totals
)
select jsonb_build_object(
 'structural_preflight_passed', structural_passed,
 'full_draw_eligibility_certified', false,
 'season2_execution_enabled', false,
 'generated_records',jsonb_build_object(
   'applications',app_count,'entries',entry_count,'draws',draw_count,
   'matches',match_count,'scheduled_matches',scheduled_matches,'byes',bye_matches,'cancelled',cancelled_matches),
 'anomalies',jsonb_build_object(
   'invalid_applications',bad_applications,'duplicate_applications',duplicate_applications,
   'invalid_entries',bad_entries,'duplicate_entries',duplicate_entries,
   'invalid_draw_snapshots',bad_draw_snapshots,'invalid_matches',bad_matches,
   'singles_results',existing_singles_results,'doubles_results',existing_doubles_results),
 'closeout_completed_at',closeout_completed_at,
 'note','Structural read-only review only. Not a full tournament eligibility or migration approval.'
) from outcome
$function$;
REVOKE ALL ON FUNCTION control_center_private.verify_tennis_season2_early_preparations_v1() FROM PUBLIC, anon, authenticated;
