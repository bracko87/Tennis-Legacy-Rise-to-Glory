-- Reduce active Private Life apartment catalog from 15 to 9 distinct types.
-- Retain a clear progression from starter flat to signature penthouse.
-- Removed types are deactivated (not deleted) to preserve any historical references.

update public.private_life_asset_catalog
set active=false, updated_at=now()
where category='apartment'
  and code in (
    'apt_city_studio',
    'apt_modern_two_bed',
    'apt_premium_residence',
    'apt_grand_penthouse',
    'apt_duplex_penthouse',
    'apt_trophy_sky'
  );

update public.private_life_asset_catalog c
set
  purchase_price = v.purchase_price,
  prestige = v.prestige,
  rarity = v.rarity,
  annual_running_cost = v.annual_running_cost,
  annual_value_rate_bps = v.annual_value_rate_bps,
  resale_discount_bps = v.resale_discount_bps,
  active = true,
  metadata = c.metadata
    || jsonb_build_object(
      'catalog_order', v.catalog_order,
      'price_multiplier_bps', v.price_multiplier_bps,
      'value_rate_adjustment_bps', v.value_rate_adjustment_bps
    ),
  updated_at = now()
from (
  values
    ('apt_starter_city',1,110000::bigint,1,'common',13200::bigint,150,1100,5500,0),
    ('apt_one_bedroom',2,160000::bigint,2,'common',19200::bigint,160,1050,8000,10),
    ('apt_modern_residence',3,220000::bigint,3,'uncommon',26400::bigint,175,1000,11000,25),
    ('apt_luxury_residence',4,300000::bigint,4,'uncommon',36000::bigint,200,950,15000,50),
    ('apt_executive',5,380000::bigint,5,'rare',45600::bigint,205,950,19000,60),
    ('apt_luxury_city',6,500000::bigint,7,'rare',60000::bigint,215,900,25000,70),
    ('apt_skyline',7,660000::bigint,9,'very_rare',79200::bigint,225,850,33000,85),
    ('apt_penthouse',8,900000::bigint,12,'very_rare',108000::bigint,235,800,45000,100),
    ('apt_trophy_residence',9,1300000::bigint,18,'legendary',156000::bigint,260,750,65000,125)
) as v(
  code,catalog_order,purchase_price,prestige,rarity,annual_running_cost,
  annual_value_rate_bps,resale_discount_bps,price_multiplier_bps,value_rate_adjustment_bps
)
where c.code=v.code
  and c.category='apartment';
