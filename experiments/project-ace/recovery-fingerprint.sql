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

-- Include structural invariants as well as table row fingerprints.
SELECT n.nspname,c.relname,k.conname,pg_get_constraintdef(k.oid),k.convalidated
FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ace_review','ace_cutover_review','ace_migration_journal','ace_migration_fixture') ORDER BY 1,2,3;
SELECT n.nspname,c.relname,i.relname,pg_get_indexdef(i.oid),x.indisvalid,x.indisready
FROM pg_index x JOIN pg_class c ON c.oid=x.indrelid JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('ace_review','ace_cutover_review','ace_migration_journal','ace_migration_fixture') ORDER BY 1,2,3;
-- pg_dump may restore an explicit owner-only ACL as NULL (default).
-- Compare normalized grants, not representation or array order. Preserve grantor,
-- grantee, privilege and grant option; distinguish explicit empty ACL from default.
SELECT n.nspname,pg_get_userbyid(n.nspowner),
 coalesce((SELECT jsonb_agg(jsonb_build_array(pg_get_userbyid(a.grantor),CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END,a.privilege_type,a.is_grantable)
 ORDER BY a.grantor,a.grantee,a.privilege_type,a.is_grantable)
 FROM aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a),'[]'::jsonb)
FROM pg_namespace n
WHERE nspname IN ('ace_review','ace_cutover_review','ace_migration_journal','ace_migration_fixture') ORDER BY 1;
