-- Project Helios H08: production schema metadata-only contract.
-- Designed to run READ-ONLY. It does not inspect or change game/user rows.
-- PASS is ONLY schema compatibility, NEVER deletion authorization.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout = '30s';

DO $guard$
DECLARE
 v_issues text;
BEGIN
 WITH expected_fk(child,parent,constraint_name,delete_action) AS (
  VALUES
   ('public.players','auth.users','players_owner_user_id_fkey','c'),
   ('public.tournament_matches','public.players','tournament_matches_player1_id_fkey','n'),
   ('public.tournament_matches','public.players','tournament_matches_player2_id_fkey','n'),
   ('public.tournament_matches','public.players','tournament_matches_winner_id_fkey','n'),
   ('public.tournament_match_sets','public.tournament_matches','tournament_match_sets_match_id_fkey','c'),
   ('public.tournament_doubles_teams','public.players','tournament_doubles_teams_player1_id_fkey','c'),
   ('public.tournament_doubles_teams','public.players','tournament_doubles_teams_player2_id_fkey','c'),
   ('public.tournament_doubles_matches','public.tournament_doubles_teams','tournament_doubles_matches_team1_id_fkey','n'),
   ('public.tournament_doubles_matches','public.tournament_doubles_teams','tournament_doubles_matches_team2_id_fkey','n'),
   ('public.tournament_doubles_matches','public.tournament_doubles_teams','tournament_doubles_matches_winner_team_id_fkey','n'),
   ('public.player_tournament_results','public.players','player_tournament_results_player_id_fkey','c'),
   ('public.player_doubles_tournament_results','public.players','player_doubles_tournament_results_player_id_fkey','c'),
   ('public.player_doubles_tournament_results','public.tournament_doubles_teams','player_doubles_tournament_results_team_id_fkey','c'),
   ('public.player_ranking_snapshots','public.players','player_ranking_snapshots_player_id_fkey','c'),
   ('public.billing_transactions','auth.users','billing_transactions_user_id_fkey','c'),
   ('public.premium_memberships','auth.users','premium_memberships_user_id_fkey','c'),
   ('public.coin_ledger','auth.users','coin_ledger_user_id_fkey','c'),
   ('public.user_wallets','auth.users','user_wallets_user_id_fkey','c'),
   ('public.career_finance_transactions','public.players','career_finance_transactions_player_id_fkey','c'),
   ('public.tennis_premium_trials_v1','auth.users','tennis_premium_trials_v1_user_id_fkey','c')
 ), missing_fk AS (
  SELECT e.child||'.'||e.constraint_name AS id
  FROM expected_fk e
  LEFT JOIN pg_constraint c ON c.conname=e.constraint_name
    AND c.conrelid=to_regclass(e.child)
    AND c.confrelid=to_regclass(e.parent)
    AND c.contype='f' AND c.confdeltype::text=e.delete_action
  WHERE c.oid IS NULL
 ), expected_col(schema_name,table_name,column_name) AS (
  VALUES
   ('public','players','owner_user_id'),
   ('public','players','first_name'),('public','players','last_name'),
   ('public','players','image_path'),('public','players','home_city'),
   ('public','tournament_matches','winner_id'),
   ('public','tournament_matches','player1_id'),
   ('public','tournament_matches','player2_id'),
   ('public','tournament_matches','status'),
   ('public','tournament_match_sets','match_id'),
   ('public','tournament_doubles_teams','player1_id'),
   ('public','tournament_doubles_teams','player2_id'),
   ('public','tournament_doubles_matches','winner_team_id'),
   ('public','player_tournament_results','ranking_points_earned'),
   ('public','player_doubles_tournament_results','ranking_points_earned'),
   ('public','player_ranking_snapshots','ranking_points'),
   ('public','billing_transactions','stripe_payment_intent_id'),
   ('public','billing_transactions','amount_eur_cents'),
   ('public','premium_memberships','stripe_subscription_id'),
   ('public','coin_ledger','balance_after'),
   ('public','career_finance_transactions','metadata'),
   ('control_center_private','tennis_guest_trials_v1','converted_at'),
   ('control_center_private','tennis_guest_trials_v1','retired_at'),
   ('control_center_private','tennis_guest_trials_v1','expires_at')
 ), missing_col AS (
  SELECT schema_name||'.'||table_name||'.'||column_name AS id
  FROM expected_col e
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema=e.schema_name
      AND c.table_name=e.table_name AND c.column_name=e.column_name
  )
 )
 SELECT string_agg(id,', ' ORDER BY id) INTO v_issues
 FROM (
  SELECT 'MISSING_OR_CHANGED_FK:'||id AS id FROM missing_fk
  UNION ALL SELECT 'MISSING_COLUMN:'||id FROM missing_col
 ) d;

 IF v_issues IS NOT NULL THEN
  RAISE EXCEPTION 'HELIOS HISTORY/FINANCE SCHEMA CONTRACT FAILED: %',v_issues;
 END IF;
 RAISE NOTICE 'HELIOS PASS: 20 critical FKs and 24 columns verified; physical guest deletion remains FORBIDDEN';
END;
$guard$;
ROLLBACK;
