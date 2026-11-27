-- Disposable planning only; never grants routing authority.
BEGIN;
DO $guard$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $guard$;
CREATE FUNCTION ace_cutover_review.pilot_preflight(p_comp text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $pilot$
DECLARE c jsonb; clk ace_cutover_review.source_clock%ROWTYPE; issues text[]:='{}'; n int; entrants int; missing int; first_due bigint; venue text;
BEGIN
 SELECT contract INTO STRICT c FROM ace_cutover_review.source_contracts WHERE competition_id=p_comp;
 SELECT * INTO clk FROM ace_cutover_review.source_clock WHERE competition_id=p_comp;
 SELECT venue_id INTO venue FROM ace_cutover_review.source_venues WHERE competition_id=p_comp;
 IF (SELECT enabled FROM ace_cutover_review.policy WHERE singleton) THEN issues:=array_append(issues,'routing_enabled'); END IF;
 IF c->>'schema' IS DISTINCT FROM 'ace-frozen-source-admission-v1' OR c->>'draw_size' IS DISTINCT FROM '8' THEN issues:=array_append(issues,'unsupported_pilot_scope'); END IF;
 SELECT count(*) INTO n FROM ace_cutover_review.source_slots WHERE competition_id=p_comp;
 IF n<>7 THEN issues:=array_append(issues,'slot_inventory_mismatch'); END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.matches m WHERE m.competition=p_comp OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s WHERE s.competition_id=p_comp AND s.match_id=m.id)) OR EXISTS(SELECT 1 FROM ace_cutover_review.source_admissions a JOIN ace_cutover_review.source_slots s USING(match_id) WHERE s.competition_id=p_comp) THEN issues:=array_append(issues,'existing_match_or_admission'); END IF;
 IF EXISTS(SELECT 1 FROM ace_review.finalization_claims f WHERE f.competition_id=p_comp OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s WHERE s.competition_id=p_comp AND s.match_id=f.match_id)) OR EXISTS(SELECT 1 FROM ace_review.finalized_competitions f WHERE f.competition_id=p_comp) THEN issues:=array_append(issues,'existing_finalization'); END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s LEFT JOIN ace_cutover_review.source_observations o USING(match_id) WHERE s.competition_id=p_comp AND (o.revision IS DISTINCT FROM 0 OR o.payload->>'status' IS DISTINCT FROM 'scheduled' OR o.payload->>'simulation' IS DISTINCT FROM 'none' OR o.payload->'started' IS DISTINCT FROM 'false'::jsonb OR o.payload->>'winner_id' IS NOT NULL OR o.payload->>'player1_id' IS DISTINCT FROM s.slot->>'player1_id' OR o.payload->>'player2_id' IS DISTINCT FROM s.slot->>'player2_id')) THEN issues:=array_append(issues,'source_observation_changed'); END IF;
 IF venue IS NULL THEN issues:=array_append(issues,'venue_missing'); END IF;
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_opt_in WHERE competition_id=p_comp) THEN issues:=array_append(issues,'career_scope_missing'); END IF;
 WITH p AS (SELECT DISTINCT v.player_id FROM ace_cutover_review.source_slots s CROSS JOIN LATERAL (VALUES(s.slot->>'player1_id'),(s.slot->>'player2_id')) v(player_id) WHERE s.competition_id=p_comp AND v.player_id IS NOT NULL)
 SELECT count(*),count(*) FILTER(WHERE cp.player_id IS NULL) INTO entrants,missing FROM p LEFT JOIN ace_cutover_review.source_career_players cp USING(player_id);
 IF entrants<>8 THEN issues:=array_append(issues,'entrant_inventory_mismatch'); END IF;
 IF missing<>0 THEN issues:=array_append(issues,'career_records_missing'); END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.active_source_resources ar WHERE ar.resource_kind='player' AND EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s WHERE s.competition_id=p_comp AND ar.resource_key IN(s.slot->>'player1_id',s.slot->>'player2_id'))) THEN issues:=array_append(issues,'entrant_resource_busy'); END IF;
 SELECT min((((c->>'season_number')::bigint-1)*366+2+((slot->>'scheduled_season_week')::bigint-1)*7+(slot->>'scheduled_day')::bigint-1)*86400+(slot->>'scheduled_start_minute')::bigint*60) INTO first_due FROM ace_cutover_review.source_slots WHERE competition_id=p_comp;
 IF clk.competition_id IS NULL THEN issues:=array_append(issues,'clock_missing');
 ELSIF clk.paused OR clk.captured_at<statement_timestamp()-interval '60 seconds' THEN issues:=array_append(issues,'clock_paused_or_stale');
 ELSIF first_due IS NULL OR clk.game_second>=first_due THEN issues:=array_append(issues,'first_match_due_or_past'); END IF;
 RETURN jsonb_build_object('schema','ace-pilot-preflight-v1','review_only',true,'production_ready',false,'activation_authorized',false,'competition_id',p_comp,'status',CASE WHEN cardinality(issues)=0 THEN 'isolated_preflight_matched' ELSE 'blocked_review' END,'blockers',to_jsonb(issues),'source_contract_sha256',c->>'sha256','expected_matches',n,'entrants',entrants,'missing_career_records',missing,'venue',venue,'clock_revision',clk.revision,'first_due_game_second',first_due,'manual_requirements',jsonb_build_array('explicit isolated pilot approval','verified backup and rollback rehearsal','independent source provenance','operator monitoring and stop procedure','current engine compatibility before production use'));
END $pilot$;
REVOKE ALL ON FUNCTION ace_cutover_review.pilot_preflight(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.pilot_preflight(text) TO ace_review_worker;
COMMIT;
