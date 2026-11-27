-- Isolated persistence experiment, deliberately separate from release migrations.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'disposable review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.followup_jobs(
 source_id text NOT NULL REFERENCES ace_cutover_review.effects(match_id),
 target_id text NOT NULL REFERENCES ace_cutover_review.matches(id),
 source_receipt jsonb NOT NULL, target_revision bigint NOT NULL,
 PRIMARY KEY(source_id,target_id), CHECK(source_id<>target_id)
);
CREATE TABLE ace_cutover_review.followup_attempts(
 source_id text NOT NULL,target_id text NOT NULL,attempt_key text NOT NULL CHECK(length(attempt_key)>0),
 outcome text NOT NULL CHECK(outcome IN ('error','blocked','waiting_live_conflict','paused','ready','rescheduled','no_longer_scheduled')),
 PRIMARY KEY(source_id,target_id,attempt_key),
 FOREIGN KEY(source_id,target_id) REFERENCES ace_cutover_review.followup_jobs
);
CREATE FUNCTION ace_cutover_review.stage_followup(p_source text,p_target text,p_revision bigint) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE e ace_cutover_review.effects%ROWTYPE; s ace_cutover_review.matches%ROWTYPE; t ace_cutover_review.matches%ROWTYPE; j ace_cutover_review.followup_jobs%ROWTYPE;
BEGIN
 SELECT * INTO STRICT e FROM ace_cutover_review.effects WHERE match_id=p_source;
 SELECT * INTO STRICT s FROM ace_cutover_review.matches WHERE id=p_source;
 SELECT * INTO STRICT t FROM ace_cutover_review.matches WHERE id=p_target FOR UPDATE;
 SELECT * INTO j FROM ace_cutover_review.followup_jobs WHERE source_id=p_source AND target_id=p_target;
 IF FOUND THEN IF j.source_receipt IS DISTINCT FROM e.receipt OR j.target_revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'conflicting followup evidence'; END IF; RETURN 'already_staged'; END IF;
 IF s.status<>'completed' OR s.owner IS DISTINCT FROM 'ace' OR e.engine<>'ace' OR t.status<>'scheduled' OR t.started OR t.revision IS DISTINCT FROM p_revision OR NOT(t.player1 IN(s.player1,s.player2) OR t.player2 IN(s.player1,s.player2)) THEN RAISE EXCEPTION 'invalid followup identity'; END IF;
 INSERT INTO ace_cutover_review.followup_jobs VALUES(p_source,p_target,e.receipt,p_revision);
 RETURN 'staged_review';
END $$;
CREATE FUNCTION ace_cutover_review.note_followup_attempt(p_source text,p_target text,p_key text,p_outcome text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE j ace_cutover_review.followup_jobs%ROWTYPE; prior text;
BEGIN
 SELECT * INTO STRICT j FROM ace_cutover_review.followup_jobs WHERE source_id=p_source AND target_id=p_target FOR UPDATE;
 SELECT outcome INTO prior FROM ace_cutover_review.followup_attempts WHERE source_id=p_source AND target_id=p_target AND attempt_key=p_key;
 IF FOUND THEN IF prior IS DISTINCT FROM p_outcome THEN RAISE EXCEPTION 'conflicting attempt'; END IF; RETURN 'already_recorded'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.followup_attempts WHERE source_id=p_source AND target_id=p_target AND outcome IN ('ready','rescheduled','no_longer_scheduled')) THEN RETURN 'already_resolved_review'; END IF;
 INSERT INTO ace_cutover_review.followup_attempts VALUES(p_source,p_target,p_key,p_outcome);
 RETURN 'recorded_review';
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.stage_followup(text,text,bigint),ace_cutover_review.note_followup_attempt(text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.stage_followup(text,text,bigint),ace_cutover_review.note_followup_attempt(text,text,text,text) TO ace_review_worker;
GRANT SELECT ON ace_cutover_review.followup_jobs,ace_cutover_review.followup_attempts TO ace_review_worker;
COMMIT;
