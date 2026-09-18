alter table public.equipment_catalog_items
  add column if not exists tour_scope text not null default 'unisex';

alter table public.equipment_catalog_items
  drop constraint if exists equipment_catalog_items_tour_scope_chk;

alter table public.equipment_catalog_items
  add constraint equipment_catalog_items_tour_scope_chk
  check (tour_scope in ('unisex','ATP','WTA'));

update public.equipment_catalog_items
set tour_scope='ATP'
where item_type='shoes';

with shoe_models(sku,new_model) as (
  values
    ('SHO-ALL-COURT','Baseline 80'),
    ('SHO-HARD-PRO','Hardline Pro'),
    ('SHO-CLAY-PRO','ClayStep Pro'),
    ('SHO-GRASS-PRO','GrassLine Pro'),
    ('SHO-NOIK-01','Vapro Lite 3'),
    ('SHO-NOIK-02','GP Challenger 1'),
    ('SHO-NOIK-03','Vapro Pro 3 Clay'),
    ('SHO-NOIK-04','Zoom Cage 4 Grass'),
    ('SHO-ADIDIS-01','SoleMatch Control X'),
    ('SHO-ADIDIS-02','Barricad 14'),
    ('SHO-ADIDIS-03','Adizero Uberspeed 5 Clay'),
    ('SHO-ADIDIS-04','Defiant Sprint 3 Grass'),
    ('SHO-ASIKS-01','Gel-Game X'),
    ('SHO-ASIKS-02','Court FF X3'),
    ('SHO-ASIKS-03','Gel-Resolve X Clay'),
    ('SHO-ASIKS-04','Solution Swift FF3 Grass'),
    ('SHO-ONN-01','Roger Advantage X'),
    ('SHO-ONN-02','Roger Pro X2'),
    ('SHO-ONN-03','Roger Clubhouse Clay'),
    ('SHO-ONN-04','Roger Pro Grass X'),
    ('SHO-HOKKA-01','Cliffton Court 10'),
    ('SHO-HOKKA-02','Bondy Court 9'),
    ('SHO-HOKKA-03','Mach Court 6 Clay'),
    ('SHO-HOKKA-04','Kawana Court 2 Grass'),
    ('SHO-KSWIS-01','Court Express X'),
    ('SHO-KSWIS-02','UltraShot X4'),
    ('SHO-KSWIS-03','HyperCourt Express X3 Clay'),
    ('SHO-KSWIS-04','SpeedTrack Pro Grass'),
    ('SHO-LININ-01','Red Hare Court 8'),
    ('SHO-LININ-02','Furious Rider Court 7'),
    ('SHO-LININ-03','Shadow Court 6 Clay'),
    ('SHO-LININ-04','Feidian Court 4 Grass'),
    ('SHO-NEWBALANS-01','796 X4'),
    ('SHO-NEWBALANS-02','FuelCell 996 X6'),
    ('SHO-NEWBALANS-03','Fresh Foam Lav X2 Clay'),
    ('SHO-NEWBALANS-04','CT Rally Grass 2'),
    ('SHO-PUMMA-01','SolarStrike Court 3'),
    ('SHO-PUMMA-02','Court Rider Nitro 2'),
    ('SHO-PUMMA-03','Accelerate Nitro 4 Clay'),
    ('SHO-PUMMA-04','Eliminate Nitro Grass'),
    ('SHO-MIZUNA-01','Break Shot X4'),
    ('SHO-MIZUNA-02','Wave Enforce Tour 2'),
    ('SHO-MIZUNA-03','Wave Exceed Tour X7 Clay'),
    ('SHO-MIZUNA-04','Wave Exceed Lite 3 Grass'),
    ('SHO-OLYMPIKOS-01','Corre Court 4'),
    ('SHO-OLYMPIKOS-02','Pride Court 4'),
    ('SHO-OLYMPIKOS-03','Voa Court 3 Clay'),
    ('SHO-OLYMPIKOS-04','Dynamic Court 2 Grass'),
    ('SHO-FILIA-01','SpeedServe X'),
    ('SHO-FILIA-02','Axilus X3 Energized'),
    ('SHO-FILIA-03','Volley Zone 2 Clay'),
    ('SHO-FILIA-04','SpeedServe Pro Grass'),
    ('SHO-UNDERARMER-01','Charged Assert Court 11'),
    ('SHO-UNDERARMER-02','HOVR Infinite Court 6'),
    ('SHO-UNDERARMER-03','Flow Velociti Court 4 Clay'),
    ('SHO-UNDERARMER-04','Phantom Court 4 Grass'),
    ('SHO-DIADORO-01','Challenge X5'),
    ('SHO-DIADORO-02','B.Icon X3'),
    ('SHO-DIADORO-03','BlueShield Torneo X2 Clay'),
    ('SHO-DIADORO-04','Speed Comp X7 Grass'),
    ('SHO-REEBAK-01','Club C Court 2'),
    ('SHO-REEBAK-02','Nano Court X4'),
    ('SHO-REEBAK-03','Flexagon Court 4 Clay'),
    ('SHO-REEBAK-04','Speed TR Court 2 Grass'),
    ('SHO-SKECHORS-01','Viper Court Rally'),
    ('SHO-SKECHORS-02','Viper Court Pro 2'),
    ('SHO-SKECHORS-03','GO Court Arch Fit Clay'),
    ('SHO-SKECHORS-04','Viper Court Smash Grass'),
    ('SHO-ANTTA-01','PG Court 7'),
    ('SHO-ANTTA-02','G21 Court Pro'),
    ('SHO-ANTTA-03','C202 Court 6 Clay'),
    ('SHO-ANTTA-04','FlashEdge Court Grass'),
    ('SHO-BATHOO-01','SFX X4'),
    ('SHO-BATHOO-02','Jet Mach X3'),
    ('SHO-BATHOO-03','Movea 2 Clay'),
    ('SHO-BATHOO-04','ProPulse Fury X3 Grass'),
    ('SHO-LOTTA-01','Mirage 300 X'),
    ('SHO-LOTTA-02','Raptor HyperPulse 100'),
    ('SHO-LOTTA-03','Mirage 200 Clay'),
    ('SHO-LOTTA-04','Mirage Spin 2 Grass'),
    ('SHO-JOMAE-01','Master 1000 X'),
    ('SHO-JOMAE-02','Slam Pro 3'),
    ('SHO-JOMAE-03','Point 5 Clay'),
    ('SHO-JOMAE-04','Ace Pro 2 Grass')
)
update public.equipment_catalog_items c
set model=m.new_model
from shoe_models m
where c.sku=m.sku
  and c.item_type='shoes';

update public.equipment_catalog_items
set
  price_usd = case sku
    when 'SHO-ALL-COURT' then 80
    when 'SHO-HARD-PRO' then 120
    when 'SHO-CLAY-PRO' then 130
    when 'SHO-GRASS-PRO' then 140
    else price_usd
  end,
  tier = case sku
    when 'SHO-ALL-COURT' then 1
    when 'SHO-HARD-PRO' then 1
    when 'SHO-CLAY-PRO' then 1
    when 'SHO-GRASS-PRO' then 2
    else tier
  end,
  traction = case surface
    when 'hard' then 78 when 'clay' then 80 when 'grass' then 82 else 73 end,
  stability = case surface
    when 'hard' then 76 when 'clay' then 74 when 'grass' then 72 else 72 end,
  comfort = case surface
    when 'hard' then 70 when 'clay' then 72 when 'grass' then 68 else 76 end,
  durability = case surface
    when 'hard' then 84 when 'clay' then 78 when 'grass' then 68 else 74 end,
  product_profile = case surface
    when 'hard' then 'men · ATP · hard-court starter'
    when 'clay' then 'men · ATP · clay starter'
    when 'grass' then 'men · ATP · grass starter'
    else 'men · ATP · budget all-court starter'
  end,
  gameplay_effects = case surface
    when 'hard' then '{"movement_pct":0.28,"return_pct":0.06,"comfort_pct":-0.02}'::jsonb
    when 'clay' then '{"movement_pct":0.34,"rally_pct":0.07,"stamina_pct":0.05,"serve_pct":-0.02}'::jsonb
    when 'grass' then '{"movement_pct":0.40,"serve_pct":0.10,"net_pct":0.06,"comfort_pct":-0.04}'::jsonb
    else '{"movement_pct":0.15,"comfort_pct":0.10,"stamina_pct":0.04}'::jsonb
  end,
  advantages = case surface
    when 'hard' then array['Affordable hard-court grip','Improved return positioning']
    when 'clay' then array['Affordable clay movement','Controlled sliding support']
    when 'grass' then array['Affordable grass traction','Quicker first step']
    else array['Very low purchase price','Balanced all-court use']
  end,
  disadvantages = case surface
    when 'hard' then array['Limited premium cushioning','Higher wrong-surface wear']
    when 'clay' then array['Small serve trade-off','Higher wrong-surface wear']
    when 'grass' then array['Lower comfort','Higher wrong-surface wear']
    else array['Limited peak performance','Less grip than surface-specific shoes']
  end,
  maintenance_text='Replace once condition drops below match-ready level; budget construction wears faster.',
  lifespan_text='Budget ATP shoe with a shorter competitive lifespan.',
  wear_per_match = case when surface='all' then 4.10 else 3.35 end,
  wrong_surface_wear_multiplier = case when surface='all' then 1.00 else 1.80 end
where item_type='shoes'
  and technical_brand_id is null;

with shoe_balance as (
  select
    c.id,
    b.tier as sponsor_tier,
    c.surface,
    case b.name
      when 'Noik' then 0 when 'Adidis' then 40 when 'Asiks' then 80
      when 'Onn' then 0 when 'Hokka' then 35 when 'K-Swis' then 70
      when 'Li-Nin' then 105 when 'New Balans' then 140 when 'Pumma' then 175 when 'Mizuna' then 210
      when 'Olympikos' then 0 when 'Filia' then 30 when 'Under Armer' then 60
      when 'Diadoro' then 90 when 'Reebak' then 120 when 'Skechors' then 150
      when 'Antta' then 0 when 'Bathoo' then 30 when 'Lotta' then 60 when 'Jomae' then 90
      else 0
    end as brand_offset,
    case b.tier
      when 'entry' then 0.35
      when 'established' then 0.65
      when 'premium' then 1.00
      when 'elite' then 1.30
      else 0.35
    end as all_strength,
    case b.tier
      when 'entry' then 0.85
      when 'established' then 1.20
      when 'premium' then 1.65
      when 'elite' then 2.00
      else 0.85
    end as hard_strength,
    case b.tier
      when 'entry' then 1.10
      when 'established' then 1.55
      when 'premium' then 2.05
      when 'elite' then 2.40
      else 1.10
    end as clay_strength,
    case b.tier
      when 'entry' then 1.30
      when 'established' then 1.80
      when 'premium' then 2.30
      when 'elite' then 2.70
      else 1.30
    end as grass_strength
  from public.equipment_catalog_items c
  join public.technical_sponsor_brands b on b.id=c.technical_brand_id
  where c.item_type='shoes'
)
update public.equipment_catalog_items c
set
  price_usd =
    case sb.sponsor_tier
      when 'entry' then 80
      when 'established' then 230
      when 'premium' then 420
      when 'elite' then 620
      else 80
    end
    + sb.brand_offset
    + case sb.surface when 'hard' then 140 when 'clay' then 260 when 'grass' then 380 else 0 end,
  tier = case sb.sponsor_tier
    when 'entry' then case sb.surface when 'hard' then 2 when 'clay' then 3 when 'grass' then 4 else 1 end
    when 'established' then case sb.surface when 'hard' then 3 when 'clay' then 4 when 'grass' then 5 else 2 end
    when 'premium' then case sb.surface when 'hard' then 4 when 'clay' then 5 when 'grass' then 5 else 3 end
    when 'elite' then case sb.surface when 'hard' then 5 when 'clay' then 5 when 'grass' then 5 else 4 end
    else c.tier
  end,
  traction = least(96, (
    case sb.sponsor_tier when 'entry' then 0 when 'established' then 3 when 'premium' then 6 when 'elite' then 9 else 0 end
    + case sb.surface when 'hard' then 80 when 'clay' then 82 when 'grass' then 84 else 74 end
  ))::smallint,
  stability = least(96, (
    case sb.sponsor_tier when 'entry' then 0 when 'established' then 3 when 'premium' then 6 when 'elite' then 9 else 0 end
    + case sb.surface when 'hard' then 78 when 'clay' then 76 when 'grass' then 74 else 72 end
  ))::smallint,
  comfort = least(96, (
    case sb.sponsor_tier when 'entry' then 0 when 'established' then 3 when 'premium' then 6 when 'elite' then 9 else 0 end
    + case sb.surface when 'hard' then 70 when 'clay' then 72 when 'grass' then 68 else 78 end
  ))::smallint,
  durability = least(96, (
    case sb.sponsor_tier when 'entry' then 0 when 'established' then 3 when 'premium' then 6 when 'elite' then 9 else 0 end
    + case sb.surface when 'hard' then 88 when 'clay' then 80 when 'grass' then 70 else 76 end
  ))::smallint,
  product_profile = case sb.surface
    when 'hard' then 'men · ATP · hard-court speed/control'
    when 'clay' then 'men · ATP · clay movement/rally'
    when 'grass' then 'men · ATP · grass speed/serve-volley'
    else 'men · ATP · balanced all-court'
  end,
  gameplay_effects = case sb.surface
    when 'hard' then jsonb_build_object(
      'movement_pct', round(sb.hard_strength,2),
      'return_pct', round(sb.hard_strength*0.25,2),
      'comfort_pct', round(sb.hard_strength*-0.08,2)
    )
    when 'clay' then jsonb_build_object(
      'movement_pct', round(sb.clay_strength,2),
      'rally_pct', round(sb.clay_strength*0.25,2),
      'stamina_pct', round(sb.clay_strength*0.20,2),
      'serve_pct', round(sb.clay_strength*-0.06,2)
    )
    when 'grass' then jsonb_build_object(
      'movement_pct', round(sb.grass_strength,2),
      'serve_pct', round(sb.grass_strength*0.30,2),
      'net_pct', round(sb.grass_strength*0.20,2),
      'comfort_pct', round(sb.grass_strength*-0.10,2)
    )
    else jsonb_build_object(
      'movement_pct', round(sb.all_strength,2),
      'comfort_pct', round(sb.all_strength*0.45,2),
      'stamina_pct', round(sb.all_strength*0.25,2)
    )
  end,
  advantages = case sb.surface
    when 'hard' then array['Fast hard-court changes of direction','Improved return positioning','Reinforced hard-court grip']
    when 'clay' then array['Controlled clay sliding','Stronger rally movement','Useful stamina support']
    when 'grass' then array['Explosive first step','Serve-and-volley movement','High grass-court traction']
    else array['Balanced movement','Long-match comfort','Usable on every surface']
  end,
  disadvantages = case sb.surface
    when 'hard' then array['Reduced comfort compared with all-court shoes','Faster wear on clay and grass']
    when 'clay' then array['Small serve trade-off','Faster wear away from clay']
    when 'grass' then array['Noticeably lower comfort','Faster wear away from grass']
    else array['Less peak grip than a surface-specific shoe']
  end,
  maintenance_text = case sb.sponsor_tier
    when 'elite' then 'Premium construction; monitor condition after tournament weeks and replace once grip falls materially.'
    when 'premium' then 'Tour-grade construction; inspect traction regularly and rotate before heavy tournament blocks.'
    when 'established' then 'Standard performance construction; expect moderate wear across repeated match weeks.'
    else 'Entry construction; inspect frequently because performance drops sooner with heavy use.'
  end,
  lifespan_text = case sb.sponsor_tier
    when 'elite' then 'Elite ATP match shoe with the longest competitive lifespan in the catalogue.'
    when 'premium' then 'Premium ATP match shoe designed for sustained tour use.'
    when 'established' then 'Established ATP performance shoe with a balanced competitive lifespan.'
    else 'Entry ATP performance shoe with a shorter competitive lifespan.'
  end,
  wear_per_match = case sb.sponsor_tier
    when 'elite' then case when sb.surface='all' then 2.40 else 1.80 end
    when 'premium' then case when sb.surface='all' then 2.80 else 2.20 end
    when 'established' then case when sb.surface='all' then 3.30 else 2.60 end
    else case when sb.surface='all' then 3.80 else 3.00 end
  end,
  wrong_surface_wear_multiplier = case when sb.surface='all' then 1.00 else 1.80 end
from shoe_balance sb
where c.id=sb.id;

update public.equipment_catalog_items c
set image_url = public.make_equipment_item_image_v1(
  'shoes',
  null,
  c.brand,
  c.model,
  coalesce(b.primary_color,'#176da7'),
  coalesce(b.secondary_color,'#36b37e'),
  coalesce(b.logo_variant,1)
)
from public.technical_sponsor_brands b
where c.item_type='shoes'
  and c.technical_brand_id=b.id
  and c.image_url like 'data:image/svg+xml;base64,%';

update public.equipment_catalog_items c
set image_url = public.make_equipment_item_image_v1(
  'shoes',null,c.brand,c.model,'#176da7','#36b37e',1
)
where c.item_type='shoes'
  and c.technical_brand_id is null
  and c.image_url like 'data:image/svg+xml;base64,%';

create or replace function public.initialize_player_equipment_v1(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_abs integer;
  v_racket uuid;
  v_shoes uuid;
  v_apparel uuid;
  v_accessory uuid;
  v_world text;
begin
  select p.world into v_world
  from public.players p
  where p.id=p_player_id and p.owner_user_id is not null;

  if v_world is null then return; end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  insert into public.player_equipment_loadouts(player_id)
  values(p_player_id)
  on conflict(player_id) do nothing;

  insert into public.player_equipment_inventory(
    id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source
  )
  select gen_random_uuid(),p_player_id,c.id,100,v_abs,'starter'
  from public.equipment_catalog_items c
  where c.sku in ('RKT-START-100','SHO-ALL-COURT','APP-START-CORE','ACC-START-TOWEL')
    and c.is_active
    and c.tour_scope in ('unisex',v_world)
    and not exists(
      select 1
      from public.player_equipment_inventory i
      where i.player_id=p_player_id
        and i.catalog_item_id=c.id
        and i.acquired_source='starter'
    );

  select i.id into v_racket
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku='RKT-START-100'
    and c.tour_scope in ('unisex',v_world)
  order by i.created_at
  limit 1;

  select i.id into v_shoes
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku='SHO-ALL-COURT'
    and c.tour_scope in ('unisex',v_world)
  order by i.created_at
  limit 1;

  select i.id into v_apparel
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku='APP-START-CORE'
    and c.tour_scope in ('unisex',v_world)
  order by i.created_at
  limit 1;

  select i.id into v_accessory
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku='ACC-START-TOWEL'
    and c.tour_scope in ('unisex',v_world)
  order by i.created_at
  limit 1;

  update public.player_equipment_loadouts
  set racket_inventory_id=coalesce(racket_inventory_id,v_racket),
      string_inventory_id=null,
      shoes_inventory_id=coalesce(shoes_inventory_id,v_shoes),
      apparel_inventory_id=coalesce(apparel_inventory_id,v_apparel),
      updated_at=now()
  where player_id=p_player_id;

  if v_accessory is not null then
    insert into public.player_equipment_accessory_loadout(player_id,accessory_kind,inventory_id)
    values(p_player_id,'towel',v_accessory)
    on conflict(player_id,accessory_kind) do nothing;
  end if;
end;
$function$;

alter function public.get_equipment_dashboard_v1()
  rename to get_equipment_dashboard_unfiltered_v1;

revoke all on function public.get_equipment_dashboard_unfiltered_v1() from public, anon, authenticated;

create or replace function public.get_equipment_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_world text;
  v_payload jsonb;
  v_catalog jsonb;
begin
  select p.id,p.world into v_player,v_world
  from public.players p
  where p.owner_user_id=auth.uid()
  order by p.created_at desc
  limit 1;

  if v_player is null then
    raise exception 'Player not found.';
  end if;

  v_payload:=public.get_equipment_dashboard_unfiltered_v1();

  select coalesce(jsonb_agg(e.item order by e.ord),'[]'::jsonb)
  into v_catalog
  from jsonb_array_elements(coalesce(v_payload->'catalog','[]'::jsonb))
       with ordinality as e(item,ord)
  where coalesce(e.item->>'tour_scope','unisex') in ('unisex',v_world);

  return jsonb_set(v_payload,'{catalog}',coalesce(v_catalog,'[]'::jsonb),true);
end;
$function$;

revoke all on function public.get_equipment_dashboard_v1() from public, anon;
grant execute on function public.get_equipment_dashboard_v1() to authenticated;

alter function public.purchase_equipment_item_v2(uuid,text)
  rename to purchase_equipment_item_unchecked_v2;

revoke all on function public.purchase_equipment_item_unchecked_v2(uuid,text) from public, anon, authenticated;

create or replace function public.purchase_equipment_item_v2(
  p_catalog_item_id uuid,
  p_request_key text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_world text;
  v_scope text;
begin
  select p.id,p.world into v_player,v_world
  from public.players p
  where p.owner_user_id=auth.uid()
  order by p.created_at desc
  limit 1;

  if v_player is null then
    raise exception 'Player not found.';
  end if;

  select c.tour_scope into v_scope
  from public.equipment_catalog_items c
  where c.id=p_catalog_item_id;

  if v_scope is null then
    raise exception 'Equipment item not found.';
  end if;

  if v_scope not in ('unisex',v_world) then
    raise exception 'This equipment item is not available for your tour.';
  end if;

  return public.purchase_equipment_item_unchecked_v2(p_catalog_item_id,p_request_key);
end;
$function$;

revoke all on function public.purchase_equipment_item_v2(uuid,text) from public, anon;
grant execute on function public.purchase_equipment_item_v2(uuid,text) to authenticated;

alter function public.equip_equipment_item_v1(uuid)
  rename to equip_equipment_item_unchecked_v1;

revoke all on function public.equip_equipment_item_unchecked_v1(uuid) from public, anon, authenticated;

create or replace function public.equip_equipment_item_v1(p_inventory_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_world text;
  v_scope text;
begin
  select p.id,p.world into v_player,v_world
  from public.players p
  where p.owner_user_id=auth.uid()
  order by p.created_at desc
  limit 1;

  if v_player is null then
    raise exception 'Player not found.';
  end if;

  select c.tour_scope into v_scope
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.id=p_inventory_id
    and i.player_id=v_player;

  if v_scope is null then
    raise exception 'Equipment item not owned or no longer active.';
  end if;

  if v_scope not in ('unisex',v_world) then
    raise exception 'This equipment item is not available for your tour.';
  end if;

  return public.equip_equipment_item_unchecked_v1(p_inventory_id);
end;
$function$;

revoke all on function public.equip_equipment_item_v1(uuid) from public, anon;
grant execute on function public.equip_equipment_item_v1(uuid) to authenticated;

alter function public.save_player_equipment_match_setup_v1(
  smallint,text,uuid,uuid,uuid,jsonb
) rename to save_player_equipment_match_setup_unchecked_v1;

revoke all on function public.save_player_equipment_match_setup_unchecked_v1(
  smallint,text,uuid,uuid,uuid,jsonb
) from public, anon, authenticated;

create or replace function public.save_player_equipment_match_setup_v1(
  p_slot_index smallint,
  p_name text,
  p_racket_inventory_id uuid,
  p_shoes_inventory_id uuid,
  p_apparel_inventory_id uuid,
  p_accessories jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_world text;
  v_shoe_scope text;
begin
  select p.id,p.world into v_player,v_world
  from public.players p
  where p.owner_user_id=auth.uid()
    and p.player_type='human'
  limit 1;

  if v_player is null then
    raise exception 'Player not found.';
  end if;

  select c.tour_scope into v_shoe_scope
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.id=p_shoes_inventory_id
    and i.player_id=v_player
    and c.item_type='shoes';

  if v_shoe_scope is null then
    raise exception 'Invalid shoes inventory item.';
  end if;

  if v_shoe_scope not in ('unisex',v_world) then
    raise exception 'These shoes are not available for your tour.';
  end if;

  return public.save_player_equipment_match_setup_unchecked_v1(
    p_slot_index,p_name,p_racket_inventory_id,p_shoes_inventory_id,p_apparel_inventory_id,p_accessories
  );
end;
$function$;

revoke all on function public.save_player_equipment_match_setup_v1(
  smallint,text,uuid,uuid,uuid,jsonb
) from public, anon;
grant execute on function public.save_player_equipment_match_setup_v1(
  smallint,text,uuid,uuid,uuid,jsonb
) to authenticated;
