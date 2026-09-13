create table if not exists public.private_life_investment_quote_history (
  id bigint generated always as identity primary key,
  instrument_code text not null references public.private_life_investment_instruments(code) on delete cascade,
  price numeric(24,8) not null check (price > 0),
  quote_as_of timestamptz not null,
  captured_at timestamptz not null default now(),
  source text not null,
  metadata jsonb not null default '{}'::jsonb
);

alter table public.private_life_investment_quote_history enable row level security;
revoke all on public.private_life_investment_quote_history from public,anon,authenticated;
create index if not exists private_life_investment_quote_history_instrument_time_idx on public.private_life_investment_quote_history(instrument_code,captured_at desc);

create table if not exists public.private_life_quote_refresh_control (
  id smallint primary key check (id=1),
  cron_token text not null,
  last_stock_refresh_at timestamptz,
  last_crypto_refresh_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.private_life_quote_refresh_control enable row level security;
revoke all on public.private_life_quote_refresh_control from public,anon,authenticated;
insert into public.private_life_quote_refresh_control(id,cron_token)
values(1,md5(gen_random_uuid()::text||clock_timestamp()::text||random()::text)||md5(gen_random_uuid()::text))
on conflict(id) do nothing;

create or replace function public.private_life_monthly_ownership_cost_v1(p_category text,p_asset_value bigint)
returns bigint
language sql
immutable
set search_path='public'
as $$
  select case
    when p_category in ('watch','jewelry','art','collectible') then 0::bigint
    when p_category='car' then greatest(150::bigint,round(greatest(0,p_asset_value)::numeric*0.006)::bigint)
    when p_category='apartment' then greatest(1000::bigint,round(greatest(0,p_asset_value)::numeric*0.01)::bigint)
    when p_category='house_villa' then greatest(1500::bigint,round(greatest(0,p_asset_value)::numeric*0.01)::bigint)
    when p_category='yacht' then greatest(2500::bigint,round(greatest(0,p_asset_value)::numeric*0.008)::bigint)
    when p_category='private_jet' then greatest(15000::bigint,round(greatest(0,p_asset_value)::numeric*0.0075)::bigint)
    else 0::bigint
  end;
$$;
revoke all on function public.private_life_monthly_ownership_cost_v1(text,bigint) from public,anon,authenticated;

update public.private_life_asset_catalog
set annual_running_cost=public.private_life_monthly_ownership_cost_v1(category,purchase_price)*12,
    updated_at=now();

update public.private_life_player_assets o
set annual_running_cost_override=public.private_life_monthly_ownership_cost_v1(c.category,o.purchase_price)*12,
    updated_at=now()
from public.private_life_asset_catalog c
where c.code=o.catalog_code and o.sold_absolute_day is null;

create or replace function public.buy_private_life_asset_v2(p_catalog_code text,p_location_code text default null)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player uuid; v_asset public.private_life_asset_catalog%rowtype; v_location public.private_life_property_locations%rowtype;
  v_owned_id uuid:=gen_random_uuid(); v_abs integer; gd record; v_fin jsonb; v_tx uuid;
  v_location_priced boolean:=false; v_multiplier integer:=10000; v_rate_adjustment integer:=0;
  v_price bigint; v_running bigint; v_rate integer;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_asset from public.private_life_asset_catalog where code=p_catalog_code and active=true;
  if v_asset.code is null then raise exception 'Lifestyle asset not found.'; end if;
  v_location_priced:=coalesce((v_asset.metadata->>'location_priced')::boolean,false);
  if v_location_priced then
    if p_location_code is null or btrim(p_location_code)='' then raise exception 'Choose a property location.'; end if;
    select * into v_location from public.private_life_property_locations where code=p_location_code and active=true and marketplace_enabled=true;
    if v_location.code is null then raise exception 'Property location not found.'; end if;
    v_multiplier:=coalesce((v_asset.metadata->>'price_multiplier_bps')::integer,10000);
    v_rate_adjustment:=coalesce((v_asset.metadata->>'value_rate_adjustment_bps')::integer,0);
    if v_asset.category='apartment' then v_price:=round(v_location.apartment_base_price::numeric*v_multiplier::numeric/10000)::bigint;
    elsif v_asset.category='house_villa' then v_price:=round(v_location.house_base_price::numeric*v_multiplier::numeric/10000)::bigint;
    else raise exception 'Location pricing is only supported for property assets.'; end if;
    v_rate:=greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment));
    if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=v_asset.code and location_code=v_location.code and sold_absolute_day is null) then raise exception 'You already own this property type in this city.'; end if;
  else
    v_price:=v_asset.purchase_price; v_rate:=v_asset.annual_value_rate_bps;
    if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=v_asset.code and location_code is null and sold_absolute_day is null) then raise exception 'You already own this asset.'; end if;
  end if;
  v_running:=public.private_life_monthly_ownership_cost_v1(v_asset.category,v_price)*12;
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  insert into public.private_life_player_assets(id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,prestige_override)
  values(v_owned_id,v_player,v_asset.code,case when v_location_priced then v_location.code else null end,'purchase',v_abs,v_price,v_running,case when v_location_priced then v_rate else null end,case when v_location_priced then v_asset.resale_discount_bps else null end,case when v_location_priced then v_asset.prestige else null end);
  v_fin:=public.post_career_finance_transaction_v1(v_player,-v_price,'private_life','purchase_'||v_asset.category,'Private Life purchase: '||v_asset.name||case when v_location_priced then ' · '||v_location.city else '' end,'private_life_asset',v_owned_id::text,'private-life-purchase:'||v_owned_id::text,jsonb_build_object('catalog_code',v_asset.code,'category',v_asset.category,'location_code',case when v_location_priced then v_location.code else null end,'city',case when v_location_priced then v_location.city else null end,'country_code',case when v_location_priced then v_location.country_code else null end,'prestige',v_asset.prestige,'annual_running_cost',v_running,'monthly_ownership_cost',v_running/12),true,v_abs);
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets set purchase_transaction_id=v_tx,updated_at=now() where id=v_owned_id;
  return jsonb_build_object('status','purchased','owned_asset_id',v_owned_id,'catalog_code',v_asset.code,'name',v_asset.name,'location_code',case when v_location_priced then v_location.code else null end,'city',case when v_location_priced then v_location.city else null end,'price',v_price,'prestige',v_asset.prestige,'monthly_ownership_cost',v_running/12,'balance',v_fin->'balance');
end;
$$;
revoke all on function public.buy_private_life_asset_v2(text,text) from public,anon;
grant execute on function public.buy_private_life_asset_v2(text,text) to authenticated;

create or replace function public.list_private_life_asset_for_sale_v1(p_owned_asset_id uuid,p_sale_mode text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player uuid; v_owned public.private_life_player_assets%rowtype; v_asset public.private_life_asset_catalog%rowtype;
  v_abs integer; gd record; v_market bigint; v_discount integer; v_sale bigint; v_wait integer; v_listing_id uuid:=gen_random_uuid();
  v_other_available_residences integer:=0;
begin
  v_player:=public.private_life_current_player_v1();
  if lower(coalesce(p_sale_mode,'')) not in ('urgent','standard','patient') then raise exception 'Sale mode must be urgent, standard or patient.'; end if;
  select * into v_owned from public.private_life_player_assets where id=p_owned_asset_id and player_id=v_player and sold_absolute_day is null for update;
  if v_owned.id is null then raise exception 'Owned lifestyle asset not found.'; end if;
  if exists(select 1 from public.private_life_asset_sale_listings where player_asset_id=v_owned.id and status='pending') then raise exception 'This asset is already listed for sale.'; end if;
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  if v_asset.category in ('apartment','house_villa') then
    select count(*)::integer into v_other_available_residences
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player
      and o.id<>v_owned.id
      and o.sold_absolute_day is null
      and c.category in ('apartment','house_villa')
      and not exists(select 1 from public.private_life_asset_sale_listings s where s.player_asset_id=o.id and s.status='pending');
    if v_other_available_residences<1 then
      raise exception 'You must own another apartment, house or villa before selling your current residence.';
    end if;
  end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_market:=public.private_life_market_value_v1(v_owned.purchase_price,coalesce(v_owned.annual_value_rate_bps_override,v_asset.annual_value_rate_bps),v_owned.purchase_absolute_day,v_abs);
  v_discount:=coalesce(v_owned.resale_discount_bps_override,v_asset.resale_discount_bps);
  v_sale:=public.private_life_sale_price_v2(v_market,v_discount,lower(p_sale_mode));
  v_wait:=public.private_life_sale_wait_days_v1(lower(p_sale_mode));
  insert into public.private_life_asset_sale_listings(id,player_id,player_asset_id,sale_mode,listed_absolute_day,settle_absolute_day,quoted_market_value,quoted_sale_price) values(v_listing_id,v_player,v_owned.id,lower(p_sale_mode),v_abs,v_abs+v_wait,v_market,v_sale);
  if v_wait=0 then return public.settle_private_life_asset_sale_listing_v1(v_listing_id); end if;
  return jsonb_build_object('status','listed','listing_id',v_listing_id,'owned_asset_id',v_owned.id,'sale_mode',lower(p_sale_mode),'quoted_market_value',v_market,'quoted_sale_price',v_sale,'wait_days',v_wait,'settle_absolute_day',v_abs+v_wait);
end;
$$;
revoke all on function public.list_private_life_asset_for_sale_v1(uuid,text) from public,anon;
grant execute on function public.list_private_life_asset_for_sale_v1(uuid,text) to authenticated;

create or replace function public.get_private_life_investments_dashboard_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare
  v_player uuid; v_account public.player_career_finance_accounts%rowtype;
  v_portfolio_value bigint:=0; v_cost_basis bigint:=0; v_realized bigint:=0;
  v_positions jsonb:='[]'::jsonb; v_instruments jsonb:='[]'::jsonb; v_trades jsonb:='[]'::jsonb;
begin
  v_player:=public.private_life_current_player_v1();
  perform public.ensure_player_career_finance_v1(v_player);
  select * into v_account from public.player_career_finance_accounts where player_id=v_player;
  select coalesce(sum(round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))),0)::bigint,coalesce(sum(p.cost_basis),0)::bigint
    into v_portfolio_value,v_cost_basis
  from public.private_life_investment_positions p left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
  where p.player_id=v_player and p.quantity>0;
  select coalesce(sum(realized_pnl),0)::bigint into v_realized from public.private_life_investment_trades where player_id=v_player and side='sell';

  select coalesce(jsonb_agg(x order by x.asset_type,x.sort_order,x.symbol),'[]'::jsonb) into v_instruments
  from (
    select i.code,i.asset_type,i.symbol,i.name,i.exchange,i.sort_order,i.metadata,q.price,q.previous_price,q.quote_as_of,q.fetched_at,q.source as quote_source,
      coalesce(q.metadata,'{}'::jsonb)||jsonb_build_object('intraday_history',coalesce(h.history,'[]'::jsonb)) as quote_metadata,
      case when q.fetched_at is null then true when i.asset_type='crypto' then q.fetched_at<now()-interval '20 minutes' else q.fetched_at<now()-interval '30 minutes' end as quote_stale,
      case when q.price is null then false when i.asset_type='crypto' then q.fetched_at>=now()-interval '60 minutes' else q.fetched_at>=now()-interval '7 days' end as tradeable,
      coalesce(p.quantity,0)::numeric as owned_quantity,coalesce(p.cost_basis,0)::bigint as cost_basis,
      case when q.price is null then 0 else round(coalesce(p.quantity,0)*q.price)::bigint end as market_value
    from public.private_life_investment_instruments i
    left join public.private_life_investment_quotes q on q.instrument_code=i.code
    left join public.private_life_investment_positions p on p.player_id=v_player and p.instrument_code=i.code
    left join lateral (
      select jsonb_agg(jsonb_build_object('t',extract(epoch from z.captured_at)::bigint,'p',z.price) order by z.captured_at) as history
      from (select captured_at,price from public.private_life_investment_quote_history hh where hh.instrument_code=i.code order by captured_at desc limit 96) z
    ) h on true
    where i.active=true
  ) x;

  select coalesce(jsonb_agg(x order by x.market_value_precise desc,x.name),'[]'::jsonb) into v_positions
  from (
    select p.instrument_code,i.asset_type,i.symbol,i.name,i.exchange,p.quantity,p.cost_basis,q.price,q.previous_price,q.quote_as_of,q.fetched_at,q.source as quote_source,
      coalesce(q.metadata,'{}'::jsonb)||jsonb_build_object('intraday_history',coalesce(h.history,'[]'::jsonb)) as quote_metadata,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end),2) as market_value_precise,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end),2)-p.cost_basis::numeric as unrealized_pnl_precise,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))::bigint as market_value,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))::bigint-p.cost_basis as unrealized_pnl,
      case when p.quantity>0 then round((p.cost_basis::numeric/p.quantity),8) else 0 end as average_buy_price,
      case when p.cost_basis>0 then round(((p.quantity*coalesce(q.price,p.cost_basis::numeric/nullif(p.quantity,0)))-p.cost_basis::numeric)*100/p.cost_basis::numeric,4) else 0 end as return_pct,
      case when q.previous_price>0 then round(((q.price-q.previous_price)*100/q.previous_price),4) else null end as daily_move_pct
    from public.private_life_investment_positions p
    join public.private_life_investment_instruments i on i.code=p.instrument_code
    left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
    left join lateral (
      select jsonb_agg(jsonb_build_object('t',extract(epoch from z.captured_at)::bigint,'p',z.price) order by z.captured_at) as history
      from (select captured_at,price from public.private_life_investment_quote_history hh where hh.instrument_code=i.code order by captured_at desc limit 96) z
    ) h on true
    where p.player_id=v_player and p.quantity>0
  ) x;

  select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) into v_trades
  from (select t.id,t.instrument_code,i.asset_type,i.symbol,i.name,t.side,t.quantity,t.unit_price,t.gross_amount,t.realized_pnl,t.game_absolute_day,t.quote_as_of,t.created_at from public.private_life_investment_trades t join public.private_life_investment_instruments i on i.code=t.instrument_code where t.player_id=v_player order by t.created_at desc limit 100) x;
  return jsonb_build_object('player_id',v_player,'currency',v_account.currency,'cash_balance',v_account.balance,'portfolio_value',v_portfolio_value,'cost_basis',v_cost_basis,'unrealized_pnl',v_portfolio_value-v_cost_basis,'realized_pnl',v_realized,'positions',v_positions,'instruments',v_instruments,'trades',v_trades);
end;
$$;
revoke all on function public.get_private_life_investments_dashboard_v1() from public,anon;
grant execute on function public.get_private_life_investments_dashboard_v1() to authenticated;