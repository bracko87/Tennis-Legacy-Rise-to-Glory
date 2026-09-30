-- Tennis Legacy commerce repricing + Stripe production fulfillment
-- 2026-09-30
-- IMPORTANT: Stripe webhook signing secret is intentionally NOT stored in source control.

create table if not exists public.commerce_catalog_items (
  code text primary key,
  kind text not null check (kind in ('premium','coin_pack')),
  label text not null,
  coins integer not null default 0 check (coins >= 0),
  price_eur_cents integer not null check (price_eur_cents > 0),
  stripe_product_id text not null,
  stripe_price_id text not null,
  stripe_payment_link_id text not null,
  stripe_payment_link_url text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.commerce_catalog_items enable row level security;
drop policy if exists "Authenticated users can read commerce catalog" on public.commerce_catalog_items;
create policy "Authenticated users can read commerce catalog"
on public.commerce_catalog_items for select to authenticated using (is_active);

insert into public.commerce_catalog_items
(code,kind,label,coins,price_eur_cents,stripe_product_id,stripe_price_id,stripe_payment_link_id,stripe_payment_link_url,is_active,sort_order)
values
('premium_monthly','premium','Tennis Legacy Premium',30,329,'prod_VM0R9k60mkKmkf','price_1ULIQGRssJyCX9btqG7lkUM3','plink_1ULIVGRssJyCX9btnC9fb4Ql','https://buy.stripe.com/9B600l9g96vw1mX69c7EQ04',true,10),
('coin_70','coin_pack','70 Coins',70,299,'prod_VM0UmcJf9FAPq3','price_1ULITFRssJyCX9btTujAaUhg','plink_1ULIVJRssJyCX9btJDjs1csU','https://buy.stripe.com/8x24gB2RLg661mXdBE7EQ05',true,20),
('coin_130','coin_pack','130 Coins',130,499,'prod_VM0U62BepYDEpk','price_1ULITIRssJyCX9btAuacKVge','plink_1ULIVLRssJyCX9btyN2cThoo','https://buy.stripe.com/cNidRb8c54no2r10OS7EQ06',true,30),
('coin_270','coin_pack','270 Coins',270,999,'prod_VM0U2xVVz5R8VH','price_1ULITKRssJyCX9btZmEEOp1y','plink_1ULIVORssJyCX9btPqzF8XrO','https://buy.stripe.com/fZudRbfEx6vw0iT7dg7EQ07',true,40),
('coin_390','coin_pack','390 Coins',390,1399,'prod_VM0UKNE7CsR5ql','price_1ULITMRssJyCX9bttBpoZWYX','plink_1ULIVQRssJyCX9btr0bszbLr','https://buy.stripe.com/8x228t3VPcTU3v52X07EQ08',true,50),
('coin_570','coin_pack','570 Coins',570,1999,'prod_VM0UFqG1lJOntk','price_1ULITPRssJyCX9btPN42xOOk','plink_1ULIVSRssJyCX9btkLEHe8wZ','https://buy.stripe.com/9B6eVf0JD1bc5Dd8hk7EQ09',true,60),
('coin_900','coin_pack','900 Coins',900,2999,'prod_VM0UwxS1mDqN5M','price_1ULITSRssJyCX9bt50ZmQPFK','plink_1ULIVVRssJyCX9btTs3QH84m','https://buy.stripe.com/8x2bJ30JD2fg0iTgNQ7EQ0a',true,70)
on conflict(code) do update set
  kind=excluded.kind,label=excluded.label,coins=excluded.coins,price_eur_cents=excluded.price_eur_cents,
  stripe_product_id=excluded.stripe_product_id,stripe_price_id=excluded.stripe_price_id,
  stripe_payment_link_id=excluded.stripe_payment_link_id,stripe_payment_link_url=excluded.stripe_payment_link_url,
  is_active=excluded.is_active,sort_order=excluded.sort_order,updated_at=now();

create table if not exists public.commerce_runtime_settings (
  id boolean primary key default true check(id),
  stripe_customer_portal_url text,
  premium_monthly_price_eur_cents integer not null default 329,
  premium_monthly_coin_reward integer not null default 30,
  updated_at timestamptz not null default now()
);

insert into public.commerce_runtime_settings(
  id,stripe_customer_portal_url,premium_monthly_price_eur_cents,premium_monthly_coin_reward
)
values(
  true,
  'https://billing.stripe.com/p/login/00w14pfExcTU2r14147EQ00',
  329,
  30
)
on conflict(id) do update set
  stripe_customer_portal_url=excluded.stripe_customer_portal_url,
  premium_monthly_price_eur_cents=329,
  premium_monthly_coin_reward=30,
  updated_at=now();

alter table public.commerce_runtime_settings enable row level security;
drop policy if exists "Authenticated users can read commerce settings" on public.commerce_runtime_settings;
create policy "Authenticated users can read commerce settings"
on public.commerce_runtime_settings for select to authenticated using (true);

update public.tennis_club_settings
set creation_cost_coins=50,updated_at=now()
where id=1;

update public.premium_memberships
set monthly_price_eur_cents=329,
    monthly_coin_reward=30,
    updated_at=now()
where plan_code='premium';

alter table public.billing_transactions
  add column if not exists stripe_checkout_session_id text,
  add column if not exists stripe_invoice_id text,
  add column if not exists stripe_payment_intent_id text,
  add column if not exists stripe_subscription_id text,
  add column if not exists stripe_customer_id text,
  add column if not exists catalog_code text;

create unique index if not exists billing_transactions_checkout_session_uidx
  on public.billing_transactions(stripe_checkout_session_id)
  where stripe_checkout_session_id is not null;

create unique index if not exists billing_transactions_invoice_uidx
  on public.billing_transactions(stripe_invoice_id)
  where stripe_invoice_id is not null;

create table if not exists public.stripe_webhook_events (
  event_id text primary key,
  event_type text not null,
  payload jsonb not null,
  processed boolean not null default false,
  process_note text,
  received_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.stripe_webhook_events enable row level security;
revoke all on public.stripe_webhook_events from anon,authenticated;

create table if not exists public.stripe_webhook_private_config (
  id boolean primary key default true check(id),
  signing_secret text,
  stripe_account_id text not null default 'acct_1T7uOkRssJyCX9bt',
  updated_at timestamptz not null default now()
);

insert into public.stripe_webhook_private_config(id,stripe_account_id)
values(true,'acct_1T7uOkRssJyCX9bt')
on conflict(id) do update
set stripe_account_id=excluded.stripe_account_id,updated_at=now();

alter table public.stripe_webhook_private_config enable row level security;
revoke all on public.stripe_webhook_private_config from anon,authenticated;

create table if not exists public.commerce_checkout_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  catalog_code text not null references public.commerce_catalog_items(code),
  status text not null default 'open' check (status in ('open','completed','expired','canceled')),
  stripe_checkout_session_id text unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 hours'),
  completed_at timestamptz
);

create index if not exists commerce_checkout_intents_user_created_idx
  on public.commerce_checkout_intents(user_id,created_at desc);

alter table public.commerce_checkout_intents enable row level security;
revoke all on public.commerce_checkout_intents from anon,authenticated;

create or replace function public.get_commerce_catalog_v1()
returns table(
  code text,
  kind text,
  label text,
  coins integer,
  price_eur_cents integer,
  stripe_payment_link_url text,
  sort_order integer
)
language sql
stable
security definer
set search_path='public','pg_temp'
as $function$
  select c.code,c.kind,c.label,c.coins,c.price_eur_cents,c.stripe_payment_link_url,c.sort_order
  from public.commerce_catalog_items c
  where c.is_active
  order by c.sort_order;
$function$;

grant execute on function public.get_commerce_catalog_v1() to authenticated;

create or replace function public.create_commerce_checkout_intent_v1(p_catalog_code text)
returns jsonb
language plpgsql
security definer
set search_path='public','auth','pg_temp'
as $function$
declare
  v_user uuid:=auth.uid();
  v_item public.commerce_catalog_items%rowtype;
  v_intent uuid;
  v_email text;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;

  select * into v_item
  from public.commerce_catalog_items
  where code=p_catalog_code and is_active;

  if v_item.code is null then raise exception 'Commerce item is unavailable.'; end if;

  if v_item.kind='premium'
     and exists(
       select 1 from public.premium_memberships
       where user_id=v_user
         and plan_code='premium'
         and status='active'
         and (current_period_end is null or current_period_end>now())
     )
  then
    return jsonb_build_object(
      'status','already_premium',
      'catalog_code',v_item.code,
      'portal_url',(select stripe_customer_portal_url from public.commerce_runtime_settings where id=true)
    );
  end if;

  update public.commerce_checkout_intents
  set status='expired'
  where user_id=v_user and status='open' and expires_at<=now();

  insert into public.commerce_checkout_intents(user_id,catalog_code)
  values(v_user,v_item.code)
  returning id into v_intent;

  select email into v_email from auth.users where id=v_user;

  return jsonb_build_object(
    'status','ready',
    'intent_id',v_intent,
    'catalog_code',v_item.code,
    'payment_link_url',v_item.stripe_payment_link_url,
    'prefilled_email',v_email,
    'expires_at',now()+interval '2 hours'
  );
end;
$function$;

revoke all on function public.create_commerce_checkout_intent_v1(text) from public,anon;
grant execute on function public.create_commerce_checkout_intent_v1(text) to authenticated;

-- Webhook processing functions are deployed in production and intentionally use
-- server-verified Stripe events only. Keep their current definitions synchronized
-- from the live database when altering fulfillment logic.
--
-- Edge Function source:
-- supabase/functions/stripe-tennis-webhook/index.ts
--
-- The signing secret must be populated out-of-band in:
-- public.stripe_webhook_private_config.signing_secret
-- and must never be committed to source control.

do $$
declare v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='create_tennis_club_v1' limit 1;
  if v_def is not null then
    v_def:=replace(v_def,'coalesce(v_cost,100)','coalesce(v_cost,50)');
    execute v_def;
  end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='get_tennis_club_dashboard_v1' limit 1;
  if v_def is not null then
    v_def:=replace(v_def,'coalesce(v_cost,100)','coalesce(v_cost,50)');
    execute v_def;
  end if;
end $$;
