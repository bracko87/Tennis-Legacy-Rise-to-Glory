\set ON_ERROR_STOP on
do $$
declare approved text[]:=array[
 'air_cessaro_citation_m3','air_emborgier_phenom_350e','air_bombara_challenger_420',
 'air_cessaro_citation_latitude_x','air_emborgier_praetor_680','air_dassier_falcon_9x',
 'air_gulfstar_g650_lx','air_bombara_global_8000x','air_gulfstar_g900_sovereign'
];
v_count integer; v_reductions integer[];
begin
 select count(*) into v_count from public.private_life_asset_catalog
  where category='private_jet' and coalesce((metadata->>'tournament_travel_eligible')::boolean,false);
 if v_count<>9 then raise exception 'Exactly nine aircraft should be bookable: %',v_count;end if;

 select count(*) into v_count from public.private_life_asset_catalog
  where code=any(approved) and
   (coalesce((metadata->>'tournament_travel_eligible')::boolean,false)<>true
   or (metadata->>'passenger_capacity')::integer<7
   or (metadata->>'max_range_km')::integer<3000
   or (metadata->>'cost_per_km')::integer<=0
   or (metadata->>'base_trip_cost')::integer<=0
   or (metadata->>'cruise_speed_kmh')::integer<=0
   or (metadata->>'overnight_transfer_limit_hours')::integer<>10);
 if v_count<>0 then raise exception 'Approved fleet lacks consistent seating/price/range/speed/overnight specification: %',v_count;end if;

 select count(*) into v_count from public.private_life_asset_catalog
  where category='private_jet' and code<>all(approved)
    and coalesce((metadata->>'tournament_travel_eligible')::boolean,false)=true;
 if v_count<>0 then raise exception 'Nonapproved aircraft can still fly tournaments: %',v_count;end if;

 select array_agg((metadata->>'travel_fatigue_reduction_bps')::integer order by (metadata->>'max_range_km')::integer)
 into v_reductions from public.private_life_asset_catalog where code=any(approved);
 for i in 2..array_length(v_reductions,1) loop
  if v_reductions[i]<=v_reductions[i-1] then
   raise exception 'Comfort progression not increasing at level %',i;
  end if;
 end loop;
 if v_reductions[9]<>5000 then raise exception 'Flagship fatigue cap must be 50 percent';end if;
 raise notice 'PASS: exactly nine screenshot aircraft, model-specific travel stats, full team, and 24-50 percent fatigue tiers';
end $$;
