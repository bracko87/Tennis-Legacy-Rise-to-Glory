-- Remove test-only functions from the live exposed schema.
-- Checks refuse to proceed if real gameplay routines or cron commands reference them.
-- No player, match, ranking, clock, payment, or travel data is touched.
DO $cleanup$
DECLARE f record;
BEGIN
 IF EXISTS (
  SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog','information_schema')
    AND p.proname NOT LIKE '__e2e_%'
    AND p.prosrc LIKE '%__e2e_%'
 ) THEN RAISE EXCEPTION 'A non-test function references E2E helpers: refuse cleanup'; END IF;
 IF EXISTS (
  SELECT 1 FROM cron.job WHERE command ILIKE '%__e2e_%'
 ) THEN RAISE EXCEPTION 'An existing cron job references E2E helpers: refuse cleanup'; END IF;
 IF EXISTS (
  SELECT 1 FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
  WHERE NOT t.tgisinternal AND p.proname LIKE '__e2e_%'
 ) THEN RAISE EXCEPTION 'A trigger invokes an E2E helper: refuse cleanup'; END IF;
 FOR f IN SELECT p.oid::regprocedure AS signature
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND left(p.proname,6)='__e2e_'
 LOOP
  EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',f.signature);
  EXECUTE format('DROP FUNCTION %s RESTRICT',f.signature);
 END LOOP;
END;
$cleanup$;
