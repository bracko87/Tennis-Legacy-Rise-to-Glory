-- Read-only, consistent-statement audit of disposable source tournaments.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE FUNCTION ace_cutover_review.source_lifecycle(p_comp text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE c jsonb; rows jsonb; issues jsonb; rewards jsonb; closure jsonb; finalized boolean; routed boolean; career boolean; missing_count int; active_count int; terminal_count int; n int; reconciliation_count int; latest_day int;
BEGIN
 SELECT contract INTO STRICT c FROM ace_cutover_review.source_contracts WHERE competition_id=p_comp;
 SELECT enabled AND p_comp=ANY(competitions) INTO STRICT routed FROM ace_cutover_review.policy WHERE singleton;
 SELECT EXISTS(SELECT 1 FROM ace_cutover_review.source_career_opt_in WHERE competition_id=p_comp) INTO career;
 SELECT report INTO closure FROM ace_cutover_review.closure_audits WHERE competition_id=p_comp;
 SELECT EXISTS(SELECT 1 FROM ace_review.finalized_competitions WHERE competition_id=p_comp) INTO finalized;
 SELECT count(*),max((snapshot->>'observed_absolute_day')::int) INTO reconciliation_count,latest_day FROM ace_cutover_review.reward_reconciliations WHERE competition_id=p_comp;
 -- Same-day divergent snapshots remain visible; no arbitrary "latest" snapshot selection.
 SELECT coalesce(jsonb_agg(jsonb_build_object('snapshot_id',snapshot_id,'status',report->>'status','observed_absolute_day',snapshot->'observed_absolute_day') ORDER BY snapshot_id),'[]') INTO rewards FROM ace_cutover_review.reward_reconciliations WHERE competition_id=p_comp AND (snapshot->>'observed_absolute_day')::int=latest_day;
 WITH inventory AS (
  SELECT s.match_id,s.slot->>'draw_type' AS phase,s.round_number,s.match_number,m.status,m.owner,m.revision,m.started,a.owner AS admitted_owner, q.status AS projected_status,q.match_revision AS projected_revision,q.owner AS projected_owner,
   (SELECT count(*) FROM ace_cutover_review.active_source_resources ar WHERE ar.match_id=s.match_id) AS resources,
   (SELECT count(*) FROM ace_cutover_review.source_resource_history h WHERE h.match_id=s.match_id AND h.terminal_revision=m.revision) AS released,
   (SELECT count(*) FROM ace_cutover_review.source_rest_history h WHERE h.match_id=s.match_id) AS rest_history,
   EXISTS(SELECT 1 FROM ace_cutover_review.source_starts ss WHERE ss.match_id=s.match_id) AS has_start,
   EXISTS(SELECT 1 FROM ace_cutover_review.handoffs h WHERE h.match_id=s.match_id AND h.resolution IS NULL) AS unresolved,
   EXISTS(SELECT 1 FROM ace_cutover_review.source_career_batches b WHERE b.match_id=s.match_id AND b.terminal_revision=m.revision) AS career_batch,
   EXISTS(SELECT 1 FROM ace_cutover_review.source_no_play_career b WHERE b.match_id=s.match_id AND b.terminal_revision=m.revision) AS no_play,
   (SELECT count(*) FROM ace_cutover_review.source_career_effects ce WHERE ce.match_id=s.match_id) AS effects_count,
   EXISTS(SELECT 1 FROM ace_review.finalized_matches fm WHERE fm.match_id=s.match_id AND fm.competition_id=p_comp) AS settled
  FROM ace_cutover_review.source_slots s LEFT JOIN ace_cutover_review.source_admissions a USING(match_id) LEFT JOIN ace_cutover_review.matches m ON m.id=s.match_id AND m.competition=p_comp LEFT JOIN ace_cutover_review.source_result_projection q ON q.match_id=s.match_id WHERE s.competition_id=p_comp
 ), checks AS (
 SELECT *,array_remove(ARRAY[
  CASE WHEN status IS NULL THEN 'not_admitted' END,
  CASE WHEN status IS NOT NULL AND owner IS DISTINCT FROM admitted_owner THEN 'ownership_mismatch' END,
  CASE WHEN owner='legacy' THEN 'legacy_owned_review' END,
  CASE WHEN status IN ('scheduled','in_progress') THEN 'match_unfinished' END,
  CASE WHEN unresolved THEN 'handoff_pending' END,
  CASE WHEN status IN ('completed','walkover','bye','cancelled') AND (projected_revision IS DISTINCT FROM revision OR projected_status IS DISTINCT FROM status OR projected_owner IS DISTINCT FROM owner) THEN 'result_sync_pending' END,
  CASE WHEN status='in_progress' AND (resources<>3 OR NOT has_start) THEN 'active_resource_mismatch' END,
  CASE WHEN status IN ('completed','walkover','bye','cancelled') AND resources<>0 THEN 'terminal_resource_leak' END,
  CASE WHEN status='completed' AND started AND (released<>3 OR rest_history<>3 OR NOT has_start) THEN 'played_recovery_evidence_missing' END,
  CASE WHEN status IN ('completed','walkover','bye','cancelled') AND NOT started AND (has_start OR rest_history<>0 OR effects_count<>0) THEN 'nonplay_activity' END,
  CASE WHEN career AND status='completed' AND started AND (NOT career_batch OR effects_count<>2) THEN 'career_effects_pending' END,
  CASE WHEN career AND status='completed' AND NOT started AND NOT no_play THEN 'no_play_ack_pending' END,
  CASE WHEN status IN ('bye','walkover','cancelled') THEN 'special_reward_review' END,
  CASE WHEN finalized AND NOT settled THEN 'finalization_inventory_mismatch' END
 ]::text[],NULL) AS blockers FROM inventory
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('match_id',match_id,'phase',phase,'round',round_number,'number',match_number,'status',coalesce(status,'not_admitted'),'owner',owner,'revision',revision,'blockers',to_jsonb(blockers)) ORDER BY CASE phase WHEN 'qualification' THEN 0 ELSE 1 END,round_number,match_number),'[]'),count(*),count(*) FILTER(WHERE status IS NULL),count(*) FILTER(WHERE status IN ('scheduled','in_progress')),count(*) FILTER(WHERE status IN ('completed','walkover','bye','cancelled'))
 INTO rows,n,missing_count,active_count,terminal_count FROM checks;
 SELECT coalesce(jsonb_agg(jsonb_build_object('match_id',x->>'match_id','kind',b.value) ORDER BY x->>'match_id',b.value),'[]') INTO issues FROM jsonb_array_elements(rows) x CROSS JOIN LATERAL jsonb_array_elements_text(x->'blockers') b(value);
 IF closure IS NULL THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','closure_audit_missing')); ELSIF closure->>'status'<>'normal_legacy_candidates' THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','closure_blocked')); END IF;
 IF NOT finalized THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','settlement_pending')); END IF;
 IF NOT career THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','career_scope_not_enabled')); END IF;
 IF reconciliation_count=0 THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','reward_reconciliation_missing'));
 ELSIF jsonb_array_length(rewards)<>1 OR EXISTS(SELECT 1 FROM jsonb_array_elements(rewards) x WHERE x->>'status' IS DISTINCT FROM 'matched_review') THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','reward_reconciliation_unresolved')); END IF;
 RETURN jsonb_build_object('schema','ace-source-lifecycle-review-v1','review_only',true,'production_ready',false,'competition_id',p_comp,'routing_enabled',routed,'career_enabled',career,'expected_matches',n,'not_admitted',missing_count,'active_matches',active_count,'terminal_matches',terminal_count,'finalized_review',finalized,'closure_status',closure->>'status','latest_day_reconciliations',rewards,'matches',rows,'blockers',issues,'status',CASE WHEN jsonb_array_length(issues)=0 THEN 'matched_review' ELSE 'blocked_review' END);
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.source_lifecycle(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.source_lifecycle(text) TO ace_review_worker;
COMMIT;
