alter table public.private_life_player_assets add column if not exists trade_locked boolean not null default false;
alter table public.private_life_player_assets drop constraint if exists private_life_player_assets_acquisition_type_check;
alter table public.private_life_player_assets add constraint private_life_player_assets_acquisition_type_check check (acquisition_type in ('purchase','starter_home','ai_static'));

create or replace function public.ensure_ai_static_prestige_possession_v1(p_player_id uuid)
returns uuid language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  p public.players%rowtype; v_existing uuid; v_code text; v_asset public.private_life_asset_catalog%rowtype; v_id uuid:=gen_random_uuid(); v_slot integer;
begin
  select * into p from public.players where id=p_player_id and player_type='ai';
  if p.id is null then return null; end if;
  select id into v_existing from public.private_life_player_assets where player_id=p.id and acquisition_type='ai_static' and sold_absolute_day is null order by created_at limit 1;
  if v_existing is not null then return v_existing; end if;
  v_slot:=mod(coalesce(p.ai_profile_number,1),5);
  v_code:=case coalesce(p.ai_skill_tier,'standard')
    when 'elite' then case v_slot when 0 then 'car_hypercar' when 1 then 'watch_asterion_celestial' when 2 then 'jewelry_atelier_masterpiece' when 3 then 'art_museum_quality' else 'collectible_private_museum_room' end
    when 'human_equivalent' then case v_slot when 0 then 'car_asterion_track' when 1 then 'watch_marceau_no8' when 2 then 'jewelry_riviera_suite' when 3 then 'art_collector_sculpture' else 'collectible_multi_sport_trophy_lot' end
    when 'competitive' then case v_slot when 0 then 'car_caelus_roadster' when 1 then 'watch_kestrel_heritage' when 2 then 'jewelry_emerald_ring' when 3 then 'art_large_format_canvas' else 'collectible_match_worn_archive' end
    else case v_slot when 0 then 'car_velaris_touring' when 1 then 'watch_lume_hart_reserve' when 2 then 'jewelry_sapphire_cufflinks' when 3 then 'art_dual_canvas_set' else 'collectible_trophy_replica_archive' end
  end;
  select * into v_asset from public.private_life_asset_catalog where code=v_code and active=true;
  if v_asset.code is null then raise exception 'Configured AI prestige asset % is unavailable.',v_code; end if;
  insert into public.private_life_player_assets(id,player_id,catalog_code,purchase_absolute_day,purchase_price,acquisition_type,annual_running_cost_override,prestige_override,trade_locked)
  values(v_id,p.id,v_asset.code,0,v_asset.purchase_price,'ai_static',0,v_asset.prestige,true);
  return v_id;
end;
$$;
revoke all on function public.ensure_ai_static_prestige_possession_v1(uuid) from public,anon,authenticated;

create or replace function public.trg_ensure_ai_static_prestige_possession_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
begin
  if new.player_type='ai' then perform public.ensure_ai_static_prestige_possession_v1(new.id); end if;
  return new;
end;
$$;
revoke all on function public.trg_ensure_ai_static_prestige_possession_v1() from public,anon,authenticated;
drop trigger if exists ensure_ai_static_prestige_possession_v1 on public.players;
create trigger ensure_ai_static_prestige_possession_v1 after insert on public.players for each row execute function public.trg_ensure_ai_static_prestige_possession_v1();

do $$ declare r record; begin
  for r in select id from public.players where player_type='ai' order by id loop
    perform public.ensure_ai_static_prestige_possession_v1(r.id);
  end loop;
end $$;

create or replace function public.list_private_life_asset_for_sale_v1(p_owned_asset_id uuid,p_sale_mode text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player uuid; v_owned public.private_life_player_assets%rowtype; v_asset public.private_life_asset_catalog%rowtype;
  v_abs integer; gd record; v_market bigint; v_discount integer; v_sale bigint; v_wait integer; v_listing_id uuid:=gen_random_uuid(); v_other_available_residences integer:=0;
begin
  v_player:=public.private_life_current_player_v1();
  if lower(coalesce(p_sale_mode,'')) not in ('urgent','standard','patient') then raise exception 'Sale mode must be urgent, standard or patient.'; end if;
  select * into v_owned from public.private_life_player_assets where id=p_owned_asset_id and player_id=v_player and sold_absolute_day is null for update;
  if v_owned.id is null then raise exception 'Owned lifestyle asset not found.'; end if;
  if v_owned.trade_locked then raise exception 'This prestige possession is permanent and cannot be sold or traded.'; end if;
  if exists(select 1 from public.private_life_asset_sale_listings where player_asset_id=v_owned.id and status='pending') then raise exception 'This asset is already listed for sale.'; end if;
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  if v_asset.category in ('apartment','house_villa') then
    select count(*)::integer into v_other_available_residences
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player and o.id<>v_owned.id and o.sold_absolute_day is null and c.category in ('apartment','house_villa')
      and not exists(select 1 from public.private_life_asset_sale_listings s where s.player_asset_id=o.id and s.status='pending');
    if v_other_available_residences<1 then raise exception 'You must own another apartment, house or villa before selling your current residence.'; end if;
  end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_market:=public.private_life_owned_asset_market_value_v2(v_owned.id,v_abs);
  v_discount:=coalesce(v_owned.resale_discount_bps_override,v_asset.resale_discount_bps);
  v_sale:=public.private_life_sale_price_v2(v_market,v_discount,lower(p_sale_mode));
  v_wait:=public.private_life_sale_wait_days_v1(lower(p_sale_mode));
  insert into public.private_life_asset_sale_listings(id,player_id,player_asset_id,sale_mode,listed_absolute_day,settle_absolute_day,quoted_market_value,quoted_sale_price)
  values(v_listing_id,v_player,v_owned.id,lower(p_sale_mode),v_abs,v_abs+v_wait,v_market,v_sale);
  if v_wait=0 then return public.settle_private_life_asset_sale_listing_v1(v_listing_id); end if;
  return jsonb_build_object('status','listed','listing_id',v_listing_id,'owned_asset_id',v_owned.id,'sale_mode',lower(p_sale_mode),'quoted_market_value',v_market,'quoted_sale_price',v_sale,'wait_days',v_wait,'settle_absolute_day',v_abs+v_wait);
end;
$$;
revoke all on function public.list_private_life_asset_for_sale_v1(uuid,text) from public,anon;
grant execute on function public.list_private_life_asset_for_sale_v1(uuid,text) to authenticated;

create or replace function public.settle_private_life_asset_sale_listing_v1(p_listing_id uuid)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_listing public.private_life_asset_sale_listings%rowtype; v_owned public.private_life_player_assets%rowtype; v_asset public.private_life_asset_catalog%rowtype;
  v_abs integer; gd record; v_fin jsonb; v_tx uuid;
begin
  select * into v_listing from public.private_life_asset_sale_listings where id=p_listing_id for update;
  if v_listing.id is null then raise exception 'Private Life sale listing not found.'; end if;
  if v_listing.status='completed' then return jsonb_build_object('status','already_completed','listing_id',v_listing.id,'sale_price',v_listing.quoted_sale_price); end if;
  if v_listing.status<>'pending' then return jsonb_build_object('status',v_listing.status,'listing_id',v_listing.id); end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  if v_abs<v_listing.settle_absolute_day then return jsonb_build_object('status','pending','listing_id',v_listing.id,'settle_absolute_day',v_listing.settle_absolute_day); end if;
  select * into v_owned from public.private_life_player_assets where id=v_listing.player_asset_id and player_id=v_listing.player_id for update;
  if v_owned.id is null or v_owned.sold_absolute_day is not null then
    update public.private_life_asset_sale_listings set status='cancelled',cancelled_at=now(),updated_at=now() where id=v_listing.id;
    return jsonb_build_object('status','cancelled','reason','asset_no_longer_available','listing_id',v_listing.id);
  end if;
  if v_owned.trade_locked then
    update public.private_life_asset_sale_listings set status='cancelled',cancelled_at=now(),updated_at=now() where id=v_listing.id;
    return jsonb_build_object('status','cancelled','reason','trade_locked','listing_id',v_listing.id);
  end if;
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  v_fin:=public.post_career_finance_transaction_v1(v_listing.player_id,v_listing.quoted_sale_price,'private_life','sale_'||v_asset.category,'Private Life sale: '||v_asset.name,'private_life_asset',v_owned.id::text,'private-life-sale-listing:'||v_listing.id::text,jsonb_build_object('listing_id',v_listing.id,'sale_mode',v_listing.sale_mode,'catalog_code',v_asset.code,'category',v_asset.category,'purchase_price',v_owned.purchase_price,'quoted_market_value',v_listing.quoted_market_value,'sale_price',v_listing.quoted_sale_price,'gain_loss',v_listing.quoted_sale_price-v_owned.purchase_price),false,v_abs);
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets set sold_absolute_day=v_abs,sold_price=v_listing.quoted_sale_price,sale_transaction_id=v_tx,updated_at=now() where id=v_owned.id;
  update public.private_life_asset_sale_listings set status='completed',finance_transaction_id=v_tx,completed_at=now(),updated_at=now() where id=v_listing.id;
  return jsonb_build_object('status','sold','listing_id',v_listing.id,'owned_asset_id',v_owned.id,'sale_mode',v_listing.sale_mode,'sale_price',v_listing.quoted_sale_price,'gain_loss',v_listing.quoted_sale_price-v_owned.purchase_price,'balance',v_fin->'balance');
end;
$$;
revoke all on function public.settle_private_life_asset_sale_listing_v1(uuid) from public,anon,authenticated;

create or replace function public.get_player_private_life_summary_v1(p_player_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_abs integer; gd record; v_prestige integer:=0; v_asset_count integer:=0; v_asset_value bigint:=0; v_possessions jsonb:='[]'::jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found.'; end if;
  perform public.ensure_private_life_starter_home_v1(p_player_id);
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  select coalesce(sum(coalesce(o.prestige_override,c.prestige)),0)::integer,count(*)::integer,coalesce(sum(public.private_life_owned_asset_market_value_v2(o.id,v_abs)),0)::bigint
  into v_prestige,v_asset_count,v_asset_value
  from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code where o.player_id=p_player_id and o.sold_absolute_day is null;
  select coalesce(jsonb_agg(x order by x.prestige desc,x.name),'[]'::jsonb) into v_possessions
  from (
    select o.id,c.category,case when l.code is not null then c.name||' · '||l.city else c.name end as name,
      coalesce(o.prestige_override,c.prestige)::integer as prestige,o.acquisition_type,o.trade_locked,l.city,l.country_code,l.country_name,
      public.private_life_owned_asset_market_value_v2(o.id,v_abs) as current_market_value
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    left join public.private_life_property_locations l on l.code=o.location_code
    where o.player_id=p_player_id and o.sold_absolute_day is null
  ) x;
  return jsonb_build_object('player_id',p_player_id,'prestige_points',v_prestige,'asset_count',v_asset_count,'asset_value',v_asset_value,'possessions',v_possessions);
end;
$$;
revoke all on function public.get_player_private_life_summary_v1(uuid) from public,anon;
grant execute on function public.get_player_private_life_summary_v1(uuid) to authenticated;
