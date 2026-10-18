-- Tennis Legacy: seven REAL days of Premium for eligible free players.
-- Separate from Stripe, recurring billing, subscription Coins, and referral grants.
-- New and existing free players receive their one-time trial on first game entry.
create table if not exists public.tennis_premium_trials_v1 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email_claim_hash text not null unique,
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  welcome_dismissed_at timestamptz,
  expiry_dismissed_at timestamptz,
  started_notified_at timestamptz,
  reminder_notified_at timestamptz,
  expired_notified_at timestamptz,
  constraint tennis_trial_exactly_seven_days check (expires_at = started_at + interval '7 days')
);
alter table public.tennis_premium_trials_v1 enable row level security;
revoke all on public.tennis_premium_trials_v1 from public, anon, authenticated;

-- Keep only a pseudonymous claim history after account deletion so re-registering
-- with the same email does not repeatedly mint a new trial.
create table if not exists public.tennis_premium_trial_claims_v1 (
  email_claim_hash text primary key,
  claimed_at timestamptz not null default now()
);
alter table public.tennis_premium_trial_claims_v1 enable row level security;
revoke all on public.tennis_premium_trial_claims_v1 from public, anon, authenticated;

insert into public.notification_catalog (
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,
  title_template,message_template,default_route,severity,default_in_app,
  default_email,default_push,is_user_configurable,is_active
) values
('premium.trial.started','account','Premium trial started',
 'A free player receives seven days to try the current Premium features.',
 'First game dashboard entry','Eligible free player with an unclaimed seven-day trial',
 'Authenticated idempotent trial onboarding',
 'Your 7-day Premium trial has started',
 'Try Private Life and ranking-point expiration tools for seven days. No card is required and no subscription starts automatically.',
 '/game/pro-packages','success',true,false,false,false,true),
('premium.trial.reminder','account','Premium trial ending soon',
 'Reminds the player during the final 24 hours of trial access.',
 'Trial check within 24 hours of expiry','Trial active and reminder not yet sent',
 'Authenticated idempotent trial status check',
 'Your Premium trial ends within 24 hours',
 'Enjoy your remaining Premium access or explore plans. No payment will be charged automatically.',
 '/game/pro-packages','info',true,false,false,false,true),
('premium.trial.expired','account','Premium trial finished',
 'Explains the automatic return to free play without losing progress.',
 'First trial check after expiry','Trial ended and user has no active paid Premium',
 'Authenticated idempotent trial status check',
 'Your free Premium trial has ended',
 'Your career and purchases are safe. Premium-only actions are now locked; you can continue playing free or choose a Premium plan.',
 '/game/pro-packages','info',true,false,false,false,true)
on conflict(code) do update set
 label=excluded.label,reason=excluded.reason,
 title_template=excluded.title_template,message_template=excluded.message_template,
 default_route=excluded.default_route,is_active=true,updated_at=now();

-- Preserve all existing paid/subscription/referral membership semantics.
-- Every server-side feature using this predicate gets exactly the same timed
-- trial entitlement as the client. Check now() at each operation, not at login.
create or replace function public.has_active_premium_v1()
returns boolean language sql stable security definer set search_path='public'
as $fn$
  select exists (
    select 1 from public.premium_memberships pm
    where pm.user_id=auth.uid() and pm.plan_code='premium'
      and pm.status='active'
      and (pm.current_period_end is null or pm.current_period_end>now())
  ) or exists (
    select 1 from public.tennis_premium_trials_v1 t
    where t.user_id=auth.uid() and t.expires_at>now()
  );
$fn$;
revoke all on function public.has_active_premium_v1() from public,anon;
grant execute on function public.has_active_premium_v1() to authenticated;

create or replace function public.get_my_tennis_premium_trial_v1(p_action text default 'status')
returns jsonb language plpgsql security definer set search_path='public','pg_temp'
as $fn$
declare
  v_user uuid := auth.uid();
  v_player uuid;
  v_email text;
  v_email_hash text;
  v_trial public.tennis_premium_trials_v1%rowtype;
  v_paid_active boolean := false;
  v_paid_before boolean := false;
  v_claimed integer := 0;
  v_started boolean := false;
  v_now timestamptz := now();
  v_action text := coalesce(p_action,'status');
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_action not in ('status','dismiss_welcome','dismiss_expired') then
    raise exception 'Unsupported trial action';
  end if;

  select p.id into v_player from public.players p
  where p.owner_user_id=v_user and p.player_type='human'
  order by p.created_at limit 1;
  if v_player is null then return jsonb_build_object('state','not_ready'); end if;

  -- Serialize all status / creation calls for this account.
  perform pg_advisory_xact_lock(hashtext('tennis_premium_trial:'||v_user::text));
  select * into v_trial from public.tennis_premium_trials_v1 where user_id=v_user;

  select exists(
    select 1 from public.premium_memberships m
    where m.user_id=v_user and m.plan_code='premium' and m.status='active'
      and (m.current_period_end is null or m.current_period_end>v_now)
  ) into v_paid_active;

  -- A Stripe purchaser, even after cancellation, should not be offered a new trial.
  select exists (
    select 1 from public.billing_transactions b
    where b.user_id=v_user and b.kind='premium_invoice' and b.status='paid'
  ) into v_paid_before;

  if v_trial.user_id is null and not v_paid_active and not v_paid_before then
    select u.email into v_email from auth.users u where u.id=v_user;
    -- Current verified account email; no raw address is persisted.
    v_email_hash := md5(lower(trim(coalesce(nullif(v_email,''),v_user::text))));
    insert into public.tennis_premium_trial_claims_v1(email_claim_hash)
      values(v_email_hash) on conflict do nothing;
    get diagnostics v_claimed = row_count;
    if v_claimed=1 then
      insert into public.tennis_premium_trials_v1(user_id,email_claim_hash,started_at,expires_at)
      values(v_user,v_email_hash,v_now,v_now+interval '7 days')
      on conflict do nothing returning * into v_trial;
      v_started := v_trial.user_id is not null;
    end if;
  end if;

  if v_trial.user_id is null then
    return jsonb_build_object('state',case when v_paid_active then 'subscribed' else 'ineligible' end,
      'is_premium',v_paid_active,'show_welcome',false,'show_expired',false);
  end if;

  if v_action='dismiss_welcome' then
    update public.tennis_premium_trials_v1
      set welcome_dismissed_at=coalesce(welcome_dismissed_at,v_now)
      where user_id=v_user;
  elsif v_action='dismiss_expired' and v_trial.expires_at<=v_now then
    update public.tennis_premium_trials_v1
      set expiry_dismissed_at=coalesce(expiry_dismissed_at,v_now)
      where user_id=v_user;
  end if;

  select * into v_trial from public.tennis_premium_trials_v1 where user_id=v_user;

  -- A subsequent paid upgrade wins over trial expiry, including pop-ups.
  if v_paid_active then
    return jsonb_build_object('state','subscribed','is_premium',true,
      'show_welcome',false,'show_expired',false,
      'started_at',v_trial.started_at,'expires_at',v_trial.expires_at);
  end if;

  if v_trial.started_notified_at is null then
    perform public.emit_notification_v1(
      v_user,v_player,'premium.trial.started',
      'Your 7-day Premium trial has started',
      'Welcome! Explore Private Life and ranking protection. No card or payment is needed.',
      '/game/pro-packages',jsonb_build_object('trial_started_at',v_trial.started_at),
      'tennis_premium_trial_started:'||v_user::text
    );
    update public.tennis_premium_trials_v1
      set started_notified_at=v_now where user_id=v_user;
  end if;

  if v_trial.expires_at<=v_now and v_trial.expired_notified_at is null then
    perform public.emit_notification_v1(
      v_user,v_player,'premium.trial.expired',
      'Your free Premium trial has ended',
      'You can keep playing for free. Private Life and ranking-protection actions are locked until you subscribe. Your career is safe.',
      '/game/pro-packages',jsonb_build_object('trial_expires_at',v_trial.expires_at),
      'tennis_premium_trial_expired:'||v_user::text
    );
    update public.tennis_premium_trials_v1 set expired_notified_at=v_now
      where user_id=v_user;
  elsif v_trial.expires_at>v_now and v_trial.expires_at<=v_now+interval '24 hours'
    and v_trial.reminder_notified_at is null then
    perform public.emit_notification_v1(
      v_user,v_player,'premium.trial.reminder',
      'Your Premium trial ends within 24 hours',
      'You still have Premium access. You can continue for free afterwards or explore plans. There is no automatic charge.',
      '/game/pro-packages',jsonb_build_object('trial_expires_at',v_trial.expires_at),
      'tennis_premium_trial_reminder:'||v_user::text
    );
    update public.tennis_premium_trials_v1 set reminder_notified_at=v_now
      where user_id=v_user;
  end if;

  return jsonb_build_object(
    'state',case when v_trial.expires_at>v_now then 'active' else 'expired' end,
    'trial_started',v_started,
    'is_premium',v_trial.expires_at>v_now,
    'started_at',v_trial.started_at,'expires_at',v_trial.expires_at,
    'seconds_left',greatest(0,ceil(extract(epoch from v_trial.expires_at-v_now))),
    'show_welcome',v_trial.welcome_dismissed_at is null and v_trial.expires_at>v_now,
    'show_expired',v_trial.expiry_dismissed_at is null and v_trial.expires_at<=v_now
  );
end;
$fn$;
revoke all on function public.get_my_tennis_premium_trial_v1(text) from public,anon;
grant execute on function public.get_my_tennis_premium_trial_v1(text) to authenticated;
