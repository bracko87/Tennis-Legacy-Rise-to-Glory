-- Authenticated player/admin APIs: defense in depth.
-- Remove unauthenticated EXECUTE without removing signed-in access.
-- All target routines already use auth.uid() / admin authorization.
-- Public rankings, public profiles, reviews, registration, invitations,
-- visitor analytics and referrals remain available to their intended roles.
DO $secure$
DECLARE
 f record;
 v_name text;
 v_count integer;
BEGIN
 FOR v_name IN SELECT unnest(ARRAY[
 'admin_refresh_tournament_operations_v1',
  'book_training_camp_v1',
  'book_training_camp_v2',
  'book_training_camp_v3',
  'cancel_avatar_replacement_request_v1',
  'cancel_training_camp_v1',
  'complete_training_camp_today_v1',
  'decline_player_sponsor_offer_v1',
  'delete_tennis_legacy_account_v1',
  'get_admin_tournament_operations_v1',
  'get_or_create_player_conversation_v1',
  'get_player_calendar_activity_v1',
  'get_player_conversation_messages_v1',
  'get_player_head_to_head_v1',
  'get_player_health_dashboard_v2',
  'get_player_health_dashboard_v3',
  'get_player_inbox_v1',
  'get_player_scouting_report_v1',
  'get_player_sponsor_dashboard_v1',
  'get_player_sponsor_dashboard_v2',
  'get_staff_dashboard_v1',
  'get_staff_dashboard_v2',
  'get_staff_market_v1',
  'get_staff_member_profile_v1',
  'get_tournament_entry_health_status_v1',
  'get_tournament_match_health_status_v1',
  'get_training_week_planner_v1',
  'quote_training_camp_v2',
  'quote_training_camp_v3',
  'restart_tennis_legacy_account_v1',
  'save_tournament_match_tactic_v1',
  'save_tournament_preparation_v1',
  'send_player_message_v1',
  'set_player_home_city_v1',
  'set_training_week_day_v1',
  'set_training_week_plan_v1',
  'sign_player_sponsor_offer_v1',
  'surrender_tournament_match_v1',
  'is_app_admin_v1'
 ]::text[])
 LOOP
   SELECT count(*) INTO v_count
   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname=v_name
     AND p.prosecdef
     AND (p.prosrc ILIKE '%auth.uid%' OR p.prosrc ILIKE '%is_app_admin_v1%');
   IF v_count<>1 THEN
     RAISE EXCEPTION 'Authentication-specific function % is missing, changed or overloaded. Manual review required.',v_name;
   END IF;

   FOR f IN
     SELECT p.oid::regprocedure signature
     FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
     WHERE n.nspname='public' AND p.proname=v_name
   LOOP
     EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon',f.signature);
     EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated,service_role',f.signature);
   END LOOP;
 END LOOP;
END $secure$;
