
-- Canonical ATP clothing names. Replace old generic model names in-place
-- and create the extra Hydrogin/Australien models so DB and UI use one
-- authoritative naming set.

with canonical(sku,brand,model,sort_order) as (
  values
    ('APP-AUSTRALIEN-01','Australien','Southern Cross',5049),
    ('APP-AUSTRALIEN-02','Australien','Outback Air',5050),
    ('APP-AUSTRALIEN-03','Australien','Coastal Flex',5051),
    ('APP-AUSTRALIEN-04','Australien','Melbourne 500',5052),

    ('APP-BJORNBORGA-01','Bjern Borga','Nordic Spin 77',5029),
    ('APP-BJORNBORGA-02','Bjern Borga','Stockholm Air 300',5030),
    ('APP-BJORNBORGA-03','Bjern Borga','Baseline Edge X',5031),
    ('APP-BJORNBORGA-04','Bjern Borga','Court Legend 5',5032),

    ('APP-BOSSO-01','Bosso','Tailor Court 55',5001),
    ('APP-BOSSO-02','Bosso','Aero Sartoria',5002),
    ('APP-BOSSO-03','Bosso','Match Form 808',5003),
    ('APP-BOSSO-04','Bosso','Prime Rally X',5004),

    ('APP-CASTORA-01','Castora','Apex Court 17',5021),
    ('APP-CASTORA-02','Castora','Velocity Grid 420',5022),
    ('APP-CASTORA-03','Castora','Flowstrike 9',5023),
    ('APP-CASTORA-04','Castora','Northline Elite',5024),

    ('APP-COURTCUTURE-01','Court Cuture','Vogue Rally 28',5017),
    ('APP-COURTCUTURE-02','Court Cuture','Aero Mode 600',5018),
    ('APP-COURTCUTURE-03','Court Cuture','Baseline Atelier',5019),
    ('APP-COURTCUTURE-04','Court Cuture','StyleFlex X7',5020),

    ('APP-HYDROGIN-01','Hydrogin','Hydro Flux',5045),
    ('APP-HYDROGIN-02','Hydrogin','Neon Aero',5046),
    ('APP-HYDROGIN-03','Hydrogin','Pulse XT',5047),
    ('APP-HYDROGIN-04','Hydrogin','H2X 700',5048),

    ('APP-LACOSTA-01','Lacosta','Courtline 72',5005),
    ('APP-LACOSTA-02','Lacosta','Aero Weave 318',5006),
    ('APP-LACOSTA-03','Lacosta','Croc Flex 9',5007),
    ('APP-LACOSTA-04','Lacosta','Match Elite 540',5008),

    ('APP-LECOQ-01','Le Coq Sportiv','Tricolore 68',5033),
    ('APP-LECOQ-02','Le Coq Sportiv','Aero Plume X',5034),
    ('APP-LECOQ-03','Le Coq Sportiv','Prestige Rally 420',5035),
    ('APP-LECOQ-04','Le Coq Sportiv','Court Heritage 88',5036),

    ('APP-LUCKI-01','Lucki In Love','Sunset Ace 7',5025),
    ('APP-LUCKI-02','Lucki In Love','Miami Bloom 360',5026),
    ('APP-LUCKI-03','Lucki In Love','Rally Muse X',5027),
    ('APP-LUCKI-04','Lucki In Love','Luxe Motion 95',5028),

    ('APP-TACHINI-01','Sergio Tachini','Roma 83',5041),
    ('APP-TACHINI-02','Sergio Tachini','Monte Carlo Air',5042),
    ('APP-TACHINI-03','Sergio Tachini','Archivio 500',5043),
    ('APP-TACHINI-04','Sergio Tachini','Veloce Knit 12',5044),

    ('APP-TRAVISMATIO-01','Travis Matio','Coastline 24',5037),
    ('APP-TRAVISMATIO-02','Travis Matio','Aero Riviera X',5038),
    ('APP-TRAVISMATIO-03','Travis Matio','Palm Drive 640',5039),
    ('APP-TRAVISMATIO-04','Travis Matio','Matchcraft 91',5040)
)
update public.equipment_catalog_items c
set
  model = x.model,
  description = x.brand || ' ' || x.model || ' is an ATP performance clothing model with price-scaled match bonuses.',
  sort_order = x.sort_order,
  tour_scope = 'ATP',
  image_url = case
    when c.image_url like 'data:image/svg+xml;base64,%' then
      'data:image/svg+xml;base64,' ||
      replace(
        encode(
          convert_to(
            format(
              '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420"><rect width="600" height="420" fill="white"/><circle cx="492" cy="72" r="108" fill="#57c3ff" opacity=".08"/><g transform="translate(120 52)"><path d="M102 20 L160 20 L199 47 L252 83 L222 132 L187 113 L187 306 L75 306 L75 113 L40 132 L10 83 L63 47 Z" fill="#263a8b"/><path d="M101 20 Q131 67 161 20" fill="white" opacity=".95"/><path d="M75 158 H187" stroke="#57c3ff" stroke-width="12" opacity=".85"/><path d="M92 65 H170" stroke="white" stroke-width="5" opacity=".6"/></g><text x="32" y="48" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#17344b">%s</text><text x="32" y="76" font-family="Arial,sans-serif" font-size="15" font-weight="700" fill="#708494">%s</text></svg>',
              x.brand,
              x.model
            ),
            'UTF8'
          ),
          'base64'
        ),
        E'\n',
        ''
      )
    else c.image_url
  end
from canonical x
where c.sku=x.sku
  and c.item_type='apparel';

-- Extra Australien model, cloned from its existing ATP clothing family.
with t as (
  select * from public.equipment_catalog_items
  where sku='APP-AUSTRALIEN-03' and item_type='apparel'
)
insert into public.equipment_catalog_items(
  sku,item_type,brand,model,description,price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,is_active,image_url,tags,advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  availability_status,equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,tour_scope
)
select
  'APP-AUSTRALIEN-05',item_type,brand,'AUS-X7',
  'Australien AUS-X7 is an ATP performance clothing model with price-scaled match bonuses.',
  395,4,surface,power,control,spin,88,traction,stability,90,
  5053,true,
  'data:image/svg+xml;base64,' ||
  replace(
    encode(
      convert_to(
        '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420"><rect width="600" height="420" fill="white"/><circle cx="492" cy="72" r="108" fill="#57c3ff" opacity=".08"/><g transform="translate(120 52)"><path d="M102 20 L160 20 L199 47 L252 83 L222 132 L187 113 L187 306 L75 306 L75 113 L40 132 L10 83 L63 47 Z" fill="#263a8b"/><path d="M101 20 Q131 67 161 20" fill="white" opacity=".95"/><path d="M75 158 H187" stroke="#57c3ff" stroke-width="12" opacity=".85"/><path d="M92 65 H170" stroke="white" stroke-width="5" opacity=".6"/></g><text x="32" y="48" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#17344b">Australien</text><text x="32" y="76" font-family="Arial,sans-serif" font-size="15" font-weight="700" fill="#708494">AUS-X7</text></svg>',
        'UTF8'
      ),
      'base64'
    ),
    E'\n',
    ''
  ),
  tags || array['advanced-performance'],advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  'available',equip_slot,is_resellable,resale_modifier,technical_brand_id,
  'lightweight',
  jsonb_build_object('movement_pct',0.97,'comfort_pct',0.73,'stamina_pct',0.58),
  wear_per_match,wrong_surface_wear_multiplier,'all',accessory_kind,estimated_uses,'ATP'
from t
on conflict (sku) do update set
  model='AUS-X7',
  description=excluded.description,
  price_usd=excluded.price_usd,
  tier=excluded.tier,
  comfort=excluded.comfort,
  durability=excluded.durability,
  sort_order=excluded.sort_order,
  is_active=true,
  availability_status='available',
  product_profile=excluded.product_profile,
  gameplay_effects=excluded.gameplay_effects,
  weather_profile=excluded.weather_profile,
  technical_brand_id=excluded.technical_brand_id,
  tour_scope='ATP';

-- Extra Hydrogin models, cloned from the existing Hydrogin family.
with extras(sku,model,template_sku,price_usd,tier,sort_order,profile,effects,weather) as (
  values
    ('APP-HYDROGIN-05','Velocity Noir','APP-HYDROGIN-01',540,4,5049,'balanced',
      '{"comfort_pct":1.06,"focus_pct":0.64}'::jsonb,'all'),
    ('APP-HYDROGIN-06','TechWave 11','APP-HYDROGIN-02',610,5,5050,'hot-weather',
      '{"heat_resistance_pct":1.75,"comfort_pct":1.22,"stamina_pct":0.84,"cold_resistance_pct":-0.21}'::jsonb,'hot'),
    ('APP-HYDROGIN-07','HyperFlow','APP-HYDROGIN-03',680,5,5051,'lightweight',
      '{"movement_pct":1.70,"comfort_pct":1.28,"stamina_pct":1.02}'::jsonb,'all')
)
insert into public.equipment_catalog_items(
  sku,item_type,brand,model,description,price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,is_active,image_url,tags,advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  availability_status,equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,tour_scope
)
select
  e.sku,t.item_type,t.brand,e.model,
  t.brand || ' ' || e.model || ' is an ATP performance clothing model with price-scaled match bonuses.',
  e.price_usd,e.tier,t.surface,t.power,t.control,t.spin,
  least(96,72+e.tier*4),t.traction,t.stability,least(97,70+e.tier*5),
  e.sort_order,true,
  'data:image/svg+xml;base64,' ||
  replace(
    encode(
      convert_to(
        format(
          '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420"><rect width="600" height="420" fill="white"/><circle cx="492" cy="72" r="108" fill="#57c3ff" opacity=".08"/><g transform="translate(120 52)"><path d="M102 20 L160 20 L199 47 L252 83 L222 132 L187 113 L187 306 L75 306 L75 113 L40 132 L10 83 L63 47 Z" fill="#263a8b"/><path d="M101 20 Q131 67 161 20" fill="white" opacity=".95"/><path d="M75 158 H187" stroke="#57c3ff" stroke-width="12" opacity=".85"/><path d="M92 65 H170" stroke="white" stroke-width="5" opacity=".6"/></g><text x="32" y="48" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#17344b">Hydrogin</text><text x="32" y="76" font-family="Arial,sans-serif" font-size="15" font-weight="700" fill="#708494">%s</text></svg>',
          e.model
        ),
        'UTF8'
      ),
      'base64'
    ),
    E'\n',
    ''
  ),
  t.tags ||
    array[case when e.price_usd>=550 then 'elite-performance' else 'premium-performance' end],
  t.advantages,t.disadvantages,t.maintenance_text,t.lifespan_text,t.effect_scope,
  'available',t.equip_slot,t.is_resellable,t.resale_modifier,t.technical_brand_id,
  e.profile,e.effects,t.wear_per_match,t.wrong_surface_wear_multiplier,e.weather,
  t.accessory_kind,t.estimated_uses,'ATP'
from extras e
join public.equipment_catalog_items t
  on t.sku=e.template_sku
 and t.item_type='apparel'
on conflict (sku) do update set
  model=excluded.model,
  description=excluded.description,
  price_usd=excluded.price_usd,
  tier=excluded.tier,
  comfort=excluded.comfort,
  durability=excluded.durability,
  sort_order=excluded.sort_order,
  is_active=true,
  availability_status='available',
  technical_brand_id=excluded.technical_brand_id,
  product_profile=excluded.product_profile,
  gameplay_effects=excluded.gameplay_effects,
  weather_profile=excluded.weather_profile,
  tour_scope='ATP';

-- Ensure Noik/Adidis are ATP-specific and canonical too.
update public.equipment_catalog_items
set tour_scope='ATP'
where item_type='apparel'
  and brand in ('Noik','Adidis')
  and is_active=true;

-- Safety: no old generic active names remain in the affected canonical brands.
update public.equipment_catalog_items
set is_active=false, availability_status='unavailable'
where item_type='apparel'
  and brand in (
    'Australien','Bjern Borga','Bosso','Castora','Court Cuture','Hydrogin',
    'Lacosta','Le Coq Sportiv','Lucki In Love','Sergio Tachini','Travis Matio'
  )
  and sku not in (
    'APP-AUSTRALIEN-01','APP-AUSTRALIEN-02','APP-AUSTRALIEN-03','APP-AUSTRALIEN-04','APP-AUSTRALIEN-05',
    'APP-BJORNBORGA-01','APP-BJORNBORGA-02','APP-BJORNBORGA-03','APP-BJORNBORGA-04',
    'APP-BOSSO-01','APP-BOSSO-02','APP-BOSSO-03','APP-BOSSO-04',
    'APP-CASTORA-01','APP-CASTORA-02','APP-CASTORA-03','APP-CASTORA-04',
    'APP-COURTCUTURE-01','APP-COURTCUTURE-02','APP-COURTCUTURE-03','APP-COURTCUTURE-04',
    'APP-HYDROGIN-01','APP-HYDROGIN-02','APP-HYDROGIN-03','APP-HYDROGIN-04','APP-HYDROGIN-05','APP-HYDROGIN-06','APP-HYDROGIN-07',
    'APP-LACOSTA-01','APP-LACOSTA-02','APP-LACOSTA-03','APP-LACOSTA-04',
    'APP-LECOQ-01','APP-LECOQ-02','APP-LECOQ-03','APP-LECOQ-04',
    'APP-LUCKI-01','APP-LUCKI-02','APP-LUCKI-03','APP-LUCKI-04',
    'APP-TACHINI-01','APP-TACHINI-02','APP-TACHINI-03','APP-TACHINI-04',
    'APP-TRAVISMATIO-01','APP-TRAVISMATIO-02','APP-TRAVISMATIO-03','APP-TRAVISMATIO-04'
  );
