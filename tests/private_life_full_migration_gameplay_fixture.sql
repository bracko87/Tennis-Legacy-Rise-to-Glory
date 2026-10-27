-- Disposable GitHub-hosted Private Life runtime fixture.
-- Synthetic tournament and staff data ONLY. Never deploy or seed production.
-- Applied AFTER all 3 real migrations to exercise their authenticated RPCs.
ALTER TABLE public.players ADD COLUMN world text NOT NULL DEFAULT 'ATP';

ALTER TABLE public.tournament_world_competitions
 ADD COLUMN tournament_edition_id uuid,
 ADD COLUMN world text NOT NULL DEFAULT 'ATP',
 ADD COLUMN status text NOT NULL DEFAULT 'scheduled';
ALTER TABLE public.tournament_entries
 ADD COLUMN draw_type text NOT NULL DEFAULT 'main_draw';

CREATE TABLE public.tournament_series (
 id uuid PRIMARY KEY,
 city text NOT NULL,
 country_code text NOT NULL,
 latitude double precision,
 longitude double precision
);
CREATE TABLE public.tournament_editions (
 id uuid PRIMARY KEY,
 tournament_series_id uuid NOT NULL REFERENCES public.tournament_series(id),
 season_number integer NOT NULL,
 status text NOT NULL DEFAULT 'scheduled'
);
CREATE TABLE public.tournament_schedule_slots (
 tournament_edition_id uuid NOT NULL REFERENCES public.tournament_editions(id),
 season_week integer NOT NULL
);
CREATE TABLE public.tournament_matches (
 competition_id uuid NOT NULL,
 draw_type text NOT NULL DEFAULT 'main_draw',
 scheduled_season_week integer NOT NULL,
 scheduled_day integer NOT NULL,
 player1_id uuid,
 player2_id uuid
);
CREATE TABLE public.player_staff_contracts (
 id uuid PRIMARY KEY,
 player_id uuid NOT NULL REFERENCES public.players(id),
 status text NOT NULL DEFAULT 'active'
);
CREATE TABLE public.travel_engine_settings (
 id integer PRIMARY KEY,
 direct_transition_max_gap_days smallint NOT NULL DEFAULT 3
);
INSERT INTO public.travel_engine_settings VALUES(1,3);

INSERT INTO public.tournament_series(id,city,country_code,latitude,longitude) VALUES
 ('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Paris','FR',48.85,2.35),
 ('22222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa','Sydney','AU',-33.87,151.21);
INSERT INTO public.tournament_editions(id,tournament_series_id,season_number) VALUES
 ('33333333-aaaa-aaaa-aaaa-aaaaaaaaaaaa','11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa',2),
 ('33333333-bbbb-bbbb-bbbb-bbbbbbbbbbbb','22222222-aaaa-aaaa-aaaa-aaaaaaaaaaaa',2);
INSERT INTO public.tournament_schedule_slots(tournament_edition_id,season_week) VALUES
 ('33333333-aaaa-aaaa-aaaa-aaaaaaaaaaaa',5),
 ('33333333-bbbb-bbbb-bbbb-bbbbbbbbbbbb',9);
INSERT INTO public.tournament_world_competitions(id,tournament_edition_id,world,status) VALUES
 ('44444444-4444-4444-4444-444444444444','33333333-aaaa-aaaa-aaaa-aaaaaaaaaaaa','ATP','scheduled'),
 ('66666666-6666-6666-6666-666666666666','33333333-bbbb-bbbb-bbbb-bbbbbbbbbbbb','ATP','scheduled');
INSERT INTO public.tournament_entries(player_id,competition_id) VALUES
 ('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444'),
 ('11111111-1111-1111-1111-111111111111','66666666-6666-6666-6666-666666666666');
INSERT INTO public.tournament_matches(competition_id,draw_type,scheduled_season_week,scheduled_day,player1_id) VALUES
 ('44444444-4444-4444-4444-444444444444','main_draw',5,1,'11111111-1111-1111-1111-111111111111'),
 ('66666666-6666-6666-6666-666666666666','main_draw',9,1,'11111111-1111-1111-1111-111111111111');
INSERT INTO public.player_tournament_preparation_plans(player_id,competition_id,selected_staff_contract_ids) VALUES
 ('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444',
  ARRAY['10101010-1010-1010-1010-101010101001'::uuid,'10101010-1010-1010-1010-101010101002'::uuid,
   '10101010-1010-1010-1010-101010101003'::uuid,'10101010-1010-1010-1010-101010101004'::uuid,
   '10101010-1010-1010-1010-101010101005'::uuid,'10101010-1010-1010-1010-101010101006'::uuid]),
 ('11111111-1111-1111-1111-111111111111','66666666-6666-6666-6666-666666666666','{}'::uuid[]);
INSERT INTO public.player_staff_contracts(id,player_id)
SELECT ('10101010-1010-1010-1010-10101010100'||i::text)::uuid,
  '11111111-1111-1111-1111-111111111111'::uuid
FROM generate_series(1,6) as i;

CREATE FUNCTION public.country_continent_v1(text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE $1 WHEN 'AU' THEN 'OC' ELSE 'EU' END
$$;
CREATE FUNCTION public.absolute_game_day_v1(integer)
RETURNS TABLE(season integer,month integer,day integer) LANGUAGE sql IMMUTABLE AS $$
 SELECT 1,1,greatest(1,least(30,$1-390))
$$;
CREATE FUNCTION public.quote_travel_v2(
 text,text,double precision,double precision,
 text,text,double precision,double precision,text,text
) RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object(
  'distance_km',CASE WHEN $5='Sydney' OR $1='Sydney' THEN 16000 WHEN $1=$5 THEN 0 ELSE 1600 END,
  'cost',CASE WHEN $10='round_trip' THEN 1000 ELSE 500 END,
  'base_cost_one_way',500,'price_multiplier',1,'gross_arrival_fatigue',20,
  'travel_day_recovery',3,'arrival_fatigue',17,'base_arrival_fatigue',20,
  'fatigue_multiplier',1,'band',CASE WHEN $1=$5 THEN 'same_city' ELSE 'long' END,
  'basis','synthetic-quote')
$$;
CREATE FUNCTION public.quote_accommodation_v1(text,text,integer,integer,integer,text)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('total',$3*$4*$5,'nights',$4)
$$;
CREATE FUNCTION public.get_tournament_staff_effects_v1(uuid,uuid,uuid[])
RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.post_tournament_hotel_night_v1(uuid,uuid,integer)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.emit_notification_v1(uuid,uuid,text,text,text,text,jsonb,text)
RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
CREATE FUNCTION public.player_tournament_commitment_unresolved_v1(uuid,text)
RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
CREATE FUNCTION public.sync_player_tournament_travel_timing_v1(uuid)
RETURNS void LANGUAGE sql AS $$ SELECT $$;

CREATE FUNCTION public.player_commitment_locations_v1(uuid)
RETURNS TABLE (
 commitment_type text, reference_id text, city text, country_code text,
 continent text, latitude double precision, longitude double precision,
 start_absolute_day integer, end_absolute_day integer
) LANGUAGE sql STABLE AS $$
 SELECT 'tournament'::text,e.competition_id::text,ts.city,ts.country_code,
   public.country_continent_v1(ts.country_code),ts.latitude,ts.longitude,
   (te.season_number-1)*366+2+(ss.season_week-1)*7,
   (te.season_number-1)*366+2+(ss.season_week-1)*7+6
 FROM public.tournament_entries e
 JOIN public.tournament_world_competitions wc ON wc.id=e.competition_id
 JOIN public.tournament_editions te ON te.id=wc.tournament_edition_id
 JOIN public.tournament_series ts ON ts.id=te.tournament_series_id
 JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=te.id
 WHERE e.player_id=$1 ORDER BY ss.season_week
$$;

-- The ordinary fixture's wrapper only counts plan rebuild calls; replace it
-- with an actual call into the UNMODIFIED migration's full core function.
CREATE OR REPLACE FUNCTION public.rebuild_player_travel_plan_v1(p_player_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='public' AS $$
BEGIN
 RETURN public.rebuild_player_travel_plan_core_v1(p_player_id);
END $$;
REVOKE ALL ON FUNCTION public.rebuild_player_travel_plan_v1(uuid)
 FROM PUBLIC,anon,authenticated;
