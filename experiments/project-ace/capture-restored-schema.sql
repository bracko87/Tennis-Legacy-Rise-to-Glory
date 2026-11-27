-- Metadata only. Authorized isolated restored database only; no application rows or routine bodies.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='3s';
SET LOCAL search_path=pg_catalog;
\set migration_json '[]'
\set cron_json '[]'
SELECT to_regclass('supabase_migrations.schema_migrations') IS NOT NULL AS has_history, to_regclass('cron.job') IS NOT NULL AS has_cron \gset
\if :has_history
SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name) ORDER BY version),'[]'::jsonb)::text AS migration_json FROM supabase_migrations.schema_migrations \gset
\endif
\if :has_cron
SELECT coalesce(jsonb_agg(jsonb_build_object('name',jobname,'active',active,'schedule',schedule) ORDER BY jobname,schedule,active),'[]'::jsonb)::text AS cron_json FROM cron.job \gset
\endif
WITH roles AS (SELECT oid,rolname FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role')),
rels AS (
 SELECT c.oid,n.nspname||'.'||c.relname AS name,c.relrowsecurity,c.relforcerowsecurity,c.relkind
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE c.relkind IN ('r','p','v','m') AND n.nspname IN ('public','control_center_private')
 AND (c.relname ~ '^(tournament_|player_|career_|ranking_|tennis_guest|national_)' OR c.relname='players')
), routines AS (
 SELECT p.oid,n.nspname||'.'||p.proname AS name,n.nspname||'.'||p.proname||'('||oidvectortypes(p.proargtypes)||')' AS signature,p.prosecdef,p.provolatile,md5(pg_get_functiondef(p.oid)) AS hash
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.prokind IN ('f','p') AND n.nspname IN ('public','control_center_private')
), tables_json AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('name',r.name,'kind',r.relkind,'rls',r.relrowsecurity,'force_rls',r.relforcerowsecurity,
 'columns',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'default_hash',md5(pg_get_expr(d.adbin,d.adrelid))) ORDER BY a.attnum),'[]'::jsonb) FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid=r.oid AND a.attnum>0 AND NOT a.attisdropped),
 'constraints',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',c.conname,'hash',md5(pg_get_constraintdef(c.oid))) ORDER BY c.conname),'[]'::jsonb) FROM pg_constraint c WHERE c.conrelid=r.oid),
 'grants',(SELECT coalesce(jsonb_object_agg(rolname,jsonb_build_object('select',has_table_privilege(oid,r.oid,'SELECT'),'insert',has_table_privilege(oid,r.oid,'INSERT'),'update',has_table_privilege(oid,r.oid,'UPDATE'),'delete',has_table_privilege(oid,r.oid,'DELETE'),'truncate',has_table_privilege(oid,r.oid,'TRUNCATE'))),'{}'::jsonb) FROM roles)) ORDER BY r.name),'[]'::jsonb) AS val FROM rels r
), routine_json AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('name',r.name,'signature',r.signature,'hash',r.hash,'security_definer',r.prosecdef,'volatility',r.provolatile,
 'execute',(SELECT coalesce(jsonb_object_agg(rolname,has_function_privilege(oid,r.oid,'EXECUTE')),'{}'::jsonb) FROM roles)) ORDER BY r.signature),'[]'::jsonb) AS val FROM routines r
), trigger_json AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('table',r.name,'name',t.tgname,'enabled',t.tgenabled,'hash',md5(pg_get_triggerdef(t.oid))) ORDER BY r.name,t.tgname),'[]'::jsonb) AS val FROM rels r JOIN pg_trigger t ON t.tgrelid=r.oid WHERE NOT t.tgisinternal
), policies_json AS (
 SELECT coalesce(jsonb_agg(jsonb_build_object('table',r.name,'name',p.polname,'hash',md5(concat_ws('|',p.polcmd::text,p.polpermissive::text,pg_get_expr(p.polqual,p.polrelid),pg_get_expr(p.polwithcheck,p.polrelid),(SELECT string_agg(CASE WHEN v=0 THEN 'PUBLIC' ELSE coalesce((SELECT rolname FROM pg_roles WHERE oid=v),'unknown') END,',' ORDER BY CASE WHEN v=0 THEN 'PUBLIC' ELSE coalesce((SELECT rolname FROM pg_roles WHERE oid=v),'unknown') END) FROM unnest(p.polroles) AS u(v))))) ORDER BY r.name,p.polname),'[]'::jsonb) AS val FROM rels r JOIN pg_policy p ON p.polrelid=r.oid
)
SELECT jsonb_build_object('schema','ace-restored-catalog-v1','server_major',split_part(current_setting('server_version'),'.',1),'roles',(SELECT coalesce(jsonb_agg(rolname ORDER BY rolname),'[]'::jsonb) FROM roles),'tables',tables_json.val,'routines',routine_json.val,'triggers',trigger_json.val,'policies',policies_json.val,'migration_history',:'migration_json'::jsonb,'cron',:'cron_json'::jsonb,'has_history',:'has_history'::boolean,'has_cron',:'has_cron'::boolean) FROM tables_json,routine_json,trigger_json,policies_json;
ROLLBACK;
