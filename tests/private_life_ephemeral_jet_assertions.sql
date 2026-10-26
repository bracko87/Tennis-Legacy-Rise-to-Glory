\set ON_ERROR_STOP on
select set_config('app.test_uid','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',false);
select set_config('app.month','1',false);
select set_config('app.day','1',false);
create trigger trg_initialize_private_jet_position after insert on public.private_life_player_assets
 for each row execute function public.initialize_private_jet_position_v1();
-- The test jet is purchased at the current real player location (Belgrade).
insert into public.private_life_player_assets(id,player_id,catalog_code,acquisition_type,purchase_absolute_day)
values
 ('22222222-2222-2222-2222-222222222225',
  '11111111-1111-1111-1111-111111111111','test_real_jet','purchase',391),
 ('22222222-2222-2222-2222-222222222226',
  '11111111-1111-1111-1111-111111111111','test_prop_plane','purchase',391);

do $$
declare p uuid:='11111111-1111-1111-1111-111111111111';
 j uuid:='22222222-2222-2222-2222-222222222225';
 prop uuid:='22222222-2222-2222-2222-222222222226';
 v jsonb; v_city text;v_country text;v_total integer;
begin
 select city,country_code into v_city,v_country from public.player_private_jet_positions
 where owned_asset_id=j;
 if v_city<>'Belgrade' or v_country<>'RS' then
  raise exception 'Jet purchase should initialize real location Belgrade/RS, got %/%',v_city,v_country;
 end if;
 select count(*) into v_total from public.player_private_jet_positions where owned_asset_id=prop;
 if v_total<>0 then raise exception 'Propeller aircraft should not be positioned as bookable jet'; end if;

 v:=public.quote_my_private_life_jet_v1('44444444-4444-4444-4444-444444444444',j,5);
 if v->>'active'<>'true' or (v->>'staff_on_jet')::integer<>5
   or (v->>'staff_commercial')::integer<>0 or (v->>'cost_one_way')::integer<>7800
   or (v->>'overnight_transfer_possible')::boolean<>true then
  raise exception 'Authenticated whole-team quote / overnight estimate is wrong: %',v;
 end if;
 v:=public.quote_private_jet_leg_v1(p,'Belgrade','RS','Paris','FR',1600,5,j,394);
 if v->>'active'<>'true' then raise exception 'In-range flight should succeed: %',v; end if;
 if (v->>'reduction_bps')::integer<>5000 then raise exception 'Fatigue benefit must be capped to 50%%'; end if;
 if (v->>'staff_on_jet')::integer<>5 or (v->>'staff_commercial')::integer<>0 then
  raise exception 'Staff seating overflow invalid: %',v; end if;
 if (v->>'cost_one_way')::integer<>7800 then
  raise exception 'Unexpected paid flight cost: %',v->>'cost_one_way'; end if;
 v:=public.quote_private_jet_leg_v1(p,'Belgrade','RS','Paris','FR',1600,7,j,394);
 if v->>'active'<>'false' or v->>'reason'<>'insufficient_passenger_seats' then
  raise exception 'Player and staff may not overflow passenger capacity: %',v; end if;
 v:=public.quote_private_jet_leg_v1(p,'Belgrade','RS','Paris','FR',2200,0,j,394);
 if v->>'active'<>'false' or v->>'reason'<>'no_eligible_owned_jet_for_range' then
  raise exception 'Out-of-range flight incorrectly offered: %',v; end if;
 v:=public.quote_private_jet_leg_v1(p,'Belgrade','RS','Paris','FR',1600,0,prop,394);
 if v->>'active'<>'false' then raise exception 'Propeller plane cannot be booked: %',v; end if;
 v:=public.quote_private_jet_leg_v1(p,'Madrid','ES','Paris','FR',1600,0,j,394);
 if (v->>'reposition_cost')::integer<>5000
   or (v->>'cost_one_way')::integer<>12800 then
  raise exception 'Positioning must be charged exactly once: %',v; end if;
 v:=public.quote_private_jet_leg_v1(p,'Tokyo','JP','Paris','FR',1600,0,j,394);
 if v->>'active'<>'false' or v->>'reason'<>'jet_reposition_out_of_range' then
  raise exception 'Out-of-range reposition must not be allowed: %',v; end if;
 insert into public.player_travel_legs(id,player_id,status,departure_absolute_day,
   destination_city,destination_country_code,jet_asset_id)
 values('33333333-3333-3333-3333-333333333333',p,'planned',395,'Madrid','ES',j);
 v:=public.quote_private_jet_leg_v1(p,'Madrid','ES','Paris','FR',1600,0,j,396);
 if (v->>'reposition_cost')::integer<>0 then
  raise exception 'Projected aircraft position in planned journey not applied: %',v; end if;
 raise notice 'PASS: authenticated group quote, jet position, prop exclusion, range, fare, fatigue cap, staff overflow, reposition and planned continuation';
end $$;
