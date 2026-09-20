update public.player_equipment_loadouts l
set
  racket_inventory_id = case
    when exists (
      select 1
      from public.player_equipment_inventory i
      join public.equipment_catalog_items c on c.id=i.catalog_item_id
      where i.id=l.racket_inventory_id
        and c.sku='RKT-START-100'
    ) then null
    else l.racket_inventory_id
  end,
  shoes_inventory_id = case
    when exists (
      select 1
      from public.player_equipment_inventory i
      join public.equipment_catalog_items c on c.id=i.catalog_item_id
      where i.id=l.shoes_inventory_id
        and c.sku='SHO-ALL-COURT'
    ) then null
    else l.shoes_inventory_id
  end,
  updated_at=now()
where exists (
  select 1
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where (i.id=l.racket_inventory_id and c.sku='RKT-START-100')
     or (i.id=l.shoes_inventory_id and c.sku='SHO-ALL-COURT')
);

update public.equipment_catalog_items
set is_active=false,
    availability_status='unavailable'
where sku in ('RKT-START-100','SHO-ALL-COURT');

create or replace function public.initialize_player_equipment_v1(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $function$
declare
  v_abs integer;
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
  where c.sku in ('APP-START-CORE','ACC-START-TOWEL')
    and c.is_active
    and c.tour_scope in ('unisex',v_world)
    and not exists(
      select 1
      from public.player_equipment_inventory i
      where i.player_id=p_player_id
        and i.catalog_item_id=c.id
        and i.acquired_source='starter'
    );

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
  set string_inventory_id=null,
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
