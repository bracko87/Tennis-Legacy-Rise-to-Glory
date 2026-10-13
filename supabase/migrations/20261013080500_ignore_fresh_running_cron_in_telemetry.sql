-- The live system-health watchdog writes "running" records at the start
-- of scheduled jobs, then later synchronizes their successful completion.
-- Hourly telemetry was counting all such transient records as failures,
-- causing a persistent fake warning on an otherwise healthy tennis game.
-- Preserve warnings when a job has genuinely been running for >15 minutes.
DO $fix$
DECLARE
 v_original text;
 v_revised text;
BEGIN
 SELECT pg_get_functiondef('control_center_private.build_hourly_telemetry_payload()'::regprocedure)
 INTO v_original;
 IF position('select distinct on (process_key) process_key, status' in v_original)=0
    OR position('where lower(coalesce(status,'''')) not in' in v_original)=0 THEN
   RAISE EXCEPTION 'Unexpected telemetry function definition, no change applied';
 END IF;
 v_revised := replace(
   v_original,
   'select distinct on (process_key) process_key, status',
   'select distinct on (process_key) process_key, status, started_at'
 );
 v_revised := replace(
   v_revised,
   'where lower(coalesce(status,'''')) not in (''ok'',''healthy'',''success'',''succeeded'',''completed'');',
   'where lower(coalesce(status,'''')) not in (''ok'',''healthy'',''success'',''succeeded'',''completed'')'
   || chr(10) ||
   '  and not (lower(coalesce(status,''''))=''running'' and started_at>=now()-interval ''15 minutes'');'
 );
 IF v_revised = v_original OR position('started_at>=now()-interval ''15 minutes''' in v_revised)=0 THEN
   RAISE EXCEPTION 'Telemetry predicate replacement failed';
 END IF;
 EXECUTE v_revised;
END
$fix$;