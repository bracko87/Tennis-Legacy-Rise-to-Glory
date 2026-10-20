-- Equipment Intelligence: rollback-only integration and entitlement checks.
begin;
do $qa$
declare
  v_world text;v_user uuid;v_player uuid;v_other uuid;
  v_free jsonb;v_premium jsonb;v_item jsonb;v_candidate jsonb;
  v_total integer;v_spend bigint;v_resale bigint;v_denied boolean;
begin
  foreach v_world in array array['ATP','WTA'] loop
    select p.owner_user_id,p.id into v_user,v_player
    from public.players p where p.player_type='human' and p.world=v_world
      and p.owner_user_id is not null
      and (exists(select 1 from public.premium_memberships m
        where m.user_id=p.owner_user_id and m.plan_code='premium'
          and m.status='active' and (m.current_period_end is null or m.current_period_end>now()))
        or exists(select 1 from public.tennis_premium_trials_v1 t
          where t.user_id=p.owner_user_id and t.expires_at>now()))
    order by (select count(*) from public.player_equipment_inventory i where i.player_id=p.id) desc
    limit 1;
    if v_player is null then raise exception 'No eligible Premium % fixture',v_world;end if;
    perform set_config('request.jwt.claim.sub',v_user::text,true);
    v_free:=public.get_equipment_dashboard_v1();
    v_premium:=public.get_premium_equipment_intelligence_v1(v_player);
    if v_premium->>'player_id'<>v_player::text
      or v_premium->>'world'<>v_world
      or jsonb_typeof(v_premium->'items')<>'array'
      or jsonb_typeof(v_premium->'replacement_candidates')<>'array'
      or (v_premium->>'owned_count')::integer<>
        jsonb_array_length(v_free->'inventory') then
      raise exception 'Invalid % Premium ownership/world payload',v_world;
    end if;
    select count(*)::integer,
      coalesce(sum((item->>'purchase_price_usd')::bigint),0)::bigint,
      coalesce(sum((item->>'resale_value_usd')::bigint),0)::bigint
    into v_total,v_spend,v_resale
    from jsonb_array_elements(v_premium->'items') item;
    if v_total<>(v_premium->>'owned_count')::integer
      or v_spend<>(v_premium->>'owned_purchase_spend_usd')::bigint
      or v_resale<>(v_premium->>'owned_resale_estimate_usd')::bigint then
      raise exception 'Premium % portfolio aggregates inaccurate',v_world;
    end if;
    for v_item in select value from jsonb_array_elements(v_premium->'items') x(value) loop
      if (v_item->>'condition')::numeric<0
        or (v_item->>'condition')::numeric>100
        or (v_item->>'resale_value_usd')::bigint<0
        or (v_item->>'nominal_uses_remaining')::integer<0
      then raise exception 'Invalid condition/resale/wear outputs';end if;
    end loop;
    for v_candidate in select value
      from jsonb_array_elements(v_premium->'replacement_candidates') x(value) loop
      if (v_candidate->>'nominal_cost_per_use_usd')::numeric<0
        or (v_candidate->>'current_price_usd')::bigint<0
        or v_candidate->>'availability' not in ('available','limited')
      then raise exception 'Invalid market offer calculation';end if;
    end loop;
  end loop;
  select id into v_other from public.players p
  where p.owner_user_id is not null and p.owner_user_id<>v_user limit 1;
  v_denied:=false;
  begin perform public.get_premium_equipment_intelligence_v1(v_other);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Cross-owner information leak';end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin perform public.get_premium_equipment_intelligence_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Free account allowed';end if;
  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin perform public.get_premium_equipment_intelligence_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Anonymous access allowed';end if;
  if has_function_privilege('anon'::regrole,
   'public.get_premium_equipment_intelligence_v1(uuid)','EXECUTE')
   then raise exception 'Anonymous RPC grant present';end if;
end
$qa$;
rollback;
