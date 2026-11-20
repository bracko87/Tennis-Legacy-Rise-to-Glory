-- Project Helios H08: READ-ONLY deletion dependency report.
-- Run in psql against staging or a read-only production connection.
-- Does not delete, update, archive, or create any records.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout = '30s';

-- Recursively enumerate FK references starting at auth.users and public.players.
-- Tracks paths (not only distinct constraints): a downstream table can be reached
-- through more than one parent. Cycle protection prevents endless traversal.
WITH RECURSIVE dependencies AS (
  SELECT c.oid AS constraint_oid, c.conname, c.conrelid AS child_oid,
         c.confrelid AS parent_oid, c.confdeltype, 1 AS depth,
         ARRAY[c.confrelid, c.conrelid] AS visited
  FROM pg_constraint c
  WHERE c.contype='f'
    AND c.confrelid IN ('auth.users'::regclass, 'public.players'::regclass)
  UNION ALL
  SELECT c.oid,c.conname,c.conrelid,c.confrelid,c.confdeltype,
         d.depth+1,d.visited||c.conrelid
  FROM pg_constraint c
  JOIN dependencies d ON c.confrelid=d.child_oid
  WHERE c.contype='f' AND d.depth<15
    AND NOT c.conrelid=ANY(d.visited)
)
SELECT depth, parent_oid::regclass AS parent_table,
       child_oid::regclass AS child_table, conname AS foreign_key,
       CASE confdeltype WHEN 'c' THEN 'CASCADE'
                        WHEN 'n' THEN 'SET NULL'
                        WHEN 'd' THEN 'SET DEFAULT'
                        WHEN 'r' THEN 'RESTRICT'
                        WHEN 'a' THEN 'NO ACTION' END AS on_delete
FROM dependencies
ORDER BY depth, parent_table::text, child_table::text, foreign_key;

-- Stable direct-dependency baseline. Explicitly report changes instead
-- of silently treating previously audited counts as exhaustive.
WITH direct_fks AS (
  SELECT confdeltype FROM pg_constraint
  WHERE contype='f'
    AND confrelid IN ('auth.users'::regclass,'public.players'::regclass)
)
SELECT count(*) AS direct_fk_count,
       count(*) FILTER (WHERE confdeltype='c') AS cascades,
       count(*) FILTER (WHERE confdeltype='n') AS set_nulls,
       count(*) FILTER (WHERE confdeltype='r') AS restricts,
       count(*) FILTER (WHERE confdeltype='a') AS no_actions,
       count(*) FILTER (WHERE confdeltype='d') AS set_defaults
FROM direct_fks;

-- Report the current account deletion routine without executing it.
SELECT p.oid::regprocedure AS deletion_function,
       p.prosecdef AS security_definer,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='delete_tennis_legacy_account_v1';

ROLLBACK;
