-- Align legacy two-week competition labels with the configured phases.
-- Some old Season 1 schedule slots used 'full' for the qualifying week
-- followed by 'main_draw'. This breaks the strict 2026-11-17 phase guard.
-- Update only 13 unpublished, unplayed Season 1 event definitions AND the
-- immutable reset snapshot so the final restart cannot reintroduce the bug.
DO $fix$
DECLARE
  affected_ids uuid[];
  v_count int;
  v_live_changed int;
  v_snapshot_changed int;
BEGIN
 SELECT array_agg(s.id ORDER BY s.id),count(*)
 INTO affected_ids,v_count
 FROM public.tournament_schedule_slots s
 JOIN public.tournament_editions ed ON ed.id=s.tournament_edition_id
 JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
 JOIN public.tournament_categories cat ON cat.code=ts.category_code
 WHERE ed.season_number=1 AND ed.status='scheduled'
   AND s.phase='full' AND cat.qualification_rounds_max>0
   AND EXISTS (SELECT 1 FROM public.tournament_schedule_slots next
     WHERE next.tournament_edition_id=ed.id
       AND next.phase='main_draw'
       AND next.season_week>s.season_week)
   AND NOT EXISTS (SELECT 1 FROM public.tournament_schedule_slots q
     WHERE q.tournament_edition_id=ed.id AND q.phase='qualification')
   AND NOT EXISTS (
     SELECT 1 FROM public.tournament_world_competitions wc
     JOIN public.tournament_draw_publications dp ON dp.competition_id=wc.id
     WHERE wc.tournament_edition_id=ed.id)
   AND NOT EXISTS (
     SELECT 1 FROM public.tournament_world_competitions wc
     JOIN public.tournament_matches m ON m.competition_id=wc.id
     WHERE wc.tournament_edition_id=ed.id);

 IF v_count<>13 THEN
   RAISE EXCEPTION 'Expected 13 unpublished, unplayed legacy two-week events, got %',v_count;
 END IF;

 IF (SELECT count(*) FROM control_center_private.tennis_prelaunch_s1_schedule_v1 snap
      WHERE snap.id=ANY(affected_ids) AND snap.phase='full')<>v_count THEN
   RAISE EXCEPTION 'Original final-reset schedule snapshot differs from live definitions';
 END IF;

 UPDATE public.tournament_schedule_slots
 SET phase='qualification'
 WHERE id=ANY(affected_ids);
 GET DIAGNOSTICS v_live_changed=ROW_COUNT;

 UPDATE control_center_private.tennis_prelaunch_s1_schedule_v1
 SET phase='qualification'
 WHERE id=ANY(affected_ids);
 GET DIAGNOSTICS v_snapshot_changed=ROW_COUNT;

 IF v_live_changed<>13 OR v_snapshot_changed<>13 THEN
   RAISE EXCEPTION 'Legacy tournament phases were not fully normalized: live % snapshot %',
    v_live_changed,v_snapshot_changed;
 END IF;

 IF EXISTS (
  SELECT 1 FROM public.tournament_schedule_slots s
  JOIN control_center_private.tennis_prelaunch_s1_schedule_v1 snap ON snap.id=s.id
  WHERE s.id=ANY(affected_ids) AND (s.phase<>'qualification' OR snap.phase<>s.phase)
 ) THEN
  RAISE EXCEPTION 'Corrected tournament phases do not match the final-reset snapshot';
 END IF;
END
$fix$;
