-- Helios H01/H02/H08: DISABLED secure guest-session foundation.
-- This does not activate anonymous Auth signups or permit gameplay RPCs.
-- Guest identity issuance, financial benefit guards and full gameplay protection
-- are independent launch blockers, so the flag defaults to false.
ALTER TABLE public.registration_control
  ADD COLUMN IF NOT EXISTS guest_test_enabled boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS control_center_private.tennis_guest_trials_v1 (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  converted_at timestamptz,
  CONSTRAINT guest_trial_duration_14_days_v1 CHECK (expires_at = started_at + interval '14 days'),
  CONSTRAINT guest_conversion_after_start_v1 CHECK (converted_at IS NULL OR converted_at >= started_at)
);
ALTER TABLE control_center_private.tennis_guest_trials_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tennis_guest_trials_v1 FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_public_tennis_guest_test_status_v1()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT COALESCE((
    SELECT guest_test_enabled FROM public.registration_control WHERE singleton_id=true
  ), false)
$fn$;
REVOKE ALL ON FUNCTION public.get_public_tennis_guest_test_status_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_tennis_guest_test_status_v1() TO anon, authenticated;

-- Internal access check for FUTURE gameplay mutations. No user ID input.
CREATE OR REPLACE FUNCTION public.get_my_tennis_guest_trial_v1()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','control_center_private','auth','pg_temp'
AS $fn$
DECLARE
  v_user uuid := auth.uid();
  v_anonymous boolean;
  v_started timestamptz;
  v_expires timestamptz;
  v_converted timestamptz;
  v_now timestamptz := now();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('state','signed_out','is_guest',false);
  END IF;
  SELECT is_anonymous INTO v_anonymous FROM auth.users WHERE id=v_user;
  IF COALESCE(v_anonymous,false)=false THEN
    RETURN jsonb_build_object('state','registered','is_guest',false);
  END IF;
  SELECT started_at,expires_at,converted_at
  INTO v_started,v_expires,v_converted
  FROM control_center_private.tennis_guest_trials_v1
  WHERE user_id=v_user;
  IF v_started IS NULL THEN
    RETURN jsonb_build_object('state','not_enrolled','is_guest',true,
      'can_play',false,'can_convert',true);
  END IF;
  RETURN jsonb_build_object(
    'state',CASE WHEN v_expires<=v_now THEN 'expired' ELSE 'active' END,
    'is_guest',true,
    'can_play',v_expires>v_now,
    'can_convert',true,
    'started_at',v_started,'expires_at',v_expires,
    'seconds_remaining',greatest(0,floor(extract(epoch from v_expires-v_now)))::bigint,
    'premium_trial_days',7,
    'maximum_guest_days',14
  );
END;
$fn$;
REVOKE ALL ON FUNCTION public.get_my_tennis_guest_trial_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_tennis_guest_trial_v1() TO authenticated;

-- Explicit enrollment is possible only for a server-recognized Supabase
-- anonymous user AND after an authorized admin enables the guest rollout flag.
-- No client may supply or overwrite start/end timestamps or another user ID.
CREATE OR REPLACE FUNCTION public.enroll_my_tennis_guest_trial_v1()
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public','control_center_private','auth','pg_temp'
AS $fn$
DECLARE
  v_user uuid := auth.uid();
  v_anonymous boolean;
  v_started timestamptz;
  v_expires timestamptz;
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
  RETURN jsonb_build_object(
    'state',CASE WHEN v_expires<=now() THEN 'expired' ELSE 'active' END,
    'is_guest',true,'can_play',v_expires>now(),'can_convert',true,
    'started_at',v_started,'expires_at',v_expires,
    'seconds_remaining',greatest(0,floor(extract(epoch from v_expires-now())))::bigint
  );
END;
$fn$;
REVOKE ALL ON FUNCTION public.enroll_my_tennis_guest_trial_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.enroll_my_tennis_guest_trial_v1() TO authenticated;

-- Intended for server-side calls in each mutating gameplay RPC as the guest
-- implementation is extended. Not yet wired into all gameplay operations.
CREATE OR REPLACE FUNCTION public.assert_my_tennis_guest_access_v1()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','control_center_private','auth','pg_temp'
AS $fn$
DECLARE v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode='42501';
  END IF;
  IF EXISTS(SELECT 1 FROM auth.users WHERE id=v_user AND is_anonymous) THEN
    IF NOT EXISTS(
      SELECT 1 FROM control_center_private.tennis_guest_trials_v1 g
      WHERE g.user_id=v_user AND g.expires_at>now()
    ) THEN
      RAISE EXCEPTION 'Guest trial expired or not enrolled' USING errcode='42501';
    END IF;
  END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION public.assert_my_tennis_guest_access_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.assert_my_tennis_guest_access_v1() TO authenticated;
