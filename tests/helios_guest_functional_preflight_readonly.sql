-- Project Helios H01/H02/H08: non-destructive preflight for staging preparation.
-- Reads only schema, server-side registration switch and function definitions.
-- Does NOT create anonymous users or modify Auth, trials, accounts or matches.
-- It should report BLOCKED while the production Guest Mode switch is OFF.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SET LOCAL statement_timeout='30s';

SELECT CASE WHEN coalesce(
 (SELECT guest_test_enabled FROM public.registration_control WHERE singleton_id=true),false)
 THEN 'PUBLIC_GUEST_GATE_ENABLED__STOP_AND_REVIEW'
 ELSE 'PUBLIC_GUEST_GATE_DISABLED__SAFE'
 END AS public_guest_gate;

WITH funcs AS (
 SELECT p.proname,pg_get_functiondef(p.oid) AS definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public'
   AND p.proname IN (
     'get_public_tennis_guest_test_status_v1',
     'enroll_my_tennis_guest_trial_v1',
     'get_my_tennis_guest_conversion_status_v1'
   )
)
SELECT count(*) AS required_functions_found,
       count(*)=3 AS required_functions_present,
       bool_and(definition IS NOT NULL) AS source_available
FROM funcs;

-- No private auth user records are selected. Function descriptions can
-- change with migrations; compare in code review before enabling rollout.
SELECT
 EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='enroll_my_tennis_guest_trial_v1'
   AND pg_get_functiondef(p.oid) LIKE '%get_public_tennis_guest_test_status_v1%'
   AND pg_get_functiondef(p.oid) LIKE '%Anonymous guest identity required%'
   AND pg_get_functiondef(p.oid) LIKE '%interval ''14 days''%'
   AND pg_get_functiondef(p.oid) LIKE '%interval ''7 days''%')
 AS enrollment_guard_code_present;

ROLLBACK;
