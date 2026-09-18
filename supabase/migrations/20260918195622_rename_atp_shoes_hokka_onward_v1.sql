with renamed(sku,new_model) as (
  values
    ('SHO-HOKKA-01','Cliffton 10 Evo'),
    ('SHO-HOKKA-02','Bondy 9 Max'),
    ('SHO-HOKKA-03','Mach X6'),
    ('SHO-HOKKA-04','Kawana 2 Glide'),
    ('SHO-KSWIS-01','Express Light X'),
    ('SHO-KSWIS-02','UltraShot X4'),
    ('SHO-KSWIS-03','HyperExpress X3'),
    ('SHO-KSWIS-04','SpeedTrac Pro'),
    ('SHO-LININ-01','Red Hare 8'),
    ('SHO-LININ-02','Furious Rider 7'),
    ('SHO-LININ-03','Shadow 6 Pro'),
    ('SHO-LININ-04','Feidian 4 Elite'),
    ('SHO-NEWBALANS-01','796 X4'),
    ('SHO-NEWBALANS-02','FuelCell 996 X6'),
    ('SHO-NEWBALANS-03','Fresh Foam Lav X2'),
    ('SHO-NEWBALANS-04','Rally Pro 2'),
    ('SHO-PUMMA-01','SolarStrike 3'),
    ('SHO-PUMMA-02','Rider Nitro 2'),
    ('SHO-PUMMA-03','Accelerate Nitro 4'),
    ('SHO-PUMMA-04','Eliminate Nitro X'),
    ('SHO-MIZUNA-01','Break Shot X4'),
    ('SHO-MIZUNA-02','Wave Enforce Tour 2'),
    ('SHO-MIZUNA-03','Wave Exceed Tour X7'),
    ('SHO-MIZUNA-04','Wave Exceed Lite 3'),
    ('SHO-OLYMPIKOS-01','Corre 4'),
    ('SHO-OLYMPIKOS-02','Pride 4'),
    ('SHO-OLYMPIKOS-03','Voa 3'),
    ('SHO-OLYMPIKOS-04','Dynamic 2'),
    ('SHO-FILIA-01','SpeedServe X'),
    ('SHO-FILIA-02','Axilus X3 Energized'),
    ('SHO-FILIA-03','Volley Zone 2'),
    ('SHO-FILIA-04','SpeedServe Pro'),
    ('SHO-UNDERARMER-01','Charged Assert 11'),
    ('SHO-UNDERARMER-02','HOVR Infinite 6'),
    ('SHO-UNDERARMER-03','Flow Velociti 4'),
    ('SHO-UNDERARMER-04','Phantom 4'),
    ('SHO-DIADORO-01','Challenge X5'),
    ('SHO-DIADORO-02','B.Icon X3'),
    ('SHO-DIADORO-03','BlueShield Torneo X2'),
    ('SHO-DIADORO-04','Speed Comp X7'),
    ('SHO-REEBAK-01','Club C 2'),
    ('SHO-REEBAK-02','Nano X4'),
    ('SHO-REEBAK-03','Flexagon 4'),
    ('SHO-REEBAK-04','Speed TR 2'),
    ('SHO-SKECHORS-01','Viper Rally'),
    ('SHO-SKECHORS-02','Viper Pro 2'),
    ('SHO-SKECHORS-03','GO Arch Fit X'),
    ('SHO-SKECHORS-04','Viper Smash'),
    ('SHO-ANTTA-01','PG 7'),
    ('SHO-ANTTA-02','G21 Pro'),
    ('SHO-ANTTA-03','C202 6'),
    ('SHO-ANTTA-04','FlashEdge X'),
    ('SHO-BATHOO-01','SFX X4'),
    ('SHO-BATHOO-02','Jet Mach X3'),
    ('SHO-BATHOO-03','Movea 2'),
    ('SHO-BATHOO-04','ProPulse Fury X3'),
    ('SHO-LOTTA-01','Mirage 300 X'),
    ('SHO-LOTTA-02','Raptor HyperPulse 100'),
    ('SHO-LOTTA-03','Mirage 200'),
    ('SHO-LOTTA-04','Mirage Spin 2'),
    ('SHO-JOMAE-01','Master 1000 X'),
    ('SHO-JOMAE-02','Slam Pro 3'),
    ('SHO-JOMAE-03','Point 5'),
    ('SHO-JOMAE-04','Ace Pro 2')
)
update public.equipment_catalog_items c
set model=r.new_model
from renamed r
where c.sku=r.sku
  and c.item_type='shoes';

update public.equipment_catalog_items c
set image_url = public.make_equipment_item_image_v1(
  'shoes',null,c.brand,c.model,
  coalesce(b.primary_color,'#176da7'),
  coalesce(b.secondary_color,'#36b37e'),
  coalesce(b.logo_variant,1)
)
from public.technical_sponsor_brands b
where c.item_type='shoes'
  and c.technical_brand_id=b.id
  and c.sku in (
    'SHO-HOKKA-01','SHO-HOKKA-02','SHO-HOKKA-03','SHO-HOKKA-04',
    'SHO-KSWIS-01','SHO-KSWIS-02','SHO-KSWIS-03','SHO-KSWIS-04',
    'SHO-LININ-01','SHO-LININ-02','SHO-LININ-03','SHO-LININ-04',
    'SHO-NEWBALANS-01','SHO-NEWBALANS-02','SHO-NEWBALANS-03','SHO-NEWBALANS-04',
    'SHO-PUMMA-01','SHO-PUMMA-02','SHO-PUMMA-03','SHO-PUMMA-04',
    'SHO-MIZUNA-01','SHO-MIZUNA-02','SHO-MIZUNA-03','SHO-MIZUNA-04',
    'SHO-OLYMPIKOS-01','SHO-OLYMPIKOS-02','SHO-OLYMPIKOS-03','SHO-OLYMPIKOS-04',
    'SHO-FILIA-01','SHO-FILIA-02','SHO-FILIA-03','SHO-FILIA-04',
    'SHO-UNDERARMER-01','SHO-UNDERARMER-02','SHO-UNDERARMER-03','SHO-UNDERARMER-04',
    'SHO-DIADORO-01','SHO-DIADORO-02','SHO-DIADORO-03','SHO-DIADORO-04',
    'SHO-REEBAK-01','SHO-REEBAK-02','SHO-REEBAK-03','SHO-REEBAK-04',
    'SHO-SKECHORS-01','SHO-SKECHORS-02','SHO-SKECHORS-03','SHO-SKECHORS-04',
    'SHO-ANTTA-01','SHO-ANTTA-02','SHO-ANTTA-03','SHO-ANTTA-04',
    'SHO-BATHOO-01','SHO-BATHOO-02','SHO-BATHOO-03','SHO-BATHOO-04',
    'SHO-LOTTA-01','SHO-LOTTA-02','SHO-LOTTA-03','SHO-LOTTA-04',
    'SHO-JOMAE-01','SHO-JOMAE-02','SHO-JOMAE-03','SHO-JOMAE-04'
  )
  and c.image_url like 'data:image/svg+xml;base64,%';
