-- Fix Stripe subscription period data with API 2025+ item-level dates.
-- Legacy root-level period fields still supported. No plan, charges, coins,
-- or membership statuses changed by this migration.
CREATE OR REPLACE FUNCTION public.try_process_tennis_stripe_event_v2(p_event_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Ignore only demonstrably external subscriptions; never infer ownership
  -- from amount alone. Genuine Tennis events still wait for account mapping.
  if v_event.event_type in (
    'invoice.paid',
    'customer.subscription.created',
    'customer.subscription.updated',
    'customer.subscription.deleted'
  ) then
    v_subscription:=case when v_event.event_type like 'customer.subscription.%'
      then v_obj->>'id'
      else coalesce(v_obj->>'subscription',
                    v_obj#>>'{parent,subscription_details,subscription}')
    end;
    v_price_id:=coalesce(
      v_obj#>>'{lines,data,0,pricing,price_details,price}',
      v_obj#>>'{lines,data,0,price,id}',
      v_obj#>>'{lines,data,0,plan,id}',
      v_obj#>>'{items,data,0,price,id}',
      v_obj#>>'{items,data,0,plan,id}'
    );
    if v_subscription is not null
       and v_price_id is not null
       and coalesce(v_obj#>>'{metadata,game}','') <> 'tennis_legacy'
       and not exists(
         select 1 from public.commerce_catalog_items c
         where c.stripe_price_id=v_price_id
       )
       and not exists(
         select 1 from public.premium_memberships pm
         where pm.stripe_subscription_id=v_subscription
            or pm.stripe_customer_id=v_obj->>'customer'
       )
       and exists(
         select 1 from public.stripe_webhook_events source
         where source.event_type in (
           'customer.subscription.created','customer.subscription.updated'
         )
           and source.payload#>>'{data,object,id}'=v_subscription
           and coalesce(source.payload#>>'{data,object,metadata,game}','') <> 'tennis_legacy'
           and nullif(source.payload#>>'{data,object,metadata,user_id}','') is not null
           and coalesce(
             source.payload#>>'{data,object,items,data,0,price,id}',
             source.payload#>>'{data,object,items,data,0,plan,id}'
           )=v_price_id
           and not exists(
             select 1 from auth.users u
             where u.id::text=source.payload#>>'{data,object,metadata,user_id}'
           )
       )
    then
      update public.stripe_webhook_events
      set processed=true,processed_at=now(),
          process_note='ignored_external_subscription'
      where event_id=p_event_id;
      return true;
    end if;
  end if;


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
    where stripe_subscription_id=v_subscription
       or (stripe_subscription_id is null and stripe_customer_id=v_customer)
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
      v_period_start:=to_timestamp(coalesce(
        nullif(v_obj->>'current_period_start',''),
        nullif(v_obj#>>'{items,data,0,current_period_start}','')
      )::double precision);
    exception when others then
      v_period_start:=null;
    end;

    begin
      v_period_end:=to_timestamp(coalesce(
        nullif(v_obj->>'current_period_end',''),
        nullif(v_obj#>>'{items,data,0,current_period_end}','')
      )::double precision);
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
    where stripe_subscription_id=v_subscription
       or (v_subscription is null and stripe_customer_id=v_customer and plan_code='premium');

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
$function$
;