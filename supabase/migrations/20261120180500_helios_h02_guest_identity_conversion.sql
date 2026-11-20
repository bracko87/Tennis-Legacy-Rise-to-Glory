-- Helios H02: preserve the anonymous guest auth user ID when linking a
-- verified email or OAuth identity. No copying player/finance/equipment rows.
-- Guest Mode and Google provider remain disabled until end-to-end verification.
CREATE OR REPLACE FUNCTION control_center_private.mark_tennis_guest_converted_v1()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
AS $function$
BEGIN
  IF OLD.is_anonymous IS TRUE AND NEW.is_anonymous IS FALSE
    AND NEW.id = OLD.id THEN
    UPDATE control_center_private.tennis_guest_trials_v1
       SET converted_at = COALESCE(converted_at, now())
     WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION control_center_private.mark_tennis_guest_converted_v1() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS mark_tennis_guest_converted_v1 ON auth.users;
CREATE TRIGGER mark_tennis_guest_converted_v1
  AFTER UPDATE OF is_anonymous ON auth.users
  FOR EACH ROW
  WHEN (OLD.is_anonymous IS TRUE AND NEW.is_anonymous IS FALSE)
  EXECUTE FUNCTION control_center_private.mark_tennis_guest_converted_v1();

-- Private current-user conversion status. Returns no email, password, coins,
-- token, or account ID. An expired guest can still convert.
CREATE OR REPLACE FUNCTION public.get_my_tennis_guest_conversion_status_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','auth','control_center_private','pg_temp'
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
BEGIN
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode='42501';
  END IF;

  SELECT u.is_anonymous, u.email_confirmed_at IS NOT NULL,
    COALESCE(NULLIF(u.encrypted_password,''),'') <> ''
    INTO v_anon,v_email_verified,v_password
  FROM auth.users u WHERE u.id=v_id;

  SELECT started_at,expires_at,converted_at
    INTO v_started,v_expires,v_converted
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
    'converted_at',v_converted,
    'can_convert',coalesce(v_anon,false),
    'can_set_password',NOT coalesce(v_anon,false) AND coalesce(v_email_verified,false)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_tennis_guest_conversion_status_v1()
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_tennis_guest_conversion_status_v1()
  TO authenticated;
