-- Proactively adjust later same-day matches after a longer simulated
-- completion. The existing start guard remains authoritative for all matches.
CREATE OR REPLACE FUNCTION public.reschedule_following_player_matches_v1(p_match_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
 played record;
 v_start_abs bigint;
 v_end_abs bigint;
 v_current_second bigint;
 v_result jsonb;
 v_rescheduled integer:=0;
 v_blocked integer:=0;
 next_match record;
BEGIN
 SELECT m.*,ed.season_number INTO played
 FROM public.tournament_matches m
 JOIN public.tournament_world_competitions wc ON wc.id=m.competition_id
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 WHERE m.id=p_match_id;
 IF played.id IS NULL OR played.status<>'completed'
    OR played.actual_duration_minutes IS NULL
    OR played.actual_duration_minutes<=coalesce(played.estimated_duration_minutes,150)
 THEN RETURN jsonb_build_object('status','no_overrun'); END IF;
 v_start_abs:=(((played.season_number-1)*366)+2
       +((played.scheduled_season_week-1)*7)+(played.scheduled_day-1))::bigint*1440
       +coalesce(played.scheduled_start_minute,600);
 v_end_abs:=v_start_abs+played.actual_duration_minutes+60;
 v_current_second:=public.current_game_second_v1();
 FOR next_match IN
  SELECT x.id,(((ed2.season_number-1)*366)+2+
        ((x.scheduled_season_week-1)*7)+(x.scheduled_day-1))::bigint*1440+
        coalesce(x.scheduled_start_minute,600) AS game_start
  FROM public.tournament_matches x
  JOIN public.tournament_world_competitions wc2 ON wc2.id=x.competition_id
  JOIN public.tournament_editions ed2 ON ed2.id=wc2.tournament_edition_id
  WHERE x.id<>played.id AND x.status='scheduled'
    AND x.player1_id IS NOT NULL AND x.player2_id IS NOT NULL
    AND (x.player1_id IN (played.player1_id,played.player2_id)
      OR x.player2_id IN (played.player1_id,played.player2_id))
    AND (((ed2.season_number-1)*366)+2+
        ((x.scheduled_season_week-1)*7)+(x.scheduled_day-1))::bigint*1440+
        coalesce(x.scheduled_start_minute,600) BETWEEN v_start_abs AND v_end_abs
  ORDER BY game_start,x.id
 LOOP
   v_result:=public.ensure_safe_singles_start_v1(next_match.id,v_current_second);
   IF v_result->>'status'='rescheduled' THEN v_rescheduled:=v_rescheduled+1;
   ELSIF v_result->>'status'='blocked' THEN v_blocked:=v_blocked+1;
   END IF;
 END LOOP;
 RETURN jsonb_build_object('status','checked','rescheduled',v_rescheduled,'blocked',v_blocked);
END;
$function$;
REVOKE ALL ON FUNCTION public.reschedule_following_player_matches_v1(uuid)
FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.finalize_match_replay_v1(p_match_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare s public.tournament_match_simulations%rowtype;m public.tournament_matches%rowtype;x jsonb;st1 jsonb;st2 jsonb;
begin
  select * into s from public.tournament_match_simulations where match_id=p_match_id for update;
  if s.match_id is null then raise exception 'Simulation not found.';end if;
  if s.simulation_status='completed' then return jsonb_build_object('status','already_completed');end if;
  if s.simulation_status<>'live' or s.live_ends_at is null or now()<s.live_ends_at then return jsonb_build_object('status','not_due');end if;
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.';end if;
  if m.status not in ('in_progress','scheduled') then raise exception 'Match cannot be finalized from status %.',m.status;end if;
  if not public.tournament_match_feeders_ready_v1(p_match_id) then
    raise exception 'Cannot finalize match % before the preceding round has finalized both actual participants.',p_match_id;
  end if;

  for x in select value from jsonb_array_elements(s.sets_payload) loop
    insert into public.tournament_match_sets(match_id,set_number,player1_games,player2_games,player1_tiebreak_points,player2_tiebreak_points,status)
    values(p_match_id,(x->>'set_number')::smallint,coalesce((x->>'player1_games')::smallint,0),coalesce((x->>'player2_games')::smallint,0),nullif(x->>'player1_tiebreak_points','')::smallint,nullif(x->>'player2_tiebreak_points','')::smallint,'completed')
    on conflict(match_id,set_number) do update set player1_games=excluded.player1_games,player2_games=excluded.player2_games,player1_tiebreak_points=excluded.player1_tiebreak_points,player2_tiebreak_points=excluded.player2_tiebreak_points,status='completed',updated_at=now();
  end loop;

  st1:=s.player1_stats;st2:=s.player2_stats;
  insert into public.tournament_match_player_stats(match_id,player_id,aces,double_faults,first_serves_in,first_serves_total,first_serve_points_won,first_serve_points_played,second_serve_points_won,second_serve_points_played,break_points_won,break_points_total,winners,unforced_errors,total_points_won)
  values(p_match_id,m.player1_id,coalesce((st1->>'aces')::int,0),coalesce((st1->>'double_faults')::int,0),coalesce((st1->>'first_serves_in')::int,0),coalesce((st1->>'first_serves_total')::int,0),coalesce((st1->>'first_serve_points_won')::int,0),coalesce((st1->>'first_serve_points_played')::int,0),coalesce((st1->>'second_serve_points_won')::int,0),coalesce((st1->>'second_serve_points_played')::int,0),coalesce((st1->>'break_points_won')::int,0),coalesce((st1->>'break_points_total')::int,0),coalesce((st1->>'winners')::int,0),coalesce((st1->>'unforced_errors')::int,0),coalesce((st1->>'total_points_won')::int,0))
  on conflict(match_id,player_id) do update set aces=excluded.aces,double_faults=excluded.double_faults,first_serves_in=excluded.first_serves_in,first_serves_total=excluded.first_serves_total,first_serve_points_won=excluded.first_serve_points_won,first_serve_points_played=excluded.first_serve_points_played,second_serve_points_won=excluded.second_serve_points_won,second_serve_points_played=excluded.second_serve_points_played,break_points_won=excluded.break_points_won,break_points_total=excluded.break_points_total,winners=excluded.winners,unforced_errors=excluded.unforced_errors,total_points_won=excluded.total_points_won,updated_at=now();

  insert into public.tournament_match_player_stats(match_id,player_id,aces,double_faults,first_serves_in,first_serves_total,first_serve_points_won,first_serve_points_played,second_serve_points_won,second_serve_points_played,break_points_won,break_points_total,winners,unforced_errors,total_points_won)
  values(p_match_id,m.player2_id,coalesce((st2->>'aces')::int,0),coalesce((st2->>'double_faults')::int,0),coalesce((st2->>'first_serves_in')::int,0),coalesce((st2->>'first_serves_total')::int,0),coalesce((st2->>'first_serve_points_won')::int,0),coalesce((st2->>'first_serve_points_played')::int,0),coalesce((st2->>'second_serve_points_won')::int,0),coalesce((st2->>'second_serve_points_played')::int,0),coalesce((st2->>'break_points_won')::int,0),coalesce((st2->>'break_points_total')::int,0),coalesce((st2->>'winners')::int,0),coalesce((st2->>'unforced_errors')::int,0),coalesce((st2->>'total_points_won')::int,0))
  on conflict(match_id,player_id) do update set aces=excluded.aces,double_faults=excluded.double_faults,first_serves_in=excluded.first_serves_in,first_serves_total=excluded.first_serves_total,first_serve_points_won=excluded.first_serve_points_won,first_serve_points_played=excluded.first_serve_points_played,second_serve_points_won=excluded.second_serve_points_won,second_serve_points_played=excluded.second_serve_points_played,break_points_won=excluded.break_points_won,break_points_total=excluded.break_points_total,winners=excluded.winners,unforced_errors=excluded.unforced_errors,total_points_won=excluded.total_points_won,updated_at=now();

  update public.tournament_match_simulations set simulation_status='completed',finalized_at=now(),updated_at=now() where match_id=p_match_id;
  update public.tournament_matches
  set winner_id=s.final_winner_id,status='completed',
      actual_duration_minutes=public.simulated_tennis_duration_minutes_v1(s.total_games,s.total_points),
      completed_at=now(),updated_at=now()
  where id=p_match_id;
  -- The match result is authoritative; scheduling follow-ups must never
  -- cause a completed tennis result to roll back if rescheduling fails.
  begin
    perform public.reschedule_following_player_matches_v1(p_match_id);
  exception when others then
    begin
      perform public.raise_system_incident_v1(
        'process:tennis-match-scheduling','high',
        'Post-match rescheduling failed',
        sqlerrm,
        'business:post-match-reschedule:'||p_match_id::text,
        jsonb_build_object('match_id',p_match_id,'error_state',sqlstate)
      );
    exception when others then
      raise notice 'Could not report post-match scheduling failure for match %',p_match_id;
    end;
  end;
  return jsonb_build_object('status','completed','match_id',p_match_id,'winner_id',s.final_winner_id);
end;$function$
;
