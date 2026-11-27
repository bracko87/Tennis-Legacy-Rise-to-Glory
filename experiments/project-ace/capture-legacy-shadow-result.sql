-- Authorized, air-gapped restored database only. Never install on live systems.
-- Invocation: psql -X -qAt -v ON_ERROR_STOP=1 -v match_id=<uuid> -f capture-legacy-shadow-result.sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='3s';
SET LOCAL search_path=pg_catalog;
DO $guard$
BEGIN
 IF current_database()<>'ace_legacy_shadow' OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet OR inet_server_port()<>55433 THEN RAISE EXCEPTION 'dedicated local shadow restore required'; END IF;
 IF to_regclass('ace_shadow_guard.approval') IS NULL THEN RAISE EXCEPTION 'missing restore approval marker'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ace_shadow_guard.approval WHERE singleton AND marker='ace-legacy-shadow-isolated-v027' AND approved_read_only) THEN RAISE EXCEPTION 'restore not approved'; END IF;
 IF to_regclass('cron.job') IS NULL THEN RAISE EXCEPTION 'cron inventory required'; END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE active IS DISTINCT FROM false) THEN RAISE EXCEPTION 'active scheduled jobs'; END IF;
END
$guard$;
WITH target AS (
 SELECT m.id,m.competition_id,m.player1_id,m.player2_id,m.winner_id,m.status,m.started_at,m.completed_at,m.actual_duration_minutes,m.completion_reason,
 m.draw_type,m.round_number,m.round_label,m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number
 FROM public.tournament_matches m WHERE m.id=:'match_id'::uuid
), sim AS (
 SELECT s.match_id,s.engine_version,s.engine_seed,s.simulation_status,s.final_winner_id,s.total_games,s.total_points,s.replay_duration_seconds,s.sets_payload,s.player1_stats,s.player2_stats
 FROM public.tournament_match_simulations s JOIN target t ON t.id=s.match_id
), sets AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('set_number',s.set_number,'player1_games',s.player1_games,'player2_games',s.player2_games,'player1_tiebreak_points',s.player1_tiebreak_points,'player2_tiebreak_points',s.player2_tiebreak_points,'status',s.status) ORDER BY s.set_number),'[]'::jsonb) AS rows
 FROM public.tournament_match_sets s JOIN target t ON t.id=s.match_id
), stats AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('player_id',s.player_id,'aces',s.aces,'double_faults',s.double_faults,'first_serves_in',s.first_serves_in,'first_serves_total',s.first_serves_total,'first_serve_points_won',s.first_serve_points_won,'first_serve_points_played',s.first_serve_points_played,'second_serve_points_won',s.second_serve_points_won,'second_serve_points_played',s.second_serve_points_played,'break_points_won',s.break_points_won,'break_points_total',s.break_points_total,'winners',s.winners,'unforced_errors',s.unforced_errors,'total_points_won',s.total_points_won) ORDER BY CASE WHEN s.player_id=t.player1_id THEN 0 WHEN s.player_id=t.player2_id THEN 1 ELSE 2 END,s.player_id),'[]'::jsonb) AS rows
 FROM public.tournament_match_player_stats s JOIN target t ON t.id=s.match_id
), routines AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('signature',n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')','definition_md5',md5(pg_get_functiondef(p.oid))) ORDER BY n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')'),'[]'::jsonb) AS rows
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind IN ('f','p') AND p.proname IN ('simulate_tournament_match_v1','prepare_tournament_match_simulation_v1','finalize_match_replay_v1','get_match_engine_profile_v1','simulated_tennis_duration_minutes_v1')
)
SELECT jsonb_build_object('schema','ace-legacy-shadow-capture-v1','restore_id',(SELECT restore_id FROM ace_shadow_guard.approval WHERE singleton),'match',(SELECT to_jsonb(t) FROM target t),'simulation',(SELECT to_jsonb(s) FROM sim s),'sets',sets.rows,'stats',stats.rows,'routines',routines.rows) FROM sets,stats,routines;
ROLLBACK;
