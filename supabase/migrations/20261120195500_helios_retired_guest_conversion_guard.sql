-- H08: no identity conversion after guest retirement has been finalized.
-- Before retirement, guests can still register by linking the SAME account.
-- After auto-removal, current-user status accurately reports no conversion.
CREATE OR REPLACE FUNCTION public.get_my_tennis_guest_trial_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'control_center_private', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_anonymous boolean;
  v_started timestamptz;
  v_expires timestamptz;
  v_converted timestamptz;
  v_retired timestamptz;
  v_now timestamptz := now();
BEGIN
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('state','signed_out','is_guest',false);
  END IF;
  SELECT is_anonymous INTO v_anonymous FROM auth.users WHERE id=v_user;
  IF COALESCE(v_anonymous,false)=false THEN
    RETURN jsonb_build_object('state','registered','is_guest',false);
  END IF;
  SELECT started_at,expires_at,converted_at,retired_at
  INTO v_started,v_expires,v_converted,v_retired
  FROM control_center_private.tennis_guest_trials_v1
  WHERE user_id=v_user;
  IF v_started IS NULL THEN
    RETURN jsonb_build_object('state','not_enrolled','is_guest',true,
      'can_play',false,'can_convert',true);
  END IF;
  RETURN jsonb_build_object(
    'state',CASE WHEN v_retired IS NOT NULL THEN 'retired' WHEN v_expires<=v_now THEN 'expired' ELSE 'active' END,
    'is_guest',true,
    'can_play',v_retired IS NULL AND v_expires>v_now,
    'can_convert',v_retired IS NULL,
    'started_at',v_started,'expires_at',v_expires,
    'seconds_remaining',greatest(0,floor(extract(epoch from v_expires-v_now)))::bigint,
    'premium_trial_days',7,
    'maximum_guest_days',14
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_tennis_guest_conversion_status_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'control_center_private', 'pg_temp'
AS $function$
DECLARE
  v_id uuid := auth.uid();
  v_anon boolean;
  v_email_verified boolean;
  v_password boolean;
  v_google boolean;
  v_started timestamptz;
  v_expires timestamptz;
  v_converted timestamptz;
  v_retired timestamptz;
BEGIN
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode='42501';
  END IF;

  SELECT u.is_anonymous, u.email_confirmed_at IS NOT NULL,
    COALESCE(NULLIF(u.encrypted_password,''),'') <> ''
    INTO v_anon,v_email_verified,v_password
  FROM auth.users u WHERE u.id=v_id;

  SELECT started_at,expires_at,converted_at,retired_at
    INTO v_started,v_expires,v_converted,v_retired
  FROM control_center_private.tennis_guest_trials_v1
  WHERE user_id=v_id;

  IF v_started IS NULL THEN
    RETURN jsonb_build_object('eligible',false,'is_anonymous',coalesce(v_anon,false));
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM auth.identities i
    WHERE i.user_id=v_id AND i.provider='google'
  ) INTO v_google;

  RETURN jsonb_build_object(
    'eligible',true,
    'is_anonymous',coalesce(v_anon,false),
    'email_verified',coalesce(v_email_verified,false),
    'password_set',coalesce(v_password,false),
    'google_linked',coalesce(v_google,false),
    'started_at',v_started,
    'expires_at',v_expires,
    'expired',v_expires<=now(),
    'retired',v_retired IS NOT NULL,
    'converted_at',v_converted,
    'can_convert',coalesce(v_anon,false) AND v_retired IS NULL,
    'can_set_password',NOT coalesce(v_anon,false) AND coalesce(v_email_verified,false)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION control_center_private.prevent_retired_tennis_guest_conversion_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $fn$
BEGIN
  IF OLD.is_anonymous IS TRUE AND NEW.is_anonymous IS FALSE
    AND EXISTS (
      SELECT 1 FROM control_center_private.tennis_guest_trials_v1 t
      WHERE t.user_id=OLD.id AND t.retired_at IS NOT NULL
    )
  THEN
    RAISE EXCEPTION 'This test account was retired after its trial. Create a new account.'
      USING errcode='42501';
  END IF;
  RETURN NEW;
END;
$fn$;
REVOKE ALL ON FUNCTION control_center_private.prevent_retired_tennis_guest_conversion_v1()
FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS prevent_retired_tennis_guest_conversion_v1 ON auth.users;
CREATE TRIGGER prevent_retired_tennis_guest_conversion_v1
BEFORE UPDATE OF is_anonymous ON auth.users
FOR EACH ROW
WHEN (OLD.is_anonymous IS TRUE AND NEW.is_anonymous IS FALSE)
EXECUTE FUNCTION control_center_private.prevent_retired_tennis_guest_conversion_v1();
