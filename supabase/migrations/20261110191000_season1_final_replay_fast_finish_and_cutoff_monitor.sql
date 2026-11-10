-- Ensure Season 1 December 31 ATP/WTA finals finish with room to settle
-- by 22:00 in-game. Preserve every simulated point, score, winner, statistic,
-- ranking record, payment, and the 23:29 clock slow-down safety setting.
-- Only replay presentation timing (not the match simulation) is compressed.
CREATE OR REPLACE FUNCTION control_center_private.compress_season1_final_replay_on_insert_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, control_center_private
AS $replay$
DECLARE
  v_is_final boolean;
  v_original integer;
  v_new_events jsonb;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.tournament_matches m
    JOIN public.tournament_world_competitions wc ON wc.id=m.competition_id
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
    WHERE m.id=NEW.match_id AND ed.season_number=1
      AND sl.season_week=52 AND m.scheduled_season_week=52
      AND m.scheduled_day=7 AND m.draw_type='main_draw'
      AND lower(m.round_label)='final'
  ) INTO v_is_final;

  IF NOT v_is_final OR NEW.replay_duration_seconds<=480 THEN
    RETURN NEW;
  END IF;
  v_original:=NEW.replay_duration_seconds;

  -- Rescale event offsets in place: every simulated point remains present
  -- in the same order, now displayed over at most 480 real seconds.
  SELECT COALESCE(jsonb_agg(
    jsonb_set(ev,'{offset_seconds}',
      to_jsonb(least(480,greatest(0,
        round((ev->>'offset_seconds')::numeric*480/v_original)::integer
      ))),true)
    ORDER BY ord
  ),'[]'::jsonb) INTO v_new_events
  FROM jsonb_array_elements(NEW.events_payload) WITH ORDINALITY AS e(ev,ord);

  IF NOT public.validate_match_replay_events_v1(v_new_events,480) THEN
    RAISE EXCEPTION 'Season 1 final replay cannot be accelerated safely: match %',NEW.match_id;
  END IF;

  NEW.events_payload:=v_new_events;
  NEW.replay_duration_seconds:=480;
  NEW.metadata:=COALESCE(NEW.metadata,'{}'::jsonb)||jsonb_build_object(
    'season1_final_8min_replay',true,
    'uncompressed_replay_duration_seconds',v_original,
    'reason','finish_and_settle_real_final_before_game_22_00'
  );
  RETURN NEW;
END
$replay$;

REVOKE ALL ON FUNCTION control_center_private.compress_season1_final_replay_on_insert_v1()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_compress_season1_final_replay_on_insert_v1
ON public.tournament_match_simulations;
CREATE TRIGGER trg_compress_season1_final_replay_on_insert_v1
BEFORE INSERT ON public.tournament_match_simulations
FOR EACH ROW EXECUTE FUNCTION control_center_private.compress_season1_final_replay_on_insert_v1();

-- Deadline monitor. Do not close real matches or manufacture results to pass.
-- A missing closeout raises a health incident from game 22:00 onwards.
CREATE OR REPLACE FUNCTION control_center_private.check_season1_dec31_22h_closeout_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, control_center_private
AS $monitor$
DECLARE
  v_now bigint;
  v_done boolean;
  v_finals integer;
  v_matches integer;
  v_editions integer;
  v_status text;
BEGIN
  SELECT game_total_seconds INTO v_now FROM public.get_game_clock_v1();
  v_done:=EXISTS(
    SELECT 1 FROM control_center_private.tennis_season1_final_closeout_v1
    WHERE season_number=1 AND game_absolute_day=365
      AND final_matches=12 AND ranking_cycles_processed=12
  );
  IF v_done THEN
    PERFORM public.resolve_system_incident_by_dedupe_v1(
      'tennis-season1-final-2200-cutoff',
      'All Season 1 finals and ranking closeout checks passed.'
    );
    RETURN jsonb_build_object('status','completed','game_second',v_now);
  END IF;

  IF v_now IS NULL OR v_now<31615200 OR v_now>=31622400 THEN
    RETURN jsonb_build_object('status','waiting_before_deadline','game_second',v_now);
  END IF;

  SELECT count(*) INTO v_finals
  FROM public.tournament_matches m
  JOIN public.tournament_world_competitions wc ON wc.id=m.competition_id
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  WHERE ed.season_number=1 AND m.scheduled_season_week=52
    AND m.draw_type='main_draw' AND lower(m.round_label)='final'
    AND m.status='completed' AND m.winner_id IS NOT NULL;
  SELECT count(*) INTO v_matches
  FROM public.tournament_matches m
  JOIN public.tournament_world_competitions wc ON wc.id=m.competition_id
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  WHERE ed.season_number=1 AND m.status IN ('scheduled','in_progress');
  SELECT count(*) INTO v_editions
  FROM public.tournament_editions
  WHERE season_number=1 AND status NOT IN ('completed','canceled');

  PERFORM public.raise_system_incident_v1(
    'check:tennis-season1-final-2200-cutoff','critical',
    'Season 1 final-day closeout missed 22:00 in-game target',
    format('Finals finished: %s/12. Unresolved singles: %s. Open editions: %s. Year-end ranking/prize checkpoint not yet committed.',
      v_finals,v_matches,v_editions),
    'tennis-season1-final-2200-cutoff',
    jsonb_build_object('game_second',v_now,'finals_completed',v_finals,
      'unfinished_singles',v_matches,'open_editions',v_editions,
      'checkpoint_committed',false)
  );
  RETURN jsonb_build_object('status','critical_overdue',
      'game_second',v_now,'finals_completed',v_finals,
      'unfinished_singles',v_matches,'open_editions',v_editions);
END
$monitor$;
REVOKE ALL ON FUNCTION control_center_private.check_season1_dec31_22h_closeout_v1()
FROM PUBLIC, anon, authenticated;

SELECT cron.schedule(
  'tennis-season1-final-2200-cutoff-v1','* * * * *',
  'select control_center_private.check_season1_dec31_22h_closeout_v1();'
);
