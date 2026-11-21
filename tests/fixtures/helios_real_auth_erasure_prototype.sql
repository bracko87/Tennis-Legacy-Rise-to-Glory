-- Executable CI-only account erasure prototype.
-- Representative schema only: NOT deployable and never an erasure endpoint.
-- Invoker permissions, private schema, explicit fixture marker required.
CREATE FUNCTION control_center_private.helios_ci_erase_retired_guest(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
AS $fn$
DECLARE p uuid;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM control_center_private.helios_real_auth_ci_marker WHERE id)
 THEN RAISE EXCEPTION 'Not the disposable fixture'; END IF;
 PERFORM 1 FROM auth.users WHERE id=p_user AND is_anonymous FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Not an anonymous identity' USING errcode='42501'; END IF;
 PERFORM 1 FROM control_center_private.tennis_guest_trials_v1
 WHERE user_id=p_user AND expires_at<=now() AND converted_at IS NULL AND retired_at IS NOT NULL
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Not eligible for erasure' USING errcode='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.billing_transactions WHERE user_id=p_user)
 OR EXISTS(SELECT 1 FROM public.premium_memberships WHERE user_id=p_user)
 THEN RAISE EXCEPTION 'Financial records need separate retention review'; END IF;
 SELECT id INTO STRICT p FROM public.players WHERE owner_user_id=p_user AND player_type='human' AND moderation_status='rejected';
 IF EXISTS(SELECT 1 FROM public.tournament_matches
 WHERE p IN(player1_id,player2_id) AND status IN('scheduled','in_progress'))
 OR EXISTS(SELECT 1 FROM public.tournament_doubles_matches m JOIN public.tournament_doubles_teams t
 ON t.id IN(m.team1_id,m.team2_id) WHERE p IN(t.player1_id,t.player2_id) AND m.status IN('scheduled','in_progress'))
 OR EXISTS(SELECT 1 FROM public.tournament_entries WHERE player_id=p AND entry_status='active')
 OR EXISTS(SELECT 1 FROM public.tournament_applications WHERE player_id=p AND status IN('applied','accepted_main_draw','accepted_qualification'))
 THEN RAISE EXCEPTION 'Unfinished competition activity'; END IF;
 -- Keep a detached non-playable historical participant and result FKs.
 DELETE FROM public.helios_ci_equipment WHERE player_id=p;
 DELETE FROM public.helios_ci_career_finance WHERE player_id=p;
 UPDATE public.players SET owner_user_id=NULL,first_name='Retired',last_name='Guest',
  image_path=NULL,home_city=NULL WHERE id=p;
 DELETE FROM public.tennis_premium_trials_v1 WHERE user_id=p_user;
 DELETE FROM public.tennis_premium_trial_claims_v1 WHERE email_claim_hash=md5('tennis-guest-premium-v1:'||p_user::text)
 AND NOT EXISTS(SELECT 1 FROM public.tennis_premium_trials_v1 WHERE email_claim_hash=md5('tennis-guest-premium-v1:'||p_user::text));
 DELETE FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=p_user;
 DELETE FROM auth.users WHERE id=p_user;
 IF NOT FOUND THEN RAISE EXCEPTION 'Auth deletion failed'; END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION control_center_private.helios_ci_erase_retired_guest(uuid) FROM PUBLIC,anon,authenticated;
