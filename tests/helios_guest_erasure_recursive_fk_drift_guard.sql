-- Helios H08: full recursive FK topology drift check.
-- READ-ONLY metadata check, not permission to delete accounts. A passing
-- result MUST NOT activate any erasure worker or public Guest Mode.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout='40s';

DO $guard$
DECLARE
 v_paths bigint;
 v_tables bigint;
 v_max_depth integer;
 v_digest text;
BEGIN
 WITH RECURSIVE dependency_paths AS (
  SELECT c.conrelid AS child_oid,c.confrelid AS parent_oid,
         ARRAY[c.confrelid,c.conrelid]::oid[] AS visited,
         ARRAY[c.oid]::oid[] AS fk_path,1 AS depth
  FROM pg_constraint c
  WHERE c.contype='f'
    AND c.confrelid IN ('auth.users'::regclass,'public.players'::regclass)
  UNION ALL
  SELECT c.conrelid,c.confrelid,p.visited||c.conrelid,
         p.fk_path||c.oid,p.depth+1
  FROM dependency_paths p
  JOIN pg_constraint c ON c.contype='f' AND c.confrelid=p.child_oid
  WHERE p.depth<12 AND NOT c.conrelid=ANY(p.visited)
 ), signatures AS (
  SELECT p.child_oid,p.depth,
    array_to_string(ARRAY(
     SELECT c.conrelid::regclass::text || '=>' ||
            c.confrelid::regclass::text || ':' ||
            c.conname || ':' || c.confdeltype::text || ':' ||
            pg_get_constraintdef(c.oid)
     FROM unnest(p.fk_path) AS hop(oid)
     JOIN pg_constraint c ON c.oid=hop.oid
    ),' > ') AS chain
  FROM dependency_paths p
 )
 SELECT count(*),count(DISTINCT child_oid),max(depth),
        md5(string_agg(chain,E'\n' ORDER BY chain))
 INTO v_paths,v_tables,v_max_depth,v_digest
 FROM signatures;

 IF v_paths<>818 OR v_tables<>180 OR v_max_depth<>5
 THEN RAISE EXCEPTION
  'HELIOS HARD DELETE BLOCKED: transitive FK graph drift (paths %, tables %, max depth %).',
  v_paths,v_tables,v_max_depth;
 END IF;
 -- Signature set after new live-schema review, intentionally omitted until
 -- audited baseline has been recorded; the count gate is only partial.
 RAISE NOTICE
  'HELIOS recursive FK count baseline matches (% paths, % tables, max depth %), fingerprint %. Deletion remains BLOCKED.',
  v_paths,v_tables,v_max_depth,v_digest;
END;
$guard$;

ROLLBACK;
