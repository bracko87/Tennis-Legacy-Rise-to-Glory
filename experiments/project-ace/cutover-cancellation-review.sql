-- Disposable review only; install after surrender review. Never production.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.cancellations (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.protected_competitions(competition_id),
 reason text NOT NULL CHECK(length(reason)>0),
 accepted_players integer NOT NULL CHECK(accepted_players>=0),
 minimum_players integer NOT NULL CHECK(minimum_players>0),
 cancelled_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(accepted_players<minimum_players)
);
GRANT SELECT ON ace_cutover_review.cancellations TO ace_review_worker;
-- Only unclaimed, unprepared and unstarted competitions are eligible.
-- Keep scheduled rows as historical fixtures; the competition tombstone blocks all admission.
CREATE FUNCTION ace_cutover_review.cancel_unstarted(p_comp text,p_count integer,p_minimum integer,p_reason text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE prior ace_cutover_review.cancellations%ROWTYPE;
BEGIN
 IF p_comp IS NULL OR p_count IS NULL OR p_count<0 OR p_minimum IS NULL OR p_minimum<>8 OR p_reason IS DISTINCT FROM 'minimum_field_not_met' OR p_count>=p_minimum THEN RAISE EXCEPTION 'invalid minimum-field evidence'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=p_comp) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 SELECT * INTO prior FROM ace_cutover_review.cancellations WHERE competition_id=p_comp;
 IF FOUND THEN
  IF ROW(prior.accepted_players,prior.minimum_players,prior.reason) IS DISTINCT FROM ROW(p_count,p_minimum,p_reason) THEN RAISE EXCEPTION 'conflicting cancellation'; END IF;
  RETURN 'already_cancelled';
 END IF;
 PERFORM 1 FROM ace_cutover_review.matches WHERE competition=p_comp ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.matches m WHERE m.competition=p_comp AND (m.owner IS NOT NULL OR m.status<>'scheduled' OR m.started OR m.legacy_simulation<>'none' OR EXISTS(SELECT 1 FROM ace_cutover_review.handoffs h WHERE h.match_id=m.id))) OR EXISTS(SELECT 1 FROM ace_review.settlement_exports WHERE competition_id=p_comp) THEN RAISE EXCEPTION 'competition already active'; END IF;
 INSERT INTO ace_cutover_review.cancellations(competition_id,reason,accepted_players,minimum_players) VALUES(p_comp,p_reason,p_count,p_minimum);
 RETURN 'cancelled';
END $$;
CREATE FUNCTION ace_cutover_review.guard_cancelled_match() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM ace_cutover_review.cancellations WHERE competition_id=NEW.competition) THEN RAISE EXCEPTION 'competition cancelled'; END IF;
 RETURN NEW;
END $$;
-- Existing guard_seed obtains competition advisory lock first, by trigger-name order.
CREATE TRIGGER z_cutover_cancelled_seed BEFORE INSERT ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_cancelled_match();
CREATE TRIGGER z_cutover_cancelled_update BEFORE UPDATE ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_cancelled_match();
CREATE FUNCTION ace_cutover_review.guard_cancelled_handoff() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM ace_cutover_review.matches m JOIN ace_cutover_review.cancellations c ON c.competition_id=m.competition WHERE m.id=NEW.match_id) THEN RAISE EXCEPTION 'competition cancelled'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_cancelled_handoff BEFORE INSERT ON ace_cutover_review.handoffs FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_cancelled_handoff();
CREATE FUNCTION ace_cutover_review.guard_cancelled_settlement() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.competition_id,91023));
 IF EXISTS(SELECT 1 FROM ace_cutover_review.cancellations WHERE competition_id=NEW.competition_id) THEN RAISE EXCEPTION 'competition cancelled'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER z_cancelled_export BEFORE INSERT ON ace_review.settlement_exports FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_cancelled_settlement();
CREATE TRIGGER z_cancelled_claim BEFORE INSERT ON ace_review.finalization_claims FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_cancelled_settlement();
-- Separate terminal evidence, not played effects. A null winner is explicit.
CREATE TABLE ace_cutover_review.bracket_voids (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 receipt jsonb NOT NULL CHECK(jsonb_typeof(receipt)='object')
);
GRANT SELECT ON ace_cutover_review.bracket_voids TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.terminal_feeder(p_id text,p_comp text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; v jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id AND competition=p_comp;
 IF m.status='completed' THEN
  SELECT jsonb_build_object('winner_id',e.winner) INTO v FROM ace_cutover_review.effects e WHERE e.match_id=p_id AND e.engine=m.owner;
 ELSIF m.status IN ('walkover','cancelled') THEN
  SELECT receipt INTO v FROM ace_cutover_review.guest_evidence WHERE match_id=p_id AND receipt->>'status'=m.status AND m.owner='ace';
 END IF;
 IF v IS NULL AND m.status IN ('bye','cancelled') THEN SELECT receipt INTO v FROM ace_cutover_review.bracket_voids WHERE match_id=p_id AND receipt->>'status'=m.status AND m.owner='ace'; END IF;
 IF v IS NULL OR NOT (v ? 'winner_id') THEN RAISE EXCEPTION 'feeder not terminal'; END IF;
 RETURN v;
END $$;
CREATE FUNCTION ace_cutover_review.continue_void_bracket(p_id text,p_revision bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; f ace_cutover_review.feeder_contract%ROWTYPE; a jsonb; b jsonb; w1 text; w2 text; w text; st text; v jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT receipt INTO v FROM ace_cutover_review.bracket_voids WHERE match_id=p_id;
 IF FOUND THEN RETURN jsonb_build_object('status','already_resolved','receipt',v); END IF;
 IF m.status<>'scheduled' OR m.started OR m.legacy_simulation<>'none' OR m.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'invalid bracket continuation'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL) OR EXISTS(SELECT 1 FROM ace_cutover_review.medical_snapshots WHERE match_id=p_id AND (return1 IS NOT NULL OR return2 IS NOT NULL)) THEN RAISE EXCEPTION 'external conflict requires review'; END IF;
 SELECT * INTO STRICT f FROM ace_cutover_review.feeder_contract WHERE match_id=p_id AND competition_id=m.competition;
 IF f.feeder1 IS NULL OR f.feeder2 IS NULL THEN RAISE EXCEPTION 'two explicit feeders required'; END IF;
 a:=ace_cutover_review.terminal_feeder(f.feeder1,m.competition);b:=ace_cutover_review.terminal_feeder(f.feeder2,m.competition);
 w1:=a->>'winner_id';w2:=b->>'winner_id';
 IF w1 IS NOT NULL AND w2 IS NOT NULL THEN RAISE EXCEPTION 'normal match required'; END IF;
 IF (w1 IS NOT NULL AND w1<>m.player1) OR (w2 IS NOT NULL AND w2<>m.player2) THEN RAISE EXCEPTION 'surviving feeder mismatch'; END IF;
 w:=coalesce(w1,w2);st:=CASE WHEN w IS NULL THEN 'cancelled' ELSE 'bye' END;
 v:=jsonb_build_object('match_id',m.id,'competition_id',m.competition,'status',st,'winner_id',w,'player1_id',w1,'player2_id',w2,'reason','winnerless_feeder','started_at',NULL,'sets','[]'::jsonb,'stats','[]'::jsonb,'actual_duration_minutes',NULL);
 INSERT INTO ace_cutover_review.bracket_voids VALUES(p_id,v);
 UPDATE ace_cutover_review.matches SET status=st,revision=revision+1 WHERE id=p_id;
 RETURN jsonb_build_object('status','resolved','receipt',v);
END $$;
-- Permit only a receipt produced by the dedicated continuation path to bypass
-- the normal two-populated-slot guard; actual slots are in the terminal receipt.
CREATE OR REPLACE FUNCTION ace_cutover_review.guard_feeder_admission() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE f ace_cutover_review.feeder_contract%ROWTYPE;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status OR NEW.status NOT IN ('in_progress','completed','walkover','cancelled','bye') OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) THEN RETURN NEW; END IF;
 IF NEW.status IN ('bye','cancelled') AND EXISTS(SELECT 1 FROM ace_cutover_review.bracket_voids v WHERE v.match_id=NEW.id AND v.receipt->>'status'=NEW.status AND NEW.owner='ace' AND NOT NEW.started) THEN RETURN NEW; END IF;
 SELECT * INTO STRICT f FROM ace_cutover_review.feeder_contract WHERE match_id=NEW.id AND competition_id=NEW.competition;
 IF f.feeder1 IS NOT NULL AND NOT ace_cutover_review.feeder_winner(f.feeder1,NEW.competition,NEW.player1) THEN RAISE EXCEPTION 'first feeder not ready or winner mismatch'; END IF;
 IF f.feeder2 IS NOT NULL AND NOT ace_cutover_review.feeder_winner(f.feeder2,NEW.competition,NEW.player2) THEN RAISE EXCEPTION 'second feeder not ready or winner mismatch'; END IF;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION ace_cutover_review.feeder_winner(p_id text,p_comp text,p_player text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
 SELECT EXISTS(SELECT 1 FROM ace_cutover_review.matches m WHERE m.id=p_id AND m.competition=p_comp AND
 ((m.status='completed' AND EXISTS(SELECT 1 FROM ace_cutover_review.effects e WHERE e.match_id=m.id AND e.engine=m.owner AND e.winner=p_player))
 OR (m.status='walkover' AND m.owner='ace' AND EXISTS(SELECT 1 FROM ace_cutover_review.guest_evidence g WHERE g.match_id=m.id AND g.receipt->>'status'='walkover' AND g.receipt->>'winner_id'=p_player))
 OR (m.status='bye' AND m.owner='ace' AND EXISTS(SELECT 1 FROM ace_cutover_review.bracket_voids v WHERE v.match_id=m.id AND v.receipt->>'status'='bye' AND v.receipt->>'winner_id'=p_player))))
$$;
CREATE OR REPLACE FUNCTION ace_cutover_review.guard_medical_status() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE h ace_cutover_review.medical_snapshots%ROWTYPE;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) AND NEW.status IN ('walkover','cancelled','bye') THEN
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.guest_evidence g WHERE g.match_id=NEW.id AND g.receipt->>'status'=NEW.status AND NEW.owner='ace' AND NOT NEW.started)
  AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.bracket_voids v WHERE v.match_id=NEW.id AND v.receipt->>'status'=NEW.status AND NEW.owner='ace' AND NOT NEW.started) THEN RAISE EXCEPTION 'protected external terminal state requires dedicated adapter'; END IF;
 END IF;
 IF NEW.status='in_progress' THEN
  SELECT * INTO h FROM ace_cutover_review.medical_snapshots WHERE match_id=NEW.id;
  IF h.return1 IS NOT NULL OR h.return2 IS NOT NULL THEN RAISE EXCEPTION 'medical restriction'; END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.cancel_unstarted(text,integer,integer,text),ace_cutover_review.guard_cancelled_match(),ace_cutover_review.guard_cancelled_handoff(),ace_cutover_review.guard_cancelled_settlement(),ace_cutover_review.terminal_feeder(text,text),ace_cutover_review.continue_void_bracket(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.cancel_unstarted(text,integer,integer,text) TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_cutover_review.continue_void_bracket(text,bigint) TO ace_cutover_ace;
COMMIT;
