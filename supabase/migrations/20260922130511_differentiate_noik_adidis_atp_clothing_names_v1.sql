
-- Differentiate Noik and Adidis ATP apparel naming while preserving all
-- existing image URLs, prices, sponsor links, bonuses, and SKUs.

with canonical(sku, model) as (
  values
    ('APP-NOIK-01','Baseline Core 24'),
    ('APP-NOIK-02','AeroDry 81'),
    ('APP-NOIK-03','SwiftKnit X4'),
    ('APP-NOIK-04','VaporForm 310'),
    ('APP-NOIK-05','AceRush 72'),
    ('APP-NOIK-06','EdgeSprint 505'),
    ('APP-NOIK-07','FlightCore X'),
    ('APP-NOIK-08','MatchLab 880'),
    ('APP-NOIK-09','SlamForce 11'),
    ('APP-NOIK-10','TourFlight 1200'),

    ('APP-ADIDIS-01','ClubLine 36'),
    ('APP-ADIDIS-02','AeroForm 260'),
    ('APP-ADIDIS-03','CourtWeave 7'),
    ('APP-ADIDIS-04','SpeedFrame X9'),
    ('APP-ADIDIS-05','ControlPoint 410'),
    ('APP-ADIDIS-06','ProCircuit 88'),
    ('APP-ADIDIS-07','PrimeGrid 640'),
    ('APP-ADIDIS-08','EliteForm 23'),
    ('APP-ADIDIS-09','MajorLine 900'),
    ('APP-ADIDIS-10','TourCode 1100')
)
update public.equipment_catalog_items c
set
  model = x.model,
  description = c.brand || ' ' || x.model || ' is an ATP performance clothing model with price-scaled match bonuses.'
from canonical x
where c.sku = x.sku
  and c.item_type = 'apparel'
  and c.is_active = true;
