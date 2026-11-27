-- Disposable review only. No production migration.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.surrender_evidence (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 event_key text NOT NULL,
 player_id text NOT NULL,
 observed_at timestamptz NOT NULL,
 health_snapshot jsonb NOT NULL,
 receipt jsonb,
 FOREIGN KEY(match_id,event_key) REFERENCES ace_cutover_review.handoffs(match_id,event_key)
);
GRANT SELECT ON ace_cutover_review.surrender_evidence TO ace_review_worker;
-- The trusted external review role supplies a pre-verified requester and concern.
-- This is NOT a production authentication or health RPC.
CREATE FUNCTION ace_cutover_review.freeze_surrender(p_id text,p_key text,p_player text,p_at timestamptz,p_health jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; s ace_cutover_review.surrender_evidence%ROWTYPE; requested text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=m.competition) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 IF p_player IS NULL OR p_player NOT IN(m.player1,m.player2) OR p_at IS NULL OR NOT isfinite(p_at) OR jsonb_typeof(p_health) IS DISTINCT FROM 'object' OR p_health->'health_concern' IS DISTINCT FROM 'true'::jsonb OR p_health->>'player_id' IS DISTINCT FROM p_player OR p_health->'human_request_verified' IS DISTINCT FROM 'true'::jsonb THEN RAISE EXCEPTION 'verified participant health concern required'; END IF;
 SELECT * INTO s FROM ace_cutover_review.surrender_evidence WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(s.event_key,s.player_id,s.observed_at,s.health_snapshot) IS DISTINCT FROM ROW(p_key,p_player,p_at,p_health) THEN RAISE EXCEPTION 'conflicting surrender evidence'; END IF;
  RETURN 'already_frozen';
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'unprepared scheduled match required'; END IF;
 requested:=ace_cutover_review.request_handoff(p_id,p_key,'health_surrender');
 IF requested NOT IN ('queued','already_requested') THEN RAISE EXCEPTION 'surrender event not queued'; END IF;
 INSERT INTO ace_cutover_review.surrender_evidence(match_id,event_key,player_id,observed_at,health_snapshot) VALUES(p_id,p_key,p_player,p_at,p_health);
 RETURN 'frozen';
END $$;
CREATE FUNCTION ace_cutover_review.finish_surrender(p_id text,p_revision bigint,p_receipt jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; s ace_cutover_review.surrender_evidence%ROWTYPE; v_winner text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT s FROM ace_cutover_review.surrender_evidence WHERE match_id=p_id FOR UPDATE;
 IF s.receipt IS NOT NULL THEN
  IF s.receipt IS DISTINCT FROM p_receipt THEN RAISE EXCEPTION 'conflicting surrender receipt'; END IF;
  RETURN 'already_completed';
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.revision IS DISTINCT FROM p_revision OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'invalid surrender completion'; END IF;
 IF (SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL)<>1 OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND event_key=s.event_key AND reason='health_surrender' AND resolution IS NULL) THEN RAISE EXCEPTION 'conflicting external events'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.medical_snapshots h WHERE h.match_id=p_id AND (h.return1 IS NOT NULL OR h.return2 IS NOT NULL)) THEN RAISE EXCEPTION 'medical walkover and surrender conflict requires review'; END IF;
 v_winner:=CASE WHEN s.player_id=m.player1 THEN m.player2 ELSE m.player1 END;
 IF p_receipt->>'match_id' IS DISTINCT FROM p_id OR p_receipt->>'competition_id' IS DISTINCT FROM m.competition OR p_receipt->>'player1_id' IS DISTINCT FROM m.player1 OR p_receipt->>'player2_id' IS DISTINCT FROM m.player2 OR p_receipt->>'winner_id' IS DISTINCT FROM v_winner OR p_receipt->>'status' IS DISTINCT FROM 'completed' OR p_receipt->>'completion_reason' IS DISTINCT FROM 'health_surrender' OR p_receipt->>'score' IS DISTINCT FROM 'W/O' OR p_receipt->'actual_duration_minutes' IS DISTINCT FROM 'null'::jsonb OR p_receipt->'engine_version' IS DISTINCT FROM 'null'::jsonb OR p_receipt->'sets' IS DISTINCT FROM '[]'::jsonb OR p_receipt->'stats' IS DISTINCT FROM '[]'::jsonb OR p_receipt->>'surrendered_player_id' IS DISTINCT FROM s.player_id OR p_receipt->>'completed_at' IS NULL OR p_receipt->>'started_at' IS DISTINCT FROM p_receipt->>'completed_at' OR (p_receipt->>'completed_at')::timestamptz IS DISTINCT FROM s.observed_at THEN RAISE EXCEPTION 'surrender receipt mismatch'; END IF;
 UPDATE ace_cutover_review.surrender_evidence SET receipt=p_receipt WHERE match_id=p_id;
 UPDATE ace_cutover_review.handoffs SET resolution='walkover',winner=v_winner WHERE match_id=p_id AND event_key=s.event_key;
 INSERT INTO ace_cutover_review.effects VALUES(p_id,'ace',v_winner,p_receipt);
 UPDATE ace_cutover_review.matches SET status='completed',revision=revision+1 WHERE id=p_id;
 RETURN 'completed';
END $$;
CREATE FUNCTION ace_cutover_review.guard_surrender_effect() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF NEW.receipt->>'completion_reason'='health_surrender' AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.surrender_evidence s WHERE s.match_id=NEW.match_id AND s.receipt=NEW.receipt AND NEW.engine='ace') THEN RAISE EXCEPTION 'use verified surrender completion'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_surrender_effect BEFORE INSERT ON ace_cutover_review.effects FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_surrender_effect();
REVOKE ALL ON FUNCTION ace_cutover_review.freeze_surrender(text,text,text,timestamptz,jsonb),ace_cutover_review.finish_surrender(text,bigint,jsonb),ace_cutover_review.guard_surrender_effect() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.freeze_surrender(text,text,text,timestamptz,jsonb) TO ace_cutover_external;
GRANT EXECUTE ON FUNCTION ace_cutover_review.finish_surrender(text,bigint,jsonb) TO ace_cutover_ace;
COMMIT;
