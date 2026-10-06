-- Calibrate city-level apartment base prices for the currently curated market
-- and the planned Standard City Apartment city set.
-- All apartment categories derive their listing price from:
-- city apartment_base_price × category price_multiplier_bps / 10000.
-- Standard City Apartment remains hidden until its image set is connected.

with price_seed(country_code,city,apartment_base_price) as (
  values
    ('MK','Skopje',90000),
    ('HU','Budapest',230000),
    ('CZ','Prague',330000),
    ('SE','Stockholm',500000),
    ('SE','Gothenburg',390000),
    ('NO','Oslo',550000),
    ('NO','Bergen',380000),
    ('FI','Helsinki',420000),
    ('IS','Reykjavik',560000),
    ('IE','Dublin',550000),
    ('GB','Edinburgh',430000),
    ('BE','Brussels',340000),
    ('LU','Luxembourg',780000),
    ('NL','Rotterdam',390000),
    ('FR','Nice',520000),
    ('FR','Lyon',400000),
    ('FR','Bordeaux',360000),
    ('DE','Cologne',360000),
    ('DE','Frankfurt',430000),
    ('DE','Dusseldorf',420000),
    ('DE','Stuttgart',420000),
    ('AT','Salzburg',450000),
    ('CH','Basel',780000),
    ('CH','Lausanne',680000),
    ('KW','Kuwait City',320000),
    ('BH','Manama',260000),
    ('IL','Tel Aviv',620000),
    ('JP','Kyoto',360000),
    ('JP','Yokohama',470000),
    ('JP','Nagoya',340000),
    ('KR','Busan',320000),
    ('KR','Incheon',300000),
    ('TW','Taipei',520000),
    ('CN','Hangzhou',320000),
    ('MO','Macau',850000),
    ('US','Boston',650000),
    ('US','Washington',600000),
    ('US','Seattle',650000),
    ('US','Austin',450000),
    ('US','Dallas',390000),
    ('US','Houston',340000),
    ('US','Denver',480000),
    ('US','San Diego',700000),
    ('CA','Montreal',420000),
    ('MX','Cancun',280000),
    ('UY','Punta del Este',350000),
    ('AU','Brisbane',470000),
    ('AU','Perth',450000),
    ('AU','Gold Coast',520000),
    ('NZ','Queenstown',550000),
    ('AL','Tirana',105000),
    ('HR','Zagreb',190000),
    ('PL','Warsaw',250000),
    ('DK','Copenhagen',520000),
    ('PT','Porto',230000),
    ('ES','Valencia',250000),
    ('IT','Florence',330000),
    ('SA','Jeddah',260000),
    ('EG','Cairo',100000),
    ('KE','Nairobi',130000),
    ('NG','Lagos',170000),
    ('GE','Tbilisi',140000),
    ('MY','Kuala Lumpur',220000),
    ('VN','Ho Chi Minh City',180000),
    ('PH','Manila',200000),
    ('ID','Jakarta',190000)
)
update public.private_life_property_locations l
set apartment_base_price=p.apartment_base_price,
    updated_at=now()
from price_seed p
where upper(l.country_code)=p.country_code
  and lower(l.city)=lower(p.city)
  and l.active=true;

update public.private_life_asset_catalog
set metadata = metadata || jsonb_build_object(
      'pricing_model','city_base_x_category_multiplier_v1',
      'pricing_currency','USD',
      'pricing_reviewed_at','2026-10-06'
    ),
    updated_at=now()
where category='apartment'
  and active=true;

-- Preserve the planned 65-city Standard City Apartment set but keep it out of
-- the marketplace until city images are uploaded and connected.
update public.private_life_property_catalog_availability
set active=false,updated_at=now()
where catalog_code='apt_modern_residence';
