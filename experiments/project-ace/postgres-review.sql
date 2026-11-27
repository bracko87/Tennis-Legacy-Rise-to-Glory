-- Disposable PostgreSQL review database only. NOT a Supabase migration.
BEGIN;
DO $$ BEGIN
 IF current_database() <> 'ace_review' THEN RAISE EXCEPTION 'Wrong database: isolated ace_review required'; END IF;
END $$;
CREATE SCHEMA ace_review;
REVOKE ALL ON SCHEMA ace_review FROM PUBLIC;
CREATE TABLE ace_review.worlds (
 id text PRIMARY KEY CHECK (id ~ '^[a-zA-Z0-9_-]{1,80}$'),
 revision bigint NOT NULL CHECK (revision >= 0),
 manifest jsonb NOT NULL CHECK (jsonb_typeof(manifest) = 'object'),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ace_review.matches (
 world_id text NOT NULL REFERENCES ace_review.worlds(id),
 ordinal integer NOT NULL CHECK (ordinal >= 0),
 match_id text NOT NULL,
 payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object' AND payload->>'id' = match_id),
 PRIMARY KEY(world_id,match_id), UNIQUE(world_id,ordinal)
);
CREATE TABLE ace_review.receipts (
 world_id text NOT NULL REFERENCES ace_review.worlds(id),
 ordinal integer NOT NULL CHECK (ordinal >= 0),
 match_id text NOT NULL,
 payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object' AND payload->>'matchId' = match_id),
 PRIMARY KEY(world_id,match_id), UNIQUE(world_id,ordinal),
 FOREIGN KEY(world_id,match_id) REFERENCES ace_review.matches(world_id,match_id)
);
CREATE TABLE ace_review.transactions (
 world_id text NOT NULL REFERENCES ace_review.worlds(id),
 ordinal integer NOT NULL CHECK (ordinal >= 0),
 transaction_key text NOT NULL,
 payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object' AND payload->>'key' = transaction_key),
 PRIMARY KEY(world_id,transaction_key), UNIQUE(world_id,ordinal)
);
-- The worker is trusted application code, not a browser/client identity.
-- No public/anon/authenticated grants and no SECURITY DEFINER functions.
ALTER TABLE ace_review.worlds ENABLE ROW LEVEL SECURITY;
ALTER TABLE ace_review.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE ace_review.receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ace_review.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY worker_world ON ace_review.worlds TO ace_review_worker USING (true) WITH CHECK (true);
CREATE POLICY worker_match ON ace_review.matches TO ace_review_worker USING (true) WITH CHECK (true);
CREATE POLICY worker_receipt ON ace_review.receipts TO ace_review_worker USING (true) WITH CHECK (true);
CREATE POLICY worker_tx ON ace_review.transactions TO ace_review_worker USING (true) WITH CHECK (true);
GRANT USAGE ON SCHEMA ace_review TO ace_review_worker;
GRANT SELECT,INSERT,UPDATE ON ace_review.worlds,ace_review.matches TO ace_review_worker;
GRANT SELECT,INSERT ON ace_review.receipts,ace_review.transactions TO ace_review_worker;
CREATE FUNCTION ace_review.load_world(p_id text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = pg_catalog, ace_review AS $$
 SELECT jsonb_build_object('revision',w.revision,'state',
 jsonb_set(jsonb_set(jsonb_set(w.manifest,'{draw,scheduler,jobs}',coalesce((SELECT jsonb_agg(m.payload ORDER BY m.ordinal) FROM ace_review.matches m WHERE m.world_id=w.id),'[]'::jsonb)),
 '{draw,scheduler,receipts}',coalesce((SELECT jsonb_agg(r.payload ORDER BY r.ordinal) FROM ace_review.receipts r WHERE r.world_id=w.id),'[]'::jsonb)),
 '{ledger,transactions}',coalesce((SELECT jsonb_agg(t.payload ORDER BY t.ordinal) FROM ace_review.transactions t WHERE t.world_id=w.id),'[]'::jsonb)))
 FROM ace_review.worlds w WHERE w.id=p_id
$$;
CREATE FUNCTION ace_review.commit_world(p_id text,p_expected bigint,p_state jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY INVOKER SET search_path = pg_catalog, ace_review AS $$
DECLARE v_rev bigint; v_manifest jsonb; v_jobs jsonb; v_receipts jsonb; v_tx jsonb;
BEGIN
 IF p_state->>'kind' IS DISTINCT FROM 'world' OR p_state->>'version' IS DISTINCT FROM '1' THEN RAISE EXCEPTION 'invalid world kind'; END IF;
 v_jobs:=p_state#>'{draw,scheduler,jobs}'; v_receipts:=p_state#>'{draw,scheduler,receipts}'; v_tx:=p_state#>'{ledger,transactions}';
 IF jsonb_typeof(v_jobs) IS DISTINCT FROM 'array' OR jsonb_typeof(v_receipts) IS DISTINCT FROM 'array' OR jsonb_typeof(v_tx) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid world arrays'; END IF;
 v_manifest:=jsonb_set(jsonb_set(jsonb_set(p_state,'{draw,scheduler,jobs}','[]'),'{draw,scheduler,receipts}','[]'),'{ledger,transactions}','[]');
 IF p_expected=-1 THEN
   INSERT INTO ace_review.worlds(id,revision,manifest) VALUES(p_id,0,v_manifest) ON CONFLICT DO NOTHING RETURNING revision INTO v_rev;
   IF NOT FOUND THEN RAISE EXCEPTION 'ACE_REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
 ELSE
   SELECT revision INTO v_rev FROM ace_review.worlds WHERE id=p_id FOR UPDATE;
   IF NOT FOUND OR v_rev IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'ACE_REVISION_CONFLICT' USING ERRCODE='40001'; END IF;
   UPDATE ace_review.worlds SET revision=revision+1,manifest=v_manifest,updated_at=clock_timestamp() WHERE id=p_id RETURNING revision INTO v_rev;
 END IF;
 -- Existing rows cannot be removed or moved; final jobs cannot change except lastNow.
 IF EXISTS(SELECT 1 FROM ace_review.matches m WHERE m.world_id=p_id AND
 NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_jobs) WITH ORDINALITY j(v,n) WHERE j.v->>'id'=m.match_id AND j.n-1=m.ordinal
 AND (m.payload->>'status'<>'completed' OR (m.payload#-'{fixture,lastNow}')=(j.v#-'{fixture,lastNow}')))) THEN RAISE EXCEPTION 'match history conflict'; END IF;
 INSERT INTO ace_review.matches(world_id,ordinal,match_id,payload)
 SELECT p_id,(n-1)::integer,v->>'id',v FROM jsonb_array_elements(v_jobs) WITH ORDINALITY j(v,n)
 ON CONFLICT(world_id,match_id) DO UPDATE SET payload=excluded.payload
 WHERE ace_review.matches.payload IS DISTINCT FROM excluded.payload;
 -- Receipts and money entries are append-only. A replay must be byte-equivalent in JSONB.
 IF EXISTS(SELECT 1 FROM ace_review.receipts r WHERE r.world_id=p_id AND NOT EXISTS(
 SELECT 1 FROM jsonb_array_elements(v_receipts) WITH ORDINALITY j(v,n) WHERE j.v->>'matchId'=r.match_id AND j.n-1=r.ordinal AND j.v=r.payload)) THEN RAISE EXCEPTION 'receipt history conflict'; END IF;
 INSERT INTO ace_review.receipts(world_id,ordinal,match_id,payload)
 SELECT p_id,(n-1)::integer,v->>'matchId',v FROM jsonb_array_elements(v_receipts) WITH ORDINALITY j(v,n)
 ON CONFLICT(world_id,match_id) DO NOTHING;
 IF EXISTS(SELECT 1 FROM ace_review.transactions t WHERE t.world_id=p_id AND NOT EXISTS(
 SELECT 1 FROM jsonb_array_elements(v_tx) WITH ORDINALITY j(v,n) WHERE j.v->>'key'=t.transaction_key AND j.n-1=t.ordinal AND j.v=t.payload)) THEN RAISE EXCEPTION 'transaction history conflict'; END IF;
 INSERT INTO ace_review.transactions(world_id,ordinal,transaction_key,payload)
 SELECT p_id,(n-1)::integer,v->>'key',v FROM jsonb_array_elements(v_tx) WITH ORDINALITY j(v,n)
 ON CONFLICT(world_id,transaction_key) DO NOTHING;
 IF (SELECT count(*) FROM ace_review.receipts WHERE world_id=p_id)<>jsonb_array_length(v_receipts) OR
 (SELECT count(*) FROM ace_review.transactions WHERE world_id=p_id)<>jsonb_array_length(v_tx) THEN RAISE EXCEPTION 'duplicate history entries'; END IF;
 RETURN v_rev;
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ace_review FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_review.load_world(text),ace_review.commit_world(text,bigint,jsonb) TO ace_review_worker;
-- Review-only settlement staging. No public game tables touched.
CREATE TABLE ace_review.settlement_exports (
 competition_id text PRIMARY KEY,
 payload jsonb NOT NULL CHECK ((payload->>'schema'='ace-settlement-review-v1' AND payload->>'review_only'='true' AND payload->>'production_ready'='false' AND payload->>'competition_id'=competition_id) IS TRUE)
);
ALTER TABLE ace_review.settlement_exports ENABLE ROW LEVEL SECURITY;
CREATE POLICY worker_export ON ace_review.settlement_exports TO ace_review_worker USING (true) WITH CHECK (true);
GRANT SELECT,INSERT ON ace_review.settlement_exports TO ace_review_worker;
CREATE FUNCTION ace_review.stage_settlement(p_payload jsonb) RETURNS text
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,ace_review AS $stage$
DECLARE v_id text:=p_payload->>'competition_id'; v_prior jsonb;
BEGIN
 IF v_id IS NULL OR v_id='' OR jsonb_typeof(p_payload->'matches') IS DISTINCT FROM 'array' OR jsonb_array_length(p_payload->'matches')=0 THEN RAISE EXCEPTION 'invalid settlement export'; END IF;
 INSERT INTO ace_review.settlement_exports(competition_id,payload) VALUES(v_id,p_payload) ON CONFLICT DO NOTHING;
 IF FOUND THEN RETURN 'staged'; END IF;
 SELECT payload INTO v_prior FROM ace_review.settlement_exports WHERE competition_id=v_id;
 IF v_prior IS DISTINCT FROM p_payload THEN RAISE EXCEPTION 'settlement export conflict'; END IF;
 RETURN 'already_staged';
END $stage$;
REVOKE ALL ON FUNCTION ace_review.stage_settlement(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_review.stage_settlement(jsonb) TO ace_review_worker;
-- Isolated rehearsal of an exclusive engine ownership and atomic finalization contract.
-- Never connected to public.tournament_matches or either production engine.
CREATE TABLE ace_review.finalization_claims (
 match_id text PRIMARY KEY,
 competition_id text NOT NULL,
 engine text NOT NULL CHECK(engine IN ('ace','legacy')),
 player1_id text NOT NULL,
 player2_id text NOT NULL CHECK(player1_id<>player2_id),
 feeder1 text REFERENCES ace_review.finalization_claims(match_id),
 feeder2 text REFERENCES ace_review.finalization_claims(match_id),
 CHECK(feeder1 IS DISTINCT FROM match_id AND feeder2 IS DISTINCT FROM match_id),
 CHECK(feeder1 IS NULL OR feeder2 IS NULL OR feeder1<>feeder2)
);
CREATE TABLE ace_review.finalized_matches (
 match_id text PRIMARY KEY REFERENCES ace_review.finalization_claims(match_id),
 competition_id text NOT NULL,
 payload jsonb NOT NULL
);
CREATE TABLE ace_review.finalized_competitions (
 competition_id text PRIMARY KEY REFERENCES ace_review.settlement_exports(competition_id),
 payload jsonb NOT NULL
);
CREATE TABLE ace_review.finalized_prizes (
 player_id text NOT NULL,
 idempotency_key text NOT NULL,
 competition_id text NOT NULL REFERENCES ace_review.finalized_competitions(competition_id),
 payload jsonb NOT NULL,
 PRIMARY KEY(player_id,idempotency_key)
);
ALTER TABLE ace_review.finalization_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE ace_review.finalized_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE ace_review.finalized_competitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ace_review.finalized_prizes ENABLE ROW LEVEL SECURITY;
CREATE POLICY worker_claims ON ace_review.finalization_claims TO ace_review_worker USING(true) WITH CHECK(true);
CREATE POLICY worker_final_matches ON ace_review.finalized_matches TO ace_review_worker USING(true) WITH CHECK(true);
CREATE POLICY worker_final_comp ON ace_review.finalized_competitions TO ace_review_worker USING(true) WITH CHECK(true);
CREATE POLICY worker_final_prizes ON ace_review.finalized_prizes TO ace_review_worker USING(true) WITH CHECK(true);
GRANT SELECT,INSERT ON ace_review.finalization_claims,ace_review.finalized_matches,ace_review.finalized_competitions,ace_review.finalized_prizes TO ace_review_worker;
CREATE FUNCTION ace_review.claim_finalization(p_match text,p_comp text,p_engine text,p_p1 text,p_p2 text,p_f1 text DEFAULT NULL,p_f2 text DEFAULT NULL) RETURNS text
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,ace_review AS $claim$
DECLARE prior ace_review.finalization_claims%ROWTYPE;
BEGIN
 IF p_match IS NULL OR p_match='' OR p_comp IS NULL OR p_comp='' OR p_p1 IS NULL OR p_p2 IS NULL OR p_p1='' OR p_p2='' THEN RAISE EXCEPTION 'invalid claim'; END IF;
 INSERT INTO ace_review.finalization_claims VALUES(p_match,p_comp,p_engine,p_p1,p_p2,p_f1,p_f2) ON CONFLICT DO NOTHING;
 IF FOUND THEN RETURN 'claimed'; END IF;
 SELECT * INTO STRICT prior FROM ace_review.finalization_claims WHERE match_id=p_match;
 IF ROW(prior.competition_id,prior.engine,prior.player1_id,prior.player2_id,prior.feeder1,prior.feeder2) IS DISTINCT FROM ROW(p_comp,p_engine,p_p1,p_p2,p_f1,p_f2) THEN RAISE EXCEPTION 'finalization ownership conflict'; END IF;
 RETURN 'already_claimed';
END $claim$;
CREATE FUNCTION ace_review.finalize_staged_competition(p_comp text) RETURNS text
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,ace_review AS $finalize$
DECLARE export jsonb; m jsonb; prize jsonb; claim ace_review.finalization_claims%ROWTYPE; feeder jsonb;
BEGIN
 -- All competing finalize requests serialize for the same competition.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 IF EXISTS(SELECT 1 FROM ace_review.finalized_competitions WHERE competition_id=p_comp) THEN RETURN 'already_finalized'; END IF;
 SELECT payload INTO STRICT export FROM ace_review.settlement_exports WHERE competition_id=p_comp;
 IF export->>'participant_order_verified' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'participant order not verified'; END IF;
 IF (SELECT count(*) FROM ace_review.finalization_claims WHERE competition_id=p_comp)<>jsonb_array_length(export->'matches') THEN RAISE EXCEPTION 'incomplete match claims'; END IF;
 FOR m IN SELECT value FROM jsonb_array_elements(export->'matches') LOOP
  SELECT * INTO STRICT claim FROM ace_review.finalization_claims WHERE match_id=m->>'match_id';
  IF claim.engine<>'ace' OR claim.competition_id<>p_comp OR m->>'competition_id' IS DISTINCT FROM p_comp OR claim.player1_id IS DISTINCT FROM m->>'player1_id' OR claim.player2_id IS DISTINCT FROM m->>'player2_id' OR m->>'status' IS DISTINCT FROM 'completed' OR m->>'winner_id' IS NULL OR m->>'winner_id' NOT IN(claim.player1_id,claim.player2_id) THEN RAISE EXCEPTION 'finalization claim mismatch'; END IF;
  IF claim.feeder1 IS NOT NULL THEN
   SELECT payload INTO STRICT feeder FROM ace_review.finalized_matches WHERE match_id=claim.feeder1 AND competition_id=p_comp;
   IF feeder->>'winner_id' IS DISTINCT FROM claim.player1_id THEN RAISE EXCEPTION 'first feeder mismatch'; END IF;
  END IF;
  IF claim.feeder2 IS NOT NULL THEN
   SELECT payload INTO STRICT feeder FROM ace_review.finalized_matches WHERE match_id=claim.feeder2 AND competition_id=p_comp;
   IF feeder->>'winner_id' IS DISTINCT FROM claim.player2_id THEN RAISE EXCEPTION 'second feeder mismatch'; END IF;
  END IF;
  IF m->>'completion_reason'='health_walkover' THEN
   IF m->>'score' IS DISTINCT FROM 'W/O' OR m->'actual_duration_minutes' IS DISTINCT FROM 'null'::jsonb OR m->'sets' IS DISTINCT FROM '[]'::jsonb OR m->'stats' IS DISTINCT FROM '[]'::jsonb OR m->'engine_version' IS DISTINCT FROM 'null'::jsonb OR m->>'started_at' IS DISTINCT FROM m->>'completed_at' OR jsonb_typeof(m->'medically_unavailable_player_ids') IS DISTINCT FROM 'array' OR jsonb_array_length(m->'medically_unavailable_player_ids') NOT BETWEEN 1 AND 2 OR EXISTS(SELECT 1 FROM jsonb_array_elements(export->'conditions') x WHERE x->>'match_id'=claim.match_id) OR EXISTS(SELECT 1 FROM jsonb_array_elements(export->'support_events') x WHERE x->>'match_id'=claim.match_id) THEN RAISE EXCEPTION 'invalid medical finalization'; END IF;
  END IF;
  IF m->>'completion_reason'='travel_no_show' THEN
   IF m->>'score' IS DISTINCT FROM 'W/O' OR m->'actual_duration_minutes' IS DISTINCT FROM 'null'::jsonb OR m->'sets' IS DISTINCT FROM '[]'::jsonb OR m->'stats' IS DISTINCT FROM '[]'::jsonb OR m->'engine_version' IS DISTINCT FROM 'null'::jsonb OR m->>'started_at' IS DISTINCT FROM m->>'completed_at' OR jsonb_typeof(m->'travel_unavailable_player_ids') IS DISTINCT FROM 'array' OR jsonb_array_length(m->'travel_unavailable_player_ids') NOT BETWEEN 1 AND 2 OR EXISTS(SELECT 1 FROM jsonb_array_elements(export->'conditions') x WHERE x->>'match_id'=claim.match_id) OR EXISTS(SELECT 1 FROM jsonb_array_elements(export->'support_events') x WHERE x->>'match_id'=claim.match_id) THEN RAISE EXCEPTION 'invalid travel finalization'; END IF;
  END IF;
  INSERT INTO ace_review.finalized_matches VALUES(claim.match_id,p_comp,m);
 END LOOP;
 INSERT INTO ace_review.finalized_competitions VALUES(p_comp,export);
 FOR prize IN SELECT value FROM jsonb_array_elements(export->'transactions') LOOP
  IF prize->>'source_id' IS DISTINCT FROM p_comp OR prize->>'idempotency_key' IS DISTINCT FROM 'tournament-prize:'||p_comp||':'||(prize->>'player_id') OR (prize->>'amount')::bigint<=0 THEN RAISE EXCEPTION 'invalid prize'; END IF;
  INSERT INTO ace_review.finalized_prizes VALUES(prize->>'player_id',prize->>'idempotency_key',p_comp,prize);
 END LOOP;
 RETURN 'finalized_review';
END $finalize$;
REVOKE ALL ON FUNCTION ace_review.claim_finalization(text,text,text,text,text,text,text),ace_review.finalize_staged_competition(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_review.claim_finalization(text,text,text,text,text,text,text),ace_review.finalize_staged_competition(text) TO ace_review_worker;
-- Career proposals are immutable and depend on a finalized review competition.
CREATE TABLE ace_review.career_exports (
 competition_id text PRIMARY KEY REFERENCES ace_review.finalized_competitions(competition_id),
 payload jsonb NOT NULL CHECK ((payload->>'schema'='ace-career-settlement-review-v1' AND payload->>'review_only'='true' AND payload->>'production_ready'='false' AND payload->>'competition_id'=competition_id) IS TRUE)
);
ALTER TABLE ace_review.career_exports ENABLE ROW LEVEL SECURITY;
CREATE POLICY worker_career ON ace_review.career_exports TO ace_review_worker USING(true) WITH CHECK(true);
GRANT SELECT,INSERT ON ace_review.career_exports TO ace_review_worker;
CREATE FUNCTION ace_review.stage_career(p_payload jsonb) RETURNS text
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,ace_review AS $career$
DECLARE v_id text:=p_payload->>'competition_id'; prior jsonb; final jsonb; a jsonb; r jsonb;
BEGIN
 SELECT payload INTO STRICT final FROM ace_review.finalized_competitions WHERE competition_id=v_id;
 IF jsonb_typeof(p_payload->'accounts') IS DISTINCT FROM 'array' OR jsonb_typeof(p_payload->'taxes') IS DISTINCT FROM 'array' OR jsonb_typeof(p_payload->'injury_rolls') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid career arrays'; END IF;
 FOR a IN SELECT value FROM jsonb_array_elements(p_payload->'accounts') LOOP
  IF (a->>'gross_prize')::bigint IS DISTINCT FROM (SELECT coalesce(sum((x->>'amount')::bigint),0) FROM jsonb_array_elements(final->'transactions') x WHERE x->>'player_id'=a->>'player_id') OR (a->>'balance_before_tax')::bigint IS DISTINCT FROM (a->>'opening_balance')::bigint+(a->>'gross_prize')::bigint THEN RAISE EXCEPTION 'career prize mismatch'; END IF;
 END LOOP;
 FOR r IN SELECT value FROM jsonb_array_elements(p_payload->'injury_rolls') LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(final->'matches') m WHERE m->>'match_id'=r->>'match_id' AND coalesce(m->>'completion_reason','') NOT IN ('health_walkover','travel_no_show') AND r->>'player_id' IN(m->>'player1_id',m->>'player2_id')) THEN RAISE EXCEPTION 'invalid career injury source'; END IF;
 END LOOP;
 INSERT INTO ace_review.career_exports VALUES(v_id,p_payload) ON CONFLICT DO NOTHING;
 IF FOUND THEN RETURN 'staged'; END IF;
 SELECT payload INTO STRICT prior FROM ace_review.career_exports WHERE competition_id=v_id;
 IF prior IS DISTINCT FROM p_payload THEN RAISE EXCEPTION 'career export conflict'; END IF;
 RETURN 'already_staged';
END $career$;
REVOKE ALL ON FUNCTION ace_review.stage_career(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_review.stage_career(jsonb) TO ace_review_worker;
COMMIT;
