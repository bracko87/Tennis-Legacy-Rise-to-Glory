-- Tennis Legacy | Reverse purchase-referral rewards on confirmed full refunds.
-- SOURCE ONLY until separately authorized Supabase release.
-- Reward policy: only FIRST paid Coin pack and FIRST paid Premium invoice
-- per validated referral; a refunded first purchase never becomes eligible again.
-- Recovery is bounded by spendable balance; outstanding amounts are collected
-- automatically after future positive Coin ledger entries. Never negative wallets.

create table if not exists public.referral_reward_reversals (
  id uuid primary key default gen_random_uuid(),
  referral_reward_id uuid not null unique references public.referral_rewards(id) on delete cascade,
  referral_id uuid not null references public.referrals(id) on delete cascade,
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  billing_transaction_id uuid not null references public.billing_transactions(id) on delete cascade,
  coins_to_recover integer not null check (coins_to_recover>0),
  coins_recovered integer not null default 0,
  reason text not null default 'full_payment_refund',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referral_reversal_recovered_chk check(coins_recovered>=0 and coins_recovered<=coins_to_recover)
);
create index if not exists referral_reward_reversals_pending_idx
  on public.referral_reward_reversals(referrer_user_id,created_at)
  where coins_recovered<coins_to_recover;
alter table public.referral_reward_reversals enable row level security;
revoke all on table public.referral_reward_reversals from PUBLIC, anon, authenticated;

create or replace function public.recover_refunded_referral_coins_v1(p_referrer_user_id uuid)
returns integer language plpgsql security definer set search_path='public','pg_temp'
as $body$
declare v_balance bigint; v_take integer; v_recovered integer:=0; v_updated bigint; r record;
begin
  -- Only trusted billing and ledger triggers may call this.
  select coins_balance into v_balance from public.user_wallets
   where user_id=p_referrer_user_id for update;
  if not found or v_balance<=0 then return 0; end if;
  for r in
    select id,referral_reward_id,coins_to_recover,coins_recovered
    from public.referral_reward_reversals
    where referrer_user_id=p_referrer_user_id and coins_recovered<coins_to_recover
    order by created_at,id
    for update
  loop
    v_take:=least(v_balance,(r.coins_to_recover-r.coins_recovered)::bigint)::integer;
    if v_take<=0 then exit; end if;
    update public.user_wallets set coins_balance=coins_balance-v_take,updated_at=now()
    where user_id=p_referrer_user_id returning coins_balance into v_updated;
    update public.referral_reward_reversals
      set coins_recovered=coins_recovered+v_take,updated_at=now() where id=r.id;
    insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description,reference_id)
    values(p_referrer_user_id,-v_take,v_updated,'referral_reward',
      'Reversal of referral purchase reward after full payment refund',
      'referral-recovery:'||r.referral_reward_id::text||':'||(r.coins_recovered+v_take)::text);
    v_recovered:=v_recovered+v_take;
    v_balance:=v_updated;
  end loop;
  return v_recovered;
end
$body$;
revoke all on function public.recover_refunded_referral_coins_v1(uuid) from PUBLIC,anon,authenticated;

-- Consume overdue recovery only AFTER the credited transaction has written
-- its positive ledger entry, to preserve exact balance_after ordering.
create or replace function public.trg_settle_referral_recovery_after_ledger_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp'
as $body$
begin
  if new.amount>0 then
    perform public.recover_refunded_referral_coins_v1(new.user_id);
  end if;
  return new;
end
$body$;
revoke all on function public.trg_settle_referral_recovery_after_ledger_v1() from PUBLIC,anon,authenticated;
drop trigger if exists settle_referral_recovery_after_ledger_v1 on public.coin_ledger;
create trigger settle_referral_recovery_after_ledger_v1
after insert on public.coin_ledger for each row
execute function public.trg_settle_referral_recovery_after_ledger_v1();

-- A refund is evidenced by the paid billing record transitioning to refunded;
-- the billing record is server-owned and not writable through client RLS.
create or replace function public.trg_reverse_referral_purchase_on_refund_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp'
as $body$
declare r record;
begin
  if new.status='refunded' and old.status='paid'
    and new.kind in ('coin_pack_purchase','premium_invoice') then
    for r in select id,referral_id,referrer_user_id,coins
      from public.referral_rewards
      where billing_transaction_id=new.id and
        ((new.kind='coin_pack_purchase' and reward_type='coin_purchase')
         or (new.kind='premium_invoice' and reward_type='premium_purchase'))
      for update
    loop
      insert into public.referral_reward_reversals
        (referral_reward_id,referral_id,referrer_user_id,billing_transaction_id,coins_to_recover)
      values(r.id,r.referral_id,r.referrer_user_id,new.id,r.coins)
      on conflict(referral_reward_id) do nothing;
      perform public.recover_refunded_referral_coins_v1(r.referrer_user_id);
    end loop;
  end if;
  return new;
end
$body$;
revoke all on function public.trg_reverse_referral_purchase_on_refund_v1() from PUBLIC,anon,authenticated;
drop trigger if exists reverse_referral_purchase_on_refund_v1 on public.billing_transactions;
create trigger reverse_referral_purchase_on_refund_v1
after update of status on public.billing_transactions for each row
when(old.status is distinct from new.status)
execute function public.trg_reverse_referral_purchase_on_refund_v1();

-- Preserve all established Stripe handling for other events, including
-- event locking/idempotency and the original paid-state validation.
create or replace function public.try_process_tennis_stripe_event_v3(p_event_id text)
returns boolean language plpgsql security definer set search_path='public','pg_temp'
as $body$
declare
  v_event public.stripe_webhook_events%rowtype;
  v_obj jsonb;v_pi text;v_invoice text;v_customer text;
  v_amount_refunded bigint;v_amount_captured bigint;
  v_bill_id uuid;v_bill_count integer;v_paid record;
begin
  select * into v_event from public.stripe_webhook_events
  where event_id=p_event_id for update;
  if not found or v_event.processed then return true; end if;

  if v_event.event_type<>'charge.refunded' then
    -- Normal, previously existing paid/payment-failed/subscription paths.
    perform public.try_process_tennis_stripe_event_v2(p_event_id);
    -- Populate a safe PaymentIntent linkage for invoice refunds when supplied
    -- by Stripe (old invoice or new invoice payment records).
    if v_event.event_type='invoice.paid' then
      v_obj:=v_event.payload->'data'->'object';
      v_pi:=coalesce(nullif(v_obj->>'payment_intent',''),
        nullif(v_obj#>>'{payments,data,0,payment,payment_intent}',''),
        nullif(v_obj#>>'{payments,data,0,payment_intent}',''));
      if v_pi like 'pi_%' then
        update public.billing_transactions
        set stripe_payment_intent_id=v_pi
        where kind='premium_invoice' and status='paid'
          and stripe_invoice_id=v_obj->>'id'
          and stripe_payment_intent_id is null
          and not exists(select 1 from public.billing_transactions b2
            where b2.stripe_payment_intent_id=v_pi);
      end if;
    end if;
    return (select processed from public.stripe_webhook_events where event_id=p_event_id);
  end if;

  v_obj:=v_event.payload->'data'->'object';
  -- charge.refunded also fires for PARTIAL refunds. Only act on a confirmed
  -- FULL refund and on EUR charges matching the paid billing amount.
  if v_obj->>'object' is distinct from 'charge'
     or v_obj->>'currency' is distinct from 'eur'
     or coalesce((v_obj->>'refunded')::boolean,false) is not true then
    update public.stripe_webhook_events set processed=true,
      processed_at=now(),process_note='ignored_partial_or_invalid_refund'
    where event_id=p_event_id;
    return true;
  end if;
  v_amount_refunded:=coalesce((v_obj->>'amount_refunded')::bigint,0);
  v_amount_captured:=coalesce((v_obj->>'amount_captured')::bigint,0);
  if v_amount_captured<=0 or v_amount_refunded<v_amount_captured then
    update public.stripe_webhook_events set processed=true,
      processed_at=now(),process_note='ignored_incomplete_refund'
    where event_id=p_event_id;
    return true;
  end if;

  v_pi:=nullif(v_obj->>'payment_intent','');
  v_invoice:=nullif(v_obj->>'invoice','');
  v_customer:=nullif(v_obj->>'customer','');

  with matches as (
    select b.id,b.status
    from public.billing_transactions b
    where b.kind in('coin_pack_purchase','premium_invoice')
      and b.status in('paid','refunded')
      and b.amount_eur_cents=v_amount_captured
      and (v_customer is null or b.stripe_customer_id=v_customer)
      and ((v_pi is not null and b.stripe_payment_intent_id=v_pi)
           or (v_invoice is not null and b.stripe_invoice_id=v_invoice)
           or (v_pi is not null and b.kind='premium_invoice' and exists(
             select 1 from public.stripe_webhook_events invoice_event
             where invoice_event.event_type='invoice.paid'
               and invoice_event.payload->'data'->'object'->>'id'=b.stripe_invoice_id
               and v_pi in (
                 invoice_event.payload->'data'->'object'->>'payment_intent',
                 invoice_event.payload#>>'{data,object,payments,data,0,payment,payment_intent}',
                 invoice_event.payload#>>'{data,object,payments,data,0,payment_intent}'
               )
           )))
  )
  select count(*),min(id) into v_bill_count,v_bill_id from matches;
  if v_bill_count<>1 then
    update public.stripe_webhook_events
      set process_note=case when v_bill_count=0
        then 'waiting_for_refunded_charge_payment_mapping'
        else 'ambiguous_refunded_charge_payment_mapping' end
    where event_id=p_event_id;
    return false; -- keep pending for a later, verified invoice/checkout mapping
  end if;

  select id,status into v_paid from public.billing_transactions
    where id=v_bill_id for update;
  if v_paid.status='paid' then
    update public.billing_transactions set status='refunded' where id=v_bill_id;
  end if;
  update public.stripe_webhook_events
    set processed=true,processed_at=now(),
      process_note=case when v_paid.status='refunded'
        then 'referral_refund_already_recorded'
        else 'confirmed_full_refund' end
    where event_id=p_event_id;
  return true;
end
$body$;
revoke all on function public.try_process_tennis_stripe_event_v3(text) from PUBLIC,anon,authenticated;

-- This is the existing trusted-webhook queue wrapper; change only its
-- processing function to v3. Preserve the existing event-id duplicate key.
create or replace function public.process_tennis_stripe_webhook_v1(p_event jsonb)
returns jsonb language plpgsql security definer set search_path='public','pg_temp'
as $body$
declare
  v_id text:=p_event->>'id';
  v_type text:=p_event->>'type';
  r record;
  v_done integer:=0;
  v_pending integer:=0;
begin
  if v_id is null or v_type is null then raise exception 'Invalid Stripe event.'; end if;
  insert into public.stripe_webhook_events(event_id,event_type,payload)
    values(v_id,v_type,p_event)
    on conflict(event_id) do nothing;
  for r in select event_id from public.stripe_webhook_events
    where not processed order by received_at limit 100
  loop
    if public.try_process_tennis_stripe_event_v3(r.event_id) then
      v_done:=v_done+1;
    else
      v_pending:=v_pending+1;
    end if;
  end loop;
  return jsonb_build_object('event_id',v_id,'processed_now',v_done,'pending',v_pending);
end
$body$;
revoke all on function public.process_tennis_stripe_webhook_v1(jsonb) from PUBLIC,anon,authenticated;
-- The existing signature-verified Edge Function invokes the SQL processor
-- through a trusted service role; do not grant client-side EXECUTE permissions.

-- Read-only view for operators. No Data API access: access through privileged SQL.
create or replace view public.referral_purchase_refund_audit_v1
with (security_invoker=true)
as
select rr.referral_id,rr.referrer_user_id,rr.referred_user_id,
  rr.id as reward_id,rr.reward_type,rr.coins as awarded_coins,
  rr.billing_transaction_id,bt.status as payment_status,
  rr.created_at as rewarded_at,
  rev.id as reversal_id,rev.created_at as refunded_at,
  coalesce(rev.coins_recovered,0) as recovered_coins,
  coalesce(rev.coins_to_recover-rev.coins_recovered,0) as pending_recovery_coins,
  case when rev.id is null then 'awarded'
    when rev.coins_recovered=rev.coins_to_recover then 'reversed'
    else 'recovery_pending' end as reward_status
from public.referral_rewards rr
left join public.billing_transactions bt on bt.id=rr.billing_transaction_id
left join public.referral_reward_reversals rev on rev.referral_reward_id=rr.id
where rr.reward_type in('coin_purchase','premium_purchase');
revoke all on public.referral_purchase_refund_audit_v1 from PUBLIC,anon,authenticated;
