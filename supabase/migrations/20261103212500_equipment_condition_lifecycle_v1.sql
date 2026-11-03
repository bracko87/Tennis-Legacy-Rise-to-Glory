-- Equipment lifecycle: one-time low-condition alert, permanent breakage and same-slot replacement.
-- Source only: production migration must be explicitly approved before deployment.
create table if not exists public.player_equipment_broken_starters_v1 (
  player_id uuid not null references public.players(id) on delete cascade,
  catalog_item_id uuid not null references public.equipment_catalog_items(id),
  broken_at timestamptz not null default now(),
  primary key(player_id,catalog_item_id)
);
revoke all on public.player_equipment_broken_starters_v1 from public,anon,authenticated;
alter table public.player_equipment_broken_starters_v1 enable row level security;

insert into public.notification_catalog
  (code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,
   title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_active)
values
  ('equipment.condition.low','equipment','Equipment wearing out',
   'Warn players before equipment breaks.','equipment condition update',
   'Condition crosses from >=20% to below 20% for the first time.','database_trigger',
   'Equipment condition low','An equipment item is below 20% condition.',
   '/game/equipment','warning',true,false,false,true),
  ('equipment.condition.broken','equipment','Equipment broken',
   'Inform players when unusable equipment is removed.','equipment condition update',
   'Condition reaches 0% and the item is discarded.','database_trigger',
   'Equipment broken','An equipment item has broken and was removed.',
   '/game/equipment','warning',true,false,false,true)
on conflict(code) do update set is_active=true,updated_at=now();

-- The original starter initializer may run every time the Gear Room is opened.
-- Its INSERT attempts must never recreate a starter that has already broken.
create or replace function public.prevent_broken_starter_regeneration_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
begin
  if new.acquired_source='starter' and exists(
    select 1 from public.player_equipment_broken_starters_v1 b
    where b.player_id=new.player_id and b.catalog_item_id=new.catalog_item_id
  ) then return null; end if;
  return new;
end; $$;
revoke all on function public.prevent_broken_starter_regeneration_v1() from public,anon,authenticated;
drop trigger if exists equipment_prevent_starter_regeneration_v1 on public.player_equipment_inventory;
create trigger equipment_prevent_starter_regeneration_v1
before insert on public.player_equipment_inventory
for each row execute function public.prevent_broken_starter_regeneration_v1();

-- Serializable per-player by locking the loadout before choosing a replacement.
-- No replacement can use another category, zero-condition item, or the broken instance.
create or replace function public.retire_broken_equipment_v1(p_inventory_id uuid)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_item public.player_equipment_inventory%rowtype;
  v_type text; v_kind text; v_name text; v_new_id uuid;
  v_slot text; v_owner uuid; v_new_name text; v_equipped boolean:=false;
begin
  select * into v_item from public.player_equipment_inventory where id=p_inventory_id for update;
  if not found or v_item.condition>0 then return jsonb_build_object('status','not_broken'); end if;
  select c.item_type,c.accessory_kind,concat_ws(' ',c.brand,c.model)
    into v_type,v_kind,v_name from public.equipment_catalog_items c
   where c.id=v_item.catalog_item_id;

  perform 1 from public.player_equipment_loadouts
   where player_id=v_item.player_id for update;
  v_slot:=case when v_type='accessory' then v_kind else v_type end;
  select exists(select 1 from public.player_equipment_loadouts l
    where l.player_id=v_item.player_id and v_item.id in
      (l.racket_inventory_id,l.shoes_inventory_id,l.apparel_inventory_id,l.string_inventory_id))
    or exists(select 1 from public.player_equipment_accessory_loadout a
    where a.player_id=v_item.player_id and a.inventory_id=v_item.id) into v_equipped;

  if v_equipped then
  select i.id,concat_ws(' ',c.brand,c.model) into v_new_id,v_new_name
    from public.player_equipment_inventory i
    join public.equipment_catalog_items c on c.id=i.catalog_item_id
   where i.player_id=v_item.player_id and i.id<>v_item.id
     and i.condition>0 and c.is_active and c.item_type=v_type
     and (v_type<>'accessory' or c.accessory_kind=v_kind)
     and not exists(
       select 1 from public.player_equipment_loadouts l
       where l.player_id=i.player_id and
         i.id in (l.racket_inventory_id,l.shoes_inventory_id,l.apparel_inventory_id,l.string_inventory_id)
     )
     and not exists(
       select 1 from public.player_equipment_accessory_loadout a
       where a.player_id=i.player_id and a.inventory_id=i.id
     )
   order by i.condition desc,i.created_at asc,i.id asc limit 1;
  end if;

  if v_type='racket' then
    update public.player_equipment_loadouts set racket_inventory_id=v_new_id,updated_at=now()
      where player_id=v_item.player_id and racket_inventory_id=v_item.id;
  elsif v_type='shoes' then
    update public.player_equipment_loadouts set shoes_inventory_id=v_new_id,updated_at=now()
      where player_id=v_item.player_id and shoes_inventory_id=v_item.id;
  elsif v_type='apparel' then
    update public.player_equipment_loadouts
       set apparel_inventory_id=v_new_id,updated_at=now()
     where player_id=v_item.player_id and apparel_inventory_id=v_item.id;
  elsif v_type='accessory' then
    if v_new_id is null then
      delete from public.player_equipment_accessory_loadout
       where player_id=v_item.player_id and inventory_id=v_item.id;
    else
      update public.player_equipment_accessory_loadout
         set inventory_id=v_new_id,updated_at=now()
       where player_id=v_item.player_id and inventory_id=v_item.id;
    end if;
  end if;

  if v_item.acquired_source='starter' then
    insert into public.player_equipment_broken_starters_v1(player_id,catalog_item_id)
    values(v_item.player_id,v_item.catalog_item_id) on conflict do nothing;
  end if;

  select p.owner_user_id into v_owner from public.players p where p.id=v_item.player_id;
  delete from public.player_equipment_inventory where id=v_item.id and player_id=v_item.player_id;
  if v_owner is not null then
    perform public.emit_notification_v1(
      v_owner,v_item.player_id,'equipment.condition.broken','Equipment broken: '||v_name,
      v_name||' reached 0% condition and was removed. '||
        case when v_new_id is null then 'No replacement is available for '||coalesce(v_slot,'this slot')||'.'
             else 'Automatically equipped '||v_new_name||'.' end,
      '/game/equipment',
      jsonb_build_object('inventory_id',v_item.id,'item_type',v_type,
        'accessory_kind',v_kind,'replacement_inventory_id',v_new_id,'action_url','/game/equipment'),
      'equipment:broken:'||v_item.id::text);
  end if;
  return jsonb_build_object('status','removed','inventory_id',v_item.id,
    'replacement_inventory_id',v_new_id,'slot',v_slot);
end; $$;
revoke all on function public.retire_broken_equipment_v1(uuid) from public,anon,authenticated;

create or replace function public.equipment_condition_lifecycle_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_owner uuid; v_name text; v_type text; v_kind text;
begin
  if new.condition is not distinct from old.condition then return new; end if;
  if old.condition>=20 and new.condition<20 and new.condition>0 then
    select p.owner_user_id into v_owner from public.players p where p.id=new.player_id;
    select concat_ws(' ',c.brand,c.model),c.item_type,c.accessory_kind
      into v_name,v_type,v_kind from public.equipment_catalog_items c where c.id=new.catalog_item_id;
    if v_owner is not null then
      perform public.emit_notification_v1(v_owner,new.player_id,'equipment.condition.low',
        'Equipment warning: '||v_name,
        v_name||' is at '||new.condition||'% condition. Replace it before it breaks.',
        '/game/equipment',
        jsonb_build_object('inventory_id',new.id,'condition',new.condition,'item_type',v_type,
          'accessory_kind',v_kind,'action_url','/game/equipment'),
        'equipment:low20:'||new.id::text);
    end if;
  end if;
  if new.condition<=0 then perform public.retire_broken_equipment_v1(new.id); end if;
  return new;
end; $$;
revoke all on function public.equipment_condition_lifecycle_v1() from public,anon,authenticated;
drop trigger if exists equipment_condition_lifecycle_after_update_v1 on public.player_equipment_inventory;
create trigger equipment_condition_lifecycle_after_update_v1
after update of condition on public.player_equipment_inventory
for each row when (old.condition is distinct from new.condition)
execute function public.equipment_condition_lifecycle_v1();

-- Existing zero-condition gear is migrated out, with replacement using the same rule.
do $$
declare v record;
begin
  for v in select id from public.player_equipment_inventory where condition<=0 order by player_id,id
  loop perform public.retire_broken_equipment_v1(v.id); end loop;
end $$;
