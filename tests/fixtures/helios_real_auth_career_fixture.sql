-- CI-only supplemental schema, loaded after the minimal real-Auth fixture.
-- The career/tournament tables come from the existing disposable retirement fixture.
-- Policies here are fixture-only, not a production RLS audit.
CREATE TABLE control_center_private.helios_real_auth_ci_marker(id boolean PRIMARY KEY CHECK(id));
INSERT INTO control_center_private.helios_real_auth_ci_marker VALUES(true);
CREATE TABLE public.player_home_city_options(
 country_code text, city text, is_active boolean DEFAULT true, sort_order integer DEFAULT 0
);
CREATE TABLE public.player_equipment_inventory(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 condition numeric NOT NULL
);
CREATE TABLE public.player_career_finance_accounts(
 player_id uuid PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE, balance bigint NOT NULL
);
DO $qa$
DECLARE t record;
BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
 END LOOP;
END
$qa$;
REVOKE ALL ON public.players FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.players TO authenticated;
CREATE POLICY helios_ci_player_select_own ON public.players FOR SELECT TO authenticated USING (owner_user_id=auth.uid());
CREATE POLICY helios_ci_player_insert_own ON public.players FOR INSERT TO authenticated WITH CHECK (owner_user_id=auth.uid() AND player_type='human');

-- Minimal dependencies needed by the real frontend AuthProvider in CI.
ALTER TABLE public.players ADD COLUMN preferred_surface text;
CREATE FUNCTION public.is_app_admin_v1() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
REVOKE ALL ON FUNCTION public.is_app_admin_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.is_app_admin_v1() TO authenticated;
CREATE FUNCTION public.get_public_google_oauth_status_v1() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
REVOKE ALL ON FUNCTION public.get_public_google_oauth_status_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_google_oauth_status_v1() TO anon,authenticated;

-- Verified production invariant, missing in the older representative fixture.
ALTER TABLE public.players ADD CONSTRAINT players_owner_by_type_check CHECK (
 (player_type='human' AND owner_user_id IS NOT NULL)
 OR (player_type='ai' AND owner_user_id IS NULL)
);

-- Representative production-named private-state tables, with scoped FK behavior.
CREATE TABLE public.player_equipment_loadouts(player_id uuid PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE,
 racket_inventory_id uuid REFERENCES public.player_equipment_inventory(id) ON DELETE SET NULL);
CREATE TABLE public.player_equipment_accessory_loadout(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
 inventory_id uuid REFERENCES public.player_equipment_inventory(id) ON DELETE CASCADE);
CREATE TABLE public.player_equipment_match_setups(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,
 racket_inventory_id uuid REFERENCES public.player_equipment_inventory(id) ON DELETE SET NULL);
CREATE TABLE public.new_player_initialization_audit(player_id uuid PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE,user_id uuid NOT NULL);
CREATE TABLE public.career_finance_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,amount bigint NOT NULL DEFAULT 0);
CREATE TABLE public.player_tournament_preparation_plans(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_tournament_match_tactics(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_doubles_match_tactics(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_tournament_transfer_preferences(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_tournament_travel_selection(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_travel_legs(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_calendar_commitments(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_direct_transfer_morale_state(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_equipment_broken_starters_v1(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_equipment_wear_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_doubles_equipment_wear_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_tournament_match_equipment_setups(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_training_plans(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_training_sessions(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_training_progress(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_weekly_training_plan_days(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_skill_history(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_health_setback_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_illness_risk_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_illnesses(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_injuries(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_injury_risk_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_lifestyle_morale_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_lifestyle_state(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_daily_activity(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_career_day_processing_state(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_skills(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_tutorial_progress(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_location_state(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_avatar_reservations(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_tournament_results(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,competition_id uuid REFERENCES public.tournament_world_competitions(id),ranking_points_earned int NOT NULL);
CREATE TABLE public.player_doubles_tournament_results(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,team_id uuid REFERENCES public.tournament_doubles_teams(id) ON DELETE CASCADE,ranking_points_earned int NOT NULL);
CREATE TABLE public.player_rankings(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,ranking_points int);
CREATE TABLE public.player_doubles_rankings(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,ranking_points int);
CREATE TABLE public.helios_ci_unreviewed_dependency(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.user_wallets(user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,coins_balance bigint DEFAULT 0,lifetime_coins_earned bigint DEFAULT 0,lifetime_coins_spent bigint DEFAULT 0);
CREATE TABLE public.coin_ledger(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.commerce_checkout_intents(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.app_admins(user_id uuid);
CREATE TABLE public.user_notifications(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.notification_preferences(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.user_interface_preferences_v1(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.user_language_preferences(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.referral_codes(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.referral_user_devices(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE control_center_private.tennis_active_player_presence_v1(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.site_analytics_daily_sessions(visitor_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid);
CREATE TABLE public.site_analytics_daily_visitors(visitor_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid);
-- Supabase initializes its own protected Storage schema. Never create fake managed tables.
DO $qa$
DECLARE t record;
BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
 END LOOP;
END
$qa$;

-- Consolidated domain fixture: production names and representative FK ordering.
CREATE TABLE public.staff_members(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),current_player_id uuid REFERENCES public.players(id) ON DELETE SET NULL,status text DEFAULT 'available',updated_at timestamptz DEFAULT now());
CREATE TABLE public.player_staff_contracts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,staff_id uuid REFERENCES public.staff_members(id),status text DEFAULT 'active');
CREATE TABLE public.staff_negotiations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,accepted_contract_id uuid REFERENCES public.player_staff_contracts(id) ON DELETE SET NULL);
CREATE TABLE public.staff_negotiation_offers(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,negotiation_id uuid REFERENCES public.staff_negotiations(id) ON DELETE CASCADE);
CREATE TABLE public.staff_financial_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,contract_id uuid REFERENCES public.player_staff_contracts(id) ON DELETE CASCADE);
CREATE TABLE public.player_training_camp_bookings(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_training_camp_days(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,booking_id uuid REFERENCES public.player_training_camp_bookings(id) ON DELETE CASCADE);
CREATE TABLE public.player_training_camp_staff(booking_id uuid REFERENCES public.player_training_camp_bookings(id) ON DELETE CASCADE,contract_id uuid REFERENCES public.player_staff_contracts(id) ON DELETE RESTRICT);
CREATE TABLE public.player_sponsor_offers(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_sponsor_contracts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,offer_id uuid REFERENCES public.player_sponsor_offers(id) ON DELETE RESTRICT);
ALTER TABLE public.player_sponsor_offers ADD COLUMN renewal_previous_contract_id uuid REFERENCES public.player_sponsor_contracts(id) ON DELETE SET NULL;
CREATE TABLE public.player_sponsor_objectives(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,contract_id uuid REFERENCES public.player_sponsor_contracts(id) ON DELETE CASCADE);
CREATE TABLE public.player_sponsor_renewal_reservations_v1(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,offer_id uuid REFERENCES public.player_sponsor_offers(id) ON DELETE CASCADE,activated_contract_id uuid REFERENCES public.player_sponsor_contracts(id) ON DELETE SET NULL);
CREATE TABLE public.player_technical_sponsor_offers(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_technical_sponsor_contracts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,offer_id uuid REFERENCES public.player_technical_sponsor_offers(id) ON DELETE SET NULL);
CREATE TABLE public.technical_sponsor_equipment_claims(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,contract_id uuid REFERENCES public.player_technical_sponsor_contracts(id) ON DELETE RESTRICT,inventory_id uuid REFERENCES public.player_equipment_inventory(id) ON DELETE RESTRICT);
CREATE TABLE public.player_equipment_match_setup_accessories(setup_id uuid REFERENCES public.player_equipment_match_setups(id) ON DELETE CASCADE,inventory_id uuid REFERENCES public.player_equipment_inventory(id) ON DELETE CASCADE);
CREATE TABLE public.private_life_player_assets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,purchase_transaction_id uuid REFERENCES public.career_finance_transactions(id));
CREATE TABLE public.private_life_asset_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,player_asset_id uuid REFERENCES public.private_life_player_assets(id) ON DELETE CASCADE,finance_transaction_id uuid REFERENCES public.career_finance_transactions(id));
CREATE TABLE public.private_life_asset_sale_listings(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,player_asset_id uuid REFERENCES public.private_life_player_assets(id) ON DELETE CASCADE,finance_transaction_id uuid REFERENCES public.career_finance_transactions(id));
CREATE TABLE public.private_life_investment_trades(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,finance_transaction_id uuid REFERENCES public.career_finance_transactions(id));
CREATE TABLE public.player_private_jet_positions(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,owned_asset_id uuid REFERENCES public.private_life_player_assets(id) ON DELETE CASCADE);
CREATE TABLE public.career_tax_periods(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,transaction_id uuid REFERENCES public.career_finance_transactions(id) ON DELETE SET NULL);
CREATE TABLE public.national_association_memberships(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL);
CREATE TABLE public.national_team_chat_presence(player_id uuid REFERENCES public.players(id) ON DELETE RESTRICT,user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,membership_id uuid REFERENCES public.national_association_memberships(id) ON DELETE CASCADE);
CREATE TABLE public.national_team_chat_messages(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.national_captain_candidates(player_id uuid REFERENCES public.players(id) ON DELETE RESTRICT,user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT);
CREATE TABLE public.national_captain_terms(player_id uuid REFERENCES public.players(id) ON DELETE RESTRICT,user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT);
CREATE TABLE public.national_association_contributions(user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,membership_id uuid REFERENCES public.national_association_memberships(id) ON DELETE RESTRICT);
CREATE TABLE public.national_captain_votes(voter_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT);
CREATE TABLE public.tennis_clubs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_player_id uuid REFERENCES public.players(id) ON DELETE RESTRICT);
CREATE TABLE public.tennis_club_requests(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,created_by_player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.tournament_doubles_partner_invitations(inviter_player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,invitee_player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,inviter_user_id uuid,invitee_user_id uuid);
CREATE TABLE public.player_conversations(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),player_one_id uuid REFERENCES public.players(id) ON DELETE CASCADE,player_two_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_messages(conversation_id uuid REFERENCES public.player_conversations(id) ON DELETE CASCADE,sender_player_id uuid REFERENCES public.players(id) ON DELETE CASCADE,body text);
CREATE TABLE public.avatar_replacement_requests(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.avatar_replacement_request_history(request_id uuid REFERENCES public.avatar_replacement_requests(id) ON DELETE CASCADE);
CREATE TABLE public.tennis_club_chat_messages(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.tennis_club_chat_read_state_v1(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.tennis_club_memberships(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_opponent_scouting_tasks(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.tournament_doubles_partner_listings(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_premium_season_targets(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_premium_tournament_watches(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_match_condition_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.player_doubles_match_condition_events(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.private_life_investment_positions(player_id uuid REFERENCES public.players(id) ON DELETE CASCADE);
CREATE TABLE public.referral_activity_days(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
CREATE TABLE public.birthday_email_outbox(user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE);
DO $qa$ DECLARE r record; BEGIN
 FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',r.tablename);
 END LOOP;
END $qa$;
