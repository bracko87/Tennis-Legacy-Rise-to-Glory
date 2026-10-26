\set ON_ERROR_STOP on
do $multistop_tests$
declare
 p uuid:='11111111-1111-1111-1111-111111111111';
 a uuid:='55555555-5555-5555-5555-555555555555';
 q jsonb; r jsonb;leg jsonb;v_max integer:=2820;
 v_stops integer;v_days integer;v_total integer;
begin
 q:=public.quote_private_jet_leg_v1(p,'Belgrade','RS','Sydney','AU',16000,6,a,394);
 if not coalesce((q->>'active')::boolean,false) then
  raise exception 'Citation M3 Serbia to Sydney should find a refuel route: %',q;
 end if;
 v_stops:=(q->>'stop_count')::integer;
 v_days:=(q->>'estimated_travel_days')::integer;
 v_total:=(q->>'route_distance_km')::integer;
 if v_stops<4 or v_days<2 or v_total<15000 then
  raise exception 'Long-distance route must contain real stops/days/distance: %',q;
 end if;
 if (q->>'staff_on_jet')::integer<>6 or (q->>'staff_commercial')::integer<>0
  or (q->>'party_size')::integer<>7 or (q->>'single_party_charge')::boolean is distinct from true then
  raise exception 'Multi-stop flight must include all six staff for one aircraft charge: %',q;
 end if;
 if (q->>'cost_one_way')::integer<20000
  or (q->>'refuel_stop_cost')::integer<>v_stops*1800 then
  raise exception 'Refuelling fees must be charged in the one whole-party total: %',q;
 end if;
 if (q->>'refuel_fatigue_penalty_bps')::integer<=0 or
    (q->>'reduction_bps')::integer>2400 then
  raise exception 'Additional stops should dilute, not increase, comfort bonus: %',q;
 end if;
 if (q->>'overnight_transfer_possible')::boolean is distinct from false then
  raise exception 'Multi-day Serbia-to-Australia flight cannot be overnight eligible: %',q;
 end if;
 for leg in select value from jsonb_array_elements(q->'route_legs') loop
  if (leg->>'distance_km')::integer>v_max then
   raise exception 'Route includes leg beyond 94%% range margin: %',leg;
  end if;
 end loop;
 r:=public.private_jet_refuel_route_v1('Honolulu','US','Sydney','AU',3000,18);
 if coalesce((r->>'active')::boolean,false) then
  raise exception 'Unsupported ocean gap should never teleport: %',r;
 end if;
 raise notice 'PASS: Serbia-Australia private jet with % refuelling stops, % game travel days and % km, no staff extra fares',v_stops,v_days,v_total;
end;$multistop_tests$;
