-- CPX Tennis Legacy app 37031: only authenticated service-role callbacks.
-- 15 whole Coins per dollar, with small survey credits accumulated exactly.
create unique index if not exists cpx_tennis_ledger_reference_idx
  on public.coin_ledger(reference_id) where reference_id like 'cpx:37031:%';

create or replace function public.apply_cpx_tennis_postback_v1(
  p_trans_id text, p_user_id uuid, p_status integer,
  p_reward_type text, p_amount_micro_usd bigint
) returns jsonb
language plpgsql security definer
set search_path=public,auth,pg_temp
as $$
declare
  v_prior public.cpx_tennis_reward_transactions%rowtype;
  v_rewards public.cpx_tennis_reward_balances%rowtype;
  v_delta bigint:=0;
  v_active bigint;
  v_target integer;
  v_coin_delta integer;
  v_wallet bigint;
  v_new_balance bigint;
  v_result text;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Service role only';
  end if;
  if p_user_id is null or p_trans_id is null
    or length(p_trans_id) not between 1 and 128
    or p_trans_id !~ '^[A-Za-z0-9_.:-]+$'
    or p_status is null or p_status not in (1,2)
    or p_reward_type is null or p_reward_type not in ('complete','out','bonus')
    or p_amount_micro_usd is null or p_amount_micro_usd not between 0 and 50000000
  then raise exception 'Invalid CPX event'; end if;

  insert into public.cpx_tennis_reward_balances(user_id)
    values(p_user_id) on conflict(user_id) do nothing;
  select * into strict v_rewards from public.cpx_tennis_reward_balances
    where user_id=p_user_id for update;
  select * into v_prior from public.cpx_tennis_reward_transactions
    where trans_id=p_trans_id for update;
  if found then
    if v_prior.user_id <> p_user_id then raise exception 'Invalid owner'; end if;
    if v_prior.status = p_status then
      return jsonb_build_object('accepted',true,'result','duplicate','coin_delta',0);
    end if;
    if v_prior.status = 2 then
      return jsonb_build_object('accepted',true,'result','already_canceled','coin_delta',0);
    end if;
    if p_status <> 2 then raise exception 'Invalid transition'; end if;
    v_delta := -v_prior.amount_micro_usd;
    update public.cpx_tennis_reward_transactions
      set status=2,updated_at=now() where trans_id=p_trans_id;
    v_result:='canceled';
  else
    insert into public.cpx_tennis_reward_transactions(
      trans_id,user_id,reward_type,amount_micro_usd,status
    ) values(p_trans_id,p_user_id,p_reward_type,p_amount_micro_usd,p_status);
    if p_status=1 then
      v_delta:=p_amount_micro_usd;
      v_result:='credited';
    else
      v_result:='canceled_before_credit';
    end if;
  end if;
  v_active:=v_rewards.active_micro_usd+v_delta;
  if v_active<0 then raise exception 'Negative CPX net revenue'; end if;
  v_target:=floor(v_active::numeric*15/1000000)::integer;
  v_coin_delta:=v_target-v_rewards.net_coins_applied;

  insert into public.user_wallets(user_id)
    values(p_user_id) on conflict(user_id) do nothing;
  select coins_balance into strict v_wallet from public.user_wallets
    where user_id=p_user_id for update;
  if v_coin_delta<0 then
    v_coin_delta:= -least((-v_coin_delta)::bigint,v_wallet)::integer;
  end if;
  if v_coin_delta<>0 then
    update public.user_wallets set
      coins_balance=coins_balance+v_coin_delta,
      lifetime_coins_earned=lifetime_coins_earned+greatest(v_coin_delta,0),
      lifetime_coins_spent=lifetime_coins_spent+greatest(-v_coin_delta,0),
      updated_at=now()
    where user_id=p_user_id returning coins_balance into v_new_balance;
    -- Existing Tennis ledger permits promo/refund categories. Keep their
    -- check constraint intact; identify CPX by description + reference.
    insert into public.coin_ledger(
      user_id,amount,balance_after,entry_type,description,reference_id
    ) values(
      p_user_id,v_coin_delta,v_new_balance,
      case when v_coin_delta>0 then 'promo' else 'refund' end,
      case when v_coin_delta>0 then 'CPX Research survey earned Coins'
            else 'CPX Research survey reward reversed' end,
      'cpx:37031:'||p_trans_id||':'||p_status::text
    );
  end if;
  update public.cpx_tennis_reward_balances set
    active_micro_usd=v_active,
    net_coins_applied=net_coins_applied+v_coin_delta,
    updated_at=now()
  where user_id=p_user_id;
  return jsonb_build_object(
    'accepted',true,'result',v_result,'coin_delta',v_coin_delta,
    'owed_coins',greatest(v_rewards.net_coins_applied+v_coin_delta-v_target,0)
  );
end $$;
revoke all on function public.apply_cpx_tennis_postback_v1(text,uuid,integer,text,bigint)
  from public,anon,authenticated;
grant execute on function public.apply_cpx_tennis_postback_v1(text,uuid,integer,text,bigint)
  to service_role;