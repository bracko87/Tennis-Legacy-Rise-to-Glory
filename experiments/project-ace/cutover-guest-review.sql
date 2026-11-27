-- Disposable review only, after admission schema. No production migration.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.guest_evidence (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 event_key text NOT NULL,
 observed_at timestamptz NOT NULL,
 player1_trial jsonb NOT NULL, player2_trial jsonb NOT NULL,
 expired1 boolean NOT NULL, expired2 boolean NOT NULL,
 receipt jsonb,
 FOREIGN KEY(match_id,event_key) REFERENCES ace_cutover_review.handoffs(match_id,event_key),
 CHECK(expired1 OR expired2)
);
GRANT SELECT ON ace_cutover_review.guest_evidence TO ace_review_worker;
-- Review inputs explicitly distinguish non-guests, anonymous trials and converted accounts.
CREATE FUNCTION ace_cutover_review.guest_expired(p_trial jsonb,p_observed timestamptz) RETURNS boolean
LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE expiry timestamptz; converted timestamptz;
BEGIN
 IF p_observed IS NULL OR NOT isfinite(p_observed) OR jsonb_typeof(p_trial) IS DISTINCT FROM 'object'
 OR jsonb_typeof(p_trial->'is_guest') IS DISTINCT FROM 'boolean' OR jsonb_typeof(p_trial->'is_anonymous') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'invalid guest evidence'; END IF;
 IF NOT (p_trial->>'is_guest')::boolean THEN
  IF (p_trial->>'is_anonymous')::boolean OR p_trial->'expires_at' IS DISTINCT FROM 'null'::jsonb OR p_trial->'converted_at' IS DISTINCT FROM 'null'::jsonb THEN RAISE EXCEPTION 'invalid non-guest evidence'; END IF;
  RETURN false;
 END IF;
 IF jsonb_typeof(p_trial->'expires_at') IS DISTINCT FROM 'string' OR NOT (p_trial ? 'converted_at') THEN RAISE EXCEPTION 'missing trial evidence'; END IF;
 expiry:=(p_trial->>'expires_at')::timestamptz; converted:=(p_trial->>'converted_at')::timestamptz;
 IF NOT isfinite(expiry) OR (converted IS NOT NULL AND (NOT isfinite(converted) OR converted>p_observed))
 OR ((p_trial->>'is_anonymous')::boolean AND converted IS NOT NULL)
 OR (NOT (p_trial->>'is_anonymous')::boolean AND converted IS NULL) THEN RAISE EXCEPTION 'inconsistent conversion evidence'; END IF;
 RETURN (p_trial->>'is_anonymous')::boolean AND converted IS NULL AND expiry<=p_observed;
END $$;
CREATE FUNCTION ace_cutover_review.freeze_guest(p_id text,p_key text,p_observed timestamptz,p1 jsonb,p2 jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; g ace_cutover_review.guest_evidence%ROWTYPE; b1 boolean; b2 boolean; requested text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=m.competition) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 b1:=ace_cutover_review.guest_expired(p1,p_observed);b2:=ace_cutover_review.guest_expired(p2,p_observed);
 SELECT * INTO g FROM ace_cutover_review.guest_evidence WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(g.event_key,g.observed_at,g.player1_trial,g.player2_trial) IS DISTINCT FROM ROW(p_key,p_observed,p1,p2) THEN RAISE EXCEPTION 'conflicting guest evidence'; END IF;
  RETURN 'already_frozen';
 END IF;
 IF NOT b1 AND NOT b2 THEN RETURN 'no_expired_guest'; END IF;
 IF m.status<>'scheduled' OR m.started OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'unstarted match required'; END IF;
 requested:=ace_cutover_review.request_handoff(p_id,p_key,'guest_retirement');
 IF requested NOT IN ('queued','already_requested') THEN RAISE EXCEPTION 'guest event not queued'; END IF;
 INSERT INTO ace_cutover_review.guest_evidence(match_id,event_key,observed_at,player1_trial,player2_trial,expired1,expired2) VALUES(p_id,p_key,p_observed,p1,p2,b1,b2);
 RETURN 'frozen';
END $$;
CREATE FUNCTION ace_cutover_review.finish_guest(p_id text,p_revision bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; g ace_cutover_review.guest_evidence%ROWTYPE; v_winner text; v_status text; v_receipt jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT g FROM ace_cutover_review.guest_evidence WHERE match_id=p_id FOR UPDATE;
 IF g.receipt IS NOT NULL THEN RETURN jsonb_build_object('status','already_resolved','receipt',g.receipt); END IF;
 IF m.status<>'scheduled' OR m.started OR m.revision IS DISTINCT FROM p_revision OR m.legacy_simulation<>'none' THEN RAISE EXCEPTION 'invalid guest completion'; END IF;
 IF (SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL)<>1 OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND event_key=g.event_key AND reason='guest_retirement' AND resolution IS NULL) THEN RAISE EXCEPTION 'conflicting external events'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.medical_snapshots h WHERE h.match_id=p_id AND (h.return1 IS NOT NULL OR h.return2 IS NOT NULL)) THEN RAISE EXCEPTION 'medical and guest conflict requires review'; END IF;
 v_status:=CASE WHEN g.expired1 AND g.expired2 THEN 'cancelled' ELSE 'walkover' END;
 v_winner:=CASE WHEN g.expired1 AND g.expired2 THEN NULL WHEN g.expired1 THEN m.player2 ELSE m.player1 END;
 v_receipt:=jsonb_build_object('match_id',m.id,'competition_id',m.competition,'player1_id',m.player1,'player2_id',m.player2,
 'winner_id',v_winner,'status',v_status,'completion_reason','guest_trial_expired','score',CASE WHEN v_status='walkover' THEN 'W/O' ELSE NULL END,
 'started_at',NULL,'completed_at',g.observed_at,'actual_duration_minutes',NULL,'engine_version',NULL,'sets','[]'::jsonb,'stats','[]'::jsonb,
 'expired_player_ids',CASE WHEN g.expired1 AND g.expired2 THEN jsonb_build_array(m.player1,m.player2) WHEN g.expired1 THEN jsonb_build_array(m.player1) ELSE jsonb_build_array(m.player2) END);
 UPDATE ace_cutover_review.guest_evidence SET receipt=v_receipt WHERE match_id=p_id;
 UPDATE ace_cutover_review.handoffs SET resolution=v_status,winner=v_winner WHERE match_id=p_id AND event_key=g.event_key;
 UPDATE ace_cutover_review.matches SET status=v_status,revision=revision+1 WHERE id=p_id;
 RETURN jsonb_build_object('status','resolved','receipt',v_receipt);
END $$;
CREATE FUNCTION ace_cutover_review.guard_guest_effect() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF NEW.receipt->>'completion_reason'='guest_trial_expired' THEN RAISE EXCEPTION 'guest resolution is not a played effect'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_guest_effect BEFORE INSERT ON ace_cutover_review.effects FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_guest_effect();

-- Add verified guest terminal states to medical guard without allowing generic handoff bypass.
CREATE OR REPLACE FUNCTION ace_cutover_review.guard_medical_status() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE h ace_cutover_review.medical_snapshots%ROWTYPE;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) AND NEW.status IN ('walkover','cancelled','bye') THEN
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.guest_evidence g WHERE g.match_id=NEW.id AND g.receipt->>'status'=NEW.status AND NEW.owner='ace' AND NOT NEW.started) THEN RAISE EXCEPTION 'protected external terminal state requires dedicated adapter'; END IF;
 END IF;
 IF NEW.status='in_progress' THEN
  SELECT * INTO h FROM ace_cutover_review.medical_snapshots WHERE match_id=NEW.id;
  IF h.return1 IS NOT NULL OR h.return2 IS NOT NULL THEN RAISE EXCEPTION 'medical restriction'; END IF;
 END IF;
 RETURN NEW;
END $$;
-- A verified guest walkover can feed the next round. A cancellation cannot.
CREATE FUNCTION ace_cutover_review.feeder_winner(p_id text,p_comp text,p_player text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
 SELECT EXISTS(SELECT 1 FROM ace_cutover_review.matches m
 WHERE m.id=p_id AND m.competition=p_comp AND
 ((m.status='completed' AND EXISTS(SELECT 1 FROM ace_cutover_review.effects e WHERE e.match_id=m.id AND e.engine=m.owner AND e.winner=p_player))
 OR (m.status='walkover' AND m.owner='ace' AND EXISTS(SELECT 1 FROM ace_cutover_review.guest_evidence g WHERE g.match_id=m.id AND g.receipt->>'status'='walkover' AND g.receipt->>'winner_id'=p_player))))
$$;
CREATE OR REPLACE FUNCTION ace_cutover_review.guard_feeder_admission() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE f ace_cutover_review.feeder_contract%ROWTYPE;
BEGIN
 IF NEW.status IS NOT DISTINCT FROM OLD.status OR NEW.status NOT IN ('in_progress','completed','walkover','cancelled') OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) THEN RETURN NEW; END IF;
 SELECT * INTO STRICT f FROM ace_cutover_review.feeder_contract WHERE match_id=NEW.id AND competition_id=NEW.competition;
 IF f.feeder1 IS NOT NULL AND NOT ace_cutover_review.feeder_winner(f.feeder1,NEW.competition,NEW.player1) THEN RAISE EXCEPTION 'first feeder not ready or winner mismatch'; END IF;
 IF f.feeder2 IS NOT NULL AND NOT ace_cutover_review.feeder_winner(f.feeder2,NEW.competition,NEW.player2) THEN RAISE EXCEPTION 'second feeder not ready or winner mismatch'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.guest_expired(jsonb,timestamptz),ace_cutover_review.freeze_guest(text,text,timestamptz,jsonb,jsonb),ace_cutover_review.finish_guest(text,bigint),ace_cutover_review.guard_guest_effect(),ace_cutover_review.feeder_winner(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.freeze_guest(text,text,timestamptz,jsonb,jsonb) TO ace_cutover_external;
GRANT EXECUTE ON FUNCTION ace_cutover_review.finish_guest(text,bigint) TO ace_cutover_ace;
COMMIT;
