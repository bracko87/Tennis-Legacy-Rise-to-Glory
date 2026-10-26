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

  -- Stripe's InvoicePayment resource links subscription invoices to their
  -- underlying PaymentIntent even when invoice.paid omits that identifier.
  if v_event.event_type='invoice_payment.paid' then
    v_obj:=v_event.payload->'data'->'object';
    v_invoice:=nullif(v_obj->>'invoice','');
    v_pi:=coalesce(nullif(v_obj#>>'{payment,payment_intent}',''),
      nullif(v_obj->>'payment_intent',''));
    if v_obj->>'object' is distinct from 'invoice_payment'
       or v_obj->>'status' is distinct from 'paid'
       or v_invoice is null or v_pi is null or v_pi not like 'pi_%' then
      update public.stripe_webhook_events set processed=true,
        processed_at=now(),process_note='ignored_unmatched_invoice_payment'
      where event_id=p_event_id;
      return true;
    end if;
    update public.billing_transactions
      set stripe_payment_intent_id=v_pi
      where kind='premium_invoice' and status='paid'
        and stripe_invoice_id=v_invoice
        and (stripe_payment_intent_id is null or stripe_payment_intent_id=v_pi)
        and not exists(select 1 from public.billing_transactions other
          where other.stripe_payment_intent_id=v_pi
            and other.stripe_invoice_id is distinct from v_invoice);
    if found then
      update public.stripe_webhook_events set processed=true,
        processed_at=now(),process_note='premium_invoice_payment_linked'
      where event_id=p_event_id;
      return true;
    end if;
    update public.stripe_webhook_events
      set process_note='waiting_for_invoice_billing_mapping'
    where event_id=p_event_id;
    return false;
  end if;

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
  select count(*),min(id::text)::uuid into v_bill_count,v_bill_id from matches;
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


-- Keep Invite Friends totals NET of refunds while retaining payout history;
-- expose per-payment refund/recovery details in the existing admin dashboard.
CREATE OR REPLACE FUNCTION public.get_referral_dashboard_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_settings public.referral_program_settings%rowtype;
  v_total int;
  v_pending int;
  v_active int;
  v_rewarded int;
  v_coins bigint;
  v_activity jsonb;
  v_contests jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  v_code := public.ensure_referral_code_v1(v_uid);
  select * into v_settings from public.referral_program_settings where id=1;
  select count(*)::int,
         count(*) filter(where status in ('registered','pending_activation'))::int,
         count(*) filter(where status in ('active','rewarded'))::int,
         count(*) filter(where exists(select 1 from public.referral_rewards rr where rr.referral_id=r.id and rr.reward_type='base_referral'))::int
  into v_total,v_pending,v_active,v_rewarded
  from public.referrals r where referrer_user_id=v_uid;
  select coalesce(sum(rr.coins-case when rev.id is null then 0 else rev.coins_to_recover end),0)
  into v_coins from public.referral_rewards rr
  left join public.referral_reward_reversals rev on rev.referral_reward_id=rr.id
  where rr.referrer_user_id=v_uid;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',q.id,'registered_at',q.registered_at,'status',q.status,'review_required',q.review_required,'reward_slot',q.reward_slot,
      'reward_coins',q.reward_coins,'base_rewarded',q.base_rewarded,'coin_purchase_rewarded',q.coin_purchase_rewarded,'premium_purchase_rewarded',q.premium_purchase_rewarded,'coin_purchase_reversed',q.coin_purchase_reversed,'premium_purchase_reversed',q.premium_purchase_reversed,'pending_recovery_coins',q.pending_recovery_coins
    ) order by q.registered_at desc),'[]'::jsonb)
  into v_activity
  from (
    select r.id,r.registered_at,r.status,r.review_required,r.reward_slot,
      coalesce(sum(rr.coins-case when rev.id is null then 0 else rev.coins_to_recover end),0) as reward_coins,
      bool_or(rr.reward_type='base_referral') as base_rewarded,
      bool_or(rr.reward_type='coin_purchase' and rev.id is null) as coin_purchase_rewarded,
      bool_or(rr.reward_type='premium_purchase' and rev.id is null) as premium_purchase_rewarded,
      bool_or(rr.reward_type='coin_purchase' and rev.id is not null) as coin_purchase_reversed,
      bool_or(rr.reward_type='premium_purchase' and rev.id is not null) as premium_purchase_reversed,
      coalesce(sum(rev.coins_to_recover-rev.coins_recovered),0) as pending_recovery_coins
    from public.referrals r
    left join public.referral_rewards rr on rr.referral_id=r.id
    left join public.referral_reward_reversals rev on rev.referral_reward_id=rr.id
    where r.referrer_user_id=v_uid
    group by r.id
    order by r.registered_at desc
    limit 50
  ) q;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'name',c.name,'description',c.description,'starts_at',c.starts_at,'ends_at',c.ends_at,
    'validation_deadline',c.validation_deadline,'status',c.status,
    'your_rank',(select x.rank_no from public.referral_contest_leaderboard_rows_v1(c.id) x where x.referrer_user_id=v_uid),
    'your_valid_referrals',(select x.valid_referrals from public.referral_contest_leaderboard_rows_v1(c.id) x where x.referrer_user_id=v_uid),
    'prizes',(select coalesce(jsonb_agg(jsonb_build_object('rank_from',p.rank_from,'rank_to',p.rank_to,'title',p.title,'coins',p.coins,'premium_days',p.premium_days,'badge_code',p.badge_code) order by p.rank_from),'[]'::jsonb) from public.referral_contest_prizes p where p.contest_id=c.id)
  ) order by c.starts_at desc),'[]'::jsonb)
  into v_contests
  from public.referral_contests c
  where c.status in ('active','validation','finalized') and c.ends_at >= now()-interval '30 days';
  return jsonb_build_object(
    'code',v_code,
    'is_admin',public.is_referral_admin_v1(v_uid),
    'stats',jsonb_build_object('total',v_total,'pending',v_pending,'active',v_active,'rewarded',v_rewarded,'coins',v_coins),
    'rules',jsonb_build_object('base_reward_coins',v_settings.base_reward_coins,'coin_purchase_reward_coins',v_settings.coin_purchase_reward_coins,'premium_purchase_reward_coins',v_settings.premium_purchase_reward_coins,'max_rewardable_referrals',v_settings.max_rewardable_referrals,'minimum_account_age_hours',v_settings.minimum_account_age_hours,'minimum_active_days',v_settings.minimum_active_days),
    'activity',v_activity,
    'contests',v_contests
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_referral_admin_dashboard_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_settings jsonb;
  v_summary jsonb;
  v_reviews jsonb;
  v_recent jsonb;
  v_contests jsonb;
begin
  if v_uid is null or not public.is_referral_admin_v1(v_uid) then raise exception 'Referral admin access required'; end if;
  select to_jsonb(s) into v_settings from public.referral_program_settings s where id=1;
  select jsonb_build_object(
    'total_referrals',count(*),
    'review_required',count(*) filter(where review_required),
    'active',count(*) filter(where status in ('active','rewarded')),
    'rejected',count(*) filter(where status in ('rejected','invalid')),
    'coins_paid',(select coalesce(sum(rr.coins-case when rev.id is null then 0 else rev.coins_to_recover end),0)
      from public.referral_rewards rr left join public.referral_reward_reversals rev on rev.referral_reward_id=rr.id),
    'refund_recovery_pending_coins',(select coalesce(sum(coins_to_recover-coins_recovered),0) from public.referral_reward_reversals)
  ) into v_summary from public.referrals;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'referrer_username',coalesce(pr.username,'Player'),'referred_username',coalesce(pd.username,'Pending account'),
    'status',r.status,'registered_at',r.registered_at,'review_reason',r.review_reason,'browser_hash_present',r.browser_hash is not null,
    'reward_slot',r.reward_slot,'admin_approved',r.admin_approved
  ) order by r.registered_at desc),'[]'::jsonb)
  into v_reviews
  from public.referrals r
  left join public.profiles pr on pr.id=r.referrer_user_id
  left join public.profiles pd on pd.id=r.referred_user_id
  where r.review_required
  limit 100;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'referrer_username',coalesce(pr.username,'Player'),'referred_username',coalesce(pd.username,'Pending account'),
    'status',r.status,'registered_at',r.registered_at,'activated_at',r.activated_at,'reward_slot',r.reward_slot,'review_required',r.review_required,
    'reward_coins',(select coalesce(sum(x.coins-case when rev.id is null then 0 else rev.coins_to_recover end),0)
      from public.referral_rewards x left join public.referral_reward_reversals rev on rev.referral_reward_id=x.id where x.referral_id=r.id),
    'reward_history',(select coalesce(jsonb_agg(jsonb_build_object(
      'reward_id',x.id,'reward_type',x.reward_type,'coins',x.coins,
      'billing_transaction_id',x.billing_transaction_id,
      'payment_status',b.status,'referrer_user_id',x.referrer_user_id,
      'referred_user_id',x.referred_user_id,
      'awarded_at',x.created_at,'reversed_at',rev.created_at,
      'coins_recovered',coalesce(rev.coins_recovered,0),
      'pending_recovery_coins',coalesce(rev.coins_to_recover-rev.coins_recovered,0),
      'reward_status',case when rev.id is null then 'awarded'
        when rev.coins_to_recover=rev.coins_recovered then 'reversed'
        else 'recovery_pending' end
      ) order by x.created_at),'[]'::jsonb)
      from public.referral_rewards x
      left join public.billing_transactions b on b.id=x.billing_transaction_id
      left join public.referral_reward_reversals rev on rev.referral_reward_id=x.id
      where x.referral_id=r.id)
  ) order by r.registered_at desc),'[]'::jsonb)
  into v_recent
  from public.referrals r
  left join public.profiles pr on pr.id=r.referrer_user_id
  left join public.profiles pd on pd.id=r.referred_user_id
  where r.registered_at >= now()-interval '90 days'
  limit 200;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'name',c.name,'description',c.description,'starts_at',c.starts_at,'ends_at',c.ends_at,'validation_deadline',c.validation_deadline,
    'status',c.status,'max_counted_referrals',c.max_counted_referrals,'finalized_at',c.finalized_at,
    'prizes',(select coalesce(jsonb_agg(to_jsonb(p)-'contest_id'-'created_at'-'id' order by p.rank_from),'[]'::jsonb) from public.referral_contest_prizes p where p.contest_id=c.id),
    'leaderboard',(select coalesce(jsonb_agg(jsonb_build_object('rank',x.rank_no,'username',coalesce(x.username,'Player'),'valid_referrals',x.valid_referrals,'reached_count_at',x.reached_count_at) order by x.rank_no),'[]'::jsonb) from public.referral_contest_leaderboard_rows_v1(c.id) x where x.rank_no<=20)
  ) order by c.created_at desc),'[]'::jsonb)
  into v_contests from public.referral_contests c;
  return jsonb_build_object('settings',v_settings,'summary',v_summary,'review_queue',v_reviews,'recent_referrals',v_recent,'contests',v_contests);
end;
$function$;

