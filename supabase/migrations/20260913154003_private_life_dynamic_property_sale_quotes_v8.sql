create or replace function public.get_private_life_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_base jsonb;
  v_owned jsonb;
  v_categories jsonb;
  v_locations jsonb;
  v_abs integer;
  v_asset_value bigint:=0;
  v_monthly_cost bigint:=0;
  v_cash bigint:=0;
  v_investments bigint:=0;
begin
  v_base:=public.get_private_life_dashboard_base_v1();
  v_abs:=coalesce((v_base->>'current_absolute_day')::integer,0);
  v_cash:=coalesce((v_base->>'cash_balance')::bigint,0);
  v_investments:=coalesce((v_base->>'investment_value')::bigint,0);

  select coalesce(jsonb_agg(
    elem || jsonb_build_object(
      'current_market_value',calc.market_value,
      'estimated_sale_price',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'standard'),
      'potential_gain_loss',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'standard')-coalesce((elem->>'purchase_price')::bigint,0),
      'property_monthly_change_bps',hist.monthly_change_bps,
      'sale_quotes',jsonb_build_object(
        'urgent',jsonb_build_object('price',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'urgent'),'wait_days',0),
        'standard',jsonb_build_object('price',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'standard'),'wait_days',7),
        'patient',jsonb_build_object('price',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'patient'),'wait_days',21)
      )
    )
    order by coalesce((elem->>'purchase_absolute_day')::integer,0) desc,elem->>'name'
  ),'[]'::jsonb)
  into v_owned
  from jsonb_array_elements(coalesce(v_base->'owned_assets','[]'::jsonb)) elem
  cross join lateral (
    select public.private_life_owned_asset_market_value_v2((elem->>'id')::uuid,v_abs) as market_value
  ) calc
  left join lateral (
    select h.monthly_change_bps
    from public.private_life_property_market_history h
    where h.location_code=elem->>'location_code'
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  select coalesce(sum((elem->>'current_market_value')::bigint),0)::bigint,
         coalesce(sum(greatest(0,round(coalesce((elem->>'annual_running_cost')::numeric,0)/12)::bigint)),0)::bigint
  into v_asset_value,v_monthly_cost
  from jsonb_array_elements(v_owned) elem;

  select coalesce(jsonb_agg(jsonb_build_object(
    'category',category,
    'owned_count',owned_count,
    'market_value',market_value,
    'prestige',prestige,
    'annual_running_cost',annual_running_cost,
    'monthly_running_cost',monthly_running_cost
  ) order by category),'[]'::jsonb)
  into v_categories
  from (
    select elem->>'category' as category,
           count(*)::integer as owned_count,
           sum((elem->>'current_market_value')::bigint)::bigint as market_value,
           sum(coalesce((elem->>'prestige')::integer,0))::integer as prestige,
           sum(coalesce((elem->>'annual_running_cost')::bigint,0))::bigint as annual_running_cost,
           sum(greatest(0,round(coalesce((elem->>'annual_running_cost')::numeric,0)/12)::bigint))::bigint as monthly_running_cost
    from jsonb_array_elements(v_owned) elem
    group by elem->>'category'
  ) x;

  select coalesce(jsonb_agg(
    elem || jsonb_build_object(
      'monthly_change_bps',hist.monthly_change_bps,
      'previous_apartment_base_price',hist.previous_apartment_base_price,
      'previous_house_base_price',hist.previous_house_base_price,
      'market_season',hist.season,
      'market_month',hist.month
    )
    order by coalesce((elem->>'sort_order')::integer,0),elem->>'country_name',elem->>'city'
  ),'[]'::jsonb)
  into v_locations
  from jsonb_array_elements(coalesce(v_base->'property_locations','[]'::jsonb)) elem
  left join lateral (
    select h.*
    from public.private_life_property_market_history h
    where h.location_code=elem->>'code'
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  return v_base || jsonb_build_object(
    'asset_value',v_asset_value,
    'net_worth',v_cash+v_asset_value+v_investments,
    'monthly_running_cost',v_monthly_cost,
    'owned_assets',v_owned,
    'category_totals',v_categories,
    'property_locations',v_locations
  );
end;
$function$;