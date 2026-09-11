create table public.private_life_asset_catalog (
  code text primary key,
  category text not null check (category in ('watch','car','apartment','house_villa','yacht')),
  name text not null,
  tier smallint not null check (tier between 1 and 5),
  description text not null,
  purchase_price bigint not null check (purchase_price > 0),
  prestige smallint not null default 0 check (prestige >= 0),
  rarity text not null check (rarity in ('common','uncommon','rare','very_rare','legendary')),
  annual_running_cost bigint not null default 0 check (annual_running_cost >= 0),
  annual_value_rate_bps integer not null default 0 check (annual_value_rate_bps between -5000 and 5000),
  resale_discount_bps integer not null default 500 check (resale_discount_bps between 0 and 3000),
  image_url text not null,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.private_life_player_assets (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  catalog_code text not null references public.private_life_asset_catalog(code),
  purchase_absolute_day integer not null,
  purchase_price bigint not null check (purchase_price > 0),
  purchase_transaction_id uuid references public.career_finance_transactions(id),
  sold_absolute_day integer,
  sold_price bigint,
  sale_transaction_id uuid references public.career_finance_transactions(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sold_absolute_day is null or sold_absolute_day >= purchase_absolute_day),
  check ((sold_absolute_day is null and sold_price is null and sale_transaction_id is null) or sold_absolute_day is not null)
);

create index private_life_player_assets_player_active_idx
  on public.private_life_player_assets(player_id,purchase_absolute_day desc)
  where sold_absolute_day is null;
create index private_life_player_assets_player_history_idx
  on public.private_life_player_assets(player_id,created_at desc);
create unique index private_life_player_assets_one_active_catalog_item_idx
  on public.private_life_player_assets(player_id,catalog_code)
  where sold_absolute_day is null;

alter table public.private_life_asset_catalog enable row level security;
alter table public.private_life_player_assets enable row level security;
revoke all on public.private_life_asset_catalog from public,anon,authenticated;
revoke all on public.private_life_player_assets from public,anon,authenticated;

insert into public.private_life_asset_catalog
(code,category,name,tier,description,purchase_price,prestige,rarity,annual_running_cost,annual_value_rate_bps,resale_discount_bps,image_url,metadata)
values
('watch_heritage_steel','watch','Heritage Steel Automatic',1,'A refined entry-level mechanical watch for a player beginning to enjoy life on tour.',3000,1,'common',75,0,800,'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=82','{"style":"classic"}'::jsonb),
('watch_continental_chrono','watch','Continental Chronograph',1,'A sporty luxury chronograph with stronger collector appeal.',12000,2,'uncommon',150,100,700,'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=82','{"style":"sport"}'::jsonb),
('watch_riviera_gold','watch','Riviera Gold Reserve',2,'A precious-metal statement piece that holds value well over time.',35000,4,'rare',300,250,550,'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=82','{"style":"gold"}'::jsonb),
('watch_grand_complication','watch','Grand Complication',3,'A high-horology piece with serious prestige and collector demand.',95000,7,'very_rare',700,400,450,'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=82','{"style":"complication"}'::jsonb),
('watch_collector_heritage','watch','Collector Heritage Edition',4,'A scarce collector watch with meaningful long-term appreciation potential.',250000,11,'very_rare',1500,700,350,'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=82','{"style":"collector"}'::jsonb),
('watch_one_of_one','watch','One-of-One Tourbillon',5,'An ultra-rare bespoke tourbillon reserved for tennis icons.',750000,18,'legendary',5000,1000,300,'https://images.unsplash.com/photo-1523170335258-f5ed11844a49?auto=format&fit=crop&w=900&q=82','{"style":"bespoke"}'::jsonb),

('car_executive_compact','car','Executive Compact',1,'A premium daily driver suited to an early professional career.',28000,2,'common',2400,-1800,900,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"executive"}'::jsonb),
('car_performance_coupe','car','Performance Coupe',2,'A fast premium coupe that balances status with practical ownership.',65000,4,'uncommon',4800,-1500,800,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"sports_coupe"}'::jsonb),
('car_luxury_sedan','car','Luxury Touring Sedan',2,'A full-size luxury sedan for comfortable travel between events.',110000,5,'uncommon',7500,-1300,750,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"luxury_sedan"}'::jsonb),
('car_sports_roadster','car','Sports Roadster',3,'A focused two-seat sports car with strong lifestyle appeal.',180000,7,'rare',12000,-1200,700,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"sports_car"}'::jsonb),
('car_supercar','car','Mid-Engine Supercar',3,'A dramatic supercar for established stars.',420000,11,'rare',28000,-1000,650,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"supercar"}'::jsonb),
('car_flagship_gt','car','Flagship Grand Tourer',4,'An elite grand tourer combining luxury, speed and exclusivity.',650000,13,'very_rare',42000,-800,550,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"grand_tourer"}'::jsonb),
('car_classic_collector','car','Classic Collector Coupe',4,'A rare analogue collector car that may appreciate instead of depreciating.',900000,15,'very_rare',55000,300,500,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"classic_collectible"}'::jsonb),
('car_hypercar','car','Limited-Series Hypercar',5,'A numbered hypercar produced in tiny quantities for the ultra-wealthy.',2200000,22,'legendary',130000,-600,450,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82','{"class":"hypercar"}'::jsonb),

('apt_starter_city','apartment','City Base Apartment',1,'A compact city apartment that gives an early-career player a first property asset.',120000,3,'common',3000,150,500,'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=82','{"property_type":"apartment"}'::jsonb),
('apt_modern_residence','apartment','Modern City Residence',2,'A high-quality apartment in a strong international city market.',350000,6,'uncommon',8500,250,450,'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=82','{"property_type":"apartment"}'::jsonb),
('apt_luxury_residence','apartment','Luxury City Residence',3,'A spacious luxury apartment with premium amenities.',800000,10,'rare',18000,300,400,'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=82','{"property_type":"luxury_apartment"}'::jsonb),
('apt_penthouse','apartment','Skyline Penthouse',4,'A prestigious penthouse with panoramic city views.',2500000,16,'very_rare',65000,400,350,'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=82','{"property_type":"penthouse"}'::jsonb),
('apt_trophy_residence','apartment','Trophy City Residence',5,'A landmark residence in one of the world’s most expensive city districts.',7500000,24,'legendary',190000,450,300,'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=900&q=82','{"property_type":"trophy_penthouse"}'::jsonb),

('home_family_house','house_villa','Private Family House',2,'A comfortable private home with more space and privacy than a city apartment.',250000,5,'common',6000,200,500,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82','{"property_type":"house"}'::jsonb),
('home_country_residence','house_villa','Country Residence',2,'A larger residence outside the city with strong long-term lifestyle value.',600000,8,'uncommon',15000,250,450,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82','{"property_type":"country_house"}'::jsonb),
('home_beach_villa','house_villa','Beach Villa',3,'A premium coastal villa for an established touring professional.',1500000,13,'rare',45000,350,400,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82','{"property_type":"beach_villa"}'::jsonb),
('home_mountain_chalet','house_villa','Mountain Residence',4,'A secluded high-end mountain residence built for privacy and recovery away from tour life.',2200000,15,'rare',65000,300,400,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82','{"property_type":"mountain_residence"}'::jsonb),
('home_grand_estate','house_villa','Grand Private Estate',4,'A substantial gated estate representing elite off-court success.',5000000,21,'very_rare',150000,400,350,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82','{"property_type":"estate"}'::jsonb),
('home_signature_mansion','house_villa','Signature Mansion',5,'An extraordinary trophy mansion for the richest champions in the game.',15000000,32,'legendary',450000,450,300,'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=82','{"property_type":"mansion"}'::jsonb),

('yacht_day_cruiser','yacht','Luxury Day Cruiser',3,'A compact luxury yacht with significant ownership costs despite its smaller size.',300000,9,'rare',30000,-1400,900,'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=900&q=82','{"yacht_class":"day_cruiser"}'::jsonb),
('yacht_motor','yacht','Luxury Motor Yacht',4,'A serious private motor yacht requiring crew, maintenance and marina spending.',1000000,15,'very_rare',100000,-1200,800,'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=900&q=82','{"yacht_class":"motor_yacht"}'::jsonb),
('yacht_explorer','yacht','Explorer Yacht',4,'A long-range luxury yacht designed for extended private travel.',3000000,21,'very_rare',300000,-1100,750,'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=900&q=82','{"yacht_class":"explorer"}'::jsonb),
('yacht_super','yacht','Superyacht',5,'A true superyacht with seven-figure yearly ownership costs.',10000000,30,'legendary',1000000,-1000,700,'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=900&q=82','{"yacht_class":"superyacht"}'::jsonb),
('yacht_flagship','yacht','Flagship Superyacht',5,'An enormous statement asset available only to the most successful tennis legends.',30000000,42,'legendary',3000000,-900,650,'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=900&q=82','{"yacht_class":"flagship_superyacht"}'::jsonb);

create or replace function public.private_life_market_value_v1(
  p_purchase_price bigint,
  p_annual_value_rate_bps integer,
  p_purchase_absolute_day integer,
  p_current_absolute_day integer
) returns bigint
language sql immutable
set search_path=public
as $$
  select greatest(
    1::bigint,
    round(
      p_purchase_price::numeric * greatest(
        0.15::numeric,
        1::numeric + (p_annual_value_rate_bps::numeric / 10000::numeric) * (greatest(0,p_current_absolute_day-p_purchase_absolute_day)::numeric / 366::numeric)
      )
    )::bigint
  );
$$;
revoke all on function public.private_life_market_value_v1(bigint,integer,integer,integer) from public,anon,authenticated;

create or replace function public.private_life_lifestyle_level_v1(p_player_id uuid)
returns smallint
language plpgsql security definer set search_path=public
as $$
declare v_earnings bigint;
begin
  select coalesce(sum(amount),0)::bigint into v_earnings
  from public.career_finance_transactions
  where player_id=p_player_id
    and amount>0
    and category not in ('career','private_life');
  return case
    when v_earnings >= 10000000 then 5
    when v_earnings >= 2000000 then 4
    when v_earnings >= 500000 then 3
    when v_earnings >= 100000 then 2
    else 1
  end;
end;
$$;
revoke all on function public.private_life_lifestyle_level_v1(uuid) from public,anon,authenticated;

create or replace function public.private_life_current_player_v1()
returns uuid
language plpgsql security definer set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_player uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(
    select 1 from public.premium_memberships pm
    where pm.user_id=v_uid
      and pm.plan_code='premium'
      and pm.status='active'
      and (pm.current_period_end is null or pm.current_period_end>now())
  ) then raise exception 'Premium membership required for Private Life.'; end if;
  select id into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human'
  order by created_at
  limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  return v_player;
end;
$$;
revoke all on function public.private_life_current_player_v1() from public,anon,authenticated;

create or replace function public.get_private_life_dashboard_v1()
returns jsonb
language plpgsql security definer set search_path=public
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
      (c.tier<=v_level) as unlocked,
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
$$;
revoke all on function public.get_private_life_dashboard_v1() from public,anon;
grant execute on function public.get_private_life_dashboard_v1() to authenticated;

create or replace function public.buy_private_life_asset_v1(p_catalog_code text)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_player uuid;
  v_asset public.private_life_asset_catalog%rowtype;
  v_owned_id uuid:=gen_random_uuid();
  v_abs integer;
  gd record;
  v_level smallint;
  v_fin jsonb;
  v_tx uuid;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_asset from public.private_life_asset_catalog where code=p_catalog_code and active=true;
  if v_asset.code is null then raise exception 'Lifestyle asset not found.'; end if;
  v_level:=public.private_life_lifestyle_level_v1(v_player);
  if v_asset.tier>v_level then raise exception 'Lifestyle level % required. Your current level is %.',v_asset.tier,v_level; end if;
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
$$;
revoke all on function public.buy_private_life_asset_v1(text) from public,anon;
grant execute on function public.buy_private_life_asset_v1(text) to authenticated;

create or replace function public.sell_private_life_asset_v1(p_owned_asset_id uuid)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_player uuid;
  v_owned public.private_life_player_assets%rowtype;
  v_asset public.private_life_asset_catalog%rowtype;
  v_abs integer;
  gd record;
  v_market bigint;
  v_sale bigint;
  v_fin jsonb;
  v_tx uuid;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_owned
  from public.private_life_player_assets
  where id=p_owned_asset_id and player_id=v_player and sold_absolute_day is null
  for update;
  if v_owned.id is null then raise exception 'Owned lifestyle asset not found.'; end if;
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_market:=public.private_life_market_value_v1(v_owned.purchase_price,v_asset.annual_value_rate_bps,v_owned.purchase_absolute_day,v_abs);
  v_sale:=round(v_market::numeric*(10000-v_asset.resale_discount_bps)::numeric/10000)::bigint;
  v_sale:=greatest(1,v_sale);

  v_fin:=public.post_career_finance_transaction_v1(
    v_player,
    v_sale,
    'private_life',
    'sale_'||v_asset.category,
    'Private Life sale: '||v_asset.name,
    'private_life_asset',
    v_owned.id::text,
    'private-life-sale:'||v_owned.id::text,
    jsonb_build_object('catalog_code',v_asset.code,'category',v_asset.category,'purchase_price',v_owned.purchase_price,'market_value',v_market,'sale_price',v_sale,'gain_loss',v_sale-v_owned.purchase_price),
    false,
    v_abs
  );
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets
  set sold_absolute_day=v_abs,sold_price=v_sale,sale_transaction_id=v_tx,updated_at=now()
  where id=v_owned.id;

  return jsonb_build_object('status','sold','owned_asset_id',v_owned.id,'name',v_asset.name,'market_value',v_market,'sale_price',v_sale,'gain_loss',v_sale-v_owned.purchase_price,'balance',v_fin->'balance');
end;
$$;
revoke all on function public.sell_private_life_asset_v1(uuid) from public,anon;
grant execute on function public.sell_private_life_asset_v1(uuid) to authenticated;
