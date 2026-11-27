-- Disposable review only; no official rewards, ranking or competition updates.
BEGIN;
DO $$ BEGIN IF current_database()<>'ace_review' THEN RAISE EXCEPTION 'isolated ace_review required'; END IF; END $$;
CREATE TABLE ace_cutover_review.closure_audits (
 competition_id text PRIMARY KEY REFERENCES ace_cutover_review.protected_competitions(competition_id),
 contract jsonb NOT NULL, report jsonb NOT NULL
);
GRANT SELECT ON ace_cutover_review.closure_audits TO ace_review_worker;
-- Controller supplies match metadata, player types, exact catalogue and publication day.
-- Database verifies all terminal receipts and derives legacy-trigger candidates.
CREATE FUNCTION ace_cutover_review.audit_special_closure(p_comp text,p_contract jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
DECLARE m ace_cutover_review.matches%ROWTYPE; prior ace_cutover_review.closure_audits%ROWTYPE; meta jsonb; player_meta jsonb; rule jsonb; final_meta jsonb; receipt jsonb; w text; loser text; participant text; stage text; label text; phase text; bonus integer; pts integer; prize bigint; pub integer; result_rows jsonb:='[]'; prize_rows jsonb:='[]'; skipped jsonb:='[]'; inventory jsonb:='[]'; blockers jsonb:='[]'; report jsonb;
BEGIN
 IF p_comp IS NULL OR jsonb_typeof(p_contract->'matches') IS DISTINCT FROM 'array' OR jsonb_typeof(p_contract->'players') IS DISTINCT FROM 'array' OR jsonb_typeof(p_contract->'rewards') IS DISTINCT FROM 'array' OR jsonb_typeof(p_contract->'ranking_publish_absolute_day') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'invalid closure contract'; END IF;
 pub:=(p_contract->>'ranking_publish_absolute_day')::integer;
 IF pub<0 THEN RAISE EXCEPTION 'invalid publication day'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_comp,91023));
 IF NOT EXISTS(SELECT 1 FROM ace_cutover_review.protected_competitions WHERE competition_id=p_comp) THEN RAISE EXCEPTION 'unregistered competition'; END IF;
 IF EXISTS(SELECT 1 FROM ace_cutover_review.cancellations WHERE competition_id=p_comp) THEN RAISE EXCEPTION 'cancelled competition requires refund review'; END IF;
 SELECT * INTO prior FROM ace_cutover_review.closure_audits WHERE competition_id=p_comp;
 IF FOUND THEN
  IF prior.contract IS DISTINCT FROM p_contract THEN RAISE EXCEPTION 'conflicting closure contract'; END IF;
  RETURN prior.report;
 END IF;
 PERFORM 1 FROM ace_cutover_review.matches WHERE competition=p_comp ORDER BY id FOR UPDATE;
 -- Imported closure must cover the immutable original inventory, not merely admitted rows.
 IF EXISTS(SELECT 1 FROM ace_cutover_review.source_contracts WHERE competition_id=p_comp) THEN
  IF EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s LEFT JOIN ace_cutover_review.matches cm ON cm.id=s.match_id AND cm.competition=s.competition_id WHERE s.competition_id=p_comp AND (cm.id IS NULL OR cm.status NOT IN ('completed','bye','walkover','cancelled'))) THEN RAISE EXCEPTION 'incomplete imported closure inventory'; END IF;
  IF EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s JOIN ace_cutover_review.source_contracts sc ON sc.competition_id=s.competition_id WHERE s.competition_id=p_comp AND NOT EXISTS(
    SELECT 1 FROM jsonb_array_elements(p_contract->'matches') x WHERE x->>'match_id'=s.match_id AND x->>'phase'=s.slot->>'draw_type' AND x->'round_number'=to_jsonb(s.round_number) AND lower(x->>'round_label')=CASE WHEN s.slot->>'draw_type'='qualification' THEN CASE WHEN s.round_number=coalesce((sc.contract->>'qualification_rounds')::int,1) THEN 'final qualifying' ELSE 'qualifying round '||s.round_number::text END ELSE CASE ((sc.contract->>'draw_size')::int/power(2,s.round_number-1)::int) WHEN 2 THEN 'final' WHEN 4 THEN 'semifinal' WHEN 8 THEN 'quarterfinal' ELSE 'round of '||((sc.contract->>'draw_size')::int/power(2,s.round_number-1)::int)::text END END
  )) THEN RAISE EXCEPTION 'imported closure topology mismatch'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_contract->'players'))<>(SELECT count(*) FROM ace_cutover_review.source_slots s CROSS JOIN LATERAL unnest(ARRAY[s.slot->>'player1_id',s.slot->>'player2_id']) v(pid) WHERE s.competition_id=p_comp AND s.round_number=1 AND v.pid IS NOT NULL)
  OR EXISTS(SELECT 1 FROM ace_cutover_review.source_slots s CROSS JOIN LATERAL unnest(ARRAY[s.slot->>'player1_id',s.slot->>'player2_id']) v(pid) WHERE s.competition_id=p_comp AND s.round_number=1 AND v.pid IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_contract->'players') x WHERE x->>'player_id'=v.pid)) THEN RAISE EXCEPTION 'imported closure player inventory mismatch'; END IF;
 END IF;
 IF jsonb_array_length(p_contract->'matches')=0 OR (SELECT count(*) FROM ace_cutover_review.matches WHERE competition=p_comp)<>jsonb_array_length(p_contract->'matches') OR (SELECT count(DISTINCT x->>'match_id') FROM jsonb_array_elements(p_contract->'matches') x)<>jsonb_array_length(p_contract->'matches') THEN RAISE EXCEPTION 'incomplete match inventory'; END IF;
 IF (SELECT count(DISTINCT x->>'player_id') FROM jsonb_array_elements(p_contract->'players') x)<>jsonb_array_length(p_contract->'players') OR (SELECT count(DISTINCT x->>'stage_code') FROM jsonb_array_elements(p_contract->'rewards') x)<>jsonb_array_length(p_contract->'rewards') THEN RAISE EXCEPTION 'duplicate contract rows'; END IF;
 SELECT x INTO STRICT final_meta FROM jsonb_array_elements(p_contract->'matches') x WHERE x->>'phase'='main_draw' AND lower(x->>'round_label')='final';
 FOR meta IN SELECT value FROM jsonb_array_elements(p_contract->'matches') ORDER BY value->>'match_id' LOOP
  SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=meta->>'match_id' AND competition=p_comp;
  IF m.owner IS DISTINCT FROM 'ace' OR EXISTS(SELECT 1 FROM ace_cutover_review.handoffs h WHERE h.match_id=m.id AND h.resolution IS NULL) THEN RAISE EXCEPTION 'unresolved ownership or handoff'; END IF;
  phase:=meta->>'phase';label:=lower(meta->>'round_label');
  IF phase IS NULL OR phase NOT IN ('main_draw','qualification') OR label IS NULL OR label='' OR jsonb_typeof(meta->'round_number') IS DISTINCT FROM 'number' OR (meta->>'round_number')::int<1 THEN RAISE EXCEPTION 'invalid round metadata'; END IF;
  receipt:=ace_cutover_review.terminal_feeder(m.id,p_comp);
  w:=receipt->>'winner_id';
  IF m.status='completed' THEN
   IF w IS NULL OR w NOT IN(m.player1,m.player2) THEN RAISE EXCEPTION 'invalid completed winner'; END IF;
   loser:=CASE WHEN w=m.player1 THEN m.player2 ELSE m.player1 END;
  ELSE
   loser:=NULL;
  END IF;
  inventory:=inventory||jsonb_build_array(jsonb_build_object('match_id',m.id,'status',m.status,'winner_id',w,'phase',phase,'round_label',label));
  -- The checked-in legacy finalizer explicitly requires status=completed.
  IF m.status<>'completed' THEN
   skipped:=skipped||jsonb_build_array(jsonb_build_object('match_id',m.id,'status',m.status,'winner_id',w,'reason','legacy_trigger_not_completed'));
   CONTINUE;
  END IF;
  FOR participant IN SELECT v FROM unnest(ARRAY[loser,CASE WHEN phase='main_draw' AND label='final' THEN w ELSE NULL END]) AS u(v) WHERE v IS NOT NULL LOOP
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(result_rows) x WHERE x->>'player_id'=participant) THEN RAISE EXCEPTION 'duplicate terminal player'; END IF;
   IF participant=w THEN stage:='winner';
   ELSIF phase='qualification' THEN stage:=CASE WHEN label LIKE 'final qualifying%' THEN 'qualifying_final_loss' ELSE 'qualifying_round_'||(meta->>'round_number')||'_loss' END;
   ELSE stage:=CASE label WHEN 'final' THEN 'runner_up' WHEN 'semifinal' THEN 'semifinal' WHEN 'quarterfinal' THEN 'quarterfinal' WHEN 'round of 16' THEN 'round_16' WHEN 'round of 32' THEN 'round_32' WHEN 'round of 64' THEN 'round_64' WHEN 'round of 128' THEN 'round_128' ELSE 'other' END;
   END IF;
   SELECT x INTO STRICT player_meta FROM jsonb_array_elements(p_contract->'players') x WHERE x->>'player_id'=participant;
   IF player_meta->>'player_type' IS NULL OR player_meta->>'player_type' NOT IN ('human','ai') THEN RAISE EXCEPTION 'invalid player type'; END IF;
   SELECT x INTO STRICT rule FROM jsonb_array_elements(p_contract->'rewards') x WHERE x->>'stage_code'=stage;
   IF jsonb_typeof(rule->'ranking_points') IS DISTINCT FROM 'number' OR jsonb_typeof(rule->'prize_money_usd') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'invalid reward rule'; END IF;
   pts:=(rule->>'ranking_points')::int;prize:=(rule->>'prize_money_usd')::bigint;bonus:=0;
   IF pts<0 OR prize<0 THEN RAISE EXCEPTION 'invalid reward amount'; END IF;
   IF phase='main_draw' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p_contract->'matches') q JOIN ace_cutover_review.matches qm ON qm.id=q->>'match_id' AND qm.competition=p_comp JOIN ace_cutover_review.effects qe ON qe.match_id=qm.id AND qe.engine=qm.owner WHERE q->>'phase'='qualification' AND lower(q->>'round_label') LIKE 'final qualifying%' AND qm.status='completed' AND qe.winner=participant) THEN
    SELECT x INTO STRICT rule FROM jsonb_array_elements(p_contract->'rewards') x WHERE x->>'stage_code'='qualified_bonus';
    bonus:=(rule->>'ranking_points')::int;IF bonus IS NULL OR bonus<0 THEN RAISE EXCEPTION 'invalid qualification bonus'; END IF;
   END IF;
   result_rows:=result_rows||jsonb_build_array(jsonb_build_object('player_id',participant,'match_id',m.id,'competition_id',p_comp,'result_stage_code',stage,'ranking_points_earned',pts+bonus,'qualifying_bonus_points',bonus,'prize_money_earned',prize,'ranking_publish_status','pending','ranking_publish_absolute_day',pub));
   IF player_meta->>'player_type'='human' AND prize>0 THEN
    prize_rows:=prize_rows||jsonb_build_array(jsonb_build_object('player_id',participant,'amount',prize,'idempotency_key','tournament-prize:'||p_comp||':'||participant,'source_id',p_comp));
   END IF;
  END LOOP;
 END LOOP;
 SELECT * INTO STRICT m FROM ace_cutover_review.matches WHERE id=final_meta->>'match_id' AND competition=p_comp;
 receipt:=ace_cutover_review.terminal_feeder(m.id,p_comp);
 IF m.status<>'completed' THEN blockers:=blockers||jsonb_build_array('final_not_completed_under_legacy_reward_trigger'); END IF;
 IF receipt->>'winner_id' IS NULL THEN blockers:=blockers||jsonb_build_array('no_champion'); END IF;
 IF jsonb_array_length(skipped)>0 THEN blockers:=blockers||jsonb_build_array('special_terminal_reward_policy_requires_review'); END IF;
 report:=jsonb_build_object('schema','ace-special-closure-review-v1','competition_id',p_comp,'review_only',true,'production_ready',false,'status',CASE WHEN jsonb_array_length(blockers)>0 THEN 'blocked_special_results' ELSE 'normal_legacy_candidates' END,'champion_candidate_id',receipt->>'winner_id','inventory',inventory,'legacy_result_candidates',result_rows,'legacy_prize_candidates',prize_rows,'skipped_matches',skipped,'blockers',blockers);
 INSERT INTO ace_cutover_review.closure_audits VALUES(p_comp,p_contract,report);
 RETURN report;
END $$;
-- Frozen audit must not silently become incomplete by adding new matches.
CREATE FUNCTION ace_cutover_review.guard_closure_audit_seed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ace_cutover_review AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM ace_cutover_review.closure_audits WHERE competition_id=NEW.competition) THEN RAISE EXCEPTION 'closure inventory frozen'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER z_closure_audit_seed BEFORE INSERT ON ace_cutover_review.matches FOR EACH ROW EXECUTE FUNCTION ace_cutover_review.guard_closure_audit_seed();
REVOKE ALL ON FUNCTION ace_cutover_review.audit_special_closure(text,jsonb),ace_cutover_review.guard_closure_audit_seed() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ace_cutover_review.audit_special_closure(text,jsonb) TO ace_review_worker;
COMMIT;
