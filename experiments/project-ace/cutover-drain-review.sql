-- Disposable review only. Runtime rollback assessment, not production migration.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
-- Scope null = global. Match-worker stop and full runtime retirement are distinct.
CREATE FUNCTION ace_cutover_review.drain_status(p_comp text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE enabled_now boolean; admissions text[]; outstanding jsonb; unresolved jsonb; awaiting_settlement jsonb; retained jsonb;
BEGIN
 SELECT enabled,competitions INTO STRICT enabled_now,admissions FROM ace_cutover_review.policy WHERE singleton;
 SELECT coalesce(jsonb_agg(jsonb_build_object('match_id',m.id,'competition_id',m.competition,'status',m.status,'revision',m.revision) ORDER BY m.id),'[]'::jsonb) INTO outstanding
 FROM ace_cutover_review.matches m WHERE m.owner='ace' AND (p_comp IS NULL OR m.competition=p_comp) AND m.status IN ('scheduled','in_progress');
 SELECT coalesce(jsonb_agg(jsonb_build_object('match_id',m.id,'event_key',h.event_key,'reason',h.reason) ORDER BY m.id,h.event_key),'[]'::jsonb) INTO unresolved
 FROM ace_cutover_review.matches m JOIN ace_cutover_review.handoffs h ON h.match_id=m.id
 WHERE m.owner='ace' AND (p_comp IS NULL OR m.competition=p_comp) AND h.resolution IS NULL;
 SELECT coalesce(jsonb_agg(p.competition_id ORDER BY p.competition_id),'[]'::jsonb) INTO awaiting_settlement
 FROM ace_cutover_review.protected_competitions p WHERE (p_comp IS NULL OR p.competition_id=p_comp)
 AND EXISTS(SELECT 1 FROM ace_cutover_review.matches m WHERE m.competition=p.competition_id AND m.owner='ace')
 AND NOT EXISTS(SELECT 1 FROM ace_review.finalized_competitions f WHERE f.competition_id=p.competition_id);
 SELECT coalesce(jsonb_agg(m.id ORDER BY m.id),'[]'::jsonb) INTO retained FROM ace_cutover_review.matches m
 WHERE m.owner='ace' AND (p_comp IS NULL OR m.competition=p_comp) AND m.status NOT IN ('scheduled','in_progress');
 RETURN jsonb_build_object('scope',p_comp,'routing_disabled',NOT enabled_now,'allowlist',to_jsonb(admissions),'unfinished_matches',outstanding,'unresolved_handoffs',unresolved,'unsettled_protected_competitions',awaiting_settlement,'retained_terminal_matches',retained,
 'can_stop_match_worker',NOT enabled_now AND jsonb_array_length(outstanding)=0 AND jsonb_array_length(unresolved)=0,
 'can_retire_review_runtime',NOT enabled_now AND jsonb_array_length(outstanding)=0 AND jsonb_array_length(unresolved)=0 AND jsonb_array_length(awaiting_settlement)=0);
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.drain_status(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.drain_status(text) TO ace_review_worker;
COMMIT;
