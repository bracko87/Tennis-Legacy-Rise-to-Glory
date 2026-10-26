-- Isolated PostgreSQL test fixture. Synthetic player IDs and fake game clock only.
-- This database is disposable and has no Supabase connectivity or user records.
create extension if not exists pgcrypto;
create schema if not exists auth;
create schema if not exists cron;
do $$
begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end $$;
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('app.test_uid',true),'')::uuid
$$;
create or replace function cron.schedule(p_name text,p_expr text,p_command text)
 returns bigint language sql as $$select 1::bigint$$;

create table public.players(
 id uuid primary key,
 owner_user_id uuid,
 player_type text default 'human',
 country_code text not null,
 home_city text not null
);
create table public.player_skills(
 player_id uuid primary key references public.players(id),
 morale integer not null default 50,
 updated_at timestamptz default now()
);
create table public.private_life_asset_catalog(
 code text primary key,
 category text not null
);
create table public.private_life_property_locations(
 code text primary key,
 city text not null,
 country_code text not null
);
create table public.private_life_player_assets(
 id uuid primary key,
 player_id uuid not null references public.players(id),
 catalog_code text not null references public.private_life_asset_catalog(code),
 location_code text references public.private_life_property_locations(code),
 acquisition_type text default 'purchase',
 purchase_absolute_day integer,
 sold_absolute_day integer
);
create table public.private_life_asset_sale_listings(
 id uuid default gen_random_uuid() primary key,
 player_id uuid not null references public.players(id),
 player_asset_id uuid not null references public.private_life_player_assets(id),
 status text default 'pending'
);
create table public.player_location_state(
 player_id uuid primary key references public.players(id),
 current_city text,
 current_country_code text,
 current_latitude double precision,
 current_longitude double precision,
 location_type text default 'home'
);
create table public.player_daily_activity(
 player_id uuid references public.players(id),
 season integer,
 month integer,
 day integer,
 activity_type text
);
create table public.player_travel_legs(
 id uuid primary key,
 player_id uuid references public.players(id),
 status text not null default 'planned',
 departure_absolute_day integer,
 destination_city text,
 destination_country_code text
);
create table public.test_career_transactions(
 player_id uuid references public.players(id),
 amount bigint not null,
 idempotency_key text not null unique
);
create or replace function public.get_current_game_day_internal_v1()
returns table(season integer,month integer,day integer) language sql stable as $$
 select 1::integer, coalesce(nullif(current_setting('app.month',true),'')::integer,1),
 coalesce(nullif(current_setting('app.day',true),'')::integer,1)
$$;
create or replace function public.game_day_absolute_v1(p_season integer,p_month integer,p_day integer)
returns integer language sql immutable as $$
 select p_season*360+p_month*30+p_day
$$;
create or replace function public.private_life_current_player_v1()
returns uuid language plpgsql stable as $$
declare v_id uuid;
begin
 select id into v_id from public.players where owner_user_id=auth.uid() and player_type='human' limit 1;
 if v_id is null then raise exception 'No player in synthetic session'; end if;
 return v_id;
end $$;
create or replace function public.resolve_location_coordinates_v1(
 p_city text,p_country_code text,p_latitude double precision,p_longitude double precision)
 returns jsonb language sql stable as $$
 select jsonb_build_object('city',p_city,'country_code',p_country_code,'latitude',0,'longitude',0)
$$;
create or replace function public.insert_planned_travel_leg_v1(
 p_player_id uuid,p_purpose text,p_source_type text,p_source_city text,p_source_country text,
 p_source_lat double precision,p_source_lon double precision,p_source_ref text,
 p_dest_type text,p_dest_city text,p_dest_country text,p_dest_lat double precision,p_dest_lon double precision,
 p_dest_ref text,p_departure integer,p_arrival integer,p_embedded boolean default false)
returns uuid language plpgsql as $$
declare v_id uuid:=gen_random_uuid();
begin
 insert into public.player_travel_legs(id,player_id,departure_absolute_day,destination_city,destination_country_code)
 values(v_id,p_player_id,p_departure,p_dest_city,p_dest_country);
 return v_id;
end $$;
create or replace function public.process_travel_leg_v1(p_leg_id uuid)
returns jsonb language plpgsql as $$
declare v_leg public.player_travel_legs%rowtype;
begin
 select * into v_leg from public.player_travel_legs where id=p_leg_id for update;
 if v_leg.status<>'completed' then
  update public.player_travel_legs set status='completed' where id=p_leg_id;
  update public.player_location_state set current_city=v_leg.destination_city,
    current_country_code=v_leg.destination_country_code,location_type='home'
    where player_id=v_leg.player_id;
 end if;
 return jsonb_build_object('status','completed');
end $$;
create or replace function public.post_career_finance_transaction_v1(
 p_player_id uuid,p_amount bigint,p_category text,p_subcategory text,p_description text,
 p_source_type text,p_source_id text,p_idempotency_key text,
 p_metadata jsonb default '{}'::jsonb,p_require_funds boolean default true,p_game_absolute_day integer default null)
returns jsonb language plpgsql as $$
begin
 insert into public.test_career_transactions(player_id,amount,idempotency_key)
 values(p_player_id,p_amount,p_idempotency_key)
 on conflict(idempotency_key) do nothing;
 return jsonb_build_object('status','recorded');
end $$;
create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb language sql as $$ select jsonb_build_object('status','unchanged') $$;

insert into public.players(id,owner_user_id,country_code,home_city)
 values('11111111-1111-1111-1111-111111111111','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','RS','Belgrade');
insert into public.player_location_state(player_id,current_city,current_country_code,location_type)
 values('11111111-1111-1111-1111-111111111111','Belgrade','RS','home');
insert into public.player_skills(player_id,morale) values('11111111-1111-1111-1111-111111111111',50);
insert into public.private_life_asset_catalog(code,category)
 values('watch_a','watch'),('watch_b','watch'),('car_a','car'),('villa_a','house_villa');
insert into public.private_life_property_locations(code,city,country_code)
 values('barcelona','Barcelona','ES');
select set_config('app.test_uid','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',false);
select set_config('app.month','1',false);
select set_config('app.day','1',false);
