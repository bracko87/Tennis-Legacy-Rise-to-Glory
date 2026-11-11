-- Preserve the Season 2 current game-time minute when a controlled,
-- already-verified Season 1->2 migration enters its 24 real-hour preparation
-- period. The ordinary future-season flow remains at January 1 00:00.
-- No current game clock or maintenance state is changed by this migration.
DO $preseason_clock_patch$
DECLARE
  v_fn text;
  v_old text := 'WHEN s.status=''preseason'' THEN (s.target_season-1)::bigint*31622400';
  v_new text := 'WHEN s.status=''preseason'' THEN g.total_seconds';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_game_clock_v1'
    AND pg_get_function_identity_arguments(p.oid)='';

  IF v_fn IS NULL THEN RAISE EXCEPTION 'Official game clock function missing'; END IF;
  IF strpos(v_fn,v_new)>0 THEN RETURN; END IF;
  IF (length(v_fn)-length(replace(v_fn,v_old,'')))/length(v_old)<>1 THEN
    RAISE EXCEPTION 'Unexpected game-clock version; refusing to alter clock semantics';
  END IF;
  EXECUTE replace(v_fn,v_old,v_new);
END $preseason_clock_patch$;
