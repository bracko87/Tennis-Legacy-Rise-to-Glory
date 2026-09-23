-- Rebalance bag prices and racket wear reduction values from the approved bag list.
with requested(brand,model,price_usd,wear_reduction) as (
  values
('Angel','ProCarry 880',180,2),
('Angel','Halo Tour 12',420,4.2),
('Bablot','Clubline 622 L',220,2.5),
('Bablot','Pure Strike 1000',520,4.8),
('Bablot','Aero Tour 12 AB',820,6.4),
('Cancha','Arc Tour 622 L',95,1.2),
('Diadema','Nova Tour 10',280,3),
('Donnei','Pro One 12 AB',310,3.2),
('Dunlup','FX Club 780',190,2.2),
('Dunlup','CX Performance 12 AB',520,4.8),
('Fischar','Pro No.1 880',165,1.9),
('Gama','Supreme Pack 622',105,1.3),
('Geo Sport','Velocity Tour 880',125,1.5),
('Hed','Velocity 37 L',240,2.7),
('Hed','Radical Pro 900',490,4.5),
('Hed','Tour Team 12R',790,6.2),
('Kneisl','Master Tour 9R',255,2.8),
('Pacifik','X-Tour 46 L',150,1.8),
('Princ','Heritage 44 L',160,1.9),
('Princ','Tour Evo 12',420,4.2),
('ProKenex','Kinetic Pack 650',180,2.1),
('ProKenex','Q Tour 12',410,4.1),
('Rosignol','Courtline 1000',90,1.1),
('Slazengar','Heritage Tour 12',140,1.7),
('Solinka','Vantage 622 L',125,1.5),
('Solinka','Blackout 12 AB',300,3.1),
('Solinka','Hyper Tour 1000',480,4.5),
('Spaldin','ATP Pro 12 AB',65,0.8),
('Tecnifibra','Tempo Rackpack 622',260,2.9),
('Tecnifibra','Tour Endurance 12',560,5),
('Thorla','Velocity 44 L',75,0.9),
('Volkel','Team Pro 622 L',145,1.7),
('Volkel','V-Cell Tour 9',350,3.6),
('Wilsan','BladeLine 1000',320,3.3),
('Wilsan','Pro Staff 622 L',540,4.9),
('Wilsan','Super Tour 15',850,6.5),
('Yonnex','Pro Tour 12',330,3.4),
('Yonnex','E-Zen 983',570,5.1),
('Yonnex','Reigna 1000 Tour',840,6.4)
)
update public.equipment_catalog_items c
set price_usd=r.price_usd,
    gameplay_effects=jsonb_set(
      coalesce(c.gameplay_effects,'{}'::jsonb),
      '{racket_wear_reduction_pct}',
      to_jsonb(r.wear_reduction),
      true
    )
from requested r
where c.brand=r.brand
  and c.model=r.model
  and c.item_type='accessory'
  and c.accessory_kind='bag'
  and c.is_active=true;
