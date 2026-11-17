-- Tennis Legacy public RPC exposure review (read-only; safe on live game).
-- Anonymous access is deliberate for public lookup endpoints and the four
-- visitor-facing write endpoints. Rate limits must be active before launch.
WITH exposed AS(
 SELECT p.oid::regprocedure::text signature,p.proname,p.provolatile,
 has_function_privilege('anon',p.oid,'EXECUTE') anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') logged_in_execute,
 p.prosecdef security_definer,
 p.prosrc ~* '(insert[[:space:]]+into|update[[:space:]]+|delete[[:space:]]+from)' sql_mutation
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.prosecdef
   AND has_function_privilege('anon',p.oid,'EXECUTE')
), review AS(
 SELECT signature,
 CASE
  WHEN proname IN (
    'record_site_analytics_event_v1','register_referral_click_v1',
    'record_cross_game_referral_event_v1','submit_public_homepage_review_v1')
     THEN 'PUBLIC_WRITE_REQUIRES_LIMITS'
  WHEN proname IN (
    'player_tournament_entry_health_eligible_v1','doubles_match_game_second_v1')
     THEN 'INTERNAL_HELPER_REVIEW'
  WHEN proname IN (
    'get_tournament_calendar_v2','get_tournament_entry_lifecycle_v2')
     THEN 'ANONYMOUS_ACCESS_REVIEW'
  WHEN proname IN (
    'get_commerce_catalog_v1','get_competition_window_v1','get_game_clock_v1',
    'get_player_profile_v1','get_player_profile_v2','get_public_home_stats_v1',
    'get_public_homepage_reviews_v1','get_public_registration_status_v1',
    'get_registration_invite_v1','get_season_transition_notice_v1',
    'get_tennis_public_maintenance_v1','get_world_rankings_v1',
    'player_current_rank_position_v1','private_life_country_property_baseline_v1',
    'private_life_property_effective_price_v1','tournament_next_available_wave_label_v1')
     THEN 'PUBLIC_INFORMATION_EXPECTED'
  ELSE 'UNEXPECTED_PUBLIC_SECURITY_DEFINER'
 END access_class,
 sql_mutation,anon_execute,logged_in_execute
 FROM exposed
)
SELECT signature,access_class,sql_mutation,anon_execute,logged_in_execute,
 CASE WHEN access_class='UNEXPECTED_PUBLIC_SECURITY_DEFINER' THEN 'BLOCK'
 WHEN access_class IN ('INTERNAL_HELPER_REVIEW','ANONYMOUS_ACCESS_REVIEW') THEN 'REVIEW'
 WHEN access_class='PUBLIC_WRITE_REQUIRES_LIMITS'
 AND to_regclass('control_center_private.tennis_public_rpc_budgets_v1') IS NULL THEN 'PENDING_DEPLOYMENT'
 WHEN access_class='PUBLIC_WRITE_REQUIRES_LIMITS' THEN 'VERIFY_EDGE_AND_UI'
 ELSE 'EXPECTED' END release_disposition
FROM review ORDER BY release_disposition,signature;
