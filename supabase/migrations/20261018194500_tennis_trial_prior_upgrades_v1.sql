-- Users who upgraded to paid Premium must never receive old trial-expiry
-- pop-ups or messages, even if the later paid subscription has ended.
CREATE OR REPLACE FUNCTION public.get_my_tennis_premium_trial_v1(p_action text DEFAULT 'status'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  if v_paid_active or v_paid_before then
    return jsonb_build_object(
      'state',case when v_paid_active then 'subscribed' else 'ineligible' end,
      'is_premium',v_paid_active,
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
$function$;
