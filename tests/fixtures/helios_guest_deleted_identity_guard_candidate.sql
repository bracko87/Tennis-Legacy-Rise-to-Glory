-- Candidate replacement for the shared guest access guard.
-- Nondeployable until reviewed and tested; loaded only into disposable CI.
CREATE OR REPLACE FUNCTION public.assert_my_tennis_guest_access_v1()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','control_center_private','auth','pg_temp'
AS $fn$
DECLARE
 v_user uuid := auth.uid();
 v_anon boolean;
BEGIN
 IF v_user IS NULL THEN
   RAISE EXCEPTION 'Authentication required' USING errcode='42501';
 END IF;
 SELECT u.is_anonymous INTO v_anon FROM auth.users u WHERE u.id=v_user;
 IF NOT FOUND THEN
   RAISE EXCEPTION 'Account no longer exists' USING errcode='42501';
 END IF;
 IF v_anon IS TRUE AND NOT EXISTS(
   SELECT 1 FROM control_center_private.tennis_guest_trials_v1 g
   WHERE g.user_id=v_user AND g.expires_at>now()
     AND g.retired_at IS NULL AND g.converted_at IS NULL
 ) THEN
   RAISE EXCEPTION 'Guest trial expired or not enrolled' USING errcode='42501';
 END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION public.assert_my_tennis_guest_access_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.assert_my_tennis_guest_access_v1() TO authenticated;
