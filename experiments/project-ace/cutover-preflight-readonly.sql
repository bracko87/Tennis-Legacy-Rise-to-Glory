-- MANUAL REVIEW ONLY; not a migration. Run on an authorized restored database first.
-- No player identifiers, match payloads, secrets, or account data are selected.
BEGIN TRANSACTION READ ONLY;
SET LOCAL statement_timeout = '15s';
SELECT current_database() AS database_name, current_setting('server_version') AS server_version;
-- Full inventory of routines whose bodies reference a match table or relevant entry points.
-- Dynamic SQL and external workers require independent source audit; this query is not exhaustive.
SELECT n.nspname AS schema_name,p.proname AS routine_name,pg_get_function_identity_arguments(p.oid) AS arguments,
       md5(pg_get_functiondef(p.oid)) AS definition_md5,p.prosecdef AS security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE p.prokind IN ('f','p') AND n.nspname IN ('public','control_center_private')
AND (p.proname ~* '(tournament.*(match|draw)|match.*(engine|replay|finaliz)|guest.*retire|travel.*no.show|health.*surrender)'
 OR p.prosrc ~* '(tournament_match_simulations|tournament_matches|process_due_match_engine_v1|start_due_match_replays_v1|finalize_match_replay_v1)')
ORDER BY 1,2,3;
SELECT n.nspname AS schema_name,c.relname AS table_name,t.tgname AS trigger_name,t.tgenabled,
       t.tgfoid::regprocedure::text AS trigger_routine,md5(pg_get_triggerdef(t.oid)) AS definition_md5
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE NOT t.tgisinternal AND n.nspname='public' AND c.relname IN ('tournament_matches','tournament_match_simulations','tournament_match_sets','tournament_match_player_stats','player_tournament_results')
ORDER BY 1,2,3;
SELECT status, count(*) AS matches FROM public.tournament_matches GROUP BY status ORDER BY status;
SELECT simulation_status,count(*) AS simulations FROM public.tournament_match_simulations GROUP BY simulation_status ORDER BY simulation_status;
SELECT m.status,s.simulation_status,count(*) AS matches
FROM public.tournament_matches m JOIN public.tournament_match_simulations s ON s.match_id=m.id
GROUP BY 1,2 ORDER BY 1,2;
SELECT c.relname AS table_name,c.relrowsecurity AS rls_enabled,
       has_table_privilege('anon',c.oid,'INSERT') AS anon_insert,
       has_table_privilege('authenticated',c.oid,'UPDATE') AS authenticated_update
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relname IN ('tournament_matches','tournament_match_simulations','tournament_match_sets','tournament_match_player_stats','player_tournament_results')
ORDER BY 1;
-- Do not print cron commands: some installations may embed credentials.
SELECT jobname,active,schedule FROM cron.job ORDER BY jobname;
ROLLBACK;
