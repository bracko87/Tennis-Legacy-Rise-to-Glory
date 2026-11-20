-- Helios H08 integration fixture: disposable PostgreSQL 16 only.
-- Exact worker + bracket function definitions are loaded from dedicated
-- production snapshots after this schema. No Supabase credentials needed.
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS control_center_private;
CREATE SCHEMA IF NOT EXISTS cron;

CREATE TABLE auth.users(
 id uuid PRIMARY KEY,
 instance_id uuid, aud text, role text,
 is_anonymous boolean NOT NULL DEFAULT false,
 raw_app_meta_data jsonb, raw_user_meta_data jsonb
);
CREATE TABLE public.registration_control(
 singleton_id boolean PRIMARY KEY DEFAULT true,
 guest_test_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO public.registration_control(singleton_id) VALUES(true);

CREATE TABLE control_center_private.tennis_guest_trials_v1(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id),
 started_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 converted_at timestamptz,
 retired_at timestamptz,
 retirement_reason text,
 CHECK(expires_at=started_at+interval '14 days')
);
CREATE TABLE public.players(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_user_id uuid REFERENCES auth.users(id),
 first_name text NOT NULL,
 last_name text NOT NULL,
 country_code text NOT NULL,
 world text NOT NULL,
 image_path text,
 player_type text NOT NULL,
 playing_style text DEFAULT 'All-court',
 playing_hand text DEFAULT 'right',
 home_city text,
 moderation_status text NOT NULL DEFAULT 'approved',
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.tournament_categories(
 code text PRIMARY KEY,
 qualification_rounds_max smallint DEFAULT 2
);
CREATE TABLE public.tournament_series(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 category_code text REFERENCES public.tournament_categories(code)
);
CREATE TABLE public.tournament_editions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tournament_series_id uuid REFERENCES public.tournament_series(id)
);
CREATE TABLE public.tournament_world_competitions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tournament_edition_id uuid REFERENCES public.tournament_editions(id),
 world text NOT NULL
);
CREATE TABLE public.tournament_entries(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 competition_id uuid REFERENCES public.tournament_world_competitions(id),
 player_id uuid REFERENCES public.players(id),
 entry_status text DEFAULT 'active',
 draw_type text DEFAULT 'main_draw',
 seed_number integer,
 bracket_slot integer,
 updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.tournament_applications(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 competition_id uuid REFERENCES public.tournament_world_competitions(id),
 player_id uuid REFERENCES public.players(id),
 status text,
 decision_reason text,
 decided_at timestamptz,
 updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.tournament_matches(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 competition_id uuid NOT NULL REFERENCES public.tournament_world_competitions(id),
 draw_type text NOT NULL DEFAULT 'main_draw',
 round_number smallint NOT NULL,
 round_label text NOT NULL,
 match_number smallint NOT NULL,
 bracket_size smallint NOT NULL,
 scheduled_season_week integer NOT NULL,
 scheduled_day smallint NOT NULL,
 player1_id uuid REFERENCES public.players(id),
 player2_id uuid REFERENCES public.players(id),
 winner_id uuid REFERENCES public.players(id),
 status text NOT NULL DEFAULT 'scheduled',
 started_at timestamptz,
 completed_at timestamptz,
 completion_reason text,
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(competition_id,draw_type,round_number,match_number)
);
CREATE TABLE public.tournament_match_simulations(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 match_id uuid REFERENCES public.tournament_matches(id)
);
CREATE TABLE public.tournament_qualifier_slots(
 competition_id uuid REFERENCES public.tournament_world_competitions(id),
 section_number integer,
 bracket_slot integer,
 resolved boolean,
 filled_player_id uuid,
 PRIMARY KEY(competition_id,section_number)
);
CREATE TABLE public.tournament_doubles_teams(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 competition_id uuid NOT NULL REFERENCES public.tournament_world_competitions(id),
 world text,
 player1_id uuid REFERENCES public.players(id),
 player2_id uuid REFERENCES public.players(id),
 status text NOT NULL,
 entry_source text,
 combined_ranking_points_snapshot integer,
 entry_strength_snapshot integer,
 withdrawn_at timestamptz,
 updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.tournament_doubles_matches(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 competition_id uuid REFERENCES public.tournament_world_competitions(id),
 round_number smallint,
 round_label text,
 match_number smallint,
 bracket_size smallint,
 scheduled_season_week integer,
 scheduled_day smallint,
 team1_id uuid REFERENCES public.tournament_doubles_teams(id),
 team2_id uuid REFERENCES public.tournament_doubles_teams(id),
 winner_team_id uuid REFERENCES public.tournament_doubles_teams(id),
 status text NOT NULL DEFAULT 'scheduled',
 started_at timestamptz,
 completed_at timestamptz,
 completion_reason text,
 updated_at timestamptz DEFAULT now(),
 UNIQUE(competition_id,round_number,match_number)
);
CREATE FUNCTION public.tournament_round_label_v1(text,smallint,integer,smallint)
RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT 'Final'::text $$;
CREATE FUNCTION public.doubles_round_label_v1(smallint,integer)
RETURNS text LANGUAGE sql IMMUTABLE AS $$ SELECT 'Final'::text $$;
CREATE FUNCTION public.schedule_doubles_match_v1(uuid)
RETURNS void LANGUAGE plpgsql AS $$ BEGIN RETURN; END $$;
CREATE FUNCTION public.resolve_main_first_round_match_v1(uuid,integer)
RETURNS void LANGUAGE plpgsql AS $$ BEGIN RETURN; END $$;

-- Minimal reference data; generated IDs are not hard-coded or returned to user.
INSERT INTO public.tournament_categories(code) VALUES('CHALLENGER');
INSERT INTO public.tournament_series(category_code) VALUES('CHALLENGER');
INSERT INTO public.tournament_editions(tournament_series_id)
SELECT id FROM public.tournament_series LIMIT 1;
INSERT INTO public.tournament_world_competitions(tournament_edition_id,world)
SELECT id,'ATP' FROM public.tournament_editions LIMIT 1;

INSERT INTO public.players(first_name,last_name,country_code,world,player_type)
VALUES
 ('Fixture','AI One','DE','ATP','ai'),
 ('Fixture','AI Two','DE','ATP','ai'),
 ('Fixture','AI Three','DE','ATP','ai'),
 ('Fixture','AI Four','DE','ATP','ai');

-- Actual trigger functions are imported next from prod snapshot files.
