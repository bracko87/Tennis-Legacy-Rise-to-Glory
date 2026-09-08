create or replace function public.get_player_sponsor_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_base jsonb;
  v_contract uuid;
  v_objectives jsonb;
  v_bonus_total bigint:=0;
  v_bonus_earned bigint:=0;
  v_first_payment integer;
  v_last_payment integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;

  perform public.reprice_player_sponsor_open_offers_v1(v_player);
  v_base:=public.get_player_sponsor_dashboard_v1();
  v_contract:=nullif(v_base#>>'{active_contract,id}','')::uuid;

  if v_contract is null then
    return v_base || jsonb_build_object('objectives','[]'::jsonb,'bonus_pool_total',0,'bonus_earned',0);
  end if;

  select first_payment_absolute_day,
         first_payment_absolute_day + greatest(0,scheduled_payment_count::integer-1)*7
  into v_first_payment,v_last_payment
  from public.player_sponsor_contracts
  where id=v_contract;

  v_base:=jsonb_set(v_base,'{active_contract,first_payment_absolute_day}',to_jsonb(v_first_payment),true);
  v_base:=jsonb_set(v_base,'{active_contract,last_payment_absolute_day}',to_jsonb(v_last_payment),true);
  v_base:=jsonb_set(v_base,'{active_contract,payment_frequency_days}',to_jsonb(7),true);

  perform public.sponsor_refresh_player_objectives_v1(v_player,(v_base->>'current_absolute_day')::integer);

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'objective_code',o.objective_code,'title',o.title,'description',o.description,
    'target_value',o.target_value,'current_value',o.current_value,'reward_amount',o.reward_amount,
    'status',o.status,'achieved_absolute_day',o.achieved_absolute_day
  ) order by case o.objective_code when 'appearances' then 1 when 'match_wins' then 2 else 3 end),'[]'::jsonb),
  coalesce(sum(o.reward_amount),0),coalesce(sum(o.reward_amount) filter(where o.status='achieved'),0)
  into v_objectives,v_bonus_total,v_bonus_earned
  from public.player_sponsor_objectives o where o.contract_id=v_contract;

  return jsonb_set(
    jsonb_set(
      jsonb_set(v_base,'{active_contract,objectives}',v_objectives,true),
      '{active_contract,bonus_pool_total}',to_jsonb(v_bonus_total),true
    ),
    '{active_contract,bonus_earned}',to_jsonb(v_bonus_earned),true
  );
end;
$function$;