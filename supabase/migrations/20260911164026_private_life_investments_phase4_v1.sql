create table if not exists public.private_life_investment_instruments (
  code text primary key,
  asset_type text not null check (asset_type in ('stock','crypto')),
  symbol text not null,
  name text not null,
  provider text not null check (provider in ('stooq','coingecko')),
  provider_key text not null,
  exchange text,
  quote_currency text not null default 'USD' check (quote_currency='USD'),
  sort_order integer not null default 0,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(asset_type,symbol)
);

create table if not exists public.private_life_investment_quotes (
  instrument_code text primary key references public.private_life_investment_instruments(code) on delete cascade,
  price numeric(24,8) not null check (price>0),
  previous_price numeric(24,8),
  quote_as_of timestamptz not null,
  fetched_at timestamptz not null default now(),
  source text not null,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.private_life_investment_positions (
  player_id uuid not null references public.players(id) on delete cascade,
  instrument_code text not null references public.private_life_investment_instruments(code),
  quantity numeric(30,10) not null default 0 check (quantity>=0),
  cost_basis bigint not null default 0 check (cost_basis>=0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(player_id,instrument_code)
);

create table if not exists public.private_life_investment_trades (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  instrument_code text not null references public.private_life_investment_instruments(code),
  side text not null check (side in ('buy','sell')),
  quantity numeric(30,10) not null check (quantity>0),
  unit_price numeric(24,8) not null check (unit_price>0),
  gross_amount bigint not null check (gross_amount>0),
  realized_pnl bigint not null default 0,
  finance_transaction_id uuid references public.career_finance_transactions(id),
  game_absolute_day integer not null,
  quote_as_of timestamptz not null,
  request_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(player_id,request_key)
);

create index if not exists private_life_investment_positions_instrument_idx on public.private_life_investment_positions(instrument_code);
create index if not exists private_life_investment_trades_player_created_idx on public.private_life_investment_trades(player_id,created_at desc);
create index if not exists private_life_investment_trades_instrument_idx on public.private_life_investment_trades(instrument_code);
create index if not exists private_life_investment_trades_finance_tx_idx on public.private_life_investment_trades(finance_transaction_id) where finance_transaction_id is not null;

alter table public.private_life_investment_instruments enable row level security;
alter table public.private_life_investment_quotes enable row level security;
alter table public.private_life_investment_positions enable row level security;
alter table public.private_life_investment_trades enable row level security;

revoke all on public.private_life_investment_instruments from public,anon,authenticated;
revoke all on public.private_life_investment_quotes from public,anon,authenticated;
revoke all on public.private_life_investment_positions from public,anon,authenticated;
revoke all on public.private_life_investment_trades from public,anon,authenticated;

insert into public.private_life_investment_instruments(code,asset_type,symbol,name,provider,provider_key,exchange,sort_order,metadata) values
('stock_aapl','stock','AAPL','Apple','stooq','aapl.us','NASDAQ',10,'{"sector":"Technology"}'),
('stock_msft','stock','MSFT','Microsoft','stooq','msft.us','NASDAQ',20,'{"sector":"Technology"}'),
('stock_nvda','stock','NVDA','NVIDIA','stooq','nvda.us','NASDAQ',30,'{"sector":"Technology"}'),
('stock_amzn','stock','AMZN','Amazon','stooq','amzn.us','NASDAQ',40,'{"sector":"Consumer"}'),
('stock_googl','stock','GOOGL','Alphabet','stooq','googl.us','NASDAQ',50,'{"sector":"Technology"}'),
('stock_meta','stock','META','Meta Platforms','stooq','meta.us','NASDAQ',60,'{"sector":"Technology"}'),
('stock_tsla','stock','TSLA','Tesla','stooq','tsla.us','NASDAQ',70,'{"sector":"Automotive"}'),
('stock_nflx','stock','NFLX','Netflix','stooq','nflx.us','NASDAQ',80,'{"sector":"Media"}'),
('stock_amd','stock','AMD','AMD','stooq','amd.us','NASDAQ',90,'{"sector":"Technology"}'),
('stock_spot','stock','SPOT','Spotify','stooq','spot.us','NYSE',100,'{"sector":"Media"}'),
('stock_nke','stock','NKE','Nike','stooq','nke.us','NYSE',110,'{"sector":"Consumer"}'),
('stock_race','stock','RACE','Ferrari','stooq','race.us','NYSE',120,'{"sector":"Luxury & Automotive"}'),
('stock_dis','stock','DIS','Walt Disney','stooq','dis.us','NYSE',130,'{"sector":"Media"}'),
('stock_ko','stock','KO','Coca-Cola','stooq','ko.us','NYSE',140,'{"sector":"Consumer"}'),
('stock_jpm','stock','JPM','JPMorgan Chase','stooq','jpm.us','NYSE',150,'{"sector":"Financials"}'),
('stock_v','stock','V','Visa','stooq','v.us','NYSE',160,'{"sector":"Financials"}'),
('stock_ma','stock','MA','Mastercard','stooq','ma.us','NYSE',170,'{"sector":"Financials"}'),
('stock_sbux','stock','SBUX','Starbucks','stooq','sbux.us','NASDAQ',180,'{"sector":"Consumer"}'),
('crypto_btc','crypto','BTC','Bitcoin','coingecko','bitcoin',null,210,'{}'),
('crypto_eth','crypto','ETH','Ethereum','coingecko','ethereum',null,220,'{}'),
('crypto_sol','crypto','SOL','Solana','coingecko','solana',null,230,'{}'),
('crypto_bnb','crypto','BNB','BNB','coingecko','binancecoin',null,240,'{}'),
('crypto_xrp','crypto','XRP','XRP','coingecko','ripple',null,250,'{}'),
('crypto_ada','crypto','ADA','Cardano','coingecko','cardano',null,260,'{}'),
('crypto_doge','crypto','DOGE','Dogecoin','coingecko','dogecoin',null,270,'{}'),
('crypto_avax','crypto','AVAX','Avalanche','coingecko','avalanche-2',null,280,'{}'),
('crypto_link','crypto','LINK','Chainlink','coingecko','chainlink',null,290,'{}'),
('crypto_dot','crypto','DOT','Polkadot','coingecko','polkadot',null,300,'{}')
on conflict (code) do update set
  asset_type=excluded.asset_type,symbol=excluded.symbol,name=excluded.name,provider=excluded.provider,provider_key=excluded.provider_key,
  exchange=excluded.exchange,sort_order=excluded.sort_order,metadata=excluded.metadata,active=true,updated_at=now();

create or replace function public.get_private_life_investments_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  v_account public.player_career_finance_accounts%rowtype;
  v_portfolio_value bigint:=0;
  v_cost_basis bigint:=0;
  v_realized bigint:=0;
  v_positions jsonb:='[]'::jsonb;
  v_instruments jsonb:='[]'::jsonb;
  v_trades jsonb:='[]'::jsonb;
begin
  v_player:=public.private_life_current_player_v1();
  perform public.ensure_player_career_finance_v1(v_player);
  select * into v_account from public.player_career_finance_accounts where player_id=v_player;

  select coalesce(sum(round(p.quantity * coalesce(q.price, case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))),0)::bigint,
         coalesce(sum(p.cost_basis),0)::bigint
  into v_portfolio_value,v_cost_basis
  from public.private_life_investment_positions p
  left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
  where p.player_id=v_player and p.quantity>0;

  select coalesce(sum(realized_pnl),0)::bigint into v_realized
  from public.private_life_investment_trades
  where player_id=v_player and side='sell';

  select coalesce(jsonb_agg(x order by x.asset_type,x.sort_order,x.symbol),'[]'::jsonb) into v_instruments
  from (
    select i.code,i.asset_type,i.symbol,i.name,i.exchange,i.sort_order,i.metadata,
      q.price,q.previous_price,q.quote_as_of,q.fetched_at,q.source as quote_source,
      case when q.fetched_at is null then true
           when i.asset_type='crypto' then q.fetched_at < now()-interval '5 minutes'
           else q.fetched_at < now()-interval '30 minutes' end as quote_stale,
      case when q.price is null then false
           when i.asset_type='crypto' then q.fetched_at >= now()-interval '30 minutes'
           else q.fetched_at >= now()-interval '7 days' end as tradeable,
      coalesce(p.quantity,0)::numeric as owned_quantity,
      coalesce(p.cost_basis,0)::bigint as cost_basis,
      case when q.price is null then 0 else round(coalesce(p.quantity,0)*q.price)::bigint end as market_value
    from public.private_life_investment_instruments i
    left join public.private_life_investment_quotes q on q.instrument_code=i.code
    left join public.private_life_investment_positions p on p.player_id=v_player and p.instrument_code=i.code
    where i.active=true
  ) x;

  select coalesce(jsonb_agg(x order by x.market_value desc,x.name),'[]'::jsonb) into v_positions
  from (
    select p.instrument_code,i.asset_type,i.symbol,i.name,i.exchange,p.quantity,p.cost_basis,
      q.price,q.quote_as_of,q.fetched_at,q.source as quote_source,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))::bigint as market_value,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))::bigint-p.cost_basis as unrealized_pnl,
      case when p.quantity>0 then round((p.cost_basis::numeric/p.quantity),8) else 0 end as average_buy_price
    from public.private_life_investment_positions p
    join public.private_life_investment_instruments i on i.code=p.instrument_code
    left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
    where p.player_id=v_player and p.quantity>0
  ) x;

  select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) into v_trades
  from (
    select t.id,t.instrument_code,i.asset_type,i.symbol,i.name,t.side,t.quantity,t.unit_price,t.gross_amount,t.realized_pnl,
      t.game_absolute_day,t.quote_as_of,t.created_at
    from public.private_life_investment_trades t
    join public.private_life_investment_instruments i on i.code=t.instrument_code
    where t.player_id=v_player
    order by t.created_at desc
    limit 100
  ) x;

  return jsonb_build_object(
    'player_id',v_player,
    'currency',v_account.currency,
    'cash_balance',v_account.balance,
    'portfolio_value',v_portfolio_value,
    'cost_basis',v_cost_basis,
    'unrealized_pnl',v_portfolio_value-v_cost_basis,
    'realized_pnl',v_realized,
    'positions',v_positions,
    'instruments',v_instruments,
    'trades',v_trades
  );
end;
$$;

create or replace function public.buy_private_life_investment_v1(p_instrument_code text,p_cash_amount bigint,p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  v_instrument public.private_life_investment_instruments%rowtype;
  v_quote public.private_life_investment_quotes%rowtype;
  v_position public.private_life_investment_positions%rowtype;
  v_existing public.private_life_investment_trades%rowtype;
  v_trade_id uuid:=gen_random_uuid();
  v_quantity numeric(30,10);
  v_fin jsonb;
  v_tx uuid;
  v_abs integer;
  gd record;
begin
  v_player:=public.private_life_current_player_v1();
  if p_request_key is null or btrim(p_request_key)='' then raise exception 'Trade request key is required.'; end if;
  if p_cash_amount is null or p_cash_amount<10 then raise exception 'Minimum investment is $10.'; end if;

  select * into v_existing from public.private_life_investment_trades where player_id=v_player and request_key=p_request_key;
  if v_existing.id is not null then
    return jsonb_build_object('status','already_posted','trade_id',v_existing.id,'quantity',v_existing.quantity,'gross_amount',v_existing.gross_amount);
  end if;

  select * into v_instrument from public.private_life_investment_instruments where code=p_instrument_code and active=true;
  if v_instrument.code is null then raise exception 'Investment instrument not found.'; end if;
  select * into v_quote from public.private_life_investment_quotes where instrument_code=v_instrument.code;
  if v_quote.instrument_code is null then raise exception 'Market quote unavailable. Refresh prices and try again.'; end if;
  if v_instrument.asset_type='crypto' and v_quote.fetched_at<now()-interval '30 minutes' then raise exception 'Crypto quote is stale. Refresh prices and try again.'; end if;
  if v_instrument.asset_type='stock' and v_quote.fetched_at<now()-interval '7 days' then raise exception 'Stock quote is stale. Refresh prices and try again.'; end if;

  v_quantity:=round(p_cash_amount::numeric/v_quote.price,10);
  if v_quantity<=0 then raise exception 'Investment amount is too small for this quote.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  v_fin:=public.post_career_finance_transaction_v1(
    v_player,-p_cash_amount,'private_life','investment_buy_'||v_instrument.asset_type,
    'Private Life investment: buy '||v_instrument.symbol,'private_life_investment_trade',v_trade_id::text,
    'private-life-investment-buy:'||p_request_key,
    jsonb_build_object('instrument_code',v_instrument.code,'symbol',v_instrument.symbol,'asset_type',v_instrument.asset_type,'quantity',v_quantity,'unit_price',v_quote.price),
    true,v_abs
  );
  v_tx:=(v_fin->>'transaction_id')::uuid;

  select * into v_position from public.private_life_investment_positions where player_id=v_player and instrument_code=v_instrument.code for update;
  if v_position.player_id is null then
    insert into public.private_life_investment_positions(player_id,instrument_code,quantity,cost_basis)
    values(v_player,v_instrument.code,v_quantity,p_cash_amount);
  else
    update public.private_life_investment_positions
    set quantity=quantity+v_quantity,cost_basis=cost_basis+p_cash_amount,updated_at=now()
    where player_id=v_player and instrument_code=v_instrument.code;
  end if;

  insert into public.private_life_investment_trades(id,player_id,instrument_code,side,quantity,unit_price,gross_amount,realized_pnl,finance_transaction_id,game_absolute_day,quote_as_of,request_key,metadata)
  values(v_trade_id,v_player,v_instrument.code,'buy',v_quantity,v_quote.price,p_cash_amount,0,v_tx,v_abs,v_quote.quote_as_of,p_request_key,jsonb_build_object('quote_source',v_quote.source));

  return jsonb_build_object('status','bought','trade_id',v_trade_id,'instrument_code',v_instrument.code,'symbol',v_instrument.symbol,'quantity',v_quantity,'unit_price',v_quote.price,'gross_amount',p_cash_amount,'balance',v_fin->'balance');
end;
$$;

create or replace function public.sell_private_life_investment_v1(p_instrument_code text,p_quantity numeric,p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  v_instrument public.private_life_investment_instruments%rowtype;
  v_quote public.private_life_investment_quotes%rowtype;
  v_position public.private_life_investment_positions%rowtype;
  v_existing public.private_life_investment_trades%rowtype;
  v_trade_id uuid:=gen_random_uuid();
  v_quantity numeric(30,10);
  v_proceeds bigint;
  v_allocated_cost bigint;
  v_pnl bigint;
  v_fin jsonb;
  v_tx uuid;
  v_abs integer;
  gd record;
begin
  v_player:=public.private_life_current_player_v1();
  if p_request_key is null or btrim(p_request_key)='' then raise exception 'Trade request key is required.'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Sell quantity must be greater than zero.'; end if;

  select * into v_existing from public.private_life_investment_trades where player_id=v_player and request_key=p_request_key;
  if v_existing.id is not null then
    return jsonb_build_object('status','already_posted','trade_id',v_existing.id,'quantity',v_existing.quantity,'gross_amount',v_existing.gross_amount,'realized_pnl',v_existing.realized_pnl);
  end if;

  select * into v_instrument from public.private_life_investment_instruments where code=p_instrument_code and active=true;
  if v_instrument.code is null then raise exception 'Investment instrument not found.'; end if;
  select * into v_quote from public.private_life_investment_quotes where instrument_code=v_instrument.code;
  if v_quote.instrument_code is null then raise exception 'Market quote unavailable. Refresh prices and try again.'; end if;
  if v_instrument.asset_type='crypto' and v_quote.fetched_at<now()-interval '30 minutes' then raise exception 'Crypto quote is stale. Refresh prices and try again.'; end if;
  if v_instrument.asset_type='stock' and v_quote.fetched_at<now()-interval '7 days' then raise exception 'Stock quote is stale. Refresh prices and try again.'; end if;

  select * into v_position from public.private_life_investment_positions where player_id=v_player and instrument_code=v_instrument.code for update;
  if v_position.player_id is null or v_position.quantity<=0 then raise exception 'You do not own this investment.'; end if;
  if p_quantity>v_position.quantity+0.0000000001 then raise exception 'Sell quantity exceeds your holding.'; end if;

  v_quantity:=least(round(p_quantity,10),v_position.quantity);
  v_proceeds:=greatest(1,round(v_quantity*v_quote.price)::bigint);
  if abs(v_quantity-v_position.quantity)<0.0000000001 then
    v_allocated_cost:=v_position.cost_basis;
  else
    v_allocated_cost:=round(v_position.cost_basis::numeric*(v_quantity/v_position.quantity))::bigint;
  end if;
  v_pnl:=v_proceeds-v_allocated_cost;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  v_fin:=public.post_career_finance_transaction_v1(
    v_player,v_proceeds,'private_life','investment_sale_'||v_instrument.asset_type,
    'Private Life investment: sell '||v_instrument.symbol,'private_life_investment_trade',v_trade_id::text,
    'private-life-investment-sell:'||p_request_key,
    jsonb_build_object('instrument_code',v_instrument.code,'symbol',v_instrument.symbol,'asset_type',v_instrument.asset_type,'quantity',v_quantity,'unit_price',v_quote.price,'realized_pnl',v_pnl),
    false,v_abs
  );
  v_tx:=(v_fin->>'transaction_id')::uuid;

  if abs(v_quantity-v_position.quantity)<0.0000000001 then
    delete from public.private_life_investment_positions where player_id=v_player and instrument_code=v_instrument.code;
  else
    update public.private_life_investment_positions
    set quantity=greatest(0,quantity-v_quantity),cost_basis=greatest(0,cost_basis-v_allocated_cost),updated_at=now()
    where player_id=v_player and instrument_code=v_instrument.code;
  end if;

  insert into public.private_life_investment_trades(id,player_id,instrument_code,side,quantity,unit_price,gross_amount,realized_pnl,finance_transaction_id,game_absolute_day,quote_as_of,request_key,metadata)
  values(v_trade_id,v_player,v_instrument.code,'sell',v_quantity,v_quote.price,v_proceeds,v_pnl,v_tx,v_abs,v_quote.quote_as_of,p_request_key,jsonb_build_object('quote_source',v_quote.source,'allocated_cost_basis',v_allocated_cost));

  return jsonb_build_object('status','sold','trade_id',v_trade_id,'instrument_code',v_instrument.code,'symbol',v_instrument.symbol,'quantity',v_quantity,'unit_price',v_quote.price,'gross_amount',v_proceeds,'realized_pnl',v_pnl,'balance',v_fin->'balance');
end;
$$;

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
  v_level smallint;
  v_earnings bigint;
  v_prestige integer;
  v_asset_value bigint;
  v_investment_value bigint:=0;
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
  select coalesce(sum(amount),0)::bigint into v_earnings from public.career_finance_transactions where player_id=v_player and amount>0 and category not in ('career','private_life');

  select coalesce(sum(c.prestige),0)::integer,
    coalesce(sum(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)),0)::bigint,
    coalesce(sum(c.annual_running_cost),0)::bigint
  into v_prestige,v_asset_value,v_running_cost
  from public.private_life_player_assets o
  join public.private_life_asset_catalog c on c.code=o.catalog_code
  where o.player_id=v_player and o.sold_absolute_day is null;

  select coalesce(sum(round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))),0)::bigint
  into v_investment_value
  from public.private_life_investment_positions p
  left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
  where p.player_id=v_player and p.quantity>0;

  select coalesce(jsonb_agg(x order by x.purchase_absolute_day desc,x.name),'[]'::jsonb) into v_owned
  from (
    select o.id,o.catalog_code,c.category,c.name,c.description,c.tier,c.prestige,c.rarity,c.image_url,c.annual_running_cost,c.annual_value_rate_bps,c.resale_discount_bps,
      o.purchase_absolute_day,o.purchase_price,
      public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs) as current_market_value,
      round(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)::numeric*(10000-c.resale_discount_bps)::numeric/10000)::bigint as estimated_sale_price,
      round(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)::numeric*(10000-c.resale_discount_bps)::numeric/10000)::bigint-o.purchase_price as potential_gain_loss,
      greatest(0,v_abs-o.purchase_absolute_day) as ownership_days
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player and o.sold_absolute_day is null
  ) x;

  select coalesce(jsonb_agg(x order by x.category),'[]'::jsonb) into v_categories
  from (
    select c.category,count(*)::integer as owned_count,
      coalesce(sum(public.private_life_market_value_v1(o.purchase_price,c.annual_value_rate_bps,o.purchase_absolute_day,v_abs)),0)::bigint as market_value,
      coalesce(sum(c.prestige),0)::integer as prestige,coalesce(sum(c.annual_running_cost),0)::bigint as annual_running_cost
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player and o.sold_absolute_day is null group by c.category
  ) x;

  select coalesce(jsonb_agg(x order by x.tier,x.purchase_price,x.name),'[]'::jsonb) into v_catalog
  from (
    select c.code,c.category,c.name,c.tier,c.description,c.purchase_price,c.prestige,c.rarity,c.annual_running_cost,c.annual_value_rate_bps,c.resale_discount_bps,c.image_url,c.metadata,
      true as unlocked,(c.purchase_price<=v_account.balance) as affordable,
      exists(select 1 from public.private_life_player_assets o where o.player_id=v_player and o.catalog_code=c.code and o.sold_absolute_day is null) as owned
    from public.private_life_asset_catalog c where c.active=true
  ) x;

  return jsonb_build_object('player_id',v_player,'currency',v_account.currency,'cash_balance',v_account.balance,
    'current_absolute_day',v_abs,'season',gd.season,'month',gd.month,'day',gd.day,
    'lifestyle_level',v_level,'career_earnings',v_earnings,'prestige',v_prestige,'asset_value',v_asset_value,
    'investment_value',v_investment_value,'net_worth',v_account.balance+v_asset_value+v_investment_value,
    'annual_running_cost',v_running_cost,'category_totals',v_categories,'owned_assets',v_owned,'catalog',v_catalog);
end;
$$;

revoke execute on function public.get_private_life_investments_dashboard_v1() from public,anon;
revoke execute on function public.buy_private_life_investment_v1(text,bigint,text) from public,anon;
revoke execute on function public.sell_private_life_investment_v1(text,numeric,text) from public,anon;
grant execute on function public.get_private_life_investments_dashboard_v1() to authenticated;
grant execute on function public.buy_private_life_investment_v1(text,bigint,text) to authenticated;
grant execute on function public.sell_private_life_investment_v1(text,numeric,text) to authenticated;
