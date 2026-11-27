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
-- Health classification is advisory only; no automatic stop or transfer of ownership.
-- Default grace is a provisional review threshold, not an approved production SLA.
CREATE FUNCTION ace_cutover_review.pilot_health(p_comp text,p_grace_seconds integer DEFAULT 900) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $health$
DECLARE mon jsonb; c ace_cutover_review.source_clock%ROWTYPE; contract jsonb; alerts jsonb; clock_state text; stale boolean; critical int; warnings int;
BEGIN
 IF p_grace_seconds IS NULL OR p_grace_seconds NOT BETWEEN 60 AND 86400 THEN RAISE EXCEPTION 'invalid monitoring grace'; END IF;
 mon:=ace_cutover_review.pilot_monitor(p_comp);
 SELECT * INTO c FROM ace_cutover_review.source_clock WHERE competition_id=p_comp;
 SELECT s.contract INTO STRICT contract FROM ace_cutover_review.source_contracts s WHERE competition_id=p_comp;
 stale:=c.competition_id IS NULL OR c.captured_at<statement_timestamp()-interval '60 seconds' OR c.captured_at>statement_timestamp();
 clock_state:=CASE WHEN stale THEN 'missing_or_stale' WHEN c.paused THEN 'paused' ELSE 'observed' END;
 WITH integrity AS (
 SELECT x->>'kind' AS kind,x->>'match_id' AS match_id,
 CASE WHEN x->>'kind' IN ('ownership_mismatch','active_resource_mismatch','terminal_resource_leak','nonplay_activity','finalization_inventory_mismatch') THEN 'critical' ELSE 'warning' END AS severity
 FROM jsonb_array_elements(mon->'lifecycle'->'blockers') x
 WHERE x->>'kind' IN ('ownership_mismatch','active_resource_mismatch','terminal_resource_leak','nonplay_activity','finalization_inventory_mismatch','result_sync_pending','played_recovery_evidence_missing','career_effects_pending','handoff_pending','reward_reconciliation_unresolved')
 ), overdue AS (
 SELECT CASE WHEN m.status='in_progress' THEN 'live_match_overdue' ELSE 'scheduled_match_overdue' END AS kind,m.id AS match_id,'warning'::text AS severity
 FROM ace_cutover_review.matches m JOIN ace_cutover_review.source_slots s ON s.match_id=m.id
 LEFT JOIN ace_cutover_review.source_starts st ON st.match_id=m.id
 WHERE m.competition=p_comp AND m.owner='ace' AND NOT stale AND NOT c.paused
 AND ((m.status='in_progress' AND st.game_second IS NOT NULL AND c.game_second>st.game_second+25200+p_grace_seconds)
 OR (m.status='scheduled' AND c.game_second>((((contract->>'season_number')::bigint-1)*366+2+((s.slot->>'scheduled_season_week')::bigint-1)*7+(s.slot->>'scheduled_day')::bigint-1)*86400+(s.slot->>'scheduled_start_minute')::bigint*60+p_grace_seconds)))
 ), all_alerts AS (
 SELECT * FROM integrity UNION ALL SELECT * FROM overdue
 UNION ALL SELECT 'clock_missing_or_stale',NULL::text,'warning' WHERE stale
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('kind',kind,'match_id',match_id,'severity',severity) ORDER BY severity,kind,match_id),'[]'::jsonb),count(*) FILTER(WHERE severity='critical'),count(*) FILTER(WHERE severity='warning') INTO alerts,critical,warnings FROM all_alerts;
 RETURN jsonb_build_object('schema','ace-pilot-health-v1','competition_id',p_comp,'review_only',true,'production_ready',false,'state',mon->>'state','clock_state',clock_state,'clock_revision',c.revision,'grace_game_seconds',p_grace_seconds,'alerts',alerts,'critical_count',critical,'warning_count',warnings,
 'recommendation',CASE WHEN critical>0 THEN 'operator_stop_review' WHEN warnings>0 THEN 'operator_investigation' ELSE 'no_detected_integrity_alert' END,
 'can_retire_pilot',mon->'can_retire_pilot','worker_heartbeat_verified',false,'automatic_stop',false);
END $health$;
REVOKE ALL ON FUNCTION ace_cutover_review.pilot_health(text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.pilot_health(text,integer) TO ace_review_worker;
COMMIT;
