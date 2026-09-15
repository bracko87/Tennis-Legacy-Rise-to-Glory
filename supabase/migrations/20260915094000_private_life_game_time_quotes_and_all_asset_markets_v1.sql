alter table public.private_life_quote_refresh_control
  add column if not exists last_stock_refresh_game_second bigint,
  add column if not exists last_crypto_refresh_game_second bigint;

create table if not exists public.private_life_asset_market_history (
  id bigint generated always as identity primary key,
  catalog_code text not null references public.private_life_asset_catalog(code) on delete cascade,
  season integer not null,
  month integer not null check (month between 1 and 12),
  previous_price bigint not null check (previous_price > 0),
  price bigint not null check (price > 0),
  monthly_change_bps integer not null,
  created_at timestamptz not null default now(),
  unique (catalog_code, season, month)
);

create index if not exists private_life_asset_market_history_catalog_idx
  on public.private_life_asset_market_history(catalog_code, season desc, month desc);

alter table public.private_life_asset_market_history enable row level security;
revoke all on public.private_life_asset_market_history from public, anon, authenticated;

update public.private_life_asset_catalog
set metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('base_market_price', purchase_price)
where active = true
  and not coalesce((metadata->>'location_priced')::boolean,false)
  and not (coalesce(metadata,'{}'::jsonb) ? 'base_market_price');

create or replace function public.private_life_asset_market_delta_bps_v1(
  p_catalog_code text,
  p_category text,
  p_annual_value_rate_bps integer,
  p_season integer,
  p_month integer
)
returns integer
language plpgsql
immutable
set search_path to 'public','pg_temp'
as $function$
declare
  v_volatility integer;
  v_trend integer;
  v_hash bigint;
  v_shock integer;
  v_delta integer;
begin
  v_volatility := case p_category
    when 'watch' then 220
    when 'jewelry' then 200
    when 'car' then 320
    when 'yacht' then 300
    when 'private_jet' then 260
    when 'art' then 380
    when 'collectible' then 420
    else 240
  end;
  v_trend := round(coalesce(p_annual_value_rate_bps,0)::numeric / 12)::integer;
  v_hash := abs(hashtextextended(coalesce(p_catalog_code,'') || ':' || coalesce(p_season,1)::text || ':' || coalesce(p_month,1)::text, 0));
  v_shock := mod(v_hash, (v_volatility * 2 + 1)::bigint)::integer - v_volatility;
  v_delta := greatest(-800, least(800, v_trend + v_shock));
  return v_delta;
end;
$function$;

create or replace function public.process_private_life_asset_market_month_v1(
  p_season integer,
  p_month integer
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  r record;
  v_previous bigint;
  v_base bigint;
  v_delta integer;
  v_new bigint;
  v_processed integer := 0;
begin
  if p_season < 1 or p_month < 1 or p_month > 12 then
    raise exception 'Invalid game month';
  end if;

  for r in
    select c.code,c.category,c.purchase_price,c.annual_value_rate_bps,c.metadata
    from public.private_life_asset_catalog c
    where c.active = true
      and not coalesce((c.metadata->>'location_priced')::boolean,false)
    order by c.code
  loop
    if exists (
      select 1 from public.private_life_asset_market_history h
      where h.catalog_code=r.code and h.season=p_season and h.month=p_month
    ) then
      continue;
    end if;

    v_previous := r.purchase_price;
    v_base := greatest(1, coalesce((r.metadata->>'base_market_price')::bigint, r.purchase_price));
    v_delta := public.private_life_asset_market_delta_bps_v1(r.code,r.category,r.annual_value_rate_bps,p_season,p_month);
    v_new := round(v_previous::numeric * (10000 + v_delta)::numeric / 10000)::bigint;
    v_new := greatest(greatest(1,round(v_base::numeric*0.15)::bigint), least(round(v_base::numeric*5)::bigint, v_new));

    insert into public.private_life_asset_market_history(catalog_code,season,month,previous_price,price,monthly_change_bps)
    values (r.code,p_season,p_month,v_previous,v_new,v_delta)
    on conflict (catalog_code,season,month) do nothing;

    if found then
      update public.private_life_asset_catalog
      set purchase_price=v_new, updated_at=now()
      where code=r.code;
      v_processed := v_processed + 1;
    end if;
  end loop;

  return jsonb_build_object('season',p_season,'month',p_month,'processed',v_processed);
end;
$function$;

create or replace function public.process_private_life_asset_market_to_current_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  gd record;
  v_result jsonb;
begin
  select * into gd from public.get_current_game_day_internal_v1();
  v_result := public.process_private_life_asset_market_month_v1(gd.season,gd.month);
  return v_result || jsonb_build_object('current_day',gd.day);
end;
$function$;

revoke all on function public.private_life_asset_market_delta_bps_v1(text,text,integer,integer,integer) from public, anon, authenticated;
revoke all on function public.process_private_life_asset_market_month_v1(integer,integer) from public, anon, authenticated;
revoke all on function public.process_private_life_asset_market_to_current_v1() from public, anon, authenticated;

create or replace function public.private_life_owned_asset_market_value_v2(p_player_asset_id uuid, p_absolute_day integer)
returns bigint
language plpgsql
stable security definer
set search_path to 'public','pg_temp'
as $function$
declare
  o public.private_life_player_assets%rowtype;
  c public.private_life_asset_catalog%rowtype;
  l public.private_life_property_locations%rowtype;
  v_multiplier integer;
  v_base bigint;
begin
  select * into o from public.private_life_player_assets where id=p_player_asset_id;
  if o.id is null then return 0; end if;
  select * into c from public.private_life_asset_catalog where code=o.catalog_code;

  if c.category in ('apartment','house_villa') and o.location_code is not null
     and coalesce((c.metadata->>'location_priced')::boolean,false) then
    select * into l from public.private_life_property_locations where code=o.location_code;
    if l.code is not null then
      v_multiplier:=coalesce((c.metadata->>'price_multiplier_bps')::integer,10000);
      v_base:=case when c.category='apartment' then l.apartment_base_price else l.house_base_price end;
      return greatest(1,round(v_base::numeric*v_multiplier::numeric/10000)::bigint);
    end if;
  end if;

  return greatest(1,c.purchase_price);
end;
$function$;

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
  v_catalog jsonb;
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
      'property_monthly_change_bps',ph.monthly_change_bps,
      'asset_monthly_change_bps',ah.monthly_change_bps,
      'previous_market_price',ah.previous_price,
      'market_season',coalesce(ph.season,ah.season),
      'market_month',coalesce(ph.month,ah.month),
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
    select h.monthly_change_bps,h.season,h.month
    from public.private_life_property_market_history h
    where h.location_code=elem->>'location_code'
    order by h.season desc,h.month desc
    limit 1
  ) ph on true
  left join lateral (
    select h.monthly_change_bps,h.previous_price,h.season,h.month
    from public.private_life_asset_market_history h
    where h.catalog_code=elem->>'catalog_code'
    order by h.season desc,h.month desc
    limit 1
  ) ah on true;

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

  select coalesce(jsonb_agg(
    elem || jsonb_build_object(
      'market_monthly_change_bps',hist.monthly_change_bps,
      'previous_market_price',hist.previous_price,
      'market_season',hist.season,
      'market_month',hist.month
    )
    order by elem->>'category',coalesce((elem->>'purchase_price')::bigint,0),elem->>'name'
  ),'[]'::jsonb)
  into v_catalog
  from jsonb_array_elements(coalesce(v_base->'catalog','[]'::jsonb)) elem
  left join lateral (
    select h.monthly_change_bps,h.previous_price,h.season,h.month
    from public.private_life_asset_market_history h
    where h.catalog_code=elem->>'code'
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  return v_base || jsonb_build_object(
    'asset_value',v_asset_value,
    'net_worth',v_cash+v_asset_value+v_investments,
    'monthly_running_cost',v_monthly_cost,
    'owned_assets',v_owned,
    'category_totals',v_categories,
    'property_locations',v_locations,
    'catalog',v_catalog
  );
end;
$function$;

with clock as (
  select game_total_seconds from public.get_game_clock_v1()
)
update public.private_life_investment_quotes q
set metadata = coalesce(q.metadata,'{}'::jsonb) || jsonb_build_object(
  'game_checked_total_seconds',(select game_total_seconds from clock),
  'game_last_change_total_seconds',coalesce((q.metadata->>'game_last_change_total_seconds')::bigint,(select game_total_seconds from clock)),
  'provider_quote_as_of',q.quote_as_of
);

select public.process_private_life_asset_market_to_current_v1();

do $do$
begin
  if exists(select 1 from cron.job where jobname='tennis-private-life-asset-market-v1') then
    perform cron.unschedule('tennis-private-life-asset-market-v1');
  end if;
  perform cron.schedule('tennis-private-life-asset-market-v1','*/5 * * * *','select public.process_private_life_asset_market_to_current_v1();');
end
$do$;
