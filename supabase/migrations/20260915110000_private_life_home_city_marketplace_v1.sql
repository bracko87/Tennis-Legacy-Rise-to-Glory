create or replace function public.ensure_private_life_starter_home_v1(p_player_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player record;
  v_existing uuid;
  v_existing_location text;
  v_location public.private_life_property_locations%rowtype;
  v_location_code text;
  v_country_name text;
  v_price bigint;
  v_owned_id uuid:=gen_random_uuid();
begin
  select id,owner_user_id,player_type,country_code,home_city
  into v_player
  from public.players
  where id=p_player_id;

  if v_player.id is null or v_player.home_city is null or btrim(v_player.home_city)='' then
    return null;
  end if;

  select coalesce(c.name,upper(coalesce(v_player.country_code,'XX')))
  into v_country_name
  from public.countries c
  where upper(c.code)=upper(coalesce(v_player.country_code,''))
  limit 1;
  v_country_name:=coalesce(v_country_name,upper(coalesce(v_player.country_code,'XX')));

  select * into v_location
  from public.private_life_property_locations
  where active=true
    and upper(country_code)=upper(coalesce(v_player.country_code,''))
    and lower(city)=lower(v_player.home_city)
  order by marketplace_enabled desc,sort_order
  limit 1;

  if v_location.code is null then
    v_location_code:='home_'||replace(p_player_id::text,'-','');
    insert into public.private_life_property_locations(
      code,country_code,country_name,city,apartment_base_price,house_base_price,
      annual_value_rate_bps,marketplace_enabled,active,sort_order
    ) values(
      v_location_code,upper(coalesce(v_player.country_code,'XX')),v_country_name,
      v_player.home_city,120000,300000,225,false,true,9999
    ) on conflict (code) do update set
      country_code=excluded.country_code,
      country_name=excluded.country_name,
      city=excluded.city,
      active=true,
      updated_at=now();
    select * into v_location from public.private_life_property_locations where code=v_location_code;
  elsif not v_location.marketplace_enabled and v_location.country_name<>v_country_name then
    update public.private_life_property_locations
    set country_name=v_country_name,updated_at=now()
    where code=v_location.code;
    v_location.country_name:=v_country_name;
  end if;

  select id,location_code into v_existing,v_existing_location
  from public.private_life_player_assets
  where player_id=p_player_id and catalog_code='apt_home_starter' and sold_absolute_day is null
  order by created_at
  limit 1;

  v_price:=greatest(1,round(v_location.apartment_base_price::numeric*0.60)::bigint);

  if v_existing is not null then
    if v_existing_location is distinct from v_location.code then
      update public.private_life_player_assets
      set location_code=v_location.code,
          purchase_price=v_price,
          annual_value_rate_bps_override=v_location.annual_value_rate_bps,
          updated_at=now()
      where id=v_existing;
    end if;
    return v_existing;
  end if;

  insert into public.private_life_player_assets(
    id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,
    annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,
    prestige_override,trade_locked
  ) values(
    v_owned_id,p_player_id,'apt_home_starter',v_location.code,'starter_home',0,v_price,
    0,v_location.annual_value_rate_bps,1200,0,(v_player.player_type='ai')
  );

  return v_owned_id;
end;
$function$;

update public.private_life_property_locations l
set country_name=c.name,updated_at=now()
from public.countries c
where l.marketplace_enabled=false
  and upper(l.country_code)=upper(c.code)
  and l.country_name is distinct from c.name;

create or replace function public.private_life_property_locations_for_player_v1(p_player_id uuid)
returns table(
  code text,
  country_code text,
  country_name text,
  city text,
  apartment_base_price bigint,
  house_base_price bigint,
  annual_value_rate_bps integer,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_country_code text;
  v_home_city text;
  v_home_location_code text;
  v_core_home boolean:=false;
begin
  select p.country_code,p.home_city
  into v_country_code,v_home_city
  from public.players p
  where p.id=p_player_id;

  if v_home_city is null or btrim(v_home_city)='' then
    return query
    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,l.sort_order
    from public.private_life_property_locations l
    where l.active=true and l.marketplace_enabled=true
    order by l.sort_order,l.country_name,l.city;
    return;
  end if;

  select exists(
    select 1
    from public.private_life_property_locations l
    where l.active=true and l.marketplace_enabled=true
      and upper(l.country_code)=upper(coalesce(v_country_code,''))
      and lower(l.city)=lower(v_home_city)
  ) into v_core_home;

  if v_core_home then
    return query
    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,l.sort_order
    from public.private_life_property_locations l
    where l.active=true and l.marketplace_enabled=true
    order by l.sort_order,l.country_name,l.city;
    return;
  end if;

  perform public.ensure_private_life_starter_home_v1(p_player_id);

  select o.location_code
  into v_home_location_code
  from public.private_life_player_assets o
  join public.private_life_property_locations l on l.code=o.location_code
  where o.player_id=p_player_id
    and o.catalog_code='apt_home_starter'
    and o.sold_absolute_day is null
    and upper(l.country_code)=upper(coalesce(v_country_code,''))
    and lower(l.city)=lower(v_home_city)
  order by o.created_at
  limit 1;

  return query
  select x.code,x.country_code,x.country_name,x.city,x.apartment_base_price,x.house_base_price,x.annual_value_rate_bps,x.sort_order
  from (
    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,l.sort_order
    from public.private_life_property_locations l
    where l.active=true and l.marketplace_enabled=true and l.code<>'rs_belgrade'
    union all
    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,1 as sort_order
    from public.private_life_property_locations l
    where l.code=v_home_location_code and l.active=true
  ) x
  order by x.sort_order,x.country_name,x.city;
end;
$function$;

revoke all on function public.private_life_property_locations_for_player_v1(uuid) from public,anon,authenticated;

create or replace function public.get_private_life_dashboard_v3()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_base jsonb;
  v_player uuid;
  v_locations jsonb;
begin
  v_base:=public.get_private_life_dashboard_v2();
  v_player:=(v_base->>'player_id')::uuid;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'code',l.code,
      'country_code',l.country_code,
      'country_name',l.country_name,
      'city',l.city,
      'apartment_base_price',l.apartment_base_price,
      'house_base_price',l.house_base_price,
      'annual_value_rate_bps',l.annual_value_rate_bps,
      'sort_order',l.sort_order,
      'monthly_change_bps',hist.monthly_change_bps,
      'previous_apartment_base_price',hist.previous_apartment_base_price,
      'previous_house_base_price',hist.previous_house_base_price,
      'market_season',hist.season,
      'market_month',hist.month
    ) order by l.sort_order,l.country_name,l.city
  ),'[]'::jsonb)
  into v_locations
  from public.private_life_property_locations_for_player_v1(v_player) l
  left join lateral (
    select h.*
    from public.private_life_property_market_history h
    where h.location_code=l.code
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  return v_base || jsonb_build_object('property_locations',v_locations);
end;
$function$;

revoke all on function public.get_private_life_dashboard_v3() from public,anon,authenticated;

create or replace function public.get_private_life_dashboard_v1()
returns jsonb
language sql
security definer
set search_path to 'public','pg_temp'
as $function$
  select public.get_private_life_dashboard_v3();
$function$;

grant execute on function public.get_private_life_dashboard_v1() to authenticated;

create or replace function public.buy_private_life_asset_v2(p_catalog_code text,p_location_code text default null::text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player uuid; v_asset public.private_life_asset_catalog%rowtype; v_location public.private_life_property_locations%rowtype;
  v_owned_id uuid:=gen_random_uuid(); v_abs integer; gd record; v_fin jsonb; v_tx uuid;
  v_location_priced boolean:=false; v_multiplier integer:=10000; v_rate_adjustment integer:=0;
  v_price bigint; v_running bigint; v_rate integer;
begin
  v_player:=public.private_life_current_player_v1();
  select * into v_asset from public.private_life_asset_catalog where code=p_catalog_code and active=true;
  if v_asset.code is null then raise exception 'Lifestyle asset not found.'; end if;
  v_location_priced:=coalesce((v_asset.metadata->>'location_priced')::boolean,false);
  if v_location_priced then
    if p_location_code is null or btrim(p_location_code)='' then raise exception 'Choose a property location.'; end if;
    select l.* into v_location
    from public.private_life_property_locations l
    where l.code=p_location_code and l.active=true
      and (
        l.marketplace_enabled=true
        or exists(
          select 1 from public.players p
          where p.id=v_player
            and upper(p.country_code)=upper(l.country_code)
            and lower(p.home_city)=lower(l.city)
        )
      );
    if v_location.code is null then raise exception 'Property location not found.'; end if;
    v_multiplier:=coalesce((v_asset.metadata->>'price_multiplier_bps')::integer,10000);
    v_rate_adjustment:=coalesce((v_asset.metadata->>'value_rate_adjustment_bps')::integer,0);
    if v_asset.category='apartment' then v_price:=round(v_location.apartment_base_price::numeric*v_multiplier::numeric/10000)::bigint;
    elsif v_asset.category='house_villa' then v_price:=round(v_location.house_base_price::numeric*v_multiplier::numeric/10000)::bigint;
    else raise exception 'Location pricing is only supported for property assets.'; end if;
    v_rate:=greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment));
    if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=v_asset.code and location_code=v_location.code and sold_absolute_day is null) then raise exception 'You already own this property type in this city.'; end if;
  else
    v_price:=v_asset.purchase_price; v_rate:=v_asset.annual_value_rate_bps;
    if exists(select 1 from public.private_life_player_assets where player_id=v_player and catalog_code=v_asset.code and location_code is null and sold_absolute_day is null) then raise exception 'You already own this asset.'; end if;
  end if;
  v_running:=public.private_life_monthly_ownership_cost_v1(v_asset.category,v_price)*12;
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  insert into public.private_life_player_assets(id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,prestige_override)
  values(v_owned_id,v_player,v_asset.code,case when v_location_priced then v_location.code else null end,'purchase',v_abs,v_price,v_running,case when v_location_priced then v_rate else null end,case when v_location_priced then v_asset.resale_discount_bps else null end,case when v_location_priced then v_asset.prestige else null end);
  v_fin:=public.post_career_finance_transaction_v1(v_player,-v_price,'private_life','purchase_'||v_asset.category,'Private Life purchase: '||v_asset.name||case when v_location_priced then ' · '||v_location.city else '' end,'private_life_asset',v_owned_id::text,'private-life-purchase:'||v_owned_id::text,jsonb_build_object('catalog_code',v_asset.code,'category',v_asset.category,'location_code',case when v_location_priced then v_location.code else null end,'city',case when v_location_priced then v_location.city else null end,'country_code',case when v_location_priced then v_location.country_code else null end,'prestige',v_asset.prestige,'annual_running_cost',v_running,'monthly_ownership_cost',v_running/12),true,v_abs);
  v_tx:=(v_fin->>'transaction_id')::uuid;
  update public.private_life_player_assets set purchase_transaction_id=v_tx,updated_at=now() where id=v_owned_id;
  return jsonb_build_object('status','purchased','owned_asset_id',v_owned_id,'catalog_code',v_asset.code,'name',v_asset.name,'location_code',case when v_location_priced then v_location.code else null end,'city',case when v_location_priced then v_location.city else null end,'price',v_price,'prestige',v_asset.prestige,'monthly_ownership_cost',v_running/12,'balance',v_fin->'balance');
end;
$function$;

grant execute on function public.buy_private_life_asset_v2(text,text) to authenticated;