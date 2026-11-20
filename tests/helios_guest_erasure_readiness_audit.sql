-- Project Helios H08: read-only guest deletion readiness and retention inventory.
-- Use only for inspection; no Auth deletion or modification. Outputs NO user data.
-- Labels below are INVESTIGATION CATEGORIES, not approval to retain/delete data.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout='45s';

-- Direct constraints: every relationship must receive an explicit approved
-- treatment before the production deletion worker can be implemented.
WITH relationships AS (
 SELECT c.oid, c.conname, c.confrelid::regclass::text AS parent_table,
        c.conrelid::regclass::text AS dependent_table,
        c.confdeltype,
        CASE
          WHEN c.conrelid::regclass::text ~* '(tournament|ranking|national_team|national_captain|national_association|tennis_club|player_doubles|player_tournament_results)'
            THEN 'HISTORY_OR_COMMUNITY'
          WHEN c.conrelid::regclass::text ~* '(billing|coin|commerce|wallet|finance|tax|premium|reward|payment)'
            THEN 'FINANCIAL_OR_ENTITLEMENT'
          WHEN c.conrelid::regclass::text ~* '(message|chat|conversation|email|contact|notification|presence|device|referral)'
            THEN 'COMMUNICATION_OR_IDENTITY'
          ELSE 'OTHER_OR_GAMEPLAY'
        END AS suggested_review_area
 FROM pg_constraint c
 WHERE c.contype='f'
   AND c.confrelid IN ('auth.users'::regclass,'public.players'::regclass)
)
SELECT suggested_review_area,parent_table,dependent_table,conname,
       CASE confdeltype WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL'
            WHEN 'r' THEN 'RESTRICT' WHEN 'a' THEN 'NO ACTION'
            WHEN 'd' THEN 'SET DEFAULT' ELSE 'UNKNOWN' END AS on_delete,
       'REVIEW_REQUIRED'::text AS deletion_policy
FROM relationships
ORDER BY suggested_review_area,dependent_table,parent_table,conname;

-- Baseline drift is a hard stop for future deletion automation.
WITH rel AS (
 SELECT confdeltype
 FROM pg_constraint
 WHERE contype='f'
   AND confrelid IN ('auth.users'::regclass,'public.players'::regclass)
)
SELECT count(*) AS current_direct_relationships,188 AS reviewed_baseline,
       count(*)=188 AS direct_fk_baseline_matches,
       count(*) FILTER(WHERE confdeltype='c') AS cascades,
       count(*) FILTER(WHERE confdeltype='n') AS set_nulls,
       count(*) FILTER(WHERE confdeltype='r') AS restricts,
       count(*) FILTER(WHERE confdeltype='a') AS no_actions,
       'NOT_READY_FOR_HARD_DELETE'::text AS deletion_readiness
FROM rel;

-- Informational: check any direct constraints targeting historic match
-- and doubles-team references, without reading player or match data.
SELECT c.conname, c.conrelid::regclass::text AS table_name,
       c.confrelid::regclass::text AS references_table,
       pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
WHERE c.contype='f' AND c.conrelid IN (
 'public.tournament_matches'::regclass,
 'public.tournament_doubles_teams'::regclass,
 'public.tournament_doubles_matches'::regclass)
ORDER BY c.conrelid::regclass::text,c.conname;


-- Recursive reachability inventory: captures indirect effects when deleting
-- auth.users -> players -> tournament/team/finance/other dependent tables.
-- Multiple paths may reach the same table; path count is not row count.
-- Traversal is cycle-safe (path tracks OIDs), limited to 12 edges and reports
-- whether the limit was hit. New schema edges require renewed review.
WITH RECURSIVE dependency_paths AS (
  SELECT c.conrelid AS child_oid,c.confrelid AS parent_oid,
         ARRAY[c.confrelid,c.conrelid]::oid[] AS visited,1 AS depth,
         ARRAY[c.confdeltype]::"char"[] AS delete_behaviors
  FROM pg_constraint c
  WHERE c.contype='f'
    AND c.confrelid IN ('auth.users'::regclass,'public.players'::regclass)
  UNION ALL
  SELECT c.conrelid,c.confrelid,p.visited||c.conrelid,p.depth+1,
         p.delete_behaviors||c.confdeltype
  FROM dependency_paths p
  JOIN pg_constraint c ON c.contype='f' AND c.confrelid=p.child_oid
  WHERE p.depth<12 AND NOT c.conrelid=ANY(p.visited)
)
SELECT count(*) AS reachable_constraint_paths,
       count(DISTINCT child_oid) AS reachable_dependent_tables,
       max(depth) AS longest_chain,
       count(*) FILTER(WHERE depth>1) AS indirect_paths,
       count(*) FILTER(WHERE depth=12) AS traversal_depth_cap_hits,
       bool_or('c'::"char"=ANY(delete_behaviors)) AS includes_cascade,
       'REVIEW_REQUIRED__NO_HARD_DELETE'::text AS decision
FROM dependency_paths;

-- Which *additional* tables are visible only when considering chains?
-- No personal game records are read.
WITH RECURSIVE dependency_paths AS (
 SELECT c.conrelid AS child_oid,ARRAY[c.confrelid,c.conrelid]::oid[] AS visited,1 AS depth
 FROM pg_constraint c WHERE c.contype='f'
 AND c.confrelid IN ('auth.users'::regclass,'public.players'::regclass)
 UNION ALL
 SELECT c.conrelid,p.visited||c.conrelid,p.depth+1
 FROM dependency_paths p JOIN pg_constraint c
 ON c.contype='f' AND c.confrelid=p.child_oid
 WHERE p.depth<12 AND NOT c.conrelid=ANY(p.visited)
)
SELECT child_oid::regclass::text AS indirectly_reachable_table,
       min(depth) AS shortest_dependency_chain
FROM dependency_paths
WHERE child_oid NOT IN (
 SELECT conrelid FROM pg_constraint
 WHERE contype='f' AND confrelid IN ('auth.users'::regclass,'public.players'::regclass)
)
GROUP BY child_oid ORDER BY child_oid::regclass::text;


ROLLBACK;
