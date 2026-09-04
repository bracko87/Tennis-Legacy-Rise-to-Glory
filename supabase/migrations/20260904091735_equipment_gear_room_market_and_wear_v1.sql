create table if not exists public.equipment_catalog_items (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  item_type text not null check (item_type in ('racket','string','shoes')),
  brand text not null,
  model text not null,
  description text not null default '',
  price_usd bigint not null check (price_usd >= 0),
  tier smallint not null default 1 check (tier between 1 and 5),
  surface text null check (surface is null or surface in ('all','hard','clay','grass')),
  power smallint not null default 75 check (power between 0 and 100),
  control smallint not null default 75 check (control between 0 and 100),
  spin smallint not null default 75 check (spin between 0 and 100),
  comfort smallint not null default 75 check (comfort between 0 and 100),
  traction smallint not null default 75 check (traction between 0 and 100),
  stability smallint not null default 75 check (stability between 0 and 100),
  durability smallint not null default 75 check (durability between 0 and 100),
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(item_type, brand, model)
);

create table if not exists public.player_equipment_inventory (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  catalog_item_id uuid not null references public.equipment_catalog_items(id),
  condition smallint not null default 100 check (condition between 0 and 100),
  acquired_absolute_day integer not null,
  acquired_source text not null default 'purchase' check (acquired_source in ('starter','purchase','sponsor','reward')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists player_equipment_inventory_player_idx on public.player_equipment_inventory(player_id, created_at desc);

create table if not exists public.player_equipment_loadouts (
  player_id uuid primary key references public.players(id) on delete cascade,
  racket_inventory_id uuid null references public.player_equipment_inventory(id) on delete set null,
  string_inventory_id uuid null references public.player_equipment_inventory(id) on delete set null,
  shoes_inventory_id uuid null references public.player_equipment_inventory(id) on delete set null,
  string_tension_kg numeric(4,1) not null default 24.0 check (string_tension_kg between 20.0 and 28.0),
  apparel_brand text not null default 'Independent',
  racket_sponsor_name text null,
  apparel_sponsor_name text null,
  footwear_sponsor_name text null,
  updated_at timestamptz not null default now()
);

create table if not exists public.player_equipment_wear_events (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  match_id uuid not null references public.tournament_matches(id) on delete cascade,
  surface text null,
  racket_before smallint null,
  racket_after smallint null,
  string_before smallint null,
  string_after smallint null,
  shoes_before smallint null,
  shoes_after smallint null,
  created_at timestamptz not null default now(),
  unique(player_id, match_id)
);

alter table public.equipment_catalog_items enable row level security;
alter table public.player_equipment_inventory enable row level security;
alter table public.player_equipment_loadouts enable row level security;
alter table public.player_equipment_wear_events enable row level security;
revoke all on public.equipment_catalog_items from anon, authenticated;
revoke all on public.player_equipment_inventory from anon, authenticated;
revoke all on public.player_equipment_loadouts from anon, authenticated;
revoke all on public.player_equipment_wear_events from anon, authenticated;

insert into public.equipment_catalog_items
(sku,item_type,brand,model,description,price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,sort_order)
values
('RKT-START-100','racket','CourtForge','Balance 100','Balanced starter frame with forgiving response and neutral characteristics.',180,1,null,76,78,75,78,75,75,82,10),
('RKT-VOLT-98','racket','Voltis','Strike 98','Aggressive frame focused on first-strike power and spin.',260,2,null,86,76,82,68,75,75,80,20),
('RKT-AXIOM-97','racket','Axiom','Control 97','Precision-oriented frame for directional control and clean timing.',290,3,null,72,90,77,74,75,75,84,30),
('RKT-SPIN-100','racket','SpinArc','Tour 100','Open-pattern frame built around heavy spin and aggressive baseline shapes.',310,3,null,80,78,91,70,75,75,79,40),
('STR-COREPOLY-125','string','CoreLine','CorePoly 1.25','Durable polyester setup with strong control and spin response.',22,1,null,70,80,84,58,75,75,78,110),
('STR-SOFTMULTI-130','string','CoreLine','SoftMulti 1.30','Comfort-oriented multifilament with easy depth and softer impact.',25,1,null,82,68,66,90,75,75,60,120),
('STR-TOURHYBRID','string','Axiom','Tour Hybrid','Balanced hybrid setup combining control, spin and comfort.',32,2,null,78,82,80,78,75,75,72,130),
('STR-NATURALTOUCH','string','Heritage','Natural Touch','Premium natural-gut style setup emphasizing comfort and effortless power.',45,3,null,88,80,72,94,75,75,58,140),
('SHO-ALL-COURT','shoes','CourtFlex','All Court','Versatile all-surface shoe with balanced traction, comfort and durability.',110,1,'all',75,75,75,80,76,76,76,210),
('SHO-HARD-PRO','shoes','CourtFlex','HardGuard Pro','Hard-court shoe with high stability and abrasion resistance.',145,2,'hard',75,75,75,76,88,86,88,220),
('SHO-CLAY-PRO','shoes','CourtFlex','ClaySlide Pro','Clay-specific outsole for controlled sliding and reliable traction.',140,2,'clay',75,75,75,77,90,82,82,230),
('SHO-GRASS-PRO','shoes','CourtFlex','GrassGrip Pro','Grass-specific traction pattern for secure movement on low-friction courts.',155,2,'grass',75,75,75,76,92,84,72,240)
on conflict (sku) do update set item_type=excluded.item_type,brand=excluded.brand,model=excluded.model,description=excluded.description,price_usd=excluded.price_usd,tier=excluded.tier,surface=excluded.surface,power=excluded.power,control=excluded.control,spin=excluded.spin,comfort=excluded.comfort,traction=excluded.traction,stability=excluded.stability,durability=excluded.durability,sort_order=excluded.sort_order,is_active=true;

create or replace function public.initialize_player_equipment_v1(p_player_id uuid)
returns void language plpgsql security definer set search_path='public' as $$
declare v_abs integer; v_racket uuid; v_string uuid; v_shoes uuid;
begin
  if not exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id is not null) then return; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  insert into public.player_equipment_loadouts(player_id) values(p_player_id) on conflict(player_id) do nothing;
  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source)
  select gen_random_uuid(),p_player_id,c.id,100,v_abs,'starter' from public.equipment_catalog_items c
  where c.sku in ('RKT-START-100','STR-COREPOLY-125','SHO-ALL-COURT') and not exists(select 1 from public.player_equipment_inventory i where i.player_id=p_player_id and i.catalog_item_id=c.id and i.acquired_source='starter');
  select i.id into v_racket from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.player_id=p_player_id and c.sku='RKT-START-100' order by i.created_at limit 1;
  select i.id into v_string from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.player_id=p_player_id and c.sku='STR-COREPOLY-125' order by i.created_at limit 1;
  select i.id into v_shoes from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.player_id=p_player_id and c.sku='SHO-ALL-COURT' order by i.created_at limit 1;
  update public.player_equipment_loadouts set racket_inventory_id=coalesce(racket_inventory_id,v_racket),string_inventory_id=coalesce(string_inventory_id,v_string),shoes_inventory_id=coalesce(shoes_inventory_id,v_shoes),updated_at=now() where player_id=p_player_id;
end; $$;

create or replace function public.initialize_new_human_player_equipment_v1() returns trigger language plpgsql security definer set search_path='public' as $$
begin if new.owner_user_id is not null then perform public.initialize_player_equipment_v1(new.id); end if; return new; end; $$;
drop trigger if exists initialize_new_human_player_equipment_v1 on public.players;
create trigger initialize_new_human_player_equipment_v1 after insert on public.players for each row execute function public.initialize_new_human_player_equipment_v1();
select public.initialize_player_equipment_v1(p.id) from public.players p where p.owner_user_id is not null;

create or replace function public.get_equipment_match_modifiers_internal_v1(p_player_id uuid,p_surface text default 'hard') returns jsonb language plpgsql security definer set search_path='public' as $$
declare l public.player_equipment_loadouts%rowtype; r record; s record; sh record; v_surface text:=lower(coalesce(p_surface,'hard')); r_pen numeric:=0; s_pen numeric:=0; sh_pen numeric:=0; surface_bonus numeric:=0; v_power numeric:=0; v_control numeric:=0; v_spin numeric:=0; v_movement numeric:=0; v_comfort numeric:=0;
begin
  perform public.initialize_player_equipment_v1(p_player_id); select * into l from public.player_equipment_loadouts where player_id=p_player_id;
  select i.condition,c.* into r from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.racket_inventory_id and i.player_id=p_player_id;
  select i.condition,c.* into s from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.string_inventory_id and i.player_id=p_player_id;
  select i.condition,c.* into sh from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.shoes_inventory_id and i.player_id=p_player_id;
  r_pen:=case when coalesce(r.condition,100)>=70 then 0 when r.condition>=50 then -0.15 when r.condition>=30 then -0.40 else -0.80 end;
  s_pen:=case when coalesce(s.condition,100)>=70 then 0 when s.condition>=50 then -0.25 when s.condition>=30 then -0.60 else -1.20 end;
  sh_pen:=case when coalesce(sh.condition,100)>=70 then 0 when sh.condition>=50 then -0.20 when sh.condition>=30 then -0.50 else -0.90 end;
  surface_bonus:=case when sh.surface=v_surface then 0.45 when sh.surface='all' then 0.15 when sh.surface is null then 0 else -0.35 end;
  v_power:=((coalesce(r.power,75)-75)*0.04)+((coalesce(s.power,75)-75)*0.02)+((24-coalesce(l.string_tension_kg,24))*0.10)+r_pen+s_pen;
  v_control:=((coalesce(r.control,75)-75)*0.04)+((coalesce(s.control,75)-75)*0.02)+((coalesce(l.string_tension_kg,24)-24)*0.10)+r_pen+s_pen;
  v_spin:=((coalesce(r.spin,75)-75)*0.035)+((coalesce(s.spin,75)-75)*0.025)+r_pen+s_pen;
  v_movement:=((((coalesce(sh.traction,75)+coalesce(sh.stability,75))/2.0)-75)*0.035)+surface_bonus+sh_pen;
  v_comfort:=(((coalesce(r.comfort,75)+coalesce(s.comfort,75)+coalesce(sh.comfort,75))/3.0)-75)*0.02 + least(0,r_pen+s_pen+sh_pen)/3.0;
  return jsonb_build_object('surface',v_surface,'power_pct',round(v_power,2),'control_pct',round(v_control,2),'spin_pct',round(v_spin,2),'movement_pct',round(v_movement,2),'comfort_pct',round(v_comfort,2),'string_tension_kg',l.string_tension_kg,'racket_condition',coalesce(r.condition,0),'string_condition',coalesce(s.condition,0),'shoes_condition',coalesce(sh.condition,0),'shoe_surface',coalesce(sh.surface,'all'));
end; $$;

create or replace function public.get_equipment_dashboard_v1() returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; v_balance bigint:=0; v_loadout jsonb; v_inventory jsonb; v_catalog jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if;
  perform public.initialize_player_equipment_v1(v_player); perform public.ensure_player_career_finance_v1(v_player); select balance into v_balance from public.player_career_finance_accounts where player_id=v_player;
  select jsonb_build_object('string_tension_kg',l.string_tension_kg,'apparel_brand',l.apparel_brand,'racket_sponsor_name',l.racket_sponsor_name,'apparel_sponsor_name',l.apparel_sponsor_name,'footwear_sponsor_name',l.footwear_sponsor_name,'racket',case when ri.id is null then null else jsonb_build_object('inventory_id',ri.id,'condition',ri.condition,'item',to_jsonb(rc)) end,'string',case when si.id is null then null else jsonb_build_object('inventory_id',si.id,'condition',si.condition,'item',to_jsonb(sc)) end,'shoes',case when shi.id is null then null else jsonb_build_object('inventory_id',shi.id,'condition',shi.condition,'item',to_jsonb(shc)) end) into v_loadout
  from public.player_equipment_loadouts l left join public.player_equipment_inventory ri on ri.id=l.racket_inventory_id and ri.player_id=l.player_id left join public.equipment_catalog_items rc on rc.id=ri.catalog_item_id left join public.player_equipment_inventory si on si.id=l.string_inventory_id and si.player_id=l.player_id left join public.equipment_catalog_items sc on sc.id=si.catalog_item_id left join public.player_equipment_inventory shi on shi.id=l.shoes_inventory_id and shi.player_id=l.player_id left join public.equipment_catalog_items shc on shc.id=shi.catalog_item_id where l.player_id=v_player;
  select coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.id,'condition',i.condition,'acquired_source',i.acquired_source,'acquired_absolute_day',i.acquired_absolute_day,'item',to_jsonb(c)) order by c.item_type,c.sort_order,i.created_at),'[]'::jsonb) into v_inventory from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.player_id=v_player;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.item_type,c.sort_order),'[]'::jsonb) into v_catalog from public.equipment_catalog_items c where c.is_active;
  return jsonb_build_object('player_id',v_player,'currency','USD','balance',coalesce(v_balance,0),'loadout',coalesce(v_loadout,'{}'::jsonb),'inventory',v_inventory,'catalog',v_catalog,'effects',jsonb_build_object('hard',public.get_equipment_match_modifiers_internal_v1(v_player,'hard'),'clay',public.get_equipment_match_modifiers_internal_v1(v_player,'clay'),'grass',public.get_equipment_match_modifiers_internal_v1(v_player,'grass')),'wear_rules',jsonb_build_object('racket_per_match',1,'strings_per_match',10,'shoes_surface_specific',3,'shoes_all_court',4,'shoes_wrong_surface',5));
end; $$;

create or replace function public.purchase_equipment_item_v1(p_catalog_item_id uuid) returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; c public.equipment_catalog_items%rowtype; v_inventory uuid:=gen_random_uuid(); v_abs integer; f jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if;
  select * into c from public.equipment_catalog_items where id=p_catalog_item_id and is_active; if c.id is null then raise exception 'Equipment item not available.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  f:=public.post_career_finance_transaction_v1(v_player,-c.price_usd,'equipment',c.item_type,'Equipment purchase — '||c.brand||' '||c.model,'equipment_catalog',c.id::text,'equipment-purchase:'||v_inventory::text,jsonb_build_object('catalog_item_id',c.id,'sku',c.sku,'brand',c.brand,'model',c.model,'item_type',c.item_type),true,v_abs);
  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source) values(v_inventory,v_player,c.id,100,v_abs,'purchase');
  return jsonb_build_object('status','purchased','inventory_id',v_inventory,'item_type',c.item_type,'price_usd',c.price_usd,'balance',f->'balance');
end; $$;

create or replace function public.equip_equipment_item_v1(p_inventory_id uuid) returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; v_type text;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if; perform public.initialize_player_equipment_v1(v_player);
  select c.item_type into v_type from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=p_inventory_id and i.player_id=v_player; if v_type is null then raise exception 'Equipment item not owned.'; end if;
  if v_type='racket' then update public.player_equipment_loadouts set racket_inventory_id=p_inventory_id,updated_at=now() where player_id=v_player;
  elsif v_type='string' then update public.player_equipment_loadouts set string_inventory_id=p_inventory_id,updated_at=now() where player_id=v_player;
  elsif v_type='shoes' then update public.player_equipment_loadouts set shoes_inventory_id=p_inventory_id,updated_at=now() where player_id=v_player; else raise exception 'Unsupported equipment type.'; end if;
  return jsonb_build_object('status','equipped','inventory_id',p_inventory_id,'item_type',v_type);
end; $$;

create or replace function public.set_equipment_string_tension_v1(p_tension_kg numeric) returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; v_tension numeric(4,1);
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if;
  if p_tension_kg<20 or p_tension_kg>28 then raise exception 'String tension must be between 20 and 28 kg.'; end if; v_tension:=round(p_tension_kg,1); perform public.initialize_player_equipment_v1(v_player); update public.player_equipment_loadouts set string_tension_kg=v_tension,updated_at=now() where player_id=v_player; return jsonb_build_object('status','saved','string_tension_kg',v_tension);
end; $$;

create or replace function public.get_equipment_match_modifiers_v1(p_surface text default 'hard') returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_player uuid; begin select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1; if v_player is null then raise exception 'Player not found.'; end if; return public.get_equipment_match_modifiers_internal_v1(v_player,p_surface); end; $$;

create or replace function public.apply_equipment_match_wear_v1(p_player_id uuid,p_match_id uuid,p_surface text) returns jsonb language plpgsql security definer set search_path='public' as $$
declare l public.player_equipment_loadouts%rowtype; rb smallint; ra smallint; sb smallint; sa smallint; shb smallint; sha smallint; shoe_surface text; shoe_wear smallint:=4;
begin
  if exists(select 1 from public.player_equipment_wear_events where player_id=p_player_id and match_id=p_match_id) then return jsonb_build_object('status','already_applied'); end if;
  perform public.initialize_player_equipment_v1(p_player_id); select * into l from public.player_equipment_loadouts where player_id=p_player_id for update; if l.player_id is null then return jsonb_build_object('status','no_loadout'); end if;
  select condition into rb from public.player_equipment_inventory where id=l.racket_inventory_id and player_id=p_player_id for update; select condition into sb from public.player_equipment_inventory where id=l.string_inventory_id and player_id=p_player_id for update;
  select i.condition,c.surface into shb,shoe_surface from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id where i.id=l.shoes_inventory_id and i.player_id=p_player_id for update of i;
  ra:=greatest(0,coalesce(rb,0)-1); sa:=greatest(0,coalesce(sb,0)-10); shoe_wear:=case when shoe_surface=lower(coalesce(p_surface,'hard')) then 3 when shoe_surface='all' then 4 else 5 end; sha:=greatest(0,coalesce(shb,0)-shoe_wear);
  if l.racket_inventory_id is not null then update public.player_equipment_inventory set condition=ra,updated_at=now() where id=l.racket_inventory_id and player_id=p_player_id; end if; if l.string_inventory_id is not null then update public.player_equipment_inventory set condition=sa,updated_at=now() where id=l.string_inventory_id and player_id=p_player_id; end if; if l.shoes_inventory_id is not null then update public.player_equipment_inventory set condition=sha,updated_at=now() where id=l.shoes_inventory_id and player_id=p_player_id; end if;
  insert into public.player_equipment_wear_events(player_id,match_id,surface,racket_before,racket_after,string_before,string_after,shoes_before,shoes_after) values(p_player_id,p_match_id,lower(coalesce(p_surface,'hard')),rb,ra,sb,sa,shb,sha);
  return jsonb_build_object('status','applied','racket',jsonb_build_array(rb,ra),'string',jsonb_build_array(sb,sa),'shoes',jsonb_build_array(shb,sha));
end; $$;

create or replace function public.apply_equipment_wear_on_completed_match_v1() returns trigger language plpgsql security definer set search_path='public' as $$
declare v_surface text:='hard'; begin select s.surface into v_surface from public.tournament_world_competitions wc join public.tournament_editions e on e.id=wc.tournament_edition_id join public.tournament_series s on s.id=e.tournament_series_id where wc.id=new.competition_id; if new.player1_id is not null and exists(select 1 from public.players p where p.id=new.player1_id and p.owner_user_id is not null) then perform public.apply_equipment_match_wear_v1(new.player1_id,new.id,coalesce(v_surface,'hard')); end if; if new.player2_id is not null and exists(select 1 from public.players p where p.id=new.player2_id and p.owner_user_id is not null) then perform public.apply_equipment_match_wear_v1(new.player2_id,new.id,coalesce(v_surface,'hard')); end if; return new; end; $$;
drop trigger if exists apply_equipment_wear_on_completed_match_v1 on public.tournament_matches;
create trigger apply_equipment_wear_on_completed_match_v1 after update of status on public.tournament_matches for each row when (new.status='completed' and old.status is distinct from 'completed') execute function public.apply_equipment_wear_on_completed_match_v1();

revoke all on function public.initialize_player_equipment_v1(uuid) from public,anon,authenticated;
revoke all on function public.initialize_new_human_player_equipment_v1() from public,anon,authenticated;
revoke all on function public.get_equipment_match_modifiers_internal_v1(uuid,text) from public,anon,authenticated;
revoke all on function public.apply_equipment_match_wear_v1(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.apply_equipment_wear_on_completed_match_v1() from public,anon,authenticated;
revoke all on function public.get_equipment_dashboard_v1() from public,anon;
revoke all on function public.purchase_equipment_item_v1(uuid) from public,anon;
revoke all on function public.equip_equipment_item_v1(uuid) from public,anon;
revoke all on function public.set_equipment_string_tension_v1(numeric) from public,anon;
revoke all on function public.get_equipment_match_modifiers_v1(text) from public,anon;
grant execute on function public.get_equipment_dashboard_v1() to authenticated;
grant execute on function public.purchase_equipment_item_v1(uuid) to authenticated;
grant execute on function public.equip_equipment_item_v1(uuid) to authenticated;
grant execute on function public.set_equipment_string_tension_v1(numeric) to authenticated;
grant execute on function public.get_equipment_match_modifiers_v1(text) to authenticated;
