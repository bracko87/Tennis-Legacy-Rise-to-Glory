-- H08 — Issue exactly one seven-day Premium entitlement, atomically with
-- the server-owned fourteen-day guest signup; public rollout remains OFF.
-- No real auth.users or existing permanent-player records modified.
CREATE OR REPLACE FUNCTION public.enroll_my_tennis_guest_trial_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'control_center_private', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_anonymous boolean;
  v_started timestamptz;
  v_expires timestamptz;
  v_claim_hash text;
  v_premium_expires timestamptz;
BEGIN
  IF NOT public.get_public_tennis_guest_test_status_v1() THEN
    RAISE EXCEPTION 'Guest mode is not available' USING errcode='42501';
  END IF;
  SELECT is_anonymous INTO v_anonymous FROM auth.users WHERE id=v_user;
  IF v_user IS NULL OR COALESCE(v_anonymous,false)=false THEN
    RAISE EXCEPTION 'Anonymous guest identity required' USING errcode='42501';
  END IF;
  -- Serialize trial enrollment per exact authenticated account.
  PERFORM pg_advisory_xact_lock(hashtext('tennis_guest_enroll:'||v_user::text));
  INSERT INTO control_center_private.tennis_guest_trials_v1(user_id,started_at,expires_at)
  VALUES (v_user,now(),now()+interval '14 days')
  ON CONFLICT (user_id) DO NOTHING;
  SELECT started_at,expires_at INTO v_started,v_expires
  FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=v_user;

  -- The 7-day Premium clock shares the original guest trial start timestamp.
  -- A repeated enrollment, even after 7 or 14 days, never extends Premium.
  -- Keep the existing canonical Premium table so the entitlement follows the
  -- same auth.users.id when a guest becomes a permanent linked user.
  v_claim_hash := md5('tennis-guest-premium-v1:'||v_user::text);
  INSERT INTO public.tennis_premium_trial_claims_v1(email_claim_hash)
  VALUES (v_claim_hash) ON CONFLICT DO NOTHING;

  INSERT INTO public.tennis_premium_trials_v1(
    user_id,email_claim_hash,started_at,expires_at,
    reserved_for_launch,launch_cohort
  )
  SELECT v_user,v_claim_hash,v_started,v_started+interval '7 days',false,false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.billing_transactions b
    WHERE b.user_id=v_user AND b.kind='premium_invoice' AND b.status='paid'
  ) AND NOT EXISTS (
    SELECT 1 FROM public.premium_memberships m
    WHERE m.user_id=v_user AND m.plan_code='premium' AND m.status='active'
      AND (m.current_period_end IS NULL OR m.current_period_end>now())
  )
  ON CONFLICT DO NOTHING;

  SELECT expires_at INTO v_premium_expires
  FROM public.tennis_premium_trials_v1 WHERE user_id=v_user;

  RETURN jsonb_build_object(
    'state',CASE WHEN v_expires<=now() THEN 'expired' ELSE 'active' END,
    'is_guest',true,'can_play',v_expires>now(),'can_convert',true,
    'started_at',v_started,'expires_at',v_expires,
    'seconds_remaining',greatest(0,floor(extract(epoch from v_expires-now())))::bigint,
    'premium_expires_at',v_premium_expires,
    'premium_trial_active',coalesce(v_premium_expires>now(),false)
  );
END;
$function$
;
