-- Synthetic fixture ONLY, inside the network-disabled CI container.
CREATE TABLE public.tournament_matches (
 id uuid PRIMARY KEY,competition_id uuid NOT NULL,player1_id uuid NOT NULL,player2_id uuid NOT NULL,winner_id uuid,status text,started_at timestamptz,completed_at timestamptz,actual_duration_minutes integer,completion_reason text,draw_type text,round_number integer,round_label text,scheduled_season_week integer,scheduled_day integer,scheduled_start_minute integer,court_number integer
);
CREATE TABLE public.tournament_match_simulations (
 match_id uuid PRIMARY KEY REFERENCES public.tournament_matches,engine_version text,engine_seed text,simulation_status text,final_winner_id uuid,total_games integer,total_points integer,replay_duration_seconds integer,sets_payload jsonb,player1_stats jsonb,player2_stats jsonb
);
CREATE TABLE public.tournament_match_sets (
 match_id uuid REFERENCES public.tournament_matches,set_number integer,player1_games integer,player2_games integer,player1_tiebreak_points integer,player2_tiebreak_points integer,status text,PRIMARY KEY(match_id,set_number)
);
CREATE TABLE public.tournament_match_player_stats (
 match_id uuid REFERENCES public.tournament_matches,player_id uuid,aces integer,double_faults integer,first_serves_in integer,first_serves_total integer,first_serve_points_won integer,first_serve_points_played integer,second_serve_points_won integer,second_serve_points_played integer,break_points_won integer,break_points_total integer,winners integer,unforced_errors integer,total_points_won integer,PRIMARY KEY(match_id,player_id)
);
-- Fingerprint stand-ins only. These functions are never invoked.
CREATE FUNCTION public.simulate_tournament_match_v1(uuid,text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.prepare_tournament_match_simulation_v1(uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.finalize_match_replay_v1(uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.get_match_engine_profile_v1(uuid,text) RETURNS jsonb LANGUAGE sql AS $$SELECT '{}'::jsonb$$;
CREATE FUNCTION public.simulated_tennis_duration_minutes_v1(integer,integer) RETURNS integer LANGUAGE sql AS $$SELECT 66$$;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
INSERT INTO public.tournament_matches VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000003','completed','2026-01-01T10:00:00Z','2026-01-01T11:06:00Z',66,NULL,'main_draw',1,'Round 1',5,2,600,1);
INSERT INTO public.tournament_match_sets SELECT id,n,6,0,NULL,NULL,'completed' FROM public.tournament_matches CROSS JOIN generate_series(1,2) n;
INSERT INTO public.tournament_match_player_stats
 SELECT id,player1_id,0,0,24,24,24,24,0,0,6,6,48,0,48 FROM public.tournament_matches
 UNION ALL
 SELECT id,player2_id,0,0,24,24,0,24,0,0,0,0,0,0,0 FROM public.tournament_matches;
INSERT INTO public.tournament_match_simulations
 SELECT m.id,'synthetic-sql-control','fixture-seed','completed',m.winner_id,12,48,120,
 (SELECT jsonb_agg(to_jsonb(s)-'match_id' ORDER BY set_number) FROM public.tournament_match_sets s WHERE s.match_id=m.id),
 (SELECT to_jsonb(s)-'match_id'-'player_id' FROM public.tournament_match_player_stats s WHERE s.match_id=m.id AND s.player_id=m.player1_id),
 (SELECT to_jsonb(s)-'match_id'-'player_id' FROM public.tournament_match_player_stats s WHERE s.match_id=m.id AND s.player_id=m.player2_id)
 FROM public.tournament_matches m;
CREATE ROLE ace_shadow_reader LOGIN PASSWORD 'ace-shadow-disposable-reader';
GRANT CONNECT ON DATABASE ace_legacy_shadow TO ace_shadow_reader;
GRANT USAGE ON SCHEMA public TO ace_shadow_reader;
GRANT SELECT ON public.tournament_matches,public.tournament_match_simulations,public.tournament_match_sets,public.tournament_match_player_stats TO ace_shadow_reader;
ALTER ROLE ace_shadow_reader SET default_transaction_read_only=on;
