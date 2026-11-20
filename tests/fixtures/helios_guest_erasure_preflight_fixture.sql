-- H08 proof ONLY: ephemeral-schema guarded erasure preflight.
-- Not a production migration and not a privileged deletion endpoint.
-- Returns only non-identifying blocker codes. It NEVER deletes rows.
-- The returned hard_delete_ready flag is ALWAYS false until the full
-- 180-table review, production authorization and full-schema E2E complete.
CREATE TABLE public.helios_fixture_billing_transactions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES auth.users(id),
 status text NOT NULL
);
CREATE TABLE public.helios_fixture_premium_memberships (
 user_id uuid NOT NULL REFERENCES auth.users(id),
 status text NOT NULL
);

CREATE OR REPLACE FUNCTION control_center_private.helios_guest_erasure_preflight_fixture_v1(
 p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $func$
DECLARE
 v_auth_anonymous boolean;
 v_trial record;
 v_player_ids uuid[];
 v_blockers jsonb:='[]'::jsonb;
 v_candidate boolean:=false;
BEGIN
 SELECT u.is_anonymous INTO v_auth_anonymous
 FROM auth.users u WHERE u.id=p_user_id;

 SELECT started_at,expires_at,retired_at,converted_at
 INTO v_trial FROM control_center_private.tennis_guest_trials_v1
 WHERE user_id=p_user_id;

 IF v_auth_anonymous IS DISTINCT FROM true
 THEN v_blockers:=v_blockers || '["not_anonymous_or_missing_account"]'::jsonb; END IF;
 IF NOT FOUND OR v_trial.started_at IS NULL
 THEN v_blockers:=v_blockers || '["missing_guest_trial"]'::jsonb;
 ELSE
  IF v_trial.expires_at>now()
  THEN v_blockers:=v_blockers || '["guest_trial_not_expired"]'::jsonb; END IF;
  IF v_trial.retired_at IS NULL
  THEN v_blockers:=v_blockers || '["guest_not_retired"]'::jsonb; END IF;
  IF v_trial.converted_at IS NOT NULL
  THEN v_blockers:=v_blockers || '["converted_account"]'::jsonb; END IF;
 END IF;

 SELECT array_agg(id) INTO v_player_ids
 FROM public.players WHERE owner_user_id=p_user_id AND player_type='human';

 IF EXISTS(
  SELECT 1 FROM public.helios_fixture_billing_transactions
  WHERE user_id=p_user_id
 ) THEN v_blockers:=v_blockers || '["financial_transaction_review_required"]'::jsonb; END IF;
 IF EXISTS(
  SELECT 1 FROM public.helios_fixture_premium_memberships
  WHERE user_id=p_user_id AND status IN ('active','trialing','past_due')
 ) THEN v_blockers:=v_blockers || '["active_or_unsettled_paid_membership"]'::jsonb; END IF;
 IF EXISTS(
  SELECT 1 FROM public.tournament_matches m
  WHERE m.status='in_progress' AND
   (m.player1_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])) OR m.player2_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])))
 ) THEN v_blockers:=v_blockers || '["singles_in_progress"]'::jsonb; END IF;
 IF EXISTS(
  SELECT 1 FROM public.tournament_doubles_matches m
  WHERE m.status='in_progress' AND
   EXISTS(SELECT 1 FROM public.tournament_doubles_teams t
    WHERE t.id IN(m.team1_id,m.team2_id)
     AND (t.player1_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])) OR t.player2_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[]))))
 ) THEN v_blockers:=v_blockers || '["doubles_in_progress"]'::jsonb; END IF;
 IF EXISTS(
  SELECT 1 FROM public.tournament_matches m
  WHERE m.status='completed' AND
   (m.player1_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])) OR m.player2_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])))
 ) OR EXISTS(
  SELECT 1 FROM public.tournament_doubles_matches m
  JOIN public.tournament_doubles_teams t ON t.id IN(m.team1_id,m.team2_id)
  WHERE m.status='completed' AND
   (t.player1_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])) OR t.player2_id=ANY(coalesce(v_player_ids,ARRAY[]::uuid[])))
 ) THEN v_blockers:=v_blockers || '["historical_match_preservation_not_approved"]'::jsonb; END IF;

 v_candidate := v_auth_anonymous IS TRUE AND
   v_trial.expires_at<=now() AND v_trial.retired_at IS NOT NULL AND
   v_trial.converted_at IS NULL;
 v_blockers:=v_blockers || '["full_schema_erasure_not_approved"]'::jsonb;
 RETURN jsonb_build_object(
  'candidate_eligible_for_future_review',v_candidate,
  'hard_delete_ready',false,
  'blockers',v_blockers
 );
END;
$func$;

REVOKE ALL ON FUNCTION control_center_private.helios_guest_erasure_preflight_fixture_v1(uuid)
 FROM PUBLIC, anon, authenticated;
