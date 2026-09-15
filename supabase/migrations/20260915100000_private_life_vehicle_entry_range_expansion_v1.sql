insert into public.private_life_asset_catalog(
  code, category, name, tier, description, purchase_price, prestige, rarity,
  annual_running_cost, annual_value_rate_bps, resale_discount_bps, image_url,
  active, metadata
) values
  ('car_bayside_micro','car','Bayside City Mini',1,'A simple second-hand city car for a player at the very start of a professional career.',5500,1,'common',1800,-2600,1600,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":5500,"vehicle_segment":"city_micro","market_band":"entry_used"}'::jsonb),
  ('car_novara_economy','car','Novara Economy Hatch',1,'An affordable used hatchback with low prestige but practical everyday running costs.',7000,1,'common',1800,-2500,1550,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":7000,"vehicle_segment":"economy_hatch","market_band":"entry_used"}'::jsonb),
  ('car_elmford_compact','car','Elmford Compact',1,'A dependable compact car that gives young touring players a realistic first-car option.',9000,1,'common',1800,-2400,1500,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":9000,"vehicle_segment":"compact","market_band":"entry_used"}'::jsonb),
  ('car_mareno_family_hatch','car','Mareno Family Hatch',1,'A roomy five-door hatchback balancing price, comfort and practical travel between tournaments.',11500,1,'common',1800,-2300,1450,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":11500,"vehicle_segment":"family_hatch","market_band":"entry"}'::jsonb),
  ('car_vale_touring_wagon','car','Vale Touring Wagon',1,'A practical touring wagon with extra luggage space for an improving professional player.',14000,1,'common',1800,-2200,1400,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":14000,"vehicle_segment":"wagon","market_band":"entry"}'::jsonb),
  ('car_astor_sedan','car','Astor Comfort Sedan',1,'A comfortable mid-size sedan for players ready to move beyond basic entry-level transport.',17000,2,'common',1800,-2100,1350,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":17000,"vehicle_segment":"sedan","market_band":"mainstream"}'::jsonb),
  ('car_corda_crossover','car','Corda Urban Crossover',1,'A modern compact crossover with useful space, everyday comfort and a little more status.',21000,2,'common',1800,-2000,1300,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":21000,"vehicle_segment":"compact_crossover","market_band":"mainstream"}'::jsonb),
  ('car_solara_hybrid','car','Solara Hybrid',1,'An efficient hybrid hatch-sedan aimed at players who want a newer car without entering the luxury market.',25000,2,'common',1800,-1850,1250,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":25000,"vehicle_segment":"hybrid","market_band":"mainstream"}'::jsonb),
  ('car_evermont_sport_compact','car','Evermont Sport Compact',1,'A sharper compact performance car with stronger prestige while remaining attainable early in a career.',30000,3,'uncommon',2160,-1750,1200,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":30000,"vehicle_segment":"sport_compact","market_band":"upper_mainstream"}'::jsonb),
  ('car_lucent_roadster','car','Lucent Entry Roadster',1,'An attainable two-seat roadster that introduces genuine lifestyle prestige before the premium sports-car tiers.',37000,3,'uncommon',2664,-1650,1150,'https://images.unsplash.com/photo-1503736334956-4c8f8e92946d?auto=format&fit=crop&w=900&q=82',true,'{"brand_fictional":true,"base_market_price":37000,"vehicle_segment":"roadster","market_band":"upper_mainstream"}'::jsonb)
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
  active=excluded.active,
  metadata=excluded.metadata,
  updated_at=now();

select public.process_private_life_asset_market_to_current_v1();