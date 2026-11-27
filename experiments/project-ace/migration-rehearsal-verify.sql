-- Run only against the marked disposable database after atomic install.
DO $$
DECLARE n integer; role_name text; t record; p record;
BEGIN
 IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE singleton AND marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'wrong rehearsal database'; END IF;
 IF (SELECT count(*) FROM ace_migration_journal.installed)<>17 THEN RAISE EXCEPTION 'missing migration journal entries'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.policy WHERE singleton AND NOT enabled AND cardinality(competitions)=0) THEN RAISE EXCEPTION 'routing is not disabled by default'; END IF;
 IF (SELECT count(*) FROM ace_cutover_review.matches)<>0 OR (SELECT count(*) FROM ace_review.finalized_prizes)<>0 THEN RAISE EXCEPTION 'unexpected initial rows'; END IF;
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated'] LOOP
  IF has_schema_privilege(role_name,'ace_review','USAGE') OR has_schema_privilege(role_name,'ace_cutover_review','USAGE') OR has_schema_privilege(role_name,'ace_migration_journal','USAGE') THEN RAISE EXCEPTION 'client schema exposure: %',role_name; END IF;
  FOR t IN SELECT c.oid FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname IN ('ace_review','ace_cutover_review','ace_migration_journal') AND c.relkind IN ('r','p','v','m') LOOP
   IF has_table_privilege(role_name,t.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'client table exposure: %',role_name; END IF;
  END LOOP;
  FOR p IN SELECT f.oid FROM pg_proc f JOIN pg_namespace s ON s.oid=f.pronamespace WHERE s.nspname IN ('ace_review','ace_cutover_review') LOOP
   IF has_function_privilege(role_name,p.oid,'EXECUTE') THEN RAISE EXCEPTION 'client function exposure: %',role_name; END IF;
  END LOOP;
 END LOOP;
 FOREACH role_name IN ARRAY ARRAY['ace_cutover_ace','ace_cutover_legacy','ace_cutover_external'] LOOP
  FOR t IN SELECT c.oid FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname IN ('ace_review','ace_cutover_review','ace_migration_journal') AND c.relkind IN ('r','p') LOOP
   IF has_table_privilege(role_name,t.oid,'INSERT,UPDATE,DELETE,TRUNCATE') THEN RAISE EXCEPTION 'engine direct write exposure: %',role_name; END IF;
  END LOOP;
 END LOOP;
 IF NOT has_function_privilege('ace_cutover_ace','ace_cutover_review.claim(text)','EXECUTE') OR NOT has_function_privilege('ace_cutover_legacy','ace_cutover_review.claim(text)','EXECUTE') OR has_function_privilege('ace_cutover_external','ace_cutover_review.claim(text)','EXECUTE') OR has_function_privilege('ace_cutover_legacy','ace_cutover_review.settle_owned(jsonb,jsonb)','EXECUTE') THEN RAISE EXCEPTION 'ownership grant drift'; END IF;
 RAISE NOTICE 'PASS atomic installation journal, disabled routing and role isolation';
END $$;
