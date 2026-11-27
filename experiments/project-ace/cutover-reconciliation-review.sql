-- Disposable review only. No official result, finance or ranking writes.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.reward_reconciliations (
 competition_id text NOT NULL REFERENCES ace_cutover_review.closure_audits(competition_id),
 snapshot_id text NOT NULL CHECK(length(snapshot_id)>0),
 snapshot jsonb NOT NULL,
 report jsonb NOT NULL,
 PRIMARY KEY(competition_id,snapshot_id)
);
GRANT SELECT ON ace_cutover_review.reward_reconciliations TO ace_review_worker;

-- Snapshot must be a consistent, complete competition-scoped export, including
-- prize-key collisions even where the stored source_id is wrong. Not a live query.
CREATE FUNCTION ace_cutover_review.reconcile_rewards(p_comp text,p_snapshot_id text,p_snapshot jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE a ace_cutover_review.closure_audits%ROWTYPE; prior ace_cutover_review.reward_reconciliations%ROWTYPE;
 expected jsonb; actual jsonb; tx jsonb; expected_tx jsonb; contribution jsonb; candidate jsonb;
 day integer; pub integer; season integer; series text; world text; pid text; result_code text;
 result_state text; prize_state text; rank_state text; rows jsonb:='[]'; issues jsonb:='[]'; report jsonb;
BEGIN
 IF p_comp IS NULL OR p_snapshot_id IS NULL OR btrim(p_snapshot_id)='' OR p_snapshot->>'competition_id' IS DISTINCT FROM p_comp
 OR p_snapshot->'complete_export' IS DISTINCT FROM 'true'::jsonb OR jsonb_typeof(p_snapshot->'results') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_snapshot->'prizes') IS DISTINCT FROM 'array' OR jsonb_typeof(p_snapshot->'contributions') IS DISTINCT FROM 'array'
 OR jsonb_typeof(p_snapshot->'observed_absolute_day') IS DISTINCT FROM 'number'
 OR jsonb_typeof(p_snapshot->'season_number') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'complete scoped snapshot required'; END IF;
 day:=(p_snapshot->>'observed_absolute_day')::int; season:=(p_snapshot->>'season_number')::int; series:=p_snapshot->>'tournament_series_id';world:=p_snapshot->>'world';
 IF day<0 OR season<1 OR series IS NULL OR series='' OR world IS NULL OR world NOT IN ('ATP','WTA') THEN RAISE EXCEPTION 'invalid snapshot identity'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 SELECT * INTO STRICT a FROM ace_cutover_review.closure_audits WHERE competition_id=p_comp;
 SELECT * INTO prior FROM ace_cutover_review.reward_reconciliations WHERE competition_id=p_comp AND snapshot_id=p_snapshot_id;
 IF FOUND THEN
  IF prior.snapshot IS DISTINCT FROM p_snapshot THEN RAISE EXCEPTION 'conflicting reconciliation snapshot'; END IF;
  RETURN prior.report;
 END IF;
 -- Reject duplicate or missing identities, never choose an arbitrary winner.
 IF (SELECT count(DISTINCT x->>'player_id') FROM jsonb_array_elements(p_snapshot->'results') x)<>jsonb_array_length(p_snapshot->'results')
 OR (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p_snapshot->'results') x)<>jsonb_array_length(p_snapshot->'results')
 OR (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p_snapshot->'prizes') x)<>jsonb_array_length(p_snapshot->'prizes')
 OR (SELECT count(DISTINCT (x->>'player_id',x->>'idempotency_key')) FROM jsonb_array_elements(p_snapshot->'prizes') x)<>jsonb_array_length(p_snapshot->'prizes')
 OR (SELECT count(DISTINCT x->>'source_result_id') FROM jsonb_array_elements(p_snapshot->'contributions') x)<>jsonb_array_length(p_snapshot->'contributions')
 OR (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p_snapshot->'contributions') x)<>jsonb_array_length(p_snapshot->'contributions') THEN RAISE EXCEPTION 'duplicate or missing snapshot identity'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_snapshot->'results') x WHERE x->>'competition_id' IS DISTINCT FROM p_comp)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_snapshot->'contributions') x WHERE x->>'competition_id' IS DISTINCT FROM p_comp)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_snapshot->'prizes') x WHERE x->>'player_id' IS NULL OR x->>'idempotency_key' IS NULL OR (x->>'source_id' IS DISTINCT FROM p_comp AND left(x->>'idempotency_key',length('tournament-prize:'||p_comp||':')) IS DISTINCT FROM 'tournament-prize:'||p_comp||':')) THEN RAISE EXCEPTION 'foreign snapshot row'; END IF;
 FOR expected IN SELECT value FROM jsonb_array_elements(a.report->'legacy_result_candidates') ORDER BY value->>'player_id' LOOP
  pid:=expected->>'player_id';pub:=(expected->>'ranking_publish_absolute_day')::int;
  result_code:=CASE WHEN expected->>'result_stage_code'='winner' THEN 'champion' WHEN left(expected->>'result_stage_code',11)='qualifying_' THEN 'qualifying' ELSE expected->>'result_stage_code' END;
  SELECT x INTO actual FROM jsonb_array_elements(p_snapshot->'results') x WHERE x->>'player_id'=pid;
  SELECT x INTO expected_tx FROM jsonb_array_elements(a.report->'legacy_prize_candidates') x WHERE x->>'player_id'=pid;
  SELECT x INTO tx FROM jsonb_array_elements(p_snapshot->'prizes') x WHERE x->>'player_id'=pid AND x->>'idempotency_key'='tournament-prize:'||p_comp||':'||pid;
  SELECT x INTO contribution FROM jsonb_array_elements(p_snapshot->'contributions') x WHERE x->>'source_result_id'=actual->>'id';
  IF actual IS NULL THEN result_state:='missing';
  ELSIF actual->>'result_stage_code' IS DISTINCT FROM expected->>'result_stage_code' OR actual->>'result_code' IS DISTINCT FROM result_code
   OR actual->'ranking_points_earned' IS DISTINCT FROM expected->'ranking_points_earned' OR actual->'qualifying_bonus_points' IS DISTINCT FROM expected->'qualifying_bonus_points'
   OR actual->'prize_money_earned' IS DISTINCT FROM expected->'prize_money_earned' OR actual->'ranking_publish_absolute_day' IS DISTINCT FROM expected->'ranking_publish_absolute_day'
   OR coalesce(actual->>'ranking_publish_status','') NOT IN ('pending','published') THEN result_state:='conflict';
  ELSE result_state:='matched'; END IF;
  IF expected_tx IS NULL THEN
   prize_state:=CASE WHEN tx IS NULL THEN 'not_required' ELSE 'unexpected' END;
  ELSIF tx IS NULL THEN prize_state:='missing';
  ELSIF result_state<>'matched' OR tx->'amount' IS DISTINCT FROM expected_tx->'amount' OR tx->>'category' IS DISTINCT FROM 'prize_money'
   OR tx->>'subcategory' IS DISTINCT FROM expected->>'result_stage_code' OR tx->>'source_type' IS DISTINCT FROM 'tournament_result'
   OR tx->>'source_id' IS DISTINCT FROM p_comp OR jsonb_typeof(tx->'balance_before') IS DISTINCT FROM 'number' OR jsonb_typeof(tx->'balance_after') IS DISTINCT FROM 'number'
   OR (tx->>'balance_after')::bigint-(tx->>'balance_before')::bigint IS DISTINCT FROM (expected_tx->>'amount')::bigint THEN prize_state:='conflict';
  ELSE prize_state:='already_posted'; END IF;
  IF result_state<>'matched' THEN rank_state:='blocked_result';
  ELSIF actual->>'ranking_publish_status'='pending' THEN
   rank_state:=CASE WHEN contribution IS NOT NULL THEN 'conflict' WHEN day>=pub THEN 'due_review' ELSE 'pending_not_due' END;
  ELSIF contribution IS NULL THEN rank_state:='missing_contribution';
  ELSIF day<pub OR contribution->>'player_id' IS DISTINCT FROM pid OR contribution->>'tournament_series_id' IS DISTINCT FROM series OR contribution->>'world' IS DISTINCT FROM world
   OR contribution->'season_number' IS DISTINCT FROM to_jsonb(season) OR contribution->'ranking_points' IS DISTINCT FROM expected->'ranking_points_earned'
   OR contribution->'awarded_absolute_day' IS DISTINCT FROM to_jsonb(pub) OR contribution->'expires_absolute_day' IS DISTINCT FROM to_jsonb(pub+366)
   OR jsonb_typeof(contribution->'is_active') IS DISTINCT FROM 'boolean' THEN rank_state:='conflict';
  ELSIF (contribution->>'is_active')::boolean THEN
   rank_state:=CASE WHEN day>=pub+366 THEN 'expiry_review' ELSE 'already_active' END;
  ELSE
   IF jsonb_typeof(contribution->'deactivated_absolute_day') IS DISTINCT FROM 'number' OR (contribution->>'deactivated_absolute_day')::int NOT BETWEEN pub AND day THEN rank_state:='conflict';ELSE rank_state:='historical_inactive';END IF;
  END IF;
  rows:=rows||jsonb_build_array(jsonb_build_object('player_id',pid,'result',result_state,'prize',prize_state,'ranking',rank_state,'result_id',actual->>'id','prize_transaction_id',tx->>'id','contribution_id',contribution->>'id'));
  IF result_state<>'matched' OR prize_state NOT IN ('already_posted','not_required') OR rank_state NOT IN ('pending_not_due','already_active','historical_inactive') THEN
   issues:=issues||jsonb_build_array(jsonb_build_object('kind','candidate_requires_review','player_id',pid,'result',result_state,'prize',prize_state,'ranking',rank_state));
  END IF;
 END LOOP;
 -- Existing results/payments absent from known candidates are protected, not deleted.
 FOR candidate IN SELECT value FROM jsonb_array_elements(p_snapshot->'results') LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.report->'legacy_result_candidates') x WHERE x->>'player_id'=candidate->>'player_id') THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','unmapped_existing_result','id',candidate->>'id','player_id',candidate->>'player_id')); END IF;
 END LOOP;
 FOR candidate IN SELECT value FROM jsonb_array_elements(p_snapshot->'prizes') LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a.report->'legacy_prize_candidates') x WHERE x->>'player_id'=candidate->>'player_id' AND x->>'idempotency_key'=candidate->>'idempotency_key') THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','unmapped_existing_prize','id',candidate->>'id','player_id',candidate->>'player_id')); END IF;
 END LOOP;
 FOR candidate IN SELECT value FROM jsonb_array_elements(p_snapshot->'contributions') LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_snapshot->'results') x WHERE x->>'id'=candidate->>'source_result_id' AND x->>'player_id'=candidate->>'player_id') THEN issues:=issues||jsonb_build_array(jsonb_build_object('kind','orphan_or_mismatched_contribution','id',candidate->>'id')); END IF;
 END LOOP;
 report:=jsonb_build_object('schema','ace-reward-reconciliation-v1','competition_id',p_comp,'snapshot_id',p_snapshot_id,'review_only',true,'production_ready',false,'status',CASE WHEN jsonb_array_length(a.report->'blockers')>0 OR jsonb_array_length(issues)>0 THEN 'blocked_review' ELSE 'matched_review' END,'players',rows,'issues',issues,'closure_blockers',a.report->'blockers');
 INSERT INTO ace_cutover_review.reward_reconciliations VALUES(p_comp,p_snapshot_id,p_snapshot,report);
 RETURN report;
END $$;
REVOKE ALL ON FUNCTION ace_cutover_review.reconcile_rewards(text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.reconcile_rewards(text,text,jsonb) TO ace_review_worker;
COMMIT;
