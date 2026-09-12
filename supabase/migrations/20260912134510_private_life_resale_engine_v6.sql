create or replace function public.private_life_sale_wait_days_v1(p_sale_mode text)
returns integer language sql immutable set search_path='public' as $$
  select case lower(coalesce(p_sale_mode,'standard')) when 'urgent' then 0 when 'standard' then 7 when 'patient' then 21 else 7 end;
$$;

create or replace function public.private_life_sale_price_v2(p_market_value bigint,p_base_resale_discount_bps integer,p_sale_mode text)
returns bigint language sql immutable set search_path='public' as $$
  select greatest(1::bigint,round(greatest(1,p_market_value)::numeric * (10000 - case lower(coalesce(p_sale_mode,'standard')) when 'urgent' then least(5000,greatest(0,p_base_resale_discount_bps)+1200) when 'patient' then greatest(500,greatest(0,p_base_resale_discount_bps)-400) else greatest(0,p_base_resale_discount_bps) end)::numeric / 10000)::bigint);
$$;
revoke all on function public.private_life_sale_wait_days_v1(text) from public,anon,authenticated;
revoke all on function public.private_life_sale_price_v2(bigint,integer,text) from public,anon,authenticated;

create or replace function public.settle_private_life_asset_sale_listing_v1(p_listing_id uuid)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_listing public.private_life_asset_sale_listings%rowtype;
  v_owned public.private_life_player_assets%rowtype;
  v_asset public.private_life_asset_catalog%rowtype;
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
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  v_fin:=public.post_career_finance_transaction_v1(v_listing.player_id,v_listing.quoted_sale_price,'private_life','sale_'||v_asset.category,'Private Life sale: '||v_asset.name,'private_life_asset',v_owned.id::text,'private-life-sale-listing:'||v_listing.id::text,jsonb_build_object('listing_id',v_listing.id,'sale_mode',v_listing.sale_mode,'catalog_code',v_asset.code,'category',v_asset.category,'purchase_price',v_owned.purchase_price,'quoted_market_value',v_listing.quoted_market_value,'sale_price',v_listing.quoted_sale_price,'gain_loss',v_listing.quoted_sale_price-v_owned.purchase_price),false,v_abs);
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets set sold_absolute_day=v_abs,sold_price=v_listing.quoted_sale_price,sale_transaction_id=v_tx,updated_at=now() where id=v_owned.id;
  update public.private_life_asset_sale_listings set status='completed',finance_transaction_id=v_tx,completed_at=now(),updated_at=now() where id=v_listing.id;
  return jsonb_build_object('status','sold','listing_id',v_listing.id,'owned_asset_id',v_owned.id,'sale_mode',v_listing.sale_mode,'sale_price',v_listing.quoted_sale_price,'gain_loss',v_listing.quoted_sale_price-v_owned.purchase_price,'balance',v_fin->'balance');
end;
$$;
revoke all on function public.settle_private_life_asset_sale_listing_v1(uuid) from public,anon,authenticated;

create or replace function public.list_private_life_asset_for_sale_v1(p_owned_asset_id uuid,p_sale_mode text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player uuid; v_owned public.private_life_player_assets%rowtype; v_asset public.private_life_asset_catalog%rowtype;
  v_abs integer; gd record; v_market bigint; v_discount integer; v_sale bigint; v_wait integer; v_listing_id uuid:=gen_random_uuid();
begin
  v_player:=public.private_life_current_player_v1();
  if lower(coalesce(p_sale_mode,'')) not in ('urgent','standard','patient') then raise exception 'Sale mode must be urgent, standard or patient.'; end if;
  select * into v_owned from public.private_life_player_assets where id=p_owned_asset_id and player_id=v_player and sold_absolute_day is null for update;
  if v_owned.id is null then raise exception 'Owned lifestyle asset not found.'; end if;
  if exists(select 1 from public.private_life_asset_sale_listings where player_asset_id=v_owned.id and status='pending') then raise exception 'This asset is already listed for sale.'; end if;
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_market:=public.private_life_market_value_v1(v_owned.purchase_price,coalesce(v_owned.annual_value_rate_bps_override,v_asset.annual_value_rate_bps),v_owned.purchase_absolute_day,v_abs);
  v_discount:=coalesce(v_owned.resale_discount_bps_override,v_asset.resale_discount_bps);
  v_sale:=public.private_life_sale_price_v2(v_market,v_discount,lower(p_sale_mode));
  v_wait:=public.private_life_sale_wait_days_v1(lower(p_sale_mode));
  insert into public.private_life_asset_sale_listings(id,player_id,player_asset_id,sale_mode,listed_absolute_day,settle_absolute_day,quoted_market_value,quoted_sale_price) values(v_listing_id,v_player,v_owned.id,lower(p_sale_mode),v_abs,v_abs+v_wait,v_market,v_sale);
  if v_wait=0 then return public.settle_private_life_asset_sale_listing_v1(v_listing_id); end if;
  return jsonb_build_object('status','listed','listing_id',v_listing_id,'owned_asset_id',v_owned.id,'sale_mode',lower(p_sale_mode),'quoted_market_value',v_market,'quoted_sale_price',v_sale,'wait_days',v_wait,'settle_absolute_day',v_abs+v_wait);
end;
$$;
revoke all on function public.list_private_life_asset_for_sale_v1(uuid,text) from public,anon;
grant execute on function public.list_private_life_asset_for_sale_v1(uuid,text) to authenticated;

create or replace function public.cancel_private_life_asset_sale_v1(p_listing_id uuid)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_player uuid; v_listing public.private_life_asset_sale_listings%rowtype;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_listing from public.private_life_asset_sale_listings where id=p_listing_id and player_id=v_player for update;
  if v_listing.id is null then raise exception 'Private Life sale listing not found.'; end if;
  if v_listing.status<>'pending' then raise exception 'Only pending sale listings can be cancelled.'; end if;
  update public.private_life_asset_sale_listings set status='cancelled',cancelled_at=now(),updated_at=now() where id=v_listing.id;
  return jsonb_build_object('status','cancelled','listing_id',v_listing.id,'player_asset_id',v_listing.player_asset_id);
end;
$$;
revoke all on function public.cancel_private_life_asset_sale_v1(uuid) from public,anon;
grant execute on function public.cancel_private_life_asset_sale_v1(uuid) to authenticated;

create or replace function public.process_private_life_asset_sales_to_current_v1()
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare gd record; v_abs integer; r record; v_result jsonb; v_count integer:=0;
begin
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  for r in select id from public.private_life_asset_sale_listings where status='pending' and settle_absolute_day<=v_abs order by settle_absolute_day,created_at loop
    v_result:=public.settle_private_life_asset_sale_listing_v1(r.id);
    if v_result->>'status'='sold' then v_count:=v_count+1; end if;
  end loop;
  return jsonb_build_object('status','processed','completed_sales',v_count,'through_absolute_day',v_abs);
end;
$$;
revoke all on function public.process_private_life_asset_sales_to_current_v1() from public,anon,authenticated;

create or replace function public.sell_private_life_asset_v1(p_owned_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$ begin return public.list_private_life_asset_for_sale_v1(p_owned_asset_id,'urgent'); end; $$;
revoke all on function public.sell_private_life_asset_v1(uuid) from public,anon;
grant execute on function public.sell_private_life_asset_v1(uuid) to authenticated;