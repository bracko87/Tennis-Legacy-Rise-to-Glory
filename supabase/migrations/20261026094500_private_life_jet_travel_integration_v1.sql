
-- Private aircraft travel and booked-mode pricing. All values are in game USD.
create table if not exists public.player_private_jet_positions (
 owned_asset_id uuid primary key references public.private_life_player_assets(id) on delete cascade,
 player_id uuid not null references public.players(id) on delete cascade,
 city text not null,
 country_code text not null,
 updated_at timestamptz not null default now()
);
create table if not exists public.player_tournament_travel_selection (
 player_id uuid not null references public.players(id) on delete cascade,
 competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
 travel_mode text not null check(travel_mode in ('commercial','private_jet')),
 owned_jet_asset_id uuid references public.private_life_player_assets(id),
 updated_at timestamptz not null default now(),
 primary key(player_id,competition_id)
);
alter table public.player_travel_legs add column if not exists travel_mode text not null default 'commercial'
 check(travel_mode in ('commercial','private_jet'));
alter table public.player_travel_legs add column if not exists jet_asset_id uuid references public.private_life_player_assets(id);
alter table public.player_travel_legs add column if not exists jet_quote jsonb;
alter table public.player_private_jet_positions enable row level security;
alter table public.player_tournament_travel_selection enable row level security;
revoke all on public.player_private_jet_positions,public.player_tournament_travel_selection from anon,authenticated;
grant select on public.player_private_jet_positions,public.player_tournament_travel_selection to authenticated;
drop policy if exists player_jet_position_owner_read on public.player_private_jet_positions;
create policy player_jet_position_owner_read on public.player_private_jet_positions
 for select to authenticated using(exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=(select auth.uid())));
drop policy if exists player_tournament_mode_owner_read on public.player_tournament_travel_selection;
create policy player_tournament_mode_owner_read on public.player_tournament_travel_selection
 for select to authenticated using(exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=(select auth.uid())));

-- Small hobby planes remain lifestyle-only; never infer eligibility from category alone.
update public.private_life_asset_catalog c
set metadata=coalesce(c.metadata,'{}'::jsonb) || jsonb_build_object(
 'tournament_travel_eligible', (c.metadata->>'propulsion'='jet' or c.code like 'jet_%'),
 'passenger_capacity',coalesce(nullif(c.metadata->>'aircraft_seats','')::integer,
   case when c.tier>=6 then 13 when c.tier=5 then 10 when c.tier=4 then 7 else 4 end),
 'max_range_km',case when c.tier>=6 then 12500 when c.tier=5 then 7000 when c.tier=4 then 4000 else 2600 end,
 'base_trip_cost',case when c.tier>=6 then 9500 when c.tier=5 then 6500 when c.tier=4 then 4000 else 2500 end,
 'cost_per_km',case when c.tier>=6 then 13 when c.tier=5 then 9 when c.tier=4 then 6 else 4 end,
 'travel_fatigue_reduction_bps',case when c.tier>=6 then 5000 when c.tier=5 then 4300 when c.tier=4 then 3200 else 2200 end
 ),description=replace(c.description,
 'Ownership reduces tournament travel fatigue by 90% while the jet is owned.',
 'Tournament flights require a booking and payment of operating costs.'),
 updated_at=now()
where c.category='private_jet';


-- An aircraft's physical position is fixed at purchase. Moving Home Base must
-- not teleport an already-owned jet to another country for free.
create or replace function public.initialize_private_jet_position_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $
declare v_city text;v_country text;
begin
 if new.sold_absolute_day is not null then return new; end if;
 if not exists(select 1 from public.private_life_asset_catalog c
   where c.code=new.catalog_code and c.category='private_jet'
   and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false))
 then return new; end if;
 select coalesce(nullif(ls.current_city,''),p.home_city),
        coalesce(nullif(ls.current_country_code,''),p.country_code)
 into v_city,v_country
 from public.players p left join public.player_location_state ls on ls.player_id=p.id
 where p.id=new.player_id;
 if v_city is not null and v_country is not null then
  insert into public.player_private_jet_positions(owned_asset_id,player_id,city,country_code)
  values(new.id,new.player_id,v_city,v_country) on conflict(owned_asset_id) do nothing;
 end if;
 return new;
end; $;
revoke all on function public.initialize_private_jet_position_v1() from public,anon,authenticated;
drop trigger if exists trg_initialize_private_jet_position on public.private_life_player_assets;
create trigger trg_initialize_private_jet_position after insert on public.private_life_player_assets
 for each row execute function public.initialize_private_jet_position_v1();

-- Existing owned aircraft are initially positioned at the player's currently
-- recorded location; this one-time backfill does not rewrite active travel legs.
insert into public.player_private_jet_positions(owned_asset_id,player_id,city,country_code)
select a.id,a.player_id,coalesce(nullif(ls.current_city,''),p.home_city),
 coalesce(nullif(ls.current_country_code,''),p.country_code)
from public.private_life_player_assets a
join public.private_life_asset_catalog c on c.code=a.catalog_code
join public.players p on p.id=a.player_id
left join public.player_location_state ls on ls.player_id=p.id
where a.sold_absolute_day is null and c.category='private_jet'
 and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false)
 and coalesce(nullif(ls.current_city,''),p.home_city) is not null
 and coalesce(nullif(ls.current_country_code,''),p.country_code) is not null
on conflict(owned_asset_id) do nothing;

create or replace function public.quote_private_jet_leg_v1(
 p_player_id uuid,p_source_city text,p_source_country text,p_destination_city text,
 p_destination_country text,p_distance_km integer,p_staff_count integer default 0,
 p_requested_asset_id uuid default null,p_departure_day integer default null)
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp' as $$
declare v_jet record; v_position record; v_home jsonb; v_last record;
 v_range integer; v_capacity integer; v_base integer; v_rate numeric;
 v_reduction integer; v_reposition integer:=0; v_distance integer:=0;
 v_origin_city text; v_origin_country text; v_reposition_quote jsonb;
begin
 if coalesce(p_distance_km,0)<1 then return jsonb_build_object('active',false,'reason','no_flight'); end if;
 select o.id,c.name,c.code,c.tier,c.metadata into v_jet
 from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
 where o.player_id=p_player_id and o.sold_absolute_day is null and c.category='private_jet'
 and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false)
 and coalesce((c.metadata->>'max_range_km')::integer,0)>=p_distance_km
 and (p_requested_asset_id is null or o.id=p_requested_asset_id)
 order by coalesce((c.metadata->>'travel_fatigue_reduction_bps')::integer,0) desc,o.purchase_price desc limit 1;
 if v_jet.id is null then return jsonb_build_object('active',false,'reason','no_eligible_owned_jet_for_range'); end if;
 v_range:=(v_jet.metadata->>'max_range_km')::integer;
 v_capacity:=(v_jet.metadata->>'passenger_capacity')::integer;
 v_base:=(v_jet.metadata->>'base_trip_cost')::integer;
 v_rate:=(v_jet.metadata->>'cost_per_km')::numeric;
 v_reduction:=least(5000,greatest(0,(v_jet.metadata->>'travel_fatigue_reduction_bps')::integer));
 select city,country_code into v_origin_city,v_origin_country from public.player_private_jet_positions where owned_asset_id=v_jet.id;
 -- Later booked legs inherit the aircraft's projected position, avoiding false repositioning on returns.
 if p_departure_day is not null then
  select destination_city,destination_country_code into v_last
  from public.player_travel_legs
  where jet_asset_id=v_jet.id and status='planned' and departure_absolute_day<=p_departure_day
  order by departure_absolute_day desc,created_at desc limit 1;
  if v_last.destination_city is not null then v_origin_city:=v_last.destination_city;v_origin_country:=v_last.destination_country_code;end if;
 end if;
 if v_origin_city is null then
   v_home:=public.get_player_home_base_v1(p_player_id);
   v_origin_city:=v_home->>'city';v_origin_country:=v_home->>'country_code';
 end if;
 if lower(coalesce(v_origin_city,''))<>lower(coalesce(p_source_city,'')) or upper(coalesce(v_origin_country,''))<>upper(coalesce(p_source_country,'')) then
  v_reposition_quote:=public.quote_travel_v2(v_origin_city,v_origin_country,null,null,p_source_city,p_source_country,null,null,'Economy','one_way');
  v_distance:=coalesce((v_reposition_quote->>'distance_km')::integer,0);
  if v_distance>v_range then return jsonb_build_object('active',false,'reason','jet_reposition_out_of_range'); end if;
  v_reposition:=v_base+ceil(v_distance*v_rate)::integer;
 end if;
 return jsonb_build_object('active',true,'owned_asset_id',v_jet.id,'name',v_jet.name,
   'catalog_code',v_jet.code,'distance_km',p_distance_km,'max_range_km',v_range,
   'passenger_capacity',v_capacity,'staff_on_jet',least(greatest(0,p_staff_count),greatest(0,v_capacity-1)),
   'staff_commercial',greatest(0,p_staff_count-greatest(0,v_capacity-1)),
   'reduction_bps',v_reduction,'reduction_percent',round(v_reduction::numeric/100),
   'reposition_cost',v_reposition,'base_trip_cost',v_base,'cost_per_km',v_rate,
   'cost_one_way',v_base+ceil(p_distance_km*v_rate)::integer+1000+v_reposition,
   'estimated_hours',round((p_distance_km::numeric/750)+1.5,1));
end; $$;
revoke all on function public.quote_private_jet_leg_v1(uuid,text,text,text,text,integer,integer,uuid,integer) from public,anon,authenticated;

create or replace function public.set_private_life_tournament_travel_v1(
 p_competition_id uuid,p_mode text,p_owned_jet_asset_id uuid default null)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_player uuid; v_exists boolean; v_preparation jsonb; v_route_jet jsonb;
 v_staff_count integer:=0; v_arrive integer;
begin
 v_player:=public.private_life_current_player_v1();
 if p_mode not in ('commercial','private_jet') then raise exception 'Invalid travel mode.'; end if;
 if not exists(select 1 from public.tournament_entries where player_id=v_player and competition_id=p_competition_id)
 then raise exception 'This tournament is not entered.'; end if;
 if p_mode='private_jet' then
  select exists(select 1 from public.private_life_player_assets a
   join public.private_life_asset_catalog c on c.code=a.catalog_code
   where a.id=p_owned_jet_asset_id and a.player_id=v_player and a.sold_absolute_day is null
   and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false)) into v_exists;
  if not v_exists then raise exception 'Select an owned travel-capable private jet.'; end if;
  -- Server-authoritative range, booked location and repositioning check.
  v_preparation:=public.quote_tournament_preparation_v1(v_player,p_competition_id);
  select coalesce(array_length(selected_staff_contract_ids,1),0)
    into v_staff_count from public.player_tournament_preparation_plans
    where player_id=v_player and competition_id=p_competition_id;
  v_arrive:=coalesce((v_preparation->>'arrival_absolute_day')::integer,0);
  v_route_jet:=public.quote_private_jet_leg_v1(
    v_player,v_preparation->'origin'->>'city',v_preparation->'origin'->>'country_code',
    v_preparation->'destination'->>'city',v_preparation->'destination'->>'country_code',
    coalesce((v_preparation->'player_travel'->>'distance_km')::integer,0),
    coalesce(v_staff_count,0),p_owned_jet_asset_id,v_arrive-1);
  if not coalesce((v_route_jet->>'active')::boolean,false) then
    raise exception 'Selected private jet is unavailable for this itinerary: %.',
      coalesce(v_route_jet->>'reason','range or repositioning restriction');
  end if;
 end if;
 insert into public.player_tournament_travel_selection(player_id,competition_id,travel_mode,owned_jet_asset_id)
 values(v_player,p_competition_id,p_mode,case when p_mode='private_jet' then p_owned_jet_asset_id else null end)
 on conflict(player_id,competition_id) do update set travel_mode=excluded.travel_mode,
 owned_jet_asset_id=excluded.owned_jet_asset_id,updated_at=now();
 perform public.rebuild_player_travel_plan_v1(v_player);
 return jsonb_build_object('status','saved','travel_mode',p_mode,'owned_jet_asset_id',
 case when p_mode='private_jet' then p_owned_jet_asset_id else null end);
end; $$;
revoke all on function public.set_private_life_tournament_travel_v1(uuid,text,uuid) from public,anon;
grant execute on function public.set_private_life_tournament_travel_v1(uuid,text,uuid) to authenticated;

create or replace function public.get_my_private_life_career_v1()
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp' as $$
declare v_player uuid;v_home jsonb;v_current record;v_state public.player_lifestyle_state%rowtype;
 v_jets jsonb;v_morale integer;v_day integer;
begin
 v_player:=public.private_life_current_player_v1();
 v_home:=public.get_player_home_base_v1(v_player);
 select * into v_state from public.player_lifestyle_state where player_id=v_player;
 select * into v_current from public.player_location_state where player_id=v_player;
 select public.game_day_absolute_v1(season,month,day) into v_day from public.get_current_game_day_internal_v1();
 select least(3,coalesce(sum(greatest(0,e.boost_points-greatest(0,v_day-e.purchased_absolute_day)/7)),0)) into v_morale
 from public.player_lifestyle_morale_events e where e.player_id=v_player;
 select coalesce(jsonb_agg(jsonb_build_object('owned_asset_id',o.id,'name',c.name,
 'max_range_km',(c.metadata->>'max_range_km')::integer,
 'passenger_capacity',(c.metadata->>'passenger_capacity')::integer,
 'cost_per_km',(c.metadata->>'cost_per_km')::numeric,
 'base_trip_cost',(c.metadata->>'base_trip_cost')::integer,
 'reduction_percent',round((c.metadata->>'travel_fatigue_reduction_bps')::numeric/100))
 order by c.tier desc,o.purchase_price desc),'[]'::jsonb) into v_jets
 from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
 where o.player_id=v_player and o.sold_absolute_day is null
 and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false);
 return jsonb_build_object('home_base',v_home,
 'current_location',jsonb_build_object('city',v_current.current_city,'country_code',v_current.current_country_code,'type',v_current.location_type),
 'active_residence_asset_id',v_state.active_residence_asset_id,
 'pending_residence_asset_id',v_state.pending_residence_asset_id,
 'pending_effective_absolute_day',v_state.pending_effective_absolute_day,
 'last_relocation_absolute_day',v_state.last_relocation_absolute_day,
 'preferred_travel_mode',coalesce(v_state.preferred_travel_mode,'ask_every_time'),
 'morale_bonus',coalesce(v_morale,0),'maximum_morale_bonus',3,'eligible_jets',v_jets);
end; $$;
revoke all on function public.get_my_private_life_career_v1() from public,anon;
grant execute on function public.get_my_private_life_career_v1() to authenticated;

create or replace function public.get_private_life_tournament_travel_v1(p_competition_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp' as $$
declare v_player uuid;v_selection record;v_quote jsonb;v_base jsonb;v_staff integer:=0;
 v_plan public.player_tournament_preparation_plans%rowtype;
 v_commercial_player jsonb;v_commercial_staff jsonb;
begin
 v_player:=public.private_life_current_player_v1();
 if not exists(select 1 from public.tournament_entries where player_id=v_player and competition_id=p_competition_id)
 then raise exception 'This tournament is not entered.'; end if;
 select * into v_selection from public.player_tournament_travel_selection
 where player_id=v_player and competition_id=p_competition_id;
 if v_selection.travel_mode is null then
   select case when preferred_travel_mode='best_owned_jet' then 'private_jet'
          else 'commercial' end as travel_mode,null::uuid as owned_jet_asset_id
     into v_selection from public.player_lifestyle_state where player_id=v_player;
 end if;
 select * into v_plan from public.player_tournament_preparation_plans
 where player_id=v_player and competition_id=p_competition_id;
 v_staff:=coalesce(array_length(v_plan.selected_staff_contract_ids,1),0);
 v_base:=public.quote_tournament_preparation_v1(
  v_player,p_competition_id,coalesce(v_plan.player_travel_class,'Economy'),
  coalesce(v_plan.staff_travel_class,'Economy'),coalesce(v_plan.hotel_tier,'Standard'),
  coalesce(v_plan.selected_staff_contract_ids,'{}'::uuid[]));
 -- Always compute a separate commercial baseline, even when the selected
 -- itinerary currently uses the owned jet.
 v_commercial_player:=public.quote_travel_v2(
  v_base->'origin'->>'city',v_base->'origin'->>'country_code',
  nullif(v_base->'origin'->>'latitude','')::double precision,
  nullif(v_base->'origin'->>'longitude','')::double precision,
  v_base->'destination'->>'city',v_base->'destination'->>'country_code',
  null,null,coalesce(v_plan.player_travel_class,'Economy'),'round_trip');
 v_commercial_staff:=public.quote_travel_v2(
  v_base->'origin'->>'city',v_base->'origin'->>'country_code',
  nullif(v_base->'origin'->>'latitude','')::double precision,
  nullif(v_base->'origin'->>'longitude','')::double precision,
  v_base->'destination'->>'city',v_base->'destination'->>'country_code',
  null,null,coalesce(v_plan.staff_travel_class,'Economy'),'round_trip');
 v_quote:=public.quote_private_jet_leg_v1(v_player,v_base->'origin'->>'city',
 v_base->'origin'->>'country_code',v_base->'destination'->>'city',
 v_base->'destination'->>'country_code',coalesce((v_base->'player_travel'->>'distance_km')::integer,0),
 coalesce(v_staff,0),v_selection.owned_jet_asset_id,coalesce((v_base->>'arrival_absolute_day')::integer,0)-1);
 return jsonb_build_object('selected_mode',coalesce(v_selection.travel_mode,'commercial'),
 'selected_asset_id',coalesce(v_selection.owned_jet_asset_id,(v_quote->>'owned_asset_id')::uuid),
 'private_jet_quote',v_quote,'commercial_player_cost',(v_commercial_player->>'cost')::integer,
 'commercial_staff_cost',coalesce(v_staff,0)*(v_commercial_staff->>'cost')::integer);
end; $$;
revoke all on function public.get_private_life_tournament_travel_v1(uuid) from public,anon;
grant execute on function public.get_private_life_tournament_travel_v1(uuid) to authenticated;

-- Override existing plan insert with paid, selected jet booking.
CREATE OR REPLACE FUNCTION public.insert_planned_travel_leg_v1(p_player_id uuid, p_purpose text, p_source_type text, p_source_city text, p_source_country text, p_source_lat double precision, p_source_lon double precision, p_source_ref text, p_dest_type text, p_dest_city text, p_dest_country text, p_dest_lat double precision, p_dest_lon double precision, p_dest_ref text, p_departure integer, p_arrival integer, p_embedded boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  q jsonb; v_id uuid; gd record; v_existing text; v_class text:='Economy';
  v_jet jsonb; v_reduction integer:=0; v_base_gross integer; v_base_net integer; v_jet_gross integer; v_jet_net integer; v_jet_recovery integer;
  v_jet_applies boolean:=false; v_mode text:='commercial'; v_comp uuid; v_staff_count integer:=0; v_selected uuid;
  v_staff_class text:='Economy';v_staff_commercial integer:=0;v_staff_quote jsonb;
begin
  if upper(coalesce(p_source_country,''))=upper(coalesce(p_dest_country,'')) and lower(trim(coalesce(p_source_city,'')))<>'' and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_dest_city,''))) then return null; end if;
  if p_dest_type='tournament' and coalesce(p_dest_ref,'')~*'^[0-9a-f-]{36}$' then
    select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_dest_ref::uuid;
  elsif p_source_type='tournament' and coalesce(p_source_ref,'')~*'^[0-9a-f-]{36}$' then
    select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_source_ref::uuid;
  end if;
  v_class:=coalesce(v_class,'Economy');
  q:=public.quote_travel_v2(p_source_city,p_source_country,p_source_lat,p_source_lon,p_dest_city,p_dest_country,p_dest_lat,p_dest_lon,v_class,'one_way');

  if coalesce(p_dest_ref,'')~*'^[0-9a-f-]{36}$' and p_dest_type='tournament' then v_comp:=p_dest_ref::uuid;
  elsif coalesce(p_source_ref,'')~*'^[0-9a-f-]{36}$' and p_source_type='tournament' then v_comp:=p_source_ref::uuid;
  end if;
  if v_comp is not null then
    select travel_mode,owned_jet_asset_id into v_mode,v_selected
    from public.player_tournament_travel_selection where player_id=p_player_id and competition_id=v_comp;
    if v_mode is null then
      select case when preferred_travel_mode='best_owned_jet' then 'private_jet' when preferred_travel_mode='cheapest' then 'cheapest' else 'commercial' end
      into v_mode from public.player_lifestyle_state where player_id=p_player_id;
    end if;
    select coalesce(array_length(selected_staff_contract_ids,1),0),coalesce(staff_travel_class,'Economy')
      into v_staff_count,v_staff_class
    from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=v_comp;
    if coalesce(v_staff_count,0)>0 then
      v_staff_quote:=public.quote_travel_v2(p_source_city,p_source_country,p_source_lat,p_source_lon,
       p_dest_city,p_dest_country,p_dest_lat,p_dest_lon,coalesce(v_staff_class,'Economy'),'one_way');
    end if;
  end if;
  v_mode:=coalesce(v_mode,'commercial');
  if v_mode in ('private_jet','cheapest') and coalesce(q->>'band','')<>'same_city' then
    v_jet:=public.quote_private_jet_leg_v1(p_player_id,p_source_city,p_source_country,p_dest_city,p_dest_country,
     coalesce((q->>'distance_km')::integer,0),coalesce(v_staff_count,0),v_selected,p_departure);
    v_jet_applies:=coalesce((v_jet->>'active')::boolean,false)
      and (v_mode='private_jet' or (
         (v_jet->>'cost_one_way')::integer
         +coalesce((v_jet->>'staff_commercial')::integer,0)*coalesce((v_staff_quote->>'cost')::integer,0)
         < (q->>'cost')::integer+coalesce(v_staff_count,0)*coalesce((v_staff_quote->>'cost')::integer,0)
      ));
    if v_jet_applies then
      v_reduction:=least(5000,coalesce((v_jet->>'reduction_bps')::integer,0));
      v_base_gross:=greatest(1,coalesce((q->>'gross_arrival_fatigue')::integer,1));
      v_base_net:=greatest(1,coalesce((q->>'arrival_fatigue')::integer,1));
      v_jet_gross:=greatest(1,round(v_base_gross::numeric*(10000-v_reduction)/10000)::integer);
      v_jet_net:=greatest(1,round(v_base_net::numeric*(10000-v_reduction)/10000)::integer);
      v_jet_recovery:=greatest(0,v_jet_gross-v_jet_net);
      q:=q||jsonb_build_object('gross_arrival_fatigue',v_jet_gross,
        'travel_day_recovery',v_jet_recovery,'arrival_fatigue',v_jet_net,
        'cost',(v_jet->>'cost_one_way')::integer);
    end if;
  end if;

  -- Staff sharing an owned jet do not purchase separate tickets. Overflow staff
  -- and all commercially flying staff pay their one-way fare exactly once.
  if v_comp is not null and coalesce(v_staff_count,0)>0 then
    select staff_travel_class into v_staff_class from public.player_tournament_preparation_plans
    where player_id=p_player_id and competition_id=v_comp;
    v_staff_class:=coalesce(v_staff_class,'Economy');
    v_staff_commercial:=case when v_jet_applies then coalesce((v_jet->>'staff_commercial')::integer,0)
                       else v_staff_count end;
    if v_staff_commercial>0 then
      v_staff_quote:=public.quote_travel_v2(p_source_city,p_source_country,p_source_lat,p_source_lon,
       p_dest_city,p_dest_country,p_dest_lat,p_dest_lon,v_staff_class,'one_way');
      q:=q||jsonb_build_object('cost',(q->>'cost')::integer+
        ((v_staff_quote->>'cost')::integer*v_staff_commercial),
        'staff_ticket_count',v_staff_commercial,
        'staff_ticket_cost',(v_staff_quote->>'cost')::integer*v_staff_commercial);
    end if;
  end if;

  insert into public.player_travel_legs(
    player_id,purpose,source_location_type,source_city,source_country_code,source_continent,source_latitude,source_longitude,
    destination_location_type,destination_city,destination_country_code,destination_continent,destination_latitude,destination_longitude,
    source_reference_id,destination_reference_id,departure_absolute_day,arrival_absolute_day,distance_km,estimated_cost,
    gross_arrival_fatigue,travel_day_recovery,arrival_fatigue,travel_band,travel_basis,embedded_transition,status,travel_class,
    base_estimated_cost,price_multiplier,base_arrival_fatigue,fatigue_multiplier,travel_mode,jet_asset_id,jet_quote
  ) values(
    p_player_id,p_purpose,p_source_type,p_source_city,p_source_country,public.country_continent_v1(p_source_country),p_source_lat,p_source_lon,
    p_dest_type,p_dest_city,p_dest_country,public.country_continent_v1(p_dest_country),p_dest_lat,p_dest_lon,p_source_ref,p_dest_ref,
    p_departure,p_arrival,nullif(q->>'distance_km','')::integer,(q->>'cost')::integer,
    (q->>'gross_arrival_fatigue')::smallint,(q->>'travel_day_recovery')::smallint,(q->>'arrival_fatigue')::smallint,
    q->>'band',q->>'basis',p_embedded,'planned',v_class,(q->>'base_cost_one_way')::integer,(q->>'price_multiplier')::numeric,
    (q->>'base_arrival_fatigue')::smallint,(q->>'fatigue_multiplier')::numeric,
    case when v_jet_applies then 'private_jet' else 'commercial' end,
    case when v_jet_applies then (v_jet->>'owned_asset_id')::uuid else null end,
    case when v_jet_applies then v_jet else null end
  ) returning id into v_id;

  if not p_embedded then
    select * into gd from public.absolute_game_day_v1(p_departure);
    select activity_type into v_existing from public.player_daily_activity where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;
    if v_existing is null or v_existing='home' then
      insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note)
      values(p_player_id,gd.season,gd.month,gd.day,'travel','travel_plan',v_id::text,
        format('Travel to %s%s',coalesce(p_dest_city,p_dest_country),case when v_jet_applies then ' · private jet' else '' end))
      on conflict(player_id,season,month,day) do update set activity_type='travel',source='travel_plan',reference_id=v_id::text,note=excluded.note,updated_at=now()
      where public.player_daily_activity.effects_applied_at is null and public.player_daily_activity.activity_type='home';
    else
      update public.player_travel_legs set embedded_transition=true,updated_at=now() where id=v_id;
    end if;
  end if;
  return v_id;
end;
$function$
;

-- Charge only selected jet travel, and record actual aircraft position after arrival.
CREATE OR REPLACE FUNCTION public.process_travel_leg_v1(p_leg_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  l public.player_travel_legs%rowtype;
  v_before smallint; v_after smallint; gd record; v_owner uuid; v_finance jsonb:='{}'::jsonb; v_hotel jsonb:='{}'::jsonb;
  v_human boolean:=false; v_comp uuid;
  v_baseline_gross integer; v_baseline_net integer; v_gross integer; v_recovery integer; v_net integer;
  v_jet jsonb:=jsonb_build_object('active',false,'reduction_bps',0,'reduction_percent',0); v_reduction integer:=0; v_jet_applies boolean:=false;
  v_fallback_staff integer:=0;v_fallback_class text:='Economy';v_fallback_comp uuid;v_fallback_fare integer:=0;
begin
  select * into l from public.player_travel_legs where id=p_leg_id for update;
  if l.id is null then raise exception 'Travel leg not found.'; end if;
  if l.status='completed' then return jsonb_build_object('status','already_processed','travel_leg_id',l.id); end if;
  if l.status='cancelled' then return jsonb_build_object('status','cancelled','travel_leg_id',l.id); end if;

  select owner_user_id,(player_type='human' and owner_user_id is not null) into v_owner,v_human from public.players where id=l.player_id;
  -- Revalidate ownership before charging; a sold jet cannot provide travel or fatigue benefits.
  if l.jet_asset_id is not null and not exists(
    select 1 from public.private_life_player_assets o where o.id=l.jet_asset_id and o.player_id=l.player_id and o.sold_absolute_day is null
  ) then
    if l.destination_location_type='tournament' and coalesce(l.destination_reference_id,'')~*'^[0-9a-f-]{36}$' then
      v_fallback_comp:=l.destination_reference_id::uuid;
    elsif l.source_location_type='tournament' and coalesce(l.source_reference_id,'')~*'^[0-9a-f-]{36}$' then
      v_fallback_comp:=l.source_reference_id::uuid;
    end if;
    if v_fallback_comp is not null then
      select coalesce(array_length(selected_staff_contract_ids,1),0),coalesce(staff_travel_class,'Economy')
      into v_fallback_staff,v_fallback_class from public.player_tournament_preparation_plans
      where player_id=l.player_id and competition_id=v_fallback_comp;
      if coalesce(v_fallback_staff,0)>0 then
        v_fallback_fare:=(public.quote_travel_v2(l.source_city,l.source_country_code,
          l.source_latitude,l.source_longitude,l.destination_city,l.destination_country_code,
          l.destination_latitude,l.destination_longitude,coalesce(v_fallback_class,'Economy'),'one_way')->>'cost')::integer;
      end if;
    end if;
    update public.player_travel_legs
    set travel_mode='commercial',jet_asset_id=null,jet_quote=null,
      estimated_cost=greatest(0,round(coalesce(base_estimated_cost,estimated_cost,0)*coalesce(price_multiplier,1))::integer)
        +coalesce(v_fallback_staff,0)*coalesce(v_fallback_fare,0)
    where id=l.id;
    select * into l from public.player_travel_legs where id=p_leg_id;
  end if;
    if v_human and coalesce(l.estimated_cost,0)>0 and coalesce(l.purpose,'')<>'training_camp' and coalesce(l.source_location_type,'')<>'training_camp' then
    v_finance:=public.post_career_finance_transaction_v1(l.player_id,-l.estimated_cost,'travel',coalesce(l.purpose,'travel'),
      format('%s → %s · %s',coalesce(l.source_city,l.source_country_code),coalesce(l.destination_city,l.destination_country_code),coalesce(l.travel_class,'Economy')),
      'travel_leg',l.id::text,'travel-leg:'||l.id::text,
      jsonb_build_object('distance_km',l.distance_km,'travel_class',l.travel_class,'purpose',l.purpose,'source_city',l.source_city,'destination_city',l.destination_city),false,l.departure_absolute_day);
  end if;


  v_baseline_gross:=greatest(1,round(coalesce(l.base_arrival_fatigue,l.gross_arrival_fatigue,l.arrival_fatigue,1)::numeric*coalesce(l.fatigue_multiplier,1))::integer);
  v_baseline_net:=greatest(1,v_baseline_gross-3);
  v_gross:=v_baseline_gross;
  v_net:=v_baseline_net;
  v_recovery:=greatest(0,v_gross-v_net);

  v_jet_applies:=l.jet_asset_id is not null and l.travel_mode='private_jet';
  if v_jet_applies then
    v_jet:=l.jet_quote;
    v_reduction:=least(5000,greatest(0,coalesce((v_jet->>'reduction_bps')::integer,0)));
    v_gross:=greatest(1,round(v_baseline_gross::numeric*(10000-v_reduction)/10000)::integer);
    v_net:=greatest(1,round(v_baseline_net::numeric*(10000-v_reduction)/10000)::integer);
    v_recovery:=greatest(0,v_gross-v_net);
  end if;

  select fatigue into v_before from public.player_skills where player_id=l.player_id for update;
  v_after:=least(100,coalesce(v_before,0)+v_net)::smallint;
  update public.player_skills set fatigue=v_after,updated_at=now() where player_id=l.player_id;
  update public.player_location_state set current_city=l.destination_city,current_country_code=l.destination_country_code,current_continent=l.destination_continent,current_latitude=l.destination_latitude,current_longitude=l.destination_longitude,location_type=l.destination_location_type,source_reference_id=l.destination_reference_id,location_since_absolute_day=l.arrival_absolute_day,updated_at=now() where player_id=l.player_id;
  update public.player_travel_legs set gross_arrival_fatigue=v_gross::smallint,travel_day_recovery=v_recovery::smallint,arrival_fatigue=v_net::smallint,status='completed',processed_at=now(),updated_at=now() where id=l.id;

  if v_jet_applies then
    insert into public.player_private_jet_positions(owned_asset_id,player_id,city,country_code)
    values(l.jet_asset_id,l.player_id,l.destination_city,l.destination_country_code)
    on conflict(owned_asset_id) do update set city=excluded.city,country_code=excluded.country_code,updated_at=now();
  end if;
  select * into gd from public.absolute_game_day_v1(l.departure_absolute_day);
  update public.player_daily_activity set effects_applied_at=coalesce(effects_applied_at,now()),effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object(
    'travel_leg_id',l.id,'from',jsonb_build_object('city',l.source_city,'country_code',l.source_country_code),'to',jsonb_build_object('city',l.destination_city,'country_code',l.destination_country_code),
    'distance_km',l.distance_km,'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before,
    'private_jet',v_jet,'baseline_net_travel_fatigue',v_baseline_net,'finance',v_finance),updated_at=now()
  where player_id=l.player_id and season=gd.season and month=gd.month and day=gd.day and source='travel_plan' and reference_id=l.id::text;

  if v_human and coalesce(l.destination_location_type,'')='tournament' and l.destination_reference_id is not null then
    begin
      v_comp:=l.destination_reference_id::uuid;
      v_hotel:=public.post_tournament_hotel_night_v1(l.player_id,v_comp,l.arrival_absolute_day);
    exception when invalid_text_representation then
      v_hotel:=jsonb_build_object('status','skipped','reason','invalid_tournament_reference');
    end;
  end if;

  perform public.emit_notification_v1(v_owner,l.player_id,'travel.arrived','Travel completed',
    case when coalesce((v_jet->>'active')::boolean,false) then
      format('You arrived in %s by private jet. Travel fatigue was reduced by %s%%: +%s fatigue instead of +%s.',coalesce(l.destination_city,l.destination_country_code),coalesce(v_jet->>'reduction_percent','90'),v_net,v_baseline_net)
    else
      format('You arrived in %s. Gross travel fatigue: +%s. Travel-day rest: -%s. Net fatigue: +%s.',coalesce(l.destination_city,l.destination_country_code),v_gross,v_recovery,v_net)
    end,
    '/game/schedule',jsonb_build_object('travel_leg_id',l.id,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'distance_km',l.distance_km,'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'fatigue_change',v_net,'baseline_net_travel_fatigue',v_baseline_net,'private_jet',v_jet,'finance',v_finance),'travel-arrived:'||l.id::text);

  return jsonb_build_object('status','completed','travel_leg_id',l.id,'distance_km',l.distance_km,'estimated_cost',l.estimated_cost,
    'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'net_travel_fatigue',v_net,'baseline_net_travel_fatigue',v_baseline_net,
    'private_jet',v_jet,'fatigue_before',v_before,'fatigue_after',v_after,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'finance',v_finance,'arrival_hotel',v_hotel);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_player_origin_before_day_v1(p_player_id uuid, p_target_absolute_day integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype; v_state public.player_location_state%rowtype; v_current integer; v_gap smallint:=3; c record; p jsonb;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into v_state from public.player_location_state where player_id=p_player_id;
  select public.game_day_absolute_v1(season,month,day) into v_current from public.get_current_game_day_internal_v1();
  select direct_transition_max_gap_days into v_gap from public.travel_engine_settings where id=1;

  if p_target_absolute_day<=v_current+1 and v_state.player_id is not null then
    p:=public.resolve_location_coordinates_v1(v_state.current_city,v_state.current_country_code,v_state.current_latitude,v_state.current_longitude);
    return p||jsonb_build_object('continent',coalesce(v_state.current_continent,public.country_continent_v1(v_state.current_country_code)),'location_type',v_state.location_type,'reference_id',v_state.source_reference_id,'continuity','current_location');
  end if;

  select * into c
  from public.player_commitment_locations_v1(p_player_id) x
  where x.end_absolute_day < p_target_absolute_day
    and x.end_absolute_day >= v_current-1
  order by x.end_absolute_day desc
  limit 1;

  if c.reference_id is not null and (p_target_absolute_day-c.end_absolute_day-1)<=v_gap then
    p:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
    return p||jsonb_build_object('continent',c.continent,'location_type',c.commitment_type,'reference_id',c.reference_id,'continuity','direct_from_previous_commitment','gap_days',p_target_absolute_day-c.end_absolute_day-1);
  end if;

  p:=public.get_player_home_base_v1(p_player_id);
  p:=public.resolve_location_coordinates_v1(p->>'city',p->>'country_code',null,null);
  return p||jsonb_build_object('continent',public.country_continent_v1(p->>'country_code'),'location_type','home','reference_id',null,'continuity','home_base');
end; $function$
;

CREATE OR REPLACE FUNCTION public.rebuild_player_travel_plan_core_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype;
  v_state public.player_location_state%rowtype;
  v_current integer;
  v_gap_limit smallint:=3;
  v_source_city text;
  v_source_country text;
  v_source_type text;
  v_source_ref text;
  v_source_lat double precision;
  v_source_lon double precision;
  v_prev_end integer;
  v_had boolean:=false;
  c record;
  q jsonb;
  v_depart integer;
  v_arrive integer;
  v_embedded boolean;
  v_count integer:=0;
  homep jsonb; v_home_city text; v_home_country text;
  v_return_home boolean;
  v_unresolved_tournament boolean:=false;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.';end if;
  homep:=public.get_player_home_base_v1(p_player_id);
  v_home_city:=homep->>'city';v_home_country:=homep->>'country_code';

  select public.game_day_absolute_v1(season,month,day)
  into v_current
  from public.get_current_game_day_internal_v1();

  select direct_transition_max_gap_days into v_gap_limit
  from public.travel_engine_settings where id=1;

  select * into v_state
  from public.player_location_state where player_id=p_player_id;

  update public.player_daily_activity
  set activity_type='home',source=null,reference_id=null,note=null,updated_at=now()
  where player_id=p_player_id
    and source='travel_plan'
    and effects_applied_at is null
    and public.game_day_absolute_v1(season,month,day)>=v_current;

  delete from public.player_travel_legs
  where player_id=p_player_id
    and status='planned'
    and arrival_absolute_day>=v_current;

  if v_state.player_id is null then
    insert into public.player_location_state(
      player_id,current_city,current_country_code,current_continent,
      location_type,location_since_absolute_day,updated_at
    ) values(
      p_player_id,v_home_city,v_home_country,
      public.country_continent_v1(v_home_country),'home',v_current,now()
    ) on conflict(player_id) do nothing;
    select * into v_state from public.player_location_state where player_id=p_player_id;
  end if;

  v_source_city:=coalesce(v_state.current_city,v_home_city);
  v_source_country:=coalesce(v_state.current_country_code,v_home_country);
  v_source_type:=coalesce(v_state.location_type,'home');
  v_source_ref:=v_state.source_reference_id;
  q:=public.resolve_location_coordinates_v1(v_source_city,v_source_country,v_state.current_latitude,v_state.current_longitude);
  v_source_lat:=nullif(q->>'latitude','')::double precision;
  v_source_lon:=nullif(q->>'longitude','')::double precision;
  v_prev_end:=v_current-1;

  for c in
    select *
    from public.player_commitment_locations_v1(p_player_id)
    where end_absolute_day>=v_current
    order by start_absolute_day,end_absolute_day,commitment_type
  loop
    v_unresolved_tournament:=c.commitment_type='tournament'
      and public.player_tournament_commitment_unresolved_v1(p_player_id,c.reference_id);

    if c.start_absolute_day<=v_current and c.end_absolute_day>=v_current then
      q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
      v_source_city:=c.city;
      v_source_country:=c.country_code;
      v_source_type:=c.commitment_type;
      v_source_ref:=c.reference_id;
      v_source_lat:=nullif(q->>'latitude','')::double precision;
      v_source_lon:=nullif(q->>'longitude','')::double precision;
      update public.player_location_state
      set current_city=c.city,current_country_code=c.country_code,current_continent=c.continent,
          current_latitude=v_source_lat,current_longitude=v_source_lon,
          location_type=c.commitment_type,source_reference_id=c.reference_id,
          location_since_absolute_day=coalesce(location_since_absolute_day,v_current),updated_at=now()
      where player_id=p_player_id;
      v_prev_end:=c.end_absolute_day;
      v_had:=true;
      exit when v_unresolved_tournament;
      continue;
    end if;

    v_return_home:=false;
    if v_had and v_source_type<>'home' and not v_unresolved_tournament then
      if v_source_type='tournament' and c.commitment_type='tournament' then
        v_return_home:=c.start_absolute_day>v_prev_end+1;
      else
        v_return_home:=(c.start_absolute_day-v_prev_end-1)>v_gap_limit;
      end if;
    end if;

    if v_return_home then
      homep:=public.resolve_location_coordinates_v1(v_home_city,v_home_country,null,null);
      v_depart:=greatest(v_current,v_prev_end+1);
      perform public.insert_planned_travel_leg_v1(
        p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
        'home',v_home_city,v_home_country,
        nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,
        v_depart,v_depart,false
      );
      v_count:=v_count+1;
      v_source_city:=v_home_city;
      v_source_country:=v_home_country;
      v_source_type:='home';
      v_source_ref:=null;
      v_source_lat:=nullif(homep->>'latitude','')::double precision;
      v_source_lon:=nullif(homep->>'longitude','')::double precision;
    end if;

    q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
    v_depart:=greatest(v_current,c.start_absolute_day-1);
    v_embedded:=v_depart<=v_prev_end or v_depart>=c.start_absolute_day;
    v_arrive:=case when v_embedded then c.start_absolute_day else v_depart end;

    if public.insert_planned_travel_leg_v1(
      p_player_id,c.commitment_type,
      v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
      c.commitment_type,c.city,c.country_code,
      nullif(q->>'latitude','')::double precision,nullif(q->>'longitude','')::double precision,c.reference_id,
      v_depart,v_arrive,v_embedded
    ) is not null then
      v_count:=v_count+1;
    end if;

    v_source_city:=c.city;
    v_source_country:=c.country_code;
    v_source_type:=c.commitment_type;
    v_source_ref:=c.reference_id;
    v_source_lat:=nullif(q->>'latitude','')::double precision;
    v_source_lon:=nullif(q->>'longitude','')::double precision;
    v_prev_end:=c.end_absolute_day;
    v_had:=true;

    exit when v_unresolved_tournament;
  end loop;

  if v_had and v_source_type<>'home'
     and not public.player_tournament_commitment_unresolved_v1(p_player_id,v_source_ref) then
    homep:=public.resolve_location_coordinates_v1(v_home_city,v_home_country,null,null);
    v_depart:=greatest(v_current,v_prev_end+1);
    if public.insert_planned_travel_leg_v1(
      p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
      'home',v_home_city,v_home_country,
      nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,
      v_depart,v_depart,false
    ) is not null then
      v_count:=v_count+1;
    end if;
  end if;

  perform public.sync_player_tournament_travel_timing_v1(p_player_id);
  return jsonb_build_object(
    'status','rebuilt',
    'travel_legs',v_count,
    'direct_transition_max_gap_days',v_gap_limit,
    'unresolved_tournament_rule','no return or later travel is booked until active tournament outcome is known'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.quote_tournament_preparation_v1(p_player_id uuid, p_competition_id uuid, p_player_travel_class text DEFAULT 'Economy'::text, p_staff_travel_class text DEFAULT 'Economy'::text, p_hotel_tier text DEFAULT 'Standard'::text, p_selected_staff_contract_ids uuid[] DEFAULT '{}'::uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_staff_effects jsonb; v_jet jsonb; v_mode text;v_jet_id uuid;v_jet_extra_staff integer:=0;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where id=p_player_id and owner_user_id=v_uid;
  if v_player.id is null then raise exception 'Player access denied.'; end if;

  select ts.city,ts.country_code,ts.latitude,ts.longitude,te.season_number,min(ss.season_week),max(ss.season_week)
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

  select coalesce(e.draw_type,'main_draw')
  into v_draw_type
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
    v_city,v_country,v_lat,v_lon,p_player_travel_class,'round_trip'
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

  v_staff_effects:=public.get_tournament_staff_effects_v1(
    p_player_id,p_competition_id,coalesce(p_selected_staff_contract_ids,'{}'::uuid[])
  );

  v_staff_travel:=public.quote_travel_v2(
    v_origin->>'city',v_origin->>'country_code',
    nullif(v_origin->>'latitude','')::double precision,
    nullif(v_origin->>'longitude','')::double precision,
    v_city,v_country,v_lat,v_lon,p_staff_travel_class,'round_trip'
  );

  select * into v_hotel from public.travel_stay_tiers where tier_name=p_hotel_tier;
  if v_hotel.tier_name is null then raise exception 'Invalid hotel tier.'; end if;

  v_party:=1+v_staff_count;
  v_hotel_min:=public.quote_accommodation_v1(v_city,v_country,v_hotel.base_nightly_cost,v_min_nights,v_party,'night');
  v_hotel_max:=public.quote_accommodation_v1(v_city,v_country,v_hotel.base_nightly_cost,v_max_nights,v_party,'night');
  v_player_cost:=(v_travel->>'cost')::integer;
  v_staff_cost:=(v_staff_travel->>'cost')::integer*v_staff_count;
  select travel_mode,owned_jet_asset_id into v_mode,v_jet_id from public.player_tournament_travel_selection
  where player_id=p_player_id and competition_id=p_competition_id;
  if v_mode is null then
    select case when preferred_travel_mode='best_owned_jet' then 'private_jet' when preferred_travel_mode='cheapest' then 'cheapest' else 'commercial' end
      into v_mode from public.player_lifestyle_state where player_id=p_player_id;
  end if;
  if v_mode in ('private_jet','cheapest') then
    v_jet:=public.quote_private_jet_leg_v1(p_player_id,v_origin->>'city',v_origin->>'country_code',v_city,v_country,
      (v_travel->>'distance_km')::integer,v_staff_count,v_jet_id,v_arrival_abs-1);
    if coalesce((v_jet->>'active')::boolean,false) and (v_mode='private_jet' or 2*(v_jet->>'cost_one_way')::integer-(v_jet->>'reposition_cost')::integer + (v_staff_travel->>'cost')::integer * (v_jet->>'staff_commercial')::integer < v_player_cost + v_staff_cost) then
      v_player_cost:=2*(v_jet->>'cost_one_way')::integer-(v_jet->>'reposition_cost')::integer;
      v_jet_extra_staff:=(v_jet->>'staff_commercial')::integer;
      v_staff_cost:=(v_staff_travel->>'cost')::integer*v_jet_extra_staff;
      v_travel:=v_travel||jsonb_build_object('private_jet',v_jet,
         'arrival_fatigue',greatest(1,round((v_travel->>'arrival_fatigue')::numeric*
         (10000-(v_jet->>'reduction_bps')::numeric)/10000)::integer));
    else
      v_jet:=jsonb_build_object('active',false,'reason','commercial_cheaper_or_unavailable');
    end if;
  end if;
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
    'private_jet',coalesce(v_jet,jsonb_build_object('active',false)),
    'staff_effects',v_staff_effects,
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_private_life_dashboard_v3()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_base jsonb;
  v_player uuid;
  v_locations jsonb;
begin
  v_base:=public.get_private_life_dashboard_v2();
  v_player:=(v_base->>'player_id')::uuid;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'code',l.code,
      'country_code',l.country_code,
      'country_name',l.country_name,
      'city',l.city,
      'apartment_base_price',l.apartment_base_price,
      'house_base_price',l.house_base_price,
      'annual_value_rate_bps',l.annual_value_rate_bps,
      'sort_order',l.sort_order,
      'monthly_change_bps',hist.monthly_change_bps,
      'previous_apartment_base_price',hist.previous_apartment_base_price,
      'previous_house_base_price',hist.previous_house_base_price,
      'market_season',hist.season,
      'market_month',hist.month,
      'is_standard_location',coalesce((
        select pl.marketplace_enabled
        from public.private_life_property_locations pl
        where pl.code=l.code
      ),false),
      'available_apartment_codes',
        case
          when not coalesce((
            select pl.marketplace_enabled
            from public.private_life_property_locations pl
            where pl.code=l.code
          ),false) then jsonb_build_array('apt_starter_city')
          else coalesce((
            select jsonb_agg(a.catalog_code order by coalesce((c.metadata->>'catalog_order')::integer,999),a.catalog_code)
            from public.private_life_property_catalog_availability a
            join public.private_life_asset_catalog c on c.code=a.catalog_code
            where a.location_code=l.code
              and a.active=true
              and c.active=true
              and c.category='apartment'
          ),'[]'::jsonb)
        end,
      'available_house_codes',
        case
          when not coalesce((
            select pl.marketplace_enabled
            from public.private_life_property_locations pl
            where pl.code=l.code
          ),false) then '[]'::jsonb
          else coalesce((
            select jsonb_agg(a.catalog_code order by coalesce((c.metadata->>'catalog_order')::integer,999),a.catalog_code)
            from public.private_life_property_catalog_availability a
            join public.private_life_asset_catalog c on c.code=a.catalog_code
            where a.location_code=l.code
              and a.active=true
              and c.active=true
              and c.category='house_villa'
          ),'[]'::jsonb)
        end
    ) order by l.sort_order,l.country_name,l.city
  ),'[]'::jsonb)
  into v_locations
  from public.private_life_property_locations_for_player_v1(v_player) l
  left join lateral (
    select h.*
    from public.private_life_property_market_history h
    where h.location_code=l.code
    order by h.season desc,h.month desc
    limit 1
  ) hist on true;

  return v_base || jsonb_build_object('property_locations',v_locations,'career_lifestyle',public.get_my_private_life_career_v1());
end;
$function$
;


-- Defensive compatibility: legacy code must never grant the previous
-- 90% automatic reduction merely for owning an aircraft.
create or replace function public.private_life_private_jet_travel_benefit_v1(p_player_id uuid)
returns jsonb language sql stable security definer set search_path='public','pg_temp' as $$
 select jsonb_build_object('active',false,'reduction_bps',0,'reduction_percent',0,
  'reason','book_and_pay_for_tournament_flight');
$$;
revoke all on function public.private_life_private_jet_travel_benefit_v1(uuid) from public,anon,authenticated;
