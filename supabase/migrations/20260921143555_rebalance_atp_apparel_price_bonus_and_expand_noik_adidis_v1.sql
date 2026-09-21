
-- Expand the two dominant ATP apparel brands so they are the most common
-- clothing brands in the market, then rebalance all active apparel pricing
-- and gameplay modifiers by brand prestige and product position.

with new_models(sku,brand,model,template_sku,sort_order) as (
  values
    ('APP-NOIK-05','Noik','Rally Pro 2','APP-NOIK-01',5105),
    ('APP-NOIK-06','Noik','Advantage 7','APP-NOIK-02',5106),
    ('APP-NOIK-07','Noik','Elite Motion X','APP-NOIK-03',5107),
    ('APP-NOIK-08','Noik','Premier Match 9','APP-NOIK-04',5108),
    ('APP-NOIK-09','Noik','Slam Pro Elite','APP-NOIK-01',5109),
    ('APP-NOIK-10','Noik','Tour Signature X','APP-NOIK-03',5110),
    ('APP-ADIDIS-05','Adidis','Rally Control 2','APP-ADIDIS-01',5115),
    ('APP-ADIDIS-06','Adidis','ProMotion 7','APP-ADIDIS-02',5116),
    ('APP-ADIDIS-07','Adidis','Prime Flex X','APP-ADIDIS-03',5117),
    ('APP-ADIDIS-08','Adidis','Elite Match 9','APP-ADIDIS-04',5118),
    ('APP-ADIDIS-09','Adidis','Grand Slam Pro','APP-ADIDIS-01',5119),
    ('APP-ADIDIS-10','Adidis','Tour Signature X','APP-ADIDIS-03',5120)
)
insert into public.equipment_catalog_items(
  sku,item_type,brand,model,description,price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,is_active,image_url,tags,advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  availability_status,equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,tour_scope
)
select
  n.sku,
  t.item_type,
  n.brand,
  n.model,
  n.brand || ' ' || n.model || ' is an ATP performance clothing model with price-scaled match bonuses.',
  t.price_usd,
  t.tier,
  t.surface,
  t.power,
  t.control,
  t.spin,
  t.comfort,
  t.traction,
  t.stability,
  t.durability,
  n.sort_order,
  true,
  'data:image/svg+xml;base64,' ||
    replace(
      encode(
        convert_to(
          format(
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420"><rect width="600" height="420" fill="white"/><circle cx="492" cy="72" r="108" fill="%s" opacity=".08"/><g transform="translate(120 52)"><path d="M102 20 L160 20 L199 47 L252 83 L222 132 L187 113 L187 306 L75 306 L75 113 L40 132 L10 83 L63 47 Z" fill="%s"/><path d="M101 20 Q131 67 161 20" fill="white" opacity=".95"/><path d="M75 158 H187" stroke="%s" stroke-width="12" opacity=".85"/><path d="M92 65 H170" stroke="white" stroke-width="5" opacity=".6"/></g><text x="32" y="48" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#17344b">%s</text><text x="32" y="76" font-family="Arial,sans-serif" font-size="15" font-weight="700" fill="#708494">%s</text></svg>',
            case when n.brand='Noik' then '#57c3ff' else '#44c7b1' end,
            case when n.brand='Noik' then '#263a8b' else '#172f73' end,
            case when n.brand='Noik' then '#57c3ff' else '#44c7b1' end,
            n.brand,
            n.model
          ),
          'UTF8'
        ),
        'base64'
      ),
      E'\n',
      ''
    ),
  t.tags,
  t.advantages,
  t.disadvantages,
  t.maintenance_text,
  t.lifespan_text,
  t.effect_scope,
  'available',
  t.equip_slot,
  t.is_resellable,
  t.resale_modifier,
  t.technical_brand_id,
  t.product_profile,
  t.gameplay_effects,
  t.wear_per_match,
  t.wrong_surface_wear_multiplier,
  t.weather_profile,
  t.accessory_kind,
  t.estimated_uses,
  'ATP'
from new_models n
join public.equipment_catalog_items t
  on t.sku=n.template_sku
 and t.item_type='apparel'
on conflict (sku) do update
set brand=excluded.brand,
    model=excluded.model,
    description=excluded.description,
    sort_order=excluded.sort_order,
    is_active=true,
    availability_status='available',
    image_url=excluded.image_url,
    technical_brand_id=excluded.technical_brand_id,
    product_profile=excluded.product_profile,
    weather_profile=excluded.weather_profile,
    tour_scope='ATP';

with core(sku,model,sort_order) as (
  values
    ('APP-NOIK-01','Court Essential',5101),
    ('APP-NOIK-02','DriMotion 3',5102),
    ('APP-NOIK-03','Aero Flex 5',5103),
    ('APP-NOIK-04','Vapro Knit X',5104),
    ('APP-ADIDIS-01','Club Motion',5111),
    ('APP-ADIDIS-02','Aero Ready 3',5112),
    ('APP-ADIDIS-03','Match Flex 5',5113),
    ('APP-ADIDIS-04','CourtSpeed X',5114)
)
update public.equipment_catalog_items c
set model=core.model,
    sort_order=core.sort_order,
    description=c.brand || ' ' || core.model || ' is an ATP performance clothing model with price-scaled match bonuses.',
    tour_scope='ATP',
    is_active=true,
    availability_status='available',
    image_url=
      'data:image/svg+xml;base64,' ||
      replace(
        encode(
          convert_to(
            format(
              '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="420" viewBox="0 0 600 420"><rect width="600" height="420" fill="white"/><circle cx="492" cy="72" r="108" fill="%s" opacity=".08"/><g transform="translate(120 52)"><path d="M102 20 L160 20 L199 47 L252 83 L222 132 L187 113 L187 306 L75 306 L75 113 L40 132 L10 83 L63 47 Z" fill="%s"/><path d="M101 20 Q131 67 161 20" fill="white" opacity=".95"/><path d="M75 158 H187" stroke="%s" stroke-width="12" opacity=".85"/><path d="M92 65 H170" stroke="white" stroke-width="5" opacity=".6"/></g><text x="32" y="48" font-family="Arial,sans-serif" font-size="24" font-weight="900" fill="#17344b">%s</text><text x="32" y="76" font-family="Arial,sans-serif" font-size="15" font-weight="700" fill="#708494">%s</text></svg>',
              case when c.brand='Noik' then '#57c3ff' else '#44c7b1' end,
              case when c.brand='Noik' then '#263a8b' else '#172f73' end,
              case when c.brand='Noik' then '#57c3ff' else '#44c7b1' end,
              c.brand,
              core.model
            ),
            'UTF8'
          ),
          'base64'
        ),
        E'\n',
        ''
      )
from core
where c.sku=core.sku
  and c.item_type='apparel';

with ranked as (
  select
    c.id,
    c.brand,
    c.product_profile,
    b.prestige,
    row_number() over(partition by c.brand order by c.sort_order,c.sku)::int as rn,
    count(*) over(partition by c.brand)::int as cnt
  from public.equipment_catalog_items c
  left join public.technical_sponsor_brands b on b.id=c.technical_brand_id
  where c.item_type='apparel'
    and c.is_active
    and c.availability_status='available'
),
priced as (
  select
    r.*,
    case
      when r.brand='Noik' then
        (array[90,130,180,240,310,390,480,580,690,800])[least(r.rn,10)]
      when r.brand='Adidis' then
        (array[85,125,175,235,305,385,475,575,685,795])[least(r.rn,10)]
      when coalesce(r.prestige,0)>=80 then
        round(
          (300 + (coalesce(r.prestige,87)-87)*8)
          +
          (
            (620 + (coalesce(r.prestige,87)-87)*18)
            - (300 + (coalesce(r.prestige,87)-87)*8)
          ) * (r.rn-1)::numeric / greatest(r.cnt-1,1)
        )::int
      when coalesce(r.prestige,0)>=60 then
        round(
          (190 + (coalesce(r.prestige,70)-70)*4)
          +
          (
            (470 + (coalesce(r.prestige,70)-70)*10)
            - (190 + (coalesce(r.prestige,70)-70)*4)
          ) * (r.rn-1)::numeric / greatest(r.cnt-1,1)
        )::int
      when coalesce(r.prestige,0)>=40 then
        round(
          (125 + (coalesce(r.prestige,49)-49)*2)
          +
          (
            (300 + (coalesce(r.prestige,49)-49)*6)
            - (125 + (coalesce(r.prestige,49)-49)*2)
          ) * (r.rn-1)::numeric / greatest(r.cnt-1,1)
        )::int
      else
        round(
          (80 + greatest(coalesce(r.prestige,29)-29,0)*2)
          +
          (
            (190 + greatest(coalesce(r.prestige,29)-29,0)*5)
            - (80 + greatest(coalesce(r.prestige,29)-29,0)*2)
          ) * (r.rn-1)::numeric / greatest(r.cnt-1,1)
        )::int
    end as new_price
  from ranked r
),
scaled as (
  select
    p.*,
    least(2.00::numeric,
      greatest(0.18::numeric,
        0.18::numeric + (greatest(p.new_price,80)-80)::numeric / 720.0 * 1.82
      )
    ) as bonus_scale
  from priced p
)
update public.equipment_catalog_items c
set
  price_usd=s.new_price,
  tier=case
    when s.new_price < 130 then 1
    when s.new_price < 220 then 2
    when s.new_price < 350 then 3
    when s.new_price < 550 then 4
    else 5
  end,
  comfort=least(96,72 + (
    case
      when s.new_price < 130 then 1
      when s.new_price < 220 then 2
      when s.new_price < 350 then 3
      when s.new_price < 550 then 4
      else 5
    end
  )*4),
  durability=least(97,70 + (
    case
      when s.new_price < 130 then 1
      when s.new_price < 220 then 2
      when s.new_price < 350 then 3
      when s.new_price < 550 then 4
      else 5
    end
  )*5),
  gameplay_effects=case
    when s.product_profile='hot-weather' then jsonb_build_object(
      'heat_resistance_pct',round((s.bonus_scale*1.15)::numeric,2),
      'comfort_pct',round((s.bonus_scale*0.80)::numeric,2),
      'stamina_pct',round((s.bonus_scale*0.55)::numeric,2),
      'cold_resistance_pct',round((-least(0.35::numeric,s.bonus_scale*0.14))::numeric,2)
    )
    when s.product_profile='lightweight' then jsonb_build_object(
      'movement_pct',round((s.bonus_scale*1.00)::numeric,2),
      'comfort_pct',round((s.bonus_scale*0.75)::numeric,2),
      'stamina_pct',round((s.bonus_scale*0.60)::numeric,2)
    )
    when s.product_profile='cool-weather' then jsonb_build_object(
      'cold_resistance_pct',round((s.bonus_scale*1.15)::numeric,2),
      'comfort_pct',round((s.bonus_scale*0.80)::numeric,2),
      'heat_resistance_pct',round((-least(0.35::numeric,s.bonus_scale*0.12))::numeric,2)
    )
    else jsonb_build_object(
      'comfort_pct',round(s.bonus_scale::numeric,2),
      'focus_pct',round((s.bonus_scale*0.60)::numeric,2)
    )
  end,
  advantages=case
    when s.product_profile='hot-weather' then array['Heat-management fabric','Improves comfort and stamina in warm conditions']
    when s.product_profile='lightweight' then array['Lightweight movement profile','Improves movement, comfort and stamina']
    when s.product_profile='cool-weather' then array['Cold-weather protection','Improves comfort in cooler match conditions']
    else array['Balanced match comfort','Improves concentration during long matches']
  end,
  disadvantages=case
    when s.product_profile='hot-weather' then array['Small cold-weather trade-off']
    when s.product_profile='cool-weather' then array['Small hot-weather trade-off']
    else '{}'::text[]
  end,
  tags=(
    select array_agg(distinct tag)
    from unnest(
      coalesce(c.tags,'{}'::text[]) ||
      array[
        case
          when s.new_price>=550 then 'elite-performance'
          when s.new_price>=350 then 'premium-performance'
          when s.new_price>=220 then 'advanced-performance'
          when s.new_price>=130 then 'mid-range'
          else 'budget'
        end
      ]
    ) tag
  )
from scaled s
where c.id=s.id;
