-- Future match runtime: simulate game-time match lengths, and prevent a later
-- singles match starting when the same player or court is still occupied.
-- No mass historical backfill or edits to matches on installation.
CREATE OR REPLACE FUNCTION public.simulated_tennis_duration_minutes_v1(
 p_total_games integer,p_total_points integer
) RETURNS integer LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER
SET search_path TO 'public','pg_temp'
AS $function$
 SELECT least(420,greatest(60,round(greatest(p_total_games,0)*5.0+
                                      greatest(p_total_points,0)*0.13)::integer))
$function$;
REVOKE ALL ON FUNCTION public.simulated_tennis_duration_minutes_v1(integer,integer)
FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ensure_safe_singles_start_v1(p_match_id uuid,p_game_second bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
 target record;
 rule public.tournament_match_scheduling_rules%rowtype;
 v_phase_first_week integer;
 v_phase_last_week integer;
 v_phase_first_day integer;
 v_phase_last_day integer;
 v_original_day integer;
 v_original_abs bigint;
 v_day integer;
 v_first_candidate integer;
 v_start integer;
 v_abs bigint;
 v_game_abs_min bigint:=greatest(0,p_game_second/60);
 v_clock_speed numeric:=1;
 v_court integer;
 v_court_offset integer;
 v_max_courts integer;
 v_pref_court integer;
 v_duration integer;
 v_blocked boolean;
 v_conflict_count integer:=0;
 v_moved_count integer:=0;
BEGIN
 SELECT m.*,ed.season_number,ts.category_code
 INTO target
 FROM public.tournament_matches m
 JOIN public.tournament_world_competitions wc ON wc.id=m.competition_id
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
 WHERE m.id=p_match_id
 FOR UPDATE OF m;

 IF target.id IS NULL OR target.status<>'scheduled'
    OR target.player1_id IS NULL OR target.player2_id IS NULL THEN
   RETURN jsonb_build_object('status','not_eligible');
 END IF;

 SELECT r.* INTO rule FROM public.tournament_match_scheduling_rules r
 WHERE r.category_code=target.category_code;
 SELECT coalesce(speed_multiplier,1) INTO v_clock_speed FROM public.game_clock WHERE id=1;
 v_clock_speed:=greatest(0.001,coalesce(v_clock_speed,1));
 v_max_courts:=greatest(1,coalesce(rule.court_count,1));
 v_pref_court:=greatest(1,least(v_max_courts,coalesce(target.court_number,1)));

 SELECT min(sl.season_week),max(sl.season_week)
 INTO v_phase_first_week,v_phase_last_week
 FROM public.tournament_world_competitions wc
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
 WHERE wc.id=target.competition_id AND sl.phase=target.draw_type;

 v_phase_first_week:=coalesce(v_phase_first_week,target.scheduled_season_week);
 v_phase_last_week:=coalesce(v_phase_last_week,target.scheduled_season_week);
 v_phase_first_day:=(target.season_number-1)*366+2+(v_phase_first_week-1)*7;
 v_phase_last_day:=(target.season_number-1)*366+2+(v_phase_last_week-1)*7+6;
 v_original_day:=(target.season_number-1)*366+2+(target.scheduled_season_week-1)*7+(target.scheduled_day-1);
 v_original_abs:=v_original_day::bigint*1440+coalesce(target.scheduled_start_minute,600);

 SELECT coalesce(public.simulated_tennis_duration_minutes_v1(sim.total_games,sim.total_points),
                 target.estimated_duration_minutes,150) INTO v_duration
 FROM public.tournament_match_simulations sim WHERE sim.match_id=target.id;
 v_duration:=coalesce(v_duration,target.estimated_duration_minutes,150);

 -- Keep the scheduled match in its qualification/main phase; existing historic
 -- results and live matches are never touched.
 FOR v_day IN greatest(v_original_day,v_phase_first_day)..v_phase_last_day LOOP
   v_first_candidate:=case when v_day=v_original_day then
                          greatest(600,coalesce(target.scheduled_start_minute,600))
                          else 600 end;

   FOR v_start IN SELECT generate_series(v_first_candidate,1290,30) LOOP
      v_abs:=v_day::bigint*1440+v_start;
      IF v_abs<>v_original_abs AND v_abs<=v_game_abs_min+10 THEN CONTINUE; END IF;

      FOR v_court_offset IN 0..v_max_courts-1 LOOP
        v_court:=((v_pref_court-1+v_court_offset)%v_max_courts)+1;
        SELECT EXISTS (
          SELECT 1
          FROM public.tournament_matches x
          JOIN public.tournament_world_competitions wc2 ON wc2.id=x.competition_id
          JOIN public.tournament_editions ed2 ON ed2.id=wc2.tournament_edition_id
          LEFT JOIN public.tournament_match_simulations sx ON sx.match_id=x.id
          CROSS JOIN LATERAL (
             SELECT ((ed2.season_number-1)*366+2+(x.scheduled_season_week-1)*7+(x.scheduled_day-1))::bigint AS day_abs
          ) day_pos
          CROSS JOIN LATERAL (
             SELECT day_pos.day_abs*1440+coalesce(x.scheduled_start_minute,600) AS start_abs,
               coalesce(x.actual_duration_minutes,
                        CASE WHEN sx.match_id IS NOT NULL
                          THEN public.simulated_tennis_duration_minutes_v1(sx.total_games,sx.total_points) END,
                        x.estimated_duration_minutes,150)::integer AS minutes_long
          ) occupancy
          CROSS JOIN LATERAL (
             SELECT greatest(occupancy.start_abs+occupancy.minutes_long,
               CASE WHEN x.status='in_progress' AND sx.live_ends_at>now()
                 THEN v_game_abs_min+ceil(extract(epoch from(sx.live_ends_at-now()))*v_clock_speed/60)::bigint
                 ELSE occupancy.start_abs END) AS projected_end_abs
          ) occupied_until
          WHERE x.id<>target.id AND x.status IN ('scheduled','in_progress','completed')
            AND x.scheduled_start_minute IS NOT NULL
            AND x.player1_id IS NOT NULL AND x.player2_id IS NOT NULL
            AND occupancy.start_abs<=v_abs
            AND (occupancy.start_abs<v_abs OR x.status IN ('in_progress','completed') OR x.id<target.id)
            AND (
              (x.competition_id=target.competition_id
               AND x.court_number=v_court
               AND v_abs<occupied_until.projected_end_abs+15)
              OR
              (
               ((x.player1_id IS NOT NULL AND x.player1_id IN (target.player1_id,target.player2_id))
                 OR (x.player2_id IS NOT NULL AND x.player2_id IN (target.player1_id,target.player2_id)))
               AND
               ( (x.competition_id<>target.competition_id AND day_pos.day_abs=v_day)
                 OR v_abs<occupied_until.projected_end_abs+60
               )
              )
            )
        ) INTO v_blocked;

        IF NOT v_blocked THEN
          IF v_abs=v_original_abs AND v_court=v_pref_court THEN
            RETURN jsonb_build_object('status','ready','duration_minutes',v_duration);
          END IF;
          UPDATE public.tournament_matches
          SET scheduled_season_week=(1+((v_day-((target.season_number-1)*366+2))/7))::integer,
              scheduled_day=(((v_day-((target.season_number-1)*366+2))%7)+1)::smallint,
              scheduled_start_minute=v_start::smallint,
              court_number=v_court::smallint,
              updated_at=now()
          WHERE id=target.id AND status='scheduled';
          RETURN jsonb_build_object('status','rescheduled','old_day',v_original_day,
                 'new_day',v_day,'old_minute',target.scheduled_start_minute,
                 'new_minute',v_start,'court',v_court,'duration_minutes',v_duration);
        END IF;
        v_conflict_count:=v_conflict_count+1;
      END LOOP;
   END LOOP;
 END LOOP;

 -- Fail closed. Do not start an impossible or overlapping match.
 PERFORM public.raise_system_incident_v1(
   'process:tennis-match-scheduling','high',
   'No safe match slot before tournament phase ends',
   format('Match %s cannot be fitted in the configured phase without player/court conflict.',target.id),
   'business:tennis-match-slot:'||target.id::text,
   jsonb_build_object('competition_id',target.competition_id,'match_id',target.id,
      'phase',target.draw_type,'original_week',target.scheduled_season_week,
      'phase_first_week',v_phase_first_week,'phase_last_week',v_phase_last_week,
      'conflicts_examined',v_conflict_count)
 );
 RETURN jsonb_build_object('status','blocked','reason','no_safe_slot_in_phase');
END;
$function$;
REVOKE ALL ON FUNCTION public.ensure_safe_singles_start_v1(uuid,bigint)
FROM PUBLIC,anon,authenticated;
