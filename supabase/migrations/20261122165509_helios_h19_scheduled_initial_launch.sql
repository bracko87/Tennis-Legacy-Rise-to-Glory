CREATE OR REPLACE FUNCTION control_center_private.tennis_start_initial_launch_v1()
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE v_clock public.game_clock%ROWTYPE; v_scheduled timestamptz; v_started timestamptz; v_maintenance text;
BEGIN
  IF NOT pg_try_advisory_xact_lock(817152026,19) THEN RETURN 'busy'; END IF;
  SELECT * INTO STRICT v_clock FROM public.game_clock WHERE id=1 FOR UPDATE;
  SELECT scheduled_at,unpaused_at INTO STRICT v_scheduled,v_started FROM control_center_private.tennis_premium_launch_control_v1 WHERE id=true FOR UPDATE;
  IF v_started IS NOT NULL THEN RETURN 'already_started'; END IF;
  IF v_scheduled IS DISTINCT FROM timestamptz '2026-12-01 06:00:00+00' THEN RETURN 'schedule_changed'; END IF;
  IF clock_timestamp()<v_scheduled THEN RETURN 'not_due'; END IF;
  IF clock_timestamp()>=v_scheduled+interval '1 day' THEN RETURN 'launch_window_missed'; END IF;
  SELECT status INTO v_maintenance FROM control_center_private.tennis_season_maintenance_control_v1 WHERE id=true FOR UPDATE;
  IF v_maintenance IS DISTINCT FROM 'off' THEN RETURN 'maintenance_active'; END IF;
  IF NOT v_clock.is_paused OR v_clock.season<>1 OR v_clock.month<>1 OR v_clock.day<>1 OR v_clock.minute_of_day<>0 OR v_clock.speed_multiplier<>2 THEN RETURN 'unexpected_clock_state'; END IF;
  UPDATE public.game_clock SET is_paused=false,real_anchor_at=clock_timestamp(),updated_at=clock_timestamp() WHERE id=1;
  RETURN 'launched';
END
$function$;
REVOKE ALL ON FUNCTION control_center_private.tennis_start_initial_launch_v1() FROM PUBLIC,anon,authenticated,service_role;
SELECT cron.schedule('tennis-helios-initial-launch-v1','* * 1 12 *','SELECT control_center_private.tennis_start_initial_launch_v1();');
