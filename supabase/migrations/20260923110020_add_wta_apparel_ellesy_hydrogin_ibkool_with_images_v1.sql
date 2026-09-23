-- Add WTA apparel for Ellesy, Hydrogin, and IBKool.
-- Clone balance/economics from corresponding ATP brand templates while
-- keeping separate WTA SKUs, model names, images, and tour scope.

with supplied(sku, brand, model, source_sku, sort_order, image_url) as (
  values
    ('APP-WTA-ELLESY-01','Ellesy','Heritage Muse 61','APP-ELLESY-01',7211,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Ellesy%20-%20Heritage%20Muse%2061.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0VsbGVzeSAtIEhlcml0YWdlIE11c2UgNjEucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDgxNCwiZXhwIjo0OTEyMjI0ODE0fQ.5B-hIXpPKtdOeBbrID4e2FRxThxw10ZHKHaMBrEb9jXoXXkWTGUUkiIRy9ECxwszIEit3JXe34sYz5lwWvEHgg'),
    ('APP-WTA-ELLESY-02','Ellesy','Tempo Silk','APP-ELLESY-02',7212,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Ellesy%20-%20Tempo%20Silk.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0VsbGVzeSAtIFRlbXBvIFNpbGsucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDgyMywiZXhwIjo0OTEyMjI0ODIzfQ.EvMM43cXx1ZINRpra4-bWqvUQLbGvs1wbeD-lkcmBriNH-SYEHxwJMjPYmT8Dc8sTsbjsW9O5O7qhVWUJghOAg'),
    ('APP-WTA-ELLESY-03','Ellesy','RallyForm X6','APP-ELLESY-03',7213,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Ellesy%20-%20Ellesy%20-%20RallyForm%20X6.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0VsbGVzeSAtIEVsbGVzeSAtIFJhbGx5Rm9ybSBYNi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwNzkxLCJleHAiOjQ5MTIyMjQ3OTF9.k_jR63DL-eiLM74vQpbjRbXQtuuGV1cchE4sDMQH0KF2_5zG4rcPzWVlFJKQDx9RLtE-SWuO7xFaNFa-IHyR4w'),
    ('APP-WTA-ELLESY-04','Ellesy','ELS 420','APP-ELLESY-04',7214,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Ellesy%20-%20ELS%20420.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0VsbGVzeSAtIEVMUyA0MjAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDgwNSwiZXhwIjo0OTEyMjI0ODA1fQ.G6QgsBplRtztGY8oK18_sJPZqH-YmMj95lO5HlARPyh4jT8DpH8LRtCDMyqJrxvzpv8DrFL5S6BC5uXu3WhGFA'),
    ('APP-WTA-ELLESY-05','Ellesy','Courtline 84','APP-ELLESY-05',7215,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Ellesy%20-%20Courtline%2084.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0VsbGVzeSAtIENvdXJ0bGluZSA4NC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwNzc4LCJleHAiOjQ5MTIyMjQ3Nzh9.anwCDR7sEw7KD14pTEqal6VRPwcLltyuNMbfdnUK7Wa7NDbqqEk8MYr-BsBiJcGfDxryXGtpo9L5giEmAMCf_g'),
    ('APP-WTA-ELLESY-06','Ellesy','Pace Aura 730','APP-ELLESY-06',7216,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Ellesy%20-%20Pace%20Aura%20730.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0VsbGVzeSAtIFBhY2UgQXVyYSA3MzAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDgzNCwiZXhwIjo0OTEyMjI0ODM0fQ.AQsjZ1EFjFEvBfeV7gkKPKm-PokYOwubnuzvnPo2Nmas3jhoHBwzY1Czt-ridNT9StIrbmUTA0XcXCTBjxauCQ'),

    ('APP-WTA-HYDROGIN-01','Hydrogin','Aqua Bloom','APP-HYDROGIN-01',7221,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20Aqua%20Bloom.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gQXF1YSBCbG9vbS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwODQ5LCJleHAiOjQ5MTIyMjQ4NDl9._prAyplDpVosxA3mM5YqMHrEHN4zl6sBBrExQjhVSbM4eolIbXMmeyumzxSqRxx9pGpbtZtIy4iPTZnFv8KzYQ'),
    ('APP-WTA-HYDROGIN-02','Hydrogin','Neon Flow 17','APP-HYDROGIN-02',7222,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20Neon%20Flow%2017.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gTmVvbiBGbG93IDE3LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxNjA4NjEsImV4cCI6NDkxMjIyNDg2MX0.jWZM-7Iya4tB5qlFfl_G8huNfQLfmltm8hWBPuFkZdU7wR1sFBpjpVpaEkN7iOMZnV63DlLE1uUhvJl2A2LQog'),
    ('APP-WTA-HYDROGIN-03','Hydrogin','Pulse Femme X','APP-HYDROGIN-03',7223,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20Pulse%20Femme%20X.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gUHVsc2UgRmVtbWUgWC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwODc0LCJleHAiOjQ5MTIyMjQ4NzR9.IgjHtFehJ_ZFod_oXOzJnGueiVlr0Apnj7jKGdh0F25d3rFoXcXU9rwiLz9GQydOMpI8oUj_d7ZRLYS9ERTOSg'),
    ('APP-WTA-HYDROGIN-04','Hydrogin','H2X 580','APP-HYDROGIN-04',7224,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20H2X%20580.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gSDJYIDU4MC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwODg1LCJleHAiOjQ5MTIyMjQ4ODV9.VXXKHkgcOnz2oG-ByQLGtwRCXcSgvWEp2i8U2x1GhhIm9yKkz_gm0H-E2fG3dkqUIHVhOP-lEnH0FUhJ45zkJg'),
    ('APP-WTA-HYDROGIN-05','Hydrogin','Velocity Azure','APP-HYDROGIN-05',7225,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20Velocity%20Azure.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gVmVsb2NpdHkgQXp1cmUucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDg5NSwiZXhwIjo0OTEyMjI0ODk1fQ.7f-QlftssS767EnvVFnC7V3YPv8irE101M2cWjiacFSSziikyWdPcdNqnM410uZrAzsMpTJZphRGKTDOunSi8g'),
    ('APP-WTA-HYDROGIN-06','Hydrogin','TechWave 26','APP-HYDROGIN-06',7226,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20TechWave%2026.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gVGVjaFdhdmUgMjYucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDkwNywiZXhwIjo0OTEyMjI0OTA3fQ.ytoEmWkSsZhdfdLhJn6kW2D_1eUVJn8KjdzCfxKeCKTh-v40sTZjZrtAYvqRLWvJIh_n_WwcpL9PBToU_zumvQ'),
    ('APP-WTA-HYDROGIN-07','Hydrogin','HyperSilk 910','APP-HYDROGIN-07',7227,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Hydrogin%20-%20HyperSilk%20910.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0h5ZHJvZ2luIC0gSHlwZXJTaWxrIDkxMC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwOTE4LCJleHAiOjQ5MTIyMjQ5MTh9.FfZlAFFw7OnPVbBYcp_lAL_AYkRiECBzh9J-7brQu02C-b4lD0yuaBwzDkCRfQqTYQ7roUyraq4uSrBJHJjQ1Q'),

    ('APP-WTA-IBKOOL-01','IBKool','ChillMuse','APP-IBKOOL-01',7231,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/IBKool%20-%20ChillMuse.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0lCS29vbCAtIENoaWxsTXVzZS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwOTM4LCJleHAiOjQ5MTIyMjQ5Mzh9.I7J2xfEaS_Ugwy0gBz2xtIGUt9Mxo7639HmePgFtxq8VyPCwP9tiCrXt89mceyJhjN2bKOVl74eWnBOqSEJLaw'),
    ('APP-WTA-IBKOOL-02','IBKool','IceFlow 23','APP-IBKOOL-02',7232,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/IBKool%20-%20IceFlow%2023.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0lCS29vbCAtIEljZUZsb3cgMjMucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDk0OCwiZXhwIjo0OTEyMjI0OTQ4fQ.yfQPmuKhJRpDXRRunZcMyOrLICdux8sEYsAKTKkmaJeK9qkXzS0SKJI8NvpKk07HfnCf-6JeVCEToMtj9RodxQ'),
    ('APP-WTA-IBKOOL-03','IBKool','BreezeLine X5','APP-IBKOOL-03',7233,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/IBKool%20-%20BreezeLine%20X5.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0lCS29vbCAtIEJyZWV6ZUxpbmUgWDUucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MDk2OCwiZXhwIjo0OTEyMjI0OTY4fQ.7SkFXSxGmegnsG7WUjCPaFzWURqtIX_GZQt6iqthWz6dFMFdy52-WBGUgBnZQWIHbPWbqhet6BdJJdlHhg11Bg'),
    ('APP-WTA-IBKOOL-04','IBKool','Fresh 440','APP-IBKOOL-04',7234,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/IBKool%20-%20Fresh%20440.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0lCS29vbCAtIEZyZXNoIDQ0MC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwOTgxLCJleHAiOjQ5MTIyMjQ5ODF9.lCgQO4PIb7k1JPJO8xT4SdMRGfyvb5Y2BhNkH_hrYaw0Vna-7CdMyS3cb-PBfLL6ZPU_uuM6n5AL5CsXVcoVOg'),
    ('APP-WTA-IBKOOL-05','IBKool','CoolStrike 8','APP-IBKOOL-05',7235,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/IBKool%20-%20CoolStrike%208.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0lCS29vbCAtIENvb2xTdHJpa2UgOC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYwOTkyLCJleHAiOjQ5MTIyMjQ5OTJ9.-aPCIaLAydpMATYIJpvM-UkuRkubHtpDMmc2vqmA22r96FsfuwdHOzmaiyDnR5RzwxJ3FASPLj6r6Ix2MroZZA'),
    ('APP-WTA-IBKOOL-06','IBKool','ZeroHeat 720','APP-IBKOOL-06',7236,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/IBKool%20-%20ZeroHeat%20720.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0lCS29vbCAtIFplcm9IZWF0IDcyMC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYxMDAyLCJleHAiOjQ5MTIyMjUwMDJ9.1Ly0FbW-ppLvmgC4g0WoFxOmYSTsBoUHhV_kTOlYGKPwHFfC5ya_A10ib4fJcG-oO7uTfYuxPnMaxwhvidnP0A')
),
src as (
  select
    s.*,
    c.item_type,c.surface,c.power,c.control,c.spin,c.comfort,c.traction,c.stability,c.durability,
    c.price_usd,c.tier,c.tags,c.advantages,c.disadvantages,c.maintenance_text,c.lifespan_text,
    c.effect_scope,c.equip_slot,c.is_resellable,c.resale_modifier,c.technical_brand_id,
    c.product_profile,c.gameplay_effects,c.wear_per_match,c.wrong_surface_wear_multiplier,
    c.weather_profile,c.accessory_kind,c.estimated_uses
  from supplied s
  join public.equipment_catalog_items c
    on c.sku=s.source_sku
   and c.item_type='apparel'
   and c.is_active=true
)
insert into public.equipment_catalog_items(
  sku,item_type,brand,model,description,price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,is_active,image_url,tags,advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  availability_status,equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,tour_scope
)
select
  sku,item_type,brand,model,
  brand || ' ' || model || ' is a WTA performance clothing model with price-scaled match bonuses.',
  price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,true,image_url,
  case
    when 'wta'=any(coalesce(tags,'{}'::text[])) then coalesce(tags,'{}'::text[])
    else coalesce(tags,'{}'::text[]) || array['wta']
  end,
  advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  'available',equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,'WTA'
from src
on conflict (sku) do update set
  brand=excluded.brand,
  model=excluded.model,
  description=excluded.description,
  price_usd=excluded.price_usd,
  tier=excluded.tier,
  surface=excluded.surface,
  power=excluded.power,
  control=excluded.control,
  spin=excluded.spin,
  comfort=excluded.comfort,
  traction=excluded.traction,
  stability=excluded.stability,
  durability=excluded.durability,
  sort_order=excluded.sort_order,
  is_active=true,
  image_url=excluded.image_url,
  tags=excluded.tags,
  advantages=excluded.advantages,
  disadvantages=excluded.disadvantages,
  maintenance_text=excluded.maintenance_text,
  lifespan_text=excluded.lifespan_text,
  effect_scope=excluded.effect_scope,
  availability_status='available',
  equip_slot=excluded.equip_slot,
  is_resellable=excluded.is_resellable,
  resale_modifier=excluded.resale_modifier,
  technical_brand_id=excluded.technical_brand_id,
  product_profile=excluded.product_profile,
  gameplay_effects=excluded.gameplay_effects,
  wear_per_match=excluded.wear_per_match,
  wrong_surface_wear_multiplier=excluded.wrong_surface_wear_multiplier,
  weather_profile=excluded.weather_profile,
  accessory_kind=excluded.accessory_kind,
  estimated_uses=excluded.estimated_uses,
  tour_scope='WTA';;
