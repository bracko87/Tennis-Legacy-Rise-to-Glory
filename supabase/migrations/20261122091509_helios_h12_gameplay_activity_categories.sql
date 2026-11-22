CREATE FUNCTION control_center_private.build_tennis_game_activity_v2(p_start date,p_end date) RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $activity$
WITH bounds AS (SELECT p_start::timestamp AT TIME ZONE 'Europe/Berlin' AS lo,(p_end+1)::timestamp AT TIME ZONE 'Europe/Berlin' AS hi),
players AS MATERIALIZED (
 SELECT p.id,p.player_type,p.guest_history_erased_at,g.started_at,g.converted_at,u.is_anonymous
 FROM public.players p LEFT JOIN auth.users u ON u.id=p.owner_user_id
 LEFT JOIN control_center_private.tennis_guest_trials_v1 g ON g.user_id=p.owner_user_id
), matches AS MATERIALIZED (
 SELECT 'singles'::text AS kind,m.id,m.status,m.completed_at AS event_at,ARRAY[m.player1_id,m.player2_id] AS participant_ids
 FROM public.tournament_matches m CROSS JOIN bounds b WHERE m.completed_at>=b.lo AND m.completed_at<b.hi AND m.status IN ('completed','walkover','cancelled','bye')
 UNION ALL
 SELECT 'doubles',m.id,m.status,m.completed_at,ARRAY[t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id]
 FROM public.tournament_doubles_matches m LEFT JOIN public.tournament_doubles_teams t1 ON t1.id=m.team1_id LEFT JOIN public.tournament_doubles_teams t2 ON t2.id=m.team2_id CROSS JOIN bounds b
 WHERE m.completed_at>=b.lo AND m.completed_at<b.hi AND m.status IN ('completed','walkover','cancelled','bye')
), match_categories AS (
 SELECT m.*, EXISTS(SELECT 1 FROM players p WHERE p.id=ANY(m.participant_ids) AND p.player_type='human') AS human,
 EXISTS(SELECT 1 FROM players p WHERE p.id=ANY(m.participant_ids) AND p.player_type='human' AND (p.guest_history_erased_at IS NOT NULL OR (p.started_at IS NOT NULL AND m.event_at>=p.started_at AND (p.converted_at IS NULL OR m.event_at<p.converted_at)))) AS guest,
 EXISTS(SELECT 1 FROM players p WHERE p.id=ANY(m.participant_ids) AND p.player_type='human' AND p.guest_history_erased_at IS NULL AND p.is_anonymous IS FALSE AND (p.started_at IS NULL OR m.event_at>=p.converted_at)) AS permanent,
 (SELECT count(DISTINCT p.id) FROM players p WHERE p.id=ANY(m.participant_ids) AND p.player_type='ai')=CASE WHEN m.kind='singles' THEN 2 ELSE 4 END AS ai_only
 FROM matches m
), events AS MATERIALIZED (
 SELECT 'training_sessions'::text AS kind,t.player_id,t.created_at AS event_at FROM public.player_training_sessions t CROSS JOIN bounds b WHERE t.created_at>=b.lo AND t.created_at<b.hi
 UNION ALL SELECT 'tournament_applications',a.player_id,a.created_at FROM public.tournament_applications a CROSS JOIN bounds b WHERE a.created_at>=b.lo AND a.created_at<b.hi
 UNION ALL SELECT 'staff_contracts_signed',s.player_id,s.signed_at FROM public.player_staff_contracts s CROSS JOIN bounds b WHERE s.signed_at>=b.lo AND s.signed_at<b.hi
 UNION ALL SELECT 'nonstarter_equipment_acquired',e.player_id,e.created_at FROM public.player_equipment_inventory e CROSS JOIN bounds b WHERE e.created_at>=b.lo AND e.created_at<b.hi AND e.acquired_source NOT IN ('starter','initial')
 UNION ALL SELECT 'skill_history_updates',h.player_id,h.recorded_at FROM public.player_skill_history h CROSS JOIN bounds b WHERE h.recorded_at>=b.lo AND h.recorded_at<b.hi AND h.source<>'initial'
 UNION ALL SELECT 'match_participations',x.player_id,m.event_at FROM matches m CROSS JOIN LATERAL (SELECT DISTINCT id AS player_id FROM unnest(m.participant_ids) id WHERE id IS NOT NULL) x WHERE m.status='completed'
), classified AS MATERIALIZED (
 SELECT e.*,CASE WHEN p.player_type='ai' THEN 'ai' WHEN p.player_type='human' AND (p.guest_history_erased_at IS NOT NULL OR (p.started_at IS NOT NULL AND e.event_at>=p.started_at AND (p.converted_at IS NULL OR e.event_at<p.converted_at))) THEN 'guest'
 WHEN p.player_type='human' AND p.is_anonymous IS FALSE AND (p.started_at IS NULL OR e.event_at>=p.converted_at) THEN 'permanent' ELSE 'unknown' END AS category,p.player_type
 FROM events e JOIN players p ON p.id=e.player_id
), activity AS (
 SELECT jsonb_object_agg(k.kind,jsonb_build_object('permanent',(SELECT count(*) FROM classified e WHERE e.kind=k.kind AND e.category='permanent'),'guest',(SELECT count(*) FROM classified e WHERE e.kind=k.kind AND e.category='guest'),'ai',(SELECT count(*) FROM classified e WHERE e.kind=k.kind AND e.category='ai'),'unknown',(SELECT count(*) FROM classified e WHERE e.kind=k.kind AND e.category='unknown'))) AS payload
 FROM (VALUES ('training_sessions'),('tournament_applications'),('staff_contracts_signed'),('nonstarter_equipment_acquired'),('skill_history_updates'),('match_participations')) k(kind)
)
SELECT jsonb_build_object(
 'generated_at',now(),'timezone','Europe/Berlin','start_date',p_start,'end_date',p_end,
 'training_sessions',(SELECT count(*) FROM classified WHERE player_type='human' AND kind='training_sessions'),
 'tournament_applications',(SELECT count(*) FROM classified WHERE player_type='human' AND kind='tournament_applications'),
 'completed_matches',(SELECT count(*) FROM match_categories WHERE human AND status='completed'),
 'completed_singles_matches',(SELECT count(*) FROM match_categories WHERE human AND status='completed' AND kind='singles'),
 'completed_doubles_matches',(SELECT count(*) FROM match_categories WHERE human AND status='completed' AND kind='doubles'),
 'human_walkovers',(SELECT count(*) FROM match_categories WHERE human AND status='walkover'),
 'human_cancelled_matches',(SELECT count(*) FROM match_categories WHERE human AND status='cancelled'),
 'ai_only_completed_matches',(SELECT count(*) FROM match_categories WHERE ai_only AND status='completed'),
 'guest_involved_completed_matches',(SELECT count(*) FROM match_categories WHERE guest AND status='completed'),
 'permanent_involved_completed_matches',(SELECT count(*) FROM match_categories WHERE permanent AND status='completed'),
 'staff_contracts_signed',(SELECT count(*) FROM classified WHERE player_type='human' AND kind='staff_contracts_signed'),
 'nonstarter_equipment_acquired',(SELECT count(*) FROM classified WHERE player_type='human' AND kind='nonstarter_equipment_acquired'),
 'skill_history_updates',(SELECT count(*) FROM classified WHERE player_type='human' AND kind='skill_history_updates'),
 'distinct_human_players_with_actions',(SELECT count(DISTINCT player_id) FROM classified WHERE player_type='human'),
 'last_gameplay_event_at',(SELECT max(event_at) FROM classified WHERE player_type='human'),
 'activity_by_player_type',(SELECT payload FROM activity),
 'is_game_clock_paused',(SELECT is_paused FROM public.game_clock WHERE id=1),
 'definition','Recorded gameplay events by Berlin calendar date, not manual clicks. Completed singles and doubles matches count once each; walkovers and cancellations are separate. Guest/permanent match involvement may overlap. Participant activity counts each distinct participant per played match. Guest classification uses event time relative to conversion; erased guest match history remains attributable, but deleted activity records are not recoverable. Unknown classifications are reported separately.')
$activity$;
REVOKE ALL ON FUNCTION control_center_private.build_tennis_game_activity_v2(date,date) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.get_admin_tennis_game_activity_v1(p_days integer DEFAULT 30) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $admin$
DECLARE v_days integer:=coalesce(p_days,30); v_end date:=(now() AT TIME ZONE 'Europe/Berlin')::date;
BEGIN
 IF NOT public.is_app_admin_v1(auth.uid()) THEN RAISE EXCEPTION 'Admin access required' USING errcode='42501'; END IF;
 IF v_days NOT IN (0,7,30,90,365) THEN RAISE EXCEPTION 'Unsupported analytics period' USING errcode='22023'; END IF;
 RETURN control_center_private.build_tennis_game_activity_v2(CASE WHEN v_days=0 THEN date '2000-01-01' ELSE v_end-v_days+1 END,v_end);
END
$admin$;
REVOKE ALL ON FUNCTION public.get_admin_tennis_game_activity_v1(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_admin_tennis_game_activity_v1(integer) TO authenticated;
