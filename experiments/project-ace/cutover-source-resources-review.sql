-- Disposable review only. Imported matches share active player and physical-court reservations.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.source_venues (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.source_contracts(competition_id),
 venue_id text NOT NULL CHECK(length(venue_id)>0)
);
CREATE TABLE ace_cutover_review.active_source_resources (
 resource_kind text NOT NULL CHECK(resource_kind IN ('player','court')),
 resource_key text NOT NULL,
 match_id text NOT NULL REFERENCES ace_cutover_review.source_admissions(match_id),
 PRIMARY KEY(resource_kind,resource_key)
);
CREATE INDEX active_source_resources_match ON ace_cutover_review.active_source_resources(match_id);
CREATE TABLE ace_cutover_review.source_resource_history (
 match_id text NOT NULL REFERENCES ace_cutover_review.source_admissions(match_id),
 resource_kind text NOT NULL,
 resource_key text NOT NULL,
 start_revision bigint NOT NULL,
 terminal_revision bigint,
 PRIMARY KEY(match_id,resource_kind,resource_key)
);
GRANT SELECT ON ace_cutover_review.source_venues,ace_cutover_review.active_source_resources,ace_cutover_review.source_resource_history TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.bind_source_venue(p_comp text,p_venue text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE prior text;
BEGIN
 IF p_venue IS NULL OR btrim(p_venue)<>p_venue OR length(p_venue) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'invalid venue identity'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 SELECT venue_id INTO prior FROM ace_cutover_review.source_venues WHERE competition_id=p_comp;
 IF FOUND THEN
  IF prior IS DISTINCT FROM p_venue THEN RAISE EXCEPTION 'conflicting venue identity'; END IF;
  RETURN 'already_bound';
 END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id=p_comp) THEN RAISE EXCEPTION 'bind venue before admission'; END IF;
 INSERT INTO ace_cutover_review.source_venues VALUES(p_comp,p_venue);
 RETURN 'bound';
END $$;
-- Same ordered keys for every start; conflicting inserts cannot both succeed.
-- Any failed start rolls back all reservations and the source-start evidence.
CREATE FUNCTION ace_cutover_review.reserve_source_resources() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE venue text; court int; r record;
BEGIN
 IF OLD.status IS NOT DISTINCT FROM NEW.status OR NEW.status<>'in_progress' OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) THEN RETURN NEW; END IF;
 SELECT venue_id INTO venue FROM ace_cutover_review.source_venues WHERE competition_id=NEW.competition;
 IF venue IS NULL THEN RAISE EXCEPTION 'physical venue binding required'; END IF;
 SELECT (slot->>'court_number')::int INTO STRICT court FROM ace_cutover_review.source_slots WHERE match_id=NEW.id;
 FOR r IN SELECT * FROM (VALUES ('player'::text,NEW.player1),('player'::text,NEW.player2),('court'::text,jsonb_build_array(venue,court)::text)) AS v(kind,key) ORDER BY kind COLLATE "C",key COLLATE "C" LOOP
  INSERT INTO ace_cutover_review.active_source_resources VALUES(r.kind,r.key,NEW.id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RAISE EXCEPTION 'source resource conflict: %',r.kind; END IF;
  INSERT INTO ace_cutover_review.source_resource_history VALUES(NEW.id,r.kind,r.key,NEW.revision,NULL);
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER zz_source_reserve BEFORE UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.reserve_source_resources();
CREATE FUNCTION ace_cutover_review.release_source_resources() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE n integer;
BEGIN
 IF OLD.status='in_progress' AND NEW.status IN ('completed','walkover','bye','cancelled') AND EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) THEN
  UPDATE ace_cutover_review.source_resource_history SET terminal_revision=NEW.revision WHERE match_id=NEW.id AND terminal_revision IS NULL;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>3 THEN RAISE EXCEPTION 'incomplete resource history'; END IF;
  DELETE FROM ace_cutover_review.active_source_resources WHERE match_id=NEW.id;
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>3 THEN RAISE EXCEPTION 'incomplete active reservations'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER zz_source_release AFTER UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.release_source_resources();

-- Separate target projection: never modifies source_observations or official tables.
CREATE TABLE ace_cutover_review.source_result_projection (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_admissions(match_id),
 match_revision bigint NOT NULL,
 owner text NOT NULL,
 status text NOT NULL,
 winner_id text,
 receipt jsonb
);
CREATE TABLE ace_cutover_review.source_sync_receipts (
 match_id text NOT NULL REFERENCES ace_cutover_review.source_admissions(match_id),
 match_revision bigint NOT NULL,
 report jsonb NOT NULL,
 PRIMARY KEY(match_id,match_revision)
);
GRANT SELECT ON ace_cutover_review.source_result_projection,ace_cutover_review.source_sync_receipts TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.sync_source_event(p_id text,p_rev bigint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; a ace_cutover_review.source_admissions%ROWTYPE; ev ace_cutover_review.source_runtime_events%ROWTYPE; p ace_cutover_review.source_result_projection%ROWTYPE; v jsonb; w text;
BEGIN
 -- Serialize event application with match lifecycle; exact older replay is harmless.
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 SELECT * INTO STRICT a FROM ace_cutover_review.source_admissions WHERE match_id=p_id;
 SELECT report INTO v FROM ace_cutover_review.source_sync_receipts WHERE match_id=p_id AND match_revision=p_rev;
 IF FOUND THEN RETURN v; END IF;
 SELECT * INTO STRICT ev FROM ace_cutover_review.source_runtime_events WHERE match_id=p_id AND match_revision=p_rev;
 INSERT INTO ace_cutover_review.source_result_projection(match_id,match_revision,owner,status) VALUES(p_id,1,a.owner,'scheduled') ON CONFLICT DO NOTHING;
 SELECT * INTO STRICT p FROM ace_cutover_review.source_result_projection WHERE match_id=p_id FOR UPDATE;
 IF p_rev IS DISTINCT FROM p.match_revision+1 OR p.owner IS DISTINCT FROM a.owner OR ev.owner IS DISTINCT FROM a.owner OR m.owner IS DISTINCT FROM a.owner THEN RAISE EXCEPTION 'source sync out of order or owner mismatch'; END IF;
 IF ev.status='in_progress' THEN
  IF p.status<>'scheduled' OR ev.receipt IS NOT NULL THEN RAISE EXCEPTION 'invalid source start event'; END IF;
 ELSIF ev.status='completed' THEN
  IF p.status NOT IN ('scheduled','in_progress') OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.effects e WHERE e.match_id=p_id AND e.engine=a.owner AND e.receipt=ev.receipt) THEN RAISE EXCEPTION 'unverified source completion'; END IF;
  SELECT winner INTO STRICT w FROM ace_cutover_review.effects WHERE match_id=p_id;
  IF w NOT IN(m.player1,m.player2) OR (ev.receipt ? 'winner_id' AND ev.receipt->>'winner_id' IS DISTINCT FROM w) THEN RAISE EXCEPTION 'source winner mismatch'; END IF;
 ELSIF ev.status IN ('walkover','bye','cancelled') THEN
  IF p.status<>'scheduled' OR ev.receipt IS DISTINCT FROM ace_cutover_review.terminal_feeder(p_id,m.competition) THEN RAISE EXCEPTION 'unverified special source outcome'; END IF;
  w:=ev.receipt->>'winner_id';
  IF (ev.status='cancelled' AND w IS NOT NULL) OR (ev.status<>'cancelled' AND (w IS NULL OR w NOT IN(m.player1,m.player2))) THEN RAISE EXCEPTION 'invalid special source winner'; END IF;
 ELSE RAISE EXCEPTION 'unsupported source event'; END IF;
 UPDATE ace_cutover_review.source_result_projection SET match_revision=p_rev,status=ev.status,winner_id=w,receipt=ev.receipt WHERE match_id=p_id;
 v:=jsonb_build_object('schema','ace-source-sync-review-v1','review_only',true,'production_ready',false,'match_id',p_id,'match_revision',p_rev,'owner',a.owner,'status',ev.status,'winner_id',w);
 INSERT INTO ace_cutover_review.source_sync_receipts VALUES(p_id,p_rev,v);
 RETURN v;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.bind_source_venue(text,text),ace_cutover_review.reserve_source_resources(),ace_cutover_review.release_source_resources(),ace_cutover_review.sync_source_event(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.bind_source_venue(text,text),ace_cutover_review.sync_source_event(text,bigint) TO ace_review_worker;
COMMIT;
