-- Fix player creation 23505/409 after Season 1 reset:
-- a preexisting country/city property location is not a portrait conflict.
-- Reuse the location without adding marketplace listings or altering
-- another player's property prices. Concurrent city inserts are safe.
CREATE OR REPLACE FUNCTION public.ensure_private_life_starter_home_v1(p_player_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  v_starter public.private_life_asset_catalog%rowtype;
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
    ) or exists (
      select 1 from public.tennis_premium_trials_v1 trial
      where trial.user_id=v_player.owner_user_id and trial.expires_at>now()
    ) into v_is_premium;

    if not v_is_premium then
      return null;
    end if;
  end if;

  select *
  into v_starter
  from public.private_life_asset_catalog c
  where c.code='apt_starter_city'
    and c.category='apartment'
    and c.active=true
  limit 1;

  if v_starter.code is null then
    raise exception 'Compact City Flat starter apartment is not active.';
  end if;

  v_multiplier:=coalesce((v_starter.metadata->>'price_multiplier_bps')::integer,10000);
  v_rate_adjustment:=coalesce((v_starter.metadata->>'value_rate_adjustment_bps')::integer,0);

  select coalesce(c.name,upper(coalesce(v_player.country_code,'XX')))
  into v_country_name
  from public.countries c
  where upper(c.code)=upper(coalesce(v_player.country_code,''))
  limit 1;
  v_country_name:=coalesce(v_country_name,upper(coalesce(v_player.country_code,'XX')));

  -- A standard starter home may only use a city that actually offers the
  -- Compact City Flat category. One-Bedroom-only cities do not qualify.
  select l.*
  into v_location
  from public.private_life_property_locations l
  join public.private_life_property_catalog_availability a
    on a.location_code=l.code
   and a.catalog_code='apt_starter_city'
   and a.active=true
  where l.active=true
    and l.marketplace_enabled=true
    and upper(l.country_code)=upper(coalesce(v_player.country_code,''))
    and lower(l.city)=lower(v_player.home_city)
  order by l.sort_order,l.code
  limit 1;

  if v_location.code is null then
    -- Reuse existing private starter locations after a career reset.
    -- All players share the same unique (country_code,city) location row.
    -- This never changes the storefront's property catalog availability.
    select l.*
    into v_location
    from public.private_life_property_locations l
    where l.active=true
      and l.marketplace_enabled=false
      and upper(l.country_code)=upper(coalesce(v_player.country_code,''))
      and lower(l.city)=lower(v_player.home_city)
    order by case
      when l.code='starter_home_'||replace(p_player_id::text,'-','') then 0
      when l.code='home_'||replace(p_player_id::text,'-','') then 1
      else 2 end, l.sort_order,l.code
    limit 1;

    if v_location.code is null then
      -- A marketplace city may lack an entry-level flat offering. Reuse
      -- its city location for this private starter asset without adding
      -- any new publicly purchasable property listings.
      select l.* into v_location
      from public.private_life_property_locations l
      where upper(l.country_code)=upper(coalesce(v_player.country_code,''))
        and lower(l.city)=lower(v_player.home_city)
      order by l.active desc,l.sort_order,l.code
      limit 1;
    end if;

    if v_location.code is null then
      select *
      into v_baseline
      from public.private_life_country_property_baseline_v1(v_player.country_code);

      if v_baseline.tier is null then
        select *
        into v_baseline
        from public.private_life_property_price_tiers
        where tier=4;
      end if;

      v_location_code:='starter_home_'||replace(p_player_id::text,'-','');

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
      -- A concurrent signup can create the same city first. Do not
      -- overwrite marketplace flags or prices when that happens.
      on conflict do nothing;

      select *
      into v_location
      from public.private_life_property_locations
      where upper(country_code)=upper(coalesce(v_player.country_code,''))
        and lower(city)=lower(v_player.home_city)
      order by active desc,sort_order,code
      limit 1;
      if v_location.code is null then
        raise exception 'Selected starter home location is unavailable.';
      end if;
    elsif v_location.code in (
      'starter_home_'||replace(p_player_id::text,'-',''),
      'home_'||replace(p_player_id::text,'-','')
    ) then
      -- Reprice only a private location created for this player.
      -- Never mutate a reused city belonging to another player.
      select *
      into v_baseline
      from public.private_life_country_property_baseline_v1(v_player.country_code);

      if v_baseline.tier is not null then
        update public.private_life_property_locations
        set country_name=v_country_name,
            apartment_base_price=v_baseline.apartment_base_price,
            house_base_price=v_baseline.house_base_price,
            annual_value_rate_bps=v_baseline.annual_value_rate_bps,
            marketplace_enabled=false,
            updated_at=now()
        where code=v_location.code
        returning * into v_location;
      end if;
    end if;
  end if;

  select o.id,o.sold_absolute_day,o.catalog_code,o.location_code,o.purchase_price
  into v_existing
  from public.private_life_player_assets o
  where o.player_id=p_player_id
    and o.acquisition_type='starter_home'
  order by o.created_at
  limit 1;

  v_price:=greatest(1,round(v_location.apartment_base_price::numeric*v_multiplier::numeric/10000)::bigint);

  if v_existing.id is not null then
    if v_existing.sold_absolute_day is null
       and (
         v_existing.catalog_code is distinct from v_starter.code
         or v_existing.location_code is distinct from v_location.code
       ) then
      update public.private_life_player_assets
      set catalog_code=v_starter.code,
          location_code=v_location.code,
          purchase_price=v_price,
          annual_running_cost_override=0,
          annual_value_rate_bps_override=greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment)),
          resale_discount_bps_override=v_starter.resale_discount_bps,
          prestige_override=v_starter.prestige,
          trade_locked=false,
          updated_at=now()
      where id=v_existing.id;
    end if;
    return v_existing.id;
  end if;

  insert into public.private_life_player_assets(
    id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,
    annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,
    prestige_override,trade_locked
  ) values(
    v_owned_id,p_player_id,v_starter.code,v_location.code,'starter_home',0,v_price,
    0,greatest(-5000,least(5000,v_location.annual_value_rate_bps+v_rate_adjustment)),
    v_starter.resale_discount_bps,v_starter.prestige,false
  );

  return v_owned_id;
end;
$function$
;
