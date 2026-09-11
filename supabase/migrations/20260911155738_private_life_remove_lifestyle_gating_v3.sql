create or replace function public.buy_private_life_asset_v1(p_catalog_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_asset public.private_life_asset_catalog%rowtype;
  v_owned_id uuid:=gen_random_uuid();
  v_abs integer;
  gd record;
  v_fin jsonb;
  v_tx uuid;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_asset from public.private_life_asset_catalog where code=p_catalog_code and active=true;
  if v_asset.code is null then raise exception 'Lifestyle asset not found.'; end if;
  if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=p_catalog_code and sold_absolute_day is null) then raise exception 'You already own this asset.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  insert into public.private_life_player_assets(id,player_id,catalog_code,purchase_absolute_day,purchase_price)
  values(v_owned_id,v_player,v_asset.code,v_abs,v_asset.purchase_price);

  v_fin:=public.post_career_finance_transaction_v1(
    v_player,
    -v_asset.purchase_price,
    'private_life',
    'purchase_'||v_asset.category,
    'Private Life purchase: '||v_asset.name,
    'private_life_asset',
    v_owned_id::text,
    'private-life-purchase:'||v_owned_id::text,
    jsonb_build_object('catalog_code',v_asset.code,'category',v_asset.category,'prestige',v_asset.prestige,'annual_running_cost',v_asset.annual_running_cost),
    true,
    v_abs
  );
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets set purchase_transaction_id=v_tx,updated_at=now() where id=v_owned_id;
  return jsonb_build_object('status','purchased','owned_asset_id',v_owned_id,'catalog_code',v_asset.code,'name',v_asset.name,'price',v_asset.purchase_price,'balance',v_fin->'balance');
end;
$function$;

create or replace function public.get_private_life_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_abs integer;
  gd record;
  v_account public.player_career_finance_accounts%rowtype;
  v_level smallint;
  v_earnings bigint;
  v_prestige integer;
  v_asset_value bigint;
  v_running_cost bigint;
  v_owned jsonb;
  v_catalog jsonb;
  v_categories jsonb;
begin
  v_player:=public.private_life_current_player_v1();
  perform public.ensure_player_career_finance_v1(v_player);
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  select * into v_account from public.player_career_finance_accounts where player_id=v_player;
  v_level:=public.private_life_lifestyle_level_v1(v_player);
  select coalesce(sum(amount),0)::bigint into v_earnings
  from public.career_finance_transactions
  where player_id=v_player and amount>0 and category not in ('career','private_life');

  select
    coalesce(sum(c.prestige),0)::integer,
    coalesce(sum(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)),0)::bigint,
    coalesce(sum(c.annual_running_cost),0)::bigint
  into v_prestige,v_asset_value,v_running_cost
  from public.private_life_player_assets o
  join public.private_life_asset_catalog c on c.code=o.catalog_code
  where o.player_id=v_player and o.sold_absolute_day is null;

  select coalesce(jsonb_agg(x order by x.purchase_absolute_day desc,x.name),'[]'::jsonb) into v_owned
  from (
    select
      o.id,o.catalog_code,c.category,c.name,c.description,c.tier,c.prestige,c.rarity,c.image_url,c.annual_running_cost,c.annual_value_rate_bps,c.resale_discount_bps,
      o.purchase_absolute_day,o.purchase_price,
      public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs) as current_market_value,
      round(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)::numeric * (10000-c.resale_discount_bps)::numeric / 10000)::bigint as estimated_sale_price,
      round(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)::numeric * (10000-c.resale_discount_bps)::numeric / 10000)::bigint - o.purchase_price as potential_gain_loss,
      greatest(0,v_abs-o.purchase_absolute_day) as ownership_days
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player and o.sold_absolute_day is null
  ) x;

  select coalesce(jsonb_agg(x order by x.category),'[]'::jsonb) into v_categories
  from (
    select c.category,
      count(*)::integer as owned_count,
      coalesce(sum(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)),0)::bigint as market_value,
      coalesce(sum(c.prestige),0)::integer as prestige,
      coalesce(sum(c.annual_running_cost),0)::bigint as annual_running_cost
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player and o.sold_absolute_day is null
    group by c.category
  ) x;

  select coalesce(jsonb_agg(x order by x.tier,x.purchase_price,x.name),'[]'::jsonb) into v_catalog
  from (
    select c.code,c.category,c.name,c.tier,c.description,c.purchase_price,c.prestige,c.rarity,c.annual_running_cost,c.annual_value_rate_bps,c.resale_discount_bps,c.image_url,c.metadata,
      true as unlocked,
      (c.purchase_price<=v_account.balance) as affordable,
      exists(select 1 from public.private_life_player_assets o where o.player_id=v_player and o.catalog_code=c.code and o.sold_absolute_day is null) as owned
    from public.private_life_asset_catalog c
    where c.active=true
  ) x;

  return jsonb_build_object(
    'player_id',v_player,
    'currency',v_account.currency,
    'cash_balance',v_account.balance,
    'current_absolute_day',v_abs,
    'season',gd.season,
    'month',gd.month,
    'day',gd.day,
    'lifestyle_level',v_level,
    'career_earnings',v_earnings,
    'prestige',v_prestige,
    'asset_value',v_asset_value,
    'net_worth',v_account.balance+v_asset_value,
    'annual_running_cost',v_running_cost,
    'category_totals',v_categories,
    'owned_assets',v_owned,
    'catalog',v_catalog
  );
end;
$function$;
