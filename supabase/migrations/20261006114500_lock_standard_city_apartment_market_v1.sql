-- Lock the prepared Standard City Apartment market model.
-- The 65 destinations and their calibrated city base prices are implemented now,
-- but remain hidden (availability.active=false) until the image set is uploaded
-- and connected in a later migration.

create temporary table tmp_standard_city_apartment_seed(
  country_code text not null,
  city text not null,
  primary key(country_code,city)
) on commit drop;

insert into tmp_standard_city_apartment_seed(country_code,city)
values
    ('GB','London'),
    ('FR','Paris'),
    ('MC','Monaco'),
    ('AE','Dubai'),
    ('US','New York'),
    ('US','Miami'),
    ('US','Los Angeles'),
    ('US','San Francisco'),
    ('CA','Vancouver'),
    ('AU','Sydney'),
    ('JP','Tokyo'),
    ('JP','Osaka'),
    ('SG','Singapore'),
    ('HK','Hong Kong'),
    ('IN','Delhi'),
    ('MK','Skopje'),
    ('HU','Budapest'),
    ('CZ','Prague'),
    ('SE','Stockholm'),
    ('SE','Gothenburg'),
    ('NO','Oslo'),
    ('NO','Bergen'),
    ('FI','Helsinki'),
    ('IS','Reykjavik'),
    ('IE','Dublin'),
    ('GB','Edinburgh'),
    ('BE','Brussels'),
    ('LU','Luxembourg'),
    ('NL','Rotterdam'),
    ('FR','Nice'),
    ('FR','Lyon'),
    ('FR','Bordeaux'),
    ('DE','Cologne'),
    ('DE','Frankfurt'),
    ('DE','Dusseldorf'),
    ('DE','Stuttgart'),
    ('AT','Salzburg'),
    ('CH','Basel'),
    ('CH','Lausanne'),
    ('KW','Kuwait City'),
    ('BH','Manama'),
    ('IL','Tel Aviv'),
    ('JP','Kyoto'),
    ('JP','Yokohama'),
    ('JP','Nagoya'),
    ('KR','Busan'),
    ('KR','Incheon'),
    ('TW','Taipei'),
    ('CN','Hangzhou'),
    ('MO','Macau'),
    ('US','Boston'),
    ('US','Washington'),
    ('US','Seattle'),
    ('US','Austin'),
    ('US','Dallas'),
    ('US','Houston'),
    ('US','Denver'),
    ('US','San Diego'),
    ('CA','Montreal'),
    ('MX','Cancun'),
    ('UY','Punta del Este'),
    ('AU','Brisbane'),
    ('AU','Perth'),
    ('AU','Gold Coast'),
    ('NZ','Queenstown');

with resolved as (
  select distinct on (s.country_code,lower(s.city))
    l.code as location_code,
    s.country_code,
    s.city
  from tmp_standard_city_apartment_seed s
  join public.private_life_property_locations l
    on upper(l.country_code)=s.country_code
   and lower(l.city)=lower(s.city)
   and l.active=true
  order by s.country_code,lower(s.city),l.marketplace_enabled desc,l.sort_order,l.code
)
insert into public.private_life_property_catalog_availability(location_code,catalog_code,active)
select r.location_code,'apt_modern_residence',false
from resolved r
on conflict(location_code,catalog_code) do update set
  active=false,
  updated_at=now();

-- Remove any stray Standard City Apartment destinations outside the approved 65.
delete from public.private_life_property_catalog_availability a
where a.catalog_code='apt_modern_residence'
  and not exists (
    select 1
    from tmp_standard_city_apartment_seed s
    join public.private_life_property_locations l
      on upper(l.country_code)=s.country_code
     and lower(l.city)=lower(s.city)
     and l.active=true
    where l.code=a.location_code
  );

-- Record the prepared market model on the catalog entry.
update public.private_life_asset_catalog
set metadata = metadata || jsonb_build_object(
      'planned_city_count',65,
      'city_set_status','prepared_waiting_for_images',
      'city_set_version','standard_city_apartment_v1',
      'pricing_model','city_base_x_category_multiplier_v1',
      'pricing_currency','USD',
      'price_multiplier_bps',11000
    ),
    updated_at=now()
where code='apt_modern_residence'
  and category='apartment';
