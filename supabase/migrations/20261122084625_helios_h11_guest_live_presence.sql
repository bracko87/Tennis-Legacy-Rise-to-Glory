ALTER TABLE control_center_private.tennis_live_page_sessions_v1 ADD COLUMN is_guest boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION public.record_live_page_presence_v1(p_visitor_id uuid, p_session_id uuid, p_path text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'control_center_private', 'pg_temp'
AS $function$
DECLARE
  v_path text;
  v_registered boolean := false;
  v_guest boolean := false;
  v_uid uuid := auth.uid();
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
  IF v_uid IS NOT NULL THEN
    SELECT NOT u.is_anonymous, u.is_anonymous INTO v_registered,v_guest
    FROM auth.users u WHERE u.id=v_uid AND u.deleted_at IS NULL
      AND (NOT u.is_anonymous OR EXISTS (
        SELECT 1 FROM control_center_private.tennis_guest_trials_v1 g
        WHERE g.user_id=u.id AND g.converted_at IS NULL AND g.retired_at IS NULL AND g.expires_at>now()
      ));
    IF NOT FOUND THEN RETURN; END IF;
  END IF;

  INSERT INTO control_center_private.tennis_live_page_sessions_v1
    (session_id, visitor_id, path, is_registered, is_guest, last_seen_at)
  VALUES (p_session_id, p_visitor_id, v_path, v_registered, v_guest, now())
  ON CONFLICT (session_id) DO UPDATE
  SET visitor_id = EXCLUDED.visitor_id,
      path = EXCLUDED.path,
      is_registered = EXCLUDED.is_registered,
      is_guest = EXCLUDED.is_guest,
      last_seen_at = EXCLUDED.last_seen_at
  WHERE control_center_private.tennis_live_page_sessions_v1.last_seen_at < now() - interval '10 seconds'
     OR control_center_private.tennis_live_page_sessions_v1.path IS DISTINCT FROM EXCLUDED.path
     OR control_center_private.tennis_live_page_sessions_v1.is_registered IS DISTINCT FROM EXCLUDED.is_registered
     OR control_center_private.tennis_live_page_sessions_v1.is_guest IS DISTINCT FROM EXCLUDED.is_guest;

  -- Opportunistic 24-hour retention cleanup; active report itself uses a strict
  -- 2-minute window so old records are never counted even if traffic stops.
  IF random() < 0.02 THEN
    DELETE FROM control_center_private.tennis_live_page_sessions_v1
    WHERE last_seen_at < now() - interval '24 hours';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_admin_live_page_activity_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'control_center_private', 'pg_temp'
AS $function$
DECLARE
  v_report jsonb;
BEGIN
  IF NOT public.is_app_admin_v1(auth.uid()) THEN
    RAISE EXCEPTION 'Administrator access required' USING errcode = '42501';
  END IF;

  WITH latest AS (
    SELECT DISTINCT ON (visitor_id)
      visitor_id, path, is_registered, is_guest, last_seen_at
    FROM control_center_private.tennis_live_page_sessions_v1
    WHERE last_seen_at >= now() - interval '2 minutes'
    ORDER BY visitor_id, last_seen_at DESC, path
  ), grouped AS (
    SELECT path,
           count(*)::integer AS visitors,
           count(*) FILTER (WHERE is_registered)::integer AS registered,
           count(*) FILTER (WHERE NOT is_registered)::integer AS anonymous,
           count(*) FILTER (WHERE is_guest)::integer AS guests,
           count(*) FILTER (WHERE NOT is_registered AND NOT is_guest)::integer AS signed_out
    FROM latest
    GROUP BY path
  )
  SELECT jsonb_build_object(
    'generated_at', now(),
    'window_seconds', 120,
    'active_visitors', (SELECT count(*) FROM latest),
    'registered', (SELECT count(*) FROM latest WHERE is_registered),
    'anonymous', (SELECT count(*) FROM latest WHERE NOT is_registered),
    'guests', (SELECT count(*) FROM latest WHERE is_guest),
    'signed_out', (SELECT count(*) FROM latest WHERE NOT is_registered AND NOT is_guest),
    'pages', coalesce(
       (SELECT jsonb_agg(
          jsonb_build_object('path', path, 'visitors', visitors,
                             'registered', registered, 'anonymous', anonymous, 'guests', guests, 'signed_out', signed_out)
          ORDER BY visitors DESC, path)
        FROM grouped),
       '[]'::jsonb
    ),
    'definition', 'Recently interactive, visible browser sessions on the official site in the last 2 minutes; a visitor is counted once on their latest page. Idle or hidden tabs expire. Permanent, guest and signed-out browser categories derive from current server-side identity at each heartbeat. Legacy anonymous totals include guests. Not a websocket online count.'
  ) INTO v_report;
  RETURN v_report;
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_my_tennis_presence_v1()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'control_center_private', 'pg_temp'
AS $function$
DECLARE v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL OR auth.role() <> 'authenticated' THEN
    RAISE EXCEPTION 'Authenticated player required' USING errcode='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id=v_user AND u.deleted_at IS NULL AND (NOT u.is_anonymous OR EXISTS (SELECT 1 FROM control_center_private.tennis_guest_trials_v1 g WHERE g.user_id=u.id AND g.converted_at IS NULL AND g.retired_at IS NULL AND g.expires_at>now()))) THEN RETURN; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.players p
    WHERE p.owner_user_id = v_user AND p.player_type='human' AND p.moderation_status IS DISTINCT FROM 'rejected'
  ) THEN
    RETURN;
  END IF;
  INSERT INTO control_center_private.tennis_active_player_presence_v1
    (user_id,last_activity_at,updated_at)
  VALUES (v_user,now(),now())
  ON CONFLICT (user_id) DO UPDATE
  SET last_activity_at=excluded.last_activity_at,
      updated_at=excluded.updated_at
  WHERE control_center_private.tennis_active_player_presence_v1.last_activity_at < now()-interval '15 seconds';
END;
$function$;
