-- Use the existing allowed Coin ledger category for the one-time career grant.

drop index if exists public.coin_ledger_new_career_starting_uidx;

create unique index coin_ledger_new_career_starting_uidx
on public.coin_ledger(user_id,reference_id)
where entry_type='signup_reward'
  and reference_id='new-career-starting-coins-v1';

create or replace function public.grant_new_career_starting_coins_v1(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_balance bigint;
begin
  if p_user_id is null then
    return jsonb_build_object('status','skipped','reason','missing_user');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('new-career-starting-coins:'||p_user_id::text,0));

  if exists(
    select 1
    from public.coin_ledger
    where user_id=p_user_id
      and entry_type='signup_reward'
      and reference_id='new-career-starting-coins-v1'
  ) then
    select coins_balance into v_balance
    from public.user_wallets
    where user_id=p_user_id;

    return jsonb_build_object(
      'status','already_granted',
      'amount',20,
      'balance_after',coalesce(v_balance,0)
    );
  end if;

  insert into public.user_wallets(user_id)
  values(p_user_id)
  on conflict(user_id) do nothing;

  update public.user_wallets
  set coins_balance=coins_balance+20,
      lifetime_coins_earned=lifetime_coins_earned+20,
      updated_at=now()
  where user_id=p_user_id
  returning coins_balance into v_balance;

  insert into public.coin_ledger(
    user_id,amount,balance_after,entry_type,description,reference_id
  ) values(
    p_user_id,20,v_balance,'signup_reward',
    'New career starting Coins',
    'new-career-starting-coins-v1'
  );

  return jsonb_build_object(
    'status','granted',
    'amount',20,
    'balance_after',v_balance
  );
exception when unique_violation then
  select coins_balance into v_balance
  from public.user_wallets
  where user_id=p_user_id;
  return jsonb_build_object('status','already_granted','amount',20,'balance_after',coalesce(v_balance,0));
end;
$$;
