-- Disposable review of common scheduling lock and non-admitted inventory.
BEGIN;
DO $guard$ BEGIN IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'disposable review required'; END IF; END $guard$;
CREATE SCHEMA ace_shared_schedule_fixture;
CREATE TABLE ace_shared_schedule_fixture.inventory(
 id text PRIMARY KEY, owner text NOT NULL CHECK(owner IN ('ace','legacy','external')),
 status text NOT NULL CHECK(status IN ('scheduled','live','completed')),
 revision bigint NOT NULL DEFAULT 0, venue text NOT NULL, court int NOT NULL CHECK(court>0),
 player1 text NOT NULL, player2 text NOT NULL CHECK(player2<>player1),
 start_second bigint NOT NULL CHECK(start_second>=0), duration_minutes int NOT NULL CHECK(duration_minutes BETWEEN 60 AND 420));
ALTER TABLE ace_shared_schedule_fixture.inventory ADD COLUMN actual_end_second bigint;
ALTER TABLE ace_shared_schedule_fixture.inventory ADD CHECK ((status='completed')=(actual_end_second IS NOT NULL));
-- Explicit feeder graph: identities are match IDs, not predicted winners.
CREATE TABLE ace_shared_schedule_fixture.feeders(
 feeder_id text REFERENCES ace_shared_schedule_fixture.inventory(id),
 downstream_id text REFERENCES ace_shared_schedule_fixture.inventory(id),
 PRIMARY KEY(feeder_id,downstream_id), CHECK(feeder_id<>downstream_id)
);
CREATE FUNCTION ace_shared_schedule_fixture.guard_feeder_graph() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,ace_shared_schedule_fixture AS $fn$
BEGIN
 PERFORM pg_advisory_xact_lock(91029001);
 IF EXISTS(WITH RECURSIVE reach(id) AS (SELECT NEW.downstream_id UNION SELECT f.downstream_id FROM ace_shared_schedule_fixture.feeders f JOIN reach r ON f.feeder_id=r.id) SELECT 1 FROM reach WHERE id=NEW.feeder_id) THEN RAISE EXCEPTION 'cyclic feeder graph'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER feeder_graph_guard BEFORE INSERT OR UPDATE ON ace_shared_schedule_fixture.feeders FOR EACH ROW EXECUTE FUNCTION ace_shared_schedule_fixture.guard_feeder_graph();
CREATE FUNCTION ace_shared_schedule_fixture.change_slot(p_id text,p_revision bigint,p_start bigint,p_court int,p_start_live boolean) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_shared_schedule_fixture AS $fn$
DECLARE m ace_shared_schedule_fixture.inventory%ROWTYPE; actor text;
BEGIN
 -- Lock precedes all inventory row locks. Both engine roles use this same authority.
 PERFORM pg_advisory_xact_lock(91029001);
 actor:=CASE session_user WHEN 'ace_cutover_ace' THEN 'ace' WHEN 'ace_cutover_legacy' THEN 'legacy' ELSE NULL END;
 SELECT * INTO STRICT m FROM ace_shared_schedule_fixture.inventory WHERE id=p_id FOR UPDATE;
 IF actor IS NULL OR actor<>m.owner THEN RAISE EXCEPTION 'wrong scheduling owner'; END IF;
 IF m.status<>'scheduled' OR m.revision<>p_revision OR p_revision IS NULL OR p_start IS NULL OR p_start<0 OR p_court IS NULL OR p_court<1 OR p_start_live IS NULL THEN RAISE EXCEPTION 'invalid schedule revision'; END IF;
 IF p_start_live AND (p_start<>m.start_second OR p_court<>m.court) THEN RAISE EXCEPTION 'start must use current slot'; END IF;
 IF EXISTS(SELECT 1 FROM ace_shared_schedule_fixture.inventory x WHERE x.id<>m.id AND (
 (x.status='live' AND p_start_live AND ((x.venue=m.venue AND x.court=p_court) OR x.player1 IN (m.player1,m.player2) OR x.player2 IN (m.player1,m.player2))) OR
 (x.status IN ('scheduled','live','completed') AND (
 (x.venue=m.venue AND x.court=p_court AND p_start<coalesce(x.actual_end_second,x.start_second+x.duration_minutes*60)+900 AND x.start_second<p_start+(m.duration_minutes+15)*60) OR
 ((x.player1 IN (m.player1,m.player2) OR x.player2 IN (m.player1,m.player2)) AND p_start<coalesce(x.actual_end_second,x.start_second+x.duration_minutes*60)+3600 AND x.start_second<p_start+(m.duration_minutes+60)*60)))))
 THEN RAISE EXCEPTION 'shared resource conflict'; END IF;
 IF EXISTS(SELECT 1 FROM ace_shared_schedule_fixture.feeders f JOIN ace_shared_schedule_fixture.inventory x ON x.id=f.feeder_id WHERE f.downstream_id=m.id AND (p_start<coalesce(x.actual_end_second,x.start_second+x.duration_minutes*60)+3600 OR (p_start_live AND x.status<>'completed'))) THEN RAISE EXCEPTION 'feeder not ready'; END IF;
 IF EXISTS(SELECT 1 FROM ace_shared_schedule_fixture.feeders f JOIN ace_shared_schedule_fixture.inventory x ON x.id=f.downstream_id WHERE f.feeder_id=m.id AND (x.status<>'scheduled' OR x.start_second<p_start+(m.duration_minutes+60)*60)) THEN RAISE EXCEPTION 'downstream chronology conflict'; END IF;
 UPDATE ace_shared_schedule_fixture.inventory SET start_second=p_start,court=p_court,status=CASE WHEN p_start_live THEN 'live' ELSE status END,revision=revision+1 WHERE id=p_id;
 RETURN CASE WHEN p_start_live THEN 'started_review' ELSE 'rescheduled_review' END;
END $fn$;
REVOKE ALL ON SCHEMA ace_shared_schedule_fixture FROM PUBLIC;
REVOKE ALL ON FUNCTION ace_shared_schedule_fixture.change_slot(text,bigint,bigint,int,boolean) FROM PUBLIC;
GRANT USAGE ON SCHEMA ace_shared_schedule_fixture TO ace_cutover_ace,ace_cutover_legacy;
GRANT EXECUTE ON FUNCTION ace_shared_schedule_fixture.change_slot(text,bigint,bigint,int,boolean) TO ace_cutover_ace,ace_cutover_legacy;
CREATE TABLE ace_shared_schedule_fixture.obligations(
 source_id text REFERENCES ace_shared_schedule_fixture.inventory(id),
 target_id text REFERENCES ace_shared_schedule_fixture.inventory(id),
 target_owner text NOT NULL, target_revision bigint NOT NULL,
 player_conflict boolean NOT NULL, court_conflict boolean NOT NULL,
 earliest_second bigint NOT NULL, observed_start bigint NOT NULL,
 PRIMARY KEY(source_id,target_id), CHECK(source_id<>target_id), CHECK(player_conflict OR court_conflict)
);
CREATE FUNCTION ace_shared_schedule_fixture.finish_slot(p_id text,p_revision bigint,p_end bigint) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_shared_schedule_fixture AS $fn$
DECLARE m ace_shared_schedule_fixture.inventory%ROWTYPE; actor text;
BEGIN
 PERFORM pg_advisory_xact_lock(91029001);
 actor:=CASE session_user WHEN 'ace_cutover_ace' THEN 'ace' WHEN 'ace_cutover_legacy' THEN 'legacy' ELSE NULL END;
 SELECT * INTO STRICT m FROM ace_shared_schedule_fixture.inventory WHERE id=p_id FOR UPDATE;
 IF actor IS NULL OR actor<>m.owner THEN RAISE EXCEPTION 'wrong scheduling owner'; END IF;
 IF m.status='completed' AND p_revision=m.revision-1 AND p_end=m.actual_end_second THEN RETURN 'already_completed_review'; END IF;
 IF m.status<>'live' OR p_revision IS DISTINCT FROM m.revision OR p_end IS NULL OR p_end<m.start_second+3600 OR p_end>m.start_second+25200 THEN RAISE EXCEPTION 'invalid completion evidence'; END IF;
 UPDATE ace_shared_schedule_fixture.inventory SET status='completed',actual_end_second=p_end,revision=revision+1 WHERE id=p_id;
 INSERT INTO ace_shared_schedule_fixture.obligations
 SELECT m.id,x.id,x.owner,x.revision,
  (x.player1 IN(m.player1,m.player2) OR x.player2 IN(m.player1,m.player2)) AND x.start_second<p_end+3600,
  (x.venue=m.venue AND x.court=m.court) AND x.start_second<p_end+900,
  greatest(CASE WHEN x.player1 IN(m.player1,m.player2) OR x.player2 IN(m.player1,m.player2) THEN p_end+3600 ELSE 0 END,
           CASE WHEN x.venue=m.venue AND x.court=m.court THEN p_end+900 ELSE 0 END),
  x.start_second
 FROM ace_shared_schedule_fixture.inventory x
 WHERE x.id<>m.id AND x.status='scheduled' AND x.start_second>=m.start_second
 AND ((x.player1 IN(m.player1,m.player2) OR x.player2 IN(m.player1,m.player2)) AND x.start_second<p_end+3600
 OR (x.venue=m.venue AND x.court=m.court AND x.start_second<p_end+900))
 AND p_end>m.start_second+m.duration_minutes*60;
 RETURN 'completed_review';
END $fn$;
REVOKE ALL ON FUNCTION ace_shared_schedule_fixture.finish_slot(text,bigint,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_shared_schedule_fixture.finish_slot(text,bigint,bigint) TO ace_cutover_ace,ace_cutover_legacy;
INSERT INTO ace_shared_schedule_fixture.inventory(id,owner,status,revision,venue,court,player1,player2,start_second,duration_minutes) VALUES
 ('a','ace','scheduled',0,'venue',1,'p1','p2',36000,60),
 ('l','legacy','scheduled',0,'venue',2,'p3','p4',36000,60),
 ('e','external','scheduled',0,'venue',3,'p1','p5',54000,60);
CREATE TABLE ace_shared_schedule_fixture.phase_policy(
 match_id text PRIMARY KEY REFERENCES ace_shared_schedule_fixture.inventory(id),
 first_day int NOT NULL CHECK(first_day>=0), last_day int NOT NULL,
 court_count int NOT NULL CHECK(court_count BETWEEN 1 AND 32),
 CHECK(last_day BETWEEN first_day AND first_day+14)
);
CREATE TABLE ace_shared_schedule_fixture.resolutions(
 source_id text NOT NULL,target_id text NOT NULL, revised_second bigint NOT NULL,revised_court int NOT NULL,revised_revision bigint NOT NULL,
 PRIMARY KEY(source_id,target_id), FOREIGN KEY(source_id,target_id) REFERENCES ace_shared_schedule_fixture.obligations(source_id,target_id)
);
CREATE FUNCTION ace_shared_schedule_fixture.resolve_slot(p_source text,p_target text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_shared_schedule_fixture AS $fn$
DECLARE m ace_shared_schedule_fixture.inventory%ROWTYPE; o ace_shared_schedule_fixture.obligations%ROWTYPE; policy ace_shared_schedule_fixture.phase_policy%ROWTYPE; prior ace_shared_schedule_fixture.resolutions%ROWTYPE; actor text; candidate record; earliest bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(91029001);
 actor:=CASE session_user WHEN 'ace_cutover_ace' THEN 'ace' WHEN 'ace_cutover_legacy' THEN 'legacy' ELSE NULL END;
 SELECT * INTO STRICT m FROM ace_shared_schedule_fixture.inventory WHERE id=p_target FOR UPDATE;
 IF actor IS NULL OR actor<>m.owner THEN RAISE EXCEPTION 'wrong scheduling owner'; END IF;
 SELECT * INTO STRICT o FROM ace_shared_schedule_fixture.obligations WHERE source_id=p_source AND target_id=p_target;
 SELECT * INTO prior FROM ace_shared_schedule_fixture.resolutions WHERE source_id=p_source AND target_id=p_target;
 IF FOUND THEN RETURN to_jsonb(prior)||jsonb_build_object('status','already_resolved_review'); END IF;
 IF m.status<>'scheduled' OR m.revision<>o.target_revision THEN RETURN jsonb_build_object('status','stale_obligation_review'); END IF;
 SELECT * INTO policy FROM ace_shared_schedule_fixture.phase_policy WHERE match_id=p_target;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','phase_policy_required'); END IF;
 SELECT greatest(m.start_second,max(earliest_second)) INTO earliest FROM ace_shared_schedule_fixture.obligations WHERE target_id=p_target AND target_revision=m.revision;
 FOR candidate IN SELECT d::bigint*86400+minute*60 AS second,c AS court FROM generate_series(greatest(policy.first_day,(earliest/86400)::int),policy.last_day) d CROSS JOIN generate_series(600,1290,30) minute CROSS JOIN generate_series(1,policy.court_count) c WHERE d::bigint*86400+minute*60>=earliest ORDER BY d,(c<>m.court),minute,c LOOP
  BEGIN
   PERFORM ace_shared_schedule_fixture.change_slot(p_target,m.revision,candidate.second,candidate.court,false);
  EXCEPTION WHEN raise_exception THEN
   IF SQLERRM NOT IN ('shared resource conflict','feeder not ready','downstream chronology conflict') THEN RAISE; END IF;
   CONTINUE;
  END;
  INSERT INTO ace_shared_schedule_fixture.resolutions VALUES(p_source,p_target,candidate.second,candidate.court,m.revision+1) RETURNING * INTO prior;
  RETURN to_jsonb(prior)||jsonb_build_object('status','resolved_review');
 END LOOP;
 RETURN jsonb_build_object('status','no_safe_slot_review');
END $fn$;
REVOKE ALL ON FUNCTION ace_shared_schedule_fixture.resolve_slot(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_shared_schedule_fixture.resolve_slot(text,text) TO ace_cutover_ace,ace_cutover_legacy;
-- A bounded, explicitly authorized batch. All changes are applied or rolled back together.
CREATE TABLE ace_shared_schedule_fixture.batch_receipts(
 batch_key text PRIMARY KEY, plan jsonb NOT NULL, report jsonb NOT NULL
);
CREATE FUNCTION ace_shared_schedule_fixture.apply_round_plan(p_key text,p_plan jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_shared_schedule_fixture AS $fn$
DECLARE prior ace_shared_schedule_fixture.batch_receipts%ROWTYPE; item jsonb; m ace_shared_schedule_fixture.inventory%ROWTYPE; policy ace_shared_schedule_fixture.phase_policy%ROWTYPE; n int; result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(91029001);
 IF session_user<>'ace_review_worker' THEN RAISE EXCEPTION 'coordinator required'; END IF;
 IF p_key IS NULL OR length(p_key) NOT BETWEEN 1 AND 120 OR jsonb_typeof(p_plan) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid round plan'; END IF;
 n:=jsonb_array_length(p_plan);
 IF n NOT BETWEEN 1 AND 32 THEN RAISE EXCEPTION 'invalid round plan size'; END IF;
 SELECT * INTO prior FROM ace_shared_schedule_fixture.batch_receipts WHERE batch_key=p_key;
 IF FOUND THEN
  IF prior.plan IS DISTINCT FROM p_plan THEN RAISE EXCEPTION 'conflicting round plan retry'; END IF;
  RETURN prior.report||jsonb_build_object('status','already_applied_review');
 END IF;
 IF (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p_plan) x)<>n THEN RAISE EXCEPTION 'duplicate or missing plan match'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_plan) LOOP
  SELECT * INTO STRICT m FROM ace_shared_schedule_fixture.inventory WHERE id=item->>'id' FOR UPDATE;
  SELECT * INTO STRICT policy FROM ace_shared_schedule_fixture.phase_policy WHERE match_id=m.id;
  IF m.owner NOT IN ('ace','legacy') OR m.status<>'scheduled' OR m.revision IS DISTINCT FROM (item->>'revision')::bigint OR m.owner IS DISTINCT FROM item->>'owner' OR (item->>'second')::bigint IS NULL OR (item->>'court')::int IS NULL THEN RAISE EXCEPTION 'invalid round plan ownership or revision'; END IF;
  IF (item->>'second')::bigint<m.start_second OR (item->>'second')::bigint/86400 NOT BETWEEN policy.first_day AND policy.last_day OR (item->>'second')::bigint%86400 NOT BETWEEN 36000 AND 77400 OR (item->>'second')::bigint%1800<>0 OR (item->>'court')::int NOT BETWEEN 1 AND policy.court_count THEN RAISE EXCEPTION 'round plan outside phase policy'; END IF;
  UPDATE ace_shared_schedule_fixture.inventory SET start_second=(item->>'second')::bigint,court=(item->>'court')::int,revision=revision+1 WHERE id=m.id;
 END LOOP;
 -- Validate the final state, not the transient order of the proposed changes.
 IF EXISTS(SELECT 1 FROM ace_shared_schedule_fixture.feeders f JOIN ace_shared_schedule_fixture.inventory a ON a.id=f.feeder_id JOIN ace_shared_schedule_fixture.inventory b ON b.id=f.downstream_id WHERE (a.id IN(SELECT x->>'id' FROM jsonb_array_elements(p_plan) x) OR b.id IN(SELECT x->>'id' FROM jsonb_array_elements(p_plan) x)) AND b.start_second<coalesce(a.actual_end_second,a.start_second+a.duration_minutes*60)+3600) THEN RAISE EXCEPTION 'round plan feeder conflict'; END IF;
 IF EXISTS(SELECT 1 FROM ace_shared_schedule_fixture.inventory a JOIN ace_shared_schedule_fixture.inventory b ON a.id<>b.id WHERE a.id IN(SELECT x->>'id' FROM jsonb_array_elements(p_plan) x) AND (
 (a.venue=b.venue AND a.court=b.court AND a.start_second<coalesce(b.actual_end_second,b.start_second+b.duration_minutes*60)+900 AND b.start_second<a.start_second+a.duration_minutes*60+900)
 OR ((b.player1 IN(a.player1,a.player2) OR b.player2 IN(a.player1,a.player2)) AND a.start_second<coalesce(b.actual_end_second,b.start_second+b.duration_minutes*60)+3600 AND b.start_second<a.start_second+a.duration_minutes*60+3600))) THEN RAISE EXCEPTION 'round plan resource conflict'; END IF;
 result:=jsonb_build_object('status','applied_review','count',n,'batch_key',p_key,'production_ready',false);
 INSERT INTO ace_shared_schedule_fixture.batch_receipts VALUES(p_key,p_plan,result);
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION ace_shared_schedule_fixture.apply_round_plan(text,jsonb) FROM PUBLIC;
GRANT USAGE ON SCHEMA ace_shared_schedule_fixture TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_shared_schedule_fixture.apply_round_plan(text,jsonb) TO ace_review_worker;
COMMIT;
