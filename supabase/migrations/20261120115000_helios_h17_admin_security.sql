-- Project Helios H17: tighten administrator authorization to real, verified auth identities.
-- Old behavior accepted an active admin entry by matching email from JWT,
-- even when its user_id no longer existed. This migration removes that fallback.
-- Keep owner account and paid/gameplay data unchanged.
UPDATE public.app_admins
SET is_active = false
WHERE lower(email) = 'levnajic.aleksandar@gmail.com'
  AND user_id IS NULL
  AND is_active;

CREATE OR REPLACE FUNCTION public.is_app_admin_v1(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','auth','pg_temp'
AS $auth$
  SELECT auth.uid() IS NOT NULL
    AND p_user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.app_admins a
      JOIN auth.users u ON u.id=a.user_id
      WHERE a.is_active
        AND a.user_id=auth.uid()
        AND u.deleted_at IS NULL
        AND u.email_confirmed_at IS NOT NULL
        AND lower(u.email)=lower(a.email)
    );
$auth$;
REVOKE ALL ON FUNCTION public.is_app_admin_v1(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.is_app_admin_v1(uuid) TO authenticated;

-- Summary is restricted to approved admins and contains counts, not accounts/emails.
CREATE OR REPLACE FUNCTION public.get_admin_tennis_security_status_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public','auth','pg_temp'
AS $status$
BEGIN
  IF NOT public.is_app_admin_v1(auth.uid()) THEN
    RAISE EXCEPTION 'Administrator access required' USING errcode='42501';
  END IF;

  RETURN jsonb_build_object(
    'checked_at',now(),
    'active_admin_records',(SELECT count(*) FROM public.app_admins WHERE is_active),
    'verified_active_admins',(
      SELECT count(*) FROM public.app_admins a
      JOIN auth.users u ON u.id=a.user_id
      WHERE a.is_active AND u.deleted_at IS NULL
        AND u.email_confirmed_at IS NOT NULL
        AND lower(u.email)=lower(a.email)
    ),
    'unlinked_active_records',(
      SELECT count(*) FROM public.app_admins a
      LEFT JOIN auth.users u ON u.id=a.user_id
      WHERE a.is_active AND (u.id IS NULL OR u.deleted_at IS NOT NULL
        OR u.email_confirmed_at IS NULL OR lower(u.email) IS DISTINCT FROM lower(a.email))
    ),
    'analytics_anon_execute',(
      SELECT has_function_privilege('anon','public.get_admin_analytics_dashboard_v1(integer)','EXECUTE')
    ),
    'history_anon_execute',(
      SELECT has_function_privilege('anon','public.get_admin_tennis_event_history_v1(integer,text,text,integer,integer)','EXECUTE')
    ),
    'economy_anon_execute',(
      SELECT has_function_privilege('anon','public.get_admin_tennis_economy_v1(integer)','EXECUTE')
    ),
    'definition','Administrator access is checked against a verified current auth identity and an active exact-UID record; public analytics RPCs must remain inaccessible to anonymous roles. This is a point-in-time permission check, not a full penetration test.'
  );
END;
$status$;
REVOKE ALL ON FUNCTION public.get_admin_tennis_security_status_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_admin_tennis_security_status_v1() TO authenticated;
