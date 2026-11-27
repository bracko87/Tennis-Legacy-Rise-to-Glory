-- Experimental projection only; install inside disposable CI after normal schemas.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' OR NOT EXISTS(SELECT 1 FROM ace_migration_fixture.guard WHERE marker='ace-disposable-ci-v025') THEN RAISE EXCEPTION 'disposable review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.schedule_revisions(
 match_id text NOT NULL REFERENCES ace_cutover_review.source_slots(match_id),
 revision bigint NOT NULL CHECK(revision>0),
 previous_slot jsonb NOT NULL, revised_slot jsonb NOT NULL,
 source_id text NOT NULL, attempt_key text NOT NULL,
 PRIMARY KEY(match_id,revision), UNIQUE(source_id,match_id,attempt_key),
 FOREIGN KEY(source_id,match_id,attempt_key) REFERENCES ace_cutover_review.followup_attempts(source_id,target_id,attempt_key)
);
-- Explicit synthetic policy bounds, not inferred from the number of booked courts.
CREATE TABLE ace_cutover_review.schedule_phase_policy(
 competition_id text NOT NULL REFERENCES ace_cutover_review.source_contracts(competition_id),
 phase text NOT NULL CHECK(phase IN ('main_draw','qualification')),
 first_week integer NOT NULL CHECK(first_week BETWEEN 1 AND 52),
 last_week integer NOT NULL CHECK(last_week BETWEEN first_week AND 52),
 court_count integer NOT NULL CHECK(court_count BETWEEN 1 AND 100),
 PRIMARY KEY(competition_id,phase)
);
CREATE FUNCTION ace_cutover_review.bind_schedule_phase(p_comp text,p_phase text,p_first int,p_last int,p_courts int) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE old ace_cutover_review.schedule_phase_policy%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 SELECT * INTO old FROM ace_cutover_review.schedule_phase_policy WHERE competition_id=p_comp AND phase=p_phase;
 IF FOUND THEN
  IF ROW(old.first_week,old.last_week,old.court_count) IS DISTINCT FROM ROW(p_first,p_last,p_courts) THEN RAISE EXCEPTION 'conflicting phase policy'; END IF;
  RETURN 'already_bound';
 END IF;
 IF p_first IS NULL OR p_last IS NULL OR p_courts IS NULL OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots WHERE competition_id=p_comp AND slot->>'draw_type'=p_phase) OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots WHERE competition_id=p_comp AND slot->>'draw_type'=p_phase AND ((slot->>'scheduled_season_week')::int NOT BETWEEN p_first AND p_last OR (slot->>'court_number')::int NOT BETWEEN 1 AND p_courts)) THEN RAISE EXCEPTION 'invalid phase inventory'; END IF;
 INSERT INTO ace_cutover_review.schedule_phase_policy VALUES(p_comp,p_phase,p_first,p_last,p_courts);
 RETURN 'bound_review';
END $$;
CREATE FUNCTION ace_cutover_review.validate_schedule_candidate(p_id text,p_week int,p_day int,p_min int,p_court int) RETURNS bigint
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE s ace_cutover_review.source_slots%ROWTYPE; pol ace_cutover_review.schedule_phase_policy%ROWTYPE; season int;
BEGIN
 SELECT * INTO STRICT s FROM ace_cutover_review.source_slots WHERE match_id=p_id;
 SELECT * INTO STRICT pol FROM ace_cutover_review.schedule_phase_policy WHERE competition_id=s.competition_id AND phase=s.slot->>'draw_type';
 IF p_week IS NULL OR p_day IS NULL OR p_min IS NULL OR p_court IS NULL OR p_week NOT BETWEEN pol.first_week AND pol.last_week OR p_day NOT BETWEEN 1 AND 7 OR p_min NOT BETWEEN 600 AND 1290 OR p_court NOT BETWEEN 1 AND pol.court_count THEN RAISE EXCEPTION 'candidate outside phase or venue capacity'; END IF;
 SELECT (contract->>'season_number')::int INTO STRICT season FROM ace_cutover_review.source_contracts WHERE competition_id=s.competition_id;
 RETURN ((season-1)::bigint*366+2+(p_week-1)*7+p_day-1)*86400+p_min*60;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.bind_schedule_phase(text,text,int,int,int),ace_cutover_review.validate_schedule_candidate(text,int,int,int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.bind_schedule_phase(text,text,int,int,int),ace_cutover_review.validate_schedule_candidate(text,int,int,int,int) TO ace_review_worker;
GRANT SELECT ON ace_cutover_review.schedule_phase_policy TO ace_review_worker;

CREATE FUNCTION ace_cutover_review.effective_schedule(p_id text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
 SELECT coalesce((SELECT revised_slot FROM ace_cutover_review.schedule_revisions WHERE match_id=p_id ORDER BY revision DESC LIMIT 1), (SELECT slot FROM ace_cutover_review.source_slots WHERE match_id=p_id))
$$;
-- Deliberately narrow first adapter: same-day delay, same court. Moving to
-- another day/court needs authoritative phase and venue-capacity evidence.

-- Explicit, immutable review estimates. Unknown matches retain the conservative bound.
CREATE TABLE ace_cutover_review.schedule_duration_evidence(
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_slots(match_id),
 estimate_minutes integer NOT NULL CHECK(estimate_minutes BETWEEN 60 AND 420),
 evidence_key text NOT NULL CHECK(length(btrim(evidence_key)) BETWEEN 1 AND 120)
);
CREATE FUNCTION ace_cutover_review.bind_schedule_duration(p_id text,p_minutes int,p_key text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $duration$
DECLARE prior ace_cutover_review.schedule_duration_evidence%ROWTYPE;
BEGIN
 PERFORM pg_advisory_xact_lock(91026001);
 SELECT * INTO prior FROM ace_cutover_review.schedule_duration_evidence WHERE match_id=p_id;
 IF FOUND THEN
  IF ROW(prior.estimate_minutes,prior.evidence_key) IS DISTINCT FROM ROW(p_minutes,p_key) THEN RAISE EXCEPTION 'conflicting duration evidence'; END IF;
  RETURN 'already_bound';
 END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.matches WHERE id=p_id AND status<>'scheduled') OR EXISTS(SELECT 1 FROM ace_cutover_review.schedule_revisions WHERE match_id=p_id) THEN RAISE EXCEPTION 'duration evidence too late'; END IF;
 INSERT INTO ace_cutover_review.schedule_duration_evidence VALUES(p_id,p_minutes,p_key);
 RETURN 'bound_review';
END $duration$;
CREATE FUNCTION ace_cutover_review.projected_schedule_duration(p_id text) RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $duration$
 SELECT coalesce((SELECT estimate_minutes FROM ace_cutover_review.schedule_duration_evidence WHERE match_id=p_id),420)
$duration$;
CREATE FUNCTION ace_cutover_review.projected_overlap(p_a bigint,p_a_minutes integer,p_b bigint,p_b_minutes integer,p_buffer integer) RETURNS boolean
LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER AS $duration$
 SELECT p_a<p_b+(p_b_minutes+p_buffer)::bigint*60 AND p_b<p_a+(p_a_minutes+p_buffer)::bigint*60
$duration$;
REVOKE ALL ON FUNCTION ace_cutover_review.bind_schedule_duration(text,int,text),ace_cutover_review.projected_schedule_duration(text),ace_cutover_review.projected_overlap(bigint,int,bigint,int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.bind_schedule_duration(text,int,text),ace_cutover_review.projected_schedule_duration(text),ace_cutover_review.projected_overlap(bigint,int,bigint,int,int) TO ace_review_worker;
GRANT SELECT ON ace_cutover_review.schedule_duration_evidence TO ace_review_worker;

CREATE FUNCTION ace_cutover_review.apply_followup_slot(p_source text,p_target text,p_key text,p_expected bigint,p_week integer,p_day integer,p_minute integer,p_court integer) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; j ace_cutover_review.followup_jobs%ROWTYPE; old jsonb; prior ace_cutover_review.schedule_revisions%ROWTYPE; rev bigint; c ace_cutover_review.source_clock%ROWTYPE; due bigint; season int; venue text; court_key text; old_due bigint; revised jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_target FOR UPDATE;
 SELECT * INTO STRICT j FROM ace_cutover_review.followup_jobs WHERE source_id=p_source AND target_id=p_target FOR UPDATE;
 SELECT * INTO prior FROM ace_cutover_review.schedule_revisions WHERE source_id=p_source AND match_id=p_target AND attempt_key=p_key;
 IF FOUND THEN
  IF prior.revision<>p_expected+1 OR ROW((prior.revised_slot->>'scheduled_season_week')::int,(prior.revised_slot->>'scheduled_day')::int,(prior.revised_slot->>'scheduled_start_minute')::int,(prior.revised_slot->>'court_number')::int) IS DISTINCT FROM ROW(p_week,p_day,p_minute,p_court) THEN RAISE EXCEPTION 'conflicting schedule retry'; END IF;
  RETURN 'already_applied_review';
 END IF;
 IF m.status<>'scheduled' OR m.started OR m.revision<>j.target_revision OR m.owner IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'stale or ineligible target'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_starts WHERE match_id=p_target) THEN RAISE EXCEPTION 'target already started'; END IF;
 SELECT coalesce(max(revision),0) INTO rev FROM ace_cutover_review.schedule_revisions WHERE match_id=p_target;
 IF rev IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'stale schedule revision'; END IF;
 old:=ace_cutover_review.effective_schedule(p_target);
 IF old IS NULL THEN RAISE EXCEPTION 'missing schedule'; END IF;
 SELECT * INTO STRICT c FROM ace_cutover_review.source_clock WHERE competition_id=m.competition FOR SHARE;
 SELECT (contract->>'season_number')::int INTO STRICT season FROM ace_cutover_review.source_contracts WHERE competition_id=m.competition;
 due:=ace_cutover_review.validate_schedule_candidate(p_target,p_week,p_day,p_minute,p_court);
 old_due:=((season-1)::bigint*366+2+((old->>'scheduled_season_week')::int-1)*7+(old->>'scheduled_day')::int-1)*86400+(old->>'scheduled_start_minute')::int*60;
 IF due<old_due OR (due=old_due AND p_court=(old->>'court_number')::int) THEN RAISE EXCEPTION 'not a forward schedule change'; END IF;
 SELECT venue_id INTO STRICT venue FROM ace_cutover_review.source_venues WHERE competition_id=m.competition;
 court_key:=jsonb_build_array(venue,p_court)::text;
 -- Serialize competing extended projections. Live admission still rechecks actual resources.
 PERFORM pg_advisory_xact_lock(91026001);
 IF EXISTS(SELECT 1 FROM ace_cutover_review.active_source_resources a WHERE (a.resource_kind='player' AND a.resource_key IN(m.player1,m.player2)) OR (a.resource_kind='court' AND a.resource_key=court_key)) THEN RAISE EXCEPTION 'active resource conflict'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_rest_history h WHERE h.resource_kind='court' AND h.resource_key=court_key AND due<h.ready_second) THEN RAISE EXCEPTION 'court recovery conflict'; END IF;
 -- Explicit estimates are directional; missing evidence retains 420 minutes.
 -- Actual start checks continue to enforce live resource and recovery safety.
 IF EXISTS(
 SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.source_contracts sc USING(competition_id)
 LEFT JOIN ace_cutover_review.matches x ON x.id=s.match_id
 LEFT JOIN ace_cutover_review.source_venues v ON v.competition_id=s.competition_id
 CROSS JOIN LATERAL (SELECT ace_cutover_review.effective_schedule(s.match_id) AS sl) q
 CROSS JOIN LATERAL (SELECT (( (sc.contract->>'season_number')::bigint-1)*366+2+((q.sl->>'scheduled_season_week')::int-1)*7+(q.sl->>'scheduled_day')::int-1)*86400+(q.sl->>'scheduled_start_minute')::int*60 AS at_second) z
 WHERE s.match_id<>p_target AND coalesce(x.status,'scheduled')='scheduled'
 AND ((v.venue_id=venue AND (q.sl->>'court_number')::int=p_court AND ace_cutover_review.projected_overlap(due,ace_cutover_review.projected_schedule_duration(p_target),z.at_second,ace_cutover_review.projected_schedule_duration(s.match_id),15))
 OR ((coalesce(x.player1,q.sl->>'player1_id') IN(m.player1,m.player2) OR coalesce(x.player2,q.sl->>'player2_id') IN(m.player1,m.player2)) AND (ace_cutover_review.projected_overlap(due,ace_cutover_review.projected_schedule_duration(p_target),z.at_second,ace_cutover_review.projected_schedule_duration(s.match_id),60) OR (s.competition_id<>m.competition AND z.at_second/86400=due/86400))))
 ) THEN RAISE EXCEPTION 'projected schedule conflict'; END IF;
 -- Do not silently move a feeder behind its downstream match.
 IF EXISTS(
 SELECT 1 FROM ace_cutover_review.source_slots nxt
 CROSS JOIN LATERAL (SELECT ace_cutover_review.effective_schedule(nxt.match_id) AS sl) q
 WHERE (nxt.feeder1=p_target OR nxt.feeder2=p_target)
 AND (((season-1)::bigint*366+2+((q.sl->>'scheduled_season_week')::int-1)*7+(q.sl->>'scheduled_day')::int-1)*86400+(q.sl->>'scheduled_start_minute')::int*60)<due+(ace_cutover_review.projected_schedule_duration(p_target)+60)::bigint*60
 ) THEN RAISE EXCEPTION 'downstream feeder schedule conflict'; END IF;
 revised:=old||jsonb_build_object('scheduled_season_week',p_week,'scheduled_day',p_day,'scheduled_start_minute',p_minute,'court_number',p_court);
 IF c.paused OR clock_timestamp()-c.captured_at>interval '60 seconds' OR due<=c.game_second+600 THEN RAISE EXCEPTION 'clock or delay not safe'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_rest_history h WHERE h.resource_kind='player' AND h.resource_key IN(m.player1,m.player2) AND (due<h.ready_second OR (h.competition_id<>m.competition AND h.start_second/86400=due/86400))) THEN RAISE EXCEPTION 'player recovery conflict'; END IF;
 IF ace_cutover_review.note_followup_attempt(p_source,p_target,p_key,'rescheduled')<>'recorded_review' THEN RAISE EXCEPTION 'unavailable attempt'; END IF;
 INSERT INTO ace_cutover_review.schedule_revisions VALUES(p_target,rev+1,old,revised,p_source,p_key);
 -- Force fresh readiness without changing lifecycle revisions (which are contiguous).
 UPDATE ace_cutover_review.source_readiness SET match_revision=-1 WHERE match_id=p_target;
 RETURN 'applied_review';
END $$;
CREATE FUNCTION ace_cutover_review.apply_followup_delay(p_source text,p_target text,p_key text,p_expected bigint,p_minute integer) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $delay$
DECLARE sl jsonb; prior ace_cutover_review.schedule_revisions%ROWTYPE;
BEGIN
 -- Match lock precedes effective slot read, as in the extended path.
 PERFORM 1 FROM ace_cutover_review.matches WHERE id=p_target FOR UPDATE;
 SELECT * INTO prior FROM ace_cutover_review.schedule_revisions WHERE source_id=p_source AND match_id=p_target AND attempt_key=p_key;
 IF FOUND THEN
  sl:=prior.previous_slot;
 ELSE
  sl:=ace_cutover_review.effective_schedule(p_target);
 END IF;
 IF sl IS NULL OR p_minute IS NULL OR p_minute<=(sl->>'scheduled_start_minute')::int THEN RAISE EXCEPTION 'invalid same-day delay'; END IF;
 RETURN ace_cutover_review.apply_followup_slot(p_source,p_target,p_key,p_expected,(sl->>'scheduled_season_week')::int,(sl->>'scheduled_day')::int,p_minute,(sl->>'court_number')::int);
END $delay$;
REVOKE ALL ON FUNCTION ace_cutover_review.apply_followup_slot(text,text,text,bigint,int,int,int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.apply_followup_slot(text,text,text,bigint,int,int,int,int) TO ace_review_worker;
-- Discovery is explicit replay of committed review evidence; no production trigger.
CREATE TABLE ace_cutover_review.followup_discovery(
 source_id text PRIMARY KEY REFERENCES ace_cutover_review.effects(match_id),
 report jsonb NOT NULL
);
CREATE FUNCTION ace_cutover_review.discover_followups(p_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $discover$
DECLARE m ace_cutover_review.matches%ROWTYPE; e ace_cutover_review.effects%ROWTYPE; st ace_cutover_review.source_starts%ROWTYPE; sl jsonb; season int; actual int; estimate int; original_start bigint; ending bigint; r record; rows jsonb:='[]'; report jsonb; outcome text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_id,91027));
 SELECT d.report INTO report FROM ace_cutover_review.followup_discovery d WHERE source_id=p_id;
 IF FOUND THEN RETURN report; END IF;
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id;
 SELECT * INTO STRICT e FROM ace_cutover_review.effects WHERE match_id=p_id;
 IF m.status<>'completed' OR NOT m.started OR m.owner IS DISTINCT FROM 'ace' OR e.engine<>'ace' THEN RAISE EXCEPTION 'played Ace completion required'; END IF;
 SELECT * INTO STRICT st FROM ace_cutover_review.source_starts WHERE match_id=p_id;
 SELECT (contract->>'season_number')::int INTO STRICT season FROM ace_cutover_review.source_contracts WHERE competition_id=m.competition;
 sl:=ace_cutover_review.effective_schedule(p_id);
 IF sl IS NULL OR jsonb_typeof(e.receipt->'actual_duration_minutes') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'missing duration evidence'; END IF;
 actual:=(e.receipt->>'actual_duration_minutes')::int;
 IF actual NOT BETWEEN 60 AND 420 THEN RAISE EXCEPTION 'invalid played duration'; END IF;
 SELECT coalesce((SELECT estimate_minutes FROM ace_cutover_review.schedule_duration_evidence WHERE match_id=p_id),150) INTO estimate;
 original_start:=((season-1)::bigint*366+2+((sl->>'scheduled_season_week')::int-1)*7+(sl->>'scheduled_day')::int-1)*86400+(sl->>'scheduled_start_minute')::int*60;
 SELECT max(end_second) INTO ending FROM ace_cutover_review.source_rest_history WHERE match_id=p_id AND resource_kind='player';
 IF ending IS NULL OR ending<st.game_second+actual::bigint*60 OR (SELECT count(*) FROM ace_cutover_review.source_rest_history WHERE match_id=p_id AND resource_kind='player')<>2 THEN RAISE EXCEPTION 'incomplete recovery evidence'; END IF;
 IF actual>estimate THEN
 FOR r IN
 SELECT s.match_id,x.revision,x.owner,x.status,
 (( (sc.contract->>'season_number')::bigint-1)*366+2+((q.sl->>'scheduled_season_week')::int-1)*7+(q.sl->>'scheduled_day')::int-1)*86400+(q.sl->>'scheduled_start_minute')::int*60 AS due
 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.source_contracts sc USING(competition_id)
 LEFT JOIN ace_cutover_review.matches x ON x.id=s.match_id
 LEFT JOIN ace_cutover_review.source_observations o ON o.match_id=s.match_id
 CROSS JOIN LATERAL (SELECT ace_cutover_review.effective_schedule(s.match_id) AS sl) q
 WHERE s.match_id<>p_id AND coalesce(x.status,o.payload->>'status')='scheduled'
 AND (coalesce(x.player1,o.payload->>'player1_id') IN(m.player1,m.player2) OR coalesce(x.player2,o.payload->>'player2_id') IN(m.player1,m.player2))
 ORDER BY due,s.match_id
 LOOP
 IF r.due BETWEEN original_start AND ending+3600 THEN
  IF r.owner='ace' THEN
   BEGIN
    outcome:=ace_cutover_review.stage_followup(p_id,r.match_id,r.revision);
   EXCEPTION WHEN OTHERS THEN outcome:='stage_requires_retry'; END;
  ELSE outcome:='external_or_unadmitted_review'; END IF;
  rows:=rows||jsonb_build_array(jsonb_build_object('match_id',r.match_id,'due_second',r.due,'outcome',outcome));
 END IF;
 END LOOP;
 END IF;
 report:=jsonb_build_object('source_id',p_id,'actual_minutes',actual,'estimate_minutes',estimate,'window_start',original_start,'window_end',ending+3600,'candidates',rows,'review_only',true,'production_ready',false);
 -- Do not freeze transient staging failures; replay can retry.
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(rows) x WHERE x->>'outcome'='stage_requires_retry') THEN
 INSERT INTO ace_cutover_review.followup_discovery VALUES(p_id,report);
 END IF;
 RETURN report;
END $discover$;
REVOKE ALL ON FUNCTION ace_cutover_review.discover_followups(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.discover_followups(text) TO ace_review_worker;
GRANT SELECT ON ace_cutover_review.followup_discovery TO ace_review_worker;

-- Transactional outbox: completion creates an obligation, discovery runs separately.
CREATE TABLE ace_cutover_review.followup_outbox(
 source_id text PRIMARY KEY REFERENCES ace_cutover_review.effects(match_id),
 attempts integer NOT NULL DEFAULT 0 CHECK(attempts>=0),
 state text NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','discovered','review_required')),
 last_error text,
 next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 report jsonb,
 CHECK((state='pending') OR report IS NOT NULL)
);
CREATE FUNCTION ace_cutover_review.enqueue_followup_completion() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $outbox$
BEGIN
 IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status='completed' AND NEW.started AND NEW.owner='ace'
 AND EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id)
 AND EXISTS(SELECT 1 FROM ace_cutover_review.source_starts WHERE match_id=NEW.id) THEN
 INSERT INTO ace_cutover_review.followup_outbox(source_id) VALUES(NEW.id) ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END $outbox$;
CREATE TRIGGER zz_followup_completion AFTER UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.enqueue_followup_completion();
CREATE FUNCTION ace_cutover_review.process_followup_outbox(p_id text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $outbox$
DECLARE j ace_cutover_review.followup_outbox%ROWTYPE; r jsonb; new_state text; err text;
BEGIN
 SELECT * INTO STRICT j FROM ace_cutover_review.followup_outbox WHERE source_id=p_id FOR UPDATE;
 IF j.state<>'pending' OR j.next_attempt_at>clock_timestamp() THEN RETURN jsonb_build_object('state',j.state,'attempts',j.attempts,'report',j.report); END IF;
 BEGIN
  r:=ace_cutover_review.discover_followups(p_id);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'candidates') x WHERE x->>'outcome'='stage_requires_retry') THEN
   new_state:='pending'; err:='staging requires retry';
  ELSIF EXISTS(SELECT 1 FROM jsonb_array_elements(r->'candidates') x WHERE x->>'outcome'='external_or_unadmitted_review') THEN
   new_state:='review_required';
  ELSE new_state:='discovered'; END IF;
 EXCEPTION WHEN OTHERS THEN
  new_state:='pending'; err:=SQLSTATE; r:=NULL;
 END;
 IF new_state='pending' AND j.attempts+1>=5 THEN
  new_state:='review_required';
  r:=coalesce(r,jsonb_build_object('source_id',p_id,'review_only',true))||jsonb_build_object('retry_exhausted',true,'error',err);
 END IF;
 UPDATE ace_cutover_review.followup_outbox SET attempts=attempts+1,state=new_state,last_error=err,report=r,next_attempt_at=clock_timestamp()+make_interval(secs=>least(300,5*power(2,least(j.attempts,6)))::int) WHERE source_id=p_id RETURNING * INTO j;
 RETURN jsonb_build_object('state',j.state,'attempts',j.attempts,'report',j.report);
END $outbox$;
REVOKE ALL ON FUNCTION ace_cutover_review.enqueue_followup_completion(),ace_cutover_review.process_followup_outbox(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.process_followup_outbox(text) TO ace_review_worker;
GRANT SELECT ON ace_cutover_review.followup_outbox TO ace_review_worker;

-- Polling entrypoint. Transaction locks release automatically on worker disconnect.
CREATE INDEX followup_outbox_pending_idx ON ace_cutover_review.followup_outbox(next_attempt_at,source_id) WHERE state='pending';
CREATE FUNCTION ace_cutover_review.drain_followup_outbox(p_limit integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $drain$
DECLARE item record; results jsonb:='[]'; r jsonb;
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'invalid batch limit'; END IF;
 -- Single drain per transaction; individual processors also lock their rows.
 IF NOT pg_try_advisory_xact_lock(91028001) THEN RETURN jsonb_build_object('status','busy_review','processed',0,'items',results); END IF;
 FOR item IN SELECT source_id FROM ace_cutover_review.followup_outbox WHERE state='pending' AND next_attempt_at<=clock_timestamp()
 ORDER BY next_attempt_at,source_id LIMIT p_limit FOR UPDATE SKIP LOCKED
 LOOP
  r:=ace_cutover_review.process_followup_outbox(item.source_id);
  results:=results||jsonb_build_array(jsonb_build_object('source_id',item.source_id,'result',r));
 END LOOP;
 RETURN jsonb_build_object('status','processed_review','processed',jsonb_array_length(results),'items',results);
END $drain$;
REVOKE ALL ON FUNCTION ace_cutover_review.drain_followup_outbox(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.drain_followup_outbox(integer) TO ace_review_worker;

CREATE OR REPLACE FUNCTION ace_cutover_review.start_source(p_id text,p_match_rev bigint,p_ready_rev bigint,p_clock_rev bigint) RETURNS text
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
 s.slot:=ace_cutover_review.effective_schedule(p_id);
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
CREATE OR REPLACE FUNCTION ace_cutover_review.reserve_source_resources() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE venue text; court int; r record;
BEGIN
 IF OLD.status IS NOT DISTINCT FROM NEW.status OR NEW.status<>'in_progress' OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) THEN RETURN NEW; END IF;
 SELECT venue_id INTO venue FROM ace_cutover_review.source_venues WHERE competition_id=NEW.competition;
 IF venue IS NULL THEN RAISE EXCEPTION 'physical venue binding required'; END IF;
 court:=(ace_cutover_review.effective_schedule(NEW.id)->>'court_number')::int;
 FOR r IN SELECT * FROM (VALUES ('player'::text,NEW.player1),('player'::text,NEW.player2),('court'::text,jsonb_build_array(venue,court)::text)) AS v(kind,key) ORDER BY kind COLLATE "C",key COLLATE "C" LOOP
  INSERT INTO ace_cutover_review.active_source_resources VALUES(r.kind,r.key,NEW.id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RAISE EXCEPTION 'source resource conflict: %',r.kind; END IF;
  INSERT INTO ace_cutover_review.source_resource_history VALUES(NEW.id,r.kind,r.key,NEW.revision,NULL);
 END LOOP;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.effective_schedule(text),ace_cutover_review.apply_followup_delay(text,text,text,bigint,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.effective_schedule(text),ace_cutover_review.apply_followup_delay(text,text,text,bigint,integer) TO ace_review_worker;
GRANT SELECT ON ace_cutover_review.schedule_revisions TO ace_review_worker;
COMMIT;
