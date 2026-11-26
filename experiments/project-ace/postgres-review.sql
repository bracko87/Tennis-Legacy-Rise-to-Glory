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
COMMIT;
