-- First 24 real hours of a new season are paused at Jan 1 00:00.
-- All undrawn January tournaments (Weeks 1-4) must remain available for
-- ordinary applications during that entire period, not just a preference
-- form. The normal eligibility, one-tournament-per-week, health and capacity
-- rules continue to apply, and already published draws are immutable.
-- The window remains valid after the clock resumes until its game-time close.
DO $extend_january$
DECLARE
  v_source text;
  v_needle text := E'  return jsonb_build_object(\n    ''season_number''';
  v_replacement text := $new_window$
  -- Once a particular future season has passed the verified migration stage,
  -- its first month cannot inherit a closed window from the prior December.
  IF v_first_week BETWEEN 1 AND 4
    AND EXISTS (
      SELECT 1 FROM control_center_private.tennis_season_maintenance_control_v1 c
      WHERE c.id=true AND c.target_season=v_season AND c.preseason_starts_at IS NOT NULL
    )
    AND NOT EXISTS(
      SELECT 1 FROM public.tournament_draw_publications dp
      WHERE dp.competition_id=p_competition_id
    )
    AND NOT EXISTS(
      SELECT 1 FROM public.tournament_matches tm
      WHERE tm.competition_id=p_competition_id
    )
  THEN
    v_open := least(v_open,(v_season-1)::bigint*31622400);
    IF v_first_week=1 THEN
      -- Week 1 begins on Jan 3. Publish the draw Jan 2 22:00,
      -- ahead of the first Jan 3 10:00 matches.
      v_close := (v_season-1)::bigint*31622400 + 86400 + 16*3600;
      v_late_open := v_close;
      v_late_close := (v_season-1)::bigint*31622400 + 86400 + 18*3600;
      v_draw := (v_season-1)::bigint*31622400 + 86400 + 22*3600;
    ELSE
      -- Other January tournaments keep their normal dates unless their
      -- registration would already have closed before players got access.
      v_close := greatest(v_close,(v_season-1)::bigint*31622400 + 86400 + 16*3600);
      v_late_open := greatest(v_close,v_late_open);
      v_late_close := greatest(v_late_close,v_late_open+2*3600);
      v_draw := greatest(v_draw,v_late_close+4*3600);
      -- Never move a draw to or beyond the event's game-day start.
      v_draw := least(v_draw,v_first_start::bigint*86400-12*3600);
    END IF;
  END IF;

  return jsonb_build_object(
    'season_number'$new_window$;
  v_sites int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_tournament_entry_timeline_v1'
    AND pg_get_function_identity_arguments(p.oid)='p_competition_id uuid';

  IF v_source IS NULL THEN RAISE EXCEPTION 'Tournament timeline function not found'; END IF;
  IF position('Once a particular future season has passed' in v_source)>0 THEN
    RETURN;
  END IF;
  v_sites := (length(v_source)-length(replace(v_source,v_needle,'')))/length(v_needle);
  IF v_sites<>1 THEN RAISE EXCEPTION 'Unexpected tournament timeline structure (% sites)',v_sites; END IF;
  EXECUTE replace(v_source,v_needle,v_replacement);
END
$extend_january$;

-- Do not unlock entries already locked in a previous season until migration
-- is officially verified. The transition coordinator may reset only undrawn
-- Week 1 entries as part of its new-season preparation, separately.
