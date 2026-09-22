-- Add WTA apparel for BlokUV, Bosso, Castora, and Court Cuture.
-- Clone gameplay/economic balance from corresponding ATP brand templates
-- while using separate WTA SKUs, model names, images, and tour scope.

with supplied(sku, brand, model, source_sku, sort_order, image_url) as (
  values
    ('APP-WTA-BLOKUV-01','BlokUV','Solar Shield 8','APP-BLOKUV-01',7171,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/BlokUV%20-%20Solar%20Shield%208.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jsb2tVViAtIFNvbGFyIFNoaWVsZCA4LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE4MDUsImV4cCI6NDkxMjE2NTgwNX0.H1NP5sZvrJ2Mh5gsMWdLIoTQZCHAQM3_lM6mcHhHN4zKDNtDtfmwfUoVnEg64id12h4dtJU_EoZ57TeCq4W6cA'),
    ('APP-WTA-BLOKUV-02','BlokUV','SunMuse 210','APP-BLOKUV-02',7172,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/BlokUV%20-%20SunMuse%20210.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jsb2tVViAtIFN1bk11c2UgMjEwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE4MTcsImV4cCI6NDkxMjE2NTgxN30.YkcrxP__UleSCnxA3KFc6uUym-s5G4y5igfdD-whlMoD4wxybkPOJ_vjUuOvwZjz1oiURnWRWTcmuoONp2qvrQ'),
    ('APP-WTA-BLOKUV-03','BlokUV','UVFlow X4','APP-BLOKUV-03',7173,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/BlokUV%20-%20UVFlow%20X4.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jsb2tVViAtIFVWRmxvdyBYNC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAxODI5LCJleHAiOjQ5MTIxNjU4Mjl9._rndEqYM424kez4TOH8HyaZAHZhFACPb4YpIsgkMGZlLZD7vQJXI8C6tNH-p4lSlFqqbafYZhQE-ePQL6v0ybA'),
    ('APP-WTA-BLOKUV-04','BlokUV','Radiant 550','APP-BLOKUV-04',7174,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/BlokUV%20-%20Radiant%20550.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jsb2tVViAtIFJhZGlhbnQgNTUwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE4NDEsImV4cCI6NDU2NTI2OTg0MX0.kr4171A4T0yRvWQ98cRInuPLj1UWnVAkbvyVZZTLWyhc-a-cBwtCDuldOlljXpVXatdG1TcF4T3TkS8SlTTliA'),
    ('APP-WTA-BLOKUV-05','BlokUV','Shield 920','APP-BLOKUV-05',7175,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/BlokUV%20-%20Shield%20920.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jsb2tVViAtIFNoaWVsZCA5MjAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDEwMjA3MSwiZXhwIjo0OTEyMTY2MDcxfQ.ZgZfH-U3TQlyL_DVv12cd97NWxAcR3rgpQ9chjSFoSj99xPbFXLTTN5FRRFSmNItWb16k4pzUO-k3UJIbftseA'),
    ('APP-WTA-BOSSO-01','Bosso','Atelier Court 38','APP-BOSSO-01',7181,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bosso%20-%20Atelier%20Court%2038.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jvc3NvIC0gQXRlbGllciBDb3VydCAzOC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAxODc0LCJleHAiOjQ5MTIxNjU4NzR9.a__1xrLH6SBsn36HRfeHeUNAn9PRwVaNu-X8K8YaPf4dbtOubqIzXhjvxerUJgwufLOBxBfN60KePd-OP9T7bg'),
    ('APP-WTA-BOSSO-02','Bosso','Milano Air','APP-BOSSO-02',7182,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bosso%20-%20Milano%20Air.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jvc3NvIC0gTWlsYW5vIEFpci5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAxOTE4LCJleHAiOjQ5MTIxNjU5MTh9.O5iVFIaV8W6z53kMaB0fRCtl-b1pblCnmWghfClfCZKMBeIk5gUX3cWph5IrlV5WDHMEBHfIkqkSDmGEUeqBzg'),
    ('APP-WTA-BOSSO-03','Bosso','Forma 660','APP-BOSSO-03',7183,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bosso%20-%20Forma%20660.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jvc3NvIC0gRm9ybWEgNjYwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE5MjgsImV4cCI6NDU2NTI2OTkyOH0.ciN2g0UjrdDAW5QOQgT9MPygzlLXMT5zH2flZBRoaFXpZHYJwgxBR-eBlIFtjXdNgG7wYyvLudjSm-cgq1Xlrg'),
    ('APP-WTA-BOSSO-04','Bosso','Sartoria Elite X8','APP-BOSSO-04',7184,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bosso%20-%20Sartoria%20Elite%20X8.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Jvc3NvIC0gU2FydG9yaWEgRWxpdGUgWDgucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDEwMTkzOSwiZXhwIjo0OTEyMTY1OTM5fQ.DIGJUAOroh3ZiKzt1J8LV8ABzp-yHlrEh2xbTtcZYbvrykmoiet1tj501U6MBFLIo52ibArcUaUx5k0yfd4r_g'),
    ('APP-WTA-CASTORA-01','Castora','Aura Court 14','APP-CASTORA-01',7191,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Castora%20-%20Aura%20Court%2014.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Nhc3RvcmEgLSBBdXJhIENvdXJ0IDE0LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE5NDgsImV4cCI6NDkxMjE2NTk0OH0.F4Qf-gZ9CXZBEsgaSu5FfIrcXW2BG0MVP8PksBaxUScb4g5SzeX7MjJgcfbbJ2N0cNtkaeuSdhOFea3zmAI6DQ'),
    ('APP-WTA-CASTORA-02','Castora','Velocity Bloom 330','APP-CASTORA-02',7192,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Castora%20-%20Velocity%20Bloom%20330.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Nhc3RvcmEgLSBWZWxvY2l0eSBCbG9vbSAzMzAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDEwMTk1OCwiZXhwIjo0OTEyMTY1OTU4fQ.rI3INdymy6ugtPORVqITFbcaVnm3adoSotxApkEH9MjI64s5wBtPTL0yW7BKr8S7xYh210-y32Rl_zDPeDkHBg'),
    ('APP-WTA-CASTORA-03','Castora','FlowMuse X7','APP-CASTORA-03',7193,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Castora%20-%20FlowMuse%20X7.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Nhc3RvcmEgLSBGbG93TXVzZSBYNy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAxOTY0LCJleHAiOjE4MjE2Mzc5NjR9.UuPMhUnVEWjYKGOwa5SBqXV18En_8RxKcO1RZX62IxB1DlIAe6k4lIHl-FGugbrLTsnuuGElQRcbwNowdlaq7g'),
    ('APP-WTA-CASTORA-04','Castora','Northstar 840','APP-CASTORA-04',7194,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Castora%20-%20Northstar%20840.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0Nhc3RvcmEgLSBOb3J0aHN0YXIgODQwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE5ODEsImV4cCI6NDkxMjE2NTk4MX0.a35IPIabZwhaa2cRQn_wBnKp-238lgHctqWk239rTpsS1xIcY0t6SaMM58H-NxlE1P9W_Eh7rdhZlwCXIzKRBw'),
    ('APP-WTA-COURTCUTURE-01','Court Cuture','Vogue Ace 33','APP-COURTCUTURE-01',7201,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Court%20Cuture%20-%20Vogue%20Ace%2033.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0NvdXJ0IEN1dHVyZSAtIFZvZ3VlIEFjZSAzMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAyMDM0LCJleHAiOjQ5MTIxNjYwMzR9.8p05U0WeFGnsncOppc9FzgjzVoBXD5fRECc6UW-fhI_8uVDSmsVm84GAAar6UDd1VqqcxzyltiYP0D6dKTulBg'),
    ('APP-WTA-COURTCUTURE-02','Court Cuture','Riviera Atelier','APP-COURTCUTURE-02',7202,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Court%20Cuture%20-%20Riviera%20Atelier.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0NvdXJ0IEN1dHVyZSAtIFJpdmllcmEgQXRlbGllci5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAyMDA1LCJleHAiOjQ5MTIxNjYwMDV9.PYCH8NhDy0-VsnDkflHhlLEgwGqlJ-Cy-NdcT1J_KhqbaGePoQ9muZrVqdu5W98aY9kyjP-QTbARrYLm_Tvkig'),
    ('APP-WTA-COURTCUTURE-03','Court Cuture','Baseline Chic 515','APP-COURTCUTURE-03',7203,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Court%20Cuture%20-%20Baseline%20Chic%20515.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0NvdXJ0IEN1dHVyZSAtIEJhc2VsaW5lIENoaWMgNTE1LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDE5OTMsImV4cCI6NDkxMjE2NTk5M30.gZlT9vpvbIgK7yGugNcRpbLnoHMY9NgSR_dH7HQ-bY4en5RobB_A-MjnO8tTGiKrjIbt0z8Rctyp6WhB5UBUdQ'),
    ('APP-WTA-COURTCUTURE-04','Court Cuture','StyleMuse X9','APP-COURTCUTURE-04',7204,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Court%20Cuture%20-%20StyleMuse%20X9.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0NvdXJ0IEN1dHVyZSAtIFN0eWxlTXVzZSBYOS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAyMDE5LCJleHAiOjQ5MTIxNjYwMTl9.QPglMUqL3xulDV0imy0CiJn3m08odzZN1_5LyaICBSbLUadiSdFF1mEPnRM3uTqjdgKdBoGU2ZLL2SNPbE77Mw')
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
  tour_scope='WTA';
