\set ON_ERROR_STOP on
-- Never invoke outside the CI disposable database. Guard runs before any mutation.
BEGIN;
SET LOCAL statement_timeout='40s';
SELECT set_config('helios.qa_guest', :'guest_id', true);
SELECT set_config('helios.qa_phase', :'phase', true);
DO $qa$
DECLARE uid uuid:=current_setting('helios.qa_guest')::uuid;
 ph text:=current_setting('helios.qa_phase');
 p uuid; a uuid; b uuid; c uuid; comp uuid; m uuid;
 team_guest uuid; team_other uuid; result jsonb;
BEGIN
 IF to_regclass('control_center_private.helios_real_auth_ci_marker') IS NULL
 THEN RAISE EXCEPTION 'CI database marker missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM control_center_private.helios_real_auth_ci_marker WHERE id)
 THEN RAISE EXCEPTION 'Invalid CI database marker'; END IF;
 IF ph='gate_off' OR ph='gate_on' THEN
   UPDATE public.registration_control SET guest_test_enabled=(ph='gate_on') WHERE singleton_id=true;
   RETURN;
 END IF;
 SELECT id INTO STRICT p FROM public.players WHERE owner_user_id=uid AND player_type='human';
 IF ph='seed' THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND is_anonymous) THEN RAISE EXCEPTION 'Expected synthetic real Auth guest'; END IF;
   INSERT INTO public.helios_ci_equipment VALUES(p,73);
   INSERT INTO public.helios_ci_career_finance VALUES(p,1234);
 ELSIF ph='verify_converted' THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND NOT is_anonymous)
      OR NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=uid AND converted_at IS NOT NULL AND retired_at IS NULL)
      OR NOT EXISTS(SELECT 1 FROM public.helios_ci_equipment WHERE player_id=p AND condition_percent=73)
      OR NOT EXISTS(SELECT 1 FROM public.helios_ci_career_finance WHERE player_id=p AND balance=1234)
      OR NOT EXISTS(SELECT 1 FROM public.tennis_premium_trials_v1 WHERE user_id=uid AND expires_at=started_at+interval '7 days')
   THEN RAISE EXCEPTION 'Conversion lost original ownership, progress or Premium'; END IF;
 ELSIF ph='expire' THEN
   SELECT id INTO a FROM public.players WHERE player_type='ai' ORDER BY id LIMIT 1;
   SELECT id INTO b FROM public.players WHERE player_type='ai' AND id<>a ORDER BY id LIMIT 1;
   SELECT id INTO c FROM public.players WHERE player_type='ai' AND id NOT IN(a,b) ORDER BY id LIMIT 1;
   SELECT id INTO STRICT comp FROM public.tournament_world_competitions WHERE world='ATP';
   INSERT INTO public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,status)
   VALUES(comp,'main_draw',1,'Semifinal',1,4,1,1,p,a,'scheduled');
   INSERT INTO public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,status,started_at,completed_at)
   VALUES(comp,'main_draw',1,'Historical',99,2,1,1,p,b,b,'completed',now()-interval '3 hours',now()-interval '1 hour');
   INSERT INTO public.tournament_doubles_teams(competition_id,world,player1_id,player2_id,status,entry_source,combined_ranking_points_snapshot,entry_strength_snapshot)
   VALUES(comp,'ATP',p,b,'active','human',0,0) RETURNING id INTO team_guest;
   INSERT INTO public.tournament_doubles_teams(competition_id,world,player1_id,player2_id,status,entry_source,combined_ranking_points_snapshot,entry_strength_snapshot)
   VALUES(comp,'ATP',a,c,'active','ai',0,0) RETURNING id INTO team_other;
   INSERT INTO public.tournament_doubles_matches(competition_id,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,team1_id,team2_id,status)
   VALUES(comp,1,'Semifinal',1,4,1,1,team_guest,team_other,'scheduled');
   INSERT INTO public.tournament_applications(competition_id,player_id,status) VALUES(comp,p,'accepted_main_draw');
   INSERT INTO public.tournament_entries(competition_id,player_id,entry_status) VALUES(comp,p,'active');
   UPDATE control_center_private.tennis_guest_trials_v1 SET started_at=now()-interval '15 days',expires_at=now()-interval '1 day' WHERE user_id=uid AND converted_at IS NULL;
   UPDATE public.tennis_premium_trials_v1 SET started_at=now()-interval '15 days',expires_at=now()-interval '8 days' WHERE user_id=uid;
 ELSIF ph='retire' THEN
   SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'retired_guests')::int IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Expected exactly one retired real-auth guest'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_matches WHERE player1_id=p AND match_number=1 AND status='walkover' AND winner_id=player2_id)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_matches WHERE player1_id=p AND match_number=99 AND status='completed' AND winner_id=player2_id)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_matches h JOIN public.tournament_matches n ON n.competition_id=h.competition_id AND n.round_number=2 AND (n.player1_id=h.winner_id OR n.player2_id=h.winner_id) WHERE h.player1_id=p AND h.match_number=1)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_doubles_teams t JOIN public.tournament_doubles_matches m ON m.team1_id=t.id WHERE t.player1_id=p AND t.status='withdrawn' AND m.status='walkover' AND m.winner_team_id=m.team2_id)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_applications WHERE player_id=p AND status='withdrawn')
     OR NOT EXISTS(SELECT 1 FROM public.tournament_entries WHERE player_id=p AND entry_status='withdrawn')
     OR NOT EXISTS(SELECT 1 FROM public.players WHERE id=p AND moderation_status='rejected')
   THEN RAISE EXCEPTION 'Real Auth guest retirement did not preserve history and resolve scheduled entries'; END IF;
   SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'retired_guests')::int IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Retirement must be idempotent'; END IF;
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND is_anonymous)
     OR NOT EXISTS(SELECT 1 FROM public.helios_ci_equipment WHERE player_id=p AND condition_percent=73)
     OR NOT EXISTS(SELECT 1 FROM public.helios_ci_career_finance WHERE player_id=p AND balance=1234)
   THEN RAISE EXCEPTION 'Retirement must not silently delete Auth or career records'; END IF;
 ELSIF ph='verify_retired' THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND is_anonymous)
     OR NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=uid AND retired_at IS NOT NULL AND converted_at IS NULL)
   THEN RAISE EXCEPTION 'Retired account was unexpectedly converted'; END IF;
 ELSE RAISE EXCEPTION 'Unknown CI phase';
 END IF;
END
$qa$;
COMMIT;
