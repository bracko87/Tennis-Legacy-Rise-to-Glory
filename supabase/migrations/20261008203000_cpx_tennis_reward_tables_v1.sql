-- Tennis Legacy CPX application 37031, independent from ProPeloton.
create table if not exists public.cpx_tennis_reward_transactions (
  trans_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_type text not null check (reward_type in ('complete','out','bonus')),
  amount_micro_usd bigint not null check (amount_micro_usd between 0 and 50000000),
  status smallint not null check (status in (1,2)),
  received_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists cpx_tennis_reward_tx_user_idx on public.cpx_tennis_reward_transactions(user_id,received_at desc);
create table if not exists public.cpx_tennis_reward_balances (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_micro_usd bigint not null default 0 check(active_micro_usd>=0),
  net_coins_applied integer not null default 0 check(net_coins_applied>=0),
  updated_at timestamptz not null default now()
);
alter table public.cpx_tennis_reward_transactions enable row level security;
alter table public.cpx_tennis_reward_balances enable row level security;
revoke all on public.cpx_tennis_reward_transactions from public, anon, authenticated;
revoke all on public.cpx_tennis_reward_balances from public, anon, authenticated;
grant select,insert,update on public.cpx_tennis_reward_transactions to service_role;
grant select,insert,update on public.cpx_tennis_reward_balances to service_role;
