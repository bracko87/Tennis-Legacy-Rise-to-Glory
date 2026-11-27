-- Isolated pilot controls only. No production installation.
BEGIN;
DO $guard$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $guard$;
CREATE TABLE ace_cutover_review.pilot_sessions (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.source_contracts,
 approval jsonb NOT NULL,
 preflight jsonb NOT NULL,
 activated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 stopped_at timestamptz,
 stop_reason text,
 CHECK((stopped_at IS NULL)=(stop_reason IS NULL))
);
CREATE UNIQUE INDEX single_active_pilot ON ace_cutover_review.pilot_sessions ((true)) WHERE stopped_at IS NULL;
GRANT SELECT ON ace_cutover_review.pilot_sessions TO ace_review_worker;
-- Generic configure may not reroute a recorded pilot or expand an active pilot.
CREATE FUNCTION ace_cutover_review.guard_pilot_policy() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $fn$
DECLARE active_comp text;
BEGIN
 SELECT competition_id INTO active_comp FROM ace_cutover_review.pilot_sessions WHERE stopped_at IS NULL;
 IF active_comp IS NOT NULL AND (NEW.enabled IS DISTINCT FROM true OR NEW.competitions IS DISTINCT FROM ARRAY[active_comp]) THEN RAISE EXCEPTION 'active pilot requires guarded stop'; END IF;
 IF NEW.enabled AND EXISTS(SELECT 1 FROM ace_cutover_review.pilot_sessions WHERE stopped_at IS NOT NULL AND competition_id=ANY(NEW.competitions)) THEN RAISE EXCEPTION 'stopped pilot cannot be reactivated'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER guarded_pilot_policy BEFORE UPDATE ON ace_cutover_review.policy FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_pilot_policy();
-- admit_source already takes policy SHARE before comp lock, so stop serializes with new admissions.
CREATE FUNCTION ace_cutover_review.guard_stopped_pilot_admission() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $fn$
BEGIN
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.pilot_sessions p USING(competition_id) WHERE s.match_id=NEW.match_id AND p.stopped_at IS NOT NULL) THEN RAISE EXCEPTION 'pilot stopped: new admission frozen'; END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER stopped_pilot_admission BEFORE INSERT ON ace_cutover_review.source_admissions FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_stopped_pilot_admission();
CREATE FUNCTION ace_cutover_review.activate_pilot(p_comp text,p_expected jsonb,p_approval jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $fn$
DECLARE report jsonb; prior ace_cutover_review.pilot_sessions%ROWTYPE;
BEGIN
 PERFORM 1 FROM ace_cutover_review.policy WHERE singleton FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 SELECT * INTO prior FROM ace_cutover_review.pilot_sessions WHERE competition_id=p_comp;
 IF FOUND THEN
  IF prior.stopped_at IS NOT NULL THEN RAISE EXCEPTION 'stopped pilot cannot be reactivated'; END IF;
  IF prior.approval IS DISTINCT FROM p_approval OR prior.preflight IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'conflicting pilot activation'; END IF;
  RETURN jsonb_build_object('status','already_active','competition_id',p_comp,'production_ready',false);
 END IF;
 IF p_approval->>'schema' IS DISTINCT FROM 'ace-isolated-pilot-approval-v1' OR p_approval->>'competition_id' IS DISTINCT FROM p_comp OR p_approval->>'scope' IS DISTINCT FROM 'disposable-synthetic-only' OR p_approval->'explicit_approval' IS DISTINCT FROM 'true'::jsonb OR p_approval->'rollback_rehearsed' IS DISTINCT FROM 'true'::jsonb OR p_approval->'monitoring_ready' IS DISTINCT FROM 'true'::jsonb OR coalesce(p_approval->>'approval_reference','')='' THEN RAISE EXCEPTION 'explicit isolated pilot approval required'; END IF;
 report:=ace_cutover_review.pilot_preflight(p_comp);
 IF report->>'status' IS DISTINCT FROM 'isolated_preflight_matched' OR report IS DISTINCT FROM p_expected THEN RAISE EXCEPTION 'pilot preflight blocked or changed'; END IF;
 INSERT INTO ace_cutover_review.pilot_sessions(competition_id,approval,preflight) VALUES(p_comp,p_approval,report);
 UPDATE ace_cutover_review.policy SET enabled=true,competitions=ARRAY[p_comp] WHERE singleton;
 RETURN jsonb_build_object('status','activated_isolated','competition_id',p_comp,'production_ready',false);
END $fn$;
CREATE FUNCTION ace_cutover_review.stop_pilot(p_comp text,p_reason text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $fn$
DECLARE p ace_cutover_review.pilot_sessions%ROWTYPE;
BEGIN
 IF p_reason IS NULL OR btrim(p_reason)='' OR length(p_reason)>500 THEN RAISE EXCEPTION 'stop reason required'; END IF;
 PERFORM 1 FROM ace_cutover_review.policy WHERE singleton FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 SELECT * INTO STRICT p FROM ace_cutover_review.pilot_sessions WHERE competition_id=p_comp FOR UPDATE;
 IF p.stopped_at IS NOT NULL THEN
  IF p.stop_reason IS DISTINCT FROM p_reason THEN RAISE EXCEPTION 'conflicting stop reason'; END IF;
  RETURN jsonb_build_object('status','already_stopped','competition_id',p_comp,'production_ready',false);
 END IF;
 UPDATE ace_cutover_review.pilot_sessions SET stopped_at=clock_timestamp(),stop_reason=p_reason WHERE competition_id=p_comp;
 UPDATE ace_cutover_review.policy SET enabled=false,competitions='{}' WHERE singleton;
 RETURN jsonb_build_object('status','admissions_stopped','competition_id',p_comp,'production_ready',false);
END $fn$;
CREATE FUNCTION ace_cutover_review.pilot_monitor(p_comp text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $fn$
DECLARE p ace_cutover_review.pilot_sessions%ROWTYPE; life jsonb; drain jsonb;
BEGIN
 SELECT * INTO STRICT p FROM ace_cutover_review.pilot_sessions WHERE competition_id=p_comp;
 life:=ace_cutover_review.source_lifecycle(p_comp);drain:=ace_cutover_review.drain_status(p_comp);
 RETURN jsonb_build_object('schema','ace-pilot-monitor-v1','competition_id',p_comp,'state',CASE WHEN p.stopped_at IS NULL THEN 'active_isolated' ELSE 'admissions_stopped' END,'stop_reason',p.stop_reason,'lifecycle',life,'drain',drain,'can_retire_pilot',p.stopped_at IS NOT NULL AND drain->'can_retire_review_runtime'='true'::jsonb AND life->>'status'='matched_review','review_only',true,'production_ready',false);
END $fn$;
REVOKE ALL ON FUNCTION ace_cutover_review.guard_pilot_policy(),ace_cutover_review.guard_stopped_pilot_admission(),ace_cutover_review.activate_pilot(text,jsonb,jsonb),ace_cutover_review.stop_pilot(text,text),ace_cutover_review.pilot_monitor(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.activate_pilot(text,jsonb,jsonb),ace_cutover_review.stop_pilot(text,text),ace_cutover_review.pilot_monitor(text) TO ace_review_worker;
COMMIT;
