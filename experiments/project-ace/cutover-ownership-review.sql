-- Disposable schema rehearsal ONLY, never install in production.
BEGIN;
DO $$ BEGIN
 IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF;
END $$;
CREATE SCHEMA ace_cutover_review;
REVOKE ALL ON SCHEMA ace_cutover_review FROM PUBLIC;
GRANT USAGE ON SCHEMA ace_cutover_review TO ace_review_worker,ace_cutover_ace,ace_cutover_legacy,ace_cutover_external;
CREATE TABLE ace_cutover_review.policy (
 singleton boolean PRIMARY KEY CHECK(singleton),
 enabled boolean NOT NULL DEFAULT false,
 competitions text[] NOT NULL DEFAULT '{}'
);
INSERT INTO ace_cutover_review.policy(singleton) VALUES(true);
CREATE TABLE ace_cutover_review.matches (
 id text PRIMARY KEY, competition text NOT NULL,
 scope text NOT NULL CHECK(scope IN ('singles','doubles','national_team')),
 eligible boolean NOT NULL,
 status text NOT NULL CHECK(status IN ('scheduled','in_progress','completed','bye','walkover','cancelled')),
 legacy_simulation text NOT NULL CHECK(legacy_simulation IN ('none','prepared','live','completed')),
 started boolean NOT NULL,
 player1 text NOT NULL, player2 text NOT NULL CHECK(player1<>player2),
 owner text CHECK(owner IN ('ace','legacy')),
 revision bigint NOT NULL DEFAULT 0 CHECK(revision>=0)
);
CREATE TABLE ace_cutover_review.effects (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 engine text NOT NULL CHECK(engine IN ('ace','legacy')),
 winner text NOT NULL,
 receipt jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.handoffs (
 match_id text NOT NULL REFERENCES ace_cutover_review.matches(id),
 event_key text NOT NULL, reason text NOT NULL CHECK(reason IN ('guest_retirement','travel_no_show','health_surrender','watchdog','admin_repair')),
 resolution text CHECK(resolution IN ('cancelled','walkover')),
 winner text,
 PRIMARY KEY(match_id,event_key)
);
-- Controller can seed fixtures/configure but engine logins cannot directly write any table.
GRANT SELECT ON ALL TABLES IN SCHEMA ace_cutover_review TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.seed_match(p_id text,p_comp text,p_scope text,p_eligible boolean,p_status text,p_sim text,p_started boolean,p1 text,p2 text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
 INSERT INTO ace_cutover_review.matches(id,competition,scope,eligible,status,legacy_simulation,started,player1,player2)
 VALUES(p_id,p_comp,p_scope,p_eligible,p_status,p_sim,p_started,p1,p2)
$$;
CREATE FUNCTION ace_cutover_review.configure(p_enabled boolean,p_competitions text[]) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF p_enabled IS NULL OR p_competitions IS NULL OR array_position(p_competitions,NULL) IS NOT NULL THEN RAISE EXCEPTION 'invalid policy'; END IF;
 UPDATE ace_cutover_review.policy SET enabled=p_enabled,competitions=p_competitions WHERE singleton;
END $$;
CREATE FUNCTION ace_cutover_review.actor() RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT CASE session_user WHEN 'ace_cutover_ace' THEN 'ace' WHEN 'ace_cutover_legacy' THEN 'legacy' END
$$;
CREATE FUNCTION ace_cutover_review.claim(p_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; p ace_cutover_review.policy%ROWTYPE; engine text:=ace_cutover_review.actor(); chosen text;
BEGIN
 IF engine IS NULL THEN RAISE EXCEPTION 'invalid engine identity'; END IF;
 -- Lock policy before match. Disable-new-admissions serializes with all claims.
 SELECT * INTO STRICT p FROM ace_cutover_review.policy WHERE singleton FOR SHARE;
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 chosen:=coalesce(m.owner,CASE WHEN m.status='scheduled' AND m.legacy_simulation='none' AND NOT m.started AND p.enabled AND m.competition=ANY(p.competitions) AND m.scope='singles' AND m.eligible THEN 'ace' ELSE 'legacy' END);
 IF chosen<>engine THEN RETURN jsonb_build_object('status','wrong_engine','owner',chosen,'revision',m.revision); END IF;
 IF m.owner IS NOT NULL THEN RETURN jsonb_build_object('status','already_claimed','owner',chosen,'revision',m.revision); END IF;
 IF m.status NOT IN ('scheduled','in_progress') THEN RETURN jsonb_build_object('status','terminal','owner',chosen,'revision',m.revision); END IF;
 UPDATE ace_cutover_review.matches SET owner=chosen,revision=revision+1 WHERE id=p_id RETURNING * INTO m;
 RETURN jsonb_build_object('status','claimed','owner',chosen,'revision',m.revision);
END $$;
CREATE FUNCTION ace_cutover_review.start_match(p_id text,p_revision bigint) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; engine text:=ace_cutover_review.actor();
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF engine IS NULL OR m.owner IS DISTINCT FROM engine THEN RAISE EXCEPTION 'wrong engine'; END IF;
 IF m.status='in_progress' THEN RETURN 'already_started'; END IF;
 IF m.revision IS DISTINCT FROM p_revision OR m.status<>'scheduled' OR m.started THEN RAISE EXCEPTION 'invalid start'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL) THEN RETURN 'handoff_pending'; END IF;
 UPDATE ace_cutover_review.matches SET status='in_progress',started=true,revision=revision+1 WHERE id=p_id;
 RETURN 'started';
END $$;
CREATE FUNCTION ace_cutover_review.finish_match(p_id text,p_revision bigint,p_winner text,p_receipt jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; e ace_cutover_review.effects%ROWTYPE; engine text:=ace_cutover_review.actor();
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF engine IS NULL OR m.owner IS DISTINCT FROM engine THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO e FROM ace_cutover_review.effects WHERE match_id=p_id;
 IF FOUND THEN
  IF e.winner IS DISTINCT FROM p_winner OR e.receipt IS DISTINCT FROM p_receipt THEN RAISE EXCEPTION 'conflicting receipt'; END IF;
  RETURN 'already_completed';
 END IF;
 IF m.revision IS DISTINCT FROM p_revision OR m.status<>'in_progress' OR p_winner IS NULL OR p_winner NOT IN(m.player1,m.player2) OR jsonb_typeof(p_receipt) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'invalid completion'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL) THEN RETURN 'handoff_pending'; END IF;
 INSERT INTO ace_cutover_review.effects VALUES(p_id,engine,p_winner,p_receipt);
 UPDATE ace_cutover_review.matches SET status='completed',revision=revision+1 WHERE id=p_id;
 RETURN 'completed';
END $$;
CREATE FUNCTION ace_cutover_review.request_handoff(p_id text,p_key text,p_reason text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; h ace_cutover_review.handoffs%ROWTYPE;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 SELECT * INTO h FROM ace_cutover_review.handoffs WHERE match_id=p_id AND event_key=p_key;
 IF FOUND THEN
  IF h.reason IS DISTINCT FROM p_reason THEN RAISE EXCEPTION 'conflicting handoff'; END IF;
  RETURN 'already_requested';
 END IF;
 IF m.status NOT IN ('scheduled','in_progress') THEN RETURN 'terminal'; END IF;
 IF p_key IS NULL OR p_key='' THEN RAISE EXCEPTION 'invalid event'; END IF;
 INSERT INTO ace_cutover_review.handoffs(match_id,event_key,reason) VALUES(p_id,p_key,p_reason);
 RETURN CASE WHEN m.status='scheduled' THEN 'queued' ELSE 'manual_review' END;
END $$;
CREATE FUNCTION ace_cutover_review.resolve_handoff(p_id text,p_key text,p_revision bigint,p_status text,p_winner text DEFAULT NULL) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; h ace_cutover_review.handoffs%ROWTYPE; engine text:=ace_cutover_review.actor();
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF engine IS NULL OR m.owner IS DISTINCT FROM engine THEN RAISE EXCEPTION 'wrong engine'; END IF;
 SELECT * INTO STRICT h FROM ace_cutover_review.handoffs WHERE match_id=p_id AND event_key=p_key;
 IF h.resolution IS NOT NULL THEN
  IF h.resolution IS DISTINCT FROM p_status OR h.winner IS DISTINCT FROM p_winner THEN RAISE EXCEPTION 'conflicting resolution'; END IF;
  RETURN 'already_resolved';
 END IF;
 IF m.revision IS DISTINCT FROM p_revision OR m.status<>'scheduled' OR m.started OR p_status IS NULL OR p_status NOT IN ('cancelled','walkover') OR (p_status='cancelled' AND p_winner IS NOT NULL) OR (p_status='walkover' AND (p_winner IS NULL OR p_winner NOT IN(m.player1,m.player2))) THEN RAISE EXCEPTION 'invalid handoff resolution'; END IF;
 IF (SELECT count(*) FROM ace_cutover_review.handoffs WHERE match_id=p_id AND resolution IS NULL)<>1 THEN RAISE EXCEPTION 'multiple handoffs require review'; END IF;
 UPDATE ace_cutover_review.handoffs SET resolution=p_status,winner=p_winner WHERE match_id=p_id AND event_key=p_key;
 UPDATE ace_cutover_review.matches SET status=p_status,revision=revision+1 WHERE id=p_id;
 RETURN 'resolved';
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ace_cutover_review FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.seed_match(text,text,text,boolean,text,text,boolean,text,text),ace_cutover_review.configure(boolean,text[]) TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_cutover_review.claim(text),ace_cutover_review.start_match(text,bigint),ace_cutover_review.finish_match(text,bigint,text,jsonb),ace_cutover_review.resolve_handoff(text,text,bigint,text,text) TO ace_cutover_ace,ace_cutover_legacy;
GRANT EXECUTE ON FUNCTION ace_cutover_review.request_handoff(text,text,text) TO ace_cutover_external;
COMMIT;
