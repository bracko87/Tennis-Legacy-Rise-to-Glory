-- Disposable imported-match recovery only. No official calendar or career writes.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.source_rest_history (
 match_id text NOT NULL REFERENCES ace_cutover_review.source_admissions(match_id),
 resource_kind text NOT NULL CHECK(resource_kind IN ('player','court')),
 resource_key text NOT NULL,
 competition_id text NOT NULL,
 start_second bigint NOT NULL,
 end_second bigint NOT NULL CHECK(end_second>=start_second),
 ready_second bigint NOT NULL CHECK(ready_second>=end_second),
 PRIMARY KEY(match_id,resource_kind,resource_key)
);
CREATE INDEX source_rest_resource_idx ON ace_cutover_review.source_rest_history(resource_kind,resource_key,ready_second);
GRANT SELECT ON ace_cutover_review.source_rest_history TO ace_review_worker;
-- Trigger executes after the reservation trigger's ordered unique locks.
-- Completion inserts recovery history before releasing those same locks.
CREATE FUNCTION ace_cutover_review.guard_source_rest() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE st ace_cutover_review.source_starts%ROWTYPE; h record;
BEGIN
 IF OLD.status IS NOT DISTINCT FROM NEW.status OR NEW.status<>'in_progress' OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) THEN RETURN NEW; END IF;
 SELECT * INTO STRICT st FROM ace_cutover_review.source_starts WHERE match_id=NEW.id;
 FOR h IN SELECT rh.* FROM ace_cutover_review.source_rest_history rh JOIN ace_cutover_review.active_source_resources a USING(resource_kind,resource_key) WHERE a.match_id=NEW.id LOOP
  IF st.game_second<h.ready_second OR (h.resource_kind='player' AND h.competition_id<>NEW.competition AND h.start_second/86400=st.game_second/86400) THEN RAISE EXCEPTION 'source recovery conflict: %',h.resource_kind; END IF;
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER zzz_source_rest BEFORE UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_source_rest();
CREATE FUNCTION ace_cutover_review.record_source_rest() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE st ace_cutover_review.source_starts%ROWTYPE; c ace_cutover_review.source_clock%ROWTYPE; e jsonb; duration int; ending bigint; n int;
BEGIN
 IF OLD.status<>'in_progress' OR NEW.status NOT IN ('completed','walkover','bye','cancelled') OR NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions WHERE match_id=NEW.id) THEN RETURN NEW; END IF;
 SELECT * INTO STRICT st FROM ace_cutover_review.source_starts WHERE match_id=NEW.id;
 SELECT * INTO STRICT c FROM ace_cutover_review.source_clock WHERE competition_id=NEW.competition FOR SHARE;
 IF NEW.status<>'completed' THEN RAISE EXCEPTION 'live special completion requires reviewed recovery evidence'; END IF;
 SELECT receipt INTO STRICT e FROM ace_cutover_review.effects WHERE match_id=NEW.id;
 IF jsonb_typeof(e->'actual_duration_minutes') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'played duration required for source recovery'; END IF;
 duration:=(e->>'actual_duration_minutes')::int;
 IF duration NOT BETWEEN 60 AND 420 THEN RAISE EXCEPTION 'invalid played duration'; END IF;
 ending:=greatest(st.game_second+duration::bigint*60,c.game_second);
 INSERT INTO ace_cutover_review.source_rest_history
 SELECT NEW.id,a.resource_kind,a.resource_key,NEW.competition,st.game_second,ending,ending+CASE WHEN a.resource_kind='player' THEN 3600 ELSE 900 END
 FROM ace_cutover_review.active_source_resources a WHERE a.match_id=NEW.id;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>3 THEN RAISE EXCEPTION 'incomplete source recovery resources'; END IF;
 RETURN NEW;
END $$;
-- Alphabetical AFTER trigger order places this before zz_source_release.
CREATE TRIGGER source_rest_record AFTER UPDATE OF status ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.record_source_rest();
REVOKE ALL ON FUNCTION ace_cutover_review.guard_source_rest(),ace_cutover_review.record_source_rest() FROM PUBLIC;
COMMIT;
