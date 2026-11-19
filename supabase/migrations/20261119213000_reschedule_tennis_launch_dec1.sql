-- Supersedes the previous November 23 release schedule, without starting the game clock.
-- Preserve accounts, existing player data, and previously earned purchases.
UPDATE control_center_private.tennis_premium_launch_control_v1
SET scheduled_at='2026-12-01 07:00:00+01'::timestamptz, updated_at=now()
WHERE id=true AND unpaused_at IS NULL AND scheduled_at='2026-11-23 07:00:00+01'::timestamptz;

UPDATE public.tennis_premium_trials_v1
SET started_at='2026-12-01 07:00:00+01'::timestamptz,
    expires_at='2026-12-08 07:00:00+01'::timestamptz
WHERE reserved_for_launch AND launch_cohort
  AND started_at='2026-11-23 07:00:00+01'::timestamptz
  AND expires_at='2026-11-30 07:00:00+01'::timestamptz;

CREATE OR REPLACE FUNCTION control_center_private.tennis_activate_launch_trials_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'control_center_private', 'public', 'pg_temp'
AS $function$
DECLARE v_release timestamptz;v_scheduled timestamptz;
BEGIN
 IF NOT OLD.is_paused OR NEW.is_paused OR NEW.id<>1 THEN RETURN NEW;END IF;
 SELECT scheduled_at INTO v_scheduled
 FROM control_center_private.tennis_premium_launch_control_v1 WHERE id=true FOR UPDATE;
 IF v_scheduled IS NULL THEN RAISE EXCEPTION 'Premium launch gate is missing'; END IF;
 IF clock_timestamp()<v_scheduled THEN
   RAISE EXCEPTION 'Game launch cannot begin before 1 December 2026 at 07:00 German time';
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
END $function$
;
