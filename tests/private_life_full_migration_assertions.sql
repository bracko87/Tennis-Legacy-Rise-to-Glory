-- Run ONLY in a disposable, synthetic GitHub Actions PostgreSQL database.
-- All three actual Private Life SQL migrations must already have executed.
-- The first real migration is applied before the additive compatibility
-- fixture; the second/third migrations run unchanged and in release order.
-- These checks DO NOT replace full Supabase-auth/browser QA.
BEGIN;
DO $$
DECLARE
  v_player uuid := '11111111-1111-1111-1111-111111111111';
  v_jet uuid := '77777777-7777-7777-7777-777777777777';
  v_q jsonb;
  v_summary jsonb;
  v_career jsonb;
  v_n integer;
BEGIN
  SELECT count(*) INTO v_n FROM public.private_life_asset_catalog
  WHERE code in ('air_cessaro_citation_m3','air_emborgier_phenom_350e',
   'air_bombara_challenger_420','air_cessaro_citation_latitude_x',
   'air_emborgier_praetor_680','air_dassier_falcon_9x',
   'air_gulfstar_g650_lx','air_bombara_global_8000x',
   'air_gulfstar_g900_sovereign')
   AND COALESCE((metadata->>'tournament_travel_eligible')::boolean,false);
  IF v_n <> 9 THEN RAISE EXCEPTION 'Expected nine enabled Private Life transport jets: %',v_n; END IF;
  IF EXISTS(SELECT 1 FROM public.private_life_asset_catalog
    WHERE code='sandbox_hobby_propeller'
      AND COALESCE((metadata->>'tournament_travel_eligible')::boolean,false))
  THEN RAISE EXCEPTION 'Hobby plane improperly enabled for transport'; END IF;

  INSERT INTO public.private_life_player_assets
   (id,player_id,catalog_code,acquisition_type,purchase_absolute_day,purchase_price)
  VALUES(v_jet,v_player,'air_cessaro_citation_m3','purchase',391,9049320);
  IF NOT EXISTS(
   SELECT 1 FROM public.player_private_jet_positions
   WHERE owned_asset_id=v_jet AND city='Belgrade' AND country_code='RS')
  THEN RAISE EXCEPTION 'Purchased jet was not positioned correctly'; END IF;

  v_q := public.quote_private_jet_leg_v1(
    v_player,'Belgrade','RS','Paris','FR',1600,6,v_jet,391);
  IF NOT COALESCE((v_q->>'active')::boolean,false)
    OR (v_q->>'passenger_capacity')::integer <> 7
    OR (v_q->>'staff_commercial')::integer <> 0
  THEN RAISE EXCEPTION 'Approved direct private jet full-party quote invalid: %',v_q; END IF;
  IF COALESCE((v_q->>'reduction_bps')::integer,0) > 5000
  THEN RAISE EXCEPTION 'Jet fatigue reduction exceeds 50 percent'; END IF;

  v_q := public.quote_private_jet_leg_v1(
    v_player,'Belgrade','RS','Sydney','AU',16000,6,v_jet,391);
  IF COALESCE((v_q->>'active')::boolean,false)
  THEN RAISE EXCEPTION 'Out-of-range jet incorrectly quoted as active'; END IF;

  v_q := public.quote_private_jet_leg_v1(
    v_player,'Belgrade','RS','Paris','FR',1600,7,v_jet,391);
  IF COALESCE((v_q->>'active')::boolean,false)
  THEN RAISE EXCEPTION 'Jet over-capacity quote incorrectly active'; END IF;

  v_career := public.get_my_private_life_career_v1();
  IF COALESCE(jsonb_array_length(v_career->'eligible_jets'),0) <> 1
   OR v_career->'home_base'->>'country_code' <> 'RS'
  THEN RAISE EXCEPTION 'Career state read integration failed: %',v_career; END IF;

  v_summary := public.get_player_private_life_summary_v1(v_player);
  IF (v_summary->>'asset_count')::integer <> 1
   OR v_summary->'residence'->>'nationality' <> 'RS'
  THEN RAISE EXCEPTION 'Private Life profile summary integration failed: %',v_summary; END IF;

  RAISE NOTICE 'PASS: all three real migrations ran in order; catalog, jet ownership, range, seats, career and profile checks passed';
END $$;
ROLLBACK;
