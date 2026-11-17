-- Tennis Legacy: 7 real days of Premium, starting at the ACTUAL first
-- unpause of the official Season 1 prelaunch clock (not account creation).
-- Existing payment, subscription and wallet records are not modified.
-- Scheduled launch: 2026-11-23 07:00 CET / 06:00 UTC.
CREATE TABLE IF NOT EXISTS control_center_private.tennis_premium_launch_control_v1 (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  scheduled_at timestamptz NOT NULL,
  unpaused_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tennis_premium_launch_not_before_schedule
    CHECK (unpaused_at IS NULL OR unpaused_at>=scheduled_at)
);
ALTER TABLE control_center_private.tennis_premium_launch_control_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tennis_premium_launch_control_v1 FROM PUBLIC,anon,authenticated;

INSERT INTO control_center_private.tennis_premium_launch_control_v1(id,scheduled_at)
VALUES(true,'2026-11-23 07:00:00+01'::timestamptz)
ON CONFLICT(id) DO NOTHING;

DO $verify$
BEGIN
 IF NOT EXISTS(
  SELECT 1 FROM control_center_private.tennis_premium_launch_control_v1
  WHERE id=true and scheduled_at='2026-11-23 07:00:00+01'::timestamptz
 ) THEN RAISE EXCEPTION 'Prelaunch time was changed; manual review needed';END IF;
END $verify$;

ALTER TABLE public.tennis_premium_trials_v1
 ADD COLUMN IF NOT EXISTS reserved_for_launch boolean NOT NULL DEFAULT false,
 ADD COLUMN IF NOT EXISTS launch_cohort boolean NOT NULL DEFAULT false;
ALTER TABLE public.tennis_premium_trials_v1
 DROP CONSTRAINT IF EXISTS tennis_trial_reservation_requires_cohort;
ALTER TABLE public.tennis_premium_trials_v1
 ADD CONSTRAINT tennis_trial_reservation_requires_cohort
 CHECK (NOT reserved_for_launch OR launch_cohort);

-- Historical free trials came from the discarded testing season. Restore the
-- unused seven days for eligible test accounts without touching paid history.
UPDATE public.tennis_premium_trials_v1 t
SET started_at='2026-11-23 07:00:00+01'::timestamptz,
    expires_at='2026-11-23 07:00:00+01'::timestamptz+interval '7 days',
    reserved_for_launch=true,launch_cohort=true,
    welcome_dismissed_at=NULL,expiry_dismissed_at=NULL,
    started_notified_at=NULL,reminder_notified_at=NULL,
    expired_notified_at=NULL
WHERE t.started_at < '2026-11-23 07:00:00+01'::timestamptz
 AND NOT EXISTS(
  SELECT 1 FROM public.billing_transactions b
  WHERE b.user_id=t.user_id AND b.kind='premium_invoice' AND b.status='paid'
 )
 AND NOT EXISTS(
  SELECT 1 FROM public.premium_memberships m
  WHERE m.user_id=t.user_id AND m.plan_code='premium' AND m.status='active'
 );

-- Capture first real launch unpause and anchor every prelaunch trial
-- in ONE transaction. Routine pauses later never extend a trial.
CREATE OR REPLACE FUNCTION control_center_private.tennis_activate_launch_trials_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'control_center_private','public','pg_temp'
AS $function$
DECLARE v_release timestamptz;v_scheduled timestamptz;
BEGIN
 IF NOT OLD.is_paused OR NEW.is_paused OR NEW.id<>1 THEN RETURN NEW;END IF;
 SELECT scheduled_at INTO v_scheduled
 FROM control_center_private.tennis_premium_launch_control_v1 WHERE id=true FOR UPDATE;
 IF v_scheduled IS NULL THEN RAISE EXCEPTION 'Premium launch gate is missing'; END IF;
 IF clock_timestamp()<v_scheduled THEN
   RAISE EXCEPTION 'Game launch cannot begin before 23 November 2026 at 07:00 German time';
 END IF;
 UPDATE control_center_private.tennis_premium_launch_control_v1
 SET unpaused_at=clock_timestamp(),updated_at=now()
 WHERE id=true AND unpaused_at IS NULL
 RETURNING unpaused_at INTO v_release;
 IF v_release IS NULL THEN RETURN NEW;END IF;
 UPDATE public.tennis_premium_trials_v1 t
 SET started_at=v_release,expires_at=v_release+interval '7 days',
     reserved_for_launch=false,
     started_notified_at=NULL,reminder_notified_at=NULL,
     expired_notified_at=NULL,welcome_dismissed_at=NULL,
     expiry_dismissed_at=NULL
 WHERE reserved_for_launch
   AND launch_cohort
   AND EXISTS(
     SELECT 1 FROM public.players p
     WHERE p.owner_user_id=t.user_id
       AND p.player_type='human'
       AND p.created_at<=v_release
   );
 -- Accounts without a character at launch keep their reservation. They get
 -- their FULL seven days when they create their own player afterwards.
 RETURN NEW;
END $function$;
REVOKE ALL ON FUNCTION control_center_private.tennis_activate_launch_trials_v1()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS tennis_activate_launch_trials_v1 ON public.game_clock;
CREATE TRIGGER tennis_activate_launch_trials_v1
 AFTER UPDATE OF is_paused ON public.game_clock
 FOR EACH ROW WHEN (OLD.is_paused AND NOT NEW.is_paused)
 EXECUTE FUNCTION control_center_private.tennis_activate_launch_trials_v1();

CREATE OR REPLACE FUNCTION public.has_active_premium_v1()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.premium_memberships pm
    where pm.user_id=auth.uid() and pm.plan_code='premium'
      and pm.status='active'
      and (pm.current_period_end is null or pm.current_period_end>now())
  ) or exists (
    select 1 from public.tennis_premium_trials_v1 t
    where t.user_id=auth.uid()
      and not exists(
        select 1 from public.billing_transactions b
        where b.user_id=t.user_id and b.kind='premium_invoice' and b.status='paid'
      )
      and (
        (not t.reserved_for_launch and t.expires_at>now())
        or
        (t.reserved_for_launch
          and exists(
            select 1 from control_center_private.tennis_premium_launch_control_v1 l
            where l.id=true and l.unpaused_at is null
          )
          and exists(
            select 1 from public.game_clock g where g.id=1 and g.is_paused
          )
        )
      )
  );
$function$
;
CREATE OR REPLACE FUNCTION public.get_my_tennis_premium_trial_v1(p_action text DEFAULT 'status'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user uuid := auth.uid();
  v_player uuid;
  v_player_created_at timestamptz;
  v_launch_scheduled timestamptz;
  v_launch_actual timestamptz;
  v_reserve_for_launch boolean := false;
  v_start_anchor timestamptz;
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

  select p.id,p.created_at into v_player,v_player_created_at from public.players p
  where p.owner_user_id=v_user and p.player_type='human'
  order by p.created_at limit 1;
  if v_player is null then return jsonb_build_object('state','not_ready'); end if;

  -- Serialize all status / creation calls for this account.
  perform pg_advisory_xact_lock(hashtext('tennis_premium_trial:'||v_user::text));

  SELECT scheduled_at,unpaused_at INTO v_launch_scheduled,v_launch_actual
  FROM control_center_private.tennis_premium_launch_control_v1 WHERE id=true;
  IF v_launch_scheduled IS NULL THEN
    RAISE EXCEPTION 'Premium trial launch configuration missing';
  END IF;
  v_reserve_for_launch := v_launch_actual IS NULL;
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
      -- Prelaunch players share the ACTUAL first-unpause timestamp.
      -- Players created after the release begin on their own first entry.
      v_start_anchor := CASE
        WHEN v_reserve_for_launch THEN v_launch_scheduled
        WHEN v_player_created_at < v_launch_actual THEN v_launch_actual
        ELSE v_now END;
      insert into public.tennis_premium_trials_v1(
        user_id,email_claim_hash,started_at,expires_at,
        reserved_for_launch,launch_cohort)
      values(v_user,v_email_hash,v_start_anchor,v_start_anchor+interval '7 days',
        v_reserve_for_launch,
        v_reserve_for_launch OR v_player_created_at < v_launch_actual)
      on conflict do nothing returning * into v_trial;
      v_started := v_trial.user_id is not null and not v_reserve_for_launch;
    end if;
  end if;

  -- A restored test account may have a reserved trial but no character at
  -- the launch moment. Start it on first game entry after creating a player.
  IF v_trial.user_id IS NOT NULL AND v_trial.reserved_for_launch
    AND NOT v_reserve_for_launch AND NOT v_paid_active AND NOT v_paid_before THEN
    v_start_anchor := CASE WHEN v_player_created_at <= v_launch_actual
      THEN v_launch_actual ELSE v_now END;
    UPDATE public.tennis_premium_trials_v1
    SET started_at=v_start_anchor,expires_at=v_start_anchor+interval '7 days',
      reserved_for_launch=false,
      launch_cohort=(v_player_created_at <= v_launch_actual),
      welcome_dismissed_at=NULL,expiry_dismissed_at=NULL,
      started_notified_at=NULL,reminder_notified_at=NULL,expired_notified_at=NULL
    WHERE user_id=v_user AND reserved_for_launch
    RETURNING * INTO v_trial;
    v_started:=true;
  END IF;

  if v_trial.user_id is null then
    return jsonb_build_object('state',case when v_paid_active then 'subscribed' else 'ineligible' end,
      'is_premium',v_paid_active,'show_welcome',false,'show_expired',false);
  end if;

  -- Reserved trials grant preview access, but spend NO days while the
  -- initial game clock remains paused. Do not emit started/expiry notices.
  IF v_trial.reserved_for_launch THEN
    IF v_paid_active OR v_paid_before THEN
      RETURN jsonb_build_object(
        'state',CASE WHEN v_paid_active THEN 'subscribed' ELSE 'ineligible' END,
        'is_premium',v_paid_active,'show_welcome',false,'show_expired',false);
    END IF;
    IF NOT v_reserve_for_launch THEN
      RAISE EXCEPTION 'Launch entitlement not activated after game unpause';
    END IF;
    RETURN jsonb_build_object(
      'state','pending_launch','is_premium',true,'trial_started',false,
      'launch_scheduled_at',v_launch_scheduled,
      'started_at',null,'expires_at',null,'seconds_left',604800,
      'show_welcome',false,'show_expired',false);
  END IF;

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
      case when v_trial.launch_cohort
        then 'tennis_premium_trial_started_launch_2026:'||v_user::text
        else 'tennis_premium_trial_started:'||v_user::text end
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
$function$
;

REVOKE EXECUTE ON FUNCTION public.get_my_tennis_premium_trial_v1(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_tennis_premium_trial_v1(text) TO authenticated,service_role;
REVOKE EXECUTE ON FUNCTION public.has_active_premium_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.has_active_premium_v1() TO authenticated,service_role;
