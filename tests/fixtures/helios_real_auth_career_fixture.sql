-- CI-only supplemental schema, loaded after the minimal real-Auth fixture.
-- The career/tournament tables come from the existing disposable retirement fixture.
-- Policies here are fixture-only, not a production RLS audit.
CREATE TABLE control_center_private.helios_real_auth_ci_marker(id boolean PRIMARY KEY CHECK(id));
INSERT INTO control_center_private.helios_real_auth_ci_marker VALUES(true);
CREATE TABLE public.player_home_city_options(
 country_code text, city text, is_active boolean DEFAULT true, sort_order integer DEFAULT 0
);
CREATE TABLE public.helios_ci_equipment(
 player_id uuid PRIMARY KEY REFERENCES public.players(id), condition_percent integer NOT NULL
);
CREATE TABLE public.helios_ci_career_finance(
 player_id uuid PRIMARY KEY REFERENCES public.players(id), balance bigint NOT NULL
);
DO $qa$
DECLARE t record;
BEGIN
 FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
   EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t.tablename);
 END LOOP;
END
$qa$;
REVOKE ALL ON public.players FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON public.players TO authenticated;
CREATE POLICY helios_ci_player_select_own ON public.players FOR SELECT TO authenticated USING (owner_user_id=auth.uid());
CREATE POLICY helios_ci_player_insert_own ON public.players FOR INSERT TO authenticated WITH CHECK (owner_user_id=auth.uid() AND player_type='human');

-- Minimal dependencies needed by the real frontend AuthProvider in CI.
ALTER TABLE public.players ADD COLUMN preferred_surface text;
CREATE FUNCTION public.is_app_admin_v1() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
REVOKE ALL ON FUNCTION public.is_app_admin_v1() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.is_app_admin_v1() TO authenticated;
CREATE FUNCTION public.get_public_google_oauth_status_v1() RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
REVOKE ALL ON FUNCTION public.get_public_google_oauth_status_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_google_oauth_status_v1() TO anon,authenticated;

-- Verified production invariant, missing in the older representative fixture.
ALTER TABLE public.players ADD CONSTRAINT players_owner_by_type_check CHECK (
 (player_type='human' AND owner_user_id IS NOT NULL)
 OR (player_type='ai' AND owner_user_id IS NULL)
);
