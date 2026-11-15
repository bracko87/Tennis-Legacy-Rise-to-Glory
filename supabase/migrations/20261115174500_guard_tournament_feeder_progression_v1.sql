-- Tennis Legacy: prevent later-round matches from starting before their two feeders
-- finish and supply the actual winning players. Protects match preparation, replay
-- start and finalization. Does NOT change completed matches, rankings or rewards.
-- Historical two-Australian-Slam Q3 anomalies remain for audited remediation.

CREATE OR REPLACE FUNCTION public.tournament_match_feeders_ready_v1(p_match_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'public','pg_temp'
AS $feeder_guard$
 SELECT COALESCE((
  SELECT CASE WHEN m.round_number<=1 THEN TRUE ELSE EXISTS (
   SELECT 1 FROM public.tournament_matches f1
   JOIN public.tournament_matches f2 ON f2.competition_id=f1.competition_id
      AND f2.draw_type=f1.draw_type AND f2.round_number=f1.round_number
      AND f2.match_number=f1.match_number+1
   WHERE f1.competition_id=m.competition_id
     AND f1.draw_type=m.draw_type
     AND f1.round_number=m.round_number-1
     AND f1.match_number=m.match_number*2-1
     AND f1.status IN ('completed','bye','walkover')
     AND f2.status IN ('completed','bye','walkover')
     AND f1.winner_id IS NOT NULL AND f2.winner_id IS NOT NULL
     AND m.player1_id=f1.winner_id AND m.player2_id=f2.winner_id
  ) END FROM public.tournament_matches m WHERE m.id=p_match_id
 ),FALSE);
$feeder_guard$;

REVOKE ALL ON FUNCTION public.tournament_match_feeders_ready_v1(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.process_due_match_engine_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;v_game bigint;v_count integer:=0;res jsonb;begin
 select game_total_seconds into v_game from public.get_game_clock_v1() limit 1;
 for r in
   select m.id
   from public.tournament_matches m
   join public.tournament_world_competitions wc on wc.id=m.competition_id
   join public.tournament_editions ed on ed.id=wc.tournament_edition_id
   left join public.tournament_match_simulations sim on sim.match_id=m.id
   where m.status='scheduled' and m.player1_id is not null and m.player2_id is not null and sim.match_id is null
     and public.tournament_match_feeders_ready_v1(m.id)
     and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*86400+coalesce(m.scheduled_start_minute,600)::bigint*60)<=v_game
   order by m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number
   for update of m skip locked
 loop
   begin res:=public.prepare_tournament_match_simulation_v1(r.id);if res->>'status'='prepared' then v_count:=v_count+1;end if;exception when others then null;end;
 end loop;
 return jsonb_build_object('status','processed','prepared',v_count);
end;$function$
;

CREATE OR REPLACE FUNCTION public.start_due_match_replays_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;v_count integer:=0;v_game bigint;
begin
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
    update public.tournament_match_simulations
      set simulation_status='live',live_started_at=now(),live_ends_at=now()+make_interval(secs=>r.replay_duration_seconds),updated_at=now()
      where match_id=r.match_id and simulation_status='prepared';
    update public.tournament_matches set status='in_progress',started_at=coalesce(started_at,now()),updated_at=now()
      where id=r.match_id and status='scheduled';
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('status','processed','started',v_count);
end;$function$
;

CREATE OR REPLACE FUNCTION public.prepare_tournament_match_simulation_v1(p_match_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_travel jsonb;
begin
  if not public.tournament_match_feeders_ready_v1(p_match_id) then
    return jsonb_build_object('status','awaiting_feeders','match_id',p_match_id);
  end if;
  v_travel:=public.resolve_tournament_travel_no_show_v1(p_match_id);
  if v_travel->>'status'='walkover' then
    return v_travel;
  end if;

  return public.prepare_tournament_match_simulation_core_v1(p_match_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.prepare_tournament_match_simulation_core_v1(p_match_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  sim jsonb; existing public.tournament_match_simulations%rowtype; r jsonb; w jsonb; m public.tournament_matches%rowtype;
  v_day integer; p1_block boolean; p2_block boolean; v_winner uuid; v_r1 integer; v_r2 integer;
  v_owner uuid; v_blocked uuid;
begin
  select * into existing from public.tournament_match_simulations where match_id=p_match_id;
  if existing.match_id is not null then return jsonb_build_object('status',existing.simulation_status,'match_id',p_match_id,'already_exists',true); end if;
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.'; end if;
  if not public.tournament_match_feeders_ready_v1(p_match_id) then
    return jsonb_build_object('status','awaiting_feeders','match_id',p_match_id);
  end if;
  if m.status<>'scheduled' or m.player1_id is null or m.player2_id is null then raise exception 'Scheduled match with two players required.'; end if;
  v_day:=public.tournament_match_absolute_day_v2(p_match_id);
  p1_block:=public.player_tournament_blocked_by_health_v1(m.player1_id,v_day);
  p2_block:=public.player_tournament_blocked_by_health_v1(m.player2_id,v_day);
  if p1_block or p2_block then
    if p1_block and not p2_block then v_winner:=m.player2_id;
    elsif p2_block and not p1_block then v_winner:=m.player1_id;
    else
      select coalesce(min(return_day),v_day+999) into v_r1 from (
        select tournament_return_absolute_day as return_day from public.player_injuries where player_id=m.player1_id and status in('active','recovering') and v_day<tournament_return_absolute_day
        union all select tournament_return_absolute_day from public.player_illnesses where player_id=m.player1_id and status in('active','recovering') and v_day<tournament_return_absolute_day
      ) q;
      select coalesce(min(return_day),v_day+999) into v_r2 from (
        select tournament_return_absolute_day as return_day from public.player_injuries where player_id=m.player2_id and status in('active','recovering') and v_day<tournament_return_absolute_day
        union all select tournament_return_absolute_day from public.player_illnesses where player_id=m.player2_id and status in('active','recovering') and v_day<tournament_return_absolute_day
      ) q;
      v_winner:=case when v_r1<=v_r2 then m.player1_id else m.player2_id end;
    end if;
    update public.tournament_matches set status='completed',winner_id=v_winner,started_at=coalesce(started_at,now()),completed_at=now(),actual_duration_minutes=null,completion_reason='health_walkover',updated_at=now() where id=p_match_id;
    for v_blocked in select x.pid from (values (m.player1_id,p1_block),(m.player2_id,p2_block)) x(pid,blocked) where x.blocked loop
      select owner_user_id into v_owner from public.players where id=v_blocked;
      if v_owner is not null then
        perform public.emit_notification_v1(v_owner,v_blocked,'player.health.medical_walkover','Medical walkover',
          'You were medically unavailable for this match, so the opponent advanced by walkover.',
          '/game/injuries',jsonb_build_object('match_id',p_match_id,'completion_reason','health_walkover','match_absolute_day',v_day),
          'health-walkover:'||p_match_id::text||':'||v_blocked::text);
      end if;
    end loop;
    return jsonb_build_object('status','walkover','reason','health_unavailable','match_id',p_match_id,'winner_id',v_winner,'player1_blocked',p1_block,'player2_blocked',p2_block);
  end if;
  w:=public.ensure_tournament_match_weather_v1(p_match_id);sim:=public.simulate_tournament_match_v2(p_match_id,null);
  sim:=jsonb_set(sim,'{metadata}',coalesce(sim->'metadata','{}'::jsonb)||jsonb_build_object('weather',w,'engine_scope',jsonb_build_object('tactics',true,'playing_style',true,'weather',true,'injuries',true,'illness',true,'equipment',false,'staff',false)));
  r:=public.register_tournament_match_simulation_v1(p_match_id,sim->>'engine_version',sim->>'engine_seed',(sim->>'winner_id')::uuid,sim->'final_score',sim->'sets',sim->'player1_stats',sim->'player2_stats',sim->'events',(sim->>'replay_duration_seconds')::integer,(sim->>'total_points')::integer,(sim->>'total_games')::integer,sim->'metadata');
  return r||jsonb_build_object('engine_version',sim->>'engine_version');
end;
$function$
;

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
  update public.tournament_matches set winner_id=s.final_winner_id,status='completed',completed_at=now(),updated_at=now() where id=p_match_id;
  return jsonb_build_object('status','completed','match_id',p_match_id,'winner_id',s.final_winner_id);
end;$function$
;
