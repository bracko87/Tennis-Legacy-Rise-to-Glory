create or replace function public.prepare_tournament_match_simulation_v1(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare
  sim jsonb;
  existing public.tournament_match_simulations%rowtype;
  r jsonb;
  w jsonb;
  m public.tournament_matches%rowtype;
  v_day integer;
  p1_block boolean;
  p2_block boolean;
  v_winner uuid;
  v_r1 integer;
  v_r2 integer;
begin
  select * into existing from public.tournament_match_simulations where match_id=p_match_id;
  if existing.match_id is not null then
    return jsonb_build_object('status',existing.simulation_status,'match_id',p_match_id,'already_exists',true);
  end if;

  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.'; end if;
  if m.status<>'scheduled' or m.player1_id is null or m.player2_id is null then
    raise exception 'Scheduled match with two players required.';
  end if;

  v_day:=public.tournament_match_absolute_day_v2(p_match_id);
  p1_block:=public.player_tournament_blocked_by_injury_v1(m.player1_id,v_day);
  p2_block:=public.player_tournament_blocked_by_injury_v1(m.player2_id,v_day);

  if p1_block or p2_block then
    if p1_block and not p2_block then
      v_winner:=m.player2_id;
    elsif p2_block and not p1_block then
      v_winner:=m.player1_id;
    else
      select coalesce(min(tournament_return_absolute_day),v_day+999) into v_r1
      from public.player_injuries
      where player_id=m.player1_id and status in ('active','recovering') and v_day<tournament_return_absolute_day;

      select coalesce(min(tournament_return_absolute_day),v_day+999) into v_r2
      from public.player_injuries
      where player_id=m.player2_id and status in ('active','recovering') and v_day<tournament_return_absolute_day;

      v_winner:=case when v_r1<=v_r2 then m.player1_id else m.player2_id end;
    end if;

    update public.tournament_matches
    set status='completed',
        winner_id=v_winner,
        started_at=coalesce(started_at,now()),
        completed_at=now(),
        actual_duration_minutes=0,
        schedule_reason=case
          when p1_block and p2_block then 'Injury walkover · both players unavailable; earlier-return player advances'
          else 'Walkover · opponent unavailable through injury'
        end,
        updated_at=now()
    where id=p_match_id;

    return jsonb_build_object(
      'status','walkover',
      'match_id',p_match_id,
      'winner_id',v_winner,
      'player1_blocked',p1_block,
      'player2_blocked',p2_block
    );
  end if;

  w:=public.ensure_tournament_match_weather_v1(p_match_id);
  sim:=public.simulate_tournament_match_v2(p_match_id,null);
  sim:=jsonb_set(
    sim,
    '{metadata}',
    coalesce(sim->'metadata','{}'::jsonb)||jsonb_build_object(
      'weather',w,
      'engine_scope',jsonb_build_object(
        'tactics',true,
        'playing_style',true,
        'weather',true,
        'injuries',true,
        'equipment',false,
        'staff',false
      )
    )
  );

  r:=public.register_tournament_match_simulation_v1(
    p_match_id,
    sim->>'engine_version',
    sim->>'engine_seed',
    (sim->>'winner_id')::uuid,
    sim->'final_score',
    sim->'sets',
    sim->'player1_stats',
    sim->'player2_stats',
    sim->'events',
    (sim->>'replay_duration_seconds')::integer,
    (sim->>'total_points')::integer,
    (sim->>'total_games')::integer,
    sim->'metadata'
  );
  return r||jsonb_build_object('engine_version',sim->>'engine_version');
end;
$$;

create or replace function public.roll_match_injury_on_completion_v1()
returns trigger language plpgsql security definer set search_path='public' as $$
declare
  sim public.tournament_match_simulations%rowtype;
  mins integer;
  w jsonb;
  heat numeric:=0;
begin
  if new.status<>'completed' or (tg_op='UPDATE' and old.status='completed') then return new; end if;
  if coalesce(new.schedule_reason,'') ilike '%walkover%' then return new; end if;

  select * into sim from public.tournament_match_simulations where match_id=new.id;
  if sim.match_id is null then return new; end if;

  mins:=coalesce((sim.metadata->>'estimated_match_minutes')::integer,90);
  w:=coalesce(sim.metadata->'weather',public.calculate_tournament_match_weather_v1(new.id));
  heat:=coalesce((w->>'heat_index')::numeric,0);

  if new.player1_id is not null then
    perform public.notify_injury_risk_if_needed_v1(new.player1_id,'match',null);
    perform public.roll_player_injury_v1(new.player1_id,'match',new.id,null,mins,heat);
  end if;
  if new.player2_id is not null then
    perform public.notify_injury_risk_if_needed_v1(new.player2_id,'match',null);
    perform public.roll_player_injury_v1(new.player2_id,'match',new.id,null,mins,heat);
  end if;
  return new;
end;
$$;
