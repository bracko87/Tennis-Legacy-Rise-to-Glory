-- Final stage of internal game-engine RPC lockdown.
-- Anonymous visitors keep public registration, ranking, homepage and referral
-- endpoints. Authenticated players keep their normal action endpoints.
-- Only trusted game engines/service_role may call these internal procedures.
DO $secure$
DECLARE
  target text;
  f record;
  found_count integer;
BEGIN
  FOREACH target IN ARRAY ARRAY['check_game_manual_publishing_health_v1',
    'check_new_player_starting_scheme_health_v1',
    'check_player_identity_tactics_health_v1',
    'check_private_life_jewelry_images_v1',
    'check_private_life_watch_images_v1',
    'check_tournament_cancellation_spike_v1',
    'check_tournament_entry_pipeline_health_v1',
    'check_tournament_entry_processor_degradation_v1',
    'check_training_camp_health_v1',
    'check_training_camp_transition_health_v1',
    'check_wta_ai_population_expansion_v1',
    'check_wta_ai_portrait_health_v1',
    'finalize_doubles_team_result_v1',
    'finalize_training_camp_booking_v1',
    'progress_active_illness_v1',
    'roll_player_health_setback_v1',
    'roll_player_illness_v1',
    'roll_player_injury_v1',
    'notify_injury_risk_if_needed_v1',
    'queue_open_critical_incident_reminders_v1']::text[]
  LOOP
    SELECT count(*) INTO found_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=target AND p.prosecdef
      AND p.prosrc NOT ILIKE '%auth.uid%';
    IF found_count=0 THEN
      RAISE EXCEPTION 'Function % changed shape or authorization: manual review required',target;
    END IF;

    FOR f IN SELECT p.oid::regprocedure sig
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname=target
    LOOP
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.sig);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.sig);
    END LOOP;
  END LOOP;
END
$secure$;
