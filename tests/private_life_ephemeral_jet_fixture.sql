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
 '{"tournament_travel_eligible":true,"max_range_km":2000,"passenger_capacity":7,"base_trip_cost":2000,"cost_per_km":3,"travel_fatigue_reduction_bps":9000}'::jsonb),
 ('test_prop_plane','private_jet','Test propeller plane',2,
 '{"tournament_travel_eligible":false,"max_range_km":1000,"passenger_capacity":4,"base_trip_cost":1000,"cost_per_km":2,"travel_fatigue_reduction_bps":1000}'::jsonb);

create table public.tournament_entries(
 player_id uuid references public.players(id),
 competition_id uuid not null,
 primary key(player_id,competition_id)
);
create table public.player_tournament_preparation_plans(
 player_id uuid references public.players(id),
 competition_id uuid not null,
 player_travel_class text default 'Economy',
 staff_travel_class text default 'Economy',
 hotel_tier text default 'Standard',
 selected_staff_contract_ids uuid[] default '{}'::uuid[],
 primary key(player_id,competition_id)
);
insert into public.tournament_entries(player_id,competition_id)
 values('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444');
insert into public.player_tournament_preparation_plans(player_id,competition_id)
 values('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444');
create or replace function public.quote_tournament_preparation_v1(
 p_player_id uuid,p_competition_id uuid,p_player_travel_class text default 'Economy',
 p_staff_travel_class text default 'Economy',p_hotel_tier text default 'Standard',
 p_selected_staff_contract_ids uuid[] default '{}'::uuid[])
returns jsonb language sql stable as $quote_prep$
 select jsonb_build_object(
  'origin',jsonb_build_object('city','Belgrade','country_code','RS'),
  'destination',jsonb_build_object('city','Paris','country_code','FR'),
  'arrival_absolute_day',395,
  'player_travel',jsonb_build_object('distance_km',1600))
$quote_prep$;
