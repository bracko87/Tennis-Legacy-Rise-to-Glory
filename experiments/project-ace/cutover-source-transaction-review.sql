-- Disposable review only. Simulated source mirror, not official database integration.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.source_contracts (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.protected_competitions(competition_id),
 contract jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_slots (
 match_id text PRIMARY KEY,
 competition_id text NOT NULL REFERENCES ace_cutover_review.source_contracts(competition_id),
 round_number integer NOT NULL CHECK(round_number>0),
 match_number integer NOT NULL CHECK(match_number>0),
 slot jsonb NOT NULL,
 feeder1 text REFERENCES ace_cutover_review.source_slots(match_id),
 feeder2 text REFERENCES ace_cutover_review.source_slots(match_id),
 UNIQUE(competition_id,round_number,match_number)
);
CREATE TABLE ace_cutover_review.source_observations (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_slots(match_id),
 revision bigint NOT NULL DEFAULT 0,
 payload jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_admissions (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_slots(match_id),
 source_revision bigint NOT NULL,
 observation jsonb NOT NULL,
 owner text NOT NULL CHECK(owner IN ('ace','legacy'))
);
GRANT SELECT ON ace_cutover_review.source_contracts,ace_cutover_review.source_slots,ace_cutover_review.source_observations,ace_cutover_review.source_admissions TO ace_review_worker;
-- Independent structural validation of normalized frozen contract, not trust in hash.
CREATE FUNCTION ace_cutover_review.import_source_contract(p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE comp text:=p->>'competition_id'; size int; rounds int; rr int; nn int; s jsonb; a text; b text; prior jsonb;
BEGIN
 IF p->>'schema' IS DISTINCT FROM 'ace-frozen-source-admission-v1' OR comp IS NULL OR comp='' OR coalesce(p->>'sha256','') !~ '^[a-f0-9]{64}$' OR jsonb_typeof(p->'matches') IS DISTINCT FROM 'array' OR jsonb_typeof(p->'draw_size') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'invalid source contract'; END IF;
 size:=(p->>'draw_size')::int;
 IF size NOT IN (8,16,32,64,128) OR jsonb_array_length(p->'matches')<>size-1 OR (SELECT count(DISTINCT x->>'match_id') FROM jsonb_array_elements(p->'matches') x)<>size-1 THEN RAISE EXCEPTION 'invalid source inventory'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(comp,91023));
 SELECT contract INTO prior FROM ace_cutover_review.source_contracts WHERE competition_id=comp;
 IF FOUND THEN IF prior IS DISTINCT FROM p THEN RAISE EXCEPTION 'conflicting source contract'; END IF; RETURN 'already_imported'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=comp) THEN RAISE EXCEPTION 'source contract must precede protection'; END IF;
 PERFORM ace_cutover_review.register_competition(comp);
 INSERT INTO ace_cutover_review.source_contracts VALUES(comp,p);
 rounds:=log(2,size)::int;
 FOR rr IN 1..rounds LOOP
  FOR nn IN 1..(size/power(2,rr)::int) LOOP
   SELECT x INTO STRICT s FROM jsonb_array_elements(p->'matches') x WHERE x->'round_number'=to_jsonb(rr) AND x->'match_number'=to_jsonb(nn);
   IF s->>'competition_id' IS DISTINCT FROM comp OR s->>'draw_type' IS DISTINCT FROM 'main_draw' OR s->>'match_id'='' OR NOT(s ?& ARRAY['player1_id','player2_id','feeder1','feeder2']) OR
    coalesce((s->>'scheduled_season_week')::int,0) NOT BETWEEN 1 AND 53 OR coalesce((s->>'scheduled_day')::int,0) NOT BETWEEN 1 AND 7 OR coalesce((s->>'scheduled_start_minute')::int,-1) NOT BETWEEN 0 AND 1439 OR coalesce((s->>'court_number')::int,0)<1 THEN RAISE EXCEPTION 'invalid source slot'; END IF;
   IF rr=1 THEN
    IF s->>'player1_id' IS NULL OR s->>'player2_id' IS NULL OR s->>'player1_id'='' OR s->>'player2_id'='' OR s->>'player1_id'=s->>'player2_id' OR s->>'feeder1' IS NOT NULL OR s->>'feeder2' IS NOT NULL OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots z WHERE z.competition_id=comp AND (z.slot->>'player1_id' IN(s->>'player1_id',s->>'player2_id') OR z.slot->>'player2_id' IN(s->>'player1_id',s->>'player2_id'))) THEN RAISE EXCEPTION 'invalid initial participants'; END IF;
   ELSE
    SELECT match_id INTO STRICT a FROM ace_cutover_review.source_slots WHERE competition_id=comp AND round_number=rr-1 AND match_number=2*nn-1;
    SELECT match_id INTO STRICT b FROM ace_cutover_review.source_slots WHERE competition_id=comp AND round_number=rr-1 AND match_number=2*nn;
    IF s->>'player1_id' IS NOT NULL OR s->>'player2_id' IS NOT NULL OR s->>'feeder1' IS DISTINCT FROM a OR s->>'feeder2' IS DISTINCT FROM b THEN RAISE EXCEPTION 'invalid source feeders'; END IF;
   END IF;
   IF EXISTS(SELECT 1 FROM ace_cutover_review.matches WHERE id=s->>'match_id') THEN RAISE EXCEPTION 'source match identity already occupied'; END IF;
   INSERT INTO ace_cutover_review.source_slots VALUES(s->>'match_id',comp,rr,nn,s,s->>'feeder1',s->>'feeder2');
   INSERT INTO ace_cutover_review.source_observations(match_id,payload) VALUES(s->>'match_id',jsonb_build_object('player1_id',s->>'player1_id','player2_id',s->>'player2_id','status','scheduled','simulation','none','started',false,'winner_id',NULL));
  END LOOP;
 END LOOP;
 RETURN 'imported';
END $$;
-- Controller is a simulated authoritative source. Observation update is CAS.
CREATE FUNCTION ace_cutover_review.observe_source(p_id text,p_expected bigint,p jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE o ace_cutover_review.source_observations%ROWTYPE; s ace_cutover_review.source_slots%ROWTYPE;
BEGIN
 SELECT * INTO STRICT s FROM ace_cutover_review.source_slots WHERE match_id=p_id;
 SELECT * INTO STRICT o FROM ace_cutover_review.source_observations WHERE match_id=p_id FOR UPDATE;
 IF o.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'stale source observation'; END IF;
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR NOT(p ?& ARRAY['player1_id','player2_id','status','simulation','started','winner_id']) OR coalesce(p->>'status','') NOT IN ('scheduled','in_progress','completed','walkover','bye','cancelled') OR coalesce(p->>'simulation','') NOT IN ('none','prepared','live','completed') OR jsonb_typeof(p->'started') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'invalid source observation'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=p_id) THEN RAISE EXCEPTION 'source already admitted; owner path required'; END IF;
 IF s.round_number=1 AND (p->>'player1_id' IS DISTINCT FROM s.slot->>'player1_id' OR p->>'player2_id' IS DISTINCT FROM s.slot->>'player2_id') THEN RAISE EXCEPTION 'source participants changed'; END IF;
 IF o.payload=p THEN RETURN o.revision; END IF;
 UPDATE ace_cutover_review.source_observations SET revision=revision+1,payload=p WHERE match_id=p_id RETURNING revision INTO o.revision;
 RETURN o.revision;
END $$;
-- No direct fixture seed for an imported source competition. Admission must first
-- create the exact evidence in the same transaction, then seed/bind/claim.
CREATE FUNCTION ace_cutover_review.guard_source_seed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_contracts WHERE competition_id=NEW.competition) OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots WHERE match_id=NEW.id) THEN
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.source_admissions a ON a.match_id=s.match_id WHERE s.match_id=NEW.id AND s.competition_id=NEW.competition AND a.observation->>'player1_id'=NEW.player1 AND a.observation->>'player2_id'=NEW.player2 AND NEW.status='scheduled' AND NOT NEW.started AND NEW.legacy_simulation='none' AND NEW.scope='singles' AND NEW.eligible AND NEW.owner IS NULL) THEN RAISE EXCEPTION 'dedicated source admission required'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER z_source_seed BEFORE INSERT ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_source_seed();
CREATE FUNCTION ace_cutover_review.admit_source(p_id text,p_expected bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE s ace_cutover_review.source_slots%ROWTYPE; o ace_cutover_review.source_observations%ROWTYPE; prior ace_cutover_review.source_admissions%ROWTYPE; policy ace_cutover_review.policy%ROWTYPE; engine text:=ace_cutover_review.actor(); chosen text; p1 text; p2 text; result jsonb; m ace_cutover_review.matches%ROWTYPE;
BEGIN
 IF engine IS NULL THEN RAISE EXCEPTION 'invalid engine'; END IF;
 SELECT * INTO STRICT policy FROM ace_cutover_review.policy WHERE singleton FOR SHARE;
 SELECT * INTO STRICT s FROM ace_cutover_review.source_slots WHERE match_id=p_id;
 PERFORM pg_advisory_xact_lock(hashtextextended(s.competition_id,91023));
 SELECT * INTO STRICT o FROM ace_cutover_review.source_observations WHERE match_id=p_id FOR UPDATE;
 IF o.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'stale source observation'; END IF;
 SELECT * INTO prior FROM ace_cutover_review.source_admissions WHERE match_id=p_id;
 IF FOUND THEN
  SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id;
  IF m.owner IS DISTINCT FROM prior.owner THEN RAISE EXCEPTION 'source ownership mismatch'; END IF;
  RETURN jsonb_build_object('status',CASE WHEN engine=prior.owner THEN 'already_admitted' ELSE 'wrong_engine' END,'owner',prior.owner,'revision',m.revision);
 END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.cancellations WHERE competition_id=s.competition_id) THEN RAISE EXCEPTION 'competition cancelled'; END IF;
 IF o.payload->>'status'<>'scheduled' OR o.payload->>'simulation'<>'none' OR o.payload->'started' IS DISTINCT FROM 'false'::jsonb OR o.payload->>'winner_id' IS NOT NULL THEN RETURN jsonb_build_object('status','existing_source_state'); END IF;
 chosen:=CASE WHEN policy.enabled AND s.competition_id=ANY(policy.competitions) THEN 'ace' ELSE 'legacy' END;
 IF engine<>chosen THEN RETURN jsonb_build_object('status','wrong_engine','owner',chosen); END IF;
 p1:=o.payload->>'player1_id';p2:=o.payload->>'player2_id';
 IF p1 IS NULL OR p2 IS NULL OR p1=p2 THEN RETURN jsonb_build_object('status','participants_pending'); END IF;
 IF s.round_number>1 THEN
  IF NOT ace_cutover_review.feeder_winner(s.feeder1,s.competition_id,p1) OR NOT ace_cutover_review.feeder_winner(s.feeder2,s.competition_id,p2) THEN RETURN jsonb_build_object('status','feeder_receipts_pending_or_mismatch'); END IF;
  -- Require owned predecessor records, not just claimed source winners.
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=s.feeder1) OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=s.feeder2) THEN RAISE EXCEPTION 'missing source feeder admission'; END IF;
 END IF;
 INSERT INTO ace_cutover_review.source_admissions VALUES(p_id,o.revision,o.payload,chosen);
 PERFORM ace_cutover_review.seed_match(p_id,s.competition_id,'singles',true,'scheduled','none',false,p1,p2);
 PERFORM ace_cutover_review.bind_feeders(p_id,s.feeder1,s.feeder2);
 result:=ace_cutover_review.claim(p_id);
 IF result->>'status' IS DISTINCT FROM 'claimed' OR result->>'owner' IS DISTINCT FROM chosen THEN RAISE EXCEPTION 'atomic source claim failed'; END IF;
 RETURN jsonb_build_object('status','admitted','owner',chosen,'revision',result->'revision');
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.import_source_contract(jsonb),ace_cutover_review.observe_source(text,bigint,jsonb),ace_cutover_review.guard_source_seed(),ace_cutover_review.admit_source(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.import_source_contract(jsonb),ace_cutover_review.observe_source(text,bigint,jsonb) TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_cutover_review.admit_source(text,bigint) TO ace_cutover_ace,ace_cutover_legacy;
COMMIT;
