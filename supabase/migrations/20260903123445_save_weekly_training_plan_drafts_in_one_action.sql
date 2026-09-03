create or replace function public.set_training_week_days_v1(p_days jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_item jsonb;
  v_result jsonb;
  v_applied integer := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_days is null or jsonb_typeof(p_days) <> 'array' then raise exception 'Training plan changes must be an array.'; end if;
  if jsonb_array_length(p_days) > 14 then raise exception 'A maximum of 14 training days can be saved at once.'; end if;

  for v_item in select value from jsonb_array_elements(p_days)
  loop
    if not (v_item ? 'absolute_day') or not (v_item ? 'training_type') or not (v_item ? 'intensity') then
      raise exception 'Incomplete training day change.';
    end if;

    v_result := public.set_training_week_day_v1(
      (v_item->>'absolute_day')::integer,
      v_item->>'training_type',
      nullif(v_item->>'focus_attribute',''),
      v_item->>'intensity'
    );

    if coalesce(v_result->>'status','') not in ('saved','updated','ok') then
      if coalesce(v_result->>'status','') = 'blocked' then
        raise exception '%', coalesce(v_result->>'reason','Training day cannot be changed.');
      end if;
    end if;

    v_applied := v_applied + 1;
  end loop;

  return jsonb_build_object('status','saved','saved_days',v_applied);
end;
$function$;

revoke all on function public.set_training_week_days_v1(jsonb) from public;
grant execute on function public.set_training_week_days_v1(jsonb) to authenticated;
