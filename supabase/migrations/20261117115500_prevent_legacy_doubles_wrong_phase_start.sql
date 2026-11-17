-- A legacy unstarted doubles match in the wrong week is rebooked
-- before it can start. New doubles are scheduled correctly at creation.
CREATE OR REPLACE FUNCTION public.process_due_doubles_matches_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 m record;
 v_now bigint;
 v_started integer:=0;
 v_held integer:=0;
 v_rebooked integer:=0;
 v_failed integer:=0;
 v_players uuid[];
 v_main_first_week integer;
 v_main_last_week integer;
 v_player uuid;
 v_conflict boolean;
 v_result jsonb;
 v_recovery integer;
BEGIN
 -- Serialize singles and doubles starts in the same database transaction.
 PERFORM pg_advisory_xact_lock(171106,20261117);
 v_now:=public.current_game_second_v1();
 FOR m IN SELECT id FROM public.tournament_doubles_matches
     WHERE status='scheduled' AND scheduled_start_minute IS NULL
       AND team1_id IS NOT NULL AND team2_id IS NOT NULL
     ORDER BY created_at LIMIT 50
 LOOP
   PERFORM public.schedule_doubles_match_v1(m.id);
 END LOOP;

 FOR m IN
   SELECT dm.id,dm.competition_id,dm.scheduled_season_week,dm.scheduled_day,
          dm.scheduled_start_minute,dm.court_number,
          coalesce(dm.estimated_duration_minutes,105) duration_minutes,
          ed.season_number,
          coalesce(ds.minimum_recovery_minutes,60) recovery_minutes,
          t1.player1_id p1,t1.player2_id p2,t2.player1_id p3,t2.player2_id p4
   FROM public.tournament_doubles_matches dm
   JOIN public.tournament_world_competitions wc ON wc.id=dm.competition_id
   JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
   JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
   JOIN public.tournament_doubles_settings ds ON ds.tournament_series_id=ts.id
   JOIN public.tournament_doubles_teams t1 ON t1.id=dm.team1_id
   JOIN public.tournament_doubles_teams t2 ON t2.id=dm.team2_id
   WHERE dm.status='scheduled' AND dm.team1_id IS NOT NULL AND dm.team2_id IS NOT NULL
      AND dm.scheduled_start_minute IS NOT NULL
      AND public.doubles_match_game_second_v1(dm.id)<=v_now
   ORDER BY public.doubles_match_game_second_v1(dm.id),dm.id LIMIT 25
 LOOP
   v_players:=array[m.p1,m.p2,m.p3,m.p4];
   SELECT min(sl.season_week),max(sl.season_week)
   INTO v_main_first_week,v_main_last_week
   FROM public.tournament_world_competitions wc
   JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
   JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
   WHERE wc.id=m.competition_id AND sl.phase='main_draw';

   -- Old pre-restart fixtures may already exist in the wrong week. Move
   -- their unplayed doubles fixture into the real main-draw week before play.
   IF v_main_first_week IS NOT NULL AND
      (m.scheduled_season_week<v_main_first_week OR m.scheduled_season_week>v_main_last_week)
   THEN
     UPDATE public.tournament_doubles_matches
       SET scheduled_start_minute=NULL,court_number=NULL,
           schedule_reason='conflict_pending',updated_at=now()
       WHERE id=m.id AND status='scheduled';
     v_result:=public.schedule_doubles_match_v1(m.id);
     IF v_result->>'status'='scheduled' THEN v_rebooked:=v_rebooked+1;
     ELSE v_failed:=v_failed+1; END IF;
     CONTINUE;
   END IF;

   -- A live singles replay is still a real occupied match, regardless of
   -- how far the game clock advanced while the replay was playing.
   IF EXISTS (
     SELECT 1 FROM public.tournament_matches sm
     WHERE sm.status='in_progress'
       AND (
         sm.player1_id=ANY(v_players) OR sm.player2_id=ANY(v_players)
         OR (sm.competition_id=m.competition_id AND sm.court_number=m.court_number)
       )
   ) THEN
     v_held:=v_held+1;
     CONTINUE;
   END IF;

   v_conflict:=false;
   FOREACH v_player IN ARRAY v_players LOOP
     IF v_player IS NULL THEN CONTINUE; END IF;
     IF public.player_match_slot_conflict_v1(
       v_player,m.competition_id,m.season_number,m.scheduled_season_week,
       m.scheduled_day,m.scheduled_start_minute,m.duration_minutes,
       m.recovery_minutes,m.id
     ) THEN
       v_conflict:=true; EXIT;
     END IF;
   END LOOP;

   IF NOT v_conflict THEN
      SELECT EXISTS(
       SELECT 1 FROM public.tournament_matches sm
       LEFT JOIN public.tournament_match_simulations sim ON sim.match_id=sm.id
       WHERE sm.competition_id=m.competition_id
         AND sm.court_number=m.court_number
         AND sm.scheduled_season_week=m.scheduled_season_week
         AND sm.scheduled_day=m.scheduled_day
         AND sm.status IN ('scheduled','in_progress','completed')
         AND sm.player1_id IS NOT NULL AND sm.player2_id IS NOT NULL
         AND sm.scheduled_start_minute IS NOT NULL
         AND sm.scheduled_start_minute<=m.scheduled_start_minute
         AND m.scheduled_start_minute <
             sm.scheduled_start_minute+
             coalesce(sm.actual_duration_minutes,
               case when sim.match_id is not null
                 then public.simulated_tennis_duration_minutes_v1(sim.total_games,sim.total_points) end,
               sm.estimated_duration_minutes,150)+15
      ) INTO v_conflict;
   END IF;

   IF NOT v_conflict THEN
      SELECT EXISTS(
       SELECT 1 FROM public.tournament_doubles_matches dm2
       WHERE dm2.competition_id=m.competition_id AND dm2.id<>m.id
         AND dm2.court_number=m.court_number
         AND dm2.scheduled_season_week=m.scheduled_season_week
         AND dm2.scheduled_day=m.scheduled_day
         AND dm2.status IN ('scheduled','completed')
         AND dm2.scheduled_start_minute IS NOT NULL
         AND (dm2.scheduled_start_minute<m.scheduled_start_minute
              OR (dm2.scheduled_start_minute=m.scheduled_start_minute AND dm2.id<m.id))
         AND m.scheduled_start_minute <
              dm2.scheduled_start_minute+
              coalesce(dm2.actual_duration_minutes,dm2.estimated_duration_minutes,105)+15
      ) INTO v_conflict;
   END IF;

   IF v_conflict THEN
     UPDATE public.tournament_doubles_matches
       SET scheduled_start_minute=NULL,court_number=NULL,
           schedule_reason='conflict_pending',updated_at=now()
       WHERE id=m.id AND status='scheduled';
     v_result:=public.schedule_doubles_match_v1(m.id);
     IF v_result->>'status'='scheduled' THEN v_rebooked:=v_rebooked+1;
     ELSE v_failed:=v_failed+1; END IF;
     CONTINUE;
   END IF;

   PERFORM public.simulate_doubles_match_v1(m.id);
   v_started:=v_started+1;
 END LOOP;
 RETURN jsonb_build_object('processed',v_started,'held_live',v_held,
                           'rescheduled',v_rebooked,'no_safe_slot',v_failed);
END;
$function$
;
REVOKE EXECUTE ON FUNCTION public.process_due_doubles_matches_v1()
FROM PUBLIC,anon,authenticated;
