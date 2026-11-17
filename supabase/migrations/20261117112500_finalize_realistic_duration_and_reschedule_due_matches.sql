-- Apply variable simulated match lengths to new completions only, and
-- use a fail-closed player/court availability check before any new match begins.
-- Existing completed matches/results and active replays are not rewritten.
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
  return jsonb_build_object('status','completed','match_id',p_match_id,'winner_id',s.final_winner_id);
end;$function$
;
CREATE OR REPLACE FUNCTION public.start_due_match_replays_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;v_count integer:=0;v_game bigint;v_gate jsonb;
v_postponed integer:=0;v_blocked integer:=0;
begin
  -- Concurrent match-start ticks must not allow both sides of a clash to start.
  perform pg_advisory_xact_lock(171106,20261117);
  select game_total_seconds into v_game from public.get_game_clock_v1() limit 1;
  for r in
    select sim.match_id,sim.replay_duration_seconds
    from public.tournament_match_simulations sim
    join public.tournament_matches m on m.id=sim.match_id
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where sim.simulation_status='prepared' and m.status='scheduled'
      and m.player1_id is not null and m.player2_id is not null
      and public.tournament_match_feeders_ready_v1(m.id)
      and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*86400 + coalesce(m.scheduled_start_minute,600)::bigint*60)<=v_game
    order by m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number
    for update of sim skip locked
  loop
    v_gate:=public.ensure_safe_singles_start_v1(r.match_id,v_game);
    if v_gate->>'status'<>'ready' then
       if v_gate->>'status'='rescheduled' then v_postponed:=v_postponed+1;
       else v_blocked:=v_blocked+1; end if;
       continue;
    end if;
    update public.tournament_match_simulations
      set simulation_status='live',live_started_at=now(),live_ends_at=now()+make_interval(secs=>r.replay_duration_seconds),updated_at=now()
      where match_id=r.match_id and simulation_status='prepared';
    update public.tournament_matches set status='in_progress',started_at=coalesce(started_at,now()),updated_at=now()
      where id=r.match_id and status='scheduled';
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('status',case when v_blocked>0 then 'warning' else 'processed' end,
    'started',v_count,'rescheduled',v_postponed,'blocked',v_blocked);
end;$function$
;
