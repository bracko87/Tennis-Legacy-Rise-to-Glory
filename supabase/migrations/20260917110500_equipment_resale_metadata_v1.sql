do $block$
declare
  v_def text;
begin
  select pg_get_functiondef('public.get_equipment_dashboard_v1()'::regprocedure)
    into v_def;

  if position('''resale_base_percent'',65' in v_def) > 0 then
    v_def := replace(v_def, '''resale_base_percent'',65', '''resale_base_percent'',25');
    execute v_def;
  end if;
end;
$block$;
