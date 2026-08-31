drop policy if exists "Users can read own wallet" on public.user_wallets;
create policy "Users can read own wallet"
  on public.user_wallets for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read own membership" on public.premium_memberships;
create policy "Users can read own membership"
  on public.premium_memberships for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read own coin ledger" on public.coin_ledger;
create policy "Users can read own coin ledger"
  on public.coin_ledger for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can read own billing history" on public.billing_transactions;
create policy "Users can read own billing history"
  on public.billing_transactions for select
  to authenticated
  using (auth.uid() = user_id);

insert into public.user_wallets (user_id)
select id from auth.users
on conflict (user_id) do nothing;

insert into public.premium_memberships (user_id)
select id from auth.users
on conflict (user_id) do nothing;
