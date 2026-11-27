-- Disposable review only. Requires both preceding review schemas.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.protected_competitions (
 competition_id text PRIMARY KEY CHECK(length(competition_id)>0)
);
CREATE TABLE ace_cutover_review.feeder_contract (
 match_id text PRIMARY KEY REFERENCES ace_cutover_review.matches(id),
 competition_id text NOT NULL REFERENCES ace_cutover_review.protected_competitions(competition_id),
 feeder1 text REFERENCES ace_cutover_review.feeder_contract(match_id),
 feeder2 text REFERENCES ace_cutover_review.feeder_contract(match_id),
 CHECK(feeder1 IS DISTINCT FROM match_id AND feeder2 IS DISTINCT FROM match_id),
 CHECK(feeder1 IS NULL OR feeder2 IS NULL OR feeder1<>feeder2)
);
GRANT SELECT ON ace_cutover_review.protected_competitions,ace_cutover_review.feeder_contract TO ace_review_worker;
CREATE FUNCTION ace_cutover_review.register_competition(p_comp text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF p_comp IS NULL OR p_comp='' THEN RAISE EXCEPTION 'invalid competition'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=p_comp) THEN RETURN 'already_registered'; END IF;
 IF EXISTS(SELECT 1 FROM ace_review.settlement_exports WHERE competition_id=p_comp)
 OR EXISTS(SELECT 1 FROM ace_review.finalization_claims WHERE competition_id=p_comp)
 OR EXISTS(SELECT 1 FROM ace_cutover_review.matches WHERE competition=p_comp) THEN RAISE EXCEPTION 'register before match or settlement creation'; END IF;
 INSERT INTO ace_cutover_review.protected_competitions VALUES(p_comp);
 RETURN 'registered';
END $$;
CREATE FUNCTION ace_cutover_review.guard_seed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.competition,91023));
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition)
 AND EXISTS(SELECT 1 FROM ace_review.finalized_competitions WHERE competition_id=NEW.competition) THEN RAISE EXCEPTION 'competition finalized'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition) THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.id,91024));
  IF EXISTS(SELECT 1 FROM ace_review.finalization_claims WHERE match_id=NEW.id) OR EXISTS(SELECT 1 FROM ace_review.finalized_matches WHERE match_id=NEW.id) THEN RAISE EXCEPTION 'preexisting finalization identity'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_seed BEFORE INSERT ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_seed();
CREATE FUNCTION ace_cutover_review.bind_feeders(p_id text,p_f1 text DEFAULT NULL,p_f2 text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE;
BEGIN
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id;
 PERFORM pg_advisory_xact_lock(hashtextextended(m.competition,91023));
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=p_id FOR UPDATE;
 IF m.owner IS NOT NULL OR m.status<>'scheduled' OR m.started THEN RAISE EXCEPTION 'bind before admission'; END IF;
 IF p_f1 IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.feeder_contract WHERE match_id=p_f1 AND competition_id=m.competition) THEN RAISE EXCEPTION 'wrong first feeder'; END IF;
 IF p_f2 IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.feeder_contract WHERE match_id=p_f2 AND competition_id=m.competition) THEN RAISE EXCEPTION 'wrong second feeder'; END IF;
 INSERT INTO ace_cutover_review.feeder_contract VALUES(p_id,m.competition,p_f1,p_f2);
END $$;
CREATE FUNCTION ace_cutover_review.guard_settlement_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.competition_id,91023));
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition_id)
 AND session_user<>'ace_cutover_ace' THEN RAISE EXCEPTION 'protected competition requires Ace ownership'; END IF;
 IF TG_TABLE_NAME IN ('finalization_claims','finalized_matches') THEN
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.match_id,91024));
  IF EXISTS(SELECT 1 FROM ace_cutover_review.matches m JOIN ace_cutover_review.protected_competitions p ON p.competition_id=m.competition WHERE m.id=NEW.match_id AND m.competition<>NEW.competition_id) THEN RAISE EXCEPTION 'foreign protected match identity'; END IF;
  IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=NEW.competition_id) AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.matches WHERE id=NEW.match_id AND competition=NEW.competition_id) THEN RAISE EXCEPTION 'missing protected match identity'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER cutover_protected_export BEFORE INSERT ON ace_review.settlement_exports FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_settlement_insert();
CREATE TRIGGER cutover_protected_claim BEFORE INSERT ON ace_review.finalization_claims FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_settlement_insert();
CREATE TRIGGER cutover_protected_match BEFORE INSERT ON ace_review.finalized_matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_settlement_insert();
CREATE TRIGGER cutover_protected_competition BEFORE INSERT ON ace_review.finalized_competitions FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_settlement_insert();
CREATE TRIGGER cutover_protected_prize BEFORE INSERT ON ace_review.finalized_prizes FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_settlement_insert();
CREATE TRIGGER cutover_protected_career BEFORE INSERT ON ace_review.career_exports FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_settlement_insert();
CREATE FUNCTION ace_cutover_review.settle_owned(p_payload jsonb,p_career jsonb DEFAULT NULL) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE comp text:=p_payload->>'competition_id'; m jsonb; r jsonb; t jsonb; match_row ace_cutover_review.matches%ROWTYPE; e ace_cutover_review.effects%ROWTYPE; f ace_cutover_review.feeder_contract%ROWTYPE; result text;
BEGIN
 IF ace_cutover_review.actor() IS DISTINCT FROM 'ace' THEN RAISE EXCEPTION 'wrong engine'; END IF;
 IF comp IS NULL OR comp='' THEN RAISE EXCEPTION 'invalid competition'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(comp,91023));
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=comp) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.cancellations WHERE competition_id=comp) THEN RAISE EXCEPTION 'competition cancelled'; END IF;
 IF p_payload->>'schema' IS DISTINCT FROM 'ace-settlement-review-v1' OR p_payload->>'review_only' IS DISTINCT FROM 'true' OR p_payload->>'production_ready' IS DISTINCT FROM 'false' OR p_payload->>'participant_order_verified' IS DISTINCT FROM 'true'
 OR jsonb_typeof(p_payload->'matches') IS DISTINCT FROM 'array' OR jsonb_typeof(p_payload->'results') IS DISTINCT FROM 'array' OR jsonb_typeof(p_payload->'transactions') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'invalid settlement'; END IF;
 IF jsonb_array_length(p_payload->'matches')=0 OR
 (SELECT count(*) FROM ace_cutover_review.matches WHERE competition=comp)<>jsonb_array_length(p_payload->'matches') OR
 (SELECT count(DISTINCT x->>'match_id') FROM jsonb_array_elements(p_payload->'matches') x)<>jsonb_array_length(p_payload->'matches') THEN RAISE EXCEPTION 'incomplete match set'; END IF;
 PERFORM 1 FROM ace_cutover_review.matches WHERE competition=comp ORDER BY id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_contracts WHERE competition_id=comp) THEN
  IF EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s LEFT JOIN ace_cutover_review.matches m ON m.id=s.match_id AND m.competition=s.competition_id WHERE s.competition_id=comp AND (m.id IS NULL OR m.status<>'completed' OR m.owner IS DISTINCT FROM 'ace')) THEN RAISE EXCEPTION 'incomplete imported source inventory'; END IF;
  IF EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.matches m ON m.id=s.match_id WHERE s.competition_id=comp AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_result_projection q JOIN ace_cutover_review.effects oe ON oe.match_id=q.match_id WHERE q.match_id=m.id AND q.match_revision=m.revision AND q.status='completed' AND q.owner=m.owner AND q.receipt=oe.receipt AND q.winner_id=oe.winner)) THEN RAISE EXCEPTION 'imported result synchronization pending'; END IF;
  IF EXISTS(SELECT 1 FROM ace_cutover_review.source_career_opt_in WHERE competition_id=comp) AND EXISTS(SELECT 1 FROM ace_cutover_review.matches m WHERE m.competition=comp AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_batches b WHERE b.match_id=m.id AND b.terminal_revision=m.revision) AND NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_no_play_career n WHERE n.match_id=m.id AND n.terminal_revision=m.revision)) THEN RAISE EXCEPTION 'imported career settlement pending'; END IF;
  IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.closure_audits a WHERE a.competition_id=comp AND a.report->>'status'='normal_legacy_candidates' AND jsonb_array_length(a.report->'legacy_result_candidates')=jsonb_array_length(p_payload->'results') AND jsonb_array_length(a.report->'legacy_prize_candidates')=jsonb_array_length(p_payload->'transactions') AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.report->'legacy_result_candidates') x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_payload->'results') y WHERE y @> x)) AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.report->'legacy_prize_candidates') x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_payload->'transactions') y WHERE y @> x))) THEN RAISE EXCEPTION 'imported closure audit or reward mismatch'; END IF;
 END IF;
 FOR m IN SELECT value FROM jsonb_array_elements(p_payload->'matches') LOOP
  SELECT * INTO STRICT match_row FROM ace_cutover_review.matches WHERE id=m->>'match_id';
  SELECT * INTO STRICT e FROM ace_cutover_review.effects WHERE match_id=match_row.id;
  SELECT * INTO STRICT f FROM ace_cutover_review.feeder_contract WHERE match_id=match_row.id;
  IF match_row.competition<>comp OR f.competition_id<>comp OR match_row.owner IS DISTINCT FROM 'ace' OR match_row.status<>'completed' OR e.engine<>'ace'
  OR match_row.player1 IS DISTINCT FROM m->>'player1_id' OR match_row.player2 IS DISTINCT FROM m->>'player2_id' OR e.winner IS DISTINCT FROM m->>'winner_id'
  OR e.receipt IS DISTINCT FROM m OR EXISTS(SELECT 1 FROM ace_cutover_review.handoffs WHERE match_id=match_row.id AND resolution IS NULL) THEN RAISE EXCEPTION 'owned receipt mismatch'; END IF;
  IF m->>'completion_reason'='health_walkover' THEN
   IF match_row.started OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.medical_snapshots h WHERE h.match_id=match_row.id AND h.receipt=m) THEN RAISE EXCEPTION 'unverified medical receipt'; END IF;
  ELSIF m->>'completion_reason'='travel_no_show' THEN
   IF match_row.started OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.travel_evidence t WHERE t.match_id=match_row.id AND t.receipt=m) THEN RAISE EXCEPTION 'unverified travel receipt'; END IF;
  ELSIF m->>'completion_reason'='health_surrender' THEN
   IF match_row.started OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.surrender_evidence s WHERE s.match_id=match_row.id AND s.receipt=m) THEN RAISE EXCEPTION 'unverified surrender receipt'; END IF;
  ELSIF m->>'completion_reason' IS NOT NULL OR coalesce((m->>'actual_duration_minutes')::int,0)<=0 OR jsonb_typeof(m->'sets') IS DISTINCT FROM 'array' OR jsonb_array_length(m->'sets')=0 OR jsonb_typeof(m->'stats') IS DISTINCT FROM 'array' OR jsonb_array_length(m->'stats')<>2 THEN RAISE EXCEPTION 'unsupported terminal receipt'; END IF;
  PERFORM ace_review.claim_finalization(match_row.id,comp,'ace',match_row.player1,match_row.player2,f.feeder1,f.feeder2);
 END LOOP;
 IF (SELECT count(DISTINCT x->>'player_id') FROM jsonb_array_elements(p_payload->'results') x)<>jsonb_array_length(p_payload->'results') THEN RAISE EXCEPTION 'duplicate result'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_payload->'results') LOOP
  SELECT * INTO STRICT match_row FROM ace_cutover_review.matches WHERE id=r->>'match_id';
  IF match_row.competition<>comp OR r->>'competition_id' IS DISTINCT FROM comp OR r->>'player_id' IS NULL OR r->>'player_id' NOT IN(match_row.player1,match_row.player2) OR coalesce((r->>'ranking_points_earned')::bigint,-1)<0 OR coalesce((r->>'prize_money_earned')::bigint,-1)<0 THEN RAISE EXCEPTION 'invalid result'; END IF;
 END LOOP;
 FOR t IN SELECT value FROM jsonb_array_elements(p_payload->'transactions') LOOP
  SELECT x INTO STRICT r FROM jsonb_array_elements(p_payload->'results') x WHERE x->>'player_id'=t->>'player_id';
  IF (r->>'prize_money_earned')::bigint IS DISTINCT FROM (t->>'amount')::bigint OR (t->>'balance_after')::bigint-(t->>'balance_before')::bigint IS DISTINCT FROM (t->>'amount')::bigint OR t->>'is_taxable' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'prize/result mismatch'; END IF;
 END LOOP;
 PERFORM ace_review.stage_settlement(p_payload);
 result:=ace_review.finalize_staged_competition(comp);
 IF p_career IS NOT NULL THEN
  IF p_career->>'competition_id' IS DISTINCT FROM comp THEN RAISE EXCEPTION 'foreign career proposal'; END IF;
  PERFORM ace_review.stage_career(p_career);
 END IF;
 RETURN result;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.register_competition(text),ace_cutover_review.guard_seed(),ace_cutover_review.bind_feeders(text,text,text),ace_cutover_review.guard_settlement_insert(),ace_cutover_review.settle_owned(jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.register_competition(text),ace_cutover_review.bind_feeders(text,text,text) TO ace_review_worker;
GRANT EXECUTE ON FUNCTION ace_cutover_review.settle_owned(jsonb,jsonb) TO ace_cutover_ace;
COMMIT;
