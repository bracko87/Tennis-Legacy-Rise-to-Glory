-- Disposable imported medical completion and no-play career acknowledgment.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.source_medical_resolution (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_admissions(match_id),
 match_revision bigint NOT NULL,
 readiness_revision bigint NOT NULL,
 clock_revision bigint NOT NULL,
 receipt jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_no_play_career (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_admissions(match_id),
 terminal_revision bigint NOT NULL,
 report jsonb NOT NULL
);
GRANT SELECT ON ace_cutover_review.source_medical_resolution,ace_cutover_review.source_no_play_career TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.finish_source_medical(p_id text,p_match_rev bigint,p_ready_rev bigint,p_clock_rev bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; a ace_cutover_review.source_admissions%ROWTYPE; c ace_cutover_review.source_clock%ROWTYPE; rd ace_cutover_review.source_readiness%ROWTYPE; s ace_cutover_review.source_slots%ROWTYPE; h ace_cutover_review.medical_snapshots%ROWTYPE; prior ace_cutover_review.source_medical_resolution%ROWTYPE; due bigint; season int; winner text; v jsonb; blocked jsonb; outcome text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT a FROM ace_cutover_review.source_admissions WHERE match_id=p_id;
 SELECT * INTO prior FROM ace_cutover_review.source_medical_resolution WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(prior.match_revision,prior.readiness_revision,prior.clock_revision) IS DISTINCT FROM ROW(p_match_rev,p_ready_rev,p_clock_rev) THEN RAISE EXCEPTION 'conflicting medical replay'; END IF;
  RETURN jsonb_build_object('status','already_completed','receipt',prior.receipt);
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.revision IS DISTINCT FROM p_match_rev OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'invalid source medical state'; END IF;
 SELECT * INTO STRICT c FROM ace_cutover_review.source_clock WHERE competition_id=m.competition FOR SHARE;
 SELECT * INTO STRICT rd FROM ace_cutover_review.source_readiness WHERE match_id=p_id;
 IF c.revision IS DISTINCT FROM p_clock_rev OR rd.revision IS DISTINCT FROM p_ready_rev OR rd.clock_revision IS DISTINCT FROM c.revision OR rd.match_revision IS DISTINCT FROM m.revision OR rd.source_revision IS DISTINCT FROM a.source_revision THEN RAISE EXCEPTION 'stale medical readiness'; END IF;
 IF c.paused OR clock_timestamp()-c.captured_at>interval '60 seconds' THEN RETURN jsonb_build_object('status','clock_not_ready'); END IF;
 SELECT * INTO STRICT s FROM ace_cutover_review.source_slots WHERE match_id=p_id;
 SELECT (contract->>'season_number')::int INTO STRICT season FROM ace_cutover_review.source_contracts WHERE competition_id=m.competition;
 due:=((season-1)::bigint*366+2+((s.slot->>'scheduled_season_week')::int-1)*7+(s.slot->>'scheduled_day')::int-1)*86400+(s.slot->>'scheduled_start_minute')::int*60;
 IF c.game_second<due THEN RETURN jsonb_build_object('status','not_due'); END IF;
 IF rd.blocked1 IS NULL AND rd.blocked2 IS NULL THEN RETURN jsonb_build_object('status','both_medically_eligible'); END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL) THEN RETURN jsonb_build_object('status','handoff_pending'); END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_career_opt_in WHERE competition_id=m.competition) THEN
  PERFORM 1 FROM ace_cutover_review.source_career_players WHERE player_id IN(m.player1,m.player2) ORDER BY player_id COLLATE "C" FOR UPDATE;
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_players WHERE player_id=m.player1 AND state->'injuries'=rd.evidence->'health1') OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_players WHERE player_id=m.player2 AND state->'injuries'=rd.evidence->'health2') THEN RAISE EXCEPTION 'career health snapshot mismatch'; END IF;
 END IF;
 INSERT INTO ace_cutover_review.medical_snapshots(match_id,absolute_day,player1_records,player2_records,return1,return2) VALUES(p_id,(c.game_second/86400)::int,rd.evidence->'health1',rd.evidence->'health2',rd.blocked1,rd.blocked2) RETURNING * INTO h;
 winner:=ace_cutover_review.medical_winner(m,h);
 blocked:=CASE WHEN h.return1 IS NOT NULL AND h.return2 IS NOT NULL THEN jsonb_build_array(m.player1,m.player2) WHEN h.return1 IS NOT NULL THEN jsonb_build_array(m.player1) ELSE jsonb_build_array(m.player2) END;
 v:=jsonb_build_object('match_id',p_id,'competition_id',m.competition,'player1_id',m.player1,'player2_id',m.player2,'winner_id',winner,'status','completed','completion_reason','health_walkover','score','W/O','actual_duration_minutes',NULL,'engine_version',NULL,'sets','[]'::jsonb,'stats','[]'::jsonb,'medical_absolute_day',h.absolute_day,'medically_unavailable_player_ids',blocked,'started_at',c.captured_at,'completed_at',c.captured_at);
 outcome:=ace_cutover_review.finish_medical(p_id,p_match_rev,v);
 IF outcome<>'completed' THEN RAISE EXCEPTION 'atomic medical completion failed'; END IF;
 INSERT INTO ace_cutover_review.source_medical_resolution VALUES(p_id,p_match_rev,p_ready_rev,p_clock_rev,v);
 RETURN jsonb_build_object('status','completed','receipt',v);
END $$;
-- Explicit controller acknowledgment for a verified, synchronized zero-play completed result.
CREATE FUNCTION ace_cutover_review.ack_source_no_play(p_id text,p_revision bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; ef ace_cutover_review.effects%ROWTYPE; prior ace_cutover_review.source_no_play_career%ROWTYPE; report jsonb; reason text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 SELECT * INTO prior FROM ace_cutover_review.source_no_play_career WHERE match_id=p_id;
 IF FOUND THEN IF prior.terminal_revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'conflicting no-play replay'; END IF; RETURN prior.report; END IF;
 IF m.status<>'completed' OR m.started OR m.revision IS DISTINCT FROM p_revision OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_opt_in WHERE competition_id=m.competition) OR EXISTS(SELECT 1 FROM ace_cutover_review.source_starts WHERE match_id=p_id) THEN RAISE EXCEPTION 'not an opted-in zero-play match'; END IF;
 SELECT * INTO STRICT ef FROM ace_cutover_review.effects WHERE match_id=p_id;
 reason:=ef.receipt->>'completion_reason';
 IF ef.engine IS DISTINCT FROM m.owner OR ef.receipt->'actual_duration_minutes' IS DISTINCT FROM 'null'::jsonb OR ef.receipt->'sets' IS DISTINCT FROM '[]'::jsonb OR ef.receipt->'stats' IS DISTINCT FROM '[]'::jsonb OR (
 (reason='health_walkover' AND EXISTS(SELECT 1 FROM ace_cutover_review.source_medical_resolution h WHERE h.match_id=p_id AND h.receipt=ef.receipt))
 OR (reason='travel_no_show' AND EXISTS(SELECT 1 FROM ace_cutover_review.travel_evidence t WHERE t.match_id=p_id AND t.receipt=ef.receipt))
 OR (reason='health_surrender' AND EXISTS(SELECT 1 FROM ace_cutover_review.surrender_evidence t WHERE t.match_id=p_id AND t.receipt=ef.receipt))
 ) IS DISTINCT FROM TRUE THEN RAISE EXCEPTION 'unverified zero-play receipt'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_result_projection q WHERE q.match_id=p_id AND q.match_revision=p_revision AND q.status='completed' AND q.receipt=ef.receipt AND q.winner_id=ef.winner AND q.owner=m.owner) THEN RAISE EXCEPTION 'result synchronization required'; END IF;
 report:=jsonb_build_object('schema','ace-source-no-play-v1','review_only',true,'production_ready',false,'match_id',p_id,'terminal_revision',p_revision,'status','no_play_no_effects','reason',reason,'players','[]'::jsonb);
 INSERT INTO ace_cutover_review.source_no_play_career VALUES(p_id,p_revision,report);
 RETURN report;
END $$;
-- A locked full imported field cannot be cancelled based on contradictory minimum-field evidence.
CREATE FUNCTION ace_cutover_review.guard_imported_minimum_cancel() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_contracts WHERE competition_id=NEW.competition_id) THEN RAISE EXCEPTION 'locked imported field contradicts minimum-field cancellation'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_imported_minimum_cancel BEFORE INSERT ON ace_cutover_review.cancellations FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_imported_minimum_cancel();
REVOKE ALL ON FUNCTION ace_cutover_review.finish_source_medical(text,bigint,bigint,bigint),ace_cutover_review.ack_source_no_play(text,bigint),ace_cutover_review.guard_imported_minimum_cancel() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.finish_source_medical(text,bigint,bigint,bigint) TO ace_cutover_ace;
GRANT EXECUTE ON FUNCTION ace_cutover_review.ack_source_no_play(text,bigint) TO ace_review_worker;
COMMIT;
