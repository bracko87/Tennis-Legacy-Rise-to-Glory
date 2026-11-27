-- Disposable source-only winnerless feeder continuation. No placeholder player IDs.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
ALTER TABLE ace_cutover_review.matches ALTER COLUMN player1 DROP NOT NULL, ALTER COLUMN player2 DROP NOT NULL;
ALTER TABLE ace_cutover_review.matches ADD CONSTRAINT source_nullable_terminal_slots CHECK (
 (player1 IS NOT NULL AND player2 IS NOT NULL) OR
 (owner IS NOT DISTINCT FROM 'ace' AND NOT started AND legacy_simulation='none' AND
 ((status='bye' AND ((player1 IS NULL)<>(player2 IS NULL))) OR (status='cancelled' AND player1 IS NULL AND player2 IS NULL)))
);
CREATE TABLE ace_cutover_review.source_void_receipts (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_slots(match_id),
 source_revision bigint NOT NULL,
 receipt jsonb NOT NULL
);
GRANT SELECT ON ace_cutover_review.source_void_receipts TO ace_review_worker;
CREATE OR REPLACE FUNCTION ace_cutover_review.guard_source_seed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF NEW.player1 IS NULL OR NEW.player2 IS NULL THEN
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.source_admissions a ON a.match_id=s.match_id JOIN ace_cutover_review.source_void_receipts v ON v.match_id=s.match_id
    WHERE s.match_id=NEW.id AND s.competition_id=NEW.competition AND a.owner='ace' AND v.source_revision=a.source_revision AND v.receipt->>'player1_id' IS NOT DISTINCT FROM NEW.player1 AND v.receipt->>'player2_id' IS NOT DISTINCT FROM NEW.player2 AND v.receipt->>'status'=NEW.status AND NEW.owner='ace' AND NEW.revision=2 AND NOT NEW.started AND NEW.legacy_simulation='none' AND NEW.scope='singles' AND NEW.eligible) THEN RAISE EXCEPTION 'dedicated source void required'; END IF;
  RETURN NEW;
 END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_contracts WHERE competition_id=NEW.competition) OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots WHERE match_id=NEW.id) THEN
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.source_admissions a ON a.match_id=s.match_id WHERE s.match_id=NEW.id AND s.competition_id=NEW.competition AND a.observation->>'player1_id'=NEW.player1 AND a.observation->>'player2_id'=NEW.player2 AND NEW.status='scheduled' AND NOT NEW.started AND NEW.legacy_simulation='none' AND NEW.scope='singles' AND NEW.eligible AND NEW.owner IS NULL) THEN RAISE EXCEPTION 'dedicated source admission required'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE FUNCTION ace_cutover_review.resolve_source_void(p_id text,p_expected bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE s ace_cutover_review.source_slots%ROWTYPE; o ace_cutover_review.source_observations%ROWTYPE; p ace_cutover_review.policy%ROWTYPE; prior ace_cutover_review.source_void_receipts%ROWTYPE; a jsonb; b jsonb; w1 text; w2 text; v jsonb; st text;
BEGIN
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT p FROM ace_cutover_review.policy WHERE singleton FOR SHARE;
 SELECT * INTO STRICT s FROM ace_cutover_review.source_slots WHERE match_id=p_id;
 PERFORM pg_advisory_xact_lock(hashtextextended(s.competition_id,91023));
 SELECT * INTO STRICT o FROM ace_cutover_review.source_observations WHERE match_id=p_id FOR UPDATE;
 SELECT * INTO prior FROM ace_cutover_review.source_void_receipts WHERE match_id=p_id;
 IF FOUND THEN
  IF prior.source_revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'conflicting void replay'; END IF;
  RETURN jsonb_build_object('status','already_resolved','receipt',prior.receipt);
 END IF;
 IF NOT p.enabled OR NOT (s.competition_id=ANY(p.competitions)) THEN RETURN jsonb_build_object('status','routing_disabled'); END IF;
 IF o.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'stale source observation'; END IF;
 IF s.round_number<=1 OR s.feeder1 IS NULL OR s.feeder2 IS NULL THEN RAISE EXCEPTION 'two source feeders required'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=p_id) OR EXISTS(SELECT 1 FROM ace_cutover_review.matches WHERE id=p_id) OR EXISTS(SELECT 1 FROM ace_cutover_review.cancellations WHERE competition_id=s.competition_id) THEN RAISE EXCEPTION 'source slot already occupied or cancelled'; END IF;
 IF o.payload->>'status' IS DISTINCT FROM 'scheduled' OR o.payload->>'simulation' IS DISTINCT FROM 'none' OR o.payload->'started' IS DISTINCT FROM 'false'::jsonb OR o.payload->>'winner_id' IS NOT NULL THEN RAISE EXCEPTION 'existing source state'; END IF;
 -- Both feeders must be Ace-owned, terminal, and already synchronized.
 IF (SELECT count(*) FROM ace_cutover_review.source_admissions sa JOIN ace_cutover_review.matches m ON m.id=sa.match_id JOIN ace_cutover_review.source_result_projection q ON q.match_id=m.id AND q.match_revision=m.revision AND q.status=m.status AND q.owner=m.owner WHERE m.id IN(s.feeder1,s.feeder2) AND m.competition=s.competition_id AND sa.owner='ace' AND m.owner='ace' AND m.status IN ('completed','walkover','bye','cancelled'))<>2 THEN RETURN jsonb_build_object('status','feeder_sync_pending'); END IF;
 a:=ace_cutover_review.terminal_feeder(s.feeder1,s.competition_id);b:=ace_cutover_review.terminal_feeder(s.feeder2,s.competition_id);
 w1:=a->>'winner_id';w2:=b->>'winner_id';
 IF w1 IS NOT NULL AND w2 IS NOT NULL THEN RETURN jsonb_build_object('status','normal_match_required'); END IF;
 IF o.payload->>'player1_id' IS DISTINCT FROM w1 OR o.payload->>'player2_id' IS DISTINCT FROM w2 THEN RAISE EXCEPTION 'source void slot mismatch'; END IF;
 st:=CASE WHEN coalesce(w1,w2) IS NULL THEN 'cancelled' ELSE 'bye' END;
 v:=jsonb_build_object('match_id',p_id,'competition_id',s.competition_id,'player1_id',w1,'player2_id',w2,'winner_id',coalesce(w1,w2),'status',st,'reason','winnerless_feeder','started_at',NULL,'sets','[]'::jsonb,'stats','[]'::jsonb,'actual_duration_minutes',NULL);
 INSERT INTO ace_cutover_review.source_admissions VALUES(p_id,o.revision,o.payload,'ace');
 INSERT INTO ace_cutover_review.source_void_receipts VALUES(p_id,o.revision,v);
 INSERT INTO ace_cutover_review.matches(id,competition,scope,eligible,status,legacy_simulation,started,player1,player2,owner,revision) VALUES(p_id,s.competition_id,'singles',true,st,'none',false,w1,w2,'ace',2);
 INSERT INTO ace_cutover_review.feeder_contract VALUES(p_id,s.competition_id,s.feeder1,s.feeder2);
 INSERT INTO ace_cutover_review.bracket_voids VALUES(p_id,v);
 INSERT INTO ace_cutover_review.source_runtime_events VALUES(p_id,2,st,'ace',v);
 RETURN jsonb_build_object('status','resolved','receipt',v);
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.resolve_source_void(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.resolve_source_void(text,bigint) TO ace_cutover_ace;
COMMIT;
