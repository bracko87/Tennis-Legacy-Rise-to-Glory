-- Project Helios H08: disposable PostgreSQL proof of a historical guest tombstone.
-- NEVER run against production. Uses minimal tournament schema, NOT full Supabase.
-- Called by helios-guest-retirement-integration.yml after fixture schema load.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '30s';

-- Match the real player ownership cascading behavior inside this rollback-only test.
ALTER TABLE public.players DROP CONSTRAINT players_owner_user_id_fkey;
ALTER TABLE public.players ADD CONSTRAINT players_owner_user_id_fkey
  FOREIGN KEY (owner_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

DO $proof$
DECLARE
 v_guest_user uuid := gen_random_uuid();
 v_guest uuid;
 v_opponent uuid;
 v_comp uuid;
 v_match uuid;
 v_winner uuid;
 v_first text;
 v_last text;
 v_owner uuid;
 v_n integer;
 v_registered_user uuid := gen_random_uuid();
 v_registered_player uuid;
 v_doubles_team uuid;
 v_doubles_match uuid;
 v_expired_without_retirement uuid:=gen_random_uuid();
 v_active_player uuid;
 v_active_user uuid:=gen_random_uuid();
BEGIN
 SELECT id INTO v_opponent FROM public.players WHERE player_type='ai' ORDER BY id LIMIT 1;
 SELECT id INTO v_comp FROM public.tournament_world_competitions LIMIT 1;
 IF v_opponent IS NULL OR v_comp IS NULL THEN
   RAISE EXCEPTION 'H08 tombstone fixture requires seeded opponent and competition';
 END IF;

 INSERT INTO auth.users(id,is_anonymous) VALUES(v_guest_user,true);
 INSERT INTO control_center_private.tennis_guest_trials_v1(
    user_id,started_at,expires_at,retired_at)
 VALUES(v_guest_user,now()-interval '15 days',now()-interval '1 day',now()-interval '1 day');
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type,moderation_status)
 VALUES(v_guest_user,'Private','Guest Name','DE','ATP','human','rejected')
 RETURNING id INTO v_guest;
 INSERT INTO public.tournament_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,
    status,started_at,completed_at)
 VALUES(v_comp,1,'Final',80,2,1,1,v_guest,v_opponent,v_guest,
    'completed',now()-interval '2 days',now()-interval '1 day')
 RETURNING id INTO v_match;

 -- A completed doubles result must preserve the historical team and player.
 INSERT INTO public.tournament_doubles_teams(
    competition_id,world,player1_id,player2_id,status,entry_source)
 VALUES(v_comp,'ATP',v_guest,v_opponent,'active','human')
 RETURNING id INTO v_doubles_team;
 INSERT INTO public.tournament_doubles_matches(
    competition_id,round_number,round_label,match_number,bracket_size,
    scheduled_season_week,scheduled_day,team1_id,winner_team_id,status,started_at,completed_at)
 VALUES(v_comp,1,'Final',81,2,1,1,v_doubles_team,v_doubles_team,'completed',
        now()-interval '2 days',now()-interval '1 day')
 RETURNING id INTO v_doubles_match;

 -- Model an explicit history-preserving public tombstone as a *single*
 -- retained player row. Never silently change a completed winner or score.
 -- In production, all other personal data tables must be classified first.
 UPDATE public.players
 SET owner_user_id=NULL,first_name='Retired',last_name='Guest',
     image_path=NULL,home_city=NULL,moderation_status='rejected',
     updated_at=now()
 WHERE id=v_guest AND owner_user_id=v_guest_user
   AND EXISTS (
     SELECT 1 FROM auth.users u
     JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
     WHERE u.id=v_guest_user AND u.is_anonymous
       AND t.expires_at<=now() AND t.retired_at IS NOT NULL
       AND t.converted_at IS NULL
   );
 GET DIAGNOSTICS v_n=ROW_COUNT;
 IF v_n<>1 THEN RAISE EXCEPTION 'H08 tombstone guest eligibility guard failed'; END IF;

 -- Minimal-schema simulated physical Auth deletion only.
 -- The production 188-FK graph is NOT represented here.
 DELETE FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=v_guest_user;
 DELETE FROM auth.users WHERE id=v_guest_user;

 SELECT player1_id,winner_id INTO v_guest,v_winner
 FROM public.tournament_matches WHERE id=v_match;
 IF v_guest IS NULL OR v_winner IS DISTINCT FROM v_guest THEN
   RAISE EXCEPTION 'H08 historical player/winner reference disappeared';
 END IF;
 SELECT owner_user_id,first_name,last_name INTO v_owner,v_first,v_last
 FROM public.players WHERE id=v_guest;
 IF NOT FOUND OR v_owner IS NOT NULL OR v_first<>'Retired' OR v_last<>'Guest' THEN
   RAISE EXCEPTION 'H08 tombstone identity not anonymized/unlinked';
 END IF;
 IF NOT EXISTS(
  SELECT 1 FROM public.tournament_doubles_teams t
  JOIN public.tournament_doubles_matches m ON m.team1_id=t.id
  WHERE m.id=v_doubles_match AND m.status='completed'
  AND m.winner_team_id=t.id AND t.player1_id=v_guest
 ) THEN RAISE EXCEPTION 'H08 historical doubles team/result disappeared'; END IF;
 IF EXISTS (SELECT 1 FROM auth.users WHERE id=v_guest_user) THEN
   RAISE EXCEPTION 'H08 guest Auth user still present';
 END IF;

 -- Converted identities are explicitly ineligible for this operation.
 INSERT INTO auth.users(id,is_anonymous) VALUES(v_registered_user,false);
 INSERT INTO control_center_private.tennis_guest_trials_v1(
    user_id,started_at,expires_at,converted_at)
 VALUES(v_registered_user,now()-interval '15 days',now()-interval '1 day',now()-interval '2 days');
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES(v_registered_user,'Permanent','Player','DE','ATP','human')
 RETURNING id INTO v_registered_player;
 UPDATE public.players
 SET owner_user_id=NULL,first_name='Retired',last_name='Guest'
 WHERE id=v_registered_player AND owner_user_id=v_registered_user
   AND EXISTS (
     SELECT 1 FROM auth.users u
     JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
     WHERE u.id=v_registered_user AND u.is_anonymous
       AND t.expires_at<=now() AND t.retired_at IS NOT NULL
       AND t.converted_at IS NULL
   );
 GET DIAGNOSTICS v_n=ROW_COUNT;
 IF v_n<>0 THEN RAISE EXCEPTION 'H08 converted user incorrectly tombstoned'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.players
    WHERE id=v_registered_player AND owner_user_id=v_registered_user
      AND first_name='Permanent') THEN
   RAISE EXCEPTION 'H08 registered player mutated';
 END IF;

 -- Unexpired anonymous identity may not be tombstoned.
 INSERT INTO auth.users(id,is_anonymous) VALUES(v_active_user,true);
 INSERT INTO control_center_private.tennis_guest_trials_v1(
    user_id,started_at,expires_at)
 VALUES(v_active_user,now()-interval '1 day',now()+interval '13 days');
 INSERT INTO public.players(owner_user_id,first_name,last_name,country_code,world,player_type)
 VALUES(v_active_user,'Active','Guest','DE','ATP','human')
 RETURNING id INTO v_active_player;
 UPDATE public.players
 SET owner_user_id=NULL,first_name='Retired',last_name='Guest'
 WHERE id=v_active_player AND owner_user_id=v_active_user
   AND EXISTS (
     SELECT 1 FROM auth.users u
     JOIN control_center_private.tennis_guest_trials_v1 t ON t.user_id=u.id
     WHERE u.id=v_active_user AND u.is_anonymous
       AND t.expires_at<=now() AND t.retired_at IS NOT NULL
       AND t.converted_at IS NULL
   );
 GET DIAGNOSTICS v_n=ROW_COUNT;
 IF v_n<>0 THEN RAISE EXCEPTION 'H08 active guest incorrectly tombstoned'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.players
    WHERE id=v_active_player AND owner_user_id=v_active_user
      AND first_name='Active') THEN
   RAISE EXCEPTION 'H08 active guest modified'; END IF;

 RAISE NOTICE 'H08 PASS minimal schema: retired singles/doubles results retained after Auth unlink/deletion; converted and active guests protected';
END;
$proof$;
ROLLBACK;
