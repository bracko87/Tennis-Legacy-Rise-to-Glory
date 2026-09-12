create or replace function public.ensure_private_life_starter_home_v1(p_player_id uuid)
returns uuid language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player record; v_existing uuid; v_location public.private_life_property_locations%rowtype;
  v_location_code text; v_price bigint; v_owned_id uuid:=gen_random_uuid();
begin
  select id,owner_user_id,country_code,home_city into v_player from public.players where id=p_player_id;
  if v_player.id is null or v_player.owner_user_id is null or v_player.home_city is null or btrim(v_player.home_city)='' then return null; end if;
  select id into v_existing from public.private_life_player_assets where player_id=p_player_id and catalog_code='apt_home_starter' and sold_absolute_day is null limit 1;
  if v_existing is not null then return v_existing; end if;
  select * into v_location from public.private_life_property_locations where active=true and upper(country_code)=upper(coalesce(v_player.country_code,'')) and lower(city)=lower(v_player.home_city) limit 1;
  if v_location.code is null then
    v_location_code:='home_'||replace(p_player_id::text,'-','');
    insert into public.private_life_property_locations(code,country_code,country_name,city,apartment_base_price,house_base_price,annual_value_rate_bps,marketplace_enabled,active,sort_order)
    values(v_location_code,upper(coalesce(v_player.country_code,'XX')),upper(coalesce(v_player.country_code,'XX')),v_player.home_city,120000,300000,225,false,true,9999)
    on conflict (code) do nothing;
    select * into v_location from public.private_life_property_locations where code=v_location_code;
  end if;
  v_price:=greatest(1,round(v_location.apartment_base_price::numeric*0.60)::bigint);
  insert into public.private_life_player_assets(id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,prestige_override)
  values(v_owned_id,p_player_id,'apt_home_starter',v_location.code,'starter_home',0,v_price,0,v_location.annual_value_rate_bps,1200,0);
  return v_owned_id;
end;
$$;
revoke all on function public.ensure_private_life_starter_home_v1(uuid) from public,anon,authenticated;

create or replace function public.trg_ensure_private_life_starter_home_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
begin
  if new.owner_user_id is not null and new.home_city is not null and btrim(new.home_city)<>'' then perform public.ensure_private_life_starter_home_v1(new.id); end if;
  return new;
end;
$$;
revoke all on function public.trg_ensure_private_life_starter_home_v1() from public,anon,authenticated;
drop trigger if exists ensure_private_life_starter_home_v1 on public.players;
create trigger ensure_private_life_starter_home_v1 after insert or update of owner_user_id,country_code,home_city on public.players for each row execute function public.trg_ensure_private_life_starter_home_v1();

do $$ declare r record; begin
  for r in select id from public.players where owner_user_id is not null and home_city is not null and btrim(home_city)<>'' loop
    perform public.ensure_private_life_starter_home_v1(r.id);
  end loop;
end $$;

create or replace function public.buy_private_life_asset_v2(p_catalog_code text,p_location_code text default null)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player uuid; v_asset public.private_life_asset_catalog%rowtype; v_location public.private_life_property_locations%rowtype;
  v_owned_id uuid:=gen_random_uuid(); v_abs integer; gd record; v_fin jsonb; v_tx uuid;
  v_location_priced boolean:=false; v_multiplier integer:=10000; v_running_bps integer:=0; v_rate_adjustment integer:=0;
  v_price bigint; v_running bigint; v_rate integer;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_asset from public.private_life_asset_catalog where code=p_catalog_code and active=true;
  if v_asset.code is null then raise exception 'Lifestyle asset not found.'; end if;
  v_location_priced:=coalesce((v_asset.metadata->>'location_priced')::boolean,false);
  if v_location_priced then
    if p_location_code is null or btrim(p_location_code)='' then raise exception 'Choose a property location.'; end if;
    select * into v_location from public.private_life_property_locations where code=p_location_code and active=true and marketplace_enabled=true;
    if v_location.code is null then raise exception 'Property location not found.'; end if;
    v_multiplier:=coalesce((v_asset.metadata->>'price_multiplier_bps')::integer,10000);
    v_running_bps:=coalesce((v_asset.metadata->>'running_cost_bps')::integer,100);
    v_rate_adjustment:=coalesce((v_asset.metadata->>'value_rate_adjustment_bps')::integer,0);
    if v_asset.category='apartment' then v_price:=round(v_location.apartment_base_price::numeric*v_multiplier::numeric/10000)::bigint;
    elsif v_asset.category='house_villa' then v_price:=round(v_location.house_base_price::numeric*v_multiplier::numeric/10000)::bigint;
    else raise exception 'Location pricing is only supported for property assets.'; end if;
    v_running:=greatest(0,round(v_price::numeric*v_running_bps::numeric/10000)::bigint);
    v_rate:=greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment));
    if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=v_asset.code and location_code=v_location.code and sold_absolute_day is null) then raise exception 'You already own this property type in this city.'; end if;
  else
    v_price:=v_asset.purchase_price; v_running:=v_asset.annual_running_cost; v_rate:=v_asset.annual_value_rate_bps;
    if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=v_asset.code and location_code is null and sold_absolute_day is null) then raise exception 'You already own this asset.'; end if;
  end if;
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  insert into public.private_life_player_assets(id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,prestige_override)
  values(v_owned_id,v_player,v_asset.code,case when v_location_priced then v_location.code else null end,'purchase',v_abs,v_price,case when v_location_priced then v_running else null end,case when v_location_priced then v_rate else null end,case when v_location_priced then v_asset.resale_discount_bps else null end,case when v_location_priced then v_asset.prestige else null end);
  v_fin:=public.post_career_finance_transaction_v1(v_player,-v_price,'private_life','purchase_'||v_asset.category,'Private Life purchase: '||v_asset.name||case when v_location_priced then ' · '||v_location.city else '' end,'private_life_asset',v_owned_id::text,'private-life-purchase:'||v_owned_id::text,jsonb_build_object('catalog_code',v_asset.code,'category',v_asset.category,'location_code',case when v_location_priced then v_location.code else null end,'city',case when v_location_priced then v_location.city else null end,'country_code',case when v_location_priced then v_location.country_code else null end,'prestige',v_asset.prestige,'annual_running_cost',v_running),true,v_abs);
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets set purchase_transaction_id=v_tx,updated_at=now() where id=v_owned_id;
  return jsonb_build_object('status','purchased','owned_asset_id',v_owned_id,'catalog_code',v_asset.code,'name',v_asset.name,'location_code',case when v_location_priced then v_location.code else null end,'city',case when v_location_priced then v_location.city else null end,'price',v_price,'prestige',v_asset.prestige,'balance',v_fin->'balance');
end;
$$;
revoke all on function public.buy_private_life_asset_v2(text,text) from public,anon;
grant execute on function public.buy_private_life_asset_v2(text,text) to authenticated;

create or replace function public.buy_private_life_asset_v1(p_catalog_code text)
returns jsonb language plpgsql security definer set search_path='public' as $$ begin return public.buy_private_life_asset_v2(p_catalog_code,null); end; $$;
revoke all on function public.buy_private_life_asset_v1(text) from public,anon;
grant execute on function public.buy_private_life_asset_v1(text) to authenticated;

create or replace function public.process_private_life_running_costs_for_player_v1(p_player_id uuid,p_through_absolute_day integer)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare r record; v_cost bigint; v_fin jsonb; v_tx uuid; v_count integer:=0; v_total bigint:=0; v_user_id uuid; v_event_key text;
begin
  select owner_user_id into v_user_id from public.players where id=p_player_id;
  if v_user_id is null then return jsonb_build_object('status','skipped','reason','player_not_found_or_not_human','events',0,'total_cost',0); end if;
  for r in
    select o.id as player_asset_id,o.catalog_code,c.category,c.name,coalesce(o.annual_running_cost_override,c.annual_running_cost) as annual_running_cost,due.absolute_day,due.season,due.month
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    cross join lateral (select gs::integer as absolute_day,gd.season,gd.month from generate_series(o.purchase_absolute_day+1,least(p_through_absolute_day,coalesce(o.sold_absolute_day-1,p_through_absolute_day))) gs cross join lateral public.absolute_game_day_v1(gs::integer) gd where gd.day=1) due
    where o.player_id=p_player_id and coalesce(o.annual_running_cost_override,c.annual_running_cost)>0 and o.purchase_absolute_day<p_through_absolute_day
    order by due.absolute_day,o.created_at,o.id
  loop
    v_event_key:='running_cost:'||r.season::text||':'||r.month::text;
    if exists(select 1 from public.private_life_asset_events e where e.player_asset_id=r.player_asset_id and e.event_key=v_event_key) then continue; end if;
    v_cost:=greatest(1,round(r.annual_running_cost::numeric/12)::bigint);
    v_fin:=public.post_career_finance_transaction_v1(p_player_id,-v_cost,'private_life','running_cost_'||r.category,'Private Life ownership cost: '||r.name,'private_life_asset',r.player_asset_id::text||':'||r.season::text||':'||r.month::text,'private-life-running:'||r.player_asset_id::text||':'||r.season::text||':'||r.month::text,jsonb_build_object('player_asset_id',r.player_asset_id,'catalog_code',r.catalog_code,'category',r.category,'annual_running_cost',r.annual_running_cost,'season',r.season,'month',r.month),true,r.absolute_day);
    v_tx:=(v_fin->>'transaction_id')::uuid;
    insert into public.private_life_asset_events(player_id,player_asset_id,event_type,event_absolute_day,amount,finance_transaction_id,event_key,title,description,metadata)
    values(p_player_id,r.player_asset_id,'running_cost',r.absolute_day,-v_cost,v_tx,v_event_key,'Ownership cost paid','Monthly ownership cost for '||r.name||'.',jsonb_build_object('catalog_code',r.catalog_code,'category',r.category,'season',r.season,'month',r.month,'annual_running_cost',r.annual_running_cost)) on conflict(player_asset_id,event_key) do nothing;
    v_count:=v_count+1; v_total:=v_total+v_cost;
  end loop;
  if v_total>0 then perform public.emit_notification_v1(v_user_id,p_player_id,'player.private_life.running_costs','Private Life ownership costs paid','Recurring ownership costs of $'||to_char(v_total,'FM999G999G999G990')||' were charged to your career Finance balance.','/game/private-life',jsonb_build_object('total_cost',v_total,'cost_events',v_count,'through_absolute_day',p_through_absolute_day),'private-life-running-costs:'||p_player_id::text||':'||p_through_absolute_day::text); end if;
  return jsonb_build_object('status','processed','events',v_count,'total_cost',v_total,'through_absolute_day',p_through_absolute_day);
end;
$$;
revoke all on function public.process_private_life_running_costs_for_player_v1(uuid,integer) from public,anon,authenticated;