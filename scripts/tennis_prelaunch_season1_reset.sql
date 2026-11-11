-- Tennis Legacy: ONE-TIME pre-launch game reset. Runs atomically or not at all.
-- Owner-approved intent: erase rehearsal gameplay, reset AI to original skills,
-- return Season 1 Jan 1 00:00 PAUSED, keep public registration closed.
-- PRESERVE: auth.users, payment invoices, Stripe events, paid membership entitlements,
-- wallets/coin ledger, app admins, game catalogs, static schedules and system-health evidence.
-- REQUIRE: original Supabase daily backup exists, and the existing game is disposable test data.
-- This is NOT automatically deployed; use only in the selected Tennis Legacy project.
-- Rehearse without writes by replacing terminal COMMIT with ROLLBACK.
BEGIN;
SET LOCAL statement_timeout = '180s';
SET LOCAL lock_timeout = '15s';

DO $guard$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.game_clock WHERE id=1 AND is_paused)
 OR NOT EXISTS(SELECT 1 FROM public.registration_control WHERE singleton_id=true AND NOT public_signup_enabled)
 OR EXISTS(SELECT 1 FROM control_center_private.tennis_prelaunch_cron_freeze_v1 f
             JOIN cron.job j ON j.jobid=f.jobid WHERE j.active)
 OR (SELECT count(*) FROM control_center_private.tennis_prelaunch_cron_freeze_v1)<>33
 OR (SELECT count(*) FROM control_center_private.tennis_prelaunch_ai_roster_seed_v1)<>834
 OR (SELECT count(*) FROM control_center_private.tennis_prelaunch_s1_editions_v1)<>597
 OR (SELECT count(*) FROM control_center_private.tennis_prelaunch_s1_competitions_v1)<>1194
 OR (SELECT count(*) FROM control_center_private.tennis_prelaunch_s1_schedule_v1)<>613
 OR (SELECT count(*) FROM control_center_private.tennis_prelaunch_ai_starter_assets_v1)<>1668
 OR (SELECT count(*) FROM public.tournament_matches)<40000
 OR (SELECT count(*) FROM auth.users)<>6
 OR (SELECT count(*) FROM public.billing_transactions WHERE status='paid' AND amount_eur_cents=949)<>1
 THEN RAISE EXCEPTION 'Prelaunch reset guard failed. No changes allowed.'; END IF;
END $guard$;

-- Build exact 160-table dependency-checked gameplay reset set.
-- TRUNCATE RESTRICT prevents silently clearing new referenced tables.
DO $truncate$
DECLARE v_tables text; v_count integer;
BEGIN
 SELECT count(*),string_agg(format('%I.%I',schemaname,tablename),',' ORDER BY schemaname,tablename)
 INTO v_count,v_tables FROM pg_tables WHERE (schemaname='control_center_private'
  AND left(tablename,13)='tennis_season'
  AND tablename<>'tennis_season_maintenance_control_v1')
OR (schemaname='public' AND (
  (left(tablename,7)='player_' AND tablename NOT IN(
    'player_skills','player_rankings','player_doubles_rankings','player_training_plans',
    'player_location_state','player_avatar_reservations','player_home_city_options','player_homepage_reviews'))
  OR (left(tablename,11)='tournament_' AND tablename NOT IN(
    'tournament_series','tournament_categories','tournament_doubles_settings',
    'tournament_doubles_ranking_point_rules','tournament_match_scheduling_rules',
    'tournament_prize_pool_rules','tournament_prize_pools','tournament_prize_payouts',
    'tournament_doubles_prize_payouts','tournament_prize_stage_weights','tournament_ranking_point_rules'))
  OR (left(tablename,9)='national_' AND tablename NOT IN(
    'national_associations','national_association_funds','national_association_treasuries',
    'national_team_config','national_team_competition_config','national_team_country_regions',
    'national_team_regions','national_team_divisions','national_team_fixture_formats','national_team_windows'))
  OR (left(tablename,13)='private_life_' AND tablename ~
    '(_history|_events|_sale_listings|_positions|_trades|_player_assets)$')
  OR left(tablename,8)='ranking_' OR left(tablename,16)='doubles_ranking_'
  OR (left(tablename,9)='referral_' AND tablename NOT IN(
    'referral_badge_catalog','referral_program_settings','referral_admins',
    'referral_codes','referral_user_devices'))
  OR (left(tablename,6)='staff_' AND tablename ~ '(_events|_offers|_negotiations)$')
  OR (left(tablename,12)='tennis_club_' AND tablename<>'tennis_club_settings')
  OR tablename IN(
    'ai_weekly_injury_runs','career_finance_transactions','career_tax_periods','user_notifications',
    'birthday_rewards','birthday_email_outbox','new_player_initialization_audit',
    'technical_sponsor_equipment_claims','staff_financial_events','referrals','tennis_clubs',
    'site_analytics_daily_pages','site_analytics_daily_sessions','site_analytics_daily_visitors')
));
 IF v_count<>160 OR v_tables IS NULL THEN
   RAISE EXCEPTION 'Reset inventory drifted: expected 160 tables, got %',v_count;
 END IF;
 EXECUTE 'TRUNCATE TABLE '||v_tables||' RESTRICT';
END $truncate$;

-- Rebuild structural Season 1 competition calendar (no results/entries).
INSERT INTO public.tournament_editions(id,tournament_series_id,season_number,status,created_at)
SELECT id,tournament_series_id,season_number,'scheduled',now()
FROM control_center_private.tennis_prelaunch_s1_editions_v1;
INSERT INTO public.tournament_world_competitions(id,tournament_edition_id,world,status,created_at)
SELECT id,tournament_edition_id,world,'scheduled',now()
FROM control_center_private.tennis_prelaunch_s1_competitions_v1;
INSERT INTO public.tournament_schedule_slots(
 id,tournament_edition_id,calendar_month,month_week,phase,slot_order,created_at,season_week)
SELECT id,tournament_edition_id,calendar_month,month_week,phase,slot_order,now(),season_week
FROM control_center_private.tennis_prelaunch_s1_schedule_v1;

-- Existing test logins remain, but their old tennis characters/careers do not.
DELETE FROM public.players WHERE player_type='human';

UPDATE public.game_clock
SET season=1,month=1,day=1,minute_of_day=0,speed_multiplier=2,
    is_paused=true,real_anchor_at=now(),updated_at=now()
WHERE id=1;
UPDATE public.season_transition_boundary_guard_v1
SET source_season=1,stop_at_total_seconds=31622400-1,enabled=true,updated_at=now()
WHERE id=true;
UPDATE control_center_private.tennis_season_maintenance_control_v1
SET status='off',source_season=null,target_season=null,starts_at=null,planned_reopen_at=null,
    revised_reopen_at=null,preseason_starts_at=null,preseason_ends_at=null,resumed_at=null,
    notice=null,updated_at=now()
WHERE id=true;

-- Restore all 834 AI abilities using the game's authoritative starting-profile builders.
WITH initial AS (
 SELECT p.id,p.preferred_surface,p.playing_style,
 public.build_starting_nine_skill_profile_v1(coalesce(p.preferred_surface,'Hard'),
   coalesce(p.playing_style,'All-court'),p.ai_starting_technical_total::integer,
   coalesce(p.ai_profile_number,0)::integer) AS t,
 public.build_starting_physical_profile_v1(coalesce(p.playing_style,'All-court'),
   p.ai_starting_physical_total::integer,coalesce(p.ai_profile_number,0)::integer) AS ph
 FROM public.players p WHERE p.player_type='ai'
)
UPDATE public.player_skills s SET
 preferred_surface=coalesce(i.preferred_surface,'Hard'),playing_style=coalesce(i.playing_style,'All-court'),
 serve=(i.t->>'serve')::smallint,forehand=(i.t->>'forehand')::smallint,
 backhand=(i.t->>'backhand')::smallint,return_skill=(i.t->>'return_skill')::smallint,
 volley=(i.t->>'volley')::smallint,slice=(i.t->>'slice')::smallint,
 drop_shot=(i.t->>'drop_shot')::smallint,lob=(i.t->>'lob')::smallint,smash=(i.t->>'smash')::smallint,
 fitness=(i.ph->>'fitness')::smallint,stamina=(i.ph->>'stamina')::smallint,
 recovery=(i.ph->>'recovery')::smallint,movement=(i.ph->>'movement')::smallint,
 fatigue=0,sharpness=50,morale=50,confidence=50,focus=50,updated_at=now()
FROM initial i WHERE s.player_id=i.id;
UPDATE public.player_rankings r SET ranking_points=0,created_at=now(),updated_at=now()
FROM public.players p WHERE p.id=r.player_id AND p.player_type='ai';
UPDATE public.player_doubles_rankings r SET ranking_points=0,created_at=now(),updated_at=now()
FROM public.players p WHERE p.id=r.player_id AND p.player_type='ai';
UPDATE public.player_training_plans t
SET training_type='day_off',focus_attribute=null,intensity='standard',focus_share=0.85,
    is_active=true,created_at=now(),updated_at=now()
FROM public.players p WHERE p.id=t.player_id AND p.player_type='ai';
UPDATE public.player_location_state s
SET current_city=p.home_city,current_country_code=p.country_code,
 current_continent=public.country_continent_v1(p.country_code),
 current_latitude=(SELECT h.latitude FROM public.player_home_city_options h
   WHERE h.country_code=p.country_code AND lower(h.city)=lower(p.home_city) AND h.is_active
   ORDER BY h.sort_order LIMIT 1),
 current_longitude=(SELECT h.longitude FROM public.player_home_city_options h
   WHERE h.country_code=p.country_code AND lower(h.city)=lower(p.home_city) AND h.is_active
   ORDER BY h.sort_order LIMIT 1),
 location_type='home',source_reference_id=null,location_since_absolute_day=0,updated_at=now()
FROM public.players p WHERE s.player_id=p.id AND p.player_type='ai';

-- Reset all game-controlled shared balances / campaign states; retain payment obligations.
UPDATE public.staff_members SET status='available',current_player_id=null,updated_at=now();
UPDATE public.national_associations
SET status='inactive',activation_started_by_user_id=null,activated_game_day=null,
    activated_season=null,updated_at=now();
DELETE FROM public.national_association_funds WHERE season_number>=2;
UPDATE public.national_association_funds
SET contributed_amount=0,status='open',completed_game_day=null,updated_at=now();
UPDATE public.national_association_treasuries
SET coins_balance=0,cash_balance_usd=0,lifetime_cash_income_usd=0,
    lifetime_cash_spent_usd=0,updated_at=now();
UPDATE public.national_team_windows SET status='planned',updated_at=now() WHERE season_number=1;
UPDATE public.tournament_prize_pools SET distributed_pool_usd=0,updated_at=now();
UPDATE public.ai_simulation_state SET last_training_absolute_day=-1,updated_at=now() WHERE singleton=true;
UPDATE public.private_life_quote_refresh_control
SET last_stock_refresh_game_second=null,last_crypto_refresh_game_second=null,updated_at=now()
WHERE id=1;

-- Restore the verified original AI day-zero assets. Generating new starter homes
-- can violate unique country/city property locations (for example, Seville).
INSERT INTO public.private_life_player_assets
SELECT * FROM control_center_private.tennis_prelaunch_ai_starter_assets_v1;
UPDATE public.private_life_player_assets SET created_at=now(),updated_at=now()
WHERE acquisition_type IN ('starter_home','ai_static');
-- The player's opening training plan is a deterministic function of their reset stats.
DO $reseed$
DECLARE v record;
BEGIN
 FOR v IN SELECT id FROM public.players WHERE player_type='ai' ORDER BY world,ai_profile_number LOOP
   PERFORM public.configure_ai_training_plan_v1(v.id,1,1::smallint,1::smallint);
 END LOOP;
END $reseed$;

-- Starting abilities should not create historical training entries.
TRUNCATE TABLE public.player_skill_history RESTRICT;
DELETE FROM public.user_notifications;

DO $postcheck$
DECLARE v_mismatch integer;
BEGIN
 IF (SELECT count(*) FROM public.players WHERE player_type='ai')<>834
 OR (SELECT count(*) FROM public.players WHERE player_type='human')<>0
 OR (SELECT count(*) FROM public.tournament_editions WHERE season_number=1 AND status='scheduled')<>597
 OR (SELECT count(*) FROM public.tournament_editions WHERE season_number<>1)<>0
 OR (SELECT count(*) FROM public.tournament_world_competitions WHERE status='scheduled')<>1194
 OR (SELECT count(*) FROM public.tournament_schedule_slots)<>613
 OR (SELECT count(*) FROM public.tournament_matches)<>0
 OR (SELECT count(*) FROM public.tournament_entries)<>0
 OR (SELECT count(*) FROM public.tournament_applications)<>0
 OR (SELECT count(*) FROM public.player_training_sessions)<>0
 OR (SELECT count(*) FROM public.player_skill_history)<>0
 OR (SELECT count(*) FROM public.player_injuries)<>0
 OR (SELECT count(*) FROM public.player_rankings WHERE ranking_points<>0)<>0
 OR (SELECT count(*) FROM public.player_doubles_rankings WHERE ranking_points<>0)<>0
 OR (SELECT count(*) FROM public.private_life_player_assets WHERE acquisition_type='starter_home')<>834
 OR (SELECT count(*) FROM public.private_life_player_assets WHERE acquisition_type='ai_static')<>834
 OR (SELECT count(*) FROM control_center_private.tennis_season_transition_runs_v1)<>0
 OR (SELECT count(*) FROM public.national_associations WHERE status<>'inactive')<>0
 OR (SELECT count(*) FROM public.national_association_treasuries
     WHERE coins_balance<>0 OR cash_balance_usd<>0)<>0
 OR (SELECT count(*) FROM public.national_team_windows WHERE season_number=1 AND status<>'planned')<>0
 OR NOT EXISTS(SELECT 1 FROM public.game_clock WHERE id=1 AND season=1 AND month=1 AND day=1
     AND minute_of_day=0 AND is_paused)
 OR EXISTS(SELECT 1 FROM public.registration_control WHERE public_signup_enabled)
 OR EXISTS(SELECT 1 FROM cron.job j JOIN control_center_private.tennis_prelaunch_cron_freeze_v1 f USING(jobid)
      WHERE j.active)
 THEN RAISE EXCEPTION 'Post-reset consistency failed, all changes must roll back'; END IF;
 SELECT count(*) INTO v_mismatch FROM public.players p JOIN public.player_skills s ON s.player_id=p.id
 WHERE p.player_type='ai' AND (
  (s.serve+s.forehand+s.backhand+s.return_skill+s.volley+s.slice+s.drop_shot+s.lob+s.smash)
   <>p.ai_starting_technical_total
  OR (s.fitness+s.stamina+s.recovery+s.movement)<>p.ai_starting_physical_total
  OR s.fatigue<>0);
 IF v_mismatch<>0 THEN RAISE EXCEPTION 'AI starting-profile mismatch: %',v_mismatch; END IF;
END $postcheck$;
SELECT (SELECT count(*) FROM public.tournament_editions) AS season1_editions,
 (SELECT count(*) FROM public.tournament_world_competitions) AS season1_competitions,
 (SELECT count(*) FROM public.players WHERE player_type='ai') AS ai_players,
 (SELECT count(*) FROM public.players WHERE player_type='human') AS human_players,
 (SELECT count(*) FROM public.private_life_player_assets) AS ai_starting_assets,
 (SELECT count(*) FROM public.player_training_plans) AS training_plans,
 (SELECT count(*) FROM auth.users) AS retained_logins,
 (SELECT count(*) FROM public.billing_transactions WHERE status='paid') AS paid_invoices,
 (SELECT sum(coins_balance) FROM public.user_wallets) AS retained_wallet_coins,
 (SELECT season FROM public.game_clock WHERE id=1) AS game_season,
 (SELECT is_paused FROM public.game_clock WHERE id=1) AS clock_paused;
COMMIT;
