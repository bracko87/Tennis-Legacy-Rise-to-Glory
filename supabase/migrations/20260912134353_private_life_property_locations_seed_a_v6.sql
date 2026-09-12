insert into public.private_life_property_locations
(code,country_code,country_name,city,apartment_base_price,house_base_price,annual_value_rate_bps,marketplace_enabled,active,sort_order)
values
('rs_belgrade','RS','Serbia','Belgrade',120000,300000,250,true,true,1),
('gb_london','GB','United Kingdom','London',650000,1800000,275,true,true,2),
('fr_paris','FR','France','Paris',550000,1600000,250,true,true,3),
('mc_monaco','MC','Monaco','Monaco',2200000,8000000,200,true,true,4),
('es_madrid','ES','Spain','Madrid',320000,850000,275,true,true,5),
('es_barcelona','ES','Spain','Barcelona',350000,900000,275,true,true,6),
('it_rome','IT','Italy','Rome',300000,800000,225,true,true,7),
('it_milan','IT','Italy','Milan',450000,1100000,250,true,true,8),
('ch_geneva','CH','Switzerland','Geneva',750000,2000000,200,true,true,9),
('ch_zurich','CH','Switzerland','Zurich',800000,2200000,200,true,true,10),
('at_vienna','AT','Austria','Vienna',400000,1000000,250,true,true,11),
('de_berlin','DE','Germany','Berlin',380000,900000,225,true,true,12),
('de_hamburg','DE','Germany','Hamburg',420000,1000000,225,true,true,13),
('de_munich','DE','Germany','Munich',520000,1300000,225,true,true,14),
('nl_amsterdam','NL','Netherlands','Amsterdam',500000,1200000,250,true,true,15),
('pt_lisbon','PT','Portugal','Lisbon',300000,750000,300,true,true,16),
('gr_athens','GR','Greece','Athens',220000,600000,250,true,true,17),
('ae_dubai','AE','United Arab Emirates','Dubai',600000,1800000,325,true,true,18),
('qa_doha','QA','Qatar','Doha',450000,1200000,250,true,true,19),
('ae_abudhabi','AE','United Arab Emirates','Abu Dhabi',500000,1400000,250,true,true,20),
('sa_riyadh','SA','Saudi Arabia','Riyadh',350000,1000000,275,true,true,21),
('us_newyork','US','United States','New York',850000,2800000,250,true,true,22),
('us_miami','US','United States','Miami',650000,2000000,325,true,true,23),
('us_losangeles','US','United States','Los Angeles',800000,2600000,225,true,true,24),
('us_sanfrancisco','US','United States','San Francisco',900000,2700000,200,true,true,25)
on conflict (code) do update set country_code=excluded.country_code,country_name=excluded.country_name,city=excluded.city,apartment_base_price=excluded.apartment_base_price,house_base_price=excluded.house_base_price,annual_value_rate_bps=excluded.annual_value_rate_bps,marketplace_enabled=excluded.marketplace_enabled,active=excluded.active,sort_order=excluded.sort_order,updated_at=now();