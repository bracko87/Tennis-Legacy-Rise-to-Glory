-- Remove direct anonymous/player calls to internal health eligibility
-- and doubles scheduling helpers. Regular game processors are SECURITY DEFINER
-- owned by postgres; their internal calls keep working.
DO $lock$
DECLARE v_name text;f record;
BEGIN
 FOREACH v_name IN ARRAY ARRAY[
    'player_tournament_entry_health_eligible_v1',
    'doubles_match_game_second_v1'
 ]::text[]
 LOOP
   IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND p.proname=v_name AND p.prosecdef
         AND p.proowner='postgres'::regrole)<>1 THEN
     RAISE EXCEPTION 'Unexpected internal helper definition: %',v_name;
   END IF;
   IF EXISTS(
       SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND NOT p.prosecdef AND p.proname<>v_name
         AND p.prosrc ILIKE '%'||v_name||'%'
   ) THEN RAISE EXCEPTION 'Invoker function depends on %',v_name; END IF;
   FOR f IN SELECT p.oid::regprocedure sig FROM pg_proc p
       JOIN pg_namespace n ON n.oid=p.pronamespace
       WHERE n.nspname='public' AND p.proname=v_name
   LOOP
     EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.sig);
     EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.sig);
   END LOOP;
 END LOOP;
END $lock$;
