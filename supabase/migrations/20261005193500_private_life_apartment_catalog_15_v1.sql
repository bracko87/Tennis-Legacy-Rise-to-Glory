-- Expand Private Life apartments to 15 normal purchasable types.
-- Remove the special Starter Home Flat catalog row and assign the cheapest
-- normal apartment in the player's home city as the starting residence.

insert into public.private_life_asset_catalog (
  code, category, name, tier, description, purchase_price, prestige, rarity,
  annual_running_cost, annual_value_rate_bps, resale_discount_bps, image_url, active, metadata
)
values
  ('apt_starter_city','apartment','Compact City Flat',1,
   'An entry-level compact apartment. The actual price scales with the selected city.',
   110000,1,'common',13200,150,1100,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',5500,'value_rate_adjustment_bps',0,'catalog_order',1,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Compact City Flat.png')),
  ('apt_city_studio','apartment','City Studio Apartment',1,
   'A practical city studio with a more comfortable layout. The actual price scales with the selected city.',
   140000,1,'common',16800,155,1100,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',7000,'value_rate_adjustment_bps',5,'catalog_order',2,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/City Studio Apartment.png')),
  ('apt_one_bedroom','apartment','One-Bedroom Apartment',1,
   'A modern one-bedroom apartment for independent city living. The actual price scales with the selected city.',
   170000,2,'common',20400,160,1050,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',8500,'value_rate_adjustment_bps',10,'catalog_order',3,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/One-Bedroom Apartment.png')),
  ('apt_modern_residence','apartment','Standard City Apartment',2,
   'A well-finished standard city apartment with balanced space and comfort. The actual price scales with the selected city.',
   200000,2,'uncommon',24000,175,1000,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',10000,'value_rate_adjustment_bps',25,'catalog_order',4,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Standard City Apartment.png')),
  ('apt_modern_two_bed','apartment','Modern Two-Bedroom Apartment',2,
   'A contemporary two-bedroom apartment with upgraded finishes. The actual price scales with the selected city.',
   240000,3,'uncommon',28800,180,1000,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',12000,'value_rate_adjustment_bps',30,'catalog_order',5,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Modern Two-Bedroom Apartment.png')),
  ('apt_luxury_residence','apartment','Large City Apartment',2,
   'A spacious city apartment suited to an established professional lifestyle. The actual price scales with the selected city.',
   300000,4,'uncommon',36000,200,950,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',15000,'value_rate_adjustment_bps',50,'catalog_order',6,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Large City Apartment.png')),
  ('apt_executive','apartment','Executive Apartment',3,
   'An executive-grade residence with premium materials and generous living space. The actual price scales with the selected city.',
   360000,5,'rare',43200,205,950,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',18000,'value_rate_adjustment_bps',55,'catalog_order',7,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Executive Apartment.png')),
  ('apt_premium_residence','apartment','Premium Residence',3,
   'A premium urban residence with designer interiors and additional space. The actual price scales with the selected city.',
   440000,6,'rare',52800,210,900,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',22000,'value_rate_adjustment_bps',60,'catalog_order',8,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Premium Residence.png')),
  ('apt_luxury_city','apartment','Luxury City Apartment',3,
   'A high-end city apartment with luxury finishes and prestige-focused amenities. The actual price scales with the selected city.',
   520000,7,'rare',62400,215,900,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',26000,'value_rate_adjustment_bps',65,'catalog_order',9,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Luxury City Apartment.png')),
  ('apt_skyline','apartment','Skyline Apartment',3,
   'A luxury high-floor apartment with expansive city views. The actual price scales with the selected city.',
   620000,8,'rare',74400,220,850,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',31000,'value_rate_adjustment_bps',70,'catalog_order',10,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Skyline Apartment.png')),
  ('apt_penthouse','apartment','Luxury Penthouse',4,
   'A luxury penthouse with premium entertaining space and panoramic views. The actual price scales with the selected city.',
   760000,9,'very_rare',91200,225,850,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',38000,'value_rate_adjustment_bps',75,'catalog_order',11,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Luxury Penthouse.png')),
  ('apt_grand_penthouse','apartment','Grand Penthouse',4,
   'A grand penthouse with expansive living areas and top-tier finishes. The actual price scales with the selected city.',
   920000,11,'very_rare',110400,230,800,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',46000,'value_rate_adjustment_bps',80,'catalog_order',12,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Grand Penthouse.png')),
  ('apt_duplex_penthouse','apartment','Duplex Penthouse',4,
   'A two-level penthouse with statement architecture and luxury entertaining areas. The actual price scales with the selected city.',
   1100000,13,'very_rare',132000,235,800,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',55000,'value_rate_adjustment_bps',85,'catalog_order',13,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Duplex Penthouse.png')),
  ('apt_trophy_residence','apartment','Signature Penthouse',5,
   'A signature penthouse designed as a landmark personal residence. The actual price scales with the selected city.',
   1300000,16,'legendary',156000,250,750,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',65000,'value_rate_adjustment_bps',100,'catalog_order',14,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Signature Penthouse.png')),
  ('apt_trophy_sky','apartment','Trophy Sky Residence',5,
   'An exceptional top-tier sky residence representing the most prestigious apartment ownership level. The actual price scales with the selected city.',
   1600000,20,'legendary',192000,260,700,
   'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1200&q=82',true,
   jsonb_build_object('property_kind','apartment','location_priced',true,'market_currency','USD','price_multiplier_bps',80000,'value_rate_adjustment_bps',110,'catalog_order',15,'image_status','placeholder','image_storage_bucket','Admin','image_storage_folder','Private Life/Apartments','expected_image_storage_path','Private Life/Apartments/Trophy Sky Residence.png'))
on conflict (code) do update set
  category=excluded.category,
  name=excluded.name,
  tier=excluded.tier,
  description=excluded.description,
  purchase_price=excluded.purchase_price,
  prestige=excluded.prestige,
  rarity=excluded.rarity,
  annual_running_cost=excluded.annual_running_cost,
  annual_value_rate_bps=excluded.annual_value_rate_bps,
  resale_discount_bps=excluded.resale_discount_bps,
  image_url=excluded.image_url,
  active=true,
  metadata=excluded.metadata,
  updated_at=now();

-- Migrate every existing special starter flat to the cheapest normal apartment.
update public.private_life_player_assets o
set
  catalog_code='apt_starter_city',
  purchase_price=greatest(1,round(l.apartment_base_price::numeric*0.55)::bigint),
  annual_running_cost_override=0,
  annual_value_rate_bps_override=l.annual_value_rate_bps,
  resale_discount_bps_override=1100,
  prestige_override=1,
  trade_locked=false,
  updated_at=now()
from public.private_life_property_locations l
where o.catalog_code='apt_home_starter'
  and o.location_code=l.code;

-- Remove the old special catalog item after all ownership rows have been migrated.
delete from public.private_life_asset_catalog
where code='apt_home_starter';

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

  -- A player receives exactly one free starting residence in their career.
  -- If it was later sold after acquiring another residence, do not create another free one.
  select o.id,o.sold_absolute_day
  into v_existing
  from public.private_life_player_assets o
  where o.player_id=p_player_id
    and o.acquisition_type='starter_home'
  order by o.created_at
  limit 1;

  if v_existing.id is not null then
    if v_existing.sold_absolute_day is null then
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
    and o.acquisition_type='starter_home'
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

-- Pre-authorize the apartment image folder for signed URLs once generated images are uploaded.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname='storage'
      and tablename='objects'
      and policyname='admin_private_life_apartments_authenticated_read'
  ) then
    create policy "admin_private_life_apartments_authenticated_read"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id='Admin'
        and name like 'Private Life/Apartments/%'
      );
  end if;
end $$;
