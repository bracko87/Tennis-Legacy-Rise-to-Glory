-- Expanded tennis bag catalogue with varied model naming and deliberately small
-- equipment-protection bonuses. Bags remain unisex accessories and do not grant
-- large direct match-stat boosts.

update public.equipment_catalog_items
set
  model = case sku
    when 'ACC-YONNEX-02' then 'Pro Tour 12'
    when 'ACC-SOLINKA-01' then 'Vantage 622 L'
    when 'ACC-CANCHA-01' then 'Arc Tour 622 L'
    when 'ACC-GEOSPORT-02' then 'Velocity Tour 880'
    when 'ACC-THORLA-01' then 'Velocity 44 L'
    else model
  end,
  description = case sku
    when 'ACC-YONNEX-02' then 'Yonnex Pro Tour 12 is a premium tennis bag with a small racket-protection benefit and long accessory life.'
    when 'ACC-SOLINKA-01' then 'Solinka Vantage 622 L is a tennis bag with a small racket-protection benefit and long accessory life.'
    when 'ACC-CANCHA-01' then 'Cancha Arc Tour 622 L is a tennis bag with a small racket-protection benefit and long accessory life.'
    when 'ACC-GEOSPORT-02' then 'Geo Sport Velocity Tour 880 is a tennis bag with a small racket-protection benefit and long accessory life.'
    when 'ACC-THORLA-01' then 'Thorla Velocity 44 L is a tennis bag with a small racket-protection benefit and long accessory life.'
    else description
  end,
  gameplay_effects = case sku
    when 'ACC-YONNEX-02' then '{"racket_wear_reduction_pct":2.0}'::jsonb
    when 'ACC-SOLINKA-01' then '{"racket_wear_reduction_pct":1.8}'::jsonb
    when 'ACC-CANCHA-01' then '{"racket_wear_reduction_pct":1.5}'::jsonb
    when 'ACC-GEOSPORT-02' then '{"racket_wear_reduction_pct":1.8}'::jsonb
    when 'ACC-THORLA-01' then '{"racket_wear_reduction_pct":1.5}'::jsonb
    else gameplay_effects
  end
where sku in (
  'ACC-YONNEX-02','ACC-SOLINKA-01','ACC-CANCHA-01','ACC-GEOSPORT-02','ACC-THORLA-01'
)
and item_type='accessory'
and accessory_kind='bag';

with bag_defs(
  sku,brand_code,brand,model,price_usd,tier,bonus_pct,durability,wear_per_match,estimated_uses,sort_order
) as (
  values
    ('ACC-BAG-BABLOT-01','BABLOT','Bablot','Aero Tour 12 AB',229,5,3.8,99,0.20,500,7801),
    ('ACC-BAG-BABLOT-02','BABLOT','Bablot','Pure Strike 1000',199,4,3.4,97,0.25,400,7802),
    ('ACC-BAG-BABLOT-03','BABLOT','Bablot','Clubline 622 L',149,3,2.4,94,0.30,333,7803),
    ('ACC-BAG-YONNEX-01','YONNEX','Yonnex','E-Zen 983',209,4,3.6,97,0.25,400,7811),
    ('ACC-BAG-YONNEX-02','YONNEX','Yonnex','Reigna 1000 Tour',239,5,4.0,99,0.20,500,7812),
    ('ACC-BAG-WILSAN-01','WILSAN','Wilsan','Super Tour 15',235,5,3.9,99,0.20,500,7821),
    ('ACC-BAG-WILSAN-02','WILSAN','Wilsan','Pro Staff 622 L',205,4,3.5,97,0.25,400,7822),
    ('ACC-BAG-WILSAN-03','WILSAN','Wilsan','BladeLine 1000',169,3,2.8,94,0.30,333,7823),
    ('ACC-BAG-HED-01','HED','Hed','Tour Team 12R',219,5,3.7,99,0.20,500,7831),
    ('ACC-BAG-HED-02','HED','Hed','Radical Pro 900',189,4,3.2,97,0.25,400,7832),
    ('ACC-BAG-HED-03','HED','Hed','Velocity 37 L',145,3,2.3,94,0.30,333,7833),
    ('ACC-BAG-TECNIFIBRA-01','TECNIFIBRA','Tecnifibra','Tour Endurance 12',199,4,3.4,97,0.25,400,7841),
    ('ACC-BAG-TECNIFIBRA-02','TECNIFIBRA','Tecnifibra','Tempo Rackpack 622',159,3,2.6,94,0.30,333,7842),
    ('ACC-BAG-DUNLUP-01','DUNLUP','Dunlup','CX Performance 12 AB',185,4,3.1,97,0.25,400,7851),
    ('ACC-BAG-DUNLUP-02','DUNLUP','Dunlup','FX Club 780',139,2,2.2,91,0.35,286,7852),
    ('ACC-BAG-PRINC-01','PRINC','Princ','Tour Evo 12',179,4,3.0,97,0.25,400,7861),
    ('ACC-BAG-PRINC-02','PRINC','Princ','Heritage 44 L',129,2,2.0,91,0.35,286,7862),
    ('ACC-BAG-SOLINKA-01','SOLINKA','Solinka','Hyper Tour 1000',169,3,2.8,94,0.30,333,7871),
    ('ACC-BAG-SOLINKA-02','SOLINKA','Solinka','Blackout 12 AB',149,3,2.4,94,0.30,333,7872),
    ('ACC-BAG-PROKENEX-01','PROKENEX','ProKenex','Q Tour 12',175,4,2.9,97,0.25,400,7881),
    ('ACC-BAG-PROKENEX-02','PROKENEX','ProKenex','Kinetic Pack 650',135,2,2.1,91,0.35,286,7882),
    ('ACC-BAG-VOLKEL-01','VOLKEL','Volkel','V-Cell Tour 9',165,3,2.7,94,0.30,333,7891),
    ('ACC-BAG-VOLKEL-02','VOLKEL','Volkel','Team Pro 622 L',125,2,1.9,91,0.35,286,7892),
    ('ACC-BAG-ANGEL-01','ANGEL','Angel','Halo Tour 12',159,3,2.6,94,0.30,333,7901),
    ('ACC-BAG-ANGEL-02','ANGEL','Angel','ProCarry 880',119,2,1.8,91,0.35,286,7902),
    ('ACC-BAG-KNEISL-01','KNEISL','Kneisl','Master Tour 9R',145,3,2.3,94,0.30,333,7911),
    ('ACC-BAG-DONNEI-01','DONNEI','Donnei','Pro One 12 AB',155,3,2.5,94,0.30,333,7921),
    ('ACC-BAG-DIADEMA-01','DIADEMA','Diadema','Nova Tour 10',149,3,2.4,94,0.30,333,7931),
    ('ACC-BAG-FISCHAR-01','FISCHAR','Fischar','Pro No.1 880',129,2,2.0,91,0.35,286,7941),
    ('ACC-BAG-SLAZENGAR-01','SLAZENGAR','Slazengar','Heritage Tour 12',125,2,1.9,91,0.35,286,7951),
    ('ACC-BAG-PACIFIK-01','PACIFIK','Pacifik','X-Tour 46 L',129,2,2.0,91,0.35,286,7961),
    ('ACC-BAG-GAMA-01','GAMA','Gama','Supreme Pack 622',109,2,1.7,91,0.35,286,7971),
    ('ACC-BAG-ROSIGNOL-01','ROSIGNOL','Rosignol','Courtline 1000',105,2,1.6,91,0.35,286,7981),
    ('ACC-BAG-SPALDIN-01','SPALDIN','Spaldin','ATP Pro 12 AB',99,1,1.5,88,0.40,250,7991)
),
resolved as (
  select b.*,ts.id technical_brand_id
  from bag_defs b
  join public.technical_sponsor_brands ts
    on ts.code=b.brand_code and ts.is_active=true
),
prepared as (
  select
    r.*,
    'data:image/svg+xml;base64,' ||
    encode(
      convert_to(
        '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420">' ||
        '<rect width="600" height="420" fill="white"/>' ||
        '<rect x="130" y="125" width="340" height="190" rx="50" fill="#254f68"/>' ||
        '<path d="M205 130 Q300 45 395 130" fill="none" stroke="#0b78c8" stroke-width="18"/>' ||
        '<path d="M300 125 V315" stroke="white" stroke-width="6" opacity=".45"/>' ||
        '<circle cx="300" cy="220" r="31" fill="#0b78c8"/>' ||
        '<text x="32" y="48" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#17344b">' ||
          replace(r.brand,'&','&amp;') ||
        '</text>' ||
        '<text x="32" y="78" font-family="Arial,sans-serif" font-size="16" font-weight="700" fill="#708494">' ||
          replace(r.model,'&','&amp;') ||
        '</text>' ||
        '</svg>',
        'UTF8'
      ),
      'base64'
    ) as image_url
  from resolved r
)
insert into public.equipment_catalog_items(
  sku,item_type,brand,model,description,price_usd,tier,
  surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,is_active,image_url,tags,advantages,disadvantages,
  maintenance_text,lifespan_text,effect_scope,availability_status,
  equip_slot,is_resellable,resale_modifier,technical_brand_id,
  product_profile,gameplay_effects,wear_per_match,
  wrong_surface_wear_multiplier,weather_profile,accessory_kind,
  estimated_uses,tour_scope
)
select
  sku,'accessory',brand,model,
  brand || ' ' || model || ' is a tennis bag with a small racket-protection benefit and long accessory life.',
  price_usd,tier,null,75,75,75,75+tier,75,75,durability,sort_order,true,image_url,
  array['accessory','bag','long-life'],
  array['Provides a small reduction in equipped-racquet wear','Long accessory lifespan'],
  array['Does not directly increase stroke power or skill','Higher-tier bags cost more for only a modest protection gain'],
  'Keep dry and inspect zips, handles and straps. Protection gradually falls with condition.',
  'Approximately ' || estimated_uses || ' match uses under normal conditions.',
  'match','available','accessory',true,0.58,technical_brand_id,'bag',
  jsonb_build_object('racket_wear_reduction_pct',bonus_pct),
  wear_per_match,1.00,'all','bag',estimated_uses,'unisex'
from prepared
on conflict(sku) do update set
  brand=excluded.brand,
  model=excluded.model,
  description=excluded.description,
  price_usd=excluded.price_usd,
  tier=excluded.tier,
  comfort=excluded.comfort,
  durability=excluded.durability,
  sort_order=excluded.sort_order,
  is_active=true,
  image_url=excluded.image_url,
  tags=excluded.tags,
  advantages=excluded.advantages,
  disadvantages=excluded.disadvantages,
  maintenance_text=excluded.maintenance_text,
  lifespan_text=excluded.lifespan_text,
  effect_scope=excluded.effect_scope,
  availability_status='available',
  equip_slot='accessory',
  is_resellable=true,
  resale_modifier=excluded.resale_modifier,
  technical_brand_id=excluded.technical_brand_id,
  product_profile='bag',
  gameplay_effects=excluded.gameplay_effects,
  wear_per_match=excluded.wear_per_match,
  wrong_surface_wear_multiplier=1.00,
  weather_profile='all',
  accessory_kind='bag',
  estimated_uses=excluded.estimated_uses,
  tour_scope='unisex';
