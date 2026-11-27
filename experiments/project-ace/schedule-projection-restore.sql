DROP FUNCTION ace_cutover_review.drain_followup_outbox(integer);
DROP TRIGGER zz_followup_completion ON ace_cutover_review.matches;
DROP FUNCTION ace_cutover_review.enqueue_followup_completion(),ace_cutover_review.process_followup_outbox(text);
DROP TABLE ace_cutover_review.followup_outbox;
DROP FUNCTION ace_cutover_review.discover_followups(text);
DROP TABLE ace_cutover_review.followup_discovery;
DROP FUNCTION ace_cutover_review.apply_followup_slot(text,text,text,bigint,int,int,int,int);
DROP FUNCTION ace_cutover_review.bind_schedule_duration(text,int,text),ace_cutover_review.projected_schedule_duration(text),ace_cutover_review.projected_overlap(bigint,int,bigint,int,int);
DROP TABLE ace_cutover_review.schedule_duration_evidence;
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
 SELECT (slot->>'court_number')::int INTO STRICT court FROM ace_cutover_review.source_slots WHERE match_id=NEW.id;
 FOR r IN SELECT * FROM (VALUES ('player'::text,NEW.player1),('player'::text,NEW.player2),('court'::text,jsonb_build_array(venue,court)::text)) AS v(kind,key) ORDER BY kind COLLATE "C",key COLLATE "C" LOOP
  INSERT INTO ace_cutover_review.active_source_resources VALUES(r.kind,r.key,NEW.id) ON CONFLICT DO NOTHING;
  IF NOT FOUND THEN RAISE EXCEPTION 'source resource conflict: %',r.kind; END IF;
  INSERT INTO ace_cutover_review.source_resource_history VALUES(NEW.id,r.kind,r.key,NEW.revision,NULL);
 END LOOP;
 RETURN NEW;
END $$;
DROP FUNCTION ace_cutover_review.apply_followup_delay(text,text,text,bigint,integer),ace_cutover_review.effective_schedule(text);
DROP TABLE ace_cutover_review.schedule_revisions;

DROP FUNCTION ace_cutover_review.bind_schedule_phase(text,text,int,int,int),ace_cutover_review.validate_schedule_candidate(text,int,int,int,int);
DROP TABLE ace_cutover_review.schedule_phase_policy;
