-- Public-facing RPC abuse guard. No changes to users, matches, balances or history.
-- Uses a private schema so callers cannot choose their own limits or edit counters.
-- Anonymous caller IDs are inherently forgeable: this is database write protection,
-- NOT a substitute for edge IP rate limits / CAPTCHA.
CREATE TABLE IF NOT EXISTS control_center_private.tennis_public_rpc_budgets_v1(
 endpoint text NOT NULL,
 identity_hash text NOT NULL,
 window_open timestamptz NOT NULL,
 request_count integer NOT NULL DEFAULT 1 CHECK (request_count>=1),
 PRIMARY KEY(endpoint,identity_hash,window_open)
);
ALTER TABLE control_center_private.tennis_public_rpc_budgets_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE control_center_private.tennis_public_rpc_budgets_v1 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION control_center_private.tennis_allow_public_rpc_v1(
  p_endpoint text,p_identity text,p_window_seconds integer,p_limit integer
) RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'control_center_private','public','extensions','pg_temp'
AS $function$
DECLARE
 v_open timestamptz;
 v_key text;
 v_used integer;
BEGIN
 IF p_endpoint NOT IN ('analytics_visitor','analytics_global','referral_code',
   'referral_global','cross_game_global','review_email','review_global')
   OR p_identity IS NULL OR length(p_identity)>512
   OR p_window_seconds NOT IN (60,3600,86400)
   OR p_limit<1 OR p_limit>100000
 THEN RAISE EXCEPTION 'Invalid public-RPC rate-limit configuration'; END IF;
 v_open:=to_timestamp(floor(extract(epoch from clock_timestamp())/p_window_seconds)*p_window_seconds);
 v_key:=encode(extensions.digest(p_identity,'sha256'),'hex');
 INSERT INTO control_center_private.tennis_public_rpc_budgets_v1
 (endpoint,identity_hash,window_open,request_count)
 VALUES(p_endpoint,v_key,v_open,1)
 ON CONFLICT(endpoint,identity_hash,window_open) DO UPDATE
   SET request_count=control_center_private.tennis_public_rpc_budgets_v1.request_count+1
   WHERE control_center_private.tennis_public_rpc_budgets_v1.request_count<p_limit
 RETURNING request_count INTO v_used;
 RETURN v_used IS NOT NULL;
END
$function$;
REVOKE ALL ON FUNCTION control_center_private.tennis_allow_public_rpc_v1(text,text,integer,integer)
FROM PUBLIC,anon,authenticated;
-- Only postgres-owned SECURITY DEFINER public APIs may invoke this private helper.
-- Retain hashed counter rows no longer than two days.
SELECT cron.schedule('tennis-public-rpc-budget-prune-v1','19 */6 * * *',
 $job$DELETE FROM control_center_private.tennis_public_rpc_budgets_v1
       WHERE window_open < now() - interval '2 days'$job$);
