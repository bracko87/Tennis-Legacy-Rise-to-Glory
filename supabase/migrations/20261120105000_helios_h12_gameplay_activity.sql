-- Project Helios H12 — aggregate human-player gameplay activity, not page views.
-- This RPC is admin-only, uses existing authoritative gameplay tables and
-- never returns user/player identifiers or individual player histories.
CREATE OR REPLACE FUNCTION public.get_admin_tennis_game_activity_v1(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public','auth','pg_temp'
AS $function$
DECLARE
 v_days integer := coalesce(p_days,30);
 v_end date := (now() at time zone 'Europe/Berlin')::date;
 v_start date;
 v_start_time timestamptz;
 v_end_time timestamptz;
 v_training bigint;
 v_applications bigint;
 v_completed_matches bigint;
 v_staff bigint;
 v_equipment bigint;
 v_skill_changes bigint;
 v_active_players bigint;
 v_last_activity timestamptz;
BEGIN
 IF NOT public.is_app_admin_v1(auth.uid()) THEN
   RAISE EXCEPTION 'Admin access required' USING errcode='42501';
 END IF;
 IF v_days NOT IN (0,7,30,90,365) THEN
   RAISE EXCEPTION 'Unsupported analytics period' USING errcode='22023';
 END IF;
 v_start := CASE WHEN v_days=0 THEN date '2000-01-01' ELSE v_end-v_days+1 END;
 v_start_time := v_start::timestamp AT TIME ZONE 'Europe/Berlin';
 v_end_time := (v_end+1)::timestamp AT TIME ZONE 'Europe/Berlin';

 SELECT count(*) INTO v_training
 FROM public.player_training_sessions t JOIN public.players p ON p.id=t.player_id
 WHERE p.player_type='human' AND t.created_at>=v_start_time AND t.created_at<v_end_time;

 SELECT count(*) INTO v_applications
 FROM public.tournament_applications a JOIN public.players p ON p.id=a.player_id
 WHERE p.player_type='human' AND a.created_at>=v_start_time AND a.created_at<v_end_time;

 SELECT count(*) INTO v_completed_matches
 FROM public.tournament_matches m
 WHERE m.completed_at>=v_start_time AND m.completed_at<v_end_time
   AND EXISTS (SELECT 1 FROM public.players p WHERE p.player_type='human'
     AND (p.id=m.player1_id OR p.id=m.player2_id));

 SELECT count(*) INTO v_staff
 FROM public.player_staff_contracts sc JOIN public.players p ON p.id=sc.player_id
 WHERE p.player_type='human' AND sc.signed_at>=v_start_time AND sc.signed_at<v_end_time;

 SELECT count(*) INTO v_equipment
 FROM public.player_equipment_inventory e JOIN public.players p ON p.id=e.player_id
 WHERE p.player_type='human' AND e.created_at>=v_start_time AND e.created_at<v_end_time
   AND e.acquired_source NOT IN ('starter','initial');

 SELECT count(*) INTO v_skill_changes
 FROM public.player_skill_history h JOIN public.players p ON p.id=h.player_id
 WHERE p.player_type='human' AND h.source<>'initial'
   AND h.recorded_at>=v_start_time AND h.recorded_at<v_end_time;

 SELECT count(DISTINCT x.player_id),max(x.event_at)
 INTO v_active_players,v_last_activity
 FROM (
  SELECT t.player_id,t.created_at event_at FROM public.player_training_sessions t
  UNION ALL SELECT a.player_id,a.created_at FROM public.tournament_applications a
  UNION ALL SELECT sc.player_id,sc.signed_at FROM public.player_staff_contracts sc
  UNION ALL SELECT e.player_id,e.created_at FROM public.player_equipment_inventory e
    WHERE e.acquired_source NOT IN ('starter','initial')
  UNION ALL SELECT h.player_id,h.recorded_at FROM public.player_skill_history h WHERE h.source<>'initial'
  UNION ALL SELECT m.player1_id,m.completed_at FROM public.tournament_matches m WHERE m.completed_at IS NOT NULL
  UNION ALL SELECT m.player2_id,m.completed_at FROM public.tournament_matches m WHERE m.completed_at IS NOT NULL
 ) x JOIN public.players p ON p.id=x.player_id
 WHERE p.player_type='human' AND x.event_at>=v_start_time AND x.event_at<v_end_time;

 RETURN jsonb_build_object(
 'generated_at',now(),
 'timezone','Europe/Berlin',
 'start_date',v_start,'end_date',v_end,
 'training_sessions',v_training,
 'tournament_applications',v_applications,
 'completed_matches',v_completed_matches,
 'staff_contracts_signed',v_staff,
 'nonstarter_equipment_acquired',v_equipment,
 'skill_history_updates',v_skill_changes,
 'distinct_human_players_with_actions',v_active_players,
 'last_gameplay_event_at',v_last_activity,
 'is_game_clock_paused',(SELECT is_paused FROM public.game_clock WHERE id=1),
 'definition','Human-player actions from recorded gameplay tables only, grouped by actual event timestamps in Europe/Berlin. Excludes AI-only actions, starting equipment, initial skill snapshots and mere page views. Counts can be zero when the game is paused.'
 );
END
$function$;
REVOKE ALL ON FUNCTION public.get_admin_tennis_game_activity_v1(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_admin_tennis_game_activity_v1(integer) TO authenticated;
