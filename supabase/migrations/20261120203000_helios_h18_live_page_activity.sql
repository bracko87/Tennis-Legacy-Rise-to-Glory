-- Project Helios H18: live page activity by recently interactive visible browser.
-- Private, ephemeral pseudonymous session state; no IP, email, or raw user ID.
-- Aggregated administrator dashboard only. Client updates are on the official hosts.
CREATE TABLE IF NOT EXISTS control_center_private.tennis_live_page_sessions_v1 (
  session_id uuid PRIMARY KEY,
  visitor_id uuid NOT NULL,
  path text NOT NULL,
  is_registered boolean NOT NULL DEFAULT false,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tennis_live_page_path_check CHECK (left(path, 1) = '/' AND length(path) <= 240)
);
CREATE INDEX IF NOT EXISTS tennis_live_page_sessions_seen_idx
  ON control_center_private.tennis_live_page_sessions_v1 (last_seen_at DESC);
CREATE INDEX IF NOT EXISTS tennis_live_page_sessions_visitor_seen_idx
  ON control_center_private.tennis_live_page_sessions_v1 (visitor_id, last_seen_at DESC);
ALTER TABLE control_center_private.tennis_live_page_sessions_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE control_center_private.tennis_live_page_sessions_v1 FROM PUBLIC, anon, authenticated;

-- The public write endpoint deliberately accepts anonymous browsers. It writes
-- only to the private table; it never returns stored rows or user identities.
-- Signed-in status is determined from verified JWT claims, not a client flag.
CREATE OR REPLACE FUNCTION public.record_live_page_presence_v1(
  p_visitor_id uuid,
  p_session_id uuid,
  p_path text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public', 'control_center_private', 'pg_temp'
AS $presence$
DECLARE
  v_path text;
  v_registered boolean;
BEGIN
  IF p_visitor_id IS NULL OR p_session_id IS NULL THEN RETURN; END IF;

  v_path := left(trim(split_part(coalesce(p_path, ''), '?', 1)), 240);
  IF length(v_path) < 1 OR left(v_path, 1) <> '/'
     OR v_path ~ '[[:cntrl:]]'
     OR v_path = '/game/admin' OR v_path LIKE '/game/admin/%'
     OR v_path = '/admin' OR v_path LIKE '/admin/%' THEN
    RETURN;
  END IF;

  -- Group individual player/tournament links into page types to avoid retaining IDs.
  v_path := regexp_replace(v_path, '^/game/players/[^/]+.*$', '/game/players/:id');
  v_path := regexp_replace(v_path, '^/game/tournaments/[^/]+.*$', '/game/tournaments/:id');
  v_registered := auth.uid() IS NOT NULL
                  AND coalesce(auth.jwt()->>'is_anonymous', 'false') <> 'true';

  INSERT INTO control_center_private.tennis_live_page_sessions_v1
    (session_id, visitor_id, path, is_registered, last_seen_at)
  VALUES (p_session_id, p_visitor_id, v_path, v_registered, now())
  ON CONFLICT (session_id) DO UPDATE
  SET visitor_id = EXCLUDED.visitor_id,
      path = EXCLUDED.path,
      is_registered = EXCLUDED.is_registered,
      last_seen_at = EXCLUDED.last_seen_at
  WHERE control_center_private.tennis_live_page_sessions_v1.last_seen_at < now() - interval '10 seconds'
     OR control_center_private.tennis_live_page_sessions_v1.path IS DISTINCT FROM EXCLUDED.path
     OR control_center_private.tennis_live_page_sessions_v1.is_registered IS DISTINCT FROM EXCLUDED.is_registered;

  -- Opportunistic 24-hour retention cleanup; active report itself uses a strict
  -- 2-minute window so old records are never counted even if traffic stops.
  IF random() < 0.02 THEN
    DELETE FROM control_center_private.tennis_live_page_sessions_v1
    WHERE last_seen_at < now() - interval '24 hours';
  END IF;
END;
$presence$;
REVOKE ALL ON FUNCTION public.record_live_page_presence_v1(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_live_page_presence_v1(uuid, uuid, text) TO anon, authenticated;

-- An administrator receives page-level aggregates ONLY: no visitor/session IDs.
-- This is a recently interactive browser estimate, not a live socket count.
CREATE OR REPLACE FUNCTION public.get_admin_live_page_activity_v1()
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path TO 'public', 'control_center_private', 'pg_temp'
AS $report$
DECLARE
  v_report jsonb;
BEGIN
  IF NOT public.is_app_admin_v1(auth.uid()) THEN
    RAISE EXCEPTION 'Administrator access required' USING errcode = '42501';
  END IF;

  WITH latest AS (
    SELECT DISTINCT ON (visitor_id)
      visitor_id, path, is_registered, last_seen_at
    FROM control_center_private.tennis_live_page_sessions_v1
    WHERE last_seen_at >= now() - interval '2 minutes'
    ORDER BY visitor_id, last_seen_at DESC, path
  ), grouped AS (
    SELECT path,
           count(*)::integer AS visitors,
           count(*) FILTER (WHERE is_registered)::integer AS registered,
           count(*) FILTER (WHERE NOT is_registered)::integer AS anonymous
    FROM latest
    GROUP BY path
  )
  SELECT jsonb_build_object(
    'generated_at', now(),
    'window_seconds', 120,
    'active_visitors', (SELECT count(*) FROM latest),
    'registered', (SELECT count(*) FROM latest WHERE is_registered),
    'anonymous', (SELECT count(*) FROM latest WHERE NOT is_registered),
    'pages', coalesce(
       (SELECT jsonb_agg(
          jsonb_build_object('path', path, 'visitors', visitors,
                             'registered', registered, 'anonymous', anonymous)
          ORDER BY visitors DESC, path)
        FROM grouped),
       '[]'::jsonb
    ),
    'definition', 'Recently interactive, visible browser sessions on the official site in the last 2 minutes; a visitor is counted once on their latest page. Idle or hidden tabs expire. Registered and anonymous are derived from authentication, and guest trials are included with anonymous. Not a websocket online count.'
  ) INTO v_report;
  RETURN v_report;
END;
$report$;
REVOKE ALL ON FUNCTION public.get_admin_live_page_activity_v1() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_live_page_activity_v1() TO authenticated;
