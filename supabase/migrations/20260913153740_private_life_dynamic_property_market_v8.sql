create table if not exists public.private_life_property_market_history (
  id uuid primary key default gen_random_uuid(),
  location_code text not null references public.private_life_property_locations(code) on delete cascade,
  season integer not null check (season>=1),
  month smallint not null check (month between 1 and 12),
  previous_apartment_base_price bigint not null check (previous_apartment_base_price>0),
  apartment_base_price bigint not null check (apartment_base_price>0),
  previous_house_base_price bigint not null check (previous_house_base_price>0),
  house_base_price bigint not null check (house_base_price>0),
  monthly_change_bps integer not null,
  is_baseline boolean not null default false,
  created_at timestamptz not null default now(),
  unique(location_code,season,month)
);

create index if not exists private_life_property_market_history_location_month_idx
  on public.private_life_property_market_history(location_code,season desc,month desc);

alter table public.private_life_property_market_history enable row level security;
revoke all on public.private_life_property_market_history from public,anon,authenticated;

create or replace function public.private_life_property_market_delta_bps_v1(
  p_location_code text,
  p_annual_value_rate_bps integer,
  p_season integer,
  p_month integer
)
returns integer
language sql
immutable
set search_path to 'public'
as $function$
  select greatest(
    -220,
    least(
      260,
      round(coalesce(p_annual_value_rate_bps,0)::numeric/12)::integer
      + ((((hashtextextended(coalesce(p_location_code,'')||':'||p_season::text||':'||p_month::text,0) % 321)+321)%321)::integer - 160)
    )
  );
$function$;

revoke all on function public.private_life_property_market_delta_bps_v1(text,integer,integer,integer) from public,anon,authenticated;

create or replace function public.process_private_life_property_market_month_v1(p_season integer,p_month integer)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  r record;
  v_delta integer;
  v_new_apartment bigint;
  v_new_house bigint;
  v_count integer:=0;
begin
  if p_season<1 or p_month not between 1 and 12 then
    raise exception 'Invalid game month.';
  end if;

  for r in
    select * from public.private_life_property_locations
    where active=true
    order by sort_order,code
  loop
    if exists(
      select 1 from public.private_life_property_market_history h
      where h.location_code=r.code and h.season=p_season and h.month=p_month
    ) then
      continue;
    end if;

    v_delta:=public.private_life_property_market_delta_bps_v1(r.code,r.annual_value_rate_bps,p_season,p_month);
    v_new_apartment:=greatest(25000,round(r.apartment_base_price::numeric*(10000+v_delta)::numeric/10000)::bigint);
    v_new_house:=greatest(50000,round(r.house_base_price::numeric*(10000+v_delta)::numeric/10000)::bigint);

    insert into public.private_life_property_market_history(
      location_code,season,month,
      previous_apartment_base_price,apartment_base_price,
      previous_house_base_price,house_base_price,
      monthly_change_bps,is_baseline
    ) values(
      r.code,p_season,p_month,
      r.apartment_base_price,v_new_apartment,
      r.house_base_price,v_new_house,
      v_delta,false
    );

    update public.private_life_property_locations
    set apartment_base_price=v_new_apartment,
        house_base_price=v_new_house,
        updated_at=now()
    where code=r.code;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object('status','processed','season',p_season,'month',p_month,'locations_updated',v_count);
end;
$function$;

revoke all on function public.process_private_life_property_market_month_v1(integer,integer) from public,anon,authenticated;

create or replace function public.process_private_life_property_market_to_current_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  gd record;
  v_current_index integer;
  v_last_index integer;
  v_base_index integer;
  v_index integer;
  v_season integer;
  v_month integer;
  v_result jsonb;
  v_total integer:=0;
begin
  select * into gd from public.get_current_game_day_internal_v1();
  v_current_index:=(gd.season-1)*12+gd.month;

  select max((season-1)*12+month) into v_last_index
  from public.private_life_property_market_history;

  if v_last_index is null then
    v_base_index:=greatest(1,v_current_index-1);
    v_season:=((v_base_index-1)/12)+1;
    v_month:=((v_base_index-1)%12)+1;

    insert into public.private_life_property_market_history(
      location_code,season,month,
      previous_apartment_base_price,apartment_base_price,
      previous_house_base_price,house_base_price,
      monthly_change_bps,is_baseline
    )
    select code,v_season,v_month,
           apartment_base_price,apartment_base_price,
           house_base_price,house_base_price,
           0,true
    from public.private_life_property_locations
    where active=true
    on conflict(location_code,season,month) do nothing;

    v_last_index:=v_base_index;
  end if;

  if v_last_index<v_current_index then
    for v_index in (v_last_index+1)..v_current_index loop
      v_season:=((v_index-1)/12)+1;
      v_month:=((v_index-1)%12)+1;
      v_result:=public.process_private_life_property_market_month_v1(v_season,v_month);
      v_total:=v_total+coalesce((v_result->>'locations_updated')::integer,0);
    end loop;
  end if;

  return jsonb_build_object(
    'status','completed',
    'season',gd.season,
    'month',gd.month,
    'locations_updated',v_total
  );
end;
$function$;

revoke all on function public.process_private_life_property_market_to_current_v1() from public,anon,authenticated;

create or replace function public.private_life_owned_asset_market_value_v2(p_player_asset_id uuid,p_absolute_day integer)
returns bigint
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  o public.private_life_player_assets%rowtype;
  c public.private_life_asset_catalog%rowtype;
  l public.private_life_property_locations%rowtype;
  v_multiplier integer;
  v_base bigint;
begin
  select * into o from public.private_life_player_assets where id=p_player_asset_id;
  if o.id is null then return 0; end if;
  select * into c from public.private_life_asset_catalog where code=o.catalog_code;

  if c.category in ('apartment','house_villa') and o.location_code is not null
     and coalesce((c.metadata->>'location_priced')::boolean,false) then
    select * into l from public.private_life_property_locations where code=o.location_code;
    if l.code is not null then
      v_multiplier:=coalesce((c.metadata->>'price_multiplier_bps')::integer,10000);
      v_base:=case when c.category='apartment' then l.apartment_base_price else l.house_base_price end;
      return greatest(1,round(v_base::numeric*v_multiplier::numeric/10000)::bigint);
    end if;
  end if;

  return public.private_life_market_value_v1(
    o.purchase_price,
    coalesce(o.annual_value_rate_bps_override,c.annual_value_rate_bps),
    o.purchase_absolute_day,
    p_absolute_day
  );
end;
$function$;

revoke all on function public.private_life_owned_asset_market_value_v2(uuid,integer) from public,anon,authenticated;

create or replace function public.list_private_life_asset_for_sale_v1(p_owned_asset_id uuid,p_sale_mode text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_player uuid; v_owned public.private_life_player_assets%rowtype; v_asset public.private_life_asset_catalog%rowtype;
  v_abs integer; gd record; v_market bigint; v_discount integer; v_sale bigint; v_wait integer; v_listing_id uuid:=gen_random_uuid();
  v_other_available_residences integer:=0;
begin
  v_player:=public.private_life_current_player_v1();
  if lower(coalesce(p_sale_mode,'')) not in ('urgent','standard','patient') then raise exception 'Sale mode must be urgent, standard or patient.'; end if;
  select * into v_owned from public.private_life_player_assets where id=p_owned_asset_id and player_id=v_player and sold_absolute_day is null for update;
  if v_owned.id is null then raise exception 'Owned lifestyle asset not found.'; end if;
  if exists(select 1 from public.private_life_asset_sale_listings where player_asset_id=v_owned.id and status='pending') then raise exception 'This asset is already listed for sale.'; end if;
  select * into v_asset from public.private_life_asset_catalog where code=v_owned.catalog_code;
  if v_asset.category in ('apartment','house_villa') then
    select count(*)::integer into v_other_available_residences
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    where o.player_id=v_player
      and o.id<>v_owned.id
      and o.sold_absolute_day is null
      and c.category in ('apartment','house_villa')
      and not exists(select 1 from public.private_life_asset_sale_listings s where s.player_asset_id=o.id and s.status='pending');
    if v_other_available_residences<1 then
      raise exception 'You must own another apartment, house or villa before selling your current residence.';
    end if;
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
$function$;

grant execute on function public.list_private_life_asset_for_sale_v1(uuid,text) to authenticated;

create or replace function public.get_private_life_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_base jsonb;
  v_owned jsonb;
  v_categories jsonb;
  v_locations jsonb;
  v_abs integer;
  v_asset_value bigint:=0;
  v_monthly_cost bigint:=0;
  v_cash bigint:=0;
  v_investments bigint:=0;
begin
  v_base:=public.get_private_life_dashboard_v1();
  v_abs:=coalesce((v_base->>'current_absolute_day')::integer,0);
  v_cash:=coalesce((v_base->>'cash_balance')::bigint,0);
  v_investments:=coalesce((v_base->>'investment_value')::bigint,0);

  select coalesce(jsonb_agg(
    elem || jsonb_build_object(
      'current_market_value',calc.market_value,
      'estimated_sale_price',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'standard'),
      'potential_gain_loss',public.private_life_sale_price_v2(calc.market_value,coalesce((elem->>'resale_discount_bps')::integer,0),'standard')-coalesce((elem->>'purchase_price')::bigint,0),
      'property_monthly_change_bps',hist.monthly_change_bps
    )
    order by coalesce((elem->>'purchase_absolute_day')::integer,0) desc,elem->>'name'
  ),'[]'::jsonb)
  into v_owned
  from jsonb_array_elements(coalesce(v_base->'owned_assets','[]'::jsonb)) elem
  cross join lateral (
    select public.private_life_owned_asset_market_value_v2((elem->>'id')::uuid,v_abs) as market_value
  ) calc
  left join lateral (
    select h.monthly_change_bps
    from public.private_life_property_market_history h
    where h.location_code=elem->>'location_code'
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  select coalesce(sum((elem->>'current_market_value')::bigint),0)::bigint,
         coalesce(sum(greatest(0,round(coalesce((elem->>'annual_running_cost')::numeric,0)/12)::bigint)),0)::bigint
  into v_asset_value,v_monthly_cost
  from jsonb_array_elements(v_owned) elem;

  select coalesce(jsonb_agg(jsonb_build_object(
    'category',category,
    'owned_count',owned_count,
    'market_value',market_value,
    'prestige',prestige,
    'annual_running_cost',annual_running_cost,
    'monthly_running_cost',monthly_running_cost
  ) order by category),'[]'::jsonb)
  into v_categories
  from (
    select elem->>'category' as category,
           count(*)::integer as owned_count,
           sum((elem->>'current_market_value')::bigint)::bigint as market_value,
           sum(coalesce((elem->>'prestige')::integer,0))::integer as prestige,
           sum(coalesce((elem->>'annual_running_cost')::bigint,0))::bigint as annual_running_cost,
           sum(greatest(0,round(coalesce((elem->>'annual_running_cost')::numeric,0)/12)::bigint))::bigint as monthly_running_cost
    from jsonb_array_elements(v_owned) elem
    group by elem->>'category'
  ) x;

  select coalesce(jsonb_agg(
    elem || jsonb_build_object(
      'monthly_change_bps',hist.monthly_change_bps,
      'previous_apartment_base_price',hist.previous_apartment_base_price,
      'previous_house_base_price',hist.previous_house_base_price,
      'market_season',hist.season,
      'market_month',hist.month
    )
    order by coalesce((elem->>'sort_order')::integer,0),elem->>'country_name',elem->>'city'
  ),'[]'::jsonb)
  into v_locations
  from jsonb_array_elements(coalesce(v_base->'property_locations','[]'::jsonb)) elem
  left join lateral (
    select h.*
    from public.private_life_property_market_history h
    where h.location_code=elem->>'code'
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  return v_base || jsonb_build_object(
    'asset_value',v_asset_value,
    'net_worth',v_cash+v_asset_value+v_investments,
    'monthly_running_cost',v_monthly_cost,
    'owned_assets',v_owned,
    'category_totals',v_categories,
    'property_locations',v_locations
  );
end;
$function$;

revoke all on function public.get_private_life_dashboard_v2() from public,anon;
grant execute on function public.get_private_life_dashboard_v2() to authenticated;

do $do$
declare j record;
begin
  for j in select jobid from cron.job where jobname='tennis-private-life-property-market-v1' loop
    perform cron.unschedule(j.jobid);
  end loop;
  perform cron.schedule(
    'tennis-private-life-property-market-v1',
    '*/5 * * * *',
    'select public.process_private_life_property_market_to_current_v1();'
  );
end;
$do$;