-- Tennis Legacy Premium billing plans: monthly, 3-month and annual.
-- Existing monthly subscribers remain on premium_monthly.
-- Coin rewards preserve the existing 30-coins-per-month value:
-- monthly 30, quarterly 90, annual 360 per successful billing payment.

alter table public.premium_memberships
  add column if not exists billing_plan_code text,
  add column if not exists billing_period_months integer,
  add column if not exists billing_amount_eur_cents integer,
  add column if not exists coins_per_payment integer,
  add column if not exists stripe_price_id text;

update public.premium_memberships
set
  billing_plan_code = case when plan_code='premium' then coalesce(billing_plan_code,'premium_monthly') else billing_plan_code end,
  billing_period_months = case when plan_code='premium' then coalesce(billing_period_months,1) else billing_period_months end,
  billing_amount_eur_cents = case when plan_code='premium' then coalesce(billing_amount_eur_cents,nullif(monthly_price_eur_cents,0),329) else billing_amount_eur_cents end,
  coins_per_payment = case when plan_code='premium' then coalesce(coins_per_payment,nullif(monthly_coin_reward,0),30) else coins_per_payment end,
  stripe_price_id = case when plan_code='premium' then coalesce(stripe_price_id,'price_1ULIQGRssJyCX9btqG7lkUM3') else stripe_price_id end
where plan_code='premium';

insert into public.commerce_catalog_items(
  code,kind,label,coins,price_eur_cents,
  stripe_product_id,stripe_price_id,stripe_payment_link_id,stripe_payment_link_url,
  is_active,sort_order,updated_at
)
values
(
  'premium_quarterly','premium','Tennis Legacy Premium · 3 Months',90,949,
  'prod_VM0R9k60mkKmkf','price_1UOBH1RssJyCX9bthTt447Lj',
  'plink_1UOBHKRssJyCX9bt4iiyWTg8','https://buy.stripe.com/8x29AVcsl7zAd5FcxA7EQ0b',
  true,8,now()
),
(
  'premium_yearly','premium','Tennis Legacy Premium · 12 Months',360,3349,
  'prod_VM0R9k60mkKmkf','price_1UOBHARssJyCX9btLPGaIl9Y',
  'plink_1UOBHMRssJyCX9btw9T22KPJ','https://buy.stripe.com/3cI14pakd1bc1mXfJM7EQ0c',
  true,9,now()
)
on conflict(code) do update set
  kind=excluded.kind,
  label=excluded.label,
  coins=excluded.coins,
  price_eur_cents=excluded.price_eur_cents,
  stripe_product_id=excluded.stripe_product_id,
  stripe_price_id=excluded.stripe_price_id,
  stripe_payment_link_id=excluded.stripe_payment_link_id,
  stripe_payment_link_url=excluded.stripe_payment_link_url,
  is_active=true,
  sort_order=excluded.sort_order,
  updated_at=now();

update public.commerce_catalog_items
set sort_order=10, updated_at=now()
where code='premium_monthly';

create or replace function public.try_process_tennis_stripe_event_v2(p_event_id text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_event record;
  v_obj jsonb;
  v_user uuid;
  v_intent uuid;
  v_intent_status text;
  v_kind text;
  v_meta_kind text;
  v_coins integer;
  v_meta_coins integer;
  v_expected integer;
  v_amount integer;
  v_balance bigint;
  v_subscription text;
  v_customer text;
  v_invoice text;
  v_session text;
  v_catalog text;
  v_status text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_price_id text;
  v_period_months integer:=1;
  v_monthly_equivalent integer:=329;
  v_monthly_reward integer:=30;
begin
  select * into v_event
  from public.stripe_webhook_events
  where event_id=p_event_id
  for update;

  if not found or v_event.processed then return true; end if;
  v_obj:=v_event.payload->'data'->'object';

  if v_event.event_type in ('checkout.session.completed','checkout.session.async_payment_succeeded') then
    if coalesce(v_obj->'metadata'->>'game','')<>'tennis_legacy' then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='ignored_non_tennis'
      where event_id=p_event_id;
      return true;
    end if;

    begin
      v_intent:=(v_obj->>'client_reference_id')::uuid;
    exception when others then
      v_intent:=null;
    end;

    if v_intent is null then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='invalid_checkout_intent_reference'
      where event_id=p_event_id;
      return true;
    end if;

    select user_id,catalog_code,status
    into v_user,v_catalog,v_intent_status
    from public.commerce_checkout_intents
    where id=v_intent
    for update;

    if v_user is null then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='unknown_checkout_intent'
      where event_id=p_event_id;
      return true;
    end if;

    v_session:=v_obj->>'id';
    v_customer:=v_obj->>'customer';
    v_subscription:=v_obj->>'subscription';
    v_meta_kind:=v_obj->'metadata'->>'kind';

    if v_intent_status='completed' then
      if exists(
        select 1 from public.commerce_checkout_intents
        where id=v_intent and stripe_checkout_session_id=v_session
      ) then
        update public.stripe_webhook_events
        set processed=true,processed_at=now(),process_note='already_fulfilled'
        where event_id=p_event_id;
        return true;
      end if;

      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='checkout_intent_already_used'
      where event_id=p_event_id;
      return true;
    end if;

    select kind,coins,price_eur_cents,stripe_price_id
    into v_kind,v_coins,v_expected,v_price_id
    from public.commerce_catalog_items
    where code=v_catalog and is_active;

    if v_kind is null then
      raise exception 'Inactive or missing commerce catalog item for Stripe event %',p_event_id;
    end if;

    v_amount:=coalesce((v_obj->>'amount_total')::integer,0);
    begin
      v_meta_coins:=coalesce((v_obj->'metadata'->>'coins')::integer,0);
    exception when others then
      v_meta_coins:=0;
    end;

    if v_kind='coin_pack' then
      if v_meta_kind<>'coin_pack'
         or v_meta_coins<>v_coins
         or v_amount<>v_expected
      then
        raise exception 'Stripe coin pack validation failed for event %',p_event_id;
      end if;

      if coalesce(v_obj->>'payment_status','')<>'paid' then
        update public.stripe_webhook_events
        set processed=true,processed_at=now(),process_note='awaiting_async_payment_succeeded'
        where event_id=p_event_id;
        return true;
      end if;

      if exists(select 1 from public.billing_transactions where stripe_checkout_session_id=v_session) then
        update public.commerce_checkout_intents
        set status='completed',stripe_checkout_session_id=v_session,completed_at=coalesce(completed_at,now())
        where id=v_intent;
        update public.stripe_webhook_events
        set processed=true,processed_at=now(),process_note='already_fulfilled'
        where event_id=p_event_id;
        return true;
      end if;

      insert into public.user_wallets(user_id)
      values(v_user)
      on conflict(user_id) do nothing;

      update public.user_wallets
      set coins_balance=coins_balance+v_coins,
          lifetime_coins_earned=lifetime_coins_earned+v_coins,
          updated_at=now()
      where user_id=v_user
      returning coins_balance into v_balance;

      insert into public.coin_ledger(
        user_id,amount,balance_after,entry_type,description,reference_id
      )
      values(
        v_user,v_coins,v_balance,'coin_purchase',v_coins||' Coin Pack','stripe_session:'||v_session
      );

      insert into public.billing_transactions(
        user_id,kind,status,amount_eur_cents,coins_amount,description,
        stripe_checkout_session_id,stripe_payment_intent_id,stripe_customer_id,catalog_code
      )
      values(
        v_user,'coin_pack_purchase','paid',v_amount,v_coins,v_coins||' Coin Pack',
        v_session,v_obj->>'payment_intent',v_customer,v_catalog
      );

      update public.commerce_checkout_intents
      set status='completed',stripe_checkout_session_id=v_session,completed_at=now()
      where id=v_intent;

    elsif v_kind='premium' then
      if v_meta_kind<>'premium'
         or v_catalog not in ('premium_monthly','premium_quarterly','premium_yearly')
         or v_amount<>v_expected
      then
        raise exception 'Stripe Premium validation failed for event %',p_event_id;
      end if;

      v_period_months:=case v_catalog
        when 'premium_quarterly' then 3
        when 'premium_yearly' then 12
        else 1
      end;
      v_monthly_equivalent:=round(v_expected::numeric/v_period_months)::integer;

      insert into public.premium_memberships(
        user_id,plan_code,status,started_at,monthly_price_eur_cents,monthly_coin_reward,
        stripe_customer_id,stripe_subscription_id,billing_plan_code,billing_period_months,
        billing_amount_eur_cents,coins_per_payment,stripe_price_id
      )
      values(
        v_user,'premium','active',now(),v_monthly_equivalent,30,
        v_customer,v_subscription,v_catalog,v_period_months,v_expected,v_coins,v_price_id
      )
      on conflict(user_id) do update set
        plan_code='premium',
        status='active',
        monthly_price_eur_cents=v_monthly_equivalent,
        monthly_coin_reward=30,
        stripe_customer_id=coalesce(excluded.stripe_customer_id,premium_memberships.stripe_customer_id),
        stripe_subscription_id=coalesce(excluded.stripe_subscription_id,premium_memberships.stripe_subscription_id),
        billing_plan_code=v_catalog,
        billing_period_months=v_period_months,
        billing_amount_eur_cents=v_expected,
        coins_per_payment=v_coins,
        stripe_price_id=v_price_id,
        cancel_at_period_end=false,
        updated_at=now();

      update public.commerce_checkout_intents
      set status='completed',stripe_checkout_session_id=v_session,completed_at=now()
      where id=v_intent;
    end if;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  if v_event.event_type='invoice.paid' then
    v_invoice:=v_obj->>'id';
    v_customer:=v_obj->>'customer';
    v_subscription:=coalesce(
      v_obj->>'subscription',
      v_obj#>>'{parent,subscription_details,subscription}'
    );

    select user_id into v_user
    from public.premium_memberships
    where stripe_subscription_id=v_subscription
       or (v_subscription is null and stripe_customer_id=v_customer and plan_code='premium')
    limit 1;

    if v_user is null then
      update public.stripe_webhook_events
      set process_note='waiting_for_subscription_mapping'
      where event_id=p_event_id;
      return false;
    end if;

    v_price_id:=coalesce(
      v_obj#>>'{lines,data,0,pricing,price_details,price}',
      v_obj#>>'{lines,data,0,price,id}',
      v_obj#>>'{lines,data,0,plan,id}'
    );

    select code,coins,price_eur_cents
    into v_catalog,v_coins,v_expected
    from public.commerce_catalog_items
    where kind='premium'
      and is_active
      and stripe_price_id=v_price_id
    limit 1;

    if v_catalog is null then
      select billing_plan_code,coins_per_payment,billing_amount_eur_cents,stripe_price_id
      into v_catalog,v_coins,v_expected,v_price_id
      from public.premium_memberships
      where user_id=v_user;
    end if;

    if v_catalog not in ('premium_monthly','premium_quarterly','premium_yearly') then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='ignored_unknown_premium_invoice'
      where event_id=p_event_id;
      return true;
    end if;

    v_amount:=coalesce((v_obj->>'amount_paid')::integer,0);

    if v_amount<>v_expected then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='ignored_non_current_premium_invoice'
      where event_id=p_event_id;
      return true;
    end if;

    if exists(select 1 from public.billing_transactions where stripe_invoice_id=v_invoice) then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),process_note='already_fulfilled'
      where event_id=p_event_id;
      return true;
    end if;

    v_period_months:=case v_catalog
      when 'premium_quarterly' then 3
      when 'premium_yearly' then 12
      else 1
    end;
    v_monthly_equivalent:=round(v_expected::numeric/v_period_months)::integer;
    v_coins:=coalesce(v_coins,30*v_period_months);

    insert into public.user_wallets(user_id)
    values(v_user)
    on conflict(user_id) do nothing;

    update public.user_wallets
    set coins_balance=coins_balance+v_coins,
        lifetime_coins_earned=lifetime_coins_earned+v_coins,
        updated_at=now()
    where user_id=v_user
    returning coins_balance into v_balance;

    insert into public.coin_ledger(
      user_id,amount,balance_after,entry_type,description,reference_id
    )
    values(
      v_user,v_coins,v_balance,'premium_reward',
      case
        when v_period_months=12 then 'Annual Premium coin reward'
        when v_period_months=3 then '3-month Premium coin reward'
        else 'Monthly Premium coin reward'
      end,
      'stripe_invoice:'||v_invoice
    );

    insert into public.billing_transactions(
      user_id,kind,status,amount_eur_cents,coins_amount,description,
      stripe_invoice_id,stripe_subscription_id,stripe_customer_id,catalog_code
    )
    values(
      v_user,'premium_invoice','paid',v_amount,v_coins,
      case
        when v_period_months=12 then 'Tennis Legacy Premium · 12 Months'
        when v_period_months=3 then 'Tennis Legacy Premium · 3 Months'
        else 'Tennis Legacy Premium · Monthly'
      end,
      v_invoice,v_subscription,v_customer,v_catalog
    );

    update public.premium_memberships
    set plan_code='premium',
        status='active',
        monthly_price_eur_cents=v_monthly_equivalent,
        monthly_coin_reward=30,
        billing_plan_code=v_catalog,
        billing_period_months=v_period_months,
        billing_amount_eur_cents=v_expected,
        coins_per_payment=v_coins,
        stripe_price_id=v_price_id,
        updated_at=now()
    where user_id=v_user;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  if v_event.event_type in (
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted'
  ) then
    v_subscription:=v_obj->>'id';
    v_customer:=v_obj->>'customer';

    select user_id into v_user
    from public.premium_memberships
    where stripe_subscription_id=v_subscription or stripe_customer_id=v_customer
    limit 1;

    if v_user is null then
      update public.stripe_webhook_events
      set process_note='waiting_for_subscription_mapping'
      where event_id=p_event_id;
      return false;
    end if;

    v_status:=case
      when v_event.event_type='customer.subscription.deleted' then 'canceled'
      when coalesce(v_obj->>'status','') in ('active','trialing') then 'active'
      when coalesce(v_obj->>'status','') in ('past_due','unpaid') then 'past_due'
      else 'incomplete'
    end;

    begin
      v_period_start:=to_timestamp((v_obj->>'current_period_start')::double precision);
    exception when others then
      v_period_start:=null;
    end;

    begin
      v_period_end:=to_timestamp((v_obj->>'current_period_end')::double precision);
    exception when others then
      v_period_end:=null;
    end;

    v_price_id:=coalesce(
      v_obj#>>'{items,data,0,price,id}',
      v_obj#>>'{items,data,0,plan,id}',
      v_obj#>>'{items,data,0,pricing,price_details,price}'
    );

    select code,coins,price_eur_cents
    into v_catalog,v_coins,v_expected
    from public.commerce_catalog_items
    where kind='premium' and is_active and stripe_price_id=v_price_id
    limit 1;

    if v_catalog is null then
      select billing_plan_code,coins_per_payment,billing_amount_eur_cents
      into v_catalog,v_coins,v_expected
      from public.premium_memberships
      where user_id=v_user;
    end if;

    v_period_months:=case v_catalog
      when 'premium_quarterly' then 3
      when 'premium_yearly' then 12
      else 1
    end;
    v_expected:=coalesce(v_expected,329);
    v_coins:=coalesce(v_coins,30*v_period_months);
    v_monthly_equivalent:=round(v_expected::numeric/v_period_months)::integer;

    update public.premium_memberships
    set plan_code=case when v_status='canceled' then 'free' else 'premium' end,
        status=v_status,
        current_period_start=coalesce(v_period_start,current_period_start),
        current_period_end=coalesce(v_period_end,current_period_end),
        cancel_at_period_end=coalesce((v_obj->>'cancel_at_period_end')::boolean,false),
        stripe_customer_id=coalesce(v_customer,stripe_customer_id),
        stripe_subscription_id=coalesce(v_subscription,stripe_subscription_id),
        monthly_price_eur_cents=v_monthly_equivalent,
        monthly_coin_reward=30,
        billing_plan_code=coalesce(v_catalog,billing_plan_code,'premium_monthly'),
        billing_period_months=v_period_months,
        billing_amount_eur_cents=v_expected,
        coins_per_payment=v_coins,
        stripe_price_id=coalesce(v_price_id,stripe_price_id),
        updated_at=now()
    where user_id=v_user;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  if v_event.event_type='invoice.payment_failed' then
    v_customer:=v_obj->>'customer';
    v_subscription:=coalesce(
      v_obj->>'subscription',
      v_obj#>>'{parent,subscription_details,subscription}'
    );

    update public.premium_memberships
    set status='past_due',updated_at=now()
    where stripe_subscription_id=v_subscription or stripe_customer_id=v_customer;

    update public.stripe_webhook_events
    set processed=true,processed_at=now(),process_note='processed'
    where event_id=p_event_id;
    return true;
  end if;

  update public.stripe_webhook_events
  set processed=true,processed_at=now(),process_note='ignored_event_type'
  where event_id=p_event_id;
  return true;

exception when unique_violation then
  update public.stripe_webhook_events
  set processed=true,processed_at=now(),process_note='idempotent_duplicate'
  where event_id=p_event_id;
  return true;
end;
$function$;

revoke all on function public.try_process_tennis_stripe_event_v2(text) from public;
revoke all on function public.try_process_tennis_stripe_event_v2(text) from anon;
revoke all on function public.try_process_tennis_stripe_event_v2(text) from authenticated;

create or replace function public.process_tennis_stripe_webhook_v1(p_event jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  for r in
    select event_id from public.stripe_webhook_events
    where not processed
    order by received_at
    limit 100
  loop
    if public.try_process_tennis_stripe_event_v2(r.event_id) then
      v_done:=v_done+1;
    else
      v_pending:=v_pending+1;
    end if;
  end loop;

  return jsonb_build_object('event_id',v_id,'processed_now',v_done,'pending',v_pending);
end;
$function$;
