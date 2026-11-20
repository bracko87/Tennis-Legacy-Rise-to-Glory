-- Project Helios H08: isolated full-Supabase database fixture only.
-- CI runs this inside a disposable local Supabase Docker/Postgres instance.
-- Never execute against the live game database. Entire test is rolled back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '75s';
-- The guest feature is ON only within this rolled-back test transaction.
UPDATE public.registration_control SET guest_test_enabled=true WHERE singleton_id=true;

DO $guest_retirement_qa$
DECLARE
  v_user uuid:=gen_random_uuid();
  v_guest uuid;
  v_opponent uuid;
  v_opponent2 uuid;
  v_opponent3 uuid;
  v_country text;
  v_comp uuid;
  v_match uuid;
  v_historical uuid;
  v_team_guest uuid;
  v_team_other uuid;
  v_doubles uuid;
  v_status text;
  v_winner uuid;
  v_advances integer;
  v_result jsonb;
  v_n integer;
BEGIN
  SELECT p.id,p.country_code INTO v_opponent,v_country
  FROM public.players p
  WHERE p.world='ATP' AND p.player_type='ai'
  ORDER BY p.id LIMIT 1;
  SELECT p.id INTO v_opponent2 FROM public.players p
  WHERE p.world='ATP' AND p.player_type='ai' AND p.id<>v_opponent ORDER BY p.id LIMIT 1;
  SELECT p.id INTO v_opponent3 FROM public.players p
  WHERE p.world='ATP' AND p.player_type='ai' AND p.id NOT IN(v_opponent,v_opponent2) ORDER BY p.id LIMIT 1;
  SELECT id INTO v_comp FROM public.tournament_world_competitions
  WHERE world='ATP' ORDER BY id LIMIT 1;
  IF v_opponent IS NULL OR v_opponent2 IS NULL OR v_opponent3 IS NULL OR v_comp IS NULL THEN
    RAISE EXCEPTION 'H08 fixture requires seeded ATP AI players and an ATP competition';
  END IF;

  -- First-time anonymous user only, with valid temporary 14-day guest identity.
  INSERT INTO auth.users (id,instance_id,aud,role,is_anonymous,raw_app_meta_data,raw_user_meta_data)
  VALUES (v_user,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',true,
          '{"provider":"anonymous","providers":["anonymous"]}'::jsonb,'{}'::jsonb);
  INSERT INTO control_center_private.tennis_guest_trials_v1(user_id,started_at,expires_at)
  VALUES (v_user,now()-interval '1 day',now()+interval '13 days');
  PERFORM set_config('request.jwt.claim.sub',v_user::text,true);
  INSERT INTO public.players(
    owner_user_id,first_name,last_name,country_code,world,image_path,
    player_type,playing_style,playing_hand,home_city
  ) VALUES (
    v_user,'Test','Retiring',v_country,'ATP','fixtures/guest-default.webp',
    'human','All-court','right',null
  ) RETURNING id INTO v_guest;
  PERFORM set_config('request.jwt.claim.sub','',true);

  -- Previous completed match: verify retirement never changes its outcome.
  INSERT INTO public.tournament_matches(
    competition_id,draw_type,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,
    status,started_at,completed_at,completion_reason
  ) VALUES (
    v_comp,'main_draw',1,'Final',99,2,1,1,
    v_guest,v_opponent2,v_opponent2,'completed',now()-interval '3 hours',now()-interval '1 hour',null
  ) RETURNING id INTO v_historical;

  -- Unstarted singles match with an eligible opponent.
  INSERT INTO public.tournament_matches(
    competition_id,draw_type,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,player1_id,player2_id,status
  ) VALUES (
    v_comp,'main_draw',1,'Semifinal',1,4,1,1,v_guest,v_opponent,'scheduled'
  ) RETURNING id INTO v_match;

  -- Unstarted doubles match; guest's partner should not continue with them.
  INSERT INTO public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source,
    combined_ranking_points_snapshot,entry_strength_snapshot
  ) VALUES (
    v_comp,'ATP',v_guest,v_opponent2,'active','human',0,0
  ) RETURNING id INTO v_team_guest;
  INSERT INTO public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source,
    combined_ranking_points_snapshot,entry_strength_snapshot
  ) VALUES (
    v_comp,'ATP',v_opponent,v_opponent3,'active','ai',0,0
  ) RETURNING id INTO v_team_other;
  INSERT INTO public.tournament_doubles_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,team1_id,team2_id,status
  ) VALUES (
    v_comp,1,'Semifinal',1,4,1,1,v_team_guest,v_team_other,'scheduled'
  ) RETURNING id INTO v_doubles;

  -- Expiry is server-owned and the exact 14-day constraint is preserved.
  UPDATE control_center_private.tennis_guest_trials_v1
  SET started_at=now()-interval '15 days',expires_at=now()-interval '1 day'
  WHERE user_id=v_user;

  SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO v_result;
  IF (v_result->>'retired_guests')::integer<>1 THEN
    RAISE EXCEPTION 'H08 expected 1 guest retired: %',v_result;
  END IF;
  SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches WHERE id=v_match;
  IF v_status<>'walkover' OR v_winner IS DISTINCT FROM v_opponent THEN
    RAISE EXCEPTION 'H08 singles opponent must win walkover, got % / %',v_status,v_winner;
  END IF;
  SELECT count(*) INTO v_advances FROM public.tournament_matches
  WHERE competition_id=v_comp AND draw_type='main_draw' AND round_number=2
    AND (player1_id=v_opponent OR player2_id=v_opponent);
  IF v_advances<1 THEN
    RAISE EXCEPTION 'H08 singles bracket did not advance walkover winner';
  END IF;

  SELECT status,winner_team_id INTO v_status,v_winner
    FROM public.tournament_doubles_matches WHERE id=v_doubles;
  IF v_status<>'walkover' OR v_winner IS DISTINCT FROM v_team_other THEN
    RAISE EXCEPTION 'H08 doubles opponent team must win walkover: % / %',v_status,v_winner;
  END IF;
  SELECT status INTO v_status FROM public.tournament_doubles_teams WHERE id=v_team_guest;
  IF v_status<>'withdrawn' THEN
    RAISE EXCEPTION 'H08 guest doubles team not withdrawn';
  END IF;
  SELECT status,winner_id INTO v_status,v_winner FROM public.tournament_matches
    WHERE id=v_historical;
  IF v_status<>'completed' OR v_winner IS DISTINCT FROM v_opponent2 THEN
    RAISE EXCEPTION 'H08 historical match was changed: % / %',v_status,v_winner;
  END IF;
  SELECT count(*) INTO v_n FROM control_center_private.tennis_guest_trials_v1
  WHERE user_id=v_user AND retired_at IS NOT NULL;
  IF v_n<>1 THEN RAISE EXCEPTION 'H08 retirement marker absent'; END IF;
  SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO v_result;
  IF (v_result->>'retired_guests')::integer<>0 THEN
    RAISE EXCEPTION 'H08 repeated worker should do nothing: %',v_result;
  END IF;

  RAISE NOTICE 'H08 PASS: one expired guest retired; singles/doubles walkovers and bracket advancement verified; historical completed match intact; worker idempotent';
END;
$guest_retirement_qa$;
ROLLBACK;
