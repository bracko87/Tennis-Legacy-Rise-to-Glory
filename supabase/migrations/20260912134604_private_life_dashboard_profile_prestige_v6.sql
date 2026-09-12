create or replace function public.get_private_life_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  v_abs integer;
  gd record;
  v_account public.player_career_finance_accounts%rowtype;
  v_prestige integer;
  v_asset_value bigint;
  v_investment_value bigint:=0;
  v_running_cost bigint;
  v_owned jsonb;
  v_catalog jsonb;
  v_categories jsonb;
  v_locations jsonb;
begin
  v_player:=public.private_life_current_player_v1();
  perform public.ensure_player_career_finance_v1(v_player);
  perform public.ensure_private_life_starter_home_v1(v_player);
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  select * into v_account from public.player_career_finance_accounts where player_id=v_player;

  select coalesce(sum(coalesce(o.prestige_override,c.prestige)),0)::integer,
         coalesce(sum(public.private_life_market_value_v1(o.purchase_price,coalesce(o.annual_value_rate_bps_override,c.annual_value_rate_bps),o.purchase_absolute_day,v_abs)),0)::bigint,
         coalesce(sum(coalesce(o.annual_running_cost_override,c.annual_running_cost)),0)::bigint
  into v_prestige,v_asset_value,v_running_cost
  from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
  where o.player_id=v_player and o.sold_absolute_day is null;

  select coalesce(sum(round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))),0)::bigint
  into v_investment_value
  from public.private_life_investment_positions p left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
  where p.player_id=v_player and p.quantity>0;

  select coalesce(jsonb_agg(x order by x.purchase_absolute_day desc,x.name),'[]'::jsonb) into v_owned
  from (
    select o.id,o.catalog_code,c.category,
      case when l.code is not null then c.name||' · '||l.city else c.name end as name,
      c.name as base_name,c.description,c.tier,
      coalesce(o.prestige_override,c.prestige)::integer as prestige,
      c.rarity,c.image_url,
      coalesce(o.annual_running_cost_override,c.annual_running_cost)::bigint as annual_running_cost,
      coalesce(o.annual_value_rate_bps_override,c.annual_value_rate_bps)::integer as annual_value_rate_bps,
      coalesce(o.resale_discount_bps_override,c.resale_discount_bps)::integer as resale_discount_bps,
      o.purchase_absolute_day,o.purchase_price,o.acquisition_type,o.location_code,
      l.city,l.country_code,l.country_name,
      calc.current_market_value,
      public.private_life_sale_price_v2(calc.current_market_value,coalesce(o.resale_discount_bps_override,c.resale_discount_bps),'standard') as estimated_sale_price,
      public.private_life_sale_price_v2(calc.current_market_value,coalesce(o.resale_discount_bps_override,c.resale_discount_bps),'standard')-o.purchase_price as potential_gain_loss,
      greatest(0,v_abs-o.purchase_absolute_day) as ownership_days,
      jsonb_build_object(
        'urgent',jsonb_build_object('price',public.private_life_sale_price_v2(calc.current_market_value,coalesce(o.resale_discount_bps_override,c.resale_discount_bps),'urgent'),'wait_days',0),
        'standard',jsonb_build_object('price',public.private_life_sale_price_v2(calc.current_market_value,coalesce(o.resale_discount_bps_override,c.resale_discount_bps),'standard'),'wait_days',7),
        'patient',jsonb_build_object('price',public.private_life_sale_price_v2(calc.current_market_value,coalesce(o.resale_discount_bps_override,c.resale_discount_bps),'patient'),'wait_days',21)
      ) as sale_quotes,
      case when sl.id is null then null else jsonb_build_object('id',sl.id,'sale_mode',sl.sale_mode,'listed_absolute_day',sl.listed_absolute_day,'settle_absolute_day',sl.settle_absolute_day,'quoted_sale_price',sl.quoted_sale_price,'status',sl.status) end as pending_sale
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    left join public.private_life_property_locations l on l.code=o.location_code
    cross join lateral (select public.private_life_market_value_v1(o.purchase_price,coalesce(o.annual_value_rate_bps_override,c.annual_value_rate_bps),o.purchase_absolute_day,v_abs) as current_market_value) calc
    left join lateral (select s.* from public.private_life_asset_sale_listings s where s.player_asset_id=o.id and s.status='pending' order by s.created_at desc limit 1) sl on true
    where o.player_id=v_player and o.sold_absolute_day is null
  ) x;

  select coalesce(jsonb_agg(x order by x.category),'[]'::jsonb) into v_categories
  from (
    select c.category,count(*)::integer as owned_count,
      coalesce(sum(public.private_life_market_value_v1(o.purchase_price,coalesce(o.annual_value_rate_bps_override,c.annual_value_rate_bps),o.purchase_absolute_day,v_abs)),0)::bigint as market_value,
      coalesce(sum(coalesce(o.prestige_override,c.prestige)),0)::integer as prestige,
      coalesce(sum(coalesce(o.annual_running_cost_override,c.annual_running_cost)),0)::bigint as annual_running_cost
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player and o.sold_absolute_day is null
    group by c.category
  ) x;

  select coalesce(jsonb_agg(x order by x.category,x.purchase_price,x.name),'[]'::jsonb) into v_catalog
  from (
    select c.code,c.category,c.name,c.tier,c.description,c.purchase_price,c.prestige,c.rarity,c.annual_running_cost,c.annual_value_rate_bps,c.resale_discount_bps,c.image_url,c.metadata,
      coalesce((c.metadata->>'location_priced')::boolean,false) as location_priced,
      (c.purchase_price<=v_account.balance) as affordable,
      exists(select 1 from public.private_life_player_assets o where o.player_id=v_player and o.catalog_code=c.code and o.location_code is null and o.sold_absolute_day is null) as owned
    from public.private_life_asset_catalog c where c.active=true
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('code',l.code,'country_code',l.country_code,'country_name',l.country_name,'city',l.city,'apartment_base_price',l.apartment_base_price,'house_base_price',l.house_base_price,'annual_value_rate_bps',l.annual_value_rate_bps,'sort_order',l.sort_order) order by l.sort_order,l.country_name,l.city),'[]'::jsonb)
  into v_locations
  from public.private_life_property_locations l where l.active=true and l.marketplace_enabled=true;

  return jsonb_build_object('player_id',v_player,'currency',v_account.currency,'cash_balance',v_account.balance,'current_absolute_day',v_abs,'season',gd.season,'month',gd.month,'day',gd.day,'prestige',v_prestige,'asset_value',v_asset_value,'investment_value',v_investment_value,'net_worth',v_account.balance+v_asset_value+v_investment_value,'annual_running_cost',v_running_cost,'category_totals',v_categories,'owned_assets',v_owned,'catalog',v_catalog,'property_locations',v_locations);
end;
$$;
revoke all on function public.get_private_life_dashboard_v1() from public,anon;
grant execute on function public.get_private_life_dashboard_v1() to authenticated;

create or replace function public.get_player_private_life_summary_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_abs integer; gd record; v_prestige integer:=0; v_asset_count integer:=0; v_asset_value bigint:=0; v_possessions jsonb:='[]'::jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found.'; end if;
  perform public.ensure_private_life_starter_home_v1(p_player_id);
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  select coalesce(sum(coalesce(o.prestige_override,c.prestige)),0)::integer,count(*)::integer,
    coalesce(sum(public.private_life_market_value_v1(o.purchase_price,coalesce(o.annual_value_rate_bps_override,c.annual_value_rate_bps),o.purchase_absolute_day,v_abs)),0)::bigint
  into v_prestige,v_asset_count,v_asset_value
  from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
  where o.player_id=p_player_id and o.sold_absolute_day is null;
  select coalesce(jsonb_agg(x order by x.prestige desc,x.name),'[]'::jsonb) into v_possessions
  from (
    select o.id,c.category,case when l.code is not null then c.name||' · '||l.city else c.name end as name,
      coalesce(o.prestige_override,c.prestige)::integer as prestige,o.acquisition_type,l.city,l.country_code,l.country_name
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    left join public.private_life_property_locations l on l.code=o.location_code
    where o.player_id=p_player_id and o.sold_absolute_day is null
  ) x;
  return jsonb_build_object('player_id',p_player_id,'prestige_points',v_prestige,'asset_count',v_asset_count,'asset_value',v_asset_value,'possessions',v_possessions);
end;
$$;
revoke all on function public.get_player_private_life_summary_v1(uuid) from public,anon;
grant execute on function public.get_player_private_life_summary_v1(uuid) to authenticated;