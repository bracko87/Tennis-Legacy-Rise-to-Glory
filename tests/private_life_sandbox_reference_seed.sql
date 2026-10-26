-- LOCAL PRIVATE LIFE SANDBOX REFERENCE FIXTURE ONLY.
-- Never deploy this file to production or add it to the normal migration chain.
-- These are game catalog reference rows, NOT copied player/account/payment data.
-- Kept deliberately small so a schema-only dump can exercise the marketplace.
-- Storage media and player accounts are NOT copied. Empty image_url is intentional.
-- All aircraft become transport-eligible only when the real jet migration runs.
INSERT INTO public.private_life_property_locations
(code,country_code,country_name,city,apartment_base_price,house_base_price)
VALUES
('rs_belgrade','RS','Serbia','Belgrade',124374,310933),
('fr_paris','FR','France','Paris',571620,1662893),
('gb_london','GB','United Kingdom','London',665347,1842500)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.private_life_asset_catalog
(code,category,name,tier,description,purchase_price,prestige,rarity,annual_running_cost,image_url,metadata)
VALUES
('watch_bravelle_coastline','watch','Citazen Tsuyara Automatic',1,'Local-only sandbox watch',475,1,'common',0,'','{}'::jsonb),
('car_bayside_micro','car','Fiato Cinquecento City',1,'Local-only sandbox car',6130,1,'common',1800,'','{}'::jsonb),
('home_standard_house','house_villa','Standard House',1,'Local-only sandbox residential property',186000,1,'common',22320,'','{"property_kind":"house_villa"}'::jsonb),
('air_cessaro_citation_m3','private_jet','Citation M3',4,'Local-only sandbox test aircraft',9049320,24,'rare',1050000,'','{"propulsion":"jet"}'::jsonb),
('air_emborgier_phenom_350e','private_jet','Phenom 350E',4,'Local-only sandbox test aircraft',11745775,28,'very_rare',1350000,'','{"propulsion":"jet"}'::jsonb),
('air_bombara_challenger_420','private_jet','Challenger 420',4,'Local-only sandbox test aircraft',17228935,33,'very_rare',1800000,'','{"propulsion":"jet"}'::jsonb),
('air_cessaro_citation_latitude_x','private_jet','Citation Latitude X',5,'Local-only sandbox test aircraft',22514653,38,'very_rare',2200000,'','{"propulsion":"jet"}'::jsonb),
('air_emborgier_praetor_680','private_jet','Praetor 680',5,'Local-only sandbox test aircraft',27236931,45,'very_rare',2800000,'','{"propulsion":"jet"}'::jsonb),
('air_dassier_falcon_9x','private_jet','Falcon 9X',6,'Local-only sandbox test aircraft',41591377,55,'legendary',4000000,'','{"propulsion":"jet"}'::jsonb),
('air_gulfstar_g650_lx','private_jet','G650 LX',6,'Local-only sandbox test aircraft',55593689,65,'legendary',5200000,'','{"propulsion":"jet"}'::jsonb),
('air_bombara_global_8000x','private_jet','Global 8000X',7,'Local-only sandbox test aircraft',71631071,75,'legendary',6500000,'','{"propulsion":"jet"}'::jsonb),
('air_gulfstar_g900_sovereign','private_jet','G900 Sovereign',8,'Local-only sandbox test aircraft',83030719,90,'legendary',8000000,'','{"propulsion":"jet"}'::jsonb),
('sandbox_hobby_propeller','private_jet','Sandbox Hobby Propeller',1,'Local-only negative transport test; lifestyle only',150000,1,'common',6000,'','{"propulsion":"piston"}'::jsonb)
ON CONFLICT (code) DO NOTHING;
