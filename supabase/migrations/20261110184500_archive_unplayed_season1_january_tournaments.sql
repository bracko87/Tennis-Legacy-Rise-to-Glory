-- Close 16 genuinely unplayed Season 1 January ATP/WTA competitions.
-- Retain real completed ATP matches and their player/ranking/financial history.
-- Never invent tournament winners, ranking points, prizes, or match results.
DO $archive$
DECLARE
  v_before integer;
  v_after integer;
  rec record;
BEGIN
  PERFORM pg_advisory_xact_lock(2026, 1101);

  SELECT count(*) INTO v_before
  FROM public.tournament_world_competitions wc
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
  WHERE ed.season_number=1 AND sl.season_week BETWEEN 1 AND 3
    AND ed.status='scheduled' AND wc.status='scheduled';

  IF v_before NOT IN (0,16) THEN
    RAISE EXCEPTION 'Historical January archive safety check: expected 16 or 0 scheduled competitions, found %',v_before;
  END IF;

  FOR rec IN
    SELECT DISTINCT wc.id AS competition_id, ed.id AS edition_id
    FROM public.tournament_world_competitions wc
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
    WHERE ed.season_number=1 AND sl.season_week BETWEEN 1 AND 3
      AND ed.status='scheduled' AND wc.status='scheduled'
  LOOP
    IF EXISTS (SELECT 1 FROM public.tournament_matches m WHERE m.competition_id=rec.competition_id)
       OR EXISTS (SELECT 1 FROM public.tournament_doubles_matches m WHERE m.competition_id=rec.competition_id)
       OR EXISTS (SELECT 1 FROM public.tournament_entries en WHERE en.competition_id=rec.competition_id)
       OR EXISTS (SELECT 1 FROM public.tournament_applications a WHERE a.competition_id=rec.competition_id)
       OR EXISTS (SELECT 1 FROM public.player_tournament_results r WHERE r.competition_id=rec.competition_id)
       OR EXISTS (SELECT 1 FROM public.player_doubles_tournament_results r WHERE r.competition_id=rec.competition_id)
       OR EXISTS (SELECT 1 FROM public.career_finance_transactions tx WHERE tx.source_id=rec.competition_id::text)
    THEN
      RAISE EXCEPTION 'Refusing to archive competition % with actual participation/results/finances',rec.competition_id;
    END IF;

    PERFORM public.finalize_tournament_cancellation_v1(
      rec.competition_id,
      'season1_historical_unplayed',
      'Historical Season 1 tournament was not played. Closed without assigning winners, ranking points, or prize money.',
      jsonb_build_object('historical_archive',true,'season',1,
                         'verified_no_entries',true,'verified_no_matches',true,
                         'verified_no_payments',true)
    );
  END LOOP;

  -- Five entirely unplayed editions become canceled; six mixed ATP-finished /
  -- WTA-unplayed editions become completed without changing their actual ATP history.
  UPDATE public.tournament_editions ed
     SET status=CASE WHEN EXISTS (
       SELECT 1 FROM public.tournament_world_competitions wc
        WHERE wc.tournament_edition_id=ed.id AND wc.status='completed'
     ) THEN 'completed' ELSE 'canceled' END
   WHERE ed.season_number=1 AND ed.status='scheduled'
     AND EXISTS (
       SELECT 1 FROM public.tournament_schedule_slots sl
       WHERE sl.tournament_edition_id=ed.id AND sl.season_week BETWEEN 1 AND 3
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.tournament_world_competitions wc
       WHERE wc.tournament_edition_id=ed.id AND wc.status NOT IN ('completed','canceled')
     );

  SELECT count(*) INTO v_after
  FROM public.tournament_world_competitions wc
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
  WHERE ed.season_number=1 AND sl.season_week BETWEEN 1 AND 3
    AND (ed.status='scheduled' OR wc.status='scheduled');

  IF v_after<>0 THEN
    RAISE EXCEPTION 'Historical January archive left % scheduled records',v_after;
  END IF;
END;
$archive$;
