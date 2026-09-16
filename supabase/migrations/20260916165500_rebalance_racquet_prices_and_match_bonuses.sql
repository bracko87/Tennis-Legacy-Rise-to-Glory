-- Rebalance all active sponsor-linked racquets so price and match value scale together.
-- Expensive racquets provide stronger, profile-specific bonuses; mid-budget models remain competitive.
-- These gameplay_effects are consumed by the existing match-setup engine and therefore apply
-- automatically when a player selects the racquet in Default Match Setup or a custom setup.

with base as (
  select
    e.id,
    e.sku,
    e.product_profile,
    b.tier as brand_tier,
    b.prestige,
    least(
      5,
      (case b.tier
        when 'entry' then 1
        when 'established' then 2
        when 'premium' then 3
        when 'elite' then 4
        else 1
      end)
      + case when right(e.sku, 2)::int >= 4 then 1 else 0 end
    )::smallint as g
  from public.equipment_catalog_items e
  join public.technical_sponsor_brands b on b.id = e.technical_brand_id
  where e.item_type = 'racket'
    and e.is_active
    and e.availability_status = 'available'
), calc as (
  select
    *,
    (
      case g
        when 1 then 155
        when 2 then 215
        when 3 then 300
        when 4 then 405
        else 525
      end
      + round((prestige - 60) * 0.6 / 5) * 5
      + case product_profile
          when 'balanced' then -10
          when 'power' then 5
          when 'control' then 10
          when 'spin' then 0
          when 'precision' then 15
          else 0
        end
    )::bigint as new_price,
    case g
      when 1 then 1.65
      when 2 then 1.50
      when 3 then 1.40
      when 4 then 1.30
      else 1.20
    end::numeric as new_wear
  from base
), vals as (
  select
    *,
    case product_profile
      when 'balanced' then jsonb_build_object(
        'power_pct', round((0.10 + 0.10 * g)::numeric, 2),
        'control_pct', round((0.10 + 0.10 * g)::numeric, 2),
        'spin_pct', round((0.08 + 0.09 * g)::numeric, 2),
        'serve_pct', round((0.06 + 0.06 * g)::numeric, 2),
        'return_pct', round((0.06 + 0.06 * g)::numeric, 2),
        'rally_pct', round((0.10 + 0.09 * g)::numeric, 2),
        'net_pct', round((0.04 + 0.04 * g)::numeric, 2),
        'forehand_pct', round((0.05 + 0.04 * g)::numeric, 2),
        'backhand_pct', round((0.05 + 0.04 * g)::numeric, 2)
      )
      when 'power' then jsonb_build_object(
        'power_pct', round((0.35 + 0.17 * g)::numeric, 2),
        'serve_pct', round((0.28 + 0.15 * g)::numeric, 2),
        'forehand_pct', round((0.18 + 0.10 * g)::numeric, 2),
        'rally_pct', round((0.12 + 0.07 * g)::numeric, 2),
        'return_pct', -0.04,
        'control_pct', -0.08
      )
      when 'control' then jsonb_build_object(
        'control_pct', round((0.35 + 0.17 * g)::numeric, 2),
        'return_pct', round((0.25 + 0.14 * g)::numeric, 2),
        'backhand_pct', round((0.16 + 0.09 * g)::numeric, 2),
        'rally_pct', round((0.12 + 0.07 * g)::numeric, 2),
        'net_pct', round((0.10 + 0.07 * g)::numeric, 2),
        'power_pct', -0.06
      )
      when 'spin' then jsonb_build_object(
        'spin_pct', round((0.40 + 0.18 * g)::numeric, 2),
        'rally_pct', round((0.22 + 0.13 * g)::numeric, 2),
        'forehand_pct', round((0.16 + 0.09 * g)::numeric, 2),
        'serve_pct', round((0.10 + 0.06 * g)::numeric, 2),
        'return_pct', round((0.08 + 0.05 * g)::numeric, 2),
        'comfort_pct', -0.05
      )
      when 'precision' then jsonb_build_object(
        'control_pct', round((0.32 + 0.15 * g)::numeric, 2),
        'return_pct', round((0.20 + 0.11 * g)::numeric, 2),
        'net_pct', round((0.18 + 0.10 * g)::numeric, 2),
        'backhand_pct', round((0.14 + 0.08 * g)::numeric, 2),
        'rally_pct', round((0.10 + 0.06 * g)::numeric, 2),
        'serve_pct', round((0.08 + 0.04 * g)::numeric, 2)
      )
      else '{}'::jsonb
    end as new_effects
  from calc
)
update public.equipment_catalog_items e
set
  price_usd = v.new_price,
  tier = v.g,
  wear_per_match = v.new_wear,
  estimated_uses = round(100.0 / v.new_wear)::smallint,
  gameplay_effects = v.new_effects,
  power = case v.product_profile
    when 'balanced' then 76 + 2 * v.g
    when 'power' then 80 + 3 * v.g
    when 'control' then 71 + v.g
    when 'spin' then 75 + 2 * v.g
    when 'precision' then 73 + v.g
    else e.power
  end,
  control = case v.product_profile
    when 'balanced' then 76 + 2 * v.g
    when 'power' then 71 + v.g
    when 'control' then 80 + 3 * v.g
    when 'spin' then 72 + v.g
    when 'precision' then 81 + 3 * v.g
    else e.control
  end,
  spin = case v.product_profile
    when 'balanced' then 75 + 2 * v.g
    when 'power' then 75 + 2 * v.g
    when 'control' then 73 + 2 * v.g
    when 'spin' then 80 + 3 * v.g
    when 'precision' then 74 + 2 * v.g
    else e.spin
  end,
  comfort = case v.product_profile
    when 'balanced' then 77 + 2 * v.g
    when 'power' then 73 + v.g
    when 'control' then 77 + 2 * v.g
    when 'spin' then 73 + v.g
    when 'precision' then 78 + 2 * v.g
    else e.comfort
  end
from vals v
where e.id = v.id;
