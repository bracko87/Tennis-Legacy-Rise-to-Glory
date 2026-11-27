-- Disposable one-round qualification contract, explicit source final-to-main slots.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE FUNCTION ace_cutover_review.import_source_qualification(p jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE comp text:=p->>'competition_id'; n int; sz int; rr int; nn int; s jsonb; ph text; a text; b text; f text; player text; i int; used text[]:='{}'; entrants text[]:='{}'; prior jsonb; q_end bigint; t bigint;
BEGIN
 IF p->>'schema' IS DISTINCT FROM 'ace-frozen-source-qualification-v1' OR comp IS NULL OR comp='' OR coalesce(p->>'sha256','') !~ '^[a-f0-9]{64}$' OR jsonb_typeof(p->'matches') IS DISTINCT FROM 'array' OR jsonb_typeof(p->'draw_size') IS DISTINCT FROM 'number' OR jsonb_typeof(p->'qualification_count') IS DISTINCT FROM 'number' OR jsonb_typeof(p->'season_number') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'invalid qualification contract'; END IF;
 sz:=(p->>'draw_size')::int;n:=(p->>'qualification_count')::int;
 IF sz NOT IN(8,16,32,64,128) OR n NOT BETWEEN 1 AND sz OR (p->>'season_number')::int NOT BETWEEN 1 AND 10000 OR jsonb_array_length(p->'matches')<>sz-1+n OR (SELECT count(DISTINCT x->>'match_id') FROM jsonb_array_elements(p->'matches') x)<>sz-1+n THEN RAISE EXCEPTION 'invalid qualification inventory'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(comp,91023));
 SELECT contract INTO prior FROM ace_cutover_review.source_contracts WHERE competition_id=comp;
 IF FOUND THEN IF prior IS DISTINCT FROM p THEN RAISE EXCEPTION 'conflicting source contract'; END IF;RETURN 'already_imported';END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=comp) THEN RAISE EXCEPTION 'source contract must precede protection';END IF;
 PERFORM ace_cutover_review.register_competition(comp);
 INSERT INTO ace_cutover_review.source_contracts VALUES(comp,p);
 FOR s IN SELECT value FROM jsonb_array_elements(p->'matches') ORDER BY CASE value->>'draw_type' WHEN 'qualification' THEN 0 ELSE 1 END,(value->>'round_number')::int,(value->>'match_number')::int LOOP
  ph:=s->>'draw_type';rr:=(s->>'round_number')::int;nn:=(s->>'match_number')::int;
  IF s->>'competition_id' IS DISTINCT FROM comp OR coalesce(s->>'match_id','')='' OR NOT(s ?& ARRAY['player1_id','player2_id','feeder1','feeder2']) OR ph IS NULL OR ph NOT IN('qualification','main_draw') OR rr IS NULL OR nn IS NULL OR rr<1 OR nn<1 OR (ph='qualification' AND (rr<>1 OR nn>n)) OR (ph='main_draw' AND (rr>log(2,sz)::int OR nn>sz/power(2,rr)::int)) OR coalesce((s->>'scheduled_season_week')::int,0) NOT BETWEEN 1 AND 52 OR coalesce((s->>'scheduled_day')::int,0) NOT BETWEEN 1 AND 7 OR coalesce((s->>'scheduled_start_minute')::int,-1) NOT BETWEEN 0 AND 1439 OR coalesce((s->>'court_number')::int,0)<1 THEN RAISE EXCEPTION 'invalid qualification slot'; END IF;
  a:=s->>'feeder1';b:=s->>'feeder2';t:=((s->>'scheduled_season_week')::int*7+(s->>'scheduled_day')::int)*1440+(s->>'scheduled_start_minute')::int;
  IF ph='qualification' THEN
   IF a IS NOT NULL OR b IS NOT NULL THEN RAISE EXCEPTION 'one qualification round only';END IF;
   q_end:=greatest(q_end,t);
  ELSIF rr=1 THEN
   IF q_end IS NULL OR t<=q_end THEN RAISE EXCEPTION 'qualification must precede main draw';END IF;
  ELSE
   IF s->>'player1_id' IS NOT NULL OR s->>'player2_id' IS NOT NULL OR a IS NULL OR b IS NULL OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots z WHERE z.match_id=a AND z.competition_id=comp AND z.slot->>'draw_type'='main_draw' AND z.round_number=rr-1 AND z.match_number=2*nn-1) OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots z WHERE z.match_id=b AND z.competition_id=comp AND z.slot->>'draw_type'='main_draw' AND z.round_number=rr-1 AND z.match_number=2*nn) THEN RAISE EXCEPTION 'invalid main feeder';END IF;
  END IF;
  IF rr=1 THEN
   FOR i IN 1..2 LOOP
    f:=s->>('feeder'||i);player:=s->>('player'||i||'_id');
    IF f IS NULL THEN
     IF player IS NULL OR player='' OR player=ANY(entrants) THEN RAISE EXCEPTION 'invalid entrant';END IF;entrants:=array_append(entrants,player);
    ELSE
     IF ph<>'main_draw' OR player IS NOT NULL OR f=ANY(used) OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_slots z WHERE z.match_id=f AND z.competition_id=comp AND z.slot->>'draw_type'='qualification') THEN RAISE EXCEPTION 'invalid qualifier mapping';END IF;used:=array_append(used,f);
    END IF;
   END LOOP;
  END IF;
  IF EXISTS(SELECT 1 FROM ace_cutover_review.matches WHERE id=s->>'match_id') THEN RAISE EXCEPTION 'source match identity already occupied';END IF;
  INSERT INTO ace_cutover_review.source_slots VALUES(s->>'match_id',comp,rr,nn,s,a,b);
  INSERT INTO ace_cutover_review.source_observations(match_id,payload) VALUES(s->>'match_id',jsonb_build_object('player1_id',s->>'player1_id','player2_id',s->>'player2_id','status','scheduled','simulation','none','started',false,'winner_id',NULL));
 END LOOP;
 IF cardinality(used)<>n OR cardinality(entrants)<>sz+n OR (SELECT count(*) FROM ace_cutover_review.source_slots WHERE competition_id=comp AND slot->>'draw_type'='qualification')<>n THEN RAISE EXCEPTION 'incomplete qualification mapping';END IF;
 RETURN 'imported';
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.import_source_qualification(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.import_source_qualification(jsonb) TO ace_review_worker;
COMMIT;
