do $$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.process_regular_training_for_player_v2(uuid,integer,smallint,smallint,text)'::regprocedure) into v_def;
  v_old := 'begin' || chr(10)
    || '  if p_processed_by not in (''manual'',''daily_engine'') then raise exception ''Invalid processor.''; end if;' || chr(10)
    || '  if exists';
  v_new := 'begin' || chr(10)
    || '  if p_processed_by not in (''manual'',''daily_engine'') then raise exception ''Invalid processor.''; end if;' || chr(10)
    || '  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);' || chr(10)
    || '  select * into v_day_info from public.get_current_game_day_internal_v1();' || chr(10)
    || '  if v_abs > public.game_day_absolute_v1(v_day_info.season,v_day_info.month,v_day_info.day) then' || chr(10)
    || '    return jsonb_build_object(''status'',''blocked'',''reason'',''Future training days cannot be processed before the game clock reaches them.'');' || chr(10)
    || '  end if;' || chr(10)
    || '  if exists';
  if position(v_old in v_def)=0 then raise exception 'Regular Training future-guard insertion point not found.'; end if;
  execute replace(v_def,v_old,v_new);
end $$;

do $$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.process_training_camp_day_v1(uuid,integer,smallint,smallint,text)'::regprocedure) into v_def;
  v_old := 'begin' || chr(10) || '  select b.* into v_booking';
  v_new := 'begin' || chr(10)
    || '  if v_abs > (select public.game_day_absolute_v1(season,month,day) from public.get_current_game_day_internal_v1()) then' || chr(10)
    || '    return jsonb_build_object(''status'',''blocked'',''reason'',''Future training-camp days cannot be processed before the game clock reaches them.'');' || chr(10)
    || '  end if;' || chr(10)
    || '  select b.* into v_booking';
  if position(v_old in v_def)=0 then raise exception 'Training Camp future-guard insertion point not found.'; end if;
  execute replace(v_def,v_old,v_new);
end $$;
