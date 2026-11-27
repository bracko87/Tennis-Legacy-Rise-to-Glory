-- Disposable CI fault injection only. All changes roll back.
BEGIN;
DO $test$
DECLARE id text:='ops-projection-source'; r jsonb; i int; due timestamptz; before_result jsonb;
BEGIN
 IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'disposable review required'; END IF;
 SELECT receipt INTO STRICT before_result FROM ace_cutover_review.effects WHERE match_id=id;
 -- This synthetic completed non-source match deliberately lacks source evidence.
 INSERT INTO ace_cutover_review.followup_outbox(source_id) VALUES(id);
 FOR i IN 1..5 LOOP
  r:=ace_cutover_review.process_followup_outbox(id);
  IF (r->>'attempts')::int<>i THEN RAISE EXCEPTION 'attempt mismatch'; END IF;
  IF i<5 THEN
   IF r->>'state'<>'pending' THEN RAISE EXCEPTION 'premature escalation'; END IF;
   SELECT next_attempt_at INTO due FROM ace_cutover_review.followup_outbox WHERE source_id=id;
   IF due<=clock_timestamp() THEN RAISE EXCEPTION 'missing retry backoff'; END IF;
   IF ace_cutover_review.process_followup_outbox(id) IS DISTINCT FROM r THEN RAISE EXCEPTION 'early retry changed receipt'; END IF;
   IF (ace_cutover_review.drain_followup_outbox(20)->>'processed')::int<>0 THEN RAISE EXCEPTION 'early drain'; END IF;
   -- Advance eligibility without sleeping or touching the game clock.
   UPDATE ace_cutover_review.followup_outbox SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE source_id=id;
  ELSE
   IF r->>'state'<>'review_required' OR r->'report'->'retry_exhausted' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'missing exhaustion evidence'; END IF;
  END IF;
 END LOOP;
 IF ace_cutover_review.process_followup_outbox(id) IS DISTINCT FROM r THEN RAISE EXCEPTION 'terminal retry changed receipt'; END IF;
 IF (SELECT receipt FROM ace_cutover_review.effects WHERE match_id=id) IS DISTINCT FROM before_result THEN RAISE EXCEPTION 'completion modified'; END IF;
 RAISE NOTICE 'PASS retry backoff, early drain exclusion, five-attempt escalation and immutable result';
END $test$;
ROLLBACK;
