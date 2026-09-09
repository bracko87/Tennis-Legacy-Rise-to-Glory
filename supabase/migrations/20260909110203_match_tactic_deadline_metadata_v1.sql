create or replace function public.get_tournament_match_tactic_v1(p_player_id uuid, p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_match public.tournament_matches%rowtype;
  v_override public.player_tournament_match_tactics%rowtype;
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_tournament jsonb;
  v_effective jsonb;
  v_override_json jsonb:=null;
  v_source text:='automatic_default';
  v_match_second bigint;
  v_lock bigint;
  v_now bigint:=public.current_game_second_v1();
  v_editable boolean;
  v_match_day record;
  v_lock_day record;
  v_match_minute integer;
  v_lock_minute integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id=v_uid) then
    raise exception 'Player access denied.';
  end if;

  select * into v_match
  from public.tournament_matches m
  where m.id=p_match_id;
  if not found then raise exception 'Match not found.'; end if;

  if p_player_id is distinct from v_match.player1_id and p_player_id is distinct from v_match.player2_id then
    raise exception 'This player is not in the selected match.';
  end if;

  v_match_second:=public.tournament_match_game_second_v1(p_match_id);
  v_lock:=case when v_match_second is null then null else v_match_second-3600 end;
  v_editable:=v_match.status='scheduled' and (v_lock is null or v_now<v_lock);

  if v_match_second is not null then
    select * into v_match_day
    from public.absolute_game_day_v1(floor(v_match_second::numeric/86400)::integer);
    v_match_minute:=((v_match_second%86400)/60)::integer;
  end if;

  if v_lock is not null then
    select * into v_lock_day
    from public.absolute_game_day_v1(floor(v_lock::numeric/86400)::integer);
    v_lock_minute:=((v_lock%86400)/60)::integer;
  end if;

  select * into v_plan
  from public.player_tournament_preparation_plans p
  where p.player_id=p_player_id and p.competition_id=v_match.competition_id;

  if found then
    v_tournament:=jsonb_build_object(
      'preset',v_plan.tactic_preset,
      'approach',v_plan.tactic_approach,
      'rally',v_plan.tactic_rally,
      'serve',v_plan.tactic_serve,
      'returnGame',v_plan.tactic_return,
      'courtPosition',v_plan.tactic_court_position,
      'target',v_plan.tactic_target,
      'risk',v_plan.tactic_risk
    );
    v_source:='tournament_default';
  else
    v_tournament:=jsonb_build_object(
      'preset','Balanced',
      'approach','Balanced',
      'rally','Balanced rallies',
      'serve','Balanced',
      'returnGame','Balanced',
      'courtPosition','Normal baseline',
      'target','Automatic',
      'risk','Balanced'
    );
  end if;

  select * into v_override
  from public.player_tournament_match_tactics t
  where t.player_id=p_player_id and t.match_id=p_match_id;

  if found then
    v_override_json:=jsonb_build_object(
      'preset',v_override.tactic_preset,
      'approach',v_override.tactic_approach,
      'rally',v_override.tactic_rally,
      'serve',v_override.tactic_serve,
      'returnGame',v_override.tactic_return,
      'courtPosition',v_override.tactic_court_position,
      'target',v_override.tactic_target,
      'risk',v_override.tactic_risk
    );
    v_effective:=v_override_json;
    v_source:='match_override';
  else
    v_effective:=v_tournament;
  end if;

  return jsonb_build_object(
    'match_status',v_match.status,
    'editable',v_editable,
    'source',v_source,
    'tournament_default',v_tournament,
    'override',v_override_json,
    'effective',v_effective,
    'scheduled_game_second',v_match_second,
    'scheduled_start_minute',v_match.scheduled_start_minute,
    'scheduled_game_date',case when v_match_second is null then null else jsonb_build_object(
      'season',v_match_day.season,
      'month',v_match_day.month,
      'day',v_match_day.day,
      'season_week',v_match_day.season_week
    ) end,
    'tactic_lock_game_second',v_lock,
    'tactic_lock_game_date',case when v_lock is null then null else jsonb_build_object(
      'season',v_lock_day.season,
      'month',v_lock_day.month,
      'day',v_lock_day.day,
      'season_week',v_lock_day.season_week
    ) end,
    'tactic_lock_minute_of_day',v_lock_minute,
    'current_game_second',v_now,
    'lock_minutes_before_start',60
  );
end;
$$;

revoke all on function public.get_tournament_match_tactic_v1(uuid,uuid) from public,anon;
grant execute on function public.get_tournament_match_tactic_v1(uuid,uuid) to authenticated;