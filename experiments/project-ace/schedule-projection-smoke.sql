BEGIN;
DO $$ BEGIN
 IF has_function_privilege('ace_cutover_legacy','ace_cutover_review.apply_followup_delay(text,text,text,bigint,integer)','EXECUTE') THEN RAISE EXCEPTION 'legacy access'; END IF;
 IF ace_cutover_review.effective_schedule('missing-ops-slot') IS NOT NULL THEN RAISE EXCEPTION 'invented slot'; END IF;
 IF position('effective_schedule' in pg_get_functiondef('ace_cutover_review.start_source(text,bigint,bigint,bigint)'::regprocedure))=0 THEN RAISE EXCEPTION 'start integration missing'; END IF;
 IF position('effective_schedule' in pg_get_functiondef('ace_cutover_review.reserve_source_resources()'::regprocedure))=0 THEN RAISE EXCEPTION 'court integration missing'; END IF;
END $$;
ROLLBACK;
