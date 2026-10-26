-- Catalog columns represented in the actual private-life catalog.
alter table public.private_life_asset_catalog add column description text default 'Existing private jet';
alter table public.private_life_asset_catalog add column updated_at timestamptz default now();
insert into public.private_life_asset_catalog(code,category,name,tier,metadata) values
 ('air_cessaro_citation_m3','private_jet','Citation M3',4,'{}'),
 ('air_emborgier_phenom_350e','private_jet','Phenom 350E',4,'{}'),
 ('air_bombara_challenger_420','private_jet','Challenger 420',4,'{}'),
 ('air_cessaro_citation_latitude_x','private_jet','Citation Latitude X',5,'{}'),
 ('air_emborgier_praetor_680','private_jet','Praetor 680',5,'{}'),
 ('air_dassier_falcon_9x','private_jet','Falcon 9X',6,'{}'),
 ('air_gulfstar_g650_lx','private_jet','G650 LX',6,'{}'),
 ('air_bombara_global_8000x','private_jet','Global 8000X',7,'{}'),
 ('air_gulfstar_g900_sovereign','private_jet','G900 Sovereign',8,'{}'),
 ('air_hondara_hj_one','private_jet','HJ-One',3,'{"propulsion":"jet"}'),
 ('jet_entry_turbofan','private_jet','Entry Light Jet',3,'{"tournament_travel_eligible":true}'),
 ('test_other_prop','private_jet','Hobby aircraft',2,'{"propulsion":"piston"}');
