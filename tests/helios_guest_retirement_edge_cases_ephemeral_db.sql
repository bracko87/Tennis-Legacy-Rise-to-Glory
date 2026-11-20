-- Helios H08 edge-cases: only disposable PostgreSQL worker snapshots.
-- This fixture has no production credentials and rolls back all changes.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '45s';

DO $edge$
DECLARE
 u1 uuid := gen_random_uuid();
 u2 uuid := gen_random_uuid();
 p1 uuid;
 p2 uuid;
 ai1 uuid;
 ai2 uuid;
 ai3 uuid;
 comp uuid;
 singles uuid;
 inprogress uuid;
 historical uuid;
 dteam1 uuid;
 dteam2 uuid;
 doubles uuid;
 v_status text;
 v_winner uuid;
 v_doubles_winner uuid;
 v_results jsonb;
 v_n int;
BEGIN
 SELECT id INTO ai1 FROM public.players WHERE player_type='ai' ORDER BY id LIMIT 1;
 SELECT id INTO ai2 FROM public.players WHERE player_type='ai' AND id<>ai1 ORDER BY id LIMIT 1;
 SELECT id INTO ai3 FROM public.players WHERE player_type='ai' AND id NOT IN(ai1,ai2) ORDER BY id LIMIT 1;
 SELECT id INTO comp FROM public.tournament_world_competitions LIMIT 1;
 IF comp IS NULL OR ai3 IS NULL THEN
   RAISE EXCEPTION 'Edge fixture requires competition and three seeded AI players';
 END IF;

 INSERT INTO auth.users(id,is_anonymous) VALUES(u1,true),(u2,true);
 INSERT INTO control_center_private.tennis_guest_trials_v1(user_id,started_at,expires_at)
 VALUES (u1,now()-interval '15 days',now()-interval '1 day'),
        (u2,now()-interval '15 days',now()-interval '1 day');
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES(u1,'Guest','Expired One','DE','ATP','human') RETURNING id INTO p1;
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES(u2,'Guest','Expired Two','DE','ATP','human') RETURNING id INTO p2;

 -- Both singles players expired: cancel rather than grant a false win.
 INSERT INTO public.tournament_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,player1_id,player2_id,status)
 VALUES(comp,1,'Semifinal',70,4,1,1,p1,p2,'scheduled')
 RETURNING id INTO singles;

 -- In-progress match remains unchanged even after guest expiration.
 INSERT INTO public.tournament_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,player1_id,player2_id,status,started_at)
 VALUES(comp,1,'Semifinal',71,4,1,1,p1,ai1,'in_progress',now()-interval '1 hour')
 RETURNING id INTO inprogress;

 -- Completed historical result stays intact.
 INSERT INTO public.tournament_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,
    status,started_at,completed_at)
 VALUES(comp,1,'Semifinal',72,4,1,1,p2,ai2,p2,'completed',
        now()-interval '3 days',now()-interval '2 days')
 RETURNING id INTO historical;

 -- Two doubles teams, each containing an expired guest.
 INSERT INTO public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source)
 VALUES(comp,'ATP',p1,ai1,'active','human') RETURNING id INTO dteam1;
 INSERT INTO public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source)
 VALUES(comp,'ATP',p2,ai2,'active','human') RETURNING id INTO dteam2;
 INSERT INTO public.tournament_doubles_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,team1_id,team2_id,status)
 VALUES(comp,1,'Semifinal',70,4,1,1,dteam1,dteam2,'scheduled')
 RETURNING id INTO doubles;

 SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO v_results;
 IF (v_results->>'retired_guests')::int<>2 THEN
   RAISE EXCEPTION 'Expected two expired guests, got %',v_results;
 END IF;

 SELECT status,winner_id INTO v_status,v_winner
 FROM public.tournament_matches WHERE id=singles;
 IF v_status<>'cancelled' OR v_winner IS NOT NULL THEN
   RAISE EXCEPTION 'Expired vs expired must cancel with no winner: % / %',v_status,v_winner;
 END IF;

 SELECT status,winner_team_id INTO v_status,v_doubles_winner
 FROM public.tournament_doubles_matches WHERE id=doubles;
 IF v_status<>'cancelled' OR v_doubles_winner IS NOT NULL THEN
   RAISE EXCEPTION 'Expired doubles teams must cancel: % / %',v_status,v_doubles_winner;
 END IF;
 SELECT count(*) INTO v_n FROM public.tournament_doubles_teams
 WHERE id IN(dteam1,dteam2) AND status='withdrawn';
 IF v_n<>2 THEN RAISE EXCEPTION 'Both expired doubles teams must withdraw'; END IF;

 SELECT status,winner_id INTO v_status,v_winner
 FROM public.tournament_matches WHERE id=inprogress;
 IF v_status<>'in_progress' OR v_winner IS NOT NULL THEN
   RAISE EXCEPTION 'Worker changed an in-progress match: % / %',v_status,v_winner;
 END IF;
 SELECT status,winner_id INTO v_status,v_winner
 FROM public.tournament_matches WHERE id=historical;
 IF v_status<>'completed' OR v_winner IS DISTINCT FROM p2 THEN
   RAISE EXCEPTION 'Worker changed completed match: % / %',v_status,v_winner;
 END IF;
 SELECT count(*) INTO v_n FROM control_center_private.tennis_guest_trials_v1
 WHERE user_id IN(u1,u2) AND retired_at IS NOT NULL;
 IF v_n<>2 THEN RAISE EXCEPTION 'Both guests should be marked retired'; END IF;

 SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO v_results;
 IF (v_results->>'retired_guests')::int<>0 THEN
   RAISE EXCEPTION 'Repeated retirement should be idempotent: %',v_results;
 END IF;
 RAISE NOTICE 'H08 edge PASS: double-expiry cancelled, active match untouched, completed outcome kept, idempotent';
END;
$edge$;
ROLLBACK;
