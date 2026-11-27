-- CI only; all fixtures rolled back. Controller evidence, not authoritative schedule writes.
BEGIN;
INSERT INTO ace_cutover_review.matches(id,competition,scope,eligible,status,legacy_simulation,started,player1,player2,owner,revision) VALUES
 ('ops-followup-source','ops-followup-review','singles',true,'completed','none',true,'ops-a','ops-b','ace',3),
 ('ops-followup-target','ops-followup-review','singles',true,'scheduled','none',false,'ops-a','ops-c',NULL,0);
INSERT INTO ace_cutover_review.effects VALUES('ops-followup-source','ace','ops-a','{"receipt":"synthetic"}');
DO $$ DECLARE b bigint; a bigint; BEGIN
 SELECT count(*) INTO b FROM ace_review.finalized_prizes;
 IF ace_cutover_review.stage_followup('ops-followup-source','ops-followup-target',0)<>'staged_review' THEN RAISE EXCEPTION 'stage failed'; END IF;
 IF ace_cutover_review.stage_followup('ops-followup-source','ops-followup-target',0)<>'already_staged' THEN RAISE EXCEPTION 'duplicate stage'; END IF;
 IF ace_cutover_review.note_followup_attempt('ops-followup-source','ops-followup-target','1','error')<>'recorded_review' THEN RAISE EXCEPTION 'error receipt'; END IF;
 IF ace_cutover_review.note_followup_attempt('ops-followup-source','ops-followup-target','1','error')<>'already_recorded' THEN RAISE EXCEPTION 'duplicate attempt'; END IF;
 BEGIN
 PERFORM ace_cutover_review.note_followup_attempt('ops-followup-source','ops-followup-target','1','ready');
 RAISE EXCEPTION 'unexpected acceptance';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'conflicting attempt' THEN RAISE; END IF; END;
 IF ace_cutover_review.note_followup_attempt('ops-followup-source','ops-followup-target','2','rescheduled')<>'recorded_review' THEN RAISE EXCEPTION 'retry failed'; END IF;
 IF ace_cutover_review.note_followup_attempt('ops-followup-source','ops-followup-target','3','ready')<>'already_resolved_review' THEN RAISE EXCEPTION 'resolved retry'; END IF;
 SELECT count(*) INTO a FROM ace_review.finalized_prizes;
 IF a<>b OR (SELECT count(*) FROM ace_cutover_review.followup_attempts WHERE source_id='ops-followup-source')<>2 OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.effects WHERE match_id='ops-followup-source' AND receipt='{"receipt":"synthetic"}') THEN RAISE EXCEPTION 'unexpected effects'; END IF;
 IF has_function_privilege('ace_cutover_legacy','ace_cutover_review.stage_followup(text,text,bigint)','EXECUTE') THEN RAISE EXCEPTION 'legacy access'; END IF;
 RAISE NOTICE 'PASS isolated persisted followup evidence, retries, receipt conflict and unchanged prize inventory';
END $$;
ROLLBACK;
