-- Referral refund/recovery regression. Transaction rollback: no lasting data changes.
-- Run only AFTER the separately approved migration, or concatenate
-- BEGIN; migration SQL; this DO block; ROLLBACK; for isolated validation.
begin;
set local lock_timeout='2s';
set local statement_timeout='25s';
do $qa$
declare
 r public.referrals%rowtype;
 v_base bigint;v_other bigint;v_paid_coin uuid;v_paid_premium uuid;
 v_refund_event text;v_repeat_event text;v_partial_event text;
 v_pi_coin text;v_pi_premium text;v_customer text;v_invoice text;v_invoice_event text;
 v_wallet bigint;v_count int;v_due int;v_recovered int;v_gross int;v_amount int;
 v_dashboard jsonb;v_admin jsonb;v_admin_user uuid;
begin
  if (select (base_reward_coins,coin_purchase_reward_coins,premium_purchase_reward_coins)
     from public.referral_program_settings where id=1) is distinct from (3,15,30) then
    raise exception 'Live reward settings differ from regression assumptions; stop';
  end if;
  select * into r from public.referrals
    where status='pending_activation' and reward_slot is null
    order by registered_at limit 1 for update;
  if not found then raise exception 'Missing isolated referral fixture'; end if;

  select coins_balance into v_base from public.user_wallets where user_id=r.referrer_user_id;
  select coins_balance into v_other from public.user_wallets where user_id=r.referred_user_id;
  v_base:=coalesce(v_base,0);v_other:=coalesce(v_other,0);

  update public.referrals set reward_slot=1,status='active',activated_at=now()
    where id=r.id;
  v_pi_coin:='pi_refund_qa_'||replace(gen_random_uuid()::text,'-','');
  v_pi_premium:='pi_refund_qa_'||replace(gen_random_uuid()::text,'-','');
  v_customer:='cus_refund_qa_'||replace(gen_random_uuid()::text,'-','');
  v_invoice:='in_refund_qa_'||replace(gen_random_uuid()::text,'-','');

  -- No reward on pending / failed / canceled.
  insert into public.billing_transactions(user_id,kind,status,amount_eur_cents,coins_amount)
  values (r.referred_user_id,'coin_pack_purchase','pending',100,10),
    (r.referred_user_id,'coin_pack_purchase','failed',100,10),
    (r.referred_user_id,'premium_invoice','canceled',500,30);
  if exists(select 1 from public.referral_rewards where referral_id=r.id) then
    raise exception 'Unconfirmed payment issued reward';
  end if;

  -- Exactly one 15-Coin payout, one 30-Coin payout, both to referrer.
  insert into public.billing_transactions(user_id,kind,status,amount_eur_cents,coins_amount,
    stripe_payment_intent_id,stripe_customer_id)
  values (r.referred_user_id,'coin_pack_purchase','paid',100,10,v_pi_coin,v_customer)
  returning id into v_paid_coin;
  insert into public.billing_transactions(user_id,kind,status,amount_eur_cents,coins_amount,
    stripe_invoice_id,stripe_customer_id)
  values (r.referred_user_id,'premium_invoice','paid',500,30,v_invoice,v_customer)
  returning id into v_paid_premium;
  -- Realistic subscription case: invoice billing initially knows only invoice
  -- ID. A verified invoice_payment.paid event supplies the PaymentIntent link.
  v_invoice_event:='evt_refund_qa_invoice_payment_'||gen_random_uuid()::text;
  insert into public.stripe_webhook_events(event_id,event_type,payload)
  values(v_invoice_event,'invoice_payment.paid',
    jsonb_build_object('id',v_invoice_event,'type','invoice_payment.paid',
      'data',jsonb_build_object('object',jsonb_build_object(
        'object','invoice_payment','invoice',v_invoice,'status','paid',
        'payment',jsonb_build_object('payment_intent',v_pi_premium)))));
  if not public.try_process_tennis_stripe_event_v3(v_invoice_event) then
    raise exception 'Verified invoice payment mapping failed'; end if;
  if (select stripe_payment_intent_id from public.billing_transactions
      where id=v_paid_premium) is distinct from v_pi_premium then
    raise exception 'Premium invoice PaymentIntent not linked'; end if;
  insert into public.billing_transactions(user_id,kind,status,amount_eur_cents,coins_amount)
  values (r.referred_user_id,'coin_pack_purchase','paid',100,10),
    (r.referred_user_id,'premium_invoice','paid',500,30);
  perform public.process_referral_commerce_for_user_v1(r.referred_user_id);
  select count(*) into v_count from public.referral_rewards where referral_id=r.id;
  if v_count<>2 or not exists(select 1 from public.referral_rewards
    where referral_id=r.id and reward_type='coin_purchase' and coins=15
      and billing_transaction_id=v_paid_coin and referrer_user_id=r.referrer_user_id)
   or not exists(select 1 from public.referral_rewards
    where referral_id=r.id and reward_type='premium_purchase' and coins=30
      and billing_transaction_id=v_paid_premium and referrer_user_id=r.referrer_user_id)
  then raise exception 'First paid purchase referral rewards incorrect'; end if;
  select coins_balance into v_wallet from public.user_wallets where user_id=r.referrer_user_id;
  if v_wallet<>v_base+45 then raise exception 'Initial reward wallet mismatch'; end if;
  if (select coins_balance from public.user_wallets where user_id=r.referred_user_id) is distinct from v_other then
    raise exception 'Referred user credited instead of referrer'; end if;

  -- Partial refund MUST NOT reverse a reward.
  v_partial_event:='evt_refund_qa_partial_'||gen_random_uuid()::text;
  insert into public.stripe_webhook_events(event_id,event_type,payload)
  values(v_partial_event,'charge.refunded',jsonb_build_object('id',v_partial_event,
    'type','charge.refunded','data',jsonb_build_object('object',jsonb_build_object(
    'object','charge','currency','eur','refunded',false,'amount_captured',100,
    'amount_refunded',40,'payment_intent',v_pi_coin,'customer',v_customer))));
  if not public.try_process_tennis_stripe_event_v3(v_partial_event) then raise exception 'Partial event failed'; end if;
  if (select status from public.billing_transactions where id=v_paid_coin)<>'paid' then
    raise exception 'Partial refund incorrectly reversed purchase';end if;

  -- Confirmed full refund from trusted Stripe webhook MUST reverse exactly once.
  v_refund_event:='evt_refund_qa_full_'||gen_random_uuid()::text;
  insert into public.stripe_webhook_events(event_id,event_type,payload)
  values(v_refund_event,'charge.refunded',jsonb_build_object('id',v_refund_event,
    'type','charge.refunded','data',jsonb_build_object('object',jsonb_build_object(
    'object','charge','currency','eur','refunded',true,'amount_captured',100,
    'amount_refunded',100,'payment_intent',v_pi_coin,'customer',v_customer))));
  if not public.try_process_tennis_stripe_event_v3(v_refund_event) then raise exception 'Full event failed'; end if;
  if (select status from public.billing_transactions where id=v_paid_coin)<>'refunded' then
    raise exception 'Confirmed Stripe refund did not update billing';end if;
  if not exists(select 1 from public.referral_reward_reversals rev
     join public.referral_rewards rr on rr.id=rev.referral_reward_id
     where rr.referral_id=r.id and rr.reward_type='coin_purchase'
       and rev.coins_to_recover=15 and rev.coins_recovered=15) then
    raise exception 'Coin reward was not reversed';end if;
  select coins_balance into v_wallet from public.user_wallets where user_id=r.referrer_user_id;
  if v_wallet<>v_base+30 then raise exception 'Refund failed to update referrer wallet';end if;

  -- Replay same event, then a second distinct event for the same refund.
  if not public.try_process_tennis_stripe_event_v3(v_refund_event) then raise exception 'Duplicate event refused';end if;
  v_repeat_event:='evt_refund_qa_repeat_'||gen_random_uuid()::text;
  insert into public.stripe_webhook_events(event_id,event_type,payload)
  select v_repeat_event,event_type,jsonb_set(payload,'{id}',to_jsonb(v_repeat_event))
    from public.stripe_webhook_events where event_id=v_refund_event;
  if not public.try_process_tennis_stripe_event_v3(v_repeat_event) then raise exception 'Repeated refund refused';end if;
  if (select count(*) from public.referral_reward_reversals rev
     join public.referral_rewards rr on rr.id=rev.referral_reward_id
     where rr.referral_id=r.id)<>1 then
    raise exception 'Refund duplicated reversal';
  end if;

  -- Spend all remaining Coins (including unrelated balance) in this ROLLBACK,
  -- then verify pending Premium reward recovery is never a negative balance.
  update public.user_wallets set coins_balance=0 where user_id=r.referrer_user_id;
  insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description)
    values(r.referrer_user_id,-(v_base+30),0,'spend','ROLLBACK-ONLY spend fixture');
  v_refund_event:='evt_refund_qa_premium_'||gen_random_uuid()::text;
  insert into public.stripe_webhook_events(event_id,event_type,payload)
  values(v_refund_event,'charge.refunded',jsonb_build_object('id',v_refund_event,
    'type','charge.refunded','data',jsonb_build_object('object',jsonb_build_object(
    'object','charge','currency','eur','refunded',true,'amount_captured',500,
    'amount_refunded',500,'payment_intent',v_pi_premium,'customer',v_customer))));
  if not public.try_process_tennis_stripe_event_v3(v_refund_event) then raise exception 'Premium refund event failed';end if;
  select coins_to_recover-coins_recovered into v_due from public.referral_reward_reversals rev
    join public.referral_rewards rr on rr.id=rev.referral_reward_id
    where rr.referral_id=r.id and rr.reward_type='premium_purchase';
  if v_due<>30 then raise exception 'Insufficient wallet did not create 30-Coin recovery debt: %',v_due;end if;

  -- Credit 7 Coins: positive ledger is saved BEFORE 7-Coin deduction ledger.
  update public.user_wallets set coins_balance=coins_balance+7
  where user_id=r.referrer_user_id returning coins_balance into v_wallet;
  insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description)
  values(r.referrer_user_id,7,v_wallet,'promo','ROLLBACK-ONLY earn fixture');
  select coins_to_recover-coins_recovered into v_due from public.referral_reward_reversals rev
    join public.referral_rewards rr on rr.id=rev.referral_reward_id
    where rr.referral_id=r.id and rr.reward_type='premium_purchase';
  if v_due<>23 or (select coins_balance from public.user_wallets where user_id=r.referrer_user_id)<>0
  then raise exception 'Partial recovery on future Coin credit failed';end if;

  update public.user_wallets set coins_balance=coins_balance+23
  where user_id=r.referrer_user_id returning coins_balance into v_wallet;
  insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description)
  values(r.referrer_user_id,23,v_wallet,'promo','ROLLBACK-ONLY earn fixture');
  select coins_to_recover-coins_recovered into v_due from public.referral_reward_reversals rev
    join public.referral_rewards rr on rr.id=rev.referral_reward_id
    where rr.referral_id=r.id and rr.reward_type='premium_purchase';
  if v_due<>0 or (select coins_balance from public.user_wallets where user_id=r.referrer_user_id)<>0
  then raise exception 'Full recovery on future Coin credit failed';end if;

  -- Net Invite Friends totals, red/green status and backend ledger all agree.
  perform set_config('request.jwt.claim.sub',r.referrer_user_id::text,true);
  v_dashboard:=public.get_referral_dashboard_v1();
  if (v_dashboard->'stats'->>'coins')::int<>0 or not exists(
    select 1 from jsonb_array_elements(v_dashboard->'activity') a(item)
    where item->>'id'=r.id::text
      and (item->>'coin_purchase_rewarded')::boolean=false
      and (item->>'premium_purchase_rewarded')::boolean=false
      and (item->>'coin_purchase_reversed')::boolean=true
      and (item->>'premium_purchase_reversed')::boolean=true)
  then raise exception 'Invite Friends totals/status did not reflect refunds'; end if;
  if (select count(*) from public.coin_ledger l
      where l.user_id=r.referrer_user_id and l.reference_id like 'referral-recovery:%')<>3 then
    raise exception 'Recovery ledger missing or duplicate';end if;

  -- Admin dashboard returns per-payment audit links to both users and
  -- the original billing transaction (only when an admin fixture exists).
  select a.user_id into v_admin_user from public.referral_admins a
  where a.can_manage_referrals limit 1;
  if v_admin_user is not null then
    perform set_config('request.jwt.claim.sub',v_admin_user::text,true);
    v_admin:=public.get_referral_admin_dashboard_v1();
    if (v_admin->'summary'->>'refund_recovery_pending_coins')::integer<>0
    then raise exception 'Admin dashboard pending recovery mismatch'; end if;
  end if;
  perform set_config('request.jwt.claim.sub','',true);
end
$qa$;
rollback;
select 'PASS: refunded referral Coins recovered exactly once; NO production changes persisted' as result;
