create or replace function public.apply_doubles_match_effects_v1()
returns trigger language plpgsql security definer set search_path=public
as $$
declare
  t1 public.tournament_doubles_teams%rowtype;t2 public.tournament_doubles_teams%rowtype;v_player uuid;s public.player_skills%rowtype;
  v_surface text;v_fatigue_mult numeric;v_wear_mult numeric;v_gain integer;v_after smallint;v_win boolean;
begin
  if new.status<>'completed' or new.winner_team_id is null or (tg_op='UPDATE' and old.status='completed') then return new; end if;
  select * into t1 from public.tournament_doubles_teams where id=new.team1_id;
  select * into t2 from public.tournament_doubles_teams where id=new.team2_id;
  select ts.surface,ds.fatigue_multiplier,ds.equipment_wear_multiplier into v_surface,v_fatigue_mult,v_wear_mult
  from public.tournament_world_competitions wc join public.tournament_editions e on e.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=e.tournament_series_id join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id where wc.id=new.competition_id;
  foreach v_player in array array[t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id] loop
    if v_player is null or exists(select 1 from public.player_doubles_match_condition_events where doubles_match_id=new.id and player_id=v_player) then continue; end if;
    select * into s from public.player_skills where player_id=v_player for update;
    if s.player_id is null then continue; end if;
    v_win:=(new.winner_team_id=t1.id and v_player in (t1.player1_id,t1.player2_id)) or (new.winner_team_id=t2.id and v_player in (t2.player1_id,t2.player2_id));
    v_gain:=greatest(3,round(public.calculate_match_fatigue_v2(
      greatest(20,coalesce(new.actual_duration_minutes,90)),
      greatest(2,coalesce(new.sets_played,2))::smallint,
      greatest(6,coalesce(new.games_played,20)),
      s.fitness,s.stamina,s.recovery,v_surface
    )*v_fatigue_mult));
    v_after:=least(100,s.fatigue+v_gain)::smallint;
    update public.player_skills set fatigue=v_after,sharpness=least(100,s.sharpness+1),morale=greatest(1,least(100,s.morale+case when v_win then 1 else -1 end)),confidence=greatest(1,least(100,s.confidence+case when v_win then 2 else -1 end)),updated_at=now() where player_id=v_player;
    insert into public.player_doubles_match_condition_events(doubles_match_id,player_id,outcome,surface,estimated_match_minutes,sets_played,games_played,fatigue_before,fatigue_after)
    values(new.id,v_player,case when v_win then 'win' else 'loss' end,coalesce(v_surface,'hard'),coalesce(new.actual_duration_minutes,90),coalesce(new.sets_played,2),coalesce(new.games_played,20),s.fatigue,v_after);
    if exists(select 1 from public.players where id=v_player and owner_user_id is not null) then perform public.apply_doubles_equipment_wear_v1(v_player,new.id,v_surface,v_wear_mult); end if;
  end loop;
  return new;
end;
$$;