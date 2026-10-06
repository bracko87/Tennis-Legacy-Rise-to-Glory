-- Calibrate Large City Apartment prices per destination without changing the
-- base apartment market used by the other apartment categories.
--
-- Each destination receives a unique target price. The target is stored together
-- with the current city apartment base-price snapshot. Future property-market
-- movements continue to affect the Large City Apartment proportionally.

with desired(country_code, city, target_price) as (
  values
    ('BA','Sarajevo',134750::bigint),
    ('ME','Podgorica',129500::bigint),
    ('SE','Gothenburg',612500::bigint),
    ('NO','Bergen',598750::bigint),
    ('FI','Helsinki',647500::bigint),
    ('IS','Reykjavik',872500::bigint),
    ('GB','Edinburgh',668750::bigint),
    ('GB','Manchester',371250::bigint),
    ('GB','Birmingham',329750::bigint),
    ('NL','Rotterdam',603500::bigint),
    ('IT','Turin',347250::bigint),
    ('IT','Bologna',362750::bigint),
    ('IT','Venice',781500::bigint),
    ('FR','Lyon',624750::bigint),
    ('FR','Bordeaux',558500::bigint),
    ('DE','Dusseldorf',652250::bigint),
    ('DE','Stuttgart',639500::bigint),
    ('AT','Salzburg',702750::bigint),
    ('CH','Lausanne',1067500::bigint),
    ('OM','Muscat',351750::bigint),
    ('KW','Kuwait City',497500::bigint),
    ('BH','Manama',414250::bigint),
    ('EG','Alexandria',138500::bigint),
    ('TN','Tunis',132750::bigint),
    ('DZ','Algiers',136250::bigint),
    ('SN','Dakar',144500::bigint),
    ('ET','Addis Ababa',126750::bigint),
    ('RW','Kigali',153250::bigint),
    ('TZ','Dar es Salaam',148750::bigint),
    ('NA','Windhoek',141500::bigint),
    ('MU','Port Louis',356250::bigint),
    ('UZ','Tashkent',131750::bigint),
    ('AM','Yerevan',139250::bigint),
    ('JP','Yokohama',742500::bigint),
    ('JP','Nagoya',536750::bigint),
    ('JP','Fukuoka',359500::bigint),
    ('KR','Incheon',472250::bigint),
    ('CN','Shenzhen',748750::bigint),
    ('CN','Hangzhou',506500::bigint),
    ('TH','Phuket',378250::bigint),
    ('BD','Dhaka',124500::bigint),
    ('NP','Kathmandu',128750::bigint),
    ('PK','Karachi',133500::bigint),
    ('US','Washington',947500::bigint),
    ('US','Austin',711250::bigint),
    ('US','Dallas',619750::bigint),
    ('US','Houston',544500::bigint),
    ('US','Denver',756250::bigint),
    ('US','San Diego',1098500::bigint),
    ('US','Las Vegas',364750::bigint),
    ('US','Atlanta',353500::bigint),
    ('MX','Cancun',446250::bigint),
    ('PA','Panama City',361500::bigint),
    ('UY','Punta del Este',552750::bigint),
    ('AR','Cordoba',127250::bigint),
    ('AU','Brisbane',738500::bigint),
    ('AU','Perth',709750::bigint),
    ('AU','Gold Coast',816250::bigint),
    ('NZ','Wellington',358750::bigint),
    ('NZ','Queenstown',861500::bigint)
),
matched as (
  select l.code as location_code,
         d.target_price,
         l.apartment_base_price as base_snapshot
  from desired d
  join public.private_life_property_locations l
    on upper(l.country_code)=d.country_code
   and lower(l.city)=lower(d.city)
  join public.private_life_property_catalog_availability a
    on a.location_code=l.code
   and a.catalog_code='apt_luxury_residence'
)
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb)
      || jsonb_build_object(
        'city_price_overrides',
        (select jsonb_object_agg(location_code,target_price order by location_code) from matched),
        'city_price_base_snapshots',
        (select jsonb_object_agg(location_code,base_snapshot order by location_code) from matched),
        'city_price_status','calibrated_unique',
        'city_price_version','large_city_apartment_v2',
        'city_price_model','baseline_scaled_override_v1',
        'city_price_count',60
      ),
    updated_at=now()
where c.code='apt_luxury_residence'
  and c.category='apartment';

do $$
declare
  v_locations integer;
  v_prices integer;
  v_distinct_prices integer;
begin
  select count(*) into v_locations
  from public.private_life_property_catalog_availability
  where catalog_code='apt_luxury_residence';

  select jsonb_object_length(coalesce(metadata->'city_price_overrides','{}'::jsonb))
  into v_prices
  from public.private_life_asset_catalog
  where code='apt_luxury_residence';

  select count(distinct (value::text)::bigint)
  into v_distinct_prices
  from public.private_life_asset_catalog c,
       lateral jsonb_each(c.metadata->'city_price_overrides')
  where c.code='apt_luxury_residence';

  if v_locations <> 60 or v_prices <> 60 or v_distinct_prices <> 60 then
    raise exception 'Large City Apartment price calibration incomplete: locations %, prices %, unique %.',
      v_locations, v_prices, v_distinct_prices;
  end if;
end;
$$;

create or replace function public.private_life_property_effective_price_v1(
  p_catalog_code text,
  p_location_code text
)
returns bigint
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_asset public.private_life_asset_catalog%rowtype;
  v_location public.private_life_property_locations%rowtype;
  v_base bigint;
  v_override bigint;
  v_snapshot bigint;
  v_multiplier integer;
begin
  select * into v_asset
  from public.private_life_asset_catalog
  where code=p_catalog_code;

  select * into v_location
  from public.private_life_property_locations
  where code=p_location_code;

  if v_asset.code is null or v_location.code is null then
    return 0;
  end if;

  if not coalesce((v_asset.metadata->>'location_priced')::boolean,false) then
    return greatest(1,v_asset.purchase_price);
  end if;

  v_base:=case
    when v_asset.category='apartment' then v_location.apartment_base_price
    when v_asset.category='house_villa' then v_location.house_base_price
    else null
  end;

  if v_base is null then
    return greatest(1,v_asset.purchase_price);
  end if;

  if v_asset.metadata ? 'city_price_overrides' then
    v_override:=nullif(v_asset.metadata->'city_price_overrides'->>v_location.code,'')::bigint;
    v_snapshot:=nullif(v_asset.metadata->'city_price_base_snapshots'->>v_location.code,'')::bigint;
  end if;

  if coalesce(v_override,0)>0 then
    if coalesce(v_snapshot,0)>0 then
      return greatest(1,round(v_override::numeric*v_base::numeric/v_snapshot::numeric)::bigint);
    end if;
    return greatest(1,v_override);
  end if;

  v_multiplier:=coalesce((v_asset.metadata->>'price_multiplier_bps')::integer,10000);
  return greatest(1,round(v_base::numeric*v_multiplier::numeric/10000)::bigint);
end;
$function$;

create or replace function public.buy_private_life_asset_v2(
  p_catalog_code text,
  p_location_code text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player uuid; v_asset public.private_life_asset_catalog%rowtype; v_location public.private_life_property_locations%rowtype;
  v_owned_id uuid:=gen_random_uuid(); v_abs integer; gd record; v_fin jsonb; v_tx uuid;
  v_location_priced boolean:=false; v_rate_adjustment integer:=0;
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
    v_rate_adjustment:=coalesce((v_asset.metadata->>'value_rate_adjustment_bps')::integer,0);
    if v_asset.category not in ('apartment','house_villa') then raise exception 'Location pricing is only supported for property assets.'; end if;
    v_price:=public.private_life_property_effective_price_v1(v_asset.code,v_location.code);
    if coalesce(v_price,0)<=0 then raise exception 'Property price is unavailable.'; end if;
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

create or replace function public.private_life_owned_asset_market_value_v2(
  p_player_asset_id uuid,
  p_absolute_day integer
)
returns bigint
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  o public.private_life_player_assets%rowtype;
  c public.private_life_asset_catalog%rowtype;
  v_price bigint;
begin
  select * into o from public.private_life_player_assets where id=p_player_asset_id;
  if o.id is null then return 0; end if;
  select * into c from public.private_life_asset_catalog where code=o.catalog_code;

  if c.category in ('apartment','house_villa') and o.location_code is not null
     and coalesce((c.metadata->>'location_priced')::boolean,false) then
    v_price:=public.private_life_property_effective_price_v1(c.code,o.location_code);
    if coalesce(v_price,0)>0 then return v_price; end if;
  end if;

  return greatest(1,c.purchase_price);
end;
$function$;
