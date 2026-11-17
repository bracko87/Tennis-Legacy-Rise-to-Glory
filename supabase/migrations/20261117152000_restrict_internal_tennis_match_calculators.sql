-- Tennis Legacy security hardening: deny direct API access to the
-- 26 server-side calculations that reveal private tactics, player condition,
-- staffing modifiers, health risks and internal match-engine ratings.
--
-- They run as SECURITY DEFINER owned by postgres and are called by other
-- trusted server functions. Exposed player-facing dashboards keep their
-- own authenticated entrypoints and continue to work.
-- No data, match results, accounts, rankings, flights or payments are changed.
DO $secure$
DECLARE
  target text;
  f record;
  v_count integer;
BEGIN
  FOREACH target IN ARRAY ARRAY[
    'calculate_tournament_match_weather_v1',
    'doubles_player_match_strength_v1',
    'doubles_team_match_strength_v1',
    'doubles_team_strength_v1',
    'get_automatic_doubles_tactic_v1',
    'get_automatic_singles_tactic_v1',
    'get_doubles_player_entry_strength_v1',
    'get_effective_doubles_match_tactic_internal_v1',
    'get_effective_match_tactic_internal_v2',
    'get_match_engine_profile_for_match_base_v2',
    'get_match_engine_profile_for_match_core_v2',
    'get_match_engine_profile_for_match_v2',
    'get_player_active_injury_effects_v1',
    'get_player_health_summary_v1',
    'get_player_illness_risk_v1',
    'get_player_injury_risk_v1',
    'get_player_staff_effects_v1',
    'get_player_staff_effects_v2',
    'get_player_staff_effects_v3',
    'get_staff_role_effect_summary_v1',
    'player_match_count_on_game_day_v1',
    'player_match_slot_conflict_v1',
    'player_tournament_blocked_by_health_v1',
    'player_tournament_blocked_by_injury_v1',
    'player_training_blocked_by_health_v1',
    'player_training_blocked_by_injury_v1'
  ]::text[]
  LOOP
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=target
      AND p.prosecdef
      AND p.proowner='postgres'::regrole
      AND p.prokind='f';
    IF v_count<>1 THEN
      RAISE EXCEPTION 'Expected one postgres-owned internal function: %, found %',target,v_count;
    END IF;

    IF EXISTS (
      SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname IN ('public','control_center_private')
        AND NOT p.prosecdef AND p.proname<>target
        AND p.prosrc ILIKE ('%'||target||'%')
    ) THEN
      RAISE EXCEPTION 'A security-invoker function references %; review before tightening access',target;
    END IF;

    FOR f IN
      SELECT p.oid::regprocedure signature
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname=target
    LOOP
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.signature);
    END LOOP;
  END LOOP;
END
$secure$;
