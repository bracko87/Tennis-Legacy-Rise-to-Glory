-- E1: metadata-only, manual authorized endpoint review. Not a migration.
BEGIN TRANSACTION READ ONLY;
SET LOCAL search_path=pg_catalog;
SET LOCAL statement_timeout='20s';
SET LOCAL lock_timeout='3s';
WITH watched(name) AS (VALUES
 ('tournament_matches'),('tournament_match_simulations'),('tournament_match_sets'),('tournament_match_player_stats'),
 ('player_tournament_results'),('player_finance_transactions'),('player_ranking_contributions'),('player_rankings'),('ranking_defence_cycles'),('game_clock')
), roles AS (SELECT oid,rolname FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role')),
rels AS (
 SELECT w.name,c.oid,c.relrowsecurity,c.relforcerowsecurity FROM watched w
 LEFT JOIN pg_namespace n ON n.nspname='public'
 LEFT JOIN pg_class c ON c.relnamespace=n.oid AND c.relname=w.name AND c.relkind IN ('r','p')
), routines AS (
 SELECT p.oid,n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')' AS signature,
 md5(pg_get_functiondef(p.oid)) AS definition_md5,p.prosecdef AS security_definer
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE p.prokind IN ('f','p') AND n.nspname IN ('public','control_center_private')
 AND (p.proname ~* '(match|tournament|ranking|tax|injur|equipment|guest|career|travel|schedule|watchdog)'
 OR p.prosrc ~* '(tournament_matches|tournament_match_simulations|player_tournament_results|player_finance_transactions|player_ranking_contributions|process_weekly_rankings_v1|finalize_match_replay_v1)')
), triggers AS (
 SELECT n.nspname||'.'||c.relname AS relation,t.tgname AS name,t.tgenabled AS enabled,
 md5(pg_get_triggerdef(t.oid)) AS definition_md5,md5(pg_get_functiondef(t.tgfoid)) AS routine_md5
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE NOT t.tgisinternal AND n.nspname='public' AND c.relname IN (SELECT name FROM watched)
)
SELECT jsonb_build_object('schema','ace-integration-inventory-v1','review_only',true,'production_ready',false,
 'server_major',current_setting('server_version_num')::int/10000,
 'roles',(SELECT coalesce(jsonb_agg(rolname ORDER BY rolname),'[]'::jsonb) FROM roles),
 'relations',(SELECT jsonb_agg(jsonb_build_object('name',r.name,'present',r.oid IS NOT NULL,'rls',r.relrowsecurity,'force_rls',r.relforcerowsecurity,
 'grants',(SELECT coalesce(jsonb_object_agg(rolname,jsonb_build_object('select',has_table_privilege(roles.oid,r.oid,'SELECT'),'insert',has_table_privilege(roles.oid,r.oid,'INSERT'),'update',has_table_privilege(roles.oid,r.oid,'UPDATE'),'delete',has_table_privilege(roles.oid,r.oid,'DELETE'),'truncate',has_table_privilege(roles.oid,r.oid,'TRUNCATE'))),'{}'::jsonb) FROM roles WHERE r.oid IS NOT NULL)) ORDER BY r.name) FROM rels r),
 'routines',(SELECT coalesce(jsonb_agg(jsonb_build_object('signature',r.signature,'definition_md5',r.definition_md5,'security_definer',r.security_definer,
 'execute',(SELECT coalesce(jsonb_object_agg(rolname,has_function_privilege(roles.oid,r.oid,'EXECUTE')),'{}'::jsonb) FROM roles)) ORDER BY r.signature),'[]'::jsonb) FROM routines r),
 'triggers',(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY relation,name),'[]'::jsonb) FROM triggers t),
 'limitations',jsonb_build_array('Pattern-based routine inventory is not exhaustive','External callers and dynamic SQL require independent audit','No application records or routine bodies exported','No source authentication or production authorization'));
ROLLBACK;
