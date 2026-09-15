-- Simplify player-facing equipment to Racquets, Shoes, Clothing and Accessories.
-- Existing string rows remain archived for historical integrity but are no longer active,
-- purchasable, equippable, displayed or used in match calculations.

alter table public.equipment_catalog_items
  drop constraint if exists equipment_catalog_items_item_type_check;

alter table public.equipment_catalog_items
  add constraint equipment_catalog_items_item_type_check
  check (item_type in ('racket','string','shoes','apparel','accessory'));

update public.equipment_catalog_items
set is_active=false,
    availability_status='unavailable',
    equip_slot=null,
    effect_scope='none'
where item_type='string';

update public.player_equipment_loadouts
set string_inventory_id=null,
    updated_at=now()
where string_inventory_id is not null;

create or replace function public.initialize_player_equipment_v1(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_abs integer;
  v_racket uuid;
  v_shoes uuid;
begin
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id is not null) then
    return;
  end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs
  from public.get_current_game_day_internal_v1() d;

  insert into public.player_equipment_loadouts(player_id)
  values(p_player_id)
  on conflict(player_id) do nothing;

  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source)
  select gen_random_uuid(),p_player_id,c.id,100,v_abs,'starter'
  from public.equipment_catalog_items c
  where c.sku in ('RKT-START-100','SHO-ALL-COURT')
    and c.is_active
    and not exists(
      select 1 from public.player_equipment_inventory i
      where i.player_id=p_player_id and i.catalog_item_id=c.id and i.acquired_source='starter'
    );

  select i.id into v_racket
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id and c.sku='RKT-START-100'
  order by i.created_at limit 1;

  select i.id into v_shoes
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id and c.sku='SHO-ALL-COURT'
  order by i.created_at limit 1;

  update public.player_equipment_loadouts
  set racket_inventory_id=coalesce(racket_inventory_id,v_racket),
      string_inventory_id=null,
      shoes_inventory_id=coalesce(shoes_inventory_id,v_shoes),
      updated_at=now()
  where player_id=p_player_id;
end;
$$;

create or replace function public.get_equipment_match_modifiers_internal_v1(p_player_id uuid,p_surface text default 'hard')
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  l public.player_equipment_loadouts%rowtype;
  r record;
  sh record;
  v_surface text:=lower(coalesce(p_surface,'hard'));
  r_pen numeric:=0;
  sh_pen numeric:=0;
  surface_bonus numeric:=0;
  v_power numeric:=0;
  v_control numeric:=0;
  v_spin numeric:=0;
  v_movement numeric:=0;
  v_comfort numeric:=0;
begin
  perform public.initialize_player_equipment_v1(p_player_id);
  select * into l from public.player_equipment_loadouts where player_id=p_player_id;

  select i.condition,c.* into r
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.id=l.racket_inventory_id and i.player_id=p_player_id;

  select i.condition,c.* into sh
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.id=l.shoes_inventory_id and i.player_id=p_player_id;

  r_pen:=case when coalesce(r.condition,100)>=70 then 0 when r.condition>=50 then -0.15 when r.condition>=30 then -0.40 else -0.80 end;
  sh_pen:=case when coalesce(sh.condition,100)>=70 then 0 when sh.condition>=50 then -0.20 when sh.condition>=30 then -0.50 else -0.90 end;

  surface_bonus:=case
    when sh.surface=v_surface then 0.45
    when sh.surface='all' then 0.15
    when sh.surface is null then 0
    else -0.35
  end;

  v_power:=((coalesce(r.power,75)-75)*0.04)+r_pen;
  v_control:=((coalesce(r.control,75)-75)*0.04)+r_pen;
  v_spin:=((coalesce(r.spin,75)-75)*0.035)+r_pen;
  v_movement:=((((coalesce(sh.traction,75)+coalesce(sh.stability,75))/2.0)-75)*0.035)+surface_bonus+sh_pen;
  v_comfort:=(((coalesce(r.comfort,75)+coalesce(sh.comfort,75))/2.0)-75)*0.02 + least(0,r_pen+sh_pen)/2.0;

  return jsonb_build_object(
    'surface',v_surface,
    'power_pct',round(v_power,2),
    'control_pct',round(v_control,2),
    'spin_pct',round(v_spin,2),
    'movement_pct',round(v_movement,2),
    'comfort_pct',round(v_comfort,2),
    'racket_condition',coalesce(r.condition,0),
    'shoes_condition',coalesce(sh.condition,0),
    'shoe_surface',coalesce(sh.surface,'all')
  );
end;
$$;

create or replace function public.apply_equipment_match_wear_v1(p_player_id uuid,p_match_id uuid,p_surface text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  l public.player_equipment_loadouts%rowtype;
  rb smallint; ra smallint; shb smallint; sha smallint;
  shoe_surface text;
  shoe_wear smallint:=4;
begin
  if exists(select 1 from public.player_equipment_wear_events where player_id=p_player_id and match_id=p_match_id) then
    return jsonb_build_object('status','already_applied');
  end if;

  perform public.initialize_player_equipment_v1(p_player_id);
  select * into l from public.player_equipment_loadouts where player_id=p_player_id for update;
  if l.player_id is null then return jsonb_build_object('status','no_loadout'); end if;

  select condition into rb
  from public.player_equipment_inventory
  where id=l.racket_inventory_id and player_id=p_player_id
  for update;

  select i.condition,c.surface into shb,shoe_surface
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.id=l.shoes_inventory_id and i.player_id=p_player_id
  for update of i;

  ra:=greatest(0,coalesce(rb,0)-1);
  shoe_wear:=case when shoe_surface=lower(coalesce(p_surface,'hard')) then 3 when shoe_surface='all' then 4 else 5 end;
  sha:=greatest(0,coalesce(shb,0)-shoe_wear);

  if l.racket_inventory_id is not null then
    update public.player_equipment_inventory set condition=ra,updated_at=now()
    where id=l.racket_inventory_id and player_id=p_player_id;
  end if;

  if l.shoes_inventory_id is not null then
    update public.player_equipment_inventory set condition=sha,updated_at=now()
    where id=l.shoes_inventory_id and player_id=p_player_id;
  end if;

  insert into public.player_equipment_wear_events(player_id,match_id,surface,racket_before,racket_after,string_before,string_after,shoes_before,shoes_after)
  values(p_player_id,p_match_id,lower(coalesce(p_surface,'hard')),rb,ra,null,null,shb,sha);

  return jsonb_build_object('status','applied','racket',jsonb_build_array(rb,ra),'shoes',jsonb_build_array(shb,sha));
end;
$$;

create or replace function public.equip_equipment_item_v1(p_inventory_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  v_type text;
begin
  select p.id into v_player
  from public.players p
  where p.owner_user_id=auth.uid()
  order by p.created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;

  perform public.initialize_player_equipment_v1(v_player);

  select c.item_type into v_type
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.id=p_inventory_id and i.player_id=v_player and c.is_active;

  if v_type is null then raise exception 'Equipment item not owned or no longer active.'; end if;

  if v_type='racket' then
    update public.player_equipment_loadouts set racket_inventory_id=p_inventory_id,updated_at=now() where player_id=v_player;
  elsif v_type='shoes' then
    update public.player_equipment_loadouts set shoes_inventory_id=p_inventory_id,updated_at=now() where player_id=v_player;
  else
    raise exception 'This equipment type does not use a match equipment slot.';
  end if;

  return jsonb_build_object('status','equipped','inventory_id',p_inventory_id,'item_type',v_type);
end;
$$;

create or replace function public.get_equipment_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  v_balance bigint:=0;
  v_loadout jsonb;
  v_inventory jsonb;
  v_catalog jsonb;
begin
  select p.id into v_player
  from public.players p
  where p.owner_user_id=auth.uid()
  order by p.created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;

  perform public.initialize_player_equipment_v1(v_player);
  perform public.ensure_player_career_finance_v1(v_player);
  select balance into v_balance from public.player_career_finance_accounts where player_id=v_player;

  select jsonb_build_object(
    'apparel_brand',l.apparel_brand,
    'racket_sponsor_name',l.racket_sponsor_name,
    'apparel_sponsor_name',l.apparel_sponsor_name,
    'footwear_sponsor_name',l.footwear_sponsor_name,
    'racket',case when ri.id is null then null else jsonb_build_object('inventory_id',ri.id,'condition',ri.condition,'item',to_jsonb(rc)) end,
    'shoes',case when shi.id is null then null else jsonb_build_object('inventory_id',shi.id,'condition',shi.condition,'item',to_jsonb(shc)) end
  ) into v_loadout
  from public.player_equipment_loadouts l
  left join public.player_equipment_inventory ri on ri.id=l.racket_inventory_id and ri.player_id=l.player_id
  left join public.equipment_catalog_items rc on rc.id=ri.catalog_item_id and rc.is_active
  left join public.player_equipment_inventory shi on shi.id=l.shoes_inventory_id and shi.player_id=l.player_id
  left join public.equipment_catalog_items shc on shc.id=shi.catalog_item_id and shc.is_active
  where l.player_id=v_player;

  select coalesce(jsonb_agg(jsonb_build_object(
    'inventory_id',i.id,
    'condition',i.condition,
    'acquired_source',i.acquired_source,
    'acquired_absolute_day',i.acquired_absolute_day,
    'purchase_price_usd',i.purchase_price_usd,
    'is_equipped',(coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false)),
    'resell_supported',(i.acquired_source='purchase' and c.is_resellable),
    'can_sell',(i.acquired_source='purchase' and c.is_resellable and not (coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false)) and public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier)>0),
    'sell_block_reason',case
      when i.acquired_source<>'purchase' then 'Starter, sponsored and reward equipment cannot be sold.'
      when not c.is_resellable then 'This equipment item cannot be resold.'
      when coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false) then 'Equip a replacement before selling this item.'
      when public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier)<=0 then 'This equipment has no resale value.'
      else null
    end,
    'resale_value_usd',public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier),
    'item',to_jsonb(c)
  ) order by c.item_type,c.sort_order,i.created_at),'[]'::jsonb) into v_inventory
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id and c.is_active and c.item_type in ('racket','shoes','apparel','accessory')
  join public.player_equipment_loadouts l on l.player_id=i.player_id
  where i.player_id=v_player;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.item_type,c.sort_order),'[]'::jsonb) into v_catalog
  from public.equipment_catalog_items c
  where c.is_active and c.item_type in ('racket','shoes','apparel','accessory');

  return jsonb_build_object(
    'player_id',v_player,
    'currency','USD',
    'balance',coalesce(v_balance,0),
    'loadout',coalesce(v_loadout,'{}'::jsonb),
    'inventory',v_inventory,
    'catalog',v_catalog,
    'resale_base_percent',65,
    'effects',jsonb_build_object(
      'hard',public.get_equipment_match_modifiers_internal_v1(v_player,'hard'),
      'clay',public.get_equipment_match_modifiers_internal_v1(v_player,'clay'),
      'grass',public.get_equipment_match_modifiers_internal_v1(v_player,'grass')
    ),
    'wear_rules',jsonb_build_object(
      'racket_per_match',1,
      'shoes_surface_specific',3,
      'shoes_all_court',4,
      'shoes_wrong_surface',5
    )
  );
end;
$$;

revoke execute on function public.set_equipment_string_tension_v1(numeric) from authenticated;
