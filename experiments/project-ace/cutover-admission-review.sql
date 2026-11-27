-- Isolated review only, after medical schema. No production migration.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE FUNCTION ace_cutover_review.guard_feeder_admission() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE f ace_cutover_review.feeder_contract%ROWTYPE;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status OR NEW.status NOT IN ('in_progress','completed') OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) THEN RETURN NEW; END IF;
 SELECT * INTO STRICT f FROM ace_cutover_review.feeder_contract WHERE match_id=NEW.id AND competition_id=NEW.competition;
 IF f.feeder1 IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.matches m JOIN ace_cutover_review.effects e ON e.match_id=m.id WHERE m.id=f.feeder1 AND m.competition=NEW.competition AND m.status='completed' AND e.engine=m.owner AND e.winner=NEW.player1) THEN RAISE EXCEPTION 'first feeder not ready or winner mismatch'; END IF;
 IF f.feeder2 IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.matches m JOIN ace_cutover_review.effects e ON e.match_id=m.id WHERE m.id=f.feeder2 AND m.competition=NEW.competition AND m.status='completed' AND e.engine=m.owner AND e.winner=NEW.player2) THEN RAISE EXCEPTION 'second feeder not ready or winner mismatch'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_feeder_admission BEFORE UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_feeder_admission();
-- Travel source data is explicit supplied review evidence, not a live itinerary query.
CREATE TABLE ace_cutover_review.travel_evidence (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 event_key text NOT NULL,
 absolute_day integer NOT NULL CHECK(absolute_day>=0),
 player1_blocked boolean NOT NULL, player2_blocked boolean NOT NULL,
 ready1 bigint CHECK(ready1>=0), ready2 bigint CHECK(ready2>=0),
 receipt jsonb,
 FOREIGN KEY(match_id,event_key) REFERENCES ace_cutover_review.handoffs(match_id,event_key),
 CHECK(player1_blocked OR player2_blocked)
);
GRANT SELECT ON ace_cutover_review.travel_evidence TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.freeze_travel(p_id text,p_key text,p_day integer,p_b1 boolean,p_b2 boolean,p_r1 bigint,p_r2 bigint) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; t ace_cutover_review.travel_evidence%ROWTYPE; requested text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=m.competition) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 SELECT * INTO t FROM ace_cutover_review.travel_evidence WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(t.event_key,t.absolute_day,t.player1_blocked,t.player2_blocked,t.ready1,t.ready2) IS DISTINCT FROM ROW(p_key,p_day,p_b1,p_b2,p_r1,p_r2) THEN RAISE EXCEPTION 'conflicting travel evidence'; END IF;
  RETURN 'already_frozen';
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'unstarted match required'; END IF;
 requested:=ace_cutover_review.request_handoff(p_id,p_key,'travel_no_show');
 IF requested NOT IN ('queued','already_requested') THEN RAISE EXCEPTION 'travel event not queued'; END IF;
 INSERT INTO ace_cutover_review.travel_evidence(match_id,event_key,absolute_day,player1_blocked,player2_blocked,ready1,ready2) VALUES(p_id,p_key,p_day,p_b1,p_b2,p_r1,p_r2);
 RETURN 'frozen';
END $$;
CREATE FUNCTION ace_cutover_review.finish_travel(p_id text,p_revision bigint,p_receipt jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; t ace_cutover_review.travel_evidence%ROWTYPE; v_winner text; blocked jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT t FROM ace_cutover_review.travel_evidence WHERE match_id=p_id FOR UPDATE;
 IF t.receipt IS NOT NULL THEN
  IF t.receipt IS DISTINCT FROM p_receipt THEN RAISE EXCEPTION 'conflicting travel receipt'; END IF;
  RETURN 'already_completed';
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.revision IS DISTINCT FROM p_revision OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'invalid travel completion'; END IF;
 IF (SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL)<>1 OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND event_key=t.event_key AND reason='travel_no_show' AND resolution IS NULL) THEN RAISE EXCEPTION 'conflicting external events'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.medical_snapshots h WHERE h.match_id=p_id AND (h.return1 IS NOT NULL OR h.return2 IS NOT NULL)) THEN RAISE EXCEPTION 'medical and travel conflict requires review'; END IF;
 v_winner:=CASE WHEN NOT t.player1_blocked THEN m.player1 WHEN NOT t.player2_blocked THEN m.player2 WHEN coalesce(t.ready1,9223372036854775807)<=coalesce(t.ready2,9223372036854775807) THEN m.player1 ELSE m.player2 END;
 blocked:=CASE WHEN t.player1_blocked AND t.player2_blocked THEN jsonb_build_array(m.player1,m.player2) WHEN t.player1_blocked THEN jsonb_build_array(m.player1) ELSE jsonb_build_array(m.player2) END;
 IF p_receipt->>'match_id' IS DISTINCT FROM p_id OR p_receipt->>'competition_id' IS DISTINCT FROM m.competition OR p_receipt->>'player1_id' IS DISTINCT FROM m.player1 OR p_receipt->>'player2_id' IS DISTINCT FROM m.player2 OR p_receipt->>'winner_id' IS DISTINCT FROM v_winner OR p_receipt->>'status' IS DISTINCT FROM 'completed' OR p_receipt->>'completion_reason' IS DISTINCT FROM 'travel_no_show' OR p_receipt->>'score' IS DISTINCT FROM 'W/O' OR p_receipt->'actual_duration_minutes' IS DISTINCT FROM 'null'::jsonb OR p_receipt->'engine_version' IS DISTINCT FROM 'null'::jsonb OR p_receipt->'sets' IS DISTINCT FROM '[]'::jsonb OR p_receipt->'stats' IS DISTINCT FROM '[]'::jsonb OR p_receipt->'travel_absolute_day' IS DISTINCT FROM to_jsonb(t.absolute_day) OR p_receipt->'travel_unavailable_player_ids' IS DISTINCT FROM blocked OR p_receipt->>'completed_at' IS NULL OR p_receipt->>'started_at' IS DISTINCT FROM p_receipt->>'completed_at' THEN RAISE EXCEPTION 'travel receipt mismatch'; END IF;
 PERFORM (p_receipt->>'completed_at')::timestamptz;
 UPDATE ace_cutover_review.travel_evidence SET receipt=p_receipt WHERE match_id=p_id;
 UPDATE ace_cutover_review.handoffs SET resolution='walkover',winner=v_winner WHERE match_id=p_id AND event_key=t.event_key;
 INSERT INTO ace_cutover_review.effects VALUES(p_id,'ace',v_winner,p_receipt);
 UPDATE ace_cutover_review.matches SET status='completed',revision=revision+1 WHERE id=p_id;
 RETURN 'completed';
END $$;
CREATE FUNCTION ace_cutover_review.guard_travel_effect() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF NEW.receipt->>'completion_reason'='travel_no_show' AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.travel_evidence t WHERE t.match_id=NEW.match_id AND t.receipt=NEW.receipt AND NEW.engine='ace') THEN RAISE EXCEPTION 'use verified travel completion'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_travel_effect BEFORE INSERT ON ace_cutover_review.effects FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_travel_effect();
REVOKE ALL ON FUNCTION ace_cutover_review.guard_feeder_admission(),ace_cutover_review.freeze_travel(text,text,integer,boolean,boolean,bigint,bigint),ace_cutover_review.finish_travel(text,bigint,jsonb),ace_cutover_review.guard_travel_effect() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.freeze_travel(text,text,integer,boolean,boolean,bigint,bigint) TO ace_cutover_external;
GRANT EXECUTE ON FUNCTION ace_cutover_review.finish_travel(text,bigint,jsonb) TO ace_cutover_ace;
COMMIT;
