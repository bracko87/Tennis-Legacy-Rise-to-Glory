-- Keep a starting residence's acquisition value stable after it has been assigned.
create or replace function public.ensure_private_life_starter_home_v1(p_player_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player record;
  v_existing record;
  v_location public.private_life_property_locations%rowtype;
  v_location_code text;
  v_country_name text;
  v_price bigint;
  v_owned_id uuid:=gen_random_uuid();
  v_is_premium boolean:=false;
  v_baseline record;
  v_cheapest public.private_life_asset_catalog%rowtype;
  v_multiplier integer:=10000;
  v_rate_adjustment integer:=0;
begin
  select id,owner_user_id,player_type,country_code,home_city
  into v_player
  from public.players
  where id=p_player_id;

  if v_player.id is null or v_player.home_city is null or btrim(v_player.home_city)='' then
    return null;
  end if;

  if v_player.player_type='human' then
    if v_player.owner_user_id is null then return null; end if;

    select exists(
      select 1
      from public.premium_memberships pm
      where pm.user_id=v_player.owner_user_id
        and pm.plan_code='premium'
        and pm.status='active'
        and (pm.current_period_end is null or pm.current_period_end>now())
    ) into v_is_premium;

    if not v_is_premium then
      return null;
    end if;
  end if;

  select *
  into v_cheapest
  from public.private_life_asset_catalog c
  where c.category='apartment'
    and c.active=true
    and coalesce((c.metadata->>'location_priced')::boolean,false)=true
  order by coalesce((c.metadata->>'price_multiplier_bps')::integer,10000),c.purchase_price,c.code
  limit 1;

  if v_cheapest.code is null then
    raise exception 'No active apartment is available for the starting residence.';
  end if;

  v_multiplier:=coalesce((v_cheapest.metadata->>'price_multiplier_bps')::integer,10000);
  v_rate_adjustment:=coalesce((v_cheapest.metadata->>'value_rate_adjustment_bps')::integer,0);

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
    select * into v_baseline
    from public.private_life_country_property_baseline_v1(v_player.country_code);

    if v_baseline.tier is null then
      select * into v_baseline
      from public.private_life_property_price_tiers
      where tier=4;
    end if;

    v_location_code:='home_'||replace(p_player_id::text,'-','');
    insert into public.private_life_property_locations(
      code,country_code,country_name,city,apartment_base_price,house_base_price,
      annual_value_rate_bps,marketplace_enabled,active,sort_order
    ) values(
      v_location_code,
      upper(coalesce(v_player.country_code,'XX')),
      v_country_name,
      v_player.home_city,
      v_baseline.apartment_base_price,
      v_baseline.house_base_price,
      v_baseline.annual_value_rate_bps,
      false,true,9999
    )
    on conflict(code) do update set
      country_code=excluded.country_code,
      country_name=excluded.country_name,
      city=excluded.city,
      apartment_base_price=excluded.apartment_base_price,
      house_base_price=excluded.house_base_price,
      annual_value_rate_bps=excluded.annual_value_rate_bps,
      active=true,
      updated_at=now();

    select * into v_location
    from public.private_life_property_locations
    where code=v_location_code;
  elsif not v_location.marketplace_enabled and v_location.code like 'home_%' then
    select * into v_baseline
    from public.private_life_country_property_baseline_v1(v_player.country_code);

    if v_baseline.tier is not null then
      update public.private_life_property_locations
      set country_name=v_country_name,
          apartment_base_price=v_baseline.apartment_base_price,
          house_base_price=v_baseline.house_base_price,
          annual_value_rate_bps=v_baseline.annual_value_rate_bps,
          updated_at=now()
      where code=v_location.code
      returning * into v_location;
    end if;
  end if;

  select o.id,o.sold_absolute_day,o.catalog_code,o.location_code,o.purchase_price
  into v_existing
  from public.private_life_player_assets o
  where o.player_id=p_player_id
    and o.acquisition_type='starter_home'
  order by o.created_at
  limit 1;

  if v_existing.id is not null then
    if v_existing.sold_absolute_day is null
       and (
         v_existing.catalog_code is distinct from v_cheapest.code
         or v_existing.location_code is distinct from v_location.code
       ) then
      v_price:=greatest(1,round(v_location.apartment_base_price::numeric*v_multiplier::numeric/10000)::bigint);

      update public.private_life_player_assets
      set catalog_code=v_cheapest.code,
          location_code=v_location.code,
          purchase_price=v_price,
          annual_running_cost_override=0,
          annual_value_rate_bps_override=greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment)),
          resale_discount_bps_override=v_cheapest.resale_discount_bps,
          prestige_override=v_cheapest.prestige,
          trade_locked=false,
          updated_at=now()
      where id=v_existing.id;
    end if;
    return v_existing.id;
  end if;

  v_price:=greatest(1,round(v_location.apartment_base_price::numeric*v_multiplier::numeric/10000)::bigint);

  insert into public.private_life_player_assets(
    id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,
    annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,
    prestige_override,trade_locked
  ) values(
    v_owned_id,p_player_id,v_cheapest.code,v_location.code,'starter_home',0,v_price,
    0,greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment)),
    v_cheapest.resale_discount_bps,v_cheapest.prestige,false
  );

  return v_owned_id;
end;
$function$;
