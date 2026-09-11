alter table public.private_life_asset_catalog drop constraint if exists private_life_asset_catalog_category_check;
alter table public.private_life_asset_catalog add constraint private_life_asset_catalog_category_check
  check (category in ('watch','jewelry','car','apartment','house_villa','yacht','private_jet','art','collectible'));

insert into public.private_life_asset_catalog
(code,category,name,tier,description,purchase_price,prestige,rarity,annual_running_cost,annual_value_rate_bps,resale_discount_bps,image_url,active,metadata)
values
('jewelry_signature_bracelet','jewelry','Signature Gold Bracelet',1,'A refined luxury bracelet that fits an emerging tour lifestyle.',5000,1,'common',80,0,900,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jewelry_diamond_tennis','jewelry','Diamond Tennis Bracelet',2,'A classic diamond tennis bracelet with strong prestige appeal.',22000,3,'uncommon',250,100,800,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jewelry_sapphire_set','jewelry','Sapphire Evening Set',2,'A sapphire and diamond set suited to major events and sponsor galas.',65000,5,'rare',700,150,750,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jewelry_high_jewelry_necklace','jewelry','High Jewellery Necklace',3,'A statement necklace from the world of high jewellery.',180000,9,'rare',2200,250,700,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jewelry_collector_diamond','jewelry','Collector Diamond Suite',4,'A collector-grade diamond suite with long-term scarcity appeal.',650000,16,'very_rare',8500,350,650,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jewelry_one_of_one','jewelry','One-of-One High Jewellery Piece',5,'A unique commissioned piece created for a global sports celebrity.',2500000,30,'legendary',32000,450,500,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),

('art_emerging_original','art','Emerging Artist Original',1,'An original work from a promising contemporary artist.',8000,1,'common',120,200,1200,'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('art_gallery_piece','art','Gallery Contemporary Piece',2,'A gallery-level contemporary artwork with growing collector interest.',35000,3,'uncommon',550,300,1000,'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('art_established_artist','art','Established Artist Work',3,'A signed work by an established international artist.',150000,7,'rare',2600,400,850,'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('art_blue_chip','art','Blue-Chip Contemporary Work',4,'A high-value piece from a recognised blue-chip contemporary artist.',750000,14,'very_rare',14000,500,700,'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('art_museum_quality','art','Museum-Quality Masterwork',5,'A museum-quality artwork with international collector demand.',4000000,26,'very_rare',80000,600,600,'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('art_trophy_masterpiece','art','Trophy Masterpiece',5,'A headline-level trophy artwork reserved for the wealthiest collectors.',18000000,45,'legendary',360000,700,500,'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),

('collectible_signed_racquet','collectible','Signed Championship Racquet',1,'A signed championship-era racquet displayed as a career-room collectible.',2500,1,'common',40,100,1200,'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('collectible_vintage_tennis_set','collectible','Vintage Tennis Collection',2,'A curated set of classic tennis memorabilia and historic equipment.',12000,2,'uncommon',180,250,1000,'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('collectible_rare_sports_cards','collectible','Rare Sports Card Collection',2,'A professionally curated portfolio of rare sports cards.',40000,4,'rare',550,400,900,'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('collectible_match_worn_archive','collectible','Historic Match-Worn Archive',3,'A premium archive of authenticated match-worn sporting pieces.',140000,8,'rare',2100,450,800,'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('collectible_racing_archive','collectible','Classic Racing Memorabilia',4,'A rare collection of signed and authenticated motorsport memorabilia.',550000,14,'very_rare',9000,500,700,'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('collectible_museum_sports','collectible','Museum-Grade Sports Collection',5,'A museum-grade private sports collection assembled for an elite collector.',2200000,27,'legendary',38000,600,600,'https://images.unsplash.com/photo-1580136579312-94651dfd596d?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),

('jet_very_light','private_jet','Very Light Private Jet',3,'An entry-level private jet for short regional travel and smaller entourages.',3500000,12,'rare',420000,-1200,1200,'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jet_light','private_jet','Light Private Jet',4,'A comfortable light jet with improved range for European and domestic travel.',6500000,18,'rare',700000,-1100,1100,'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jet_midsize','private_jet','Midsize Private Jet',4,'A midsize business jet suitable for longer international tournament routes.',14000000,28,'very_rare',1400000,-1000,1000,'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jet_super_midsize','private_jet','Super-Midsize Private Jet',5,'A premium super-midsize jet with transcontinental range and luxury cabin space.',28000000,40,'very_rare',2600000,-900,900,'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jet_long_range','private_jet','Long-Range Private Jet',5,'A long-range private aircraft capable of major intercontinental tour travel.',52000000,55,'legendary',4800000,-800,800,'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}'),
('jet_flagship','private_jet','Flagship Ultra-Long-Range Jet',5,'The ultimate private-aircraft status symbol for a global sporting icon.',78000000,75,'legendary',7200000,-700,700,'https://images.unsplash.com/photo-1540962351504-03099e0a754b?auto=format&fit=crop&w=1200&q=80',true,'{"condition":"new"}')
on conflict (code) do update set
  category=excluded.category,name=excluded.name,tier=excluded.tier,description=excluded.description,
  purchase_price=excluded.purchase_price,prestige=excluded.prestige,rarity=excluded.rarity,
  annual_running_cost=excluded.annual_running_cost,annual_value_rate_bps=excluded.annual_value_rate_bps,
  resale_discount_bps=excluded.resale_discount_bps,image_url=excluded.image_url,active=true,metadata=excluded.metadata,updated_at=now();

alter table public.private_life_investment_instruments drop constraint if exists private_life_investment_instruments_provider_check;
alter table public.private_life_investment_instruments add constraint private_life_investment_instruments_provider_check
  check (provider in ('stooq','yahoo','coingecko'));

insert into public.private_life_investment_instruments(code,asset_type,symbol,name,provider,provider_key,exchange,sort_order,metadata) values
('stock_aapl','stock','AAPL','Apple','yahoo','AAPL','NASDAQ',10,'{"sector":"Technology","country":"US"}'),
('stock_msft','stock','MSFT','Microsoft','yahoo','MSFT','NASDAQ',20,'{"sector":"Technology","country":"US"}'),
('stock_nvda','stock','NVDA','NVIDIA','yahoo','NVDA','NASDAQ',30,'{"sector":"Technology","country":"US"}'),
('stock_amzn','stock','AMZN','Amazon','yahoo','AMZN','NASDAQ',40,'{"sector":"Consumer","country":"US"}'),
('stock_googl','stock','GOOGL','Alphabet','yahoo','GOOGL','NASDAQ',50,'{"sector":"Technology","country":"US"}'),
('stock_meta','stock','META','Meta Platforms','yahoo','META','NASDAQ',60,'{"sector":"Technology","country":"US"}'),
('stock_tsla','stock','TSLA','Tesla','yahoo','TSLA','NASDAQ',70,'{"sector":"Automotive","country":"US"}'),
('stock_nflx','stock','NFLX','Netflix','yahoo','NFLX','NASDAQ',80,'{"sector":"Media","country":"US"}'),
('stock_amd','stock','AMD','AMD','yahoo','AMD','NASDAQ',90,'{"sector":"Technology","country":"US"}'),
('stock_spot','stock','SPOT','Spotify','yahoo','SPOT','NYSE',100,'{"sector":"Media","country":"SE"}'),
('stock_nke','stock','NKE','Nike','yahoo','NKE','NYSE',110,'{"sector":"Consumer","country":"US"}'),
('stock_race','stock','RACE','Ferrari','yahoo','RACE','NYSE',120,'{"sector":"Luxury & Automotive","country":"IT"}'),
('stock_dis','stock','DIS','Walt Disney','yahoo','DIS','NYSE',130,'{"sector":"Media","country":"US"}'),
('stock_ko','stock','KO','Coca-Cola','yahoo','KO','NYSE',140,'{"sector":"Consumer","country":"US"}'),
('stock_jpm','stock','JPM','JPMorgan Chase','yahoo','JPM','NYSE',150,'{"sector":"Financials","country":"US"}'),
('stock_v','stock','V','Visa','yahoo','V','NYSE',160,'{"sector":"Financials","country":"US"}'),
('stock_ma','stock','MA','Mastercard','yahoo','MA','NYSE',170,'{"sector":"Financials","country":"US"}'),
('stock_sbux','stock','SBUX','Starbucks','yahoo','SBUX','NASDAQ',180,'{"sector":"Consumer","country":"US"}'),
('stock_orcl','stock','ORCL','Oracle','yahoo','ORCL','NYSE',190,'{"sector":"Technology","country":"US"}'),
('stock_crm','stock','CRM','Salesforce','yahoo','CRM','NYSE',200,'{"sector":"Technology","country":"US"}'),
('stock_adbe','stock','ADBE','Adobe','yahoo','ADBE','NASDAQ',210,'{"sector":"Technology","country":"US"}'),
('stock_avgo','stock','AVGO','Broadcom','yahoo','AVGO','NASDAQ',220,'{"sector":"Technology","country":"US"}'),
('stock_intc','stock','INTC','Intel','yahoo','INTC','NASDAQ',230,'{"sector":"Technology","country":"US"}'),
('stock_qcom','stock','QCOM','Qualcomm','yahoo','QCOM','NASDAQ',240,'{"sector":"Technology","country":"US"}'),
('stock_ibm','stock','IBM','IBM','yahoo','IBM','NYSE',250,'{"sector":"Technology","country":"US"}'),
('stock_tsm','stock','TSM','TSMC','yahoo','TSM','NYSE',260,'{"sector":"Technology","country":"TW"}'),
('stock_asml','stock','ASML','ASML','yahoo','ASML','NASDAQ',270,'{"sector":"Technology","country":"NL"}'),
('stock_sap','stock','SAP','SAP','yahoo','SAP','NYSE',280,'{"sector":"Technology","country":"DE"}'),
('stock_lly','stock','LLY','Eli Lilly','yahoo','LLY','NYSE',290,'{"sector":"Healthcare","country":"US"}'),
('stock_jnj','stock','JNJ','Johnson & Johnson','yahoo','JNJ','NYSE',300,'{"sector":"Healthcare","country":"US"}'),
('stock_mrk','stock','MRK','Merck','yahoo','MRK','NYSE',310,'{"sector":"Healthcare","country":"US"}'),
('stock_pfe','stock','PFE','Pfizer','yahoo','PFE','NYSE',320,'{"sector":"Healthcare","country":"US"}'),
('stock_unh','stock','UNH','UnitedHealth','yahoo','UNH','NYSE',330,'{"sector":"Healthcare","country":"US"}'),
('stock_nvo','stock','NVO','Novo Nordisk','yahoo','NVO','NYSE',340,'{"sector":"Healthcare","country":"DK"}'),
('stock_wmt','stock','WMT','Walmart','yahoo','WMT','NASDAQ',350,'{"sector":"Consumer","country":"US"}'),
('stock_cost','stock','COST','Costco','yahoo','COST','NASDAQ',360,'{"sector":"Consumer","country":"US"}'),
('stock_mcd','stock','MCD','McDonald''s','yahoo','MCD','NYSE',370,'{"sector":"Consumer","country":"US"}'),
('stock_pep','stock','PEP','PepsiCo','yahoo','PEP','NASDAQ',380,'{"sector":"Consumer","country":"US"}'),
('stock_pg','stock','PG','Procter & Gamble','yahoo','PG','NYSE',390,'{"sector":"Consumer","country":"US"}'),
('stock_hd','stock','HD','Home Depot','yahoo','HD','NYSE',400,'{"sector":"Consumer","country":"US"}'),
('stock_abnb','stock','ABNB','Airbnb','yahoo','ABNB','NASDAQ',410,'{"sector":"Travel","country":"US"}'),
('stock_bkng','stock','BKNG','Booking Holdings','yahoo','BKNG','NASDAQ',420,'{"sector":"Travel","country":"US"}'),
('stock_mar','stock','MAR','Marriott','yahoo','MAR','NASDAQ',430,'{"sector":"Travel","country":"US"}'),
('stock_xom','stock','XOM','Exxon Mobil','yahoo','XOM','NYSE',440,'{"sector":"Energy","country":"US"}'),
('stock_cvx','stock','CVX','Chevron','yahoo','CVX','NYSE',450,'{"sector":"Energy","country":"US"}'),
('stock_ba','stock','BA','Boeing','yahoo','BA','NYSE',460,'{"sector":"Industrials","country":"US"}'),
('stock_cat','stock','CAT','Caterpillar','yahoo','CAT','NYSE',470,'{"sector":"Industrials","country":"US"}'),
('stock_gs','stock','GS','Goldman Sachs','yahoo','GS','NYSE',480,'{"sector":"Financials","country":"US"}'),
('stock_bac','stock','BAC','Bank of America','yahoo','BAC','NYSE',490,'{"sector":"Financials","country":"US"}'),
('stock_axp','stock','AXP','American Express','yahoo','AXP','NYSE',500,'{"sector":"Financials","country":"US"}'),
('stock_onon','stock','ONON','On Holding','yahoo','ONON','NYSE',510,'{"sector":"Sportswear","country":"CH"}'),
('stock_ea','stock','EA','Electronic Arts','yahoo','EA','NASDAQ',520,'{"sector":"Gaming","country":"US"}')
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
      q.price,q.previous_price,q.quote_as_of,q.fetched_at,q.source as quote_source,q.metadata as quote_metadata,
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
      q.price,q.quote_as_of,q.fetched_at,q.source as quote_source,q.metadata as quote_metadata,
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

revoke all on function public.get_private_life_investments_dashboard_v1() from public,anon;
grant execute on function public.get_private_life_investments_dashboard_v1() to authenticated;