-- Season 1 final-week closeout. The ordinary match engine still plays all finals.
-- This one-off, private cron checkpoint waits for real match completion,
-- then credits pending Week 52 ranking results on Dec 31 rather than after
-- the protected season boundary. Player accounts, balances, and history remain.
CREATE TABLE IF NOT EXISTS control_center_private.tennis_season1_final_closeout_v1 (
  season_number integer PRIMARY KEY CHECK (season_number=1),
  game_absolute_day integer NOT NULL CHECK (game_absolute_day=365),
  completed_at timestamptz NOT NULL DEFAULT now(),
  final_matches integer NOT NULL,
  competition_count integer NOT NULL,
  ranking_results_published integer NOT NULL,
  ranking_contributions_activated integer NOT NULL,
  ranking_cycles_processed integer NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb
);
REVOKE ALL ON control_center_private.tennis_season1_final_closeout_v1 FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION control_center_private.process_tennis_season1_final_closeout_v1()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, control_center_private
AS $closeout$
DECLARE
  v_game bigint;
  d record;
  v_final_count integer;
  v_final_complete integer;
  v_competitions integer;
  v_unfinished integer;
  v_missing_results integer;
  v_missing_prizes integer;
  v_published integer:=0;
  v_activated integer:=0;
  v_cycles integer:=0;
  v_n integer;
  v_cycle_published integer;
  v_cycle_activated integer;
  rec record;
BEGIN
  PERFORM pg_advisory_xact_lock(2026, 1231);

  IF EXISTS(SELECT 1 FROM control_center_private.tennis_season1_final_closeout_v1 WHERE season_number=1) THEN
    RETURN jsonb_build_object('status','already_completed','season',1);
  END IF;

  SELECT game_total_seconds INTO v_game FROM public.get_game_clock_v1();
  SELECT * INTO d FROM public.get_current_game_day_internal_v1();
  IF d.season IS DISTINCT FROM 1 OR d.month IS DISTINCT FROM 12 OR d.day IS DISTINCT FROM 31
     OR v_game < (365::bigint*86400 + 16*3600) THEN
    RETURN jsonb_build_object('status','waiting_for_december_31_finals','season',d.season,
                              'month',d.month,'day',d.day);
  END IF;

  SELECT count(DISTINCT wc.id),
         count(DISTINCT tm.id) FILTER (WHERE tm.draw_type='main_draw' AND lower(tm.round_label)='final'),
         count(DISTINCT tm.id) FILTER (WHERE tm.draw_type='main_draw' AND lower(tm.round_label)='final'
             AND tm.status IN ('completed','walkover') AND tm.winner_id IS NOT NULL)
  INTO v_competitions,v_final_count,v_final_complete
  FROM public.tournament_world_competitions wc
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
  LEFT JOIN public.tournament_matches tm ON tm.competition_id=wc.id
  WHERE ed.season_number=1 AND sl.season_week=52;

  IF v_competitions<>12 OR v_final_count<>12 THEN
    RETURN jsonb_build_object('status','blocked_wrong_final_inventory',
                              'competitions',v_competitions,'finals',v_final_count);
  END IF;
  IF v_final_complete<>12 THEN
    RETURN jsonb_build_object('status','waiting_for_real_finals',
                              'completed_finals',v_final_complete,'required',12);
  END IF;

  SELECT count(*) INTO v_unfinished
  FROM public.tournament_world_competitions wc
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  WHERE ed.season_number=1 AND wc.status NOT IN ('completed','canceled');
  IF v_unfinished>0 OR EXISTS(
    SELECT 1 FROM public.tournament_editions
    WHERE season_number=1 AND status NOT IN ('completed','canceled')
  ) OR EXISTS (
    SELECT 1 FROM public.tournament_matches tm
    JOIN public.tournament_world_competitions wc ON wc.id=tm.competition_id
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    WHERE ed.season_number=1 AND tm.status IN ('scheduled','in_progress')
  ) OR EXISTS(
    SELECT 1 FROM public.tournament_doubles_matches dm
    JOIN public.tournament_world_competitions wc ON wc.id=dm.competition_id
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    WHERE ed.season_number=1 AND dm.status IN ('scheduled','in_progress')
  ) OR EXISTS(
    SELECT 1 FROM public.tournament_match_simulations sim
    JOIN public.tournament_matches tm ON tm.id=sim.match_id
    JOIN public.tournament_world_competitions wc ON wc.id=tm.competition_id
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    WHERE ed.season_number=1 AND sim.simulation_status IN ('prepared','live')
  ) THEN
    RETURN jsonb_build_object('status','waiting_for_tournament_closure',
                              'unfinished_competitions',v_unfinished);
  END IF;

  SELECT count(*) INTO v_missing_results
  FROM public.tournament_matches tm
  JOIN public.tournament_world_competitions wc ON wc.id=tm.competition_id
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
  LEFT JOIN public.player_tournament_results r1 ON r1.competition_id=tm.competition_id
                                                AND r1.player_id=tm.player1_id
  LEFT JOIN public.player_tournament_results r2 ON r2.competition_id=tm.competition_id
                                                AND r2.player_id=tm.player2_id
  WHERE ed.season_number=1 AND sl.season_week=52
    AND tm.draw_type='main_draw' AND lower(tm.round_label)='final'
    AND (r1.id IS NULL OR r2.id IS NULL
         OR NOT EXISTS(
           SELECT 1 FROM public.player_tournament_results winner
           WHERE winner.competition_id=tm.competition_id AND winner.player_id=tm.winner_id
             AND winner.result_code='champion'
         ));
  IF v_missing_results>0 THEN
    RETURN jsonb_build_object('status','waiting_for_final_player_results',
                              'missing_finalist_results',v_missing_results);
  END IF;

  SELECT count(*) INTO v_missing_prizes
  FROM public.player_tournament_results r
  JOIN public.tournament_world_competitions wc ON wc.id=r.competition_id
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
  JOIN public.players p ON p.id=r.player_id
  WHERE ed.season_number=1 AND sl.season_week=52
    AND p.player_type='human' AND r.prize_money_earned>0
    AND NOT EXISTS(
      SELECT 1 FROM public.career_finance_transactions tx
      WHERE tx.player_id=r.player_id
        AND tx.idempotency_key='tournament-prize:'||r.competition_id::text||':'||r.player_id::text
    );
  IF v_missing_prizes>0 THEN
    RETURN jsonb_build_object('status','blocked_missing_prize_payments','missing_payments',v_missing_prizes);
  END IF;

  -- Publish only the 12 real Week 52 competitions once, one calendar day
  -- before their default Jan 1 publication date; record the actual Dec 31
  -- publication day for correct one-season point expiry.
  FOR rec IN
    SELECT DISTINCT wc.id competition_id,ed.tournament_series_id,wc.world
    FROM public.tournament_world_competitions wc
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
    WHERE ed.season_number=1 AND sl.season_week=52 AND wc.status='completed'
    ORDER BY wc.id
  LOOP
    IF EXISTS(SELECT 1 FROM public.ranking_defence_cycles dc
              WHERE dc.competition_id=rec.competition_id) THEN
      CONTINUE;
    END IF;

    UPDATE public.player_tournament_results r
    SET ranking_publish_status='published',
        ranking_publish_absolute_day=365,
        ranking_published_at=coalesce(r.ranking_published_at,now()),
        updated_at=now()
    WHERE r.competition_id=rec.competition_id
      AND r.ranking_publish_status='pending'
      AND r.ranking_publish_absolute_day IS NOT NULL
      AND r.ranking_publish_absolute_day<=366;
    GET DIAGNOSTICS v_cycle_published=ROW_COUNT;
    v_published:=v_published+v_cycle_published;

    IF EXISTS(SELECT 1 FROM public.player_tournament_results r
              WHERE r.competition_id=rec.competition_id AND r.ranking_publish_status='pending') THEN
      RAISE EXCEPTION 'Unpublished/undated ranking result in competition %',rec.competition_id;
    END IF;

    INSERT INTO public.player_ranking_contributions(
      player_id,source_result_id,competition_id,tournament_series_id,world,
      season_number,ranking_points,awarded_absolute_day,expires_absolute_day,
      published_at,is_active
    )
    SELECT r.player_id,r.id,r.competition_id,rec.tournament_series_id,rec.world,
           1,greatest(r.ranking_points_earned,0),365,731,
           coalesce(r.ranking_published_at,now()),true
    FROM public.player_tournament_results r
    WHERE r.competition_id=rec.competition_id AND r.ranking_publish_status='published'
    ON CONFLICT(source_result_id) DO NOTHING;
    GET DIAGNOSTICS v_cycle_activated=ROW_COUNT;
    v_activated:=v_activated+v_cycle_activated;

    INSERT INTO public.ranking_defence_cycles(
      competition_id,tournament_series_id,world,season_number,
      previous_season_number,scheduled_publish_absolute_day,processed_absolute_day,
      processing_reason,published_results,expired_contributions,
      activated_contributions,processed_at
    ) VALUES (
      rec.competition_id,rec.tournament_series_id,rec.world,1,
      NULL,366,365,'edition_completed',v_cycle_published,0,v_cycle_activated,now()
    ) ON CONFLICT(competition_id) DO NOTHING;
    v_cycles:=v_cycles+1;
  END LOOP;

  IF v_cycles<>12 THEN
    RAISE EXCEPTION 'Season1 year-end checkpoint expected 12 new ranking cycles, found %',v_cycles;
  END IF;

  UPDATE public.player_rankings pr
  SET ranking_points=coalesce((
    SELECT sum(c.ranking_points)::integer
    FROM public.player_ranking_contributions c
    WHERE c.player_id=pr.player_id AND c.is_active
  ),0),updated_at=now();

  PERFORM public.capture_world_ranking_snapshot_internal_v1();

  -- This insert also invokes the installed doubles-ranking snapshot trigger,
  -- preserving the existing ATP/WTA + doubles ranking publication pipeline.
  INSERT INTO public.ranking_publication_runs(
    game_absolute_day,season,month,day,published_results,processed_at,
    defence_cycles_processed,contributions_expired,
    contributions_activated,orphan_contributions_expired
  ) VALUES (365,1,12,31,v_published,now(),v_cycles,0,v_activated,0)
  ON CONFLICT(game_absolute_day) DO UPDATE SET
    published_results=public.ranking_publication_runs.published_results+excluded.published_results,
    defence_cycles_processed=public.ranking_publication_runs.defence_cycles_processed+excluded.defence_cycles_processed,
    contributions_activated=public.ranking_publication_runs.contributions_activated+excluded.contributions_activated,
    processed_at=now();

  INSERT INTO control_center_private.tennis_season1_final_closeout_v1(
    season_number,game_absolute_day,final_matches,competition_count,
    ranking_results_published,ranking_contributions_activated,
    ranking_cycles_processed,details
  ) VALUES(
    1,365,v_final_complete,v_competitions,v_published,v_activated,v_cycles,
    jsonb_build_object('reason','year_end_last_day_real_results_only',
                       'prize_money','verified_existing_idempotent_transactions',
                       'ranking_publication_day',365,
                       'scheduled_ranking_publication_day',366)
  );

  RETURN jsonb_build_object('status','completed','finals',v_final_complete,
                            'ranking_results_published',v_published,
                            'ranking_contributions_activated',v_activated,
                            'ranking_cycles_processed',v_cycles);
END;
$closeout$;

REVOKE ALL ON FUNCTION control_center_private.process_tennis_season1_final_closeout_v1()
  FROM PUBLIC, anon, authenticated;

-- Trigger a quick, once-only closeout as soon as all real Dec 31 finals finish.
-- The routine is a read-only no-op until the finals and prize transactions pass.
SELECT cron.schedule('tennis-season1-final-closeout-v1','* * * * *',
                     'select control_center_private.process_tennis_season1_final_closeout_v1();');
