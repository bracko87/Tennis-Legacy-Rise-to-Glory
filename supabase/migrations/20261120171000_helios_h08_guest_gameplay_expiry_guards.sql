-- Helios H08/H01: enforce 14-day guest expiry at *database mutation* boundaries.
-- This is a first pass for 65 explicitly enumerated authenticated gameplay RPCs
-- and two directly writable player tables. Further review of indirect/internal
-- functions, payments and server jobs is required before public Guest Mode.
--
-- Non-guest registered accounts retain exactly the existing business logic.
-- Guest check relies on auth.users.is_anonymous and immutable private guest trial.
-- Never read user-provided metadata or client clock.
--
-- Each selected function must be an unambiguous SECURITY DEFINER volatile
-- PL/pgSQL function. Fail migration rather than silently skip if not.
DO $h08_guard_rpc$
DECLARE
  v_name text;
  v_oid oid;
  v_ddl text;
  v_begin_pos integer;
  v_anchor text := E'\nbegin\n';
  v_insert text := E'  PERFORM public.assert_my_tennis_guest_access_v1();\n';
  v_matches integer;
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'apply_late_tournament_entry_v1',
    'apply_to_tennis_club_v1',
    'apply_to_tournament_v3',
    'book_training_camp_v1',
    'book_training_camp_v2',
    'book_training_camp_v3',
    'buy_private_life_asset_v2',
    'buy_private_life_investment_v1',
    'cancel_training_camp_v1',
    'cast_national_captain_vote_v1',
    'claim_technical_sponsor_equipment_v1',
    'claim_technical_sponsor_replacement_v1',
    'clear_tournament_doubles_match_tactic_v1',
    'clear_tournament_match_tactic_v1',
    'complete_regular_training_today_v1',
    'complete_training_camp_today_v1',
    'confirm_staff_offer_v1',
    'contribute_national_association_fund_v1',
    'create_tennis_club_v1',
    'decline_player_sponsor_offer_v1',
    'decline_player_technical_sponsor_offer_v1',
    'discard_equipment_item_v1',
    'equip_equipment_item_v1',
    'invite_to_tennis_club_v1',
    'join_my_national_association_v1',
    'join_my_national_team_chat_v1',
    'lock_national_team_lineup_v1',
    'negotiate_staff_offer_v1',
    'purchase_equipment_item_v2',
    'register_national_captain_candidate_v1',
    'resign_national_captain_v1',
    'respond_doubles_partner_invitation_v1',
    'respond_national_team_callup_v1',
    'respond_national_team_friendly_invitation_v1',
    'respond_tennis_club_request_v1',
    'save_national_team_lineup_v1',
    'save_player_equipment_match_setup_v1',
    'save_player_tournament_match_equipment_setup_v1',
    'save_premium_season_target_v1',
    'save_tournament_doubles_match_tactic_v1',
    'save_tournament_match_tactic_v1',
    'save_tournament_preparation_v1',
    'save_tournament_transfer_preference_v1',
    'sell_private_life_investment_v1',
    'send_doubles_partner_invitation_v1',
    'send_national_team_chat_message_v1',
    'send_player_message_v1',
    'send_tennis_club_chat_message_v1',
    'set_doubles_partner_listing_v1',
    'set_national_team_friendly_listing_v1',
    'set_national_team_squad_v1',
    'set_player_home_city_v1',
    'set_premium_tournament_watch_v1',
    'set_regular_training_plan_v1',
    'set_tennis_season2_week1_preentry_v1',
    'set_training_week_day_v1',
    'set_training_week_days_v1',
    'set_training_week_plan_v1',
    'sign_player_sponsor_offer_v1',
    'sign_player_technical_sponsor_offer_v1',
    'surrender_tournament_match_v1',
    'terminate_staff_contract_v1',
    'withdraw_from_doubles_v1',
    'withdraw_national_captain_candidate_v1',
    'withdraw_tournament_application_v1'
  ] LOOP
    SELECT count(*), max(p.oid)::oid INTO v_matches, v_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    JOIN pg_language lang ON lang.oid=p.prolang
    WHERE n.nspname='public' AND p.proname=v_name
      AND p.prosecdef AND p.provolatile='v' AND lang.lanname='plpgsql';
    IF v_matches <> 1 THEN
      RAISE EXCEPTION 'Guest access protection: unexpected function signature or security attributes % (%)',
        v_name,v_matches;
    END IF;

    SELECT pg_get_functiondef(v_oid) INTO v_ddl;
    IF position(lower(v_insert) in lower(v_ddl)) > 0 THEN
      CONTINUE; -- repeatable while preserving existing user business logic
    END IF;
    v_begin_pos:=position(v_anchor IN lower(v_ddl));
    IF v_begin_pos=0 THEN
      RAISE EXCEPTION 'Guest access protection: unable to locate top-level BEGIN for %',v_name;
    END IF;
    v_ddl:=substr(v_ddl,1,v_begin_pos+length(v_anchor)-1) ||
      v_insert || substr(v_ddl,v_begin_pos+length(v_anchor));
    EXECUTE v_ddl;
  END LOOP;
END;
$h08_guard_rpc$;

-- Direct PostgREST INSERT/UPDATE writes are not routed through game RPCs.
-- Enforce the same server-side guest expiry for player details and tutorial
-- progression, while preserving database jobs with no authenticated user.
CREATE OR REPLACE FUNCTION public.guard_tennis_guest_direct_gameplay_write_v1()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NOT NULL
    AND EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND is_anonymous)
  THEN
    PERFORM public.assert_my_tennis_guest_access_v1();
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_tennis_guest_direct_gameplay_write_v1()
  FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS guard_guest_player_direct_write_v1 ON public.players;
CREATE TRIGGER guard_guest_player_direct_write_v1
  BEFORE INSERT OR UPDATE ON public.players
  FOR EACH ROW EXECUTE FUNCTION public.guard_tennis_guest_direct_gameplay_write_v1();

DROP TRIGGER IF EXISTS guard_guest_tutorial_direct_write_v1 ON public.player_tutorial_progress;
CREATE TRIGGER guard_guest_tutorial_direct_write_v1
  BEFORE INSERT OR UPDATE ON public.player_tutorial_progress
  FOR EACH ROW EXECUTE FUNCTION public.guard_tennis_guest_direct_gameplay_write_v1();
