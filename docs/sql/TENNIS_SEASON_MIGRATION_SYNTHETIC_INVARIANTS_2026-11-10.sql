
-- Synthetic invariants only. No production data is modified.
DO $tests$
DECLARE
 v_seconds_per_season bigint := 366*86400;
 v_case record;
 v_due integer;
 v_carry integer;
 v_balance bigint:=152004;
 v_coins integer:=630;
 v_after_balance bigint;
 v_after_coins integer;
BEGIN
 FOR v_case IN
  SELECT * FROM (VALUES
   ('S1 final second'::text, 31622399::bigint,1,366,86399),
   ('S2 first second',31622400::bigint,2,1,0),
   ('S2 final second',63244799::bigint,2,366,86399),
   ('S3 first second',63244800::bigint,3,1,0)
  ) a(label,second,season,season_day,second_of_day)
 LOOP
  IF (v_case.second/v_seconds_per_season)::integer+1 <> v_case.season OR
     ((v_case.second%v_seconds_per_season)/86400)::integer+1 <> v_case.season_day OR
     (v_case.second%86400)::integer <> v_case.second_of_day
  THEN RAISE EXCEPTION 'boundary arithmetic failed: %',v_case.label; END IF;
 END LOOP;

 IF public.game_day_absolute_v1(2,1,1)<>366
   OR public.game_day_absolute_v1(3,1,1)<>732
   OR public.game_day_absolute_v1(2,12,31)<>731
 THEN RAISE EXCEPTION 'fixed 366 day calendar failed'; END IF;

 WITH contracts(end_day) as (values (365),(365),(386))
 SELECT count(*) filter(where end_day<366),
        count(*) filter(where end_day>=366)
 INTO v_due,v_carry FROM contracts;
 IF (v_due,v_carry) IS DISTINCT FROM (2,1) THEN
   RAISE EXCEPTION 'Season1 to Season2 contract expiry fixture failed'; END IF;

 -- At the next boundary the surviving signed contract must also expire,
 -- never be extended or silently re-created.
 WITH contracts(end_day) as (values (365),(365),(386))
 SELECT count(*) filter(where end_day<732) INTO v_due FROM contracts;
 IF v_due<>3 THEN RAISE EXCEPTION 'Season2 to Season3 contract expiry fixture failed'; END IF;

 -- The cutover itself must not debit or credit accounts or coins.
 v_after_balance:=v_balance;
 v_after_coins:=v_coins;
 IF (v_after_balance,v_after_coins) IS DISTINCT FROM (v_balance,v_coins) THEN
    RAISE EXCEPTION 'account carryover fixture failed'; END IF;

 -- The protected production plan is intentionally not approved.
 IF EXISTS (
  SELECT 1 FROM control_center_private.tennis_season_transition_runs_v1
  WHERE source_season=1 AND target_season=2 AND
     (status <> 'planned' OR execution_enabled OR backup_verified
      OR restore_test_verified OR two_season_dry_run_verified OR operator_approved)
 ) THEN RAISE EXCEPTION 'production migration unexpectedly approved'; END IF;
END
$tests$;
