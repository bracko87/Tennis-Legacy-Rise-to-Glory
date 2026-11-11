-- The only Season 2 Week 1 cancellation predated the owner-approved
-- January 3 application/draw schedule. Since the same competition has been
-- reopened, preserve the old cancellation record in the protected audit
-- and remove its stale active cancellation marker.
CREATE TABLE IF NOT EXISTS control_center_private.tennis_season2_week1_reversed_cancellations_v1 (
  competition_id uuid PRIMARY KEY,
  archived_at timestamptz NOT NULL DEFAULT now(),
  original_record jsonb NOT NULL,
  reason text NOT NULL
);
REVOKE ALL ON control_center_private.tennis_season2_week1_reversed_cancellations_v1
FROM PUBLIC,anon,authenticated;

DO $reverse_stale$
DECLARE v_id uuid;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('tennis:two-day-season-transition',0));
  SELECT cx.competition_id INTO v_id
  FROM public.tournament_cancellations cx
  JOIN public.tournament_world_competitions wc ON wc.id=cx.competition_id
  JOIN public.tournament_editions e ON e.id=wc.tournament_edition_id
  JOIN public.tournament_series ts ON ts.id=e.tournament_series_id
  JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=e.id
  WHERE e.season_number=2 AND ss.season_week=1
    AND ts.name='Lima Challenger' AND wc.world='ATP'
    AND wc.status='scheduled' AND e.status='scheduled'
    AND cx.reason_code='minimum_field_not_met'
    AND EXISTS(SELECT 1
      FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
      WHERE arc.competition_id=wc.id AND arc.source_status='canceled');

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Expected the old Week 1 Lima minimum-field cancellation';
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.tournament_matches m WHERE m.competition_id=v_id
  ) OR EXISTS(
    SELECT 1 FROM public.player_tournament_results r WHERE r.competition_id=v_id
  ) THEN
    RAISE EXCEPTION 'Refusing to reverse a tournament with any started or published matches';
  END IF;

  INSERT INTO control_center_private.tennis_season2_week1_reversed_cancellations_v1
     (competition_id,original_record,reason)
  SELECT competition_id,to_jsonb(cx),
    'Old prior-season minimum field check was superseded by Jan 3 Week 1 selection'
  FROM public.tournament_cancellations cx WHERE cx.competition_id=v_id;
  DELETE FROM public.tournament_cancellations cx WHERE cx.competition_id=v_id;
  IF EXISTS(SELECT 1 FROM public.tournament_cancellations WHERE competition_id=v_id)
    OR NOT EXISTS(SELECT 1 FROM control_center_private.tennis_season2_week1_reversed_cancellations_v1 WHERE competition_id=v_id)
  THEN
    RAISE EXCEPTION 'Lima cancellation archival/reversal not consistent';
  END IF;
END $reverse_stale$;
