do $$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.get_training_dashboard_v1()'::regprocedure) into v_def;
  v_old := E'    order by public.game_day_absolute_v1(season,month,day) desc, created_at desc\n    limit 10';
  v_new := E'    order by public.game_day_absolute_v1(season,month,day) desc, created_at desc\n    limit 3';
  if position(v_old in v_def)=0 then
    raise exception 'Training history limit replacement point not found.';
  end if;
  execute replace(v_def, v_old, v_new);
end $$;
