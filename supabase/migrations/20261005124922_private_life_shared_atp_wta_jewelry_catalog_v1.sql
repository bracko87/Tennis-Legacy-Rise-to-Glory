
-- Replace the purchasable Private Life jewelry catalog with a shared ATP/WTA set.
-- Existing owned legacy jewelry is preserved: old catalog rows remain referenced but are no longer purchasable.

update public.private_life_asset_catalog
set active=false,
    updated_at=now()
where category='jewelry';

insert into public.private_life_asset_catalog
(code,category,name,tier,description,purchase_price,prestige,rarity,annual_running_cost,annual_value_rate_bps,resale_discount_bps,image_url,active,metadata)
values
('jewelry_tomas_savo_pure_silver_ring','jewelry','Tomas Savo Pure Silver Ring',1,'A polished silver ring inspired by contemporary premium jewellery, available to ATP and WTA players.',79,1,'common',0,-100,1600,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":79}'::jsonb),
('jewelry_tomas_savo_crystal_court_bracelet','jewelry','Tomas Savo Crystal Court Bracelet',1,'An accessible crystal-set court bracelet with a clean luxury look, available to ATP and WTA players.',109,1,'common',0,-75,1550,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":109}'::jsonb),
('jewelry_swarovika_luna_stud_earrings','jewelry','Swarovika Luna Stud Earrings',1,'Crystal stud earrings with a bright premium finish, available to ATP and WTA players.',119,1,'common',0,-75,1550,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"earrings","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":119}'::jsonb),
('jewelry_swarovika_matrix_court_bracelet','jewelry','Swarovika Matrix Court Bracelet',1,'A slim crystal tennis-style bracelet with a modern finish, available to ATP and WTA players.',189,1,'common',0,-50,1500,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":189}'::jsonb),
('jewelry_swarovika_luna_angelica_bracelet','jewelry','Swarovika Luna Angelica Bracelet',1,'A refined crystal bracelet designed as an entry luxury accessory, available to ATP and WTA players.',199,1,'common',0,-50,1500,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":199}'::jsonb),
('jewelry_tomas_savo_royal_pave_hoops','jewelry','Tomas Savo Royal Pave Hoops',1,'Pave-set hoop earrings with a polished premium appearance, available to ATP and WTA players.',229,1,'common',0,-25,1450,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"earrings","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":229}'::jsonb),
('jewelry_tomas_savo_golden_court_bracelet','jewelry','Tomas Savo Golden Court Bracelet',1,'A gold-tone court bracelet combining sporty and premium styling, available to ATP and WTA players.',329,2,'common',0,0,1400,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":329}'::jsonb),
('jewelry_guccio_interlock_silver_ring','jewelry','Guccio Interlock Silver Ring',1,'A bold interlocking silver ring inspired by Italian fashion jewellery, available to ATP and WTA players.',420,2,'common',0,0,1400,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":420}'::jsonb),
('jewelry_david_yorman_cable_classic_bracelet','jewelry','David Yorman Cable Classic Bracelet',1,'A sculpted cable bracelet with understated luxury styling, available to ATP and WTA players.',690,2,'common',0,25,1350,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":690}'::jsonb),
('jewelry_hermelle_h_click_enamel_bangle','jewelry','Hermelle H-Click Enamel Bangle',1,'A polished enamel bangle with a recognisable luxury silhouette, available to ATP and WTA players.',720,2,'uncommon',0,25,1350,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":720}'::jsonb),
('jewelry_guccio_icon_chain_necklace','jewelry','Guccio Icon Chain Necklace',1,'A fashion-house inspired chain necklace with strong visual presence, available to ATP and WTA players.',890,2,'uncommon',0,25,1300,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"necklace","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":890}'::jsonb),
('jewelry_tiffani_return_heart_pendant','jewelry','Tiffani & Co. Return Heart Pendant',2,'A polished heart pendant inspired by iconic New York luxury jewellery, available to ATP and WTA players.',1150,3,'uncommon',0,50,1250,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"necklace","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":1150}'::jsonb),
('jewelry_diora_wind_rose_bracelet','jewelry','Diora Wind Rose Bracelet',2,'A delicate rose-inspired luxury bracelet, available to ATP and WTA players.',1550,3,'uncommon',0,50,1200,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":1550}'::jsonb),
('jewelry_van_clief_sweet_fortune_bracelet','jewelry','Van Clief & Arpel Sweet Fortune Bracelet',2,'A delicate motif bracelet inspired by Parisian fine jewellery, available to ATP and WTA players.',1690,3,'uncommon',0,75,1200,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":1690}'::jsonb),
('jewelry_chopelle_ice_block_ring','jewelry','Chopelle Ice Block Ring',2,'A geometric precious-metal ring with a contemporary luxury look, available to ATP and WTA players.',1950,4,'uncommon',0,75,1150,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":1950}'::jsonb),
('jewelry_tiffani_t_line_gold_ring','jewelry','Tiffani & Co. T-Line Gold Ring',2,'A sculptural gold ring with clean metropolitan luxury styling, available to ATP and WTA players.',2250,4,'uncommon',0,75,1100,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":2250}'::jsonb),
('jewelry_messina_motion_one_diamond_bracelet','jewelry','Messina Motion One Diamond Bracelet',2,'A modern diamond bracelet built around a moving-stone visual motif, available to ATP and WTA players.',2550,4,'uncommon',0,100,1100,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":2550}'::jsonb),
('jewelry_van_clief_frivola_diamond_pendant','jewelry','Van Clief & Arpel Frivola Diamond Pendant',2,'A floral diamond pendant with refined high-jewellery styling, available to ATP and WTA players.',2650,4,'uncommon',0,100,1050,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"necklace","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":2650}'::jsonb),
('jewelry_bulvari_b_one_gold_ring','jewelry','Bulvari B-One Gold Ring',2,'A bold architectural gold ring inspired by Roman luxury design, available to ATP and WTA players.',2850,5,'rare',0,100,1050,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":2850}'::jsonb),
('jewelry_piagette_orbit_gold_ring','jewelry','Piagette Orbit Gold Ring',2,'A rotating-inspired gold ring with a playful luxury profile, available to ATP and WTA players.',3250,5,'rare',0,125,1000,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":3250}'::jsonb),
('jewelry_carthier_amour_chain_bracelet','jewelry','Carthier Amour Chain Bracelet',3,'A refined gold chain bracelet inspired by an iconic Parisian love collection, available to ATP and WTA players.',3450,5,'rare',0,125,1000,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":3450}'::jsonb),
('jewelry_david_yorman_diamond_cable_pendant','jewelry','David Yorman Diamond Cable Pendant',3,'A diamond-set pendant combining cable texture with fine-jewellery finishing, available to ATP and WTA players.',3800,6,'rare',0,125,950,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"necklace","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":3800}'::jsonb),
('jewelry_boucherin_serpent_belle_necklace','jewelry','Boucherin Serpent Belle Necklace',3,'A serpent-inspired fine-jewellery necklace with a distinctive luxury identity, available to ATP and WTA players.',4750,6,'rare',0,150,900,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"necklace","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":4750}'::jsonb),
('jewelry_van_clief_vintage_fortune_bracelet','jewelry','Van Clief & Arpel Vintage Fortune Bracelet',3,'A multi-motif gold bracelet inspired by classic Parisian high jewellery, available to ATP and WTA players.',5450,7,'rare',0,150,900,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":5450}'::jsonb),
('jewelry_boucherin_four_classic_gold_ring','jewelry','Boucherin Four Classic Gold Ring',3,'A layered multi-texture gold ring with strong luxury-house character, available to ATP and WTA players.',5900,7,'rare',0,150,850,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"ring","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":5900}'::jsonb),
('jewelry_carthier_amour_classic_bracelet','jewelry','Carthier Amour Classic Bracelet',4,'A solid precious-metal statement bracelet inspired by an iconic luxury design, available to ATP and WTA players.',8100,9,'very_rare',0,175,800,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":8100}'::jsonb),
('jewelry_bulvari_serpentina_gold_bracelet','jewelry','Bulvari Serpentina Gold Bracelet',4,'A sculptural serpent-inspired gold bracelet with elite event prestige, available to ATP and WTA players.',9500,10,'very_rare',0,175,800,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":9500}'::jsonb),
('jewelry_van_clief_fortune_diamond_bracelet','jewelry','Van Clief & Arpel Fortune Diamond Bracelet',4,'A diamond-set motif bracelet at the upper end of the fine-jewellery range, available to ATP and WTA players.',17500,12,'very_rare',0,200,750,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":17500}'::jsonb),
('jewelry_henry_winstone_royal_cluster_diamond_earrings','jewelry','Henry Winstone Royal Cluster Diamond Earrings',5,'A high-jewellery diamond cluster pair with major red-carpet prestige, available to ATP and WTA players.',19500,14,'legendary',0,225,700,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"earrings","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":19500}'::jsonb),
('jewelry_graffe_riviera_diamond_tennis_bracelet','jewelry','Graffe Riviera Diamond Tennis Bracelet',5,'An elite diamond tennis bracelet inspired by top-tier high jewellery, available to ATP and WTA players.',34500,18,'legendary',0,250,650,'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?auto=format&fit=crop&w=1200&q=80',true,'{"brand_fictional":true,"tour_scope":"both","available_to":["ATP","WTA"],"jewelry_type":"bracelet","image_status":"placeholder","image_storage_folder":"Private Life/Jewelry","base_market_price":34500}'::jsonb)
on conflict (code) do update set
  category=excluded.category,
  name=excluded.name,
  tier=excluded.tier,
  description=excluded.description,
  purchase_price=excluded.purchase_price,
  prestige=excluded.prestige,
  rarity=excluded.rarity,
  annual_running_cost=excluded.annual_running_cost,
  annual_value_rate_bps=excluded.annual_value_rate_bps,
  resale_discount_bps=excluded.resale_discount_bps,
  image_url=excluded.image_url,
  active=true,
  metadata=excluded.metadata,
  updated_at=now();

do $$
declare
  v_active integer;
  v_shared integer;
  v_placeholder integer;
begin
  select count(*) into v_active
  from public.private_life_asset_catalog
  where category='jewelry' and active=true;

  select count(*) into v_shared
  from public.private_life_asset_catalog
  where category='jewelry'
    and active=true
    and metadata->>'tour_scope'='both'
    and metadata->'available_to' @> '["ATP","WTA"]'::jsonb;

  select count(*) into v_placeholder
  from public.private_life_asset_catalog
  where category='jewelry'
    and active=true
    and metadata->>'image_status'='placeholder';

  if v_active<>30 then
    raise exception 'Expected 30 active jewelry items, found %.',v_active;
  end if;
  if v_shared<>30 then
    raise exception 'Expected all 30 jewelry items to be shared by ATP and WTA, found %.',v_shared;
  end if;
  if v_placeholder<>30 then
    raise exception 'Expected 30 image-ready placeholder jewelry rows, found %.',v_placeholder;
  end if;
end;
$$;
