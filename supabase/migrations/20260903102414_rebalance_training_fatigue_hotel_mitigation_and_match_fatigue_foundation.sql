do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.process_regular_training_for_player_v2(uuid,integer,smallint,smallint,text)'::regprocedure)
  into v_def;

  if position('v_base_fatigue:=case v_intensity when ''light'' then 3 when ''standard'' then 6 else 10 end;' in v_def)=0 then
    raise exception 'Expected technical fatigue fragment not found in process_regular_training_for_player_v2';
  end if;
  if position('v_base_fatigue:=case v_intensity when ''light'' then 4 when ''standard'' then 7 else 11 end;' in v_def)=0 then
    raise exception 'Expected physical fatigue fragment not found in process_regular_training_for_player_v2';
  end if;

  v_def := replace(
    v_def,
    'v_base_fatigue:=case v_intensity when ''light'' then 3 when ''standard'' then 6 else 10 end;',
    'v_base_fatigue:=case v_intensity when ''light'' then 2 when ''standard'' then 4 else 7 end;'
  );
  v_def := replace(
    v_def,
    'v_base_fatigue:=case v_intensity when ''light'' then 4 when ''standard'' then 7 else 11 end;',
    'v_base_fatigue:=case v_intensity when ''light'' then 3 when ''standard'' then 5 else 8 end;'
  );

  execute v_def;
end $$;

do $$
declare
  v_def text;
begin
  select pg_get_functiondef('public.process_training_camp_day_v1(uuid,integer,smallint,smallint,text)'::regprocedure)
  into v_def;

  if position('v_new_fatigue:=least(100,s.fatigue+greatest(2,round(4*v_program.quality_multiplier)::integer))::smallint;' in v_def)=0 then
    raise exception 'Expected tennis camp fatigue fragment not found';
  end if;
  if position('v_new_fatigue:=least(100,s.fatigue+greatest(3,round(6*v_program.quality_multiplier)::integer))::smallint;' in v_def)=0 then
    raise exception 'Expected physical camp fatigue fragment not found';
  end if;

  v_def := replace(
    v_def,
    'v_new_fatigue:=least(100,s.fatigue+greatest(2,round(4*v_program.quality_multiplier)::integer))::smallint;',
    'v_new_fatigue:=least(100,s.fatigue+greatest(1,greatest(2,round(4*v_program.quality_multiplier)::integer)-coalesce(v_tier.fatigue_mitigation,0)))::smallint;'
  );
  v_def := replace(
    v_def,
    'v_new_fatigue:=least(100,s.fatigue+greatest(3,round(6*v_program.quality_multiplier)::integer))::smallint;',
    'v_new_fatigue:=least(100,s.fatigue+greatest(1,greatest(3,round(6*v_program.quality_multiplier)::integer)-coalesce(v_tier.fatigue_mitigation,0)))::smallint;'
  );

  execute v_def;
end $$;

create or replace function public.calculate_match_fatigue_v1(
  p_match_minutes integer,
  p_sets_played smallint,
  p_games_played integer,
  p_fitness smallint,
  p_stamina smallint,
  p_surface text default 'hard',
  p_match_load numeric default 1.0
)
returns integer
language plpgsql
immutable
set search_path = public
as $function$
declare
  v_base numeric;
  v_resilience numeric;
  v_surface_multiplier numeric;
  v_load numeric;
  v_result integer;
begin
  if p_match_minutes is null or p_match_minutes < 20 or p_match_minutes > 480 then
    raise exception 'Match minutes must be between 20 and 480.';
  end if;
  if p_sets_played is null or p_sets_played < 2 or p_sets_played > 3 then
    raise exception 'Sets played must be 2 or 3.';
  end if;
  if p_games_played is null or p_games_played < 6 or p_games_played > 80 then
    raise exception 'Games played must be between 6 and 80.';
  end if;
  if p_fitness not between 1 and 100 or p_stamina not between 1 and 100 then
    raise exception 'Fitness and Stamina must be between 1 and 100.';
  end if;

  v_base := case
    when p_match_minutes <= 75 and p_sets_played = 2 then 6
    when p_match_minutes <= 110 and p_sets_played = 2 then 8
    when p_match_minutes <= 150 then 11
    when p_match_minutes <= 210 then 15
    else 20
  end;

  if p_games_played >= 36 then
    v_base := v_base + 2;
  elsif p_games_played >= 30 then
    v_base := v_base + 1;
  end if;

  v_surface_multiplier := case lower(coalesce(p_surface,'hard'))
    when 'clay' then 1.08
    when 'grass' then 0.95
    else 1.00
  end;

  v_load := greatest(0.85, least(1.20, coalesce(p_match_load,1.0)));
  v_resilience := (p_fitness + p_stamina)::numeric / 200.0;

  v_result := round(
    v_base
    * v_surface_multiplier
    * v_load
    * (1.12 - 0.24 * v_resilience)
  );

  return greatest(4, least(22, v_result));
end;
$function$;

comment on function public.calculate_match_fatigue_v1(integer,smallint,integer,smallint,smallint,text,numeric)
is 'Deterministic tennis match fatigue foundation. Intended for the future Match Engine; not automatically applied until match processing is connected.';

revoke all on function public.calculate_match_fatigue_v1(integer,smallint,integer,smallint,smallint,text,numeric) from public;
grant execute on function public.calculate_match_fatigue_v1(integer,smallint,integer,smallint,smallint,text,numeric) to authenticated;
