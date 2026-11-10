-- The legacy rich hourly Control Centre feed was still using an obsolete
-- token stored in telemetry_config, while the working feeds use Supabase Vault.
-- Use the same secure server-side Vault credentials without exposing tokens to
-- the client or disabling the rich telemetry/incident data.
CREATE OR REPLACE FUNCTION control_center_private.push_telemetry_v1()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'control_center_private', 'net'
AS $function$
DECLARE
  v_cfg control_center_private.telemetry_config%rowtype;
  v_endpoint text;
  v_token text;
  v_request_id bigint;
BEGIN
  SELECT * INTO v_cfg
  FROM control_center_private.telemetry_config
  WHERE singleton=true;

  IF NOT FOUND OR NOT v_cfg.enabled THEN
    RETURN null;
  END IF;

  IF v_cfg.source_project_ref IS DISTINCT FROM 'cwfznmroiqcyhfkfcrow' THEN
    RAISE EXCEPTION 'Control Centre telemetry source project does not match Tennis Legacy';
  END IF;

  SELECT decrypted_secret INTO v_endpoint
  FROM vault.decrypted_secrets
  WHERE name='game_control_center_telemetry_endpoint';
  SELECT decrypted_secret INTO v_token
  FROM vault.decrypted_secrets
  WHERE name='game_control_center_telemetry_token';

  IF nullif(v_endpoint,'') IS NULL OR nullif(v_token,'') IS NULL THEN
    RAISE EXCEPTION 'Current Control Centre telemetry credentials are missing from Vault';
  END IF;

  SELECT net.http_post(
    url:=v_endpoint,
    headers:=jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer '||v_token
    ),
    body:=control_center_private.build_telemetry_v1(),
    timeout_milliseconds:=10000
  ) INTO v_request_id;

  UPDATE control_center_private.telemetry_config
  SET last_request_id=v_request_id,last_attempt_at=now(),updated_at=now()
  WHERE singleton=true;

  RETURN v_request_id;
END;
$function$;
