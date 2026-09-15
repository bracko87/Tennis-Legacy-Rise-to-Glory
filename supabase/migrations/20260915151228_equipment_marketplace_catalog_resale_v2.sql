-- Equipment Marketplace v2: catalogue metadata, item images, tags, safe buy/sell,
-- and future-ready categories while preserving the existing match-equipment system.

alter table public.equipment_catalog_items
  drop constraint if exists equipment_catalog_items_item_type_check;

alter table public.equipment_catalog_items
  add constraint equipment_catalog_items_item_type_check
  check (item_type in ('racket','string','shoes','apparel','accessory','training','recovery'));

alter table public.equipment_catalog_items
  add column if not exists image_url text not null default '',
  add column if not exists tags text[] not null default '{}'::text[],
  add column if not exists advantages text[] not null default '{}'::text[],
  add column if not exists disadvantages text[] not null default '{}'::text[],
  add column if not exists maintenance_text text not null default '',
  add column if not exists lifespan_text text not null default '',
  add column if not exists effect_scope text not null default 'match',
  add column if not exists availability_status text not null default 'available',
  add column if not exists equip_slot text null,
  add column if not exists is_resellable boolean not null default true,
  add column if not exists resale_modifier numeric(5,4) not null default 1.0000;

alter table public.equipment_catalog_items
  drop constraint if exists equipment_catalog_items_effect_scope_check,
  add constraint equipment_catalog_items_effect_scope_check check (effect_scope in ('match','training','recovery','cosmetic','none')),
  drop constraint if exists equipment_catalog_items_availability_status_check,
  add constraint equipment_catalog_items_availability_status_check check (availability_status in ('available','unavailable','limited','sponsor_only')),
  drop constraint if exists equipment_catalog_items_equip_slot_check,
  add constraint equipment_catalog_items_equip_slot_check check (equip_slot is null or equip_slot in ('racket','string','shoes')),
  drop constraint if exists equipment_catalog_items_resale_modifier_check,
  add constraint equipment_catalog_items_resale_modifier_check check (resale_modifier >= 0 and resale_modifier <= 1);

alter table public.player_equipment_inventory
  add column if not exists purchase_price_usd bigint not null default 0,
  add column if not exists purchase_request_key text null;

alter table public.player_equipment_inventory
  drop constraint if exists player_equipment_inventory_purchase_price_check,
  add constraint player_equipment_inventory_purchase_price_check check (purchase_price_usd >= 0);

create unique index if not exists player_equipment_inventory_purchase_request_key_idx
  on public.player_equipment_inventory(player_id, purchase_request_key)
  where purchase_request_key is not null;

update public.equipment_catalog_items c
set equip_slot = case when c.item_type in ('racket','string','shoes') then c.item_type else null end,
    effect_scope = case when c.item_type in ('racket','string','shoes') then 'match' when c.item_type='training' then 'training' when c.item_type='recovery' then 'recovery' when c.item_type in ('apparel','accessory') then 'cosmetic' else 'none' end
where true;

update public.equipment_catalog_items set image_url='/equipment/marketplace/rkt-start-100.svg',tags=array['balanced','all-court','forgiving','starter'],advantages=array['Balanced response','Forgiving sweet spot','High durability'],disadvantages=array['No specialist performance edge'],maintenance_text='Inspect frame and grip regularly. Match wear is applied automatically.',lifespan_text='About 100 matches at normal racket wear before replacement is recommended.',resale_modifier=0.8500 where sku='RKT-START-100';
update public.equipment_catalog_items set image_url='/equipment/marketplace/rkt-volt-98.svg',tags=array['power','spin','aggressive','baseline'],advantages=array['Strong first-strike power','Above-average spin response'],disadvantages=array['Lower comfort','Less control than precision frames'],maintenance_text='Inspect frame and grip regularly. Match wear is applied automatically.',lifespan_text='About 100 matches at normal racket wear before replacement is recommended.',resale_modifier=0.9000 where sku='RKT-VOLT-98';
update public.equipment_catalog_items set image_url='/equipment/marketplace/rkt-axiom-97.svg',tags=array['control','precision','all-court','tour'],advantages=array['Excellent directional control','Stable precision response'],disadvantages=array['Lower free power'],maintenance_text='Inspect frame and grip regularly. Match wear is applied automatically.',lifespan_text='About 100 matches at normal racket wear before replacement is recommended.',resale_modifier=0.9500 where sku='RKT-AXIOM-97';
update public.equipment_catalog_items set image_url='/equipment/marketplace/rkt-spin-100.svg',tags=array['spin','baseline','aggressive','tour'],advantages=array['Elite spin potential','Balanced attacking power'],disadvantages=array['Lower comfort','Slightly reduced durability'],maintenance_text='Inspect frame and grip regularly. Match wear is applied automatically.',lifespan_text='About 100 matches at normal racket wear before replacement is recommended.',resale_modifier=0.9500 where sku='RKT-SPIN-100';
update public.equipment_catalog_items set image_url='/equipment/marketplace/str-corepoly-125.svg',tags=array['polyester','control','spin','durable'],advantages=array['Strong control','Strong spin response','Good durability'],disadvantages=array['Firm feel','Lower comfort'],maintenance_text='Strings lose 10% condition per completed match. Replace before condition becomes critical.',lifespan_text='About 10 matches at normal string wear.',resale_modifier=0.5500 where sku='STR-COREPOLY-125';
update public.equipment_catalog_items set image_url='/equipment/marketplace/str-softmulti-130.svg',tags=array['multifilament','comfort','power','soft'],advantages=array['Excellent comfort','Easy depth and power'],disadvantages=array['Lower control','Shorter lifespan'],maintenance_text='Strings lose 10% condition per completed match. Replace before condition becomes critical.',lifespan_text='About 10 matches at normal string wear.',resale_modifier=0.5500 where sku='STR-SOFTMULTI-130';
update public.equipment_catalog_items set image_url='/equipment/marketplace/str-tourhybrid.svg',tags=array['hybrid','balanced','control','spin'],advantages=array['Balanced control and spin','Better comfort than full polyester'],disadvantages=array['No single dominant specialty'],maintenance_text='Strings lose 10% condition per completed match. Replace before condition becomes critical.',lifespan_text='About 10 matches at normal string wear.',resale_modifier=0.6000 where sku='STR-TOURHYBRID';
update public.equipment_catalog_items set image_url='/equipment/marketplace/str-naturaltouch.svg',tags=array['natural-gut','premium','comfort','power'],advantages=array['Elite comfort','Effortless power'],disadvantages=array['High purchase price','Lowest durability in the current string range'],maintenance_text='Strings lose 10% condition per completed match. Replace before condition becomes critical.',lifespan_text='About 10 matches at normal string wear.',resale_modifier=0.6500 where sku='STR-NATURALTOUCH';
update public.equipment_catalog_items set image_url='/equipment/marketplace/sho-all-court.svg',tags=array['all-court','versatile','comfort','balanced'],advantages=array['Works on every surface','Balanced comfort and traction'],disadvantages=array['Less specialized than surface-specific shoes'],maintenance_text='Wear depends on court use. All-court shoes lose 4% condition per completed match.',lifespan_text='About 25 matches at normal all-court wear.',resale_modifier=0.8000 where sku='SHO-ALL-COURT';
update public.equipment_catalog_items set image_url='/equipment/marketplace/sho-hard-pro.svg',tags=array['hard','stability','durable','traction'],advantages=array['Excellent abrasion resistance','High stability on hard courts'],disadvantages=array['Specialized for hard courts'],maintenance_text='Correct-surface wear is 3% per match; wrong-surface use can increase wear to 5%.',lifespan_text='Roughly 20–34 matches depending on surface use.',resale_modifier=0.9000 where sku='SHO-HARD-PRO';
update public.equipment_catalog_items set image_url='/equipment/marketplace/sho-clay-pro.svg',tags=array['clay','traction','slide','stability'],advantages=array['Excellent clay traction','Controlled sliding'],disadvantages=array['Specialized for clay courts'],maintenance_text='Correct-surface wear is 3% per match; wrong-surface use can increase wear to 5%.',lifespan_text='Roughly 20–34 matches depending on surface use.',resale_modifier=0.9000 where sku='SHO-CLAY-PRO';
update public.equipment_catalog_items set image_url='/equipment/marketplace/sho-grass-pro.svg',tags=array['grass','traction','grip','movement'],advantages=array['Elite grass-court grip','Secure low-friction movement'],disadvantages=array['Lower durability','Specialized for grass courts'],maintenance_text='Correct-surface wear is 3% per match; wrong-surface use can increase wear to 5%.',lifespan_text='Roughly 20–34 matches depending on surface use.',resale_modifier=0.9000 where sku='SHO-GRASS-PRO';

update public.player_equipment_inventory i set purchase_price_usd=case when i.acquired_source='purchase' then c.price_usd else 0 end from public.equipment_catalog_items c where c.id=i.catalog_item_id and i.purchase_price_usd=0;

create or replace function public.calculate_equipment_resale_value_v1(p_purchase_price bigint,p_condition smallint,p_resale_modifier numeric) returns bigint language sql immutable set search_path='public' as $$ select greatest(0::bigint,floor(greatest(coalesce(p_purchase_price,0),0)::numeric*0.65*(least(greatest(coalesce(p_condition,0),0),100)::numeric/100.0)*least(greatest(coalesce(p_resale_modifier,0),0),1))::bigint); $$;

create or replace function public.purchase_equipment_item_v2(p_catalog_item_id uuid,p_request_key text) returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; c public.equipment_catalog_items%rowtype; v_inventory uuid:=gen_random_uuid(); v_existing public.player_equipment_inventory%rowtype; v_abs integer; v_key text:=btrim(coalesce(p_request_key,'')); v_balance bigint:=0; f jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if;
  if length(v_key)<8 or length(v_key)>128 then raise exception 'Invalid purchase request key.'; end if;
  perform pg_advisory_xact_lock(hashtextextended('equipment-purchase:'||v_player::text||':'||v_key,0));
  select * into v_existing from public.player_equipment_inventory where player_id=v_player and purchase_request_key=v_key limit 1;
  if v_existing.id is not null then perform public.ensure_player_career_finance_v1(v_player); select balance into v_balance from public.player_career_finance_accounts where player_id=v_player; return jsonb_build_object('status','already_purchased','inventory_id',v_existing.id,'price_usd',v_existing.purchase_price_usd,'balance',coalesce(v_balance,0)); end if;
  select * into c from public.equipment_catalog_items where id=p_catalog_item_id and is_active and availability_status='available'; if c.id is null then raise exception 'Equipment item not available.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  f:=public.post_career_finance_transaction_v1(v_player,-c.price_usd,'equipment',c.item_type,'Equipment purchase — '||c.brand||' '||c.model,'equipment_catalog',c.id::text,'equipment-purchase:'||v_player::text||':'||v_key,jsonb_build_object('catalog_item_id',c.id,'sku',c.sku,'brand',c.brand,'model',c.model,'item_type',c.item_type,'purchase_request_key',v_key),true,v_abs);
  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source,purchase_price_usd,purchase_request_key) values(v_inventory,v_player,c.id,100,v_abs,'purchase',c.price_usd,v_key);
  return jsonb_build_object('status','purchased','inventory_id',v_inventory,'item_type',c.item_type,'price_usd',c.price_usd,'balance',f->'balance');
end; $$;

create or replace function public.purchase_equipment_item_v1(p_catalog_item_id uuid) returns jsonb language plpgsql security definer set search_path='public' as $$ begin return public.purchase_equipment_item_v2(p_catalog_item_id,gen_random_uuid()::text); end; $$;

create or replace function public.sell_equipment_item_v1(p_inventory_id uuid) returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; i public.player_equipment_inventory%rowtype; c public.equipment_catalog_items%rowtype; l public.player_equipment_loadouts%rowtype; v_resale bigint; v_abs integer; f jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if;
  perform public.initialize_player_equipment_v1(v_player);
  select inv.* into i from public.player_equipment_inventory inv where inv.id=p_inventory_id and inv.player_id=v_player for update; if i.id is null then raise exception 'Equipment item not owned.'; end if;
  select * into c from public.equipment_catalog_items where id=i.catalog_item_id; if c.id is null then raise exception 'Equipment definition not found.'; end if;
  if i.acquired_source<>'purchase' then raise exception 'Starter, sponsored and reward equipment cannot be sold.'; end if;
  if not c.is_resellable then raise exception 'This equipment item cannot be resold.'; end if;
  select * into l from public.player_equipment_loadouts where player_id=v_player;
  if p_inventory_id=l.racket_inventory_id or p_inventory_id=l.string_inventory_id or p_inventory_id=l.shoes_inventory_id then raise exception 'This item is currently equipped. Equip a replacement before selling it.'; end if;
  v_resale:=public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier); if v_resale<=0 then raise exception 'This equipment has no resale value.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  f:=public.post_career_finance_transaction_v1(v_player,v_resale,'equipment',c.item_type,'Equipment sale — '||c.brand||' '||c.model,'equipment_inventory',i.id::text,'equipment-sale:'||i.id::text,jsonb_build_object('catalog_item_id',c.id,'inventory_id',i.id,'sku',c.sku,'brand',c.brand,'model',c.model,'item_type',c.item_type,'purchase_price_usd',i.purchase_price_usd,'condition',i.condition,'resale_modifier',c.resale_modifier),false,v_abs);
  delete from public.player_equipment_inventory where id=i.id and player_id=v_player;
  return jsonb_build_object('status','sold','inventory_id',i.id,'item_type',c.item_type,'sale_price_usd',v_resale,'balance',f->'balance');
end; $$;

create or replace function public.get_equipment_dashboard_v1() returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; v_balance bigint:=0; v_loadout jsonb; v_inventory jsonb; v_catalog jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if;
  perform public.initialize_player_equipment_v1(v_player); perform public.ensure_player_career_finance_v1(v_player); select balance into v_balance from public.player_career_finance_accounts where player_id=v_player;
  select jsonb_build_object('string_tension_kg',l.string_tension_kg,'apparel_brand',l.apparel_brand,'racket_sponsor_name',l.racket_sponsor_name,'apparel_sponsor_name',l.apparel_sponsor_name,'footwear_sponsor_name',l.footwear_sponsor_name,'racket',case when ri.id is null then null else jsonb_build_object('inventory_id',ri.id,'condition',ri.condition,'item',to_jsonb(rc)) end,'string',case when si.id is null then null else jsonb_build_object('inventory_id',si.id,'condition',si.condition,'item',to_jsonb(sc)) end,'shoes',case when shi.id is null then null else jsonb_build_object('inventory_id',shi.id,'condition',shi.condition,'item',to_jsonb(shc)) end) into v_loadout from public.player_equipment_loadouts l left join public.player_equipment_inventory ri on ri.id=l.racket_inventory_id and ri.player_id=l.player_id left join public.equipment_catalog_items rc on rc.id=ri.catalog_item_id left join public.player_equipment_inventory si on si.id=l.string_inventory_id and si.player_id=l.player_id left join public.equipment_catalog_items sc on sc.id=si.catalog_item_id left join public.player_equipment_inventory shi on shi.id=l.shoes_inventory_id and shi.player_id=l.player_id left join public.equipment_catalog_items shc on shc.id=shi.catalog_item_id where l.player_id=v_player;
  select coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.id,'condition',i.condition,'acquired_source',i.acquired_source,'acquired_absolute_day',i.acquired_absolute_day,'purchase_price_usd',i.purchase_price_usd,'is_equipped',(coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.string_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false)),'resell_supported',(i.acquired_source='purchase' and c.is_resellable),'can_sell',(i.acquired_source='purchase' and c.is_resellable and not (coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.string_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false)) and public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier)>0),'sell_block_reason',case when i.acquired_source<>'purchase' then 'Starter, sponsored and reward equipment cannot be sold.' when not c.is_resellable then 'This equipment item cannot be resold.' when coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.string_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false) then 'Equip a replacement before selling this item.' when public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier)<=0 then 'This equipment has no resale value.' else null end,'resale_value_usd',public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier),'item',to_jsonb(c)) order by c.item_type,c.sort_order,i.created_at),'[]'::jsonb) into v_inventory from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id join public.player_equipment_loadouts l on l.player_id=i.player_id where i.player_id=v_player;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.item_type,c.sort_order),'[]'::jsonb) into v_catalog from public.equipment_catalog_items c where c.is_active;
  return jsonb_build_object('player_id',v_player,'currency','USD','balance',coalesce(v_balance,0),'loadout',coalesce(v_loadout,'{}'::jsonb),'inventory',v_inventory,'catalog',v_catalog,'resale_base_percent',65,'effects',jsonb_build_object('hard',public.get_equipment_match_modifiers_internal_v1(v_player,'hard'),'clay',public.get_equipment_match_modifiers_internal_v1(v_player,'clay'),'grass',public.get_equipment_match_modifiers_internal_v1(v_player,'grass')),'wear_rules',jsonb_build_object('racket_per_match',1,'strings_per_match',10,'shoes_surface_specific',3,'shoes_all_court',4,'shoes_wrong_surface',5));
end; $$;

revoke all on function public.calculate_equipment_resale_value_v1(bigint,smallint,numeric) from public,anon,authenticated;
revoke all on function public.purchase_equipment_item_v2(uuid,text) from public,anon;
revoke all on function public.sell_equipment_item_v1(uuid) from public,anon;
revoke all on function public.purchase_equipment_item_v1(uuid) from public,anon;
revoke all on function public.get_equipment_dashboard_v1() from public,anon;
grant execute on function public.purchase_equipment_item_v2(uuid,text) to authenticated;
grant execute on function public.sell_equipment_item_v1(uuid) to authenticated;
grant execute on function public.purchase_equipment_item_v1(uuid) to authenticated;
grant execute on function public.get_equipment_dashboard_v1() to authenticated;
