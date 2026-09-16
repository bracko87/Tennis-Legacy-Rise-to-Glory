-- Second naming pass for racquets: use more realistic, brand-specific product naming.
-- Preserve the three approved Bablot models and all gameplay/pricing/sponsor data.

with rename(sku,new_model) as (
  values
    ('RKT-ANGEL-01','TC-100'),('RKT-ANGEL-02','TC-98 Tour'),('RKT-ANGEL-03','K8 Red'),('RKT-ANGEL-04','K8 Blue'),('RKT-ANGEL-05','ASX 95'),
    ('RKT-AXIOM-97','A97 Pro'),
    ('RKT-BABLOT-04','AeroRush 100'),('RKT-BABLOT-05','Pure Touch 98'),
    ('RKT-START-100','CF One'),
    ('RKT-DIADEMA-01','Nova 100'),('RKT-DIADEMA-02','Elevate 98'),('RKT-DIADEMA-03','Axis 100'),('RKT-DIADEMA-04','Nova Tour 95'),('RKT-DIADEMA-05','Icon 97'),
    ('RKT-DONNEI-01','Pro Uno 100'),('RKT-DONNEI-02','Formula Hexa'),('RKT-DONNEI-03','Allcourt 97'),('RKT-DONNEI-04','X-Dual 99'),('RKT-DONNEI-05','Penta Tour'),
    ('RKT-DUNLUP-01','CXD 200'),('RKT-DUNLUP-02','FXD 500'),('RKT-DUNLUP-03','SXD 300'),('RKT-DUNLUP-04','LX 1000'),('RKT-DUNLUP-05','CXD Tour 95'),
    ('RKT-FISCHAR-01','Vacuum Pro'),('RKT-FISCHAR-02','Magnetic Tour'),('RKT-FISCHAR-03','Pro No.2'),('RKT-FISCHAR-04','M-Comp 95'),('RKT-FISCHAR-05','Revolution 100'),
    ('RKT-GAMA-01','RZ-X 100'),('RKT-GAMA-02','Jet Pro 98'),('RKT-GAMA-03','Mirage 97'),('RKT-GAMA-04','Edge S'),('RKT-GAMA-05','Tour Elite'),
    ('RKT-HED-01','Velocity MP'),('RKT-HED-02','Gravita Pro'),('RKT-HED-03','Radix 98'),('RKT-HED-04','Booma 100'),('RKT-HED-05','Prime Tour 95'),
    ('RKT-KNEISL-01','Red Star'),('RKT-KNEISL-02','Black Star Pro'),('RKT-KNEISL-03','White Star 98'),('RKT-KNEISL-04','Aero Star'),('RKT-KNEISL-05','Master 10'),
    ('RKT-PACIFIK-01','X-Force'),('RKT-PACIFIK-02','X-Fast Pro'),('RKT-PACIFIK-03','BXT Tour'),('RKT-PACIFIK-04','X-Feel 97'),('RKT-PACIFIK-05','Nexus 100'),
    ('RKT-PRINC-01','Phantoma 100'),('RKT-PRINC-02','Warriar 98'),('RKT-PRINC-03','Beest 100'),('RKT-PRINC-04','Tour X 97'),('RKT-PRINC-05','Legacy 95'),
    ('RKT-PROKENEX-01','Ki QX 100'),('RKT-PROKENEX-02','Black Arc 98'),('RKT-PROKENEX-03','Kinetic Pro 97'),('RKT-PROKENEX-04','Q-Tour 100'),('RKT-PROKENEX-05','Ionic 95'),
    ('RKT-ROSIGNOL-01','F-200 Carbon'),('RKT-ROSIGNOL-02','F-250 Power'),('RKT-ROSIGNOL-03','F-300 Tour'),('RKT-ROSIGNOL-04','R-Spin 100'),('RKT-ROSIGNOL-05','Carbon Pro 95'),
    ('RKT-SLAZENGAR-01','Pro Braided'),('RKT-SLAZENGAR-02','Challenge X'),('RKT-SLAZENGAR-03','V-98'),('RKT-SLAZENGAR-04','Panther Tour'),('RKT-SLAZENGAR-05','AeroStrike 100'),
    ('RKT-SOLINKA-01','Whiteflash 100'),('RKT-SOLINKA-02','Blackstorm 98'),('RKT-SOLINKA-03','Hyper 97'),('RKT-SOLINKA-04','Tour X'),('RKT-SOLINKA-05','Outbreak 95'),
    ('RKT-SPALDIN-01','ATP Pro 100'),('RKT-SPALDIN-02','Assault 98'),('RKT-SPALDIN-03','Tour Comp 97'),('RKT-SPALDIN-04','Precision X'),('RKT-SPALDIN-05','Heritage 95'),
    ('RKT-SPIN-100','SA Tour'),
    ('RKT-TECNIFIBRA-01','T-Fuse 100'),('RKT-TECNIFIBRA-02','T-Combat 98'),('RKT-TECNIFIBRA-03','TF-41'),('RKT-TECNIFIBRA-04','Tempo X'),('RKT-TECNIFIBRA-05','X-One Tour'),
    ('RKT-VOLKEL-01','V-Cellar 100'),('RKT-VOLKEL-02','C11 Pro'),('RKT-VOLKEL-03','V2 Classic'),('RKT-VOLKEL-04','Power Bridge X'),('RKT-VOLKEL-05','V-Sense Tour'),
    ('RKT-VOLT-98','V98 Pro'),
    ('RKT-WILSAN-01','Blayd 98'),('RKT-WILSAN-02','Clashex 100'),('RKT-WILSAN-03','Ultron 100'),('RKT-WILSAN-04','Shifter 99'),('RKT-WILSAN-05','Pro Craft 97'),
    ('RKT-YONNEX-01','E-Zen 100'),('RKT-YONNEX-02','V-Kore 98'),('RKT-YONNEX-03','Percepta 97'),('RKT-YONNEX-04','Astral 100'),('RKT-YONNEX-05','Reigna 95')
), mapped as (
  select r.sku,r.new_model,e.brand,e.product_profile,e.image_url,e.technical_brand_id,b.primary_color,b.secondary_color,b.logo_variant
  from rename r
  join public.equipment_catalog_items e on e.sku=r.sku
  left join public.technical_sponsor_brands b on b.id=e.technical_brand_id
)
update public.equipment_catalog_items e
set model=m.new_model,
    description=e.brand||' '||m.new_model||' is '||case coalesce(e.product_profile,'standard')
      when 'balanced' then 'a versatile tour racquet designed for an even blend of pace, stability and feel.'
      when 'power' then 'a lively performance racquet tuned for easier depth, acceleration and first-strike tennis.'
      when 'control' then 'a controlled-response racquet built for directional accuracy, touch and confident ball placement.'
      when 'spin' then 'a fast-swinging racquet engineered for heavy rotation, shape and aggressive baseline patterns.'
      when 'precision' then 'a compact precision racquet aimed at clean contact, timing and exact shotmaking.'
      when 'starter' then 'an accessible all-round racquet designed for developing players and dependable match play.'
      else 'a performance racquet built for competitive all-court play.' end,
    image_url=case when e.image_url like 'data:image/svg+xml;base64,%' and m.technical_brand_id is not null
      then public.make_equipment_item_image_v1('racket',null,e.brand,m.new_model,m.primary_color,m.secondary_color,coalesce(m.logo_variant,1))
      else e.image_url end
from mapped m
where e.sku=m.sku;
