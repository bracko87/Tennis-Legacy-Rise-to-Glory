-- Disposable source/clone: table data, function definitions and ACL fingerprints.
SET timezone='UTC';
SET datestyle='ISO, YMD';
SELECT format('SELECT %L, count(*), md5(coalesce(string_agg(to_jsonb(t)::text, E''\\n'' ORDER BY to_jsonb(t)::text), '''')) FROM %I.%I t;',n.nspname||'.'||c.relname,n.nspname,c.relname)
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ace_review','ace_cutover_review','ace_migration_journal','ace_migration_fixture') AND c.relkind='r'
OR n.nspname='public' AND c.relname='ace_legacy_rehearsal'
ORDER BY n.nspname,c.relname
\gexec
SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),md5(pg_get_functiondef(p.oid)),coalesce(p.proacl::text,'default')
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('ace_review','ace_cutover_review') ORDER BY 1,2,3;
SELECT n.nspname,c.relname,coalesce(c.relacl::text,'default'),c.relrowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('ace_review','ace_cutover_review','ace_migration_journal','ace_migration_fixture') AND c.relkind='r' ORDER BY 1,2;
SELECT n.nspname,c.relname,t.tgname,md5(pg_get_triggerdef(t.oid)) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND n.nspname IN ('ace_review','ace_cutover_review') ORDER BY 1,2,3;
