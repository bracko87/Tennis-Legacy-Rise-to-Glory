-- Explicit isolated restore or synthetic CI fixture only. No production use.
-- psql -X -qAt -v ON_ERROR_STOP=1 -v competition_id=<uuid> -f capture-legacy-tournament.sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='15s';
SET LOCAL lock_timeout='3s';
SET LOCAL search_path=pg_catalog;
SET LOCAL row_security=off;
DO $guard$
BEGIN
 IF inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet THEN RAISE EXCEPTION 'local isolated database required'; END IF;
 IF NOT ((current_database()='ace_legacy_shadow' AND inet_server_port()=55433) OR (current_database()='ace_tournament_capture' AND inet_server_port()=5432)) THEN RAISE EXCEPTION 'dedicated capture database required'; END IF;
 IF to_regclass('ace_shadow_guard.approval') IS NULL OR to_regclass('cron.job') IS NULL THEN RAISE EXCEPTION 'missing isolation evidence'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ace_shadow_guard.approval WHERE singleton AND approved_read_only AND restore_id IS NOT NULL AND marker=CASE WHEN current_database()='ace_tournament_capture' THEN 'ace-tournament-synthetic-ci-v029' ELSE 'ace-legacy-shadow-isolated-v027' END) THEN RAISE EXCEPTION 'capture not approved'; END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE active IS DISTINCT FROM false) THEN RAISE EXCEPTION 'active scheduled jobs'; END IF;
END
$guard$;
WITH c AS (
 SELECT id,tournament_edition_id,world,status FROM public.tournament_world_competitions WHERE id=:'competition_id'::uuid
), e AS (
 SELECT e.id,e.season_number,e.status FROM public.tournament_editions e JOIN c ON c.tournament_edition_id=e.id
), d AS (
 SELECT p.competition_id,p.main_draw_size,p.qualifying_draw_size,p.qualifier_slots,p.published_at FROM public.tournament_draw_publications p JOIN c ON c.id=p.competition_id
), l AS (
 SELECT a.competition_id,a.field_locked_at,a.field_locked_game_second FROM public.tournament_competition_entry_cycles a JOIN c ON c.id=a.competition_id
), entries AS (
 SELECT x.id,x.player_id,x.competition_id,x.world,x.draw_type,x.entry_status,x.bracket_slot FROM public.tournament_entries x JOIN c ON c.id=x.competition_id
), matches AS (
 SELECT m.id,m.competition_id,m.draw_type,m.round_number,m.match_number,m.round_label,m.bracket_size,m.status,m.started_at,m.completed_at,m.winner_id,m.completion_reason,m.actual_duration_minutes,m.estimated_duration_minutes,m.schedule_reason,m.updated_at,m.player1_id,m.player2_id,m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number FROM public.tournament_matches m JOIN c ON c.id=m.competition_id
)
SELECT jsonb_build_object('schema','ace-legacy-tournament-export-v1','complete_export',true,'consistent_snapshot_attested',true,
 'capture_scope',CASE WHEN current_database()='ace_tournament_capture' THEN 'synthetic_ci' ELSE 'operator_supplied_restore' END,
 'restore_id',(SELECT restore_id FROM ace_shadow_guard.approval WHERE singleton),
 'competition',(SELECT to_jsonb(c) FROM c),'edition',(SELECT to_jsonb(e) FROM e),'publication',(SELECT to_jsonb(d) FROM d),'entry_cycle',(SELECT to_jsonb(l) FROM l),
 'entries',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]'::jsonb) FROM entries x),
 'matches',(SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY m.round_number,m.match_number,m.id),'[]'::jsonb) FROM matches m),
 'results',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',r.id) ORDER BY r.id),'[]'::jsonb) FROM public.player_tournament_results r JOIN c ON c.id=r.competition_id),
 'simulations',(SELECT coalesce(jsonb_agg(jsonb_build_object('match_id',s.match_id) ORDER BY s.match_id),'[]'::jsonb) FROM public.tournament_match_simulations s JOIN matches m ON m.id=s.match_id),
 'cancellations',(SELECT coalesce(jsonb_agg(jsonb_build_object('competition_id',x.competition_id)),'[]'::jsonb) FROM public.tournament_cancellations x JOIN c ON c.id=x.competition_id));
ROLLBACK;
