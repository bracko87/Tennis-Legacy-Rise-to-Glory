alter table public.coin_ledger drop constraint if exists coin_ledger_entry_type_check;
alter table public.coin_ledger add constraint coin_ledger_entry_type_check check (entry_type = any (array['premium_reward'::text,'coin_purchase'::text,'spend'::text,'admin_adjustment'::text,'signup_reward'::text,'refund'::text,'promo'::text,'referral_reward'::text]));

create table if not exists public.referral_program_settings (
  id smallint primary key default 1 check (id = 1),
  base_reward_coins integer not null default 3 check (base_reward_coins >= 0),
  coin_purchase_reward_coins integer not null default 15 check (coin_purchase_reward_coins >= 0),
  premium_purchase_reward_coins integer not null default 30 check (premium_purchase_reward_coins >= 0),
  max_rewardable_referrals integer not null default 10 check (max_rewardable_referrals between 1 and 100),
  minimum_account_age_hours integer not null default 72 check (minimum_account_age_hours >= 0),
  minimum_active_days integer not null default 2 check (minimum_active_days >= 1),
  updated_at timestamptz not null default now()
);
insert into public.referral_program_settings(id,base_reward_coins,coin_purchase_reward_coins,premium_purchase_reward_coins,max_rewardable_referrals,minimum_account_age_hours,minimum_active_days)
values (1,3,15,30,10,72,2)
on conflict (id) do update set
  base_reward_coins=excluded.base_reward_coins,
  coin_purchase_reward_coins=excluded.coin_purchase_reward_coins,
  premium_purchase_reward_coins=excluded.premium_purchase_reward_coins,
  max_rewardable_referrals=excluded.max_rewardable_referrals,
  minimum_account_age_hours=excluded.minimum_account_age_hours,
  minimum_active_days=excluded.minimum_active_days,
  updated_at=now();

create table if not exists public.referral_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text not null unique,
  created_at timestamptz not null default now(),
  revoked_at timestamptz null,
  check (code ~ '^[A-Z0-9]{8,16}$')
);

create table if not exists public.referral_clicks (
  id uuid primary key default gen_random_uuid(),
  referral_code text not null,
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  browser_hash text null,
  clicked_at timestamptz not null default now()
);
create index if not exists referral_clicks_referrer_time_idx on public.referral_clicks(referrer_user_id, clicked_at desc);
create index if not exists referral_clicks_browser_idx on public.referral_clicks(browser_hash) where browser_hash is not null;

create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referred_user_id uuid not null unique references auth.users(id) on delete cascade,
  referral_code text not null,
  browser_hash text null,
  status text not null default 'registered' check (status in ('registered','pending_activation','active','rewarded','rejected','invalid')),
  registered_at timestamptz not null default now(),
  email_verified_at timestamptz null,
  career_created_at timestamptz null,
  activated_at timestamptz null,
  reward_slot integer null check (reward_slot between 1 and 10),
  review_required boolean not null default false,
  review_reason text null,
  rejected_at timestamptz null,
  rejection_reason text null,
  updated_at timestamptz not null default now(),
  check (referrer_user_id <> referred_user_id)
);
create index if not exists referrals_referrer_idx on public.referrals(referrer_user_id, registered_at desc);
create unique index if not exists referrals_reward_slot_unique on public.referrals(referrer_user_id,reward_slot) where reward_slot is not null;

create table if not exists public.referral_activity_days (
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_date date not null,
  first_seen_at timestamptz not null default now(),
  primary key(user_id,activity_date)
);

create table if not exists public.referral_user_devices (
  user_id uuid not null references auth.users(id) on delete cascade,
  browser_hash text not null,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key(user_id,browser_hash)
);
create index if not exists referral_user_devices_hash_idx on public.referral_user_devices(browser_hash);

create table if not exists public.referral_rewards (
  id uuid primary key default gen_random_uuid(),
  referral_id uuid not null references public.referrals(id) on delete cascade,
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referred_user_id uuid not null references auth.users(id) on delete cascade,
  reward_type text not null check (reward_type in ('base_referral','coin_purchase','premium_purchase','manual_adjustment','contest')),
  coins integer not null check (coins <> 0),
  billing_transaction_id uuid null references public.billing_transactions(id) on delete set null,
  reference_key text not null unique,
  created_at timestamptz not null default now(),
  unique(referral_id,reward_type)
);
create index if not exists referral_rewards_referrer_idx on public.referral_rewards(referrer_user_id, created_at desc);

alter table public.referral_program_settings enable row level security;
alter table public.referral_codes enable row level security;
alter table public.referral_clicks enable row level security;
alter table public.referrals enable row level security;
alter table public.referral_activity_days enable row level security;
alter table public.referral_user_devices enable row level security;
alter table public.referral_rewards enable row level security;
revoke all on public.referral_program_settings, public.referral_codes, public.referral_clicks, public.referrals, public.referral_activity_days, public.referral_user_devices, public.referral_rewards from anon, authenticated;

create or replace function public.ensure_referral_code_v1(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_code text;
begin
  select code into v_code from public.referral_codes where user_id=p_user_id and revoked_at is null;
  if v_code is not null then return v_code; end if;
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
    begin
      insert into public.referral_codes(user_id,code) values(p_user_id,v_code)
      on conflict (user_id) do update set revoked_at=null
      returning code into v_code;
      return v_code;
    exception when unique_violation then
      null;
    end;
  end loop;
end;
$$;
revoke all on function public.ensure_referral_code_v1(uuid) from public,anon,authenticated;

insert into public.referral_codes(user_id,code)
select p.id, upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))
from public.profiles p
left join public.referral_codes rc on rc.user_id=p.id
where rc.user_id is null
on conflict do nothing;

create or replace function public.trg_ensure_referral_code_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  perform public.ensure_referral_code_v1(new.id);
  return new;
end;
$$;
drop trigger if exists ensure_referral_code_v1 on public.profiles;
create trigger ensure_referral_code_v1 after insert on public.profiles for each row execute function public.trg_ensure_referral_code_v1();

create or replace function public.handle_referral_signup_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_code text;
  v_referrer uuid;
  v_browser text;
begin
  v_code := upper(btrim(coalesce(new.raw_user_meta_data->>'referral_code','')));
  v_browser := nullif(btrim(coalesce(new.raw_user_meta_data->>'referral_browser_hash','')),'');
  if v_code = '' then return new; end if;
  select user_id into v_referrer from public.referral_codes where code=v_code and revoked_at is null;
  if v_referrer is null or v_referrer=new.id then return new; end if;
  insert into public.referrals(referrer_user_id,referred_user_id,referral_code,browser_hash,status,registered_at)
  values(v_referrer,new.id,v_code,v_browser,'registered',now())
  on conflict (referred_user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_referral on auth.users;
create trigger on_auth_user_created_referral after insert on auth.users for each row execute function public.handle_referral_signup_v1();

create or replace function public.award_referral_coins_v1(p_referral_id uuid,p_reward_type text,p_coins integer,p_billing_transaction_id uuid default null)
returns boolean
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_ref public.referrals%rowtype;
  v_reward_id uuid;
  v_balance bigint;
  v_reference text;
  v_desc text;
begin
  if p_coins <= 0 then return false; end if;
  select * into v_ref from public.referrals where id=p_referral_id for update;
  if not found or v_ref.reward_slot is null or v_ref.status in ('rejected','invalid') then return false; end if;
  v_reference := 'referral:'||p_referral_id::text||':'||p_reward_type;
  insert into public.referral_rewards(referral_id,referrer_user_id,referred_user_id,reward_type,coins,billing_transaction_id,reference_key)
  values(v_ref.id,v_ref.referrer_user_id,v_ref.referred_user_id,p_reward_type,p_coins,p_billing_transaction_id,v_reference)
  on conflict (referral_id,reward_type) do nothing
  returning id into v_reward_id;
  if v_reward_id is null then return false; end if;
  insert into public.user_wallets(user_id) values(v_ref.referrer_user_id) on conflict (user_id) do nothing;
  update public.user_wallets
    set coins_balance=coins_balance+p_coins,
        lifetime_coins_earned=lifetime_coins_earned+p_coins,
        updated_at=now()
    where user_id=v_ref.referrer_user_id
    returning coins_balance into v_balance;
  v_desc := case p_reward_type
    when 'base_referral' then 'Referral reward: valid invited player'
    when 'coin_purchase' then 'Referral reward: invited player made first coin purchase'
    when 'premium_purchase' then 'Referral reward: invited player made first Premium purchase'
    else 'Referral reward'
  end;
  insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description,reference_id)
  values(v_ref.referrer_user_id,p_coins,v_balance,'referral_reward',v_desc,v_reference);
  return true;
end;
$$;
revoke all on function public.award_referral_coins_v1(uuid,text,integer,uuid) from public,anon,authenticated;

create or replace function public.process_referral_commerce_for_user_v1(p_referred_user_id uuid)
returns void
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_ref public.referrals%rowtype;
  v_settings public.referral_program_settings%rowtype;
  v_tx uuid;
begin
  select * into v_ref from public.referrals where referred_user_id=p_referred_user_id;
  if not found or v_ref.reward_slot is null or v_ref.status not in ('active','rewarded') then return; end if;
  select * into v_settings from public.referral_program_settings where id=1;
  select id into v_tx from public.billing_transactions where user_id=p_referred_user_id and kind='coin_pack_purchase' and status='paid' order by created_at asc limit 1;
  if v_tx is not null then perform public.award_referral_coins_v1(v_ref.id,'coin_purchase',v_settings.coin_purchase_reward_coins,v_tx); end if;
  v_tx := null;
  select id into v_tx from public.billing_transactions where user_id=p_referred_user_id and kind='premium_invoice' and status='paid' order by created_at asc limit 1;
  if v_tx is not null then perform public.award_referral_coins_v1(v_ref.id,'premium_purchase',v_settings.premium_purchase_reward_coins,v_tx); end if;
end;
$$;
revoke all on function public.process_referral_commerce_for_user_v1(uuid) from public,anon,authenticated;

create or replace function public.process_referral_for_user_v1(p_referred_user_id uuid)
returns void
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_ref public.referrals%rowtype;
  v_settings public.referral_program_settings%rowtype;
  v_confirmed timestamptz;
  v_career timestamptz;
  v_active_days int;
  v_slot int;
  v_same_device boolean := false;
  v_duplicate_device boolean := false;
begin
  select * into v_ref from public.referrals where referred_user_id=p_referred_user_id for update;
  if not found or v_ref.status in ('rejected','invalid') then return; end if;
  select * into v_settings from public.referral_program_settings where id=1;
  select email_confirmed_at into v_confirmed from auth.users where id=p_referred_user_id;
  select min(created_at) into v_career from public.players where owner_user_id=p_referred_user_id and player_type='human';
  select count(*)::int into v_active_days from public.referral_activity_days where user_id=p_referred_user_id;
  if v_ref.browser_hash is not null then
    select exists(select 1 from public.referral_user_devices d where d.user_id=v_ref.referrer_user_id and d.browser_hash=v_ref.browser_hash) into v_same_device;
    select exists(select 1 from public.referrals r where r.id<>v_ref.id and r.referrer_user_id=v_ref.referrer_user_id and r.browser_hash=v_ref.browser_hash) into v_duplicate_device;
  end if;
  update public.referrals set
    email_verified_at=coalesce(email_verified_at,v_confirmed),
    career_created_at=coalesce(career_created_at,v_career),
    review_required=(review_required or v_same_device or v_duplicate_device),
    review_reason=case when v_same_device then 'Same browser installation as referrer' when v_duplicate_device then 'Browser installation already used by another referral' else review_reason end,
    status=case when status='registered' then 'pending_activation' else status end,
    updated_at=now()
  where id=v_ref.id;
  select * into v_ref from public.referrals where id=v_ref.id for update;
  if v_ref.review_required then return; end if;
  if v_ref.email_verified_at is null or v_ref.career_created_at is null then return; end if;
  if now() < v_ref.registered_at + make_interval(hours=>v_settings.minimum_account_age_hours) then return; end if;
  if v_active_days < v_settings.minimum_active_days then return; end if;
  if v_ref.activated_at is null then
    perform pg_advisory_xact_lock(hashtextextended(v_ref.referrer_user_id::text,0));
    select s into v_slot
    from generate_series(1,v_settings.max_rewardable_referrals) s
    where not exists(select 1 from public.referrals r where r.referrer_user_id=v_ref.referrer_user_id and r.reward_slot=s)
    order by s limit 1;
    update public.referrals set activated_at=now(),reward_slot=v_slot,status='active',updated_at=now() where id=v_ref.id;
    if v_slot is not null then
      perform public.award_referral_coins_v1(v_ref.id,'base_referral',v_settings.base_reward_coins,null);
      update public.referrals set status='rewarded',updated_at=now() where id=v_ref.id;
    end if;
  end if;
  perform public.process_referral_commerce_for_user_v1(p_referred_user_id);
end;
$$;
revoke all on function public.process_referral_for_user_v1(uuid) from public,anon,authenticated;

create or replace function public.trg_process_referral_billing_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  if new.status='paid' and new.kind in ('coin_pack_purchase','premium_invoice') and (tg_op='INSERT' or old.status is distinct from new.status) then
    perform public.process_referral_commerce_for_user_v1(new.user_id);
  end if;
  return new;
end;
$$;
drop trigger if exists process_referral_billing_v1 on public.billing_transactions;
create trigger process_referral_billing_v1 after insert or update on public.billing_transactions for each row execute function public.trg_process_referral_billing_v1();

create or replace function public.register_referral_click_v1(p_code text,p_browser_hash text default null)
returns boolean
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_referrer uuid;
  v_code text := upper(btrim(coalesce(p_code,'')));
begin
  select user_id into v_referrer from public.referral_codes where code=v_code and revoked_at is null;
  if v_referrer is null then return false; end if;
  insert into public.referral_clicks(referral_code,referrer_user_id,browser_hash) values(v_code,v_referrer,nullif(btrim(coalesce(p_browser_hash,'')),''));
  return true;
end;
$$;
grant execute on function public.register_referral_click_v1(text,text) to anon,authenticated;

create or replace function public.record_referral_activity_v1(p_browser_hash text default null)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid := auth.uid();
  v_hash text := nullif(btrim(coalesce(p_browser_hash,'')),'');
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  insert into public.referral_activity_days(user_id,activity_date) values(v_uid,current_date) on conflict do nothing;
  if v_hash is not null then
    insert into public.referral_user_devices(user_id,browser_hash) values(v_uid,v_hash)
    on conflict (user_id,browser_hash) do update set last_seen_at=now();
  end if;
  perform public.process_referral_for_user_v1(v_uid);
  return jsonb_build_object('ok',true);
end;
$$;
grant execute on function public.record_referral_activity_v1(text) to authenticated;

create or replace function public.get_referral_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
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
  select coalesce(sum(coins),0) into v_coins from public.referral_rewards where referrer_user_id=v_uid;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',q.id,
      'registered_at',q.registered_at,
      'status',q.status,
      'review_required',q.review_required,
      'reward_slot',q.reward_slot,
      'reward_coins',q.reward_coins,
      'base_rewarded',q.base_rewarded,
      'coin_purchase_rewarded',q.coin_purchase_rewarded,
      'premium_purchase_rewarded',q.premium_purchase_rewarded
    ) order by q.registered_at desc),'[]'::jsonb)
  into v_activity
  from (
    select r.id,r.registered_at,r.status,r.review_required,r.reward_slot,
      coalesce(sum(rr.coins),0) as reward_coins,
      bool_or(rr.reward_type='base_referral') as base_rewarded,
      bool_or(rr.reward_type='coin_purchase') as coin_purchase_rewarded,
      bool_or(rr.reward_type='premium_purchase') as premium_purchase_rewarded
    from public.referrals r
    left join public.referral_rewards rr on rr.referral_id=r.id
    where r.referrer_user_id=v_uid
    group by r.id
    order by r.registered_at desc
    limit 50
  ) q;
  return jsonb_build_object(
    'code',v_code,
    'stats',jsonb_build_object('total',v_total,'pending',v_pending,'active',v_active,'rewarded',v_rewarded,'coins',v_coins),
    'rules',jsonb_build_object('base_reward_coins',v_settings.base_reward_coins,'coin_purchase_reward_coins',v_settings.coin_purchase_reward_coins,'premium_purchase_reward_coins',v_settings.premium_purchase_reward_coins,'max_rewardable_referrals',v_settings.max_rewardable_referrals,'minimum_account_age_hours',v_settings.minimum_account_age_hours,'minimum_active_days',v_settings.minimum_active_days),
    'activity',v_activity
  );
end;
$$;
grant execute on function public.get_referral_dashboard_v1() to authenticated;
