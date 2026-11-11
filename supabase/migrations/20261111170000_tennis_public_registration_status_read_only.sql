-- Public read-only registration availability, controlled by the Tennis Legacy admin flag.
-- This function exposes only a boolean; do not grant direct table read access.
CREATE OR REPLACE FUNCTION public.get_public_registration_status_v1()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
  SELECT coalesce((SELECT public_signup_enabled FROM public.registration_control WHERE singleton_id=true),false);
$function$;
REVOKE ALL ON FUNCTION public.get_public_registration_status_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_registration_status_v1() TO anon,authenticated;
