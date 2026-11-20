-- H08 regression coverage for guest expiry edge cases. Run ONLY in the
-- disposable PostgreSQL CI service after authoritative worker/trigger snapshots.
-- A transaction rolls back every synthetic user/player/match mutation.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='75s';
UPDATE public.registration_control SET guest_test_enabled=true WHERE singleton_id=true;

DO $test$
DECLARE
 v_user_a uuid:=gen_random_uuid();
 v_user_b uuid:=gen_random_uuid();
 v_converted uuid:=gen_random_uuid();
 v_a uuid;
 v_b uuid;
 v_perm uuid;
 v_ai uuid;
 v_comp uuid;
 v_cross uuid;
 v_ongoing uuid;
 v_simulated uuid;
 v_future uuid;
 v_historical uuid;
 v_app uuid;
 v_entry uuid;
 v_result jsonb;
 v_status text;
 v_winner uuid;
 v_count integer;
BEGIN
 SELECT id INTO v_ai FROM public.players WHERE player_type='ai' AND world='ATP' ORDER BY id LIMIT 1;
 SELECT id INTO v_comp FROM public.tournament_world_competitions WHERE world='ATP' ORDER BY id LIMIT 1;
 IF v_ai IS NULL OR v_comp IS NULL THEN
   RAISE EXCEPTION 'H08 edge fixture requires AI opponent and ATP competition';
 END IF;

 INSERT INTO auth.users(id,instance_id,aud,role,is_anonymous)
 VALUES (v_user_a,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',true),
        (v_user_b,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',true),
        (v_converted,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',false);
 INSERT INTO control_center_private.tennis_guest_trials_v1
  (user_id,started_at,expires_at,converted_at)
 VALUES (v_user_a,now()-interval '15 days',now()-interval '1 day',null),
        (v_user_b,now()-interval '16 days',now()-interval '2 days',null),
        (v_converted,now()-interval '17 days',now()-interval '3 days',now()-interval '4 days');

 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES (v_user_a,'Test','Expired A','DE','ATP','human') RETURNING id INTO v_a;
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES (v_user_b,'Test','Expired B','DE','ATP','human') RETURNING id INTO v_b;
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES (v_converted,'Test','Converted','DE','ATP','human') RETURNING id INTO v_perm;

 -- Both expired opponents: never award a fabricated winner.
 INSERT INTO public.tournament_matches(
   competition_id,draw_type,round_number,round_label,match_number,bracket_size,
   scheduled_season_week,scheduled_day,player1_id,player2_id,status)
 VALUES(v_comp,'main_draw',1,'Round 1',31,64,1,1,v_a,v_b,'scheduled')
 RETURNING id INTO v_cross;

 -- Live matches must not be rewritten, even if the player has expired.
 INSERT INTO public.tournament_matches(
   competition_id,draw_type,round_number,round_label,match_number,bracket_size,
   scheduled_season_week,scheduled_day,player1_id,player2_id,status,started_at)
 VALUES(v_comp,'main_draw',1,'Round 1',32,64,1,1,v_a,v_ai,'in_progress',now()-interval '20 minutes')
 RETURNING id INTO v_ongoing;

 -- Simulation already exists: worker must leave the scheduled match alone.
 INSERT INTO public.tournament_matches(
   competition_id,draw_type,round_number,round_label,match_number,bracket_size,
   scheduled_season_week,scheduled_day,player1_id,player2_id,status)
 VALUES(v_comp,'main_draw',1,'Round 1',33,64,1,1,v_a,v_ai,'scheduled')
 RETURNING id INTO v_simulated;
 INSERT INTO public.tournament_match_simulations(match_id) VALUES(v_simulated);

 -- Converted former guest remains eligible regardless of old timestamp.
 INSERT INTO public.tournament_matches(
   competition_id,draw_type,round_number,round_label,match_number,bracket_size,
   scheduled_season_week,scheduled_day,player1_id,player2_id,status)
 VALUES(v_comp,'main_draw',1,'Round 1',34,64,1,1,v_perm,v_ai,'scheduled')
 RETURNING id INTO v_future;

 -- Completed match stays immutable.
 INSERT INTO public.tournament_matches(
   competition_id,draw_type,round_number,round_label,match_number,bracket_size,
   scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,
   status,started_at,completed_at)
 VALUES(v_comp,'main_draw',1,'Round 1',35,64,1,1,v_a,v_ai,v_a,
        'completed',now()-interval '3 hours',now()-interval '2 hours')
 RETURNING id INTO v_historical;

 INSERT INTO public.tournament_applications(
   competition_id,player_id,status)
 VALUES(v_comp,v_a,'accepted_main_draw') RETURNING id INTO v_app;
 INSERT INTO public.tournament_entries(
   competition_id,player_id,entry_status)
 VALUES(v_comp,v_a,'active') RETURNING id INTO v_entry;

 SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO v_result;
 IF (v_result->>'retired_guests')::int<>2
 THEN RAISE EXCEPTION 'Expected exactly two retired anonymous guests, got %',v_result; END IF;

 SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches WHERE id=v_cross;
 IF v_status<>'cancelled' OR v_winner IS NOT NULL
 THEN RAISE EXCEPTION 'Expired-v-expired must cancel without winner, got % %',v_status,v_winner; END IF;

 SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches WHERE id=v_ongoing;
 IF v_status<>'in_progress' OR v_winner IS NOT NULL
 THEN RAISE EXCEPTION 'Already started match was modified: % %',v_status,v_winner; END IF;

 SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches WHERE id=v_simulated;
 IF v_status<>'scheduled' OR v_winner IS NOT NULL
 THEN RAISE EXCEPTION 'Match with existing simulation was modified: % %',v_status,v_winner; END IF;

 SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches WHERE id=v_future;
 IF v_status<>'scheduled' OR v_winner IS NOT NULL
 THEN RAISE EXCEPTION 'Converted guest should remain eligible: % %',v_status,v_winner; END IF;

 SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches WHERE id=v_historical;
 IF v_status<>'completed' OR v_winner IS DISTINCT FROM v_a
 THEN RAISE EXCEPTION 'Historical winner lost: % %',v_status,v_winner; END IF;

 IF (SELECT status FROM public.tournament_applications WHERE id=v_app)<>'withdrawn'
 THEN RAISE EXCEPTION 'Future application was not withdrawn'; END IF;
 IF (SELECT entry_status FROM public.tournament_entries WHERE id=v_entry)<>'withdrawn'
 THEN RAISE EXCEPTION 'Future entry was not withdrawn'; END IF;
 IF (SELECT moderation_status FROM public.players WHERE id=v_a)<>'rejected'
    OR (SELECT moderation_status FROM public.players WHERE id=v_b)<>'rejected'
 THEN RAISE EXCEPTION 'Retired guests still active in rankings'; END IF;
 IF (SELECT moderation_status FROM public.players WHERE id=v_perm)<>'approved'
 THEN RAISE EXCEPTION 'Converted former guest was incorrectly hidden'; END IF;
 IF EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1
           WHERE user_id=v_converted AND retired_at IS NOT NULL)
 THEN RAISE EXCEPTION 'Converted guest incorrectly retired'; END IF;

 SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO v_result;
 IF (v_result->>'retired_guests')::int<>0
 THEN RAISE EXCEPTION 'Second run should be idempotent: %',v_result; END IF;

 SELECT count(*) INTO v_count FROM auth.users WHERE id IN(v_user_a,v_user_b,v_converted);
 IF v_count<>3 THEN RAISE EXCEPTION 'Physical Auth deletion must remain disabled'; END IF;

 RAISE NOTICE 'H08 edge cases PASS: double expiry, in-progress, simulation lock, converted identity, history, withdrawals, repeat run, no hard-delete';
END;
$test$;
ROLLBACK;
