-- Isolated GitHub-hosted PostgreSQL compatibility fixture.
-- It deliberately contains ONLY synthetic data/objects, never live Supabase
-- schema dumps, secrets, player records, or copied production data.
-- Apply after private_life_ephemeral_fixture.sql and the first real migration.
-- This enables application of the UNMODIFIED second and third migrations.
-- Not intended to reproduce full Supabase Auth, Storage, RLS, or scheduler.

-- Add just the existing public table shapes referenced by the later migrations.
ALTER TABLE public.private_life_asset_catalog
 ADD COLUMN name text NOT NULL DEFAULT 'Fixture catalog item',
 ADD COLUMN tier smallint NOT NULL DEFAULT 1,
 ADD COLUMN description text NOT NULL DEFAULT 'Fixture only',
 ADD COLUMN purchase_price bigint NOT NULL DEFAULT 100,
 ADD COLUMN prestige smallint NOT NULL DEFAULT 0,
 ADD COLUMN rarity text NOT NULL DEFAULT 'common',
 ADD COLUMN annual_running_cost bigint NOT NULL DEFAULT 0,
 ADD COLUMN image_url text NOT NULL DEFAULT '',
 ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.private_life_property_locations
 ADD COLUMN country_name text NOT NULL DEFAULT 'Fixture country',
 ADD COLUMN apartment_base_price bigint NOT NULL DEFAULT 100,
 ADD COLUMN house_base_price bigint NOT NULL DEFAULT 200,
 ADD COLUMN annual_value_rate_bps integer NOT NULL DEFAULT 250,
 ADD COLUMN marketplace_enabled boolean NOT NULL DEFAULT true,
 ADD COLUMN active boolean NOT NULL DEFAULT true,
 ADD COLUMN sort_order integer NOT NULL DEFAULT 0;

ALTER TABLE public.private_life_player_assets
 ADD COLUMN purchase_price bigint NOT NULL DEFAULT 100,
 ADD COLUMN prestige_override smallint,
 ADD COLUMN trade_locked boolean NOT NULL DEFAULT false,
 ADD COLUMN created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.player_skills
 ADD COLUMN fatigue smallint NOT NULL DEFAULT 0;

ALTER TABLE public.player_location_state
 ADD COLUMN current_continent text,
 ADD COLUMN source_reference_id text,
 ADD COLUMN location_since_absolute_day integer,
 ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.player_daily_activity
 ADD COLUMN source text,
 ADD COLUMN reference_id text,
 ADD COLUMN note text,
 ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN effects_applied_at timestamptz,
 ADD COLUMN effect_summary jsonb;
ALTER TABLE public.player_daily_activity
 ADD CONSTRAINT full_fixture_one_daily_activity UNIQUE(player_id,season,month,day);

ALTER TABLE public.player_travel_legs
 ALTER COLUMN id SET DEFAULT gen_random_uuid();
ALTER TABLE public.player_travel_legs
 ADD COLUMN created_at timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
 ADD COLUMN purpose text,
 ADD COLUMN source_location_type text,
 ADD COLUMN source_city text,
 ADD COLUMN source_country_code text,
 ADD COLUMN source_continent text,
 ADD COLUMN source_latitude double precision,
 ADD COLUMN source_longitude double precision,
 ADD COLUMN destination_location_type text,
 ADD COLUMN destination_continent text,
 ADD COLUMN destination_latitude double precision,
 ADD COLUMN destination_longitude double precision,
 ADD COLUMN source_reference_id text,
 ADD COLUMN destination_reference_id text,
 ADD COLUMN arrival_absolute_day integer,
 ADD COLUMN distance_km integer,
 ADD COLUMN estimated_cost integer,
 ADD COLUMN gross_arrival_fatigue smallint,
 ADD COLUMN travel_day_recovery smallint,
 ADD COLUMN arrival_fatigue smallint,
 ADD COLUMN travel_band text,
 ADD COLUMN travel_basis text,
 ADD COLUMN embedded_transition boolean NOT NULL DEFAULT false,
 ADD COLUMN travel_class text,
 ADD COLUMN base_estimated_cost integer,
 ADD COLUMN price_multiplier numeric,
 ADD COLUMN base_arrival_fatigue smallint,
 ADD COLUMN fatigue_multiplier numeric,
 ADD COLUMN processed_at timestamptz;

-- Current production tables used by the real SQL as FKs or row types.
CREATE TABLE public.tournament_world_competitions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid()
);
CREATE TABLE public.tournament_entries (
 player_id uuid NOT NULL REFERENCES public.players(id),
 competition_id uuid NOT NULL REFERENCES public.tournament_world_competitions(id),
 PRIMARY KEY(player_id,competition_id)
);
CREATE TABLE public.player_tournament_preparation_plans (
 player_id uuid NOT NULL REFERENCES public.players(id),
 competition_id uuid NOT NULL REFERENCES public.tournament_world_competitions(id),
 player_travel_class text DEFAULT 'Economy',
 staff_travel_class text DEFAULT 'Economy',
 hotel_tier text DEFAULT 'Standard',
 selected_staff_contract_ids uuid[] DEFAULT '{}'::uuid[],
 PRIMARY KEY(player_id,competition_id)
);

-- Only used as a row type while PostgreSQL compiles the unchanged
-- tournament-preparation function. No hotel bookings are created in QA.
CREATE TABLE public.travel_stay_tiers (
 tier_name text PRIMARY KEY,
 label text NOT NULL,
 base_nightly_cost integer NOT NULL DEFAULT 100,
 recovery_support_pct integer NOT NULL DEFAULT 0
);
INSERT INTO public.travel_stay_tiers(tier_name,label)
VALUES ('Standard','Fixture hotel');

-- The real migration intentionally REVOKES EXECUTE on these legacy helpers.
-- Their bodies are synthetic placeholders; only the signatures are required.
CREATE FUNCTION public.apply_training_camp_split_travel_v1(uuid)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.process_due_travel_legs_v1(uuid,integer)
RETURNS integer LANGUAGE sql AS $$ SELECT 0 $$;

-- No actual user data is present. These helpers permit safe execution of
-- the final profile summary against the synthetic catalog and owned assets.
CREATE FUNCTION public.ensure_private_life_starter_home_v1(uuid)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.private_life_owned_asset_market_value_v2(uuid,integer)
RETURNS bigint LANGUAGE sql STABLE AS $$ SELECT 100::bigint $$;

-- Never fabricate a production catalog snapshot. This separate file inserts
-- local-only items before the real jet migration adds transport eligibility.
