-- Disposable source readiness and runtime mirror, not official game writes.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.source_clock (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.source_contracts(competition_id),
 revision bigint NOT NULL,
 game_second bigint NOT NULL CHECK(game_second>=0),
 paused boolean NOT NULL,
 captured_at timestamptz NOT NULL
);
CREATE TABLE ace_cutover_review.source_readiness (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_admissions(match_id),
 revision bigint NOT NULL,
 match_revision bigint NOT NULL,
 source_revision bigint NOT NULL,
 clock_revision bigint NOT NULL,
 evidence jsonb NOT NULL,
 blocked1 integer,
 blocked2 integer
);
CREATE TABLE ace_cutover_review.source_starts (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_admissions(match_id),
 match_revision bigint NOT NULL,
 readiness_revision bigint NOT NULL,
 clock_revision bigint NOT NULL,
 game_second bigint NOT NULL,
 evidence jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_runtime_events (
 match_id text NOT NULL REFERENCES ace_cutover_review.source_admissions(match_id),
 match_revision bigint NOT NULL,
 status text NOT NULL,
 owner text NOT NULL,
 receipt jsonb,
 PRIMARY KEY(match_id,match_revision)
);
GRANT SELECT ON ace_cutover_review.source_clock,ace_cutover_review.source_readiness,ace_cutover_review.source_starts,ace_cutover_review.source_runtime_events TO ace_review_worker;
-- Controller-supplied clock sample; no local interpolation or live clock RPC.
CREATE FUNCTION ace_cutover_review.publish_source_clock(p_comp text,p_expected bigint,p_second bigint,p_paused boolean) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE c ace_cutover_review.source_clock%ROWTYPE;
BEGIN
 IF p_second IS NULL OR p_second<0 OR p_second>316224000000 OR p_paused IS NULL THEN RAISE EXCEPTION 'invalid clock sample'; END IF;
 -- Serialize first publication and updates without taking any match lock.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91025));
 SELECT * INTO c FROM ace_cutover_review.source_clock WHERE competition_id=p_comp FOR UPDATE;
 IF NOT FOUND THEN
  IF p_expected IS DISTINCT FROM -1 THEN RAISE EXCEPTION 'stale clock revision'; END IF;
  INSERT INTO ace_cutover_review.source_clock VALUES(p_comp,0,p_second,p_paused,clock_timestamp());
  RETURN 0;
 END IF;
 IF c.revision IS DISTINCT FROM p_expected OR p_second<c.game_second THEN RAISE EXCEPTION 'stale or backward clock'; END IF;
 UPDATE ace_cutover_review.source_clock SET revision=revision+1,game_second=p_second,paused=p_paused,captured_at=clock_timestamp() WHERE competition_id=p_comp RETURNING revision INTO c.revision;
 RETURN c.revision;
END $$;
-- A new readiness sample invalidates the earlier revision. Evidence is in slot order.
CREATE FUNCTION ace_cutover_review.freeze_source_readiness(p_id text,p_expected bigint,p_match_rev bigint,p_source_rev bigint,p_clock_rev bigint,p jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; a ace_cutover_review.source_admissions%ROWTYPE; c ace_cutover_review.source_clock%ROWTYPE; old ace_cutover_review.source_readiness%ROWTYPE; r1 integer; r2 integer;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 SELECT * INTO STRICT a FROM ace_cutover_review.source_admissions WHERE match_id=p_id;
 SELECT * INTO STRICT c FROM ace_cutover_review.source_clock WHERE competition_id=m.competition FOR SHARE;
 IF m.status<>'scheduled' OR m.started OR m.revision IS DISTINCT FROM p_match_rev OR a.source_revision IS DISTINCT FROM p_source_rev OR c.revision IS DISTINCT FROM p_clock_rev THEN RAISE EXCEPTION 'stale readiness inputs'; END IF;
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR p->>'player1_id' IS DISTINCT FROM m.player1 OR p->>'player2_id' IS DISTINCT FROM m.player2 OR p->'complete_health_export' IS DISTINCT FROM 'true'::jsonb OR jsonb_typeof(p->'travel_ready') IS DISTINCT FROM 'boolean' OR jsonb_typeof(p->'resources_ready') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'invalid readiness evidence'; END IF;
 r1:=ace_cutover_review.blocked_return(p->'health1',(c.game_second/86400)::int);
 r2:=ace_cutover_review.blocked_return(p->'health2',(c.game_second/86400)::int);
 SELECT * INTO old FROM ace_cutover_review.source_readiness WHERE match_id=p_id;
 IF FOUND THEN
  IF old.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'stale readiness revision'; END IF;
  UPDATE ace_cutover_review.source_readiness SET revision=revision+1,match_revision=p_match_rev,source_revision=p_source_rev,clock_revision=p_clock_rev,evidence=p,blocked1=r1,blocked2=r2 WHERE match_id=p_id RETURNING revision INTO old.revision;
  RETURN old.revision;
 END IF;
 IF p_expected IS DISTINCT FROM -1 THEN RAISE EXCEPTION 'stale readiness revision'; END IF;
 INSERT INTO ace_cutover_review.source_readiness VALUES(p_id,0,p_match_rev,p_source_rev,p_clock_rev,p,r1,r2);
 RETURN 0;
END $$;
-- Existing start RPC remains valid for non-source fixtures, but cannot bypass this gate.
CREATE FUNCTION ace_cutover_review.guard_source_start() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status='in_progress' AND EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_starts s WHERE s.match_id=NEW.id AND s.match_revision=OLD.revision) THEN RAISE EXCEPTION 'dedicated source start required'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER z_source_start BEFORE UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_source_start();
CREATE FUNCTION ace_cutover_review.start_source(p_id text,p_match_rev bigint,p_ready_rev bigint,p_clock_rev bigint) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; a ace_cutover_review.source_admissions%ROWTYPE; c ace_cutover_review.source_clock%ROWTYPE; rd ace_cutover_review.source_readiness%ROWTYPE; s ace_cutover_review.source_slots%ROWTYPE; prior ace_cutover_review.source_starts%ROWTYPE; season int; due bigint; outcome text;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF ace_cutover_review.actor() IS NULL OR m.owner IS DISTINCT FROM ace_cutover_review.actor() THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT a FROM ace_cutover_review.source_admissions WHERE match_id=p_id;
 SELECT * INTO prior FROM ace_cutover_review.source_starts WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(prior.match_revision,prior.readiness_revision,prior.clock_revision) IS DISTINCT FROM ROW(p_match_rev,p_ready_rev,p_clock_rev) THEN RAISE EXCEPTION 'conflicting start replay'; END IF;
  RETURN 'already_started';
 END IF;
 IF m.revision IS DISTINCT FROM p_match_rev OR m.status<>'scheduled' OR m.started THEN RAISE EXCEPTION 'invalid source start'; END IF;
 SELECT * INTO STRICT c FROM ace_cutover_review.source_clock WHERE competition_id=m.competition FOR SHARE;
 SELECT * INTO STRICT rd FROM ace_cutover_review.source_readiness WHERE match_id=p_id;
 IF c.revision IS DISTINCT FROM p_clock_rev OR rd.revision IS DISTINCT FROM p_ready_rev OR rd.clock_revision IS DISTINCT FROM c.revision OR rd.match_revision IS DISTINCT FROM m.revision OR rd.source_revision IS DISTINCT FROM a.source_revision THEN RAISE EXCEPTION 'stale readiness or clock'; END IF;
 IF clock_timestamp()-c.captured_at>interval '60 seconds' THEN RETURN 'clock_refresh_required'; END IF;
 IF c.paused THEN RETURN 'clock_paused'; END IF;
 SELECT * INTO STRICT s FROM ace_cutover_review.source_slots WHERE match_id=p_id;
 SELECT (contract->>'season_number')::int INTO STRICT season FROM ace_cutover_review.source_contracts WHERE competition_id=m.competition;
 due:=((season-1)::bigint*366+2+((s.slot->>'scheduled_season_week')::int-1)*7+(s.slot->>'scheduled_day')::int-1)*86400+(s.slot->>'scheduled_start_minute')::int*60;
 IF c.game_second<due THEN RETURN 'not_due'; END IF;
 IF rd.blocked1 IS NOT NULL OR rd.blocked2 IS NOT NULL THEN RETURN 'medical_review_required'; END IF;
 IF rd.evidence->'travel_ready' IS DISTINCT FROM 'true'::jsonb THEN RETURN 'travel_not_ready'; END IF;
 IF rd.evidence->'resources_ready' IS DISTINCT FROM 'true'::jsonb THEN RETURN 'resources_not_ready'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL) THEN RETURN 'handoff_pending'; END IF;
 INSERT INTO ace_cutover_review.source_starts VALUES(p_id,p_match_rev,p_ready_rev,p_clock_rev,c.game_second,rd.evidence);
 outcome:=ace_cutover_review.start_match(p_id,p_match_rev);
 IF outcome<>'started' THEN RAISE EXCEPTION 'atomic source start failed'; END IF;
 RETURN outcome;
END $$;
-- Owner-side mirror is append-only and derived from actual committed review transitions.
CREATE FUNCTION ace_cutover_review.record_source_runtime() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE v jsonb;
BEGIN
 IF OLD.status IS NOT DISTINCT FROM NEW.status OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) THEN RETURN NEW; END IF;
 IF NEW.status='completed' THEN SELECT receipt INTO STRICT v FROM ace_cutover_review.effects WHERE match_id=NEW.id;
 ELSIF NEW.status IN ('walkover','bye','cancelled') THEN v:=ace_cutover_review.terminal_feeder(NEW.id,NEW.competition); END IF;
 INSERT INTO ace_cutover_review.source_runtime_events VALUES(NEW.id,NEW.revision,NEW.status,NEW.owner,v);
 RETURN NEW;
END $$;
CREATE TRIGGER source_runtime_event AFTER UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.record_source_runtime();
REVOKE ALL ON FUNCTION ace_cutover_review.publish_source_clock(text,bigint,bigint,boolean),ace_cutover_review.freeze_source_readiness(text,bigint,bigint,bigint,bigint,jsonb),ace_cutover_review.guard_source_start(),ace_cutover_review.start_source(text,bigint,bigint,bigint),ace_cutover_review.record_source_runtime() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.publish_source_clock(text,bigint,bigint,boolean),ace_cutover_review.freeze_source_readiness(text,bigint,bigint,bigint,bigint,jsonb) TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_cutover_review.start_source(text,bigint,bigint,bigint) TO ace_cutover_ace,ace_cutover_legacy;
COMMIT;
