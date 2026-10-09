-- Add notification payloads to Overview so player-facing notification text
-- can be localized from notification_code + payload instead of stored English prose.
create or replace function public.get_overview_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_base jsonb;
  v_news jsonb;
begin
  v_base := public.get_overview_dashboard_v1();

  select coalesce(
    jsonb_agg(
      item || jsonb_build_object('payload', coalesce(n.payload, '{}'::jsonb))
      order by ord
    ),
    '[]'::jsonb
  )
  into v_news
  from jsonb_array_elements(coalesce(v_base->'career_news','[]'::jsonb)) with ordinality as x(item,ord)
  left join public.user_notifications n
    on n.id=(item->>'id')::uuid
   and n.user_id=auth.uid();

  return jsonb_set(v_base,'{career_news}',v_news,true);
end;
$function$;

revoke all on function public.get_overview_dashboard_v2() from public;
revoke all on function public.get_overview_dashboard_v2() from anon;
grant execute on function public.get_overview_dashboard_v2() to authenticated;
