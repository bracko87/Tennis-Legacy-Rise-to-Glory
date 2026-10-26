\set ON_ERROR_STOP on
do $trip_lifecycle$
declare
 p uuid:='11111111-1111-1111-1111-111111111111';
 j uuid:='22222222-2222-2222-2222-222222222225';
 paris_comp uuid:='44444444-4444-4444-4444-444444444444';
 syd_comp uuid:='66666666-6666-6666-6666-666666666666';
 v_leg uuid;v_flight public.player_travel_legs%rowtype;v_result jsonb;
 v_cost integer;v_fatigue integer;v_count integer;v_city text;
begin
 raise notice 'Selected Paris mode and jet: %',
   (select row_to_json(x) from (select travel_mode,owned_jet_asset_id from public.player_tournament_travel_selection where player_id=p and competition_id=paris_comp) x);
 raise notice 'Direct-jet preflight: %',
   public.quote_private_jet_leg_v1(p,'Belgrade','RS','Paris','FR',1600,6,j,394);
 select public.insert_planned_travel_leg_v1(
  p,'tournament','home','Belgrade','RS',null,null,null,
  'tournament','Paris','FR',null,null,paris_comp::text,394,395,false)
 into v_leg;
 select * into v_flight from public.player_travel_legs where id=v_leg;
 if v_flight.travel_mode<>'private_jet' or v_flight.jet_asset_id is distinct from j then
   raise exception 'Valid direct jet journey was not booked: %',row_to_json(v_flight);end if;
 if v_flight.estimated_cost<>7800 or (v_flight.jet_quote->>'staff_commercial')::integer<>0 then
   raise exception 'Jet operating fee must cover player and all six coaches once: %',row_to_json(v_flight);end if;
 v_result:=public.process_travel_leg_v1(v_leg);
 if v_result->>'status'<>'completed' or (v_result->>'net_travel_fatigue')::integer<>9
   or (v_result->>'fatigue_after')::integer<>9 then
   raise exception 'Booked jet fatigue / completion wrong: %',v_result;end if;
 select sum(-amount)::integer,count(*) into v_cost,v_count
 from public.test_career_transactions where idempotency_key='travel-leg:'||v_leg::text;
 if v_cost<>7800 or v_count<>1 then
   raise exception 'Jet fare not debited exactly once: %/%',v_cost,v_count;end if;
 select city into v_city from public.player_private_jet_positions where owned_asset_id=j;
 if v_city<>'Paris' then raise exception 'Jet must arrive with player in Paris: %',v_city; end if;
 v_result:=public.process_travel_leg_v1(v_leg);
 if v_result->>'status'<>'already_processed' then raise exception 'Second jet processing should be idempotent'; end if;
 select count(*) into v_count from public.test_career_transactions where idempotency_key='travel-leg:'||v_leg::text;
 if v_count<>1 then raise exception 'Duplicate jet invoice!';end if;

 -- Selecting a smaller jet for distant Australia has already saved the
 -- commercial fallback via the real RPC; no private jet charge applies.
 select public.insert_planned_travel_leg_v1(
  p,'tournament','tournament','Paris','FR',null,null,paris_comp::text,
  'tournament','Sydney','AU',null,null,syd_comp::text,396,397,false)
 into v_leg;
 select * into v_flight from public.player_travel_legs where id=v_leg;
 if v_flight.travel_mode<>'commercial' or v_flight.jet_asset_id is not null
   or v_flight.jet_quote is not null then
   raise exception 'Out-of-range journey must stay commercial: %',row_to_json(v_flight);end if;
 if v_flight.estimated_cost<>3500 then
   raise exception 'Commercial player + six staff total incorrect: %',v_flight.estimated_cost;end if;
 v_result:=public.process_travel_leg_v1(v_leg);
 if v_result->>'status'<>'completed'
   or (v_result->>'net_travel_fatigue')::integer<>17
   or (v_result->>'fatigue_after')::integer<>26 then
   raise exception 'Commercial journey should apply ordinary fatigue: %',v_result;end if;
 select sum(-amount)::integer,count(*) into v_cost,v_count from public.test_career_transactions
   where idempotency_key='travel-leg:'||v_leg::text;
 if v_cost<>3500 or v_count<>1 then
   raise exception 'Commercial party fare incorrect or duplicated: %/%',v_cost,v_count;end if;
 select city into v_city from public.player_private_jet_positions where owned_asset_id=j;
 if v_city<>'Paris' then raise exception 'Commercial flight must not teleport jet to Sydney';end if;
 select current_city into v_city from public.player_location_state where player_id=p;
 if v_city<>'Sydney' then raise exception 'Player should arrive in Sydney by commercial flight';end if;
 v_result:=public.process_travel_leg_v1(v_leg);
 if v_result->>'status'<>'already_processed' then raise exception 'Commercial rerun should be idempotent';end if;
 raise notice 'PASS: real flight creation & processing, 6 staff included in one jet fee, exact debits, fatigue, location, commercial fallback and idempotency';
end;$trip_lifecycle$;
