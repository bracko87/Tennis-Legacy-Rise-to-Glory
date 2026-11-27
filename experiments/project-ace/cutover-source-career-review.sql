-- Disposable career projection, not official career processing.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.source_career_players (
 player_id text PRIMARY KEY,
 revision bigint NOT NULL CHECK(revision>=0),
 state jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_career_opt_in (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.source_contracts(competition_id),
 surface text NOT NULL CHECK(surface IN ('hard','clay','grass'))
);
CREATE TABLE ace_cutover_review.source_career_starts (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_starts(match_id),
 snapshot jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_career_batches (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.source_career_starts(match_id),
 terminal_revision bigint NOT NULL,
 proposal jsonb NOT NULL,
 report jsonb NOT NULL
);
CREATE TABLE ace_cutover_review.source_career_effects (
 match_id text NOT NULL REFERENCES ace_cutover_review.source_career_batches(match_id),
 player_id text NOT NULL REFERENCES ace_cutover_review.source_career_players(player_id),
 idempotency_key text UNIQUE NOT NULL,
 before_revision bigint NOT NULL,
 after_revision bigint NOT NULL,
 effect jsonb NOT NULL,
 PRIMARY KEY(match_id,player_id)
);
GRANT SELECT ON ace_cutover_review.source_career_players,ace_cutover_review.source_career_opt_in,ace_cutover_review.source_career_starts,ace_cutover_review.source_career_batches,ace_cutover_review.source_career_effects TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.validate_source_career(p jsonb) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE k text; item jsonb;
BEGIN
 IF jsonb_typeof(p) IS DISTINCT FROM 'object' OR jsonb_typeof(p->'profile') IS DISTINCT FROM 'object' OR jsonb_typeof(p->'inventory') IS DISTINCT FROM 'array' OR jsonb_typeof(p->'loadout') IS DISTINCT FROM 'object' OR jsonb_typeof(p->'injuries') IS DISTINCT FROM 'array' OR jsonb_typeof(p->'staff') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'incomplete career state'; END IF;
 FOREACH k IN ARRAY ARRAY['fatigue','sharpness','morale','confidence','focus','fitness','stamina','recovery','movement'] LOOP
  IF jsonb_typeof(p->'profile'->k) IS DISTINCT FROM 'number' OR (p->'profile'->>k)::int NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'invalid career condition'; END IF;
 END LOOP;
 IF (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p->'inventory') x)<>jsonb_array_length(p->'inventory') THEN RAISE EXCEPTION 'duplicate inventory identity'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p->'inventory') LOOP
  IF item->>'id'='' OR coalesce(item->>'type','') NOT IN ('racket','shoes','apparel') OR jsonb_typeof(item->'condition') IS DISTINCT FROM 'number' OR (item->>'condition')::numeric NOT BETWEEN 0.01 AND 100 THEN RAISE EXCEPTION 'invalid equipment condition'; END IF;
 END LOOP;
 FOREACH k IN ARRAY ARRAY['racket','shoes','apparel'] LOOP
  IF NOT (p->'loadout' ? k) OR (p->'loadout'->>k IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'inventory') x WHERE x->>'id'=p->'loadout'->>k AND x->>'type'=k)) THEN RAISE EXCEPTION 'invalid loadout'; END IF;
 END LOOP;
END $$;
-- Simulated external career updates are CAS, even during a match. No automatic rebase.
CREATE FUNCTION ace_cutover_review.observe_source_career(p_id text,p_expected bigint,p_state jsonb) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE old ace_cutover_review.source_career_players%ROWTYPE;
BEGIN
 IF p_id IS NULL OR btrim(p_id)='' THEN RAISE EXCEPTION 'invalid player identity'; END IF;
 PERFORM ace_cutover_review.validate_source_career(p_state);
 PERFORM pg_advisory_xact_lock(hashtextextended(p_id,91026));
 SELECT * INTO old FROM ace_cutover_review.source_career_players WHERE player_id=p_id FOR UPDATE;
 IF NOT FOUND THEN
  IF p_expected IS DISTINCT FROM -1 THEN RAISE EXCEPTION 'stale career revision'; END IF;
  INSERT INTO ace_cutover_review.source_career_players VALUES(p_id,0,p_state);
  RETURN 0;
 END IF;
 IF old.revision IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'stale career revision'; END IF;
 IF old.state=p_state THEN RETURN old.revision; END IF;
 UPDATE ace_cutover_review.source_career_players SET revision=revision+1,state=p_state WHERE player_id=p_id RETURNING revision INTO old.revision;
 RETURN old.revision;
END $$;
CREATE FUNCTION ace_cutover_review.enable_source_career_review(p_comp text,p_surface text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE prior text;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 SELECT surface INTO prior FROM ace_cutover_review.source_career_opt_in WHERE competition_id=p_comp;
 IF FOUND THEN IF prior IS DISTINCT FROM p_surface THEN RAISE EXCEPTION 'conflicting career scope'; END IF; RETURN 'already_enabled'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id=p_comp) THEN RAISE EXCEPTION 'enable before admission'; END IF;
 INSERT INTO ace_cutover_review.source_career_opt_in VALUES(p_comp,p_surface);
 RETURN 'enabled';
END $$;
-- After active resource locks; capture both player rows in deterministic order.
CREATE FUNCTION ace_cutover_review.capture_source_career_start() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE st ace_cutover_review.source_starts%ROWTYPE; surface_name text; snapshots jsonb;
BEGIN
 IF OLD.status IS NOT DISTINCT FROM NEW.status OR NEW.status<>'in_progress' THEN RETURN NEW; END IF;
 SELECT surface INTO surface_name FROM ace_cutover_review.source_career_opt_in WHERE competition_id=NEW.competition;
 IF NOT FOUND THEN RETURN NEW; END IF;
 SELECT * INTO STRICT st FROM ace_cutover_review.source_starts WHERE match_id=NEW.id;
 PERFORM 1 FROM ace_cutover_review.source_career_players WHERE player_id IN(NEW.player1,NEW.player2) ORDER BY player_id COLLATE "C" FOR UPDATE;
 IF (SELECT count(*) FROM ace_cutover_review.source_career_players WHERE player_id IN(NEW.player1,NEW.player2))<>2 THEN RAISE EXCEPTION 'missing player career state'; END IF;
 SELECT jsonb_agg(state||jsonb_build_object('player_id',player_id,'career_revision',revision) ORDER BY CASE WHEN player_id=NEW.player1 THEN 1 ELSE 2 END) INTO snapshots FROM ace_cutover_review.source_career_players WHERE player_id IN(NEW.player1,NEW.player2);
 IF snapshots->0->'injuries' IS DISTINCT FROM st.evidence->'health1' OR snapshots->1->'injuries' IS DISTINCT FROM st.evidence->'health2' THEN RAISE EXCEPTION 'career health snapshot mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_career_starts cs JOIN ace_cutover_review.matches m ON m.id=cs.match_id WHERE m.status='completed' AND m.id<>NEW.id AND (m.player1 IN(NEW.player1,NEW.player2) OR m.player2 IN(NEW.player1,NEW.player2)) AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_batches b WHERE b.match_id=m.id)) THEN RAISE EXCEPTION 'prior career settlement pending'; END IF;
 INSERT INTO ace_cutover_review.source_career_starts VALUES(NEW.id,jsonb_build_object('match_id',NEW.id,'competition_id',NEW.competition,'start_revision',NEW.revision,'absolute_day',st.game_second/86400,'surface',surface_name,'players',snapshots));
 RETURN NEW;
END $$;
CREATE TRIGGER zzzz_source_career_start BEFORE UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.capture_source_career_start();
-- Controller supplies pure proposal plus exact DB snapshot and effect receipt.
-- SQL checks identity, current revisions and structural/range invariants, not full formula replay.
CREATE FUNCTION ace_cutover_review.apply_source_career(p_id text,p_snapshot jsonb,p_receipt jsonb,p jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; st jsonb; e ace_cutover_review.effects%ROWTYPE; prior ace_cutover_review.source_career_batches%ROWTYPE; x jsonb; snap jsonb; current_row ace_cutover_review.source_career_players%ROWTYPE; next_state jsonb; k text; i int; reports jsonb:='[]'; report jsonb; gear jsonb; original jsonb;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 SELECT snapshot INTO STRICT st FROM ace_cutover_review.source_career_starts WHERE match_id=p_id;
 SELECT * INTO STRICT e FROM ace_cutover_review.effects WHERE match_id=p_id;
 IF m.status<>'completed' OR e.engine IS DISTINCT FROM m.owner OR st IS DISTINCT FROM p_snapshot OR e.receipt IS DISTINCT FROM p_receipt OR p_receipt->>'completion_reason' IS NOT NULL OR p->>'schema' IS DISTINCT FROM 'ace-source-career-proposal-v1' OR p->'review_only' IS DISTINCT FROM 'true'::jsonb OR p->'production_ready' IS DISTINCT FROM 'false'::jsonb OR p->>'status' IS DISTINCT FROM 'review_proposal' OR p->>'match_id' IS DISTINCT FROM p_id OR p->>'competition_id' IS DISTINCT FROM m.competition OR p->>'owner' IS DISTINCT FROM m.owner OR p->'match_revision' IS DISTINCT FROM to_jsonb(m.revision) OR jsonb_typeof(p->'players') IS DISTINCT FROM 'array' OR jsonb_array_length(p->'players')<>2 THEN RAISE EXCEPTION 'unverified career proposal'; END IF;
 SELECT * INTO prior FROM ace_cutover_review.source_career_batches WHERE match_id=p_id;
 IF FOUND THEN IF prior.proposal IS DISTINCT FROM p THEN RAISE EXCEPTION 'conflicting career replay'; END IF; RETURN prior.report; END IF;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_result_projection q WHERE q.match_id=p_id AND q.match_revision=m.revision AND q.status='completed' AND q.receipt=e.receipt AND q.winner_id=e.winner) THEN RAISE EXCEPTION 'result synchronization required'; END IF;
 PERFORM 1 FROM ace_cutover_review.source_career_players WHERE player_id IN(m.player1,m.player2) ORDER BY player_id COLLATE "C" FOR UPDATE;
 FOR i IN 0..1 LOOP
  x:=p->'players'->i;snap:=st->'players'->i;
  SELECT * INTO STRICT current_row FROM ace_cutover_review.source_career_players WHERE player_id=snap->>'player_id';
  IF x->>'player_id' IS DISTINCT FROM snap->>'player_id' OR x->'expected_career_revision' IS DISTINCT FROM snap->'career_revision' OR to_jsonb(current_row.revision) IS DISTINCT FROM snap->'career_revision' OR current_row.state||jsonb_build_object('player_id',current_row.player_id,'career_revision',current_row.revision) IS DISTINCT FROM snap OR x->>'idempotency_key' IS DISTINCT FROM 'match-career:'||p_id||':'||current_row.player_id OR x->'equipment_before' IS DISTINCT FROM current_row.state->'inventory' OR x->'minutes' IS DISTINCT FROM e.receipt->'actual_duration_minutes' OR jsonb_typeof(x->'after') IS DISTINCT FROM 'object' OR (SELECT count(*) FROM jsonb_object_keys(x->'after'))<>5 THEN RAISE EXCEPTION 'stale or mismatched career state'; END IF;
  FOREACH k IN ARRAY ARRAY['fatigue','sharpness','morale','confidence','focus'] LOOP
   IF x->'before'->k IS DISTINCT FROM current_row.state->'profile'->k OR jsonb_typeof(x->'after'->k) IS DISTINCT FROM 'number' OR (x->'after'->>k)::int NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'invalid condition delta'; END IF;
  END LOOP;
  IF jsonb_typeof(x->'fatigue_gain') IS DISTINCT FROM 'number' OR (x->>'fatigue_gain')::int NOT BETWEEN 0 AND 28 OR (x->'after'->>'fatigue')::int<>least(100,(x->'before'->>'fatigue')::int+(x->>'fatigue_gain')::int) THEN RAISE EXCEPTION 'invalid fatigue delta'; END IF;
  next_state:=current_row.state||jsonb_build_object('profile',(current_row.state->'profile')||(x->'after'),'inventory',x->'equipment_after','loadout',x->'loadout_after');
  PERFORM ace_cutover_review.validate_source_career(next_state);
  FOR gear IN SELECT value FROM jsonb_array_elements(next_state->'inventory') LOOP
   SELECT z INTO STRICT original FROM jsonb_array_elements(current_row.state->'inventory') z WHERE z->>'id'=gear->>'id';
   IF gear-'condition' IS DISTINCT FROM original-'condition' OR (gear->>'condition')::numeric>(original->>'condition')::numeric THEN RAISE EXCEPTION 'invalid equipment change'; END IF;
  END LOOP;
  -- Only currently equipped gear may be removed or worn. Unselected stock preserved.
  FOR original IN SELECT value FROM jsonb_array_elements(current_row.state->'inventory') LOOP
   IF NOT EXISTS(SELECT 1 FROM jsonb_each_text(current_row.state->'loadout') l WHERE l.value=original->>'id') AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(next_state->'inventory') z WHERE z=original) THEN RAISE EXCEPTION 'unselected equipment changed'; END IF;
  END LOOP;
  UPDATE ace_cutover_review.source_career_players SET state=next_state,revision=revision+1 WHERE player_id=current_row.player_id;
  reports:=reports||jsonb_build_array(jsonb_build_object('player_id',current_row.player_id,'before_revision',current_row.revision,'after_revision',current_row.revision+1));
 END LOOP;
 report:=jsonb_build_object('schema','ace-career-application-review-v1','review_only',true,'production_ready',false,'match_id',p_id,'status','applied_review','players',reports);
 INSERT INTO ace_cutover_review.source_career_batches VALUES(p_id,m.revision,p,report);
 FOR x IN SELECT value FROM jsonb_array_elements(p->'players') LOOP
  INSERT INTO ace_cutover_review.source_career_effects VALUES(p_id,x->>'player_id',x->>'idempotency_key',(x->>'expected_career_revision')::bigint,(x->>'expected_career_revision')::bigint+1,x);
 END LOOP;
 RETURN report;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.validate_source_career(jsonb),ace_cutover_review.observe_source_career(text,bigint,jsonb),ace_cutover_review.enable_source_career_review(text,text),ace_cutover_review.capture_source_career_start(),ace_cutover_review.apply_source_career(text,jsonb,jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.observe_source_career(text,bigint,jsonb),ace_cutover_review.enable_source_career_review(text,text),ace_cutover_review.apply_source_career(text,jsonb,jsonb,jsonb) TO ace_review_worker;
COMMIT;
