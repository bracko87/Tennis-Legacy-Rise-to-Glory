-- CI entrypoint invokes the actual core candidate, only in disposable fixture.
CREATE FUNCTION control_center_private.helios_ci_erase_retired_guest(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'pg_catalog','pg_temp'
AS $fn$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM control_center_private.helios_real_auth_ci_marker WHERE id)
 THEN RAISE EXCEPTION 'Not the disposable fixture'; END IF;
 PERFORM control_center_private.helios_core_guest_erasure_candidate(p_user);
END;
$fn$;
REVOKE ALL ON FUNCTION control_center_private.helios_ci_erase_retired_guest(uuid) FROM PUBLIC,anon,authenticated;
