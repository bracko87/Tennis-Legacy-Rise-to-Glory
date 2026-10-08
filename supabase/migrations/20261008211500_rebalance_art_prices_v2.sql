-- Rebalance the 50-piece Art catalogue to a more player-friendly price curve.
-- Preserve artwork identities, images, prestige, rarity and ordering.

create temporary table tmp_art_price_rebalance_v2 (
  catalog_order integer primary key,
  new_price bigint not null
) on commit drop;

insert into tmp_art_price_rebalance_v2(catalog_order,new_price)
values
  (1, 10000::bigint),
  (2, 12500::bigint),
  (3, 15000::bigint),
  (4, 20000::bigint),
  (5, 25000::bigint),
  (6, 30000::bigint),
  (7, 40000::bigint),
  (8, 50000::bigint),
  (9, 65000::bigint),
  (10, 80000::bigint),
  (11, 100000::bigint),
  (12, 125000::bigint),
  (13, 150000::bigint),
  (14, 180000::bigint),
  (15, 220000::bigint),
  (16, 275000::bigint),
  (17, 325000::bigint),
  (18, 400000::bigint),
  (19, 500000::bigint),
  (20, 600000::bigint),
  (21, 725000::bigint),
  (22, 850000::bigint),
  (23, 1000000::bigint),
  (24, 1150000::bigint),
  (25, 1300000::bigint),
  (26, 1500000::bigint),
  (27, 1700000::bigint),
  (28, 1900000::bigint),
  (29, 2200000::bigint),
  (30, 2500000::bigint),
  (31, 2800000::bigint),
  (32, 3100000::bigint),
  (33, 3400000::bigint),
  (34, 3800000::bigint),
  (35, 4200000::bigint),
  (36, 4600000::bigint),
  (37, 5000000::bigint),
  (38, 5500000::bigint),
  (39, 6000000::bigint),
  (40, 6500000::bigint),
  (41, 7000000::bigint),
  (42, 7500000::bigint),
  (43, 8000000::bigint),
  (44, 8500000::bigint),
  (45, 9000000::bigint),
  (46, 9500000::bigint),
  (47, 10000000::bigint),
  (48, 10750000::bigint),
  (49, 11500000::bigint),
  (50, 12500000::bigint);

do $$
declare
  v_count integer;
  v_min bigint;
  v_max bigint;
  v_monotonic integer;
begin
  select count(*), min(new_price), max(new_price)
  into v_count,v_min,v_max
  from tmp_art_price_rebalance_v2;

  select count(*)
  into v_monotonic
  from (
    select new_price,
           lag(new_price) over(order by catalog_order) as prev_price
    from tmp_art_price_rebalance_v2
  ) x
  where prev_price is not null
    and new_price <= prev_price;

  if v_count <> 50 or v_min <> 10000 or v_max <> 12500000 or v_monotonic <> 0 then
    raise exception
      'Art price rebalance preflight failed: count %, min %, max %, nonmonotonic %.',
      v_count,v_min,v_max,v_monotonic;
  end if;
end;
$$;

update public.private_life_asset_catalog c
set purchase_price = p.new_price,
    annual_running_cost =
      round(
        p.new_price *
        case
          when p.catalog_order <= 10 then 0.008
          when p.catalog_order <= 25 then 0.010
          when p.catalog_order <= 40 then 0.011
          else 0.012
        end
      )::bigint,
    metadata = coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'base_market_price',p.new_price,
        'pricing_version','art_rebalance_v2',
        'price_status','rebalanced_player_friendly',
        'price_rebalanced_at','2026-10-08',
        'price_rebalance_reason','compress upper art market so artworks remain realistically purchasable'
      ),
    updated_at = now()
from tmp_art_price_rebalance_v2 p
where c.category='art'
  and c.active=true
  and (c.metadata->>'catalog_order')::integer=p.catalog_order;

do $$
declare
  v_active integer;
  v_exact integer;
  v_wrong integer;
  v_min bigint;
  v_max bigint;
  v_missing_images integer;
begin
  select count(*), min(purchase_price), max(purchase_price)
  into v_active,v_min,v_max
  from public.private_life_asset_catalog
  where category='art' and active=true;

  select count(*)
  into v_exact
  from public.private_life_asset_catalog c
  join tmp_art_price_rebalance_v2 p
    on (c.metadata->>'catalog_order')::integer=p.catalog_order
  where c.category='art'
    and c.active=true
    and c.purchase_price=p.new_price
    and (c.metadata->>'base_market_price')::bigint=p.new_price
    and c.metadata->>'pricing_version'='art_rebalance_v2';

  select count(*)
  into v_wrong
  from public.private_life_asset_catalog c
  join tmp_art_price_rebalance_v2 p
    on (c.metadata->>'catalog_order')::integer=p.catalog_order
  where c.category='art'
    and c.active=true
    and (
      c.purchase_price<>p.new_price
      or (c.metadata->>'base_market_price')::bigint<>p.new_price
    );

  select count(*)
  into v_missing_images
  from public.private_life_asset_catalog
  where category='art'
    and active=true
    and (
      metadata->>'image_status' <> 'curated'
      or image_url not like 'storage://Admin/PL Art/%'
    );

  if v_active<>50 or v_exact<>50 or v_wrong<>0 or v_min<>10000 or v_max<>12500000 or v_missing_images<>0 then
    raise exception
      'Art price rebalance validation failed: active %, exact %, wrong %, min %, max %, image issues %.',
      v_active,v_exact,v_wrong,v_min,v_max,v_missing_images;
  end if;
end;
$$;
