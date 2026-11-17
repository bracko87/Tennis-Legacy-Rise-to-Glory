-- Pre-release: make server-owned public tables read-only to API callers.
-- Existing SELECT grants are preserved with corresponding RLS policies.
-- No rows are inserted, modified or removed. PostgreSQL cron / trusted
-- SECURITY DEFINER game engines continue to maintain internal state.
DO $lock$
DECLARE
  target text;
  api_reads_anon boolean;
  api_reads_authenticated boolean;
  c oid;
BEGIN
  FOREACH target IN ARRAY ARRAY['ai_country_distribution',
    'ai_name_pools',
    'ai_simulation_state',
    'career_finance_settings',
    'career_tax_settings',
    'career_taxable_categories',
    'doubles_ranking_defence_cycles',
    'doubles_ranking_publication_runs',
    'game_manual_runtime_settings',
    'injury_catalog',
    'injury_treatment_catalog',
    'new_player_initialization_audit',
    'new_player_scheme_health_config',
    'private_life_country_property_tiers',
    'private_life_property_price_tiers',
    'ranking_publication_runs',
    'season_transition_boundary_guard_v1',
    'staff_generation_state',
    'tournament_cancellation_repair_audit',
    'tournament_cancellations',
    'tournament_draw_publications',
    'tournament_draw_seed_groups',
    'tournament_draw_seed_slots',
    'tournament_entry_auto_repair_attempts',
    'tournament_match_scheduling_rules',
    'tournament_prize_payouts',
    'tournament_prize_pool_rules',
    'tournament_prize_pools',
    'tournament_prize_stage_weights',
    'tournament_qualifier_slots',
    'tournament_ranking_point_rules',
    'training_camp_health_config']::text[]
  LOOP
    SELECT cls.oid INTO c
    FROM pg_class cls JOIN pg_namespace ns ON ns.oid=cls.relnamespace
    WHERE ns.nspname='public' AND cls.relname=target
      AND cls.relkind IN ('r','p');
    IF c IS NULL THEN
      RAISE EXCEPTION 'Missing protected internal table: %',target;
    END IF;
    IF (SELECT cls.relrowsecurity FROM pg_class cls WHERE cls.oid=c) THEN
      RAISE EXCEPTION 'Internal table % has unexpected existing RLS; review policies before changing',target;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_policy pol WHERE pol.polrelid=c) THEN
      RAISE EXCEPTION 'Table % has existing RLS policy; review before changing',target;
    END IF;

    api_reads_anon:=has_table_privilege('anon',c,'SELECT');
    api_reads_authenticated:=has_table_privilege('authenticated',c,'SELECT');

    EXECUTE format('REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE public.%I FROM PUBLIC, anon, authenticated',target);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',target);
    IF api_reads_anon THEN
      EXECUTE format('CREATE POLICY release_keep_anon_read_v1 ON public.%I FOR SELECT TO anon USING (true)',target);
    END IF;
    IF api_reads_authenticated THEN
      EXECUTE format('CREATE POLICY release_keep_authenticated_read_v1 ON public.%I FOR SELECT TO authenticated USING (true)',target);
    END IF;
  END LOOP;
END
$lock$;
