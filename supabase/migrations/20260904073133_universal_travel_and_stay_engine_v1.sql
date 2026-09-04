-- Universal Travel & Stay Engine v1
-- Shared authoritative pricing/fatigue/stay model for tournament travel,
-- training camps and planned player travel legs.

create table if not exists public.travel_country_cost_profiles (
  country_code text primary key,
  hotel_cost_index numeric(6,3) not null default 1.000
    check (hotel_cost_index between 0.50 and 2.50),
  cost_tier text not null default 'standard'
    check (cost_tier in ('low','standard','high')),
  updated_at timestamptz not null default now()
);

create table if not exists public.travel_locations (
  id uuid primary key default gen_random_uuid(),
  city text not null,
  country_code text not null,
  latitude double precision,
  longitude double precision,
  coordinate_basis text not null default 'country_reference'
    check (coordinate_basis in ('exact','country_reference','unknown')),
  hotel_cost_index numeric(6,3) not null default 1.000
    check (hotel_cost_index between 0.50 and 2.50),
  cost_tier text not null default 'standard'
    check (cost_tier in ('low','standard','high')),
  source text not null default 'game_catalog',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists travel_locations_city_country_uidx
  on public.travel_locations ((lower(trim(city))), (upper(country_code)));
create index if not exists travel_locations_country_idx
  on public.travel_locations (country_code);

create table if not exists public.travel_pricing_rules (
  band text primary key
    check (band in ('same_city','domestic','regional','intercontinental')),
  base_cost_one_way numeric(10,2) not null,
  cost_per_km numeric(10,4) not null default 0,
  minimum_cost_one_way numeric(10,2) not null,
  maximum_cost_one_way numeric(10,2) not null,
  base_fatigue smallint not null,
  fatigue_distance_step_km integer,
  maximum_fatigue smallint not null,
  updated_at timestamptz not null default now()
);

insert into public.travel_pricing_rules(
  band,base_cost_one_way,cost_per_km,minimum_cost_one_way,
  maximum_cost_one_way,base_fatigue,fatigue_distance_step_km,maximum_fatigue
) values
  ('same_city',20,0,20,20,1,null,1),
  ('domestic',30,0.035,45,220,1,900,4),
  ('regional',40,0.055,90,350,2,1800,6),
  ('intercontinental',110,0.050,250,1200,5,2200,14)
on conflict(band) do update set
  base_cost_one_way=excluded.base_cost_one_way,
  cost_per_km=excluded.cost_per_km,
  minimum_cost_one_way=excluded.minimum_cost_one_way,
  maximum_cost_one_way=excluded.maximum_cost_one_way,
  base_fatigue=excluded.base_fatigue,
  fatigue_distance_step_km=excluded.fatigue_distance_step_km,
  maximum_fatigue=excluded.maximum_fatigue,
  updated_at=now();

create table if not exists public.travel_class_rules (
  class_name text primary key
    check (class_name in ('Economy','Premium Economy','Business','First Class')),
  price_multiplier numeric(6,3) not null check (price_multiplier >= 1),
  fatigue_multiplier numeric(6,3) not null
    check (fatigue_multiplier > 0 and fatigue_multiplier <= 1),
  sort_order smallint not null,
  updated_at timestamptz not null default now()
);

insert into public.travel_class_rules(
  class_name,price_multiplier,fatigue_multiplier,sort_order
) values
  ('Economy',1.000,1.000,1),
  ('Premium Economy',1.450,0.850,2),
  ('Business',2.400,0.650,3),
  ('First Class',4.000,0.500,4)
on conflict(class_name) do update set
  price_multiplier=excluded.price_multiplier,
  fatigue_multiplier=excluded.fatigue_multiplier,
  sort_order=excluded.sort_order,
  updated_at=now();

create table if not exists public.travel_stay_tiers (
  tier_name text primary key
    check (tier_name in ('Budget','Standard','Premium','Luxury')),
  label text not null,
  base_nightly_cost integer not null check (base_nightly_cost >= 0),
  recovery_support_pct smallint not null default 0,
  sort_order smallint not null,
  updated_at timestamptz not null default now()
);

insert into public.travel_stay_tiers(
  tier_name,label,base_nightly_cost,recovery_support_pct,sort_order
) values
  ('Budget','Budget Hotel ★★',90,0,1),
  ('Standard','Standard Hotel ★★★',150,5,2),
  ('Premium','Premium Hotel ★★★★',240,10,3),
  ('Luxury','Luxury Hotel ★★★★★',420,15,4)
on conflict(tier_name) do update set
  label=excluded.label,
  base_nightly_cost=excluded.base_nightly_cost,
  recovery_support_pct=excluded.recovery_support_pct,
  sort_order=excluded.sort_order,
  updated_at=now();

-- Seed destination cost profiles from the existing training-camp economy.
with codes as (
  select upper(country_code) country_code
  from public.training_travel_country_reference
  union
  select upper(country_code) from public.training_camp_locations where country_code is not null
  union
  select upper(country_code) from public.tournament_series where country_code is not null
  union
  select upper(country_code) from public.player_home_city_options where country_code is not null
), camp_costs as (
  select upper(country_code) country_code,
         avg(cost_index)::numeric(6,3) hotel_cost_index
  from public.training_camp_locations
  where country_code is not null and cost_index is not null
  group by upper(country_code)
)
insert into public.travel_country_cost_profiles(country_code,hotel_cost_index,cost_tier)
select c.country_code,
       coalesce(cc.hotel_cost_index,1.000),
       case
         when coalesce(cc.hotel_cost_index,1.000)<0.925 then 'low'
         when coalesce(cc.hotel_cost_index,1.000)>1.175 then 'high'
         else 'standard'
       end
from codes c
left join camp_costs cc using(country_code)
on conflict(country_code) do update set
  hotel_cost_index=excluded.hotel_cost_index,
  cost_tier=excluded.cost_tier,
  updated_at=now();

-- Build one reusable catalog of all game destinations. Exact coordinates win;
-- until those exist, country reference coordinates provide a safe fallback.
with raw as (
  select h.city,upper(h.country_code) country_code,h.latitude,h.longitude,
         null::numeric cost_index,'home_city'::text source,1 priority
  from public.player_home_city_options h
  where h.city is not null and h.country_code is not null
  union all
  select t.city,upper(t.country_code),t.latitude,t.longitude,
         null::numeric,'tournament',2
  from public.tournament_series t
  where t.city is not null and t.country_code is not null
  union all
  select l.city,upper(l.country_code),l.latitude,l.longitude,
         l.cost_index,'training_camp',3
  from public.training_camp_locations l
  where l.city is not null and l.country_code is not null
), chosen as (
  select distinct on (lower(trim(r.city)),r.country_code)
    r.city,
    r.country_code,
    coalesce(r.latitude,cr.latitude::double precision) latitude,
    coalesce(r.longitude,cr.longitude::double precision) longitude,
    case
      when r.latitude is not null and r.longitude is not null then 'exact'
      when cr.country_code is not null then 'country_reference'
      else 'unknown'
    end coordinate_basis,
    coalesce(r.cost_index,cp.hotel_cost_index,1.000)::numeric(6,3) hotel_cost_index,
    coalesce(cp.cost_tier,'standard') cost_tier,
    r.source
  from raw r
  left join public.training_travel_country_reference cr
    on cr.country_code=r.country_code
  left join public.travel_country_cost_profiles cp
    on cp.country_code=r.country_code
  order by lower(trim(r.city)),r.country_code,
           (r.latitude is not null and r.longitude is not null) desc,
           r.priority desc
)
insert into public.travel_locations(
  city,country_code,latitude,longitude,coordinate_basis,
  hotel_cost_index,cost_tier,source
)
select city,country_code,latitude,longitude,coordinate_basis,
       hotel_cost_index,cost_tier,source
from chosen
on conflict do nothing;

alter table public.travel_country_cost_profiles enable row level security;
alter table public.travel_locations enable row level security;
alter table public.travel_pricing_rules enable row level security;
alter table public.travel_class_rules enable row level security;
alter table public.travel_stay_tiers enable row level security;

revoke all on public.travel_country_cost_profiles,
  public.travel_locations,
  public.travel_pricing_rules,
  public.travel_class_rules,
  public.travel_stay_tiers
from anon,authenticated;

create or replace function public.resolve_travel_location_v1(
  p_city text,
  p_country_code text,
  p_latitude double precision default null,
  p_longitude double precision default null
) returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  l public.travel_locations%rowtype;
  cr public.training_travel_country_reference%rowtype;
  cp public.travel_country_cost_profiles%rowtype;
  v_country text:=upper(trim(coalesce(p_country_code,'')));
begin
  select * into cp
  from public.travel_country_cost_profiles
  where country_code=v_country;

  if p_latitude is not null and p_longitude is not null then
    return jsonb_build_object(
      'city',p_city,'country_code',v_country,
      'latitude',p_latitude,'longitude',p_longitude,
      'coordinate_basis','exact',
      'hotel_cost_index',coalesce(cp.hotel_cost_index,1.000),
      'cost_tier',coalesce(cp.cost_tier,'standard')
    );
  end if;

  select * into l
  from public.travel_locations
  where lower(trim(city))=lower(trim(coalesce(p_city,'')))
    and upper(country_code)=v_country
    and is_active
  limit 1;

  if l.id is not null then
    return jsonb_build_object(
      'city',coalesce(p_city,l.city),'country_code',v_country,
      'latitude',l.latitude,'longitude',l.longitude,
      'coordinate_basis',l.coordinate_basis,
      'hotel_cost_index',l.hotel_cost_index,
      'cost_tier',l.cost_tier,
      'location_id',l.id
    );
  end if;

  select * into cr
  from public.training_travel_country_reference
  where country_code=v_country;

  return jsonb_build_object(
    'city',p_city,'country_code',v_country,
    'latitude',cr.latitude,'longitude',cr.longitude,
    'coordinate_basis',case when cr.country_code is null then 'unknown' else 'country_reference' end,
    'hotel_cost_index',coalesce(cp.hotel_cost_index,1.000),
    'cost_tier',coalesce(cp.cost_tier,'standard')
  );
end;
$$;

create or replace function public.quote_travel_v2(
  p_source_city text,
  p_source_country_code text,
  p_source_latitude double precision,
  p_source_longitude double precision,
  p_destination_city text,
  p_destination_country_code text,
  p_destination_latitude double precision,
  p_destination_longitude double precision,
  p_travel_class text default 'Economy',
  p_trip_mode text default 'one_way'
) returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  s jsonb;
  d jsonb;
  r public.travel_pricing_rules%rowtype;
  c public.travel_class_rules%rowtype;
  v_band text;
  v_basis text;
  v_km numeric;
  v_base numeric;
  v_base_cost integer;
  v_cost_one_way integer;
  v_total integer;
  v_base_fatigue integer;
  v_fatigue integer;
  v_hours numeric;
  v_legs integer;
begin
  if p_trip_mode not in ('one_way','round_trip') then
    raise exception 'Invalid trip mode.';
  end if;

  select * into c
  from public.travel_class_rules
  where class_name=p_travel_class;
  if c.class_name is null then raise exception 'Invalid travel class.'; end if;

  s:=public.resolve_travel_location_v1(
    p_source_city,p_source_country_code,p_source_latitude,p_source_longitude
  );
  d:=public.resolve_travel_location_v1(
    p_destination_city,p_destination_country_code,p_destination_latitude,p_destination_longitude
  );

  if upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,''))
     and lower(trim(coalesce(p_source_city,'')))<>''
     and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_destination_city,''))) then
    v_band:='same_city';
    v_km:=0;
    v_basis:='exact_city_match';
  elsif upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,'')) then
    v_band:='domestic';
    if s->>'coordinate_basis'='exact' and d->>'coordinate_basis'='exact' then
      v_km:=public.great_circle_km_v1(
        (s->>'latitude')::numeric,(s->>'longitude')::numeric,
        (d->>'latitude')::numeric,(d->>'longitude')::numeric
      );
      v_basis:='exact_coordinates';
    else
      v_km:=null;
      v_basis:='same_country_estimate';
    end if;
  else
    if (s->>'latitude') is not null and (d->>'latitude') is not null then
      v_km:=public.great_circle_km_v1(
        (s->>'latitude')::numeric,(s->>'longitude')::numeric,
        (d->>'latitude')::numeric,(d->>'longitude')::numeric
      );
      v_basis:=case
        when s->>'coordinate_basis'='exact' and d->>'coordinate_basis'='exact'
          then 'exact_coordinates'
        else 'country_reference_distance'
      end;
    else
      v_km:=null;
      v_basis:='continent_fallback';
    end if;
    v_band:=case
      when public.country_continent_v1(upper(p_source_country_code))=
           public.country_continent_v1(upper(p_destination_country_code))
        then 'regional'
      else 'intercontinental'
    end;
  end if;

  select * into r from public.travel_pricing_rules where band=v_band;

  if v_km is null then
    v_base_cost:=case v_band
      when 'same_city' then 20
      when 'domestic' then 45
      when 'regional' then 120
      else 350
    end;
    v_base_fatigue:=case v_band
      when 'same_city' then 1
      when 'domestic' then 2
      when 'regional' then 4
      else 9
    end;
  else
    v_base:=r.base_cost_one_way+v_km*r.cost_per_km;
    v_base_cost:=(round((greatest(
      r.minimum_cost_one_way,
      least(r.maximum_cost_one_way,v_base)
    ))/10.0)*10)::integer;

    if r.fatigue_distance_step_km is null then
      v_base_fatigue:=r.base_fatigue;
    else
      v_base_fatigue:=least(
        r.maximum_fatigue,
        greatest(
          r.base_fatigue,
          r.base_fatigue+round(v_km/r.fatigue_distance_step_km::numeric)::integer
        )
      );
    end if;
  end if;

  v_cost_one_way:=(round((v_base_cost*c.price_multiplier)/10.0)*10)::integer;
  v_fatigue:=greatest(1,round(v_base_fatigue*c.fatigue_multiplier)::integer);
  v_legs:=case when p_trip_mode='round_trip' then 2 else 1 end;
  v_total:=v_cost_one_way*v_legs;

  v_hours:=case
    when v_band='same_city' then 0.5
    when v_km is null then case v_band
      when 'domestic' then 2.5
      when 'regional' then 4.0
      else 10.0
    end
    else round((case
      when v_band='domestic' then 1.0+v_km/500.0
      when v_band='regional' then 1.5+v_km/650.0
      else 2.5+v_km/800.0
    end)::numeric,1)
  end;

  return jsonb_build_object(
    'source',s,
    'destination',d,
    'distance_km',case when v_km is null then null else v_km::integer end,
    'round_trip_km',case when v_km is null then null else (v_km*2)::integer end,
    'band',v_band,
    'basis',v_basis,
    'travel_class',c.class_name,
    'price_multiplier',c.price_multiplier,
    'fatigue_multiplier',c.fatigue_multiplier,
    'base_cost_one_way',v_base_cost,
    'cost_one_way',v_cost_one_way,
    'cost',v_total,
    'trip_mode',p_trip_mode,
    'base_arrival_fatigue',v_base_fatigue,
    'arrival_fatigue',v_fatigue,
    'estimated_hours_one_way',v_hours,
    'formula',case v_band
      when 'same_city' then 'Same-city local transfer'
      when 'domestic' then 'Domestic fare uses distance when exact city coordinates exist; otherwise a $45 one-way estimate'
      when 'regional' then 'Regional one-way fare = $40 + $0.055 × km, capped $90–$350'
      else 'Intercontinental one-way fare = $110 + $0.05 × km, capped $250–$1,200'
    end
  );
end;
$$;

create or replace function public.quote_accommodation_v1(
  p_city text,
  p_country_code text,
  p_base_unit_cost integer,
  p_units integer,
  p_party_size integer,
  p_rate_unit text default 'night'
) returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  loc jsonb;
  v_idx numeric;
  v_rate integer;
  v_total integer;
begin
  if p_base_unit_cost<0 or p_units<0 or p_party_size<1 then
    raise exception 'Invalid accommodation quote inputs.';
  end if;
  loc:=public.resolve_travel_location_v1(p_city,p_country_code,null,null);
  v_idx:=coalesce((loc->>'hotel_cost_index')::numeric,1.0);
  v_rate:=(round((p_base_unit_cost*v_idx)/10.0)*10)::integer;
  v_total:=v_rate*p_units*p_party_size;
  return jsonb_build_object(
    'city',p_city,'country_code',upper(p_country_code),
    'rate_unit',p_rate_unit,
    'base_unit_cost',p_base_unit_cost,
    'destination_cost_index',v_idx,
    'cost_tier',loc->>'cost_tier',
    'adjusted_unit_cost',v_rate,
    'units',p_units,
    'party_size',p_party_size,
    'total',v_total
  );
end;
$$;

-- Compatibility wrappers: existing Training Camp and itinerary callers now use
-- exactly the same pricing/fatigue engine.
create or replace function public.training_camp_travel_quote_v2(
  p_origin_city text,p_origin_country_code text,
  p_destination_city text,p_destination_country_code text
) returns jsonb
language plpgsql stable security definer set search_path=public
as $$
declare q jsonb;
begin
  q:=public.quote_travel_v2(
    p_origin_city,p_origin_country_code,null,null,
    p_destination_city,p_destination_country_code,null,null,
    'Economy','round_trip'
  );
  return q||jsonb_build_object(
    'one_way_km',q->'distance_km',
    'round_trip_km',q->'round_trip_km'
  );
end;
$$;

create or replace function public.travel_leg_quote_v1(
  p_source_city text,p_source_country_code text,
  p_source_latitude double precision,p_source_longitude double precision,
  p_destination_city text,p_destination_country_code text,
  p_destination_latitude double precision,p_destination_longitude double precision
) returns jsonb
language sql stable security definer set search_path=public
as $$
  select public.quote_travel_v2(
    p_source_city,p_source_country_code,p_source_latitude,p_source_longitude,
    p_destination_city,p_destination_country_code,p_destination_latitude,p_destination_longitude,
    'Economy','one_way'
  );
$$;

alter table public.player_travel_legs
  add column if not exists travel_class text not null default 'Economy';
alter table public.player_travel_legs
  add column if not exists base_estimated_cost integer;
alter table public.player_travel_legs
  add column if not exists price_multiplier numeric(6,3);
alter table public.player_travel_legs
  add column if not exists base_arrival_fatigue smallint;
alter table public.player_travel_legs
  add column if not exists fatigue_multiplier numeric(6,3);

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conname='player_travel_legs_travel_class_check'
  ) then
    alter table public.player_travel_legs
      add constraint player_travel_legs_travel_class_check
      check (travel_class in ('Economy','Premium Economy','Business','First Class'));
  end if;
end
$$;

create or replace function public.insert_planned_travel_leg_v1(
  p_player_id uuid,p_purpose text,
  p_source_type text,p_source_city text,p_source_country text,
  p_source_lat double precision,p_source_lon double precision,p_source_ref text,
  p_dest_type text,p_dest_city text,p_dest_country text,
  p_dest_lat double precision,p_dest_lon double precision,p_dest_ref text,
  p_departure integer,p_arrival integer,p_embedded boolean default false
) returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  q jsonb;
  v_id uuid;
  gd record;
  v_existing text;
  v_class text:='Economy';
begin
  if upper(coalesce(p_source_country,''))=upper(coalesce(p_dest_country,''))
     and lower(trim(coalesce(p_source_city,'')))<>''
     and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_dest_city,''))) then
    return null;
  end if;

  if p_dest_type='tournament'
     and coalesce(p_dest_ref,'')~*'^[0-9a-f-]{36}$' then
    select player_travel_class into v_class
    from public.player_tournament_preparation_plans
    where player_id=p_player_id and competition_id=p_dest_ref::uuid;
  elsif p_source_type='tournament'
     and coalesce(p_source_ref,'')~*'^[0-9a-f-]{36}$' then
    select player_travel_class into v_class
    from public.player_tournament_preparation_plans
    where player_id=p_player_id and competition_id=p_source_ref::uuid;
  end if;
  v_class:=coalesce(v_class,'Economy');

  q:=public.quote_travel_v2(
    p_source_city,p_source_country,p_source_lat,p_source_lon,
    p_dest_city,p_dest_country,p_dest_lat,p_dest_lon,
    v_class,'one_way'
  );

  insert into public.player_travel_legs(
    player_id,purpose,
    source_location_type,source_city,source_country_code,source_continent,
    source_latitude,source_longitude,
    destination_location_type,destination_city,destination_country_code,destination_continent,
    destination_latitude,destination_longitude,
    source_reference_id,destination_reference_id,
    departure_absolute_day,arrival_absolute_day,
    distance_km,estimated_cost,arrival_fatigue,travel_band,travel_basis,
    embedded_transition,status,
    travel_class,base_estimated_cost,price_multiplier,
    base_arrival_fatigue,fatigue_multiplier
  ) values(
    p_player_id,p_purpose,
    p_source_type,p_source_city,p_source_country,public.country_continent_v1(p_source_country),
    p_source_lat,p_source_lon,
    p_dest_type,p_dest_city,p_dest_country,public.country_continent_v1(p_dest_country),
    p_dest_lat,p_dest_lon,
    p_source_ref,p_dest_ref,p_departure,p_arrival,
    nullif(q->>'distance_km','')::integer,
    (q->>'cost')::integer,
    (q->>'arrival_fatigue')::smallint,
    q->>'band',q->>'basis',p_embedded,'planned',
    v_class,
    (q->>'base_cost_one_way')::integer,
    (q->>'price_multiplier')::numeric,
    (q->>'base_arrival_fatigue')::smallint,
    (q->>'fatigue_multiplier')::numeric
  ) returning id into v_id;

  if not p_embedded then
    select * into gd from public.absolute_game_day_v1(p_departure);
    select activity_type into v_existing
    from public.player_daily_activity
    where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;

    if v_existing is null or v_existing='home' then
      insert into public.player_daily_activity(
        player_id,season,month,day,activity_type,source,reference_id,note
      ) values(
        p_player_id,gd.season,gd.month,gd.day,
        'travel','travel_plan',v_id::text,
        format('Travel to %s',coalesce(p_dest_city,p_dest_country))
      )
      on conflict(player_id,season,month,day) do update set
        activity_type='travel',source='travel_plan',reference_id=v_id::text,
        note=excluded.note,updated_at=now()
      where public.player_daily_activity.effects_applied_at is null
        and public.player_daily_activity.activity_type='home';
    else
      update public.player_travel_legs
      set embedded_transition=true,updated_at=now()
      where id=v_id;
    end if;
  end if;

  return v_id;
end;
$$;

-- Training Camp quotes retain their existing public JSON shape while using
-- the shared route and destination-cost engines underneath.
create or replace function public.quote_training_camp_v2(
  p_program_id uuid,p_start_season integer,p_start_week smallint,
  p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star'
) returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_user uuid:=auth.uid();
  v_player public.players%rowtype;
  v_program public.training_camp_programs%rowtype;
  v_location public.training_camp_locations%rowtype;
  v_hotel public.training_camp_accommodation_tiers%rowtype;
  v_start_abs integer;
  v_end_abs integer;
  v_current_abs integer;
  v_start record;
  v_end record;
  v_training_total integer;
  v_hotel_weekly integer;
  v_hotel_total integer;
  v_travel integer;
  v_total integer;
  v_origin jsonb;
  v_travel_quote jsonb;
  v_accommodation_quote jsonb;
  v_origin_city text;
  v_origin_country text;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;

  select * into v_player from public.players where owner_user_id=v_user;
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into v_program
  from public.training_camp_programs
  where id=p_program_id and is_active;
  if v_program.id is null then raise exception 'Training camp program not found.'; end if;

  select * into v_location
  from public.training_camp_locations
  where id=v_program.location_id and is_active;

  select * into v_hotel
  from public.training_camp_accommodation_tiers
  where slug=p_accommodation_slug and is_active;
  if v_hotel.id is null then raise exception 'Accommodation option not found.'; end if;

  if p_duration_weeks not between 1 and 4 then
    raise exception 'Training camp duration must be between 1 and 4 weeks.';
  end if;
  if p_start_week not between 1 and 52 then
    raise exception 'Start week must be between 1 and 52.';
  end if;
  if p_start_week+p_duration_weeks-1>52 then
    raise exception 'Training camp cannot extend beyond Season Week 52.';
  end if;

  v_start_abs:=public.training_camp_week_start_absolute_v1(p_start_season,p_start_week);
  v_end_abs:=v_start_abs+p_duration_weeks*7-1;
  select public.game_day_absolute_v1(season,month,day)
    into v_current_abs
  from public.get_current_game_day_internal_v1();
  if v_start_abs<v_current_abs then
    raise exception 'Training camp must begin at the start of a current or future competition week.';
  end if;

  select * into v_start from public.absolute_game_day_v1(v_start_abs);
  select * into v_end from public.absolute_game_day_v1(v_end_abs);

  v_origin:=public.resolve_player_origin_before_day_v1(v_player.id,v_start_abs);
  v_origin_city:=nullif(v_origin->>'city','');
  v_origin_country:=v_origin->>'country_code';
  v_training_total:=v_program.weekly_cost*p_duration_weeks;

  v_accommodation_quote:=public.quote_accommodation_v1(
    v_location.city,v_location.country_code,
    v_hotel.base_weekly_cost,p_duration_weeks,1,'week'
  );
  v_hotel_weekly:=(v_accommodation_quote->>'adjusted_unit_cost')::integer;
  v_hotel_total:=(v_accommodation_quote->>'total')::integer;

  v_travel_quote:=public.training_camp_travel_quote_v2(
    v_origin_city,v_origin_country,v_location.city,v_location.country_code
  );
  v_travel:=(v_travel_quote->>'cost')::integer;
  v_total:=v_training_total+v_hotel_total+v_travel;

  return jsonb_build_object(
    'program_id',v_program.id,
    'camp_name',v_program.name,
    'training_quality',jsonb_build_object('tier',v_program.quality_tier,'multiplier',v_program.quality_multiplier),
    'quality_tier',v_program.quality_tier,
    'facility_rating',v_program.rating,
    'quality_multiplier',v_program.quality_multiplier,
    'start_season',p_start_season,
    'start_week',p_start_week,
    'start_absolute_day',v_start_abs,
    'end_absolute_day',v_end_abs,
    'start',jsonb_build_object('season',v_start.season,'month',v_start.month,'day',v_start.day),
    'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),
    'duration_weeks',p_duration_weeks,
    'origin',(v_origin-'city'-'country_code')||jsonb_build_object(
      'city',coalesce(v_origin_city,'Home base not set'),
      'country_code',public.country_flag_emoji_v1(v_origin_country),
      'raw_city',v_origin_city,
      'raw_country_code',v_origin_country
    ),
    'destination',jsonb_build_object(
      'city',v_location.city,'country',v_location.country,
      'country_code',public.country_flag_emoji_v1(v_location.country_code),
      'raw_country_code',v_location.country_code,
      'continent',v_location.continent,
      'cost_index',(v_accommodation_quote->>'destination_cost_index')::numeric
    ),
    'training_fee_weekly',v_program.weekly_cost,
    'training_fee_total',v_training_total,
    'accommodation',jsonb_build_object(
      'id',v_hotel.id,'slug',v_hotel.slug,'name',v_hotel.name,
      'stars',v_hotel.star_rating,
      'base_weekly_cost',v_hotel.base_weekly_cost,
      'destination_cost_index',(v_accommodation_quote->>'destination_cost_index')::numeric,
      'weekly_cost',v_hotel_weekly,'total',v_hotel_total,
      'rest_quality',v_hotel.rest_quality,
      'fatigue_mitigation',v_hotel.fatigue_mitigation,
      'weekly_morale_bonus',v_hotel.weekly_morale_bonus,
      'weekly_focus_bonus',v_hotel.weekly_focus_bonus,
      'description',v_hotel.description,
      'cost_tier',v_accommodation_quote->>'cost_tier'
    ),
    'travel',v_travel_quote,
    'travel_cost',v_travel,
    'travel_type','Round-trip estimate',
    'staff_count',0,
    'staff_cost',0,
    'grand_total',v_total,
    'engine','universal_travel_stay_v1'
  );
end;
$$;

create or replace function public.quote_tournament_preparation_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_player_travel_class text default 'Economy',
  p_staff_travel_class text default 'Economy',
  p_hotel_tier text default 'Standard',
  p_selected_staff_contract_ids uuid[] default '{}'::uuid[]
) returns jsonb
language plpgsql stable security definer set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_city text;
  v_country text;
  v_lat double precision;
  v_lon double precision;
  v_season integer;
  v_min_week integer;
  v_max_week integer;
  v_start_abs integer;
  v_end_abs integer;
  v_draw_start integer;
  v_first_match integer;
  v_arrival_abs integer;
  v_min_nights integer;
  v_max_nights integer;
  v_origin jsonb;
  v_travel jsonb;
  v_staff_travel jsonb;
  v_hotel public.travel_stay_tiers%rowtype;
  v_hotel_min jsonb;
  v_hotel_max jsonb;
  v_staff_count integer;
  v_invalid integer;
  v_draw_type text:='main_draw';
  v_party integer;
  v_player_cost integer;
  v_staff_cost integer;
  v_total_min integer;
  v_total_max integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where id=p_player_id and owner_user_id=v_uid;
  if v_player.id is null then raise exception 'Player access denied.'; end if;

  select ts.city,ts.country_code,ts.latitude,ts.longitude,
         te.season_number,min(ss.season_week),max(ss.season_week)
    into v_city,v_country,v_lat,v_lon,v_season,v_min_week,v_max_week
  from public.tournament_world_competitions wc
  join public.tournament_editions te on te.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=te.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
  where wc.id=p_competition_id
    and wc.world=v_player.world
    and wc.status<>'canceled'
    and te.status<>'canceled'
  group by ts.city,ts.country_code,ts.latitude,ts.longitude,te.season_number;

  if v_city is null then raise exception 'Tournament unavailable.'; end if;

  select coalesce(e.draw_type,'main_draw') into v_draw_type
  from public.tournament_entries e
  where e.player_id=p_player_id and e.competition_id=p_competition_id
  limit 1;
  v_draw_type:=coalesce(v_draw_type,'main_draw');

  v_start_abs:=((v_season-1)*366)+2+((v_min_week-1)*7);
  v_end_abs:=((v_season-1)*366)+2+((v_max_week-1)*7)+6;

  select min(((v_season-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))
    into v_draw_start
  from public.tournament_matches m
  where m.competition_id=p_competition_id and m.draw_type=v_draw_type;

  select min(((v_season-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))
    into v_first_match
  from public.tournament_matches m
  where m.competition_id=p_competition_id
    and (m.player1_id=p_player_id or m.player2_id=p_player_id);

  v_draw_start:=coalesce(v_draw_start,v_start_abs);
  v_arrival_abs:=v_draw_start-1;
  v_min_nights:=greatest(2,coalesce(v_first_match,v_draw_start)-v_arrival_abs+1);
  v_max_nights:=greatest(v_min_nights,v_end_abs-v_arrival_abs+1);

  v_origin:=public.resolve_player_origin_before_day_v1(p_player_id,v_arrival_abs);
  v_travel:=public.quote_travel_v2(
    v_origin->>'city',v_origin->>'country_code',
    nullif(v_origin->>'latitude','')::double precision,
    nullif(v_origin->>'longitude','')::double precision,
    v_city,v_country,v_lat,v_lon,
    p_player_travel_class,'round_trip'
  );

  select count(*) into v_staff_count
  from unnest(coalesce(p_selected_staff_contract_ids,'{}'::uuid[]));
  select count(*) into v_invalid
  from unnest(coalesce(p_selected_staff_contract_ids,'{}'::uuid[])) x
  left join public.player_staff_contracts c
    on c.id=x and c.player_id=p_player_id and c.status='active'
  where c.id is null;
  if v_invalid>0 then raise exception 'One or more selected staff contracts are unavailable.'; end if;
  if v_staff_count>6 then raise exception 'A maximum of six staff members can travel.'; end if;

  v_staff_travel:=public.quote_travel_v2(
    v_origin->>'city',v_origin->>'country_code',
    nullif(v_origin->>'latitude','')::double precision,
    nullif(v_origin->>'longitude','')::double precision,
    v_city,v_country,v_lat,v_lon,
    p_staff_travel_class,'round_trip'
  );

  select * into v_hotel
  from public.travel_stay_tiers
  where tier_name=p_hotel_tier;
  if v_hotel.tier_name is null then raise exception 'Invalid hotel tier.'; end if;

  v_party:=1+v_staff_count;
  v_hotel_min:=public.quote_accommodation_v1(
    v_city,v_country,v_hotel.base_nightly_cost,v_min_nights,v_party,'night'
  );
  v_hotel_max:=public.quote_accommodation_v1(
    v_city,v_country,v_hotel.base_nightly_cost,v_max_nights,v_party,'night'
  );

  v_player_cost:=(v_travel->>'cost')::integer;
  v_staff_cost:=(v_staff_travel->>'cost')::integer*v_staff_count;
  v_total_min:=v_player_cost+v_staff_cost+(v_hotel_min->>'total')::integer;
  v_total_max:=v_player_cost+v_staff_cost+(v_hotel_max->>'total')::integer;

  return jsonb_build_object(
    'engine','universal_travel_stay_v1',
    'origin',v_origin,
    'destination',jsonb_build_object('city',v_city,'country_code',v_country),
    'draw_type',v_draw_type,
    'arrival_absolute_day',v_arrival_abs,
    'minimum_nights',v_min_nights,
    'maximum_nights',v_max_nights,
    'party_size',v_party,
    'staff_count',v_staff_count,
    'player_travel',v_travel,
    'staff_travel',v_staff_travel,
    'player_travel_cost',v_player_cost,
    'staff_travel_cost',v_staff_cost,
    'hotel',jsonb_build_object(
      'tier',v_hotel.tier_name,
      'label',v_hotel.label,
      'base_nightly_cost',v_hotel.base_nightly_cost,
      'recovery_support_pct',v_hotel.recovery_support_pct,
      'minimum',v_hotel_min,
      'maximum',v_hotel_max
    ),
    'minimum_total',v_total_min,
    'maximum_total',v_total_max
  );
end;
$$;

alter table public.player_tournament_preparation_plans
  add column if not exists quote_snapshot jsonb;

create or replace function public.get_tournament_preparation_v1(
  p_player_id uuid,p_competition_id uuid
) returns jsonb
language plpgsql stable security definer set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_quote jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(
    select 1 from public.players p
    where p.id=p_player_id and p.owner_user_id=v_uid
  ) then raise exception 'Player access denied.'; end if;

  select * into v_plan
  from public.player_tournament_preparation_plans p
  where p.player_id=p_player_id and p.competition_id=p_competition_id;

  if not found then
    v_quote:=public.quote_tournament_preparation_v1(
      p_player_id,p_competition_id,'Economy','Economy','Standard','{}'::uuid[]
    );
    return jsonb_build_object(
      'saved',false,
      'player_travel_class','Economy',
      'staff_travel_class','Economy',
      'hotel_tier','Standard',
      'selected_staff_contract_ids','[]'::jsonb,
      'tactic',jsonb_build_object(
        'preset','Balanced','approach','Balanced','rally','Balanced rallies',
        'serve','Balanced','returnGame','Balanced','courtPosition','Normal baseline',
        'target','Automatic','risk','Balanced'
      ),
      'quote',v_quote
    );
  end if;

  v_quote:=public.quote_tournament_preparation_v1(
    p_player_id,p_competition_id,
    v_plan.player_travel_class,v_plan.staff_travel_class,
    v_plan.hotel_tier,v_plan.selected_staff_contract_ids
  );

  return jsonb_build_object(
    'saved',true,
    'player_travel_class',v_plan.player_travel_class,
    'staff_travel_class',v_plan.staff_travel_class,
    'hotel_tier',v_plan.hotel_tier,
    'selected_staff_contract_ids',to_jsonb(v_plan.selected_staff_contract_ids),
    'tactic',jsonb_build_object(
      'preset',v_plan.tactic_preset,'approach',v_plan.tactic_approach,
      'rally',v_plan.tactic_rally,'serve',v_plan.tactic_serve,
      'returnGame',v_plan.tactic_return,'courtPosition',v_plan.tactic_court_position,
      'target',v_plan.tactic_target,'risk',v_plan.tactic_risk
    ),
    'quote',v_quote,
    'saved_quote_snapshot',v_plan.quote_snapshot,
    'updated_at',v_plan.updated_at
  );
end;
$$;

create or replace function public.save_tournament_preparation_v1(
  p_player_id uuid,p_competition_id uuid,
  p_player_travel_class text,p_staff_travel_class text,p_hotel_tier text,
  p_selected_staff_contract_ids uuid[],
  p_tactic_preset text,p_tactic_approach text,p_tactic_rally text,
  p_tactic_serve text,p_tactic_return text,p_tactic_court_position text,
  p_tactic_target text,p_tactic_risk text
) returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_staff uuid[]:=coalesce(p_selected_staff_contract_ids,'{}'::uuid[]);
  v_quote jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if not exists(
    select 1 from public.players p
    where p.id=p_player_id and p.owner_user_id=v_uid
  ) then raise exception 'Player access denied.'; end if;
  if not exists(
    select 1 from public.tournament_entries e
    where e.player_id=p_player_id and e.competition_id=p_competition_id
  ) then raise exception 'Player is not entered in this tournament.'; end if;

  if p_player_travel_class not in ('Economy','Premium Economy','Business','First Class') then
    raise exception 'Invalid player travel class.';
  end if;
  if p_staff_travel_class not in ('Economy','Premium Economy','Business','First Class') then
    raise exception 'Invalid staff travel class.';
  end if;
  if p_hotel_tier not in ('Budget','Standard','Premium','Luxury') then
    raise exception 'Invalid hotel tier.';
  end if;
  if exists(
    select 1
    from unnest(v_staff) u(contract_id)
    left join public.player_staff_contracts c
      on c.id=u.contract_id and c.player_id=p_player_id and c.status='active'
    where c.id is null
  ) then raise exception 'One or more selected staff contracts are not active for this player.'; end if;

  select coalesce(array_agg(distinct x order by x),'{}'::uuid[])
    into v_staff
  from unnest(v_staff) x;

  v_quote:=public.quote_tournament_preparation_v1(
    p_player_id,p_competition_id,
    p_player_travel_class,p_staff_travel_class,p_hotel_tier,v_staff
  );

  insert into public.player_tournament_preparation_plans(
    owner_user_id,player_id,competition_id,
    player_travel_class,staff_travel_class,hotel_tier,selected_staff_contract_ids,
    tactic_preset,tactic_approach,tactic_rally,tactic_serve,tactic_return,
    tactic_court_position,tactic_target,tactic_risk,quote_snapshot,updated_at
  ) values(
    v_uid,p_player_id,p_competition_id,
    p_player_travel_class,p_staff_travel_class,p_hotel_tier,v_staff,
    p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,p_tactic_return,
    p_tactic_court_position,p_tactic_target,p_tactic_risk,v_quote,now()
  )
  on conflict(player_id,competition_id) do update set
    owner_user_id=excluded.owner_user_id,
    player_travel_class=excluded.player_travel_class,
    staff_travel_class=excluded.staff_travel_class,
    hotel_tier=excluded.hotel_tier,
    selected_staff_contract_ids=excluded.selected_staff_contract_ids,
    tactic_preset=excluded.tactic_preset,
    tactic_approach=excluded.tactic_approach,
    tactic_rally=excluded.tactic_rally,
    tactic_serve=excluded.tactic_serve,
    tactic_return=excluded.tactic_return,
    tactic_court_position=excluded.tactic_court_position,
    tactic_target=excluded.tactic_target,
    tactic_risk=excluded.tactic_risk,
    quote_snapshot=excluded.quote_snapshot,
    updated_at=now();

  perform public.rebuild_player_travel_plan_v1(p_player_id);
  return public.get_tournament_preparation_v1(p_player_id,p_competition_id);
end;
$$;

revoke all on function public.resolve_travel_location_v1(text,text,double precision,double precision) from public,anon;
revoke all on function public.quote_travel_v2(text,text,double precision,double precision,text,text,double precision,double precision,text,text) from public,anon;
revoke all on function public.quote_accommodation_v1(text,text,integer,integer,integer,text) from public,anon;
revoke all on function public.training_camp_travel_quote_v2(text,text,text,text) from public,anon;
revoke all on function public.travel_leg_quote_v1(text,text,double precision,double precision,text,text,double precision,double precision) from public,anon;
revoke all on function public.quote_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[]) from public,anon;
revoke all on function public.get_tournament_preparation_v1(uuid,uuid) from public,anon;
revoke all on function public.save_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[],text,text,text,text,text,text,text,text) from public,anon;

grant execute on function public.resolve_travel_location_v1(text,text,double precision,double precision) to authenticated;
grant execute on function public.quote_travel_v2(text,text,double precision,double precision,text,text,double precision,double precision,text,text) to authenticated;
grant execute on function public.quote_accommodation_v1(text,text,integer,integer,integer,text) to authenticated;
grant execute on function public.training_camp_travel_quote_v2(text,text,text,text) to authenticated;
grant execute on function public.travel_leg_quote_v1(text,text,double precision,double precision,text,text,double precision,double precision) to authenticated;
grant execute on function public.quote_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[]) to authenticated;
grant execute on function public.get_tournament_preparation_v1(uuid,uuid) to authenticated;
grant execute on function public.save_tournament_preparation_v1(uuid,uuid,text,text,text,uuid[],text,text,text,text,text,text,text,text) to authenticated;

-- Rebuild only future unprocessed itineraries; current game time is untouched.
select public.rebuild_player_travel_plan_v1(p.id)
from public.players p
where p.player_type='human' and p.owner_user_id is not null;
