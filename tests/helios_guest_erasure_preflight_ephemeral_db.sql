-- H08 fail-closed erasure preflight assertions in disposable PostgreSQL ONLY.
-- No Auth deletion. Entire test rolls back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='40s';
DO $test$
DECLARE
 u_expired uuid:=gen_random_uuid();
 u_active uuid:=gen_random_uuid();
 u_converted uuid:=gen_random_uuid();
 u_paid uuid:=gen_random_uuid();
 u_match uuid:=gen_random_uuid();
 p_match uuid;
 v_ai uuid;
 v_comp uuid;
 v_result jsonb;
BEGIN
 INSERT INTO auth.users(id,is_anonymous)
 VALUES (u_expired,true),(u_active,true),(u_converted,false),
        (u_paid,true),(u_match,true);
 INSERT INTO control_center_private.tennis_guest_trials_v1(
   user_id,started_at,expires_at,retired_at,converted_at)
 VALUES
 (u_expired,now()-interval '15 days',now()-interval '1 day',now()-interval '1 day',null),
 (u_active,now()-interval '1 day',now()+interval '13 days',null,null),
 (u_converted,now()-interval '15 days',now()-interval '1 day',null,now()-interval '2 days'),
 (u_paid,now()-interval '15 days',now()-interval '1 day',now()-interval '1 day',null),
 (u_match,now()-interval '15 days',now()-interval '1 day',now()-interval '1 day',null);

 SELECT id INTO v_ai FROM public.players WHERE player_type='ai' LIMIT 1;
 SELECT id INTO v_comp FROM public.tournament_world_competitions LIMIT 1;
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES(u_match,'Fixture','Historical','DE','ATP','human') RETURNING id INTO p_match;

 INSERT INTO public.helios_fixture_billing_transactions(user_id,status)
 VALUES(u_paid,'completed');
 INSERT INTO public.helios_fixture_premium_memberships(user_id,status)
 VALUES(u_paid,'active');

 INSERT INTO public.tournament_matches(
  competition_id,round_number,round_label,match_number,bracket_size,
  scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,
  status,started_at,completed_at)
 VALUES(v_comp,1,'Final',91,2,1,1,p_match,v_ai,p_match,
   'completed',now()-interval '2 days',now()-interval '1 day');

 v_result:=control_center_private.helios_guest_erasure_preflight_fixture_v1(u_expired);
 IF v_result->>'candidate_eligible_for_future_review'<>'true'
 OR v_result->>'hard_delete_ready'<>'false'
 OR NOT (v_result->'blockers' ? 'full_schema_erasure_not_approved')
 THEN RAISE EXCEPTION 'Expired guest must remain deletion blocked: %',v_result; END IF;

 v_result:=control_center_private.helios_guest_erasure_preflight_fixture_v1(u_active);
 IF v_result->>'candidate_eligible_for_future_review'<>'false'
 OR NOT (v_result->'blockers' ? 'guest_trial_not_expired')
 OR NOT (v_result->'blockers' ? 'guest_not_retired')
 THEN RAISE EXCEPTION 'Active guest not protected: %',v_result; END IF;

 v_result:=control_center_private.helios_guest_erasure_preflight_fixture_v1(u_converted);
 IF v_result->>'candidate_eligible_for_future_review'<>'false'
 OR NOT (v_result->'blockers' ? 'converted_account')
 OR NOT (v_result->'blockers' ? 'not_anonymous_or_missing_account')
 THEN RAISE EXCEPTION 'Converted permanent account not protected: %',v_result; END IF;

 v_result:=control_center_private.helios_guest_erasure_preflight_fixture_v1(u_paid);
 IF v_result->>'hard_delete_ready'<>'false'
 OR NOT (v_result->'blockers' ? 'financial_transaction_review_required')
 OR NOT (v_result->'blockers' ? 'active_or_unsettled_paid_membership')
 THEN RAISE EXCEPTION 'Paid records not protected: %',v_result; END IF;

 v_result:=control_center_private.helios_guest_erasure_preflight_fixture_v1(u_match);
 IF v_result->>'hard_delete_ready'<>'false'
 OR NOT (v_result->'blockers' ? 'historical_match_preservation_not_approved')
 THEN RAISE EXCEPTION 'Completed match protection missing: %',v_result; END IF;

 v_result:=control_center_private.helios_guest_erasure_preflight_fixture_v1(gen_random_uuid());
 IF v_result->>'hard_delete_ready'<>'false'
 OR NOT (v_result->'blockers' ? 'not_anonymous_or_missing_account')
 OR NOT (v_result->'blockers' ? 'missing_guest_trial')
 THEN RAISE EXCEPTION 'Unknown identity not protected: %',v_result; END IF;

 IF (SELECT count(*) FROM auth.users WHERE id IN
 (u_expired,u_active,u_converted,u_paid,u_match))<>5
 THEN RAISE EXCEPTION 'Preflight accidentally deleted account'; END IF;

 RAISE NOTICE 'H08 PASS: expired, active, converted, payment, historical and unknown identity preflight remains fail-closed; no deletion';
END;
$test$;
ROLLBACK;
