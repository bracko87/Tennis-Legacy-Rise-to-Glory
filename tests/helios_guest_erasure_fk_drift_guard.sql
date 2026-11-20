-- Project Helios H08. Read-only direct dependency drift guard.
-- Verified catalog snapshot: 2026-11-20, Tennis Legacy production schema.
-- This is a necessary but NOT sufficient prerequisite for physical deletion.
-- It checks direct FK definitions; transitive FKs, triggers, retention policy,
-- storage ownership, and all full-schema integration tests remain separate.
-- No SQL in this file modifies user data, schema, or accounts.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout = '30s';

DO $guard$
DECLARE
  v_count bigint;
  v_digest text;
BEGIN
  WITH deps AS (
    SELECT c.conname,
           c.confrelid::regclass::text AS parent_table,
           c.conrelid::regclass::text AS child_table,
           c.confdeltype::text AS delete_action,
           pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c
    WHERE c.contype = 'f'
      AND c.confrelid IN ('auth.users'::regclass, 'public.players'::regclass)
  ),
  normalized AS (
    SELECT concat_ws('|',parent_table,child_table,conname,delete_action,definition)
      AS signature
    FROM deps
  )
  SELECT count(*),md5(string_agg(signature,E'\n' ORDER BY signature))
  INTO v_count,v_digest
  FROM normalized;

  IF v_count <> 188 OR v_digest IS DISTINCT FROM
     '846107417041388f01cd703985f631d1' THEN
    RAISE EXCEPTION
      'HELIOS HARD DELETE BLOCKED: direct FK graph drift (count %, digest %). Re-audit every dependent table before approval.',
      v_count,v_digest;
  END IF;
  RAISE NOTICE 'HELIOS direct FK baseline matches 188 and digest %. Hard deletion is STILL NOT APPROVED.',v_digest;
END;
$guard$;

ROLLBACK;
