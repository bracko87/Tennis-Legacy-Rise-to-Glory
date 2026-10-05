-- Keep all 50 fixed Private Life marketplace cities for every player.
-- If a player's home town is outside that fixed list, add it as one extra personal location.
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

  -- If the home town is already one of the fixed 50 marketplace cities,
  -- return the fixed list only; the home town is naturally already included.
  if v_core_home then
    return query
    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,l.sort_order
    from public.private_life_property_locations l
    where l.active=true and l.marketplace_enabled=true
    order by l.sort_order,l.country_name,l.city;
    return;
  end if;

  -- Otherwise create/resolve the player's personal home-town location.
  perform public.ensure_private_life_starter_home_v1(p_player_id);

  select o.location_code
  into v_home_location_code
  from public.private_life_player_assets o
  join public.private_life_property_locations l on l.code=o.location_code
  where o.player_id=p_player_id
    and o.acquisition_type='starter_home'
    and upper(l.country_code)=upper(coalesce(v_country_code,''))
    and lower(l.city)=lower(v_home_city)
  order by o.created_at
  limit 1;

  -- Return all 50 standard cities PLUS the user's personal home town.
  return query
  select x.code,x.country_code,x.country_name,x.city,x.apartment_base_price,x.house_base_price,x.annual_value_rate_bps,x.sort_order
  from (
    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,l.sort_order
    from public.private_life_property_locations l
    where l.active=true and l.marketplace_enabled=true

    union all

    select l.code,l.country_code,l.country_name,l.city,l.apartment_base_price,l.house_base_price,l.annual_value_rate_bps,0 as sort_order
    from public.private_life_property_locations l
    where l.code=v_home_location_code and l.active=true
  ) x
  order by x.sort_order,x.country_name,x.city;
end;
$function$;

revoke all on function public.private_life_property_locations_for_player_v1(uuid) from public,anon,authenticated;
