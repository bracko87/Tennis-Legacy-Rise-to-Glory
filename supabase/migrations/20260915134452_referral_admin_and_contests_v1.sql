alter table public.referrals add column if not exists admin_approved boolean not null default false;
alter table public.referrals add column if not exists admin_reviewed_by uuid null references auth.users(id) on delete set null;
alter table public.referrals add column if not exists admin_reviewed_at timestamptz null;

create table if not exists public.referral_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  can_manage_referrals boolean not null default true,
  can_manage_contests boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.referral_admins(user_id)
select p.id from public.profiles p where p.username='Aleks'
on conflict (user_id) do nothing;

create table if not exists public.referral_admin_audit (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null,
  target_type text not null,
  target_id text null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists referral_admin_audit_time_idx on public.referral_admin_audit(created_at desc);

create table if not exists public.referral_reward_adjustments (
  id uuid primary key default gen_random_uuid(),
  referral_id uuid not null references public.referrals(id) on delete cascade,
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  admin_user_id uuid not null references auth.users(id) on delete restrict,
  coin_delta integer not null check (coin_delta <> 0),
  reason text not null,
  reference_key text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.referral_badge_catalog (
  code text primary key,
  name text not null,
  description text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.referral_badge_catalog(code,name,description) values
('community_builder','Community Builder','Awarded for exceptional referral-community contribution.'),
('referral_champion','Referral Champion','Awarded to a winner of a referral competition.'),
('referral_ambassador','Referral Ambassador','Awarded through a referral campaign or competition.')
on conflict (code) do nothing;

create table if not exists public.referral_user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_code text not null references public.referral_badge_catalog(code),
  contest_id uuid null,
  awarded_at timestamptz not null default now(),
  unique(user_id,badge_code,contest_id)
);

create table if not exists public.referral_contests (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  validation_deadline timestamptz not null,
  status text not null default 'draft' check (status in ('draft','active','validation','finalized','canceled')),
  ranking_rule text not null default 'valid_referrals' check (ranking_rule='valid_referrals'),
  tie_break_rule text not null default 'first_to_final_count' check (tie_break_rule='first_to_final_count'),
  max_counted_referrals integer not null default 100 check (max_counted_referrals between 1 and 10000),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  finalized_at timestamptz null,
  check (ends_at > starts_at),
  check (validation_deadline >= ends_at)
);
create index if not exists referral_contests_status_time_idx on public.referral_contests(status,starts_at,ends_at);

alter table public.referral_user_badges drop constraint if exists referral_user_badges_contest_id_fkey;
alter table public.referral_user_badges add constraint referral_user_badges_contest_id_fkey foreign key(contest_id) references public.referral_contests(id) on delete set null;

create table if not exists public.referral_contest_prizes (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references public.referral_contests(id) on delete cascade,
  rank_from integer not null check (rank_from >= 1),
  rank_to integer not null check (rank_to >= rank_from),
  title text not null,
  coins integer not null default 0 check (coins >= 0),
  premium_days integer not null default 0 check (premium_days >= 0),
  badge_code text null references public.referral_badge_catalog(code),
  created_at timestamptz not null default now(),
  check (coins > 0 or premium_days > 0 or badge_code is not null)
);
create index if not exists referral_contest_prizes_contest_idx on public.referral_contest_prizes(contest_id,rank_from,rank_to);

create table if not exists public.referral_premium_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  contest_id uuid not null references public.referral_contests(id) on delete cascade,
  days integer not null check (days > 0),
  created_at timestamptz not null default now(),
  unique(user_id,contest_id)
);

create table if not exists public.referral_contest_awards (
  id uuid primary key default gen_random_uuid(),
  contest_id uuid not null references public.referral_contests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  final_rank integer not null check (final_rank >= 1),
  valid_referrals integer not null check (valid_referrals >= 0),
  coins integer not null default 0 check (coins >= 0),
  premium_days integer not null default 0 check (premium_days >= 0),
  badge_code text null references public.referral_badge_catalog(code),
  awarded_at timestamptz not null default now(),
  unique(contest_id,user_id)
);

alter table public.referral_admins enable row level security;
alter table public.referral_admin_audit enable row level security;
alter table public.referral_reward_adjustments enable row level security;
alter table public.referral_badge_catalog enable row level security;
alter table public.referral_user_badges enable row level security;
alter table public.referral_contests enable row level security;
alter table public.referral_contest_prizes enable row level security;
alter table public.referral_premium_grants enable row level security;
alter table public.referral_contest_awards enable row level security;
revoke all on public.referral_admins, public.referral_admin_audit, public.referral_reward_adjustments, public.referral_badge_catalog, public.referral_user_badges, public.referral_contests, public.referral_contest_prizes, public.referral_premium_grants, public.referral_contest_awards from anon,authenticated;

create or replace function public.is_referral_admin_v1(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path='public'
as $$
  select exists(
    select 1 from public.referral_admins a
    where a.user_id=p_user_id and (a.can_manage_referrals or a.can_manage_contests)
  );
$$;
revoke all on function public.is_referral_admin_v1(uuid) from public,anon,authenticated;

create or replace function public.audit_referral_admin_v1(p_action text,p_target_type text,p_target_id text,p_details jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path='public'
as $$
begin
  insert into public.referral_admin_audit(admin_user_id,action,target_type,target_id,details)
  values(auth.uid(),p_action,p_target_type,p_target_id,coalesce(p_details,'{}'::jsonb));
end;
$$;
revoke all on function public.audit_referral_admin_v1(text,text,text,jsonb) from public,anon,authenticated;

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
  if v_ref.browser_hash is not null and not v_ref.admin_approved then
    select exists(select 1 from public.referral_user_devices d where d.user_id=v_ref.referrer_user_id and d.browser_hash=v_ref.browser_hash) into v_same_device;
    select exists(select 1 from public.referrals r where r.id<>v_ref.id and r.referrer_user_id=v_ref.referrer_user_id and r.browser_hash=v_ref.browser_hash) into v_duplicate_device;
  end if;
  update public.referrals set
    email_verified_at=coalesce(email_verified_at,v_confirmed),
    career_created_at=coalesce(career_created_at,v_career),
    review_required=case when admin_approved then false else (review_required or v_same_device or v_duplicate_device) end,
    review_reason=case when admin_approved then null when v_same_device then 'Same browser installation as referrer' when v_duplicate_device then 'Browser installation already used by another referral' else review_reason end,
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
grant execute on function public.process_referral_for_user_v1(uuid) to service_role;

create or replace function public.referral_contest_leaderboard_rows_v1(p_contest_id uuid)
returns table(rank_no integer,referrer_user_id uuid,username text,valid_referrals integer,reached_count_at timestamptz)
language sql
stable
security definer
set search_path='public'
as $$
  with c as (
    select * from public.referral_contests where id=p_contest_id
  ), eligible as (
    select r.referrer_user_id,r.activated_at
    from public.referrals r,c
    where r.registered_at >= c.starts_at
      and r.registered_at < c.ends_at
      and r.activated_at is not null
      and r.activated_at <= c.validation_deadline
      and r.status in ('active','rewarded')
      and not r.review_required
  ), numbered as (
    select e.*,
           row_number() over(partition by e.referrer_user_id order by e.activated_at asc) as n
    from eligible e
  ), grouped as (
    select n.referrer_user_id,
           count(*)::int as valid_referrals,
           max(n.activated_at) as reached_count_at
    from numbered n,c
    where n.n <= c.max_counted_referrals
    group by n.referrer_user_id
  ), ranked as (
    select row_number() over(order by g.valid_referrals desc,g.reached_count_at asc,g.referrer_user_id)::int as rank_no,
           g.referrer_user_id,
           p.username,
           g.valid_referrals,
           g.reached_count_at
    from grouped g
    left join public.profiles p on p.id=g.referrer_user_id
  )
  select * from ranked;
$$;
revoke all on function public.referral_contest_leaderboard_rows_v1(uuid) from public,anon,authenticated;

create or replace function public.get_referral_contest_leaderboard_v1(p_contest_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_contest public.referral_contests%rowtype;
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_contest from public.referral_contests where id=p_contest_id;
  if not found or v_contest.status='draft' then raise exception 'Contest not available'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'rank',x.rank_no,'username',coalesce(x.username,'Player'),'valid_referrals',x.valid_referrals,
    'reached_count_at',x.reached_count_at,'is_you',x.referrer_user_id=v_uid
  ) order by x.rank_no),'[]'::jsonb)
  into v_rows
  from public.referral_contest_leaderboard_rows_v1(p_contest_id) x
  where x.rank_no<=100;
  return jsonb_build_object(
    'contest',jsonb_build_object('id',v_contest.id,'name',v_contest.name,'description',v_contest.description,'starts_at',v_contest.starts_at,'ends_at',v_contest.ends_at,'validation_deadline',v_contest.validation_deadline,'status',v_contest.status,'tie_break_rule',v_contest.tie_break_rule,'max_counted_referrals',v_contest.max_counted_referrals),
    'leaderboard',v_rows
  );
end;
$$;
revoke all on function public.get_referral_contest_leaderboard_v1(uuid) from public,anon,authenticated;
grant execute on function public.get_referral_contest_leaderboard_v1(uuid) to authenticated;

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
  select coalesce(sum(coins),0) into v_coins from public.referral_rewards where referrer_user_id=v_uid;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',q.id,'registered_at',q.registered_at,'status',q.status,'review_required',q.review_required,'reward_slot',q.reward_slot,
      'reward_coins',q.reward_coins,'base_rewarded',q.base_rewarded,'coin_purchase_rewarded',q.coin_purchase_rewarded,'premium_purchase_rewarded',q.premium_purchase_rewarded
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
$$;
revoke all on function public.get_referral_dashboard_v1() from public,anon,authenticated;
grant execute on function public.get_referral_dashboard_v1() to authenticated;

create or replace function public.get_referral_admin_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
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
    'coins_paid',(select coalesce(sum(coins),0) from public.referral_rewards)
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
    'reward_coins',(select coalesce(sum(x.coins),0) from public.referral_rewards x where x.referral_id=r.id)
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
$$;
revoke all on function public.get_referral_admin_dashboard_v1() from public,anon,authenticated;
grant execute on function public.get_referral_admin_dashboard_v1() to authenticated;

create or replace function public.admin_review_referral_v1(p_referral_id uuid,p_action text,p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_ref public.referrals%rowtype;
  v_action text:=lower(btrim(p_action));
begin
  if v_uid is null or not exists(select 1 from public.referral_admins a where a.user_id=v_uid and a.can_manage_referrals) then raise exception 'Referral admin access required'; end if;
  select * into v_ref from public.referrals where id=p_referral_id for update;
  if not found then raise exception 'Referral not found'; end if;
  if v_action='approve' then
    update public.referrals set review_required=false,review_reason=null,admin_approved=true,admin_reviewed_by=v_uid,admin_reviewed_at=now(),
      status=case when status in ('rejected','invalid') then 'pending_activation' else status end,rejected_at=null,rejection_reason=null,updated_at=now()
    where id=p_referral_id;
    perform public.process_referral_for_user_v1(v_ref.referred_user_id);
  elsif v_action in ('reject','invalidate') then
    update public.referrals set status=case when v_action='reject' then 'rejected' else 'invalid' end,review_required=false,admin_approved=false,
      rejected_at=now(),rejection_reason=coalesce(nullif(btrim(p_reason),''),'Rejected by referral admin'),admin_reviewed_by=v_uid,admin_reviewed_at=now(),updated_at=now()
    where id=p_referral_id;
  elsif v_action='recheck' then
    update public.referrals set review_required=false,review_reason=null,admin_approved=false,admin_reviewed_by=v_uid,admin_reviewed_at=now(),updated_at=now() where id=p_referral_id;
    perform public.process_referral_for_user_v1(v_ref.referred_user_id);
  else
    raise exception 'Unsupported review action';
  end if;
  perform public.audit_referral_admin_v1('review_'||v_action,'referral',p_referral_id::text,jsonb_build_object('reason',p_reason));
  return jsonb_build_object('ok',true,'action',v_action);
end;
$$;
revoke all on function public.admin_review_referral_v1(uuid,text,text) from public,anon,authenticated;
grant execute on function public.admin_review_referral_v1(uuid,text,text) to authenticated;

create or replace function public.admin_update_referral_settings_v1(p_base_reward_coins integer,p_coin_purchase_reward_coins integer,p_premium_purchase_reward_coins integer,p_max_rewardable_referrals integer,p_minimum_account_age_hours integer,p_minimum_active_days integer)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_uid uuid:=auth.uid(); begin
  if v_uid is null or not exists(select 1 from public.referral_admins a where a.user_id=v_uid and a.can_manage_referrals) then raise exception 'Referral admin access required'; end if;
  if p_base_reward_coins<0 or p_coin_purchase_reward_coins<0 or p_premium_purchase_reward_coins<0 or p_max_rewardable_referrals not between 1 and 100 or p_minimum_account_age_hours<0 or p_minimum_active_days<1 then raise exception 'Invalid referral settings'; end if;
  update public.referral_program_settings set base_reward_coins=p_base_reward_coins,coin_purchase_reward_coins=p_coin_purchase_reward_coins,premium_purchase_reward_coins=p_premium_purchase_reward_coins,max_rewardable_referrals=p_max_rewardable_referrals,minimum_account_age_hours=p_minimum_account_age_hours,minimum_active_days=p_minimum_active_days,updated_at=now() where id=1;
  perform public.audit_referral_admin_v1('update_settings','settings','1',jsonb_build_object('base',p_base_reward_coins,'coin_purchase',p_coin_purchase_reward_coins,'premium_purchase',p_premium_purchase_reward_coins,'max_referrals',p_max_rewardable_referrals,'account_hours',p_minimum_account_age_hours,'active_days',p_minimum_active_days));
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.admin_update_referral_settings_v1(integer,integer,integer,integer,integer,integer) from public,anon,authenticated;
grant execute on function public.admin_update_referral_settings_v1(integer,integer,integer,integer,integer,integer) to authenticated;

create or replace function public.admin_adjust_referral_reward_v1(p_referral_id uuid,p_coin_delta integer,p_reason text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid(); v_ref public.referrals%rowtype; v_balance bigint; v_refkey text;
begin
  if v_uid is null or not exists(select 1 from public.referral_admins a where a.user_id=v_uid and a.can_manage_referrals) then raise exception 'Referral admin access required'; end if;
  if p_coin_delta=0 or nullif(btrim(p_reason),'') is null then raise exception 'A non-zero adjustment and reason are required'; end if;
  select * into v_ref from public.referrals where id=p_referral_id for update;
  if not found then raise exception 'Referral not found'; end if;
  insert into public.user_wallets(user_id) values(v_ref.referrer_user_id) on conflict(user_id) do nothing;
  select coins_balance into v_balance from public.user_wallets where user_id=v_ref.referrer_user_id for update;
  if v_balance+p_coin_delta<0 then raise exception 'Adjustment would make the Coin balance negative'; end if;
  v_refkey:='referral-adjustment:'||p_referral_id::text||':'||gen_random_uuid()::text;
  update public.user_wallets set coins_balance=coins_balance+p_coin_delta,lifetime_coins_earned=lifetime_coins_earned+greatest(p_coin_delta,0),updated_at=now() where user_id=v_ref.referrer_user_id returning coins_balance into v_balance;
  insert into public.referral_reward_adjustments(referral_id,referrer_user_id,admin_user_id,coin_delta,reason,reference_key) values(p_referral_id,v_ref.referrer_user_id,v_uid,p_coin_delta,btrim(p_reason),v_refkey);
  insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description,reference_id) values(v_ref.referrer_user_id,p_coin_delta,v_balance,'admin_adjustment','Referral reward correction: '||btrim(p_reason),v_refkey);
  perform public.audit_referral_admin_v1('reward_adjustment','referral',p_referral_id::text,jsonb_build_object('coin_delta',p_coin_delta,'reason',p_reason));
  return jsonb_build_object('ok',true,'balance_after',v_balance);
end;
$$;
revoke all on function public.admin_adjust_referral_reward_v1(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.admin_adjust_referral_reward_v1(uuid,integer,text) to authenticated;

create or replace function public.admin_create_referral_contest_v1(p_name text,p_description text,p_starts_at timestamptz,p_ends_at timestamptz,p_validation_deadline timestamptz,p_max_counted_referrals integer,p_prizes jsonb)
returns uuid
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid(); v_contest uuid; v_item jsonb;
begin
  if v_uid is null or not exists(select 1 from public.referral_admins a where a.user_id=v_uid and a.can_manage_contests) then raise exception 'Referral contest admin access required'; end if;
  if nullif(btrim(p_name),'') is null or p_ends_at<=p_starts_at or p_validation_deadline<p_ends_at or p_max_counted_referrals not between 1 and 10000 then raise exception 'Invalid contest configuration'; end if;
  if jsonb_typeof(p_prizes)<>'array' or jsonb_array_length(p_prizes)=0 then raise exception 'At least one prize tier is required'; end if;
  insert into public.referral_contests(name,description,starts_at,ends_at,validation_deadline,max_counted_referrals,created_by)
  values(btrim(p_name),coalesce(p_description,''),p_starts_at,p_ends_at,p_validation_deadline,p_max_counted_referrals,v_uid) returning id into v_contest;
  for v_item in select value from jsonb_array_elements(p_prizes) loop
    insert into public.referral_contest_prizes(contest_id,rank_from,rank_to,title,coins,premium_days,badge_code)
    values(v_contest,(v_item->>'rank_from')::int,(v_item->>'rank_to')::int,coalesce(nullif(v_item->>'title',''),'Contest prize'),coalesce((v_item->>'coins')::int,0),coalesce((v_item->>'premium_days')::int,0),nullif(v_item->>'badge_code',''));
  end loop;
  perform public.audit_referral_admin_v1('create_contest','contest',v_contest::text,jsonb_build_object('name',p_name));
  return v_contest;
end;
$$;
revoke all on function public.admin_create_referral_contest_v1(text,text,timestamptz,timestamptz,timestamptz,integer,jsonb) from public,anon,authenticated;
grant execute on function public.admin_create_referral_contest_v1(text,text,timestamptz,timestamptz,timestamptz,integer,jsonb) to authenticated;

create or replace function public.admin_set_referral_contest_status_v1(p_contest_id uuid,p_status text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_uid uuid:=auth.uid(); v_status text:=lower(btrim(p_status)); begin
  if v_uid is null or not exists(select 1 from public.referral_admins a where a.user_id=v_uid and a.can_manage_contests) then raise exception 'Referral contest admin access required'; end if;
  if v_status not in ('draft','active','validation','canceled') then raise exception 'Unsupported contest status'; end if;
  update public.referral_contests set status=v_status,updated_at=now() where id=p_contest_id and status<>'finalized';
  if not found then raise exception 'Contest not found or already finalized'; end if;
  perform public.audit_referral_admin_v1('contest_status','contest',p_contest_id::text,jsonb_build_object('status',v_status));
  return jsonb_build_object('ok',true,'status',v_status);
end;
$$;
revoke all on function public.admin_set_referral_contest_status_v1(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_set_referral_contest_status_v1(uuid,text) to authenticated;

create or replace function public.grant_referral_premium_days_v1(p_user_id uuid,p_contest_id uuid,p_days integer)
returns boolean
language plpgsql
security definer
set search_path='public'
as $$
declare v_exists uuid; begin
  if p_days<=0 then return false; end if;
  insert into public.referral_premium_grants(user_id,contest_id,days) values(p_user_id,p_contest_id,p_days) on conflict(user_id,contest_id) do nothing returning id into v_exists;
  if v_exists is null then return false; end if;
  insert into public.premium_memberships(user_id,plan_code,status,current_period_start,current_period_end,monthly_price_eur_cents,monthly_coin_reward)
  values(p_user_id,'premium','active',now(),now()+make_interval(days=>p_days),0,0)
  on conflict(user_id) do update set
    plan_code='premium',status='active',current_period_start=coalesce(public.premium_memberships.current_period_start,now()),
    current_period_end=case when public.premium_memberships.plan_code='premium' and public.premium_memberships.status='active' and public.premium_memberships.current_period_end is null then null else greatest(coalesce(public.premium_memberships.current_period_end,now()),now())+make_interval(days=>p_days) end,
    cancel_at_period_end=false,updated_at=now();
  return true;
end;
$$;
revoke all on function public.grant_referral_premium_days_v1(uuid,uuid,integer) from public,anon,authenticated;

create or replace function public.admin_finalize_referral_contest_v1(p_contest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid(); v_contest public.referral_contests%rowtype; v_row record; v_prize record; v_award_id uuid; v_balance bigint; v_refkey text; v_count int:=0;
begin
  if v_uid is null or not exists(select 1 from public.referral_admins a where a.user_id=v_uid and a.can_manage_contests) then raise exception 'Referral contest admin access required'; end if;
  select * into v_contest from public.referral_contests where id=p_contest_id for update;
  if not found then raise exception 'Contest not found'; end if;
  if v_contest.status='finalized' then return jsonb_build_object('ok',true,'already_finalized',true); end if;
  if v_contest.status='canceled' then raise exception 'Canceled contests cannot be finalized'; end if;
  if now()<v_contest.validation_deadline then raise exception 'Validation deadline has not passed'; end if;
  for v_row in select * from public.referral_contest_leaderboard_rows_v1(p_contest_id) order by rank_no loop
    select * into v_prize from public.referral_contest_prizes p where p.contest_id=p_contest_id and v_row.rank_no between p.rank_from and p.rank_to order by p.rank_from limit 1;
    if found then
      insert into public.referral_contest_awards(contest_id,user_id,final_rank,valid_referrals,coins,premium_days,badge_code)
      values(p_contest_id,v_row.referrer_user_id,v_row.rank_no,v_row.valid_referrals,v_prize.coins,v_prize.premium_days,v_prize.badge_code)
      on conflict(contest_id,user_id) do nothing returning id into v_award_id;
      if v_award_id is not null then
        if v_prize.coins>0 then
          insert into public.user_wallets(user_id) values(v_row.referrer_user_id) on conflict(user_id) do nothing;
          update public.user_wallets set coins_balance=coins_balance+v_prize.coins,lifetime_coins_earned=lifetime_coins_earned+v_prize.coins,updated_at=now() where user_id=v_row.referrer_user_id returning coins_balance into v_balance;
          v_refkey:='referral-contest:'||p_contest_id::text||':'||v_row.referrer_user_id::text;
          insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description,reference_id) values(v_row.referrer_user_id,v_prize.coins,v_balance,'referral_reward','Referral contest prize: '||v_contest.name,v_refkey);
        end if;
        if v_prize.premium_days>0 then perform public.grant_referral_premium_days_v1(v_row.referrer_user_id,p_contest_id,v_prize.premium_days); end if;
        if v_prize.badge_code is not null then insert into public.referral_user_badges(user_id,badge_code,contest_id) values(v_row.referrer_user_id,v_prize.badge_code,p_contest_id) on conflict do nothing; end if;
        v_count:=v_count+1;
      end if;
    end if;
  end loop;
  update public.referral_contests set status='finalized',finalized_at=now(),updated_at=now() where id=p_contest_id;
  perform public.audit_referral_admin_v1('finalize_contest','contest',p_contest_id::text,jsonb_build_object('awards',v_count));
  return jsonb_build_object('ok',true,'awards_created',v_count);
end;
$$;
revoke all on function public.admin_finalize_referral_contest_v1(uuid) from public,anon,authenticated;
grant execute on function public.admin_finalize_referral_contest_v1(uuid) to authenticated;
