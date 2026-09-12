create or replace function public.ensure_private_life_starter_home_v1(p_player_id uuid)
returns uuid language plpgsql security definer set search_path='public','pg_temp' as $$
declare
  v_player record; v_existing uuid; v_location public.private_life_property_locations%rowtype;
  v_location_code text; v_price bigint; v_owned_id uuid:=gen_random_uuid();
begin
  select id,owner_user_id,country_code,home_city into v_player from public.players where id=p_player_id;
  if v_player.id is null or v_player.owner_user_id is null or v_player.home_city is null or btrim(v_player.home_city)='' then return null; end if;
  select id into v_existing from public.private_life_player_assets where player_id=p_player_id and catalog_code='apt_home_starter' order by created_at limit 1;
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