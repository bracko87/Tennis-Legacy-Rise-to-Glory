-- Remove direct player/anonymous EXECUTE access from internal game engines.
-- Gameplay and cron jobs invoke these through trusted server-side functions.
-- Trigger functions remain installed and triggered normally.
-- Existing client RPC endpoints for training, travel, account and sponsorship remain.
DO $secure$
DECLARE
  target text;
  item record;
  found_count integer;
BEGIN
  FOREACH target IN ARRAY ARRAY['auto_repair_due_tournament_entry_pipelines_v1',
    'create_staff_candidate_v1',
    'grant_new_career_starting_coins_v1',
    'initialize_new_human_career_v1',
    'notify_doubles_team_entry_v1',
    'prepare_tournament_match_simulation_v1',
    'process_ai_weekly_short_injuries_v1',
    'process_doubles_rankings_for_day_v1',
    'process_due_health_recovery_v2',
    'process_due_injury_recovery_v1',
    'process_regular_training_for_player_v2',
    'process_staff_contract_expiry_v1',
    'process_staff_weekly_salary_events_v1',
    'process_training_camp_day_v1',
    'rebalance_tournament_minimum_field_v1',
    'repair_false_minimum_field_cancellation_v1',
    'repair_season1_week11_false_cancellations_v1',
    'repair_week11_minimum_fields_v1',
    'replenish_staff_market_v1',
    'resolve_tournament_travel_no_show_v1',
    'schedule_doubles_match_v1',
    'simulate_doubles_match_v1',
    'simulate_tournament_match_v2',
    'simulate_tournament_match_raw_v2',
    'ensure_tournament_match_weather_v1',
    'ensure_due_opponent_scouting_tasks_v1',
    'apply_player_effective_bonus_progress_v1',
    'apply_doubles_equipment_wear_v1']::text[] LOOP
    SELECT count(*) INTO found_count FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=target AND p.prosecdef
      AND p.prosrc NOT ILIKE '%auth.uid%';
    IF found_count=0 THEN
      RAISE EXCEPTION 'Security review needed: expected internal game engine % missing or now checks auth',target;
    END IF;
    FOR item IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
     JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.proname=target
    LOOP
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated',item.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',item.sig);
    END LOOP;
  END LOOP;

  -- Standalone trigger routines should never be callable as public RPCs.
  FOR item IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prorettype='pg_catalog.trigger'::regtype
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated',item.sig);
  END LOOP;

  -- Admin-only RPCs already verify is_app_admin_v1(auth.uid()).
  -- Removing anonymous access is a second line of protection.
  FOR item IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname IN ('admin_refresh_tournament_operations_v1',
                       'get_admin_analytics_dashboard_v1',
                       'get_admin_tournament_operations_v1')
      AND p.prosrc ILIKE '%is_app_admin_v1%'
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon',item.sig);
  END LOOP;
END
$secure$;
