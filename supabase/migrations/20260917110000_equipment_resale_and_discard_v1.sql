create or replace function public.calculate_equipment_resale_value_v1(
  p_purchase_price bigint,
  p_condition numeric,
  p_resale_modifier numeric
)
returns bigint
language sql
immutable
set search_path to 'public'
as $function$
  select greatest(
    0::bigint,
    floor(
      greatest(coalesce(p_purchase_price, 0), 0)::numeric
      * 0.25
      * power(least(greatest(coalesce(p_condition, 0), 0), 100) / 100.0, 1.15)
      * least(greatest(coalesce(p_resale_modifier, 0), 0), 1)
    )::bigint
  );
$function$;

create or replace function public.calculate_equipment_resale_value_v1(
  p_purchase_price bigint,
  p_condition smallint,
  p_resale_modifier numeric
)
returns bigint
language sql
immutable
set search_path to 'public'
as $function$
  select public.calculate_equipment_resale_value_v1(
    p_purchase_price,
    p_condition::numeric,
    p_resale_modifier
  );
$function$;

create or replace function public.discard_equipment_item_v1(p_inventory_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid;
  v_item public.player_equipment_inventory%rowtype;
  v_catalog public.equipment_catalog_items%rowtype;
  v_loadout public.player_equipment_loadouts%rowtype;
  v_equipped boolean := false;
begin
  select p.id
    into v_player
  from public.players p
  where p.owner_user_id = auth.uid()
  order by p.created_at desc
  limit 1;

  if v_player is null then
    raise exception 'Player not found.';
  end if;

  perform public.initialize_player_equipment_v1(v_player);

  select i.*
    into v_item
  from public.player_equipment_inventory i
  where i.id = p_inventory_id
    and i.player_id = v_player
  for update;

  if v_item.id is null then
    raise exception 'Equipment item not owned.';
  end if;

  select c.*
    into v_catalog
  from public.equipment_catalog_items c
  where c.id = v_item.catalog_item_id;

  if v_catalog.id is null then
    raise exception 'Equipment definition not found.';
  end if;

  if v_item.acquired_source <> 'purchase' then
    raise exception 'Only purchased equipment can be discarded.';
  end if;

  select l.*
    into v_loadout
  from public.player_equipment_loadouts l
  where l.player_id = v_player;

  v_equipped :=
    p_inventory_id = v_loadout.racket_inventory_id
    or p_inventory_id = v_loadout.string_inventory_id
    or p_inventory_id = v_loadout.shoes_inventory_id
    or p_inventory_id = v_loadout.apparel_inventory_id
    or exists (
      select 1
      from public.player_equipment_accessory_loadout al
      where al.player_id = v_player
        and al.inventory_id = p_inventory_id
    );

  if v_equipped then
    raise exception 'This item is currently equipped. Equip a replacement before discarding it.';
  end if;

  delete from public.player_equipment_inventory
  where id = v_item.id
    and player_id = v_player;

  return jsonb_build_object(
    'status', 'discarded',
    'inventory_id', v_item.id,
    'catalog_item_id', v_catalog.id,
    'brand', v_catalog.brand,
    'model', v_catalog.model,
    'value_received_usd', 0
  );
end;
$function$;

revoke execute on function public.discard_equipment_item_v1(uuid) from public, anon;
grant execute on function public.discard_equipment_item_v1(uuid) to authenticated;
