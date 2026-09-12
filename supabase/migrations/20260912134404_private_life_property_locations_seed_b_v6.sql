insert into public.private_life_property_locations
(code,country_code,country_name,city,apartment_base_price,house_base_price,annual_value_rate_bps,marketplace_enabled,active,sort_order)
values
('us_chicago','US','United States','Chicago',400000,1200000,200,true,true,26),
('ca_toronto','CA','Canada','Toronto',600000,1600000,250,true,true,27),
('ca_vancouver','CA','Canada','Vancouver',700000,1900000,250,true,true,28),
('mx_mexicocity','MX','Mexico','Mexico City',250000,700000,275,true,true,29),
('ar_buenosaires','AR','Argentina','Buenos Aires',180000,450000,250,true,true,30),
('br_rio','BR','Brazil','Rio de Janeiro',250000,700000,250,true,true,31),
('br_saopaulo','BR','Brazil','São Paulo',220000,650000,250,true,true,32),
('cl_santiago','CL','Chile','Santiago',230000,650000,250,true,true,33),
('za_capetown','ZA','South Africa','Cape Town',260000,700000,275,true,true,34),
('za_johannesburg','ZA','South Africa','Johannesburg',180000,500000,225,true,true,35),
('au_melbourne','AU','Australia','Melbourne',550000,1500000,250,true,true,36),
('au_sydney','AU','Australia','Sydney',700000,2000000,250,true,true,37),
('nz_auckland','NZ','New Zealand','Auckland',500000,1400000,225,true,true,38),
('jp_tokyo','JP','Japan','Tokyo',700000,1800000,225,true,true,39),
('jp_osaka','JP','Japan','Osaka',450000,1200000,225,true,true,40),
('kr_seoul','KR','South Korea','Seoul',550000,1500000,250,true,true,41),
('sg_singapore','SG','Singapore','Singapore',1000000,3000000,225,true,true,42),
('hk_hongkong','HK','Hong Kong','Hong Kong',1100000,3500000,200,true,true,43),
('cn_shanghai','CN','China','Shanghai',600000,1800000,250,true,true,44),
('cn_beijing','CN','China','Beijing',550000,1700000,225,true,true,45),
('th_bangkok','TH','Thailand','Bangkok',250000,750000,300,true,true,46),
('id_bali','ID','Indonesia','Bali',220000,650000,325,true,true,47),
('in_mumbai','IN','India','Mumbai',450000,1400000,275,true,true,48),
('in_delhi','IN','India','Delhi',350000,1100000,275,true,true,49),
('tr_istanbul','TR','Türkiye','Istanbul',250000,700000,275,true,true,50)
on conflict (code) do update set country_code=excluded.country_code,country_name=excluded.country_name,city=excluded.city,apartment_base_price=excluded.apartment_base_price,house_base_price=excluded.house_base_price,annual_value_rate_bps=excluded.annual_value_rate_bps,marketplace_enabled=excluded.marketplace_enabled,active=excluded.active,sort_order=excluded.sort_order,updated_at=now();