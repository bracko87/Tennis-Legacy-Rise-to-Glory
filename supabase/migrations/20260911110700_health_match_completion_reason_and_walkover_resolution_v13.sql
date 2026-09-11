alter table public.tournament_matches
  add column if not exists completion_reason text;

alter table public.tournament_matches drop constraint if exists tournament_matches_completion_reason_check;
alter table public.tournament_matches add constraint tournament_matches_completion_reason_check
  check (completion_reason is null or completion_reason in ('health_walkover','health_surrender'));

create or replace function public.prepare_tournament_match_simulation_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sim jsonb; existing public.tournament_match_simulations%rowtype; r jsonb; w jsonb; m public.tournament_matches%rowtype;
  v_day integer; p1_block boolean; p2_block boolean; v_winner uuid; v_r1 integer; v_r2 integer;
  v_owner uuid; v_blocked uuid;
begin
  select * into existing from public.tournament_match_simulations where match_id=p_match_id;
  if existing.match_id is not null then
    return jsonb_build_object('status',existing.simulation_status,'match_id',p_match_id,'already_exists',true);
  end if;

  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.'; end if;
  if m.status<>'scheduled' or m.player1_id is null or m.player2_id is null then raise exception 'Scheduled match with two players required.'; end if;

  v_day:=public.tournament_match_absolute_day_v2(p_match_id);
  p1_block:=public.player_tournament_blocked_by_health_v1(m.player1_id,v_day);
  p2_block:=public.player_tournament_blocked_by_health_v1(m.player2_id,v_day);

  if p1_block or p2_block then
    if p1_block and not p2_block then
      v_winner:=m.player2_id;
    elsif p2_block and not p1_block then
      v_winner:=m.player1_id;
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

    update public.tournament_matches
      set status='completed',winner_id=v_winner,started_at=coalesce(started_at,now()),completed_at=now(),
          actual_duration_minutes=null,completion_reason='health_walkover',updated_at=now()
    where id=p_match_id;

    for v_blocked in select x.pid from (values (m.player1_id,p1_block),(m.player2_id,p2_block)) x(pid,blocked) where x.blocked loop
      select owner_user_id into v_owner from public.players where id=v_blocked;
      if v_owner is not null then
        perform public.emit_notification_v1(
          v_owner,v_blocked,'player.health.match_surrendered','Medical walkover',
          'You were medically unavailable for this match, so the opponent advanced by walkover.',
          '/game/injuries',jsonb_build_object('match_id',p_match_id,'completion_reason','health_walkover','match_absolute_day',v_day),
          'health-walkover:'||p_match_id::text||':'||v_blocked::text
        );
      end if;
    end loop;

    return jsonb_build_object('status','walkover','reason','health_unavailable','match_id',p_match_id,'winner_id',v_winner,'player1_blocked',p1_block,'player2_blocked',p2_block);
  end if;

  w:=public.ensure_tournament_match_weather_v1(p_match_id);
  sim:=public.simulate_tournament_match_v2(p_match_id,null);
  sim:=jsonb_set(sim,'{metadata}',coalesce(sim->'metadata','{}'::jsonb)||jsonb_build_object('weather',w,'engine_scope',jsonb_build_object('tactics',true,'playing_style',true,'weather',true,'injuries',true,'illness',true,'equipment',false,'staff',false)));
  r:=public.register_tournament_match_simulation_v1(p_match_id,sim->>'engine_version',sim->>'engine_seed',(sim->>'winner_id')::uuid,sim->'final_score',sim->'sets',sim->'player1_stats',sim->'player2_stats',sim->'events',(sim->>'replay_duration_seconds')::integer,(sim->>'total_points')::integer,(sim->>'total_games')::integer,sim->'metadata');
  return r||jsonb_build_object('engine_version',sim->>'engine_version');
end;
$function$;

create or replace function public.surrender_tournament_match_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player uuid; m public.tournament_matches%rowtype; v_opponent uuid; v_health jsonb; v_status jsonb; v_owner uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id,owner_user_id into v_player,v_owner from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.'; end if;
  if v_player is distinct from m.player1_id and v_player is distinct from m.player2_id then raise exception 'This is not your match.'; end if;
  if m.status<>'scheduled' then raise exception 'Only a scheduled match can be surrendered.'; end if;
  if exists(select 1 from public.tournament_match_simulations where match_id=m.id) then raise exception 'This match has already been prepared and can no longer be surrendered.'; end if;

  v_status:=public.get_tournament_match_health_status_v1(m.id);
  if not coalesce((v_status->>'health_concern')::boolean,false) then raise exception 'Health surrender is available only when an elevated health concern is detected.'; end if;
  v_opponent:=case when m.player1_id=v_player then m.player2_id else m.player1_id end;
  if v_opponent is null then raise exception 'Opponent is not available.'; end if;
  v_health:=v_status->'health';

  insert into public.tournament_match_surrenders(match_id,player_id,opponent_id,health_snapshot)
  values(m.id,v_player,v_opponent,v_status) returning id into v_id;

  update public.tournament_matches
    set status='completed',winner_id=v_opponent,started_at=coalesce(started_at,now()),completed_at=now(),
        actual_duration_minutes=null,completion_reason='health_surrender',updated_at=now()
  where id=m.id;

  perform public.emit_notification_v1(v_owner,v_player,'player.health.match_surrendered','Match surrendered for health reasons',
    format('You surrendered the match because of a health concern (%s). Your opponent advances.',coalesce(v_health->>'label','health concern')),
    '/game/injuries',jsonb_build_object('match_id',m.id,'surrender_id',v_id,'health',v_health,'completion_reason','health_surrender'),'health-surrender:'||m.id::text);

  return jsonb_build_object('status','surrendered','match_id',m.id,'winner_id',v_opponent,'surrender_id',v_id,'health',v_health,'completion_reason','health_surrender');
end;
$function$;
