create table if not exists public.user_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coins_balance bigint not null default 0 check (coins_balance >= 0),
  lifetime_coins_earned bigint not null default 0 check (lifetime_coins_earned >= 0),
  lifetime_coins_spent bigint not null default 0 check (lifetime_coins_spent >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.premium_memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan_code text not null default 'free' check (plan_code in ('free','premium')),
  status text not null default 'active' check (status in ('active','past_due','canceled','incomplete')),
  started_at timestamptz not null default now(),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  monthly_price_eur_cents integer not null default 0 check (monthly_price_eur_cents >= 0),
  monthly_coin_reward integer not null default 0 check (monthly_coin_reward >= 0),
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coin_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check (amount <> 0),
  balance_after bigint not null check (balance_after >= 0),
  entry_type text not null check (entry_type in ('premium_reward','coin_purchase','spend','admin_adjustment','signup_reward','refund','promo')),
  description text,
  reference_id text,
  created_at timestamptz not null default now()
);

create index if not exists coin_ledger_user_created_idx
  on public.coin_ledger(user_id, created_at desc);

create table if not exists public.billing_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('premium_invoice','coin_pack_purchase','refund')),
  status text not null default 'pending' check (status in ('pending','paid','failed','refunded','canceled')),
  amount_eur_cents integer not null default 0 check (amount_eur_cents >= 0),
  coins_amount integer not null default 0 check (coins_amount >= 0),
  description text,
  created_at timestamptz not null default now()
);

create index if not exists billing_transactions_user_created_idx
  on public.billing_transactions(user_id, created_at desc);

alter table public.user_wallets enable row level security;
alter table public.premium_memberships enable row level security;
alter table public.coin_ledger enable row level security;
alter table public.billing_transactions enable row level security;
