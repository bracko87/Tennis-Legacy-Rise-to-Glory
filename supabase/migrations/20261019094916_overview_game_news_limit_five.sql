-- Cap the Overview's published in-game match results at five in the
-- authenticated dashboard response, leaving all historical match records intact.
create or replace function public.get_overview_dashboard_v2()
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  v_base jsonb;
  v_news jsonb;
  v_game_news jsonb;
begin
  v_base := public.get_overview_dashboard_v1();

  select coalesce(
    jsonb_agg(
      item || jsonb_build_object('payload', coalesce(n.payload, '{}'::jsonb))
      order by ord
    ), '[]'::jsonb
  ) into v_news
  from jsonb_array_elements(coalesce(v_base->'career_news','[]'::jsonb))
    with ordinality as x(item,ord)
  left join public.user_notifications n
    on n.id = (item->>'id')::uuid
   and n.user_id = auth.uid();

  select coalesce(jsonb_agg(item order by ord), '[]'::jsonb)
    into v_game_news
  from jsonb_array_elements(coalesce(v_base->'game_news','[]'::jsonb))
    with ordinality as x(item,ord)
  where ord <= 5;

  v_base := jsonb_set(v_base, '{career_news}', v_news, true);
  return jsonb_set(v_base, '{game_news}', v_game_news, true);
end;
$$;
