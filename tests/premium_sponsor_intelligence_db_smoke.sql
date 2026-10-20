-- Sponsor Intelligence backend smoke test. All SQL is read-only; transaction rollback adds safety.
begin;
do $qa$
declare
  v_world text;
  v_uid uuid;
  v_player uuid;
  v_other uuid;
  v_result jsonb;
  v_active jsonb;
  v_contract uuid;
  v_received bigint;
  v_bonus_paid bigint;
  v_total integer;
  v_denied boolean;
begin
  foreach v_world in array array['ATP','WTA'] loop
    select p.owner_user_id,p.id into v_uid,v_player
    from public.players p
    where p.world=v_world and p.player_type='human'
      and p.owner_user_id is not null
      and (exists(select 1 from public.premium_memberships m
        where m.user_id=p.owner_user_id and m.plan_code='premium'
          and m.status='active' and (m.current_period_end is null or m.current_period_end>now()))
        or exists(select 1 from public.tennis_premium_trials_v1 t
        where t.user_id=p.owner_user_id and t.expires_at>now()))
    order by (select count(*) from public.player_sponsor_contracts c
      where c.player_id=p.id and c.status='active') desc limit 1;
    if v_player is null then raise exception 'Missing Premium fixture for %',v_world; end if;
    perform set_config('request.jwt.claim.sub',v_uid::text,true);
    v_result:=public.get_premium_sponsor_intelligence_v1(v_player);
    if v_result->>'player_id'<>v_player::text
       or jsonb_typeof(v_result->'offers')<>'array'
       or jsonb_array_length(v_result->'offers')<>(v_result->>'offer_count')::integer
       then raise exception 'Invalid % sponsor report contract',v_world; end if;
    v_active:=v_result->'active_contract';
    if v_active is not null and v_active<>'null'::jsonb then
      v_contract:=(v_active->>'id')::uuid;
      select coalesce(sum(x.amount),0)::bigint into v_received
      from public.career_finance_transactions x
        where x.player_id=v_player and x.source_type='sponsor_contract'
        and x.source_id=v_contract::text and x.amount>0;
      select coalesce(sum(x.amount),0)::bigint into v_bonus_paid
      from public.career_finance_transactions x
      join public.player_sponsor_objectives o
        on o.id::text=x.source_id and o.contract_id=v_contract
      where x.player_id=v_player and x.source_type='sponsor_objective' and x.amount>0;
      select count(*)::integer into v_total from public.player_sponsor_objectives
        where contract_id=v_contract;
      if (v_active->>'guaranteed_received_usd')::bigint<>v_received
        or (v_active->>'bonus_posted_usd')::bigint<>v_bonus_paid
        or (v_active->>'objectives_total')::integer<>v_total
        or (v_active->>'guaranteed_remaining_usd')::bigint<>greatest(0,
           (v_active->>'guaranteed_total_usd')::bigint-v_received)
        then raise exception 'Mismatch between % report and ledger',v_world;end if;
      if exists(select 1 from jsonb_array_elements(v_active->'attention_objectives') obj
        where (obj->>'objective_code') in ('ranking_peak','season_finish_rank')
          and obj->>'progress_percent' is not null) then
        raise exception 'Rank milestone incorrectly shown as percentage';end if;
    end if;
  end loop;
  select id into v_other from public.players p where p.owner_user_id is not null
    and p.owner_user_id<>v_uid limit 1;
  v_denied:=false;
  begin perform public.get_premium_sponsor_intelligence_v1(v_other);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Cross-owner sponsor data exposed';end if;
  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin perform public.get_premium_sponsor_intelligence_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Non-Premium sponsor report exposed';end if;
  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin perform public.get_premium_sponsor_intelligence_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Anonymous sponsor report exposed';end if;
  if has_function_privilege('anon'::regrole,
     'public.get_premium_sponsor_intelligence_v1(uuid)','EXECUTE') then
    raise exception 'Anonymous EXECUTE grant present';end if;
end
$qa$;
rollback;
