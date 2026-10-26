-- Additional isolated fixtures for executing the actual jet quote/position functions.
alter table public.private_life_asset_catalog add column name text;
alter table public.private_life_asset_catalog add column tier integer default 1;
alter table public.private_life_asset_catalog add column metadata jsonb default '{}'::jsonb;
alter table public.private_life_asset_catalog add column purchase_price bigint default 100000;
alter table public.private_life_player_assets add column purchase_price bigint default 100000;
alter table public.player_travel_legs add column jet_asset_id uuid;
alter table public.player_travel_legs add column created_at timestamptz default now();
create table public.player_private_jet_positions (
 owned_asset_id uuid primary key references public.private_life_player_assets(id),
 player_id uuid not null references public.players(id),
 city text not null,country_code text not null,
 updated_at timestamptz not null default now()
);
create or replace function public.quote_travel_v2(
 p_source_city text,p_source_country text,p_source_lat double precision,
 p_source_lon double precision,p_dest_city text,p_dest_country text,
 p_dest_lat double precision,p_dest_lon double precision,
 p_class text default 'Economy',p_trip_mode text default 'one_way')
 returns jsonb language sql stable as $$
 select jsonb_build_object(
   'distance_km',
   case when p_source_city=p_dest_city then 0
        when p_dest_city='Tokyo' then 9000 else 1000 end,
   'cost',case when p_trip_mode='round_trip' then 1000 else 500 end)
$$;
insert into public.private_life_asset_catalog(code,category,name,tier,metadata)
 values('test_real_jet','private_jet','Test business jet',4,
 '{"tournament_travel_eligible":true,"max_range_km":2000,"passenger_capacity":4,"base_trip_cost":2000,"cost_per_km":3,"travel_fatigue_reduction_bps":9000}'::jsonb),
 ('test_prop_plane','private_jet','Test propeller plane',2,
 '{"tournament_travel_eligible":false,"max_range_km":1000,"passenger_capacity":4,"base_trip_cost":1000,"cost_per_km":2,"travel_fatigue_reduction_bps":1000}'::jsonb);
