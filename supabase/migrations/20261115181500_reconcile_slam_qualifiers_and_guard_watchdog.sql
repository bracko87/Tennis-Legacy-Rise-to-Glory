-- Tennis Legacy — audited repair for Season 1 Australian Grand Slam
-- November 15 2026. Five AI qualifiers earned Q3 but the engine played
-- three invalid Q3 finals before Q2 finished.
-- Preserve every played score/winner; compensate at minimum reached stage
-- without implying that a Q3 match was won or lost.
-- Apply only after strict precondition checks; all writes are atomic.

-- A single-player bye in a later round is valid ONLY after both feeder
-- matches are final and the actual winner/null slots agree with those feeders.
-- Different from the two-player replay guard installed on Nov 15.
CREATE OR REPLACE FUNCTION public.tournament_match_feeders_terminal_v1(p_match_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public','pg_temp'
AS $guard$
  SELECT coalesce((
    SELECT CASE
      WHEN m.round_number <= 1 THEN true
      ELSE EXISTS (
        SELECT 1
        FROM public.tournament_matches f1
        JOIN public.tournament_matches f2
          ON f2.competition_id=f1.competition_id
         AND f2.draw_type=f1.draw_type
         AND f2.round_number=f1.round_number
         AND f2.match_number=f1.match_number+1
        WHERE f1.competition_id=m.competition_id
          AND f1.draw_type=m.draw_type
          AND f1.round_number=m.round_number-1
          AND f1.match_number=2*m.match_number-1
          AND f1.status IN ('completed','bye','walkover','cancelled')
          AND f2.status IN ('completed','bye','walkover','cancelled')
          AND m.player1_id IS NOT DISTINCT FROM f1.winner_id
          AND m.player2_id IS NOT DISTINCT FROM f2.winner_id
      ) END
    FROM public.tournament_matches m WHERE m.id=p_match_id
  ),false);
$guard$;

REVOKE ALL ON FUNCTION public.tournament_match_feeders_terminal_v1(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.run_tournament_operations_watchdog_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_started timestamptz:=clock_timestamp();
  v_recovered integer:=0;
  v_step integer:=0;
  v_problem_count integer:=0;
  v_row record;
  v_inc record;
  v_engine jsonb;
  v_ranking_recovery jsonb;
begin
  for i in 1..32 loop
    update public.tournament_matches m
    set status='bye',
        winner_id=coalesce(m.player1_id,m.player2_id),
        completed_at=coalesce(m.completed_at,now()),
        updated_at=now()
    where m.status='scheduled'
      and ((m.player1_id is null)<>(m.player2_id is null))
      and public.tournament_match_feeders_terminal_v1(m.id)
      and public.tournament_match_game_second_v1(m.id)<=public.current_game_second_v1();

    get diagnostics v_step=row_count;
    v_recovered:=v_recovered+v_step;
    exit when v_step=0;
  end loop;

  if v_recovered>0 then
    v_engine:=public.process_due_match_engine_v1();
    perform public.start_due_match_replays_v1();
    perform public.finalize_due_match_replays_v1();
  end if;

  -- Game time can cross a Monday boundary at 6x between hourly ranking
  -- cron runs. Publish only genuinely due results from finished/cancelled
  -- tournaments, using the ordinary ranking cycle's idempotency protections.
  -- If already published, this query is false and no extra work is done.
  IF (SELECT speed_multiplier FROM public.get_game_clock_v1())>0
     AND NOT (SELECT is_paused FROM public.game_clock WHERE id=1)
     AND EXISTS(
       SELECT 1
       FROM public.get_current_game_day_internal_v1() d
       WHERE mod(
         public.game_day_absolute_v1(d.season,d.month,d.day)
         -(d.season-1)*366-2,7
       )=0
       AND EXISTS (
         SELECT 1
         FROM public.player_tournament_results r
         WHERE r.ranking_publish_status='pending'
           AND r.ranking_publish_absolute_day IS NOT NULL
           AND r.ranking_publish_absolute_day<=public.game_day_absolute_v1(d.season,d.month,d.day)
           AND NOT EXISTS (
             SELECT 1 FROM public.ranking_defence_cycles dc
             WHERE dc.competition_id=r.competition_id
           )
           AND (
             EXISTS (
               SELECT 1 FROM public.tournament_matches fm
               WHERE fm.competition_id=r.competition_id
                 AND fm.draw_type='main_draw'
                 AND lower(fm.round_label)='final'
                 AND fm.status IN ('completed','walkover')
                 AND fm.winner_id IS NOT NULL
             )
             OR EXISTS (
               SELECT 1 FROM public.tournament_cancellations cx
               WHERE cx.competition_id=r.competition_id
             )
           )
       )
     )
  THEN
    BEGIN
      v_ranking_recovery:=public.process_weekly_rankings_v1();
    EXCEPTION WHEN OTHERS THEN
      -- Let the normal Control Center incident surface genuine failures.
      v_ranking_recovery:=jsonb_build_object(
        'status','failed',
        'error',sqlerrm
      );
    END;
  END IF;


  for v_row in
    select * from public.tournament_operations_rows_v1('problems',30) r
    where r.has_problem
  loop
    v_problem_count:=v_problem_count+1;
    perform public.raise_system_incident_v1(
      'watchdog:tournament-operations',
      v_row.issue_severity,
      'Tournament Operations · '||v_row.tournament_name||' · '||v_row.world,
      v_row.issue_message,
      'tournament-ops:'||v_row.competition_id::text,
      jsonb_build_object(
        'competition_id',v_row.competition_id,
        'tournament_name',v_row.tournament_name,
        'world',v_row.world,
        'category_code',v_row.category_code,
        'phase',v_row.phase,
        'issue_key',v_row.issue_key,
        'entry_status',v_row.entry_status,
        'draw_status',v_row.draw_status,
        'matches_status',v_row.matches_status,
        'rewards_status',v_row.rewards_status,
        'closure_status',v_row.closure_status,
        'entry_count',v_row.entry_count,
        'human_entry_count',v_row.human_entry_count,
        'playable_unresolved_matches',v_row.playable_unresolved_matches,
        'result_rows',v_row.result_rows,
        'pending_ranking_rows',v_row.pending_ranking_rows,
        'human_prize_results',v_row.human_prize_results,
        'human_prize_payments',v_row.human_prize_payments,
        'main_final_completed',v_row.main_final_completed
      )
    );
  end loop;

  for v_inc in
    select si.dedupe_key
    from public.system_incidents si
    where si.process_key='watchdog:tournament-operations'
      and si.status in ('open','acknowledged')
      and not exists(
        select 1
        from public.tournament_operations_rows_v1('problems',30) r
        where r.has_problem
          and 'tournament-ops:'||r.competition_id::text=si.dedupe_key
      )
  loop
    perform public.resolve_system_incident_by_dedupe_v1(
      v_inc.dedupe_key,
      'Tournament lifecycle recovered and is now consistent.'
    );
  end loop;

  insert into public.system_monitor_runs(
    process_key,status,started_at,finished_at,duration_ms,summary,details
  )
  values(
    'watchdog:tournament-operations',
    case when v_problem_count>0 then 'warning' else 'success' end,
    v_started,
    clock_timestamp(),
    greatest(0,round(extract(epoch from (clock_timestamp()-v_started))*1000)::bigint),
    case
      when v_problem_count>0 then format('%s tournament issue(s) active.',v_problem_count)
      when v_recovered>0 then format('Healthy after automatically recovering %s orphan bye(s).',v_recovered)
      else 'Tournament lifecycle checks passed.'
    end,
    jsonb_build_object(
      'active_problems',v_problem_count,
      'orphan_byes_recovered',v_recovered,
      'engine_after_recovery',coalesce(v_engine,'{}'::jsonb),
      'ranking_recovery',coalesce(v_ranking_recovery,'{}'::jsonb)
    )
  );

  return jsonb_build_object(
    'status',case when v_problem_count>0 then 'warning' else 'success' end,
    'active_problems',v_problem_count,
    'orphan_byes_recovered',v_recovered
  );
end;
$function$
;

-- Private, immutable evidence of administrative fairness repairs. No phantom match is created.
CREATE TABLE IF NOT EXISTS control_center_private.tournament_qualification_nocontest_repairs_v1 (
  competition_id uuid NOT NULL REFERENCES public.tournament_world_competitions(id),
  player_id uuid NOT NULL REFERENCES public.players(id),
  q2_match_id uuid NOT NULL REFERENCES public.tournament_matches(id),
  invalid_q3_match_id uuid NOT NULL REFERENCES public.tournament_matches(id),
  result_id uuid NOT NULL REFERENCES public.player_tournament_results(id),
  world text NOT NULL CHECK (world IN ('ATP','WTA')),
  compensated_points integer NOT NULL,
  compensated_prize_money bigint NOT NULL,
  evidence jsonb NOT NULL,
  repaired_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (competition_id,player_id),
  UNIQUE(result_id)
);
ALTER TABLE control_center_private.tournament_qualification_nocontest_repairs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tournament_qualification_nocontest_repairs_v1 FROM PUBLIC, anon, authenticated;

-- Historical one-time repair scoped by real tournament names, season and
-- verified match history. NEVER change a completed fixture, winner, or score.
DO $repair$
DECLARE
  v_candidate record;
  v_result_id uuid;
  v_points integer;
  v_prize bigint;
  v_published_day integer;
  v_current_day integer;
  v_latest_publication_day integer;
  v_all integer;
  v_atp integer;
  v_wta integer;
  v_repaired integer:=0;
  v_rows integer;
BEGIN
  SELECT public.game_day_absolute_v1(d.season,d.month,d.day)
  INTO v_current_day FROM public.get_current_game_day_internal_v1() d;

  SELECT max(game_absolute_day) INTO v_latest_publication_day
  FROM public.ranking_publication_runs;

  IF v_current_day <= v_latest_publication_day THEN
    RAISE EXCEPTION 'Ranking publication day has not yet passed; stop repair.';
  END IF;

  SELECT count(*),
         count(*) FILTER (WHERE wc.world='ATP'),
         count(*) FILTER (WHERE wc.world='WTA')
  INTO v_all,v_atp,v_wta
  FROM public.tournament_entries e
  JOIN public.tournament_world_competitions wc ON wc.id=e.competition_id
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
  LEFT JOIN public.player_tournament_results r ON r.competition_id=e.competition_id AND r.player_id=e.player_id
  WHERE ts.name='Australian Grand Slam'
    AND ed.season_number=1
    AND wc.status='completed'
    AND e.entry_status='active'
    AND r.id IS NULL;

  IF v_all<>5 OR v_atp<>3 OR v_wta<>2 THEN
    RAISE EXCEPTION 'Live results changed, expected 5 (ATP 3/WTA 2): found % (ATP %/WTA %)',v_all,v_atp,v_wta;
  END IF;

  FOR v_candidate IN
    SELECT
      e.id entry_id,e.player_id,e.competition_id,e.draw_type,e.entry_status,
      wc.world,ed.season_number,ts.id as series_id,ts.category_code,
      q2.id q2_id,q2.completed_at q2_completed_at,q2.match_number q2_match_number,
      q3.id q3_id,q3.completed_at q3_completed_at,
      q3.player1_id q3_p1,q3.player2_id q3_p2,q3.winner_id q3_winner,
      pr.ranking_points as old_ranking_points
    FROM public.tournament_entries e
    JOIN public.tournament_world_competitions wc ON wc.id=e.competition_id
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
    JOIN public.players pl ON pl.id=e.player_id
    JOIN public.player_rankings pr ON pr.player_id=e.player_id
    JOIN public.tournament_matches q2 ON q2.competition_id=e.competition_id
      AND q2.draw_type='qualification'
      AND q2.round_number=2
      AND q2.status='completed'
      AND q2.winner_id=e.player_id
    JOIN public.tournament_matches q3 ON q3.competition_id=e.competition_id
      AND q3.draw_type='qualification'
      AND q3.round_number=3
      AND q3.match_number=(q2.match_number+1)/2
      AND q3.status='completed'
      AND q3.winner_id IS NOT NULL
    LEFT JOIN public.player_tournament_results r ON r.competition_id=e.competition_id AND r.player_id=e.player_id
    WHERE ts.name='Australian Grand Slam'
      AND ed.season_number=1
      AND wc.status='completed'
      AND e.draw_type='qualification'
      AND e.entry_status='active'
      AND r.id IS NULL
      AND pl.player_type='ai'
    ORDER BY wc.world,e.player_id
  LOOP
    IF v_candidate.q3_p1=v_candidate.player_id OR v_candidate.q3_p2=v_candidate.player_id
      OR v_candidate.q3_completed_at>=v_candidate.q2_completed_at
      OR public.tournament_match_feeders_ready_v1(v_candidate.q3_id) THEN
      RAISE EXCEPTION 'Unexpected match history: player % must not receive no-contest repair.',v_candidate.player_id;
    END IF;

    IF NOT EXISTS(
      SELECT 1 FROM public.ranking_defence_cycles dc
      WHERE dc.competition_id=v_candidate.competition_id
    ) THEN
      RAISE EXCEPTION 'Ranking cycle was not published for competition %.',v_candidate.competition_id;
    END IF;

    SELECT rp.points INTO STRICT v_points
    FROM public.tournament_ranking_point_rules rp
    WHERE rp.category_code=v_candidate.category_code
      AND rp.stage_code='qualifying_final_loss';

    SELECT pp.payout_per_player_usd INTO STRICT v_prize
    FROM public.tournament_prize_payouts pp
    WHERE pp.tournament_series_id=v_candidate.series_id
      AND pp.stage_code='qualifying_final_loss';

    IF v_candidate.category_code<>'grand_slam_2000' OR v_points<>16 OR v_prize<>50000 THEN
      RAISE EXCEPTION 'Unexpected minimum finalist reward (% / %) for player %',v_points,v_prize,v_candidate.player_id;
    END IF;

    SELECT public.training_camp_week_start_absolute_v1(
      v_candidate.season_number,max(ss.season_week)::smallint
    )+7 INTO v_published_day
    FROM public.tournament_world_competitions wc
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
    WHERE wc.id=v_candidate.competition_id;

    IF v_published_day<>v_latest_publication_day THEN
      RAISE EXCEPTION 'Unexpected publish day % (latest is %)',v_published_day,v_latest_publication_day;
    END IF;

    -- Display result as 'Qualifying' with a distinct administrative stage.
    -- Do NOT mark a Q3 match as lost or create a fabricated outcome.
    INSERT INTO public.player_tournament_results(
      player_id,competition_id,result_code,result_stage_code,
      ranking_points_earned,prize_money_earned,qualifying_bonus_points,
      ranking_publish_status,ranking_publish_absolute_day,ranking_published_at,
      completed_at,updated_at
    ) VALUES (
      v_candidate.player_id,v_candidate.competition_id,
      'qualifying','qualifying_final_administrative_nocontest',
      v_points,v_prize,0,
      'published',v_published_day,now(),now(),now()
    ) RETURNING id INTO v_result_id;

    UPDATE public.tournament_entries e
      SET entry_status='eliminated',updated_at=now()
      WHERE e.id=v_candidate.entry_id AND e.entry_status='active';
    GET DIAGNOSTICS v_rows=ROW_COUNT;
    IF v_rows<>1 THEN RAISE EXCEPTION 'Entry modified concurrently for player %',v_candidate.player_id; END IF;

    INSERT INTO public.player_ranking_contributions(
      player_id,source_result_id,competition_id,tournament_series_id,
      world,season_number,ranking_points,
      awarded_absolute_day,expires_absolute_day,published_at,is_active
    ) VALUES (
      v_candidate.player_id,v_result_id,v_candidate.competition_id,v_candidate.series_id,
      v_candidate.world,v_candidate.season_number,v_points,
      v_published_day,v_published_day+366,now(),true
    );

    INSERT INTO control_center_private.tournament_qualification_nocontest_repairs_v1(
      competition_id,player_id,q2_match_id,invalid_q3_match_id,result_id,
      world,compensated_points,compensated_prize_money,evidence
    ) VALUES (
      v_candidate.competition_id,v_candidate.player_id,v_candidate.q2_id,
      v_candidate.q3_id,v_result_id,v_candidate.world,v_points,v_prize,
      jsonb_build_object(
        'reason','qualifying_final_started_before_feeder_finalized',
        'disposition','minimum_stage_compensation_only',
        'no_match_result_invented',true,
        'original_entry_status',v_candidate.entry_status,
        'q2_match_number',v_candidate.q2_match_number,
        'q2_completed_at',v_candidate.q2_completed_at,
        'invalid_q3_completed_at',v_candidate.q3_completed_at,
        'invalid_q3_player1_id',v_candidate.q3_p1,
        'invalid_q3_player2_id',v_candidate.q3_p2,
        'invalid_q3_winner_id',v_candidate.q3_winner,
        'prior_ranking_points',v_candidate.old_ranking_points,
        'ranking_publish_absolute_day',v_published_day,
        'valid_match_results_untouched',true
      )
    );

    UPDATE public.ranking_defence_cycles dc
      SET published_results=published_results+1,
          activated_contributions=activated_contributions+1
      WHERE dc.competition_id=v_candidate.competition_id;
    GET DIAGNOSTICS v_rows=ROW_COUNT;
    IF v_rows<>1 THEN RAISE EXCEPTION 'Missing ranking defence cycle for %',v_candidate.competition_id; END IF;

    v_repaired:=v_repaired+1;
  END LOOP;

  IF v_repaired<>5 THEN
    RAISE EXCEPTION 'Expected five distinct verified no-contests, found %',v_repaired;
  END IF;

  UPDATE public.ranking_publication_runs
    SET published_results=published_results+5,
        contributions_activated=contributions_activated+5
    WHERE game_absolute_day=v_latest_publication_day;
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  IF v_rows<>1 THEN RAISE EXCEPTION 'Missing publication run for day %',v_latest_publication_day; END IF;

  -- Keep authoritative ranking totals aligned with the contributions ledger.
  UPDATE public.player_rankings pr
  SET ranking_points=coalesce((
    SELECT sum(c.ranking_points)::integer
    FROM public.player_ranking_contributions c
    WHERE c.player_id=pr.player_id AND c.is_active
  ),0),updated_at=now()
  WHERE EXISTS(
    SELECT 1 FROM control_center_private.tournament_qualification_nocontest_repairs_v1 a
    WHERE a.player_id=pr.player_id
  );
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  IF v_rows<>5 THEN RAISE EXCEPTION 'Expected five ranking totals updated, got %',v_rows; END IF;

  -- This is the latest and only publication after the affected competition.
  -- Correct the existing day-23 official snapshot, not a phantom publication.
  WITH ranked AS (
    SELECT pl.id player_id,pl.world,
      row_number() OVER(PARTITION BY pl.world ORDER BY
        coalesce(pr.ranking_points,0) DESC,
        coalesce(pr.seed_rating,0) DESC,
        pl.created_at ASC,pl.id ASC)::integer ranking_position,
      coalesce(pr.ranking_points,0) as ranking_points
    FROM public.players pl
    LEFT JOIN public.player_rankings pr ON pr.player_id=pl.id
    WHERE pl.world IN ('ATP','WTA')
  )
  UPDATE public.player_ranking_snapshots s
    SET ranking_points=ranked.ranking_points,
        ranking_position=ranked.ranking_position
  FROM ranked
  WHERE s.player_id=ranked.player_id
    AND s.world=ranked.world
    AND s.game_absolute_day=v_latest_publication_day;
  GET DIAGNOSTICS v_rows=ROW_COUNT;
  IF v_rows<>(SELECT count(*) FROM public.players WHERE world IN ('ATP','WTA')) THEN
    RAISE EXCEPTION 'Ranking snapshot coverage incomplete: % rows',v_rows;
  END IF;

  IF EXISTS(
    SELECT 1 FROM public.tournament_entries e
    JOIN public.tournament_world_competitions wc ON wc.id=e.competition_id
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
    LEFT JOIN public.player_tournament_results r
      ON r.competition_id=e.competition_id AND r.player_id=e.player_id
    WHERE ts.name='Australian Grand Slam'
      AND ed.season_number=1
      AND wc.status='completed'
      AND e.entry_status='active'
      AND r.id IS NULL
  ) THEN
    RAISE EXCEPTION 'Active entries without results remain.';
  END IF;
END
$repair$;
