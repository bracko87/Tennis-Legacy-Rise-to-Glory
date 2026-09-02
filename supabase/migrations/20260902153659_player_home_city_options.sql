create table if not exists public.player_home_city_options (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.countries(code) on update cascade on delete cascade,
  city text not null,
  sort_order smallint not null check (sort_order between 1 and 10),
  latitude double precision,
  longitude double precision,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(country_code, city),
  unique(country_code, sort_order)
);

create index if not exists player_home_city_options_country_idx
  on public.player_home_city_options(country_code, is_active, sort_order);

alter table public.player_home_city_options enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='player_home_city_options' and policyname='player_home_city_options_read'
  ) then
    create policy player_home_city_options_read on public.player_home_city_options
      for select to authenticated using (is_active);
  end if;
end $$;

create or replace function public.get_player_creation_countries_v1()
returns table(code text, name text)
language sql stable security definer
set search_path to 'public'
as $$
  select c.code, c.name
  from public.countries c
  where c.is_active
    and exists (
      select 1 from public.player_home_city_options h
      where h.country_code=c.code and h.is_active
    )
  order by c.name;
$$;

create or replace function public.get_player_home_city_options_v1(p_country_code text)
returns table(city text, sort_order smallint, latitude double precision, longitude double precision)
language sql stable security definer
set search_path to 'public'
as $$
  select h.city, h.sort_order, h.latitude, h.longitude
  from public.player_home_city_options h
  where h.country_code=upper(coalesce(p_country_code,'')) and h.is_active
  order by h.sort_order, h.city;
$$;

create or replace function public.validate_player_home_city_v1()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if new.home_city is null or btrim(new.home_city)='' then
    return new;
  end if;

  if not exists (
    select 1
    from public.player_home_city_options h
    where h.country_code=upper(new.country_code)
      and lower(h.city)=lower(btrim(new.home_city))
      and h.is_active
  ) then
    raise exception 'The selected home city is not available for this country.';
  end if;

  select h.city into new.home_city
  from public.player_home_city_options h
  where h.country_code=upper(new.country_code)
    and lower(h.city)=lower(btrim(new.home_city))
    and h.is_active
  order by h.sort_order
  limit 1;

  return new;
end;
$$;

drop trigger if exists validate_player_home_city on public.players;
create trigger validate_player_home_city
before insert or update of country_code, home_city on public.players
for each row execute function public.validate_player_home_city_v1();

create or replace function public.sync_player_home_location_v1()
returns trigger
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_lat double precision;
  v_lon double precision;
begin
  select h.latitude, h.longitude into v_lat, v_lon
  from public.player_home_city_options h
  where h.country_code=upper(new.country_code)
    and lower(h.city)=lower(coalesce(new.home_city,''))
    and h.is_active
  order by h.sort_order
  limit 1;

  insert into public.player_location_state(
    player_id,current_city,current_country_code,current_continent,
    current_latitude,current_longitude,location_type,updated_at
  )
  values(
    new.id,new.home_city,new.country_code,public.country_continent_v1(new.country_code),
    v_lat,v_lon,'home',now()
  )
  on conflict(player_id) do update set
    current_city=case when public.player_location_state.location_type='home' then excluded.current_city else public.player_location_state.current_city end,
    current_country_code=case when public.player_location_state.location_type='home' then excluded.current_country_code else public.player_location_state.current_country_code end,
    current_continent=case when public.player_location_state.location_type='home' then excluded.current_continent else public.player_location_state.current_continent end,
    current_latitude=case when public.player_location_state.location_type='home' then excluded.current_latitude else public.player_location_state.current_latitude end,
    current_longitude=case when public.player_location_state.location_type='home' then excluded.current_longitude else public.player_location_state.current_longitude end,
    updated_at=now();

  return new;
end;
$$;
