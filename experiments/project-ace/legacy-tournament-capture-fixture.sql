-- Only the synthetic CI database. All identifiers fabricated.
DO $$ BEGIN IF current_database()<>'ace_tournament_capture' THEN RAISE EXCEPTION 'wrong fixture database'; END IF; END $$;
CREATE SCHEMA ace_shadow_guard;
CREATE TABLE ace_shadow_guard.approval(singleton boolean PRIMARY KEY CHECK(singleton),marker text,approved_read_only boolean,restore_id text);
INSERT INTO ace_shadow_guard.approval VALUES(true,'ace-tournament-synthetic-ci-v029',true,'synthetic-tournament-ci');
CREATE SCHEMA cron;
CREATE TABLE cron.job(active boolean);
INSERT INTO cron.job VALUES(false);
CREATE TABLE public.tournament_world_competitions(id uuid PRIMARY KEY,tournament_edition_id uuid,world text,status text);
CREATE TABLE public.tournament_editions(id uuid PRIMARY KEY,season_number integer,status text);
CREATE TABLE public.tournament_draw_publications(competition_id uuid PRIMARY KEY,main_draw_size smallint,qualifying_draw_size smallint,qualifier_slots smallint,published_at timestamptz);
CREATE TABLE public.tournament_competition_entry_cycles(competition_id uuid PRIMARY KEY,field_locked_at timestamptz,field_locked_game_second bigint);
CREATE TABLE public.tournament_entries(id uuid PRIMARY KEY,player_id uuid,competition_id uuid,world text,draw_type text,entry_status text,bracket_slot smallint);
CREATE TABLE public.tournament_matches(id uuid PRIMARY KEY,competition_id uuid,draw_type text,round_number smallint,match_number smallint,round_label text,bracket_size smallint,status text,started_at timestamptz,completed_at timestamptz,winner_id uuid,completion_reason text,actual_duration_minutes smallint,estimated_duration_minutes smallint,schedule_reason text,updated_at timestamptz,player1_id uuid,player2_id uuid,scheduled_season_week integer,scheduled_day smallint,scheduled_start_minute smallint,court_number smallint);
CREATE TABLE public.player_tournament_results(id uuid PRIMARY KEY,competition_id uuid);
CREATE TABLE public.tournament_match_simulations(match_id uuid PRIMARY KEY);
CREATE TABLE public.tournament_cancellations(competition_id uuid PRIMARY KEY);
CREATE FUNCTION public.synthetic_id(n int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$ SELECT ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid $$;
INSERT INTO public.tournament_world_competitions VALUES(public.synthetic_id(1),public.synthetic_id(2),'ATP','registration_closed');
INSERT INTO public.tournament_editions VALUES(public.synthetic_id(2),2,'registration_closed');
INSERT INTO public.tournament_draw_publications VALUES(public.synthetic_id(1),8,0,0,'2026-11-28T00:00:00Z');
INSERT INTO public.tournament_competition_entry_cycles VALUES(public.synthetic_id(1),'2026-11-28T00:00:00Z',31622400);
INSERT INTO public.tournament_entries SELECT public.synthetic_id(100+n),public.synthetic_id(200+n),public.synthetic_id(1),'ATP','main_draw','active',n FROM generate_series(1,8) n;
INSERT INTO public.tournament_matches
SELECT public.synthetic_id(300+r*10+n),public.synthetic_id(1),'main_draw',r,n,'round-'||r,8,'scheduled',NULL,NULL,NULL,NULL,NULL,150,'standard','2026-11-28T00:00:00Z',
 CASE WHEN r=1 THEN public.synthetic_id(200+2*n-1) END,CASE WHEN r=1 THEN public.synthetic_id(200+2*n) END,1,r,600,n
FROM generate_series(1,3) r CROSS JOIN LATERAL generate_series(1,8/(2^r)::int) n;
