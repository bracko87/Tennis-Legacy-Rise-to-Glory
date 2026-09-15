create or replace function public.get_private_life_asset_transaction_history_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_player uuid;
  v_history jsonb;
begin
  v_player := public.private_life_current_player_v1();

  select coalesce(jsonb_agg(to_jsonb(x) order by x.event_absolute_day desc, x.created_at desc), '[]'::jsonb)
  into v_history
  from (
    select
      e.id,
      e.event_type,
      case
        when e.event_type = 'purchase' and a.acquisition_type = 'starter_home' then 'starter_home'
        else e.event_type
      end as transaction_type,
      e.event_absolute_day,
      e.amount,
      e.finance_transaction_id,
      e.title,
      e.description,
      e.metadata,
      e.created_at,
      a.id as player_asset_id,
      a.catalog_code,
      c.category,
      c.name as base_name,
      case when l.code is not null then c.name || ' · ' || l.city else c.name end as name,
      a.acquisition_type,
      l.city,
      l.country_code,
      l.country_name
    from public.private_life_asset_events e
    join public.private_life_player_assets a on a.id = e.player_asset_id
    join public.private_life_asset_catalog c on c.code = a.catalog_code
    left join public.private_life_property_locations l on l.code = a.location_code
    where e.player_id = v_player
    order by e.event_absolute_day desc, e.created_at desc
    limit 500
  ) x;

  return v_history;
end;
$function$;

revoke all on function public.get_private_life_asset_transaction_history_v1() from public, anon;
grant execute on function public.get_private_life_asset_transaction_history_v1() to authenticated;
