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
  v_booking jsonb;
  v_leg_id uuid;
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

  -- Exercise the real tournament-selection RPC through the actual
  -- tournament quote, full core itinerary rebuild and leg insert routines.
  -- The synthetic fixture models six selected staff contracts.
  v_booking := public.set_private_life_tournament_travel_v1(
    '44444444-4444-4444-4444-444444444444'::uuid,'private_jet',v_jet);
  IF v_booking->>'status' <> 'saved'
     OR v_booking->>'travel_mode' <> 'private_jet'
  THEN RAISE EXCEPTION 'Short-range tournament private jet selection failed: %',v_booking; END IF;
  SELECT id INTO v_leg_id FROM public.player_travel_legs
  WHERE player_id=v_player AND destination_city='Paris'
    AND status='planned' AND travel_mode='private_jet'
  ORDER BY created_at DESC LIMIT 1;
  IF v_leg_id IS NULL THEN RAISE EXCEPTION 'Approved jet was not booked into planned tournament itinerary'; END IF;
  IF EXISTS(
    SELECT 1 FROM public.player_travel_legs WHERE id=v_leg_id
    AND COALESCE((jet_quote->>'staff_commercial')::integer,-1)<>0)
  THEN RAISE EXCEPTION 'Jet booking charged extra staff air tickets'; END IF;

  v_booking := public.process_travel_leg_v1(v_leg_id);
  IF v_booking->>'status' <> 'completed'
  THEN RAISE EXCEPTION 'Paid jet arrival failed: %',v_booking; END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.player_location_state
    WHERE player_id=v_player AND current_city='Paris' AND current_country_code='FR'
  ) THEN RAISE EXCEPTION 'Flight arrival did not update player location'; END IF;
  SELECT count(*) INTO v_n FROM public.test_career_transactions
  WHERE idempotency_key='travel-leg:'||v_leg_id::text;
  IF v_n<>1 THEN RAISE EXCEPTION 'Jet flight did not debit exactly once'; END IF;
  v_booking := public.process_travel_leg_v1(v_leg_id);
  IF v_booking->>'status' <> 'already_processed'
  THEN RAISE EXCEPTION 'Repeated travel settlement was not idempotent'; END IF;

  -- Owned jets must fall back to normal commercial travel for Australia.
  v_booking := public.set_private_life_tournament_travel_v1(
    '66666666-6666-6666-6666-666666666666'::uuid,'private_jet',v_jet);
  IF v_booking->>'status' <> 'commercial_fallback'
    OR v_booking->>'travel_mode' <> 'commercial'
  THEN RAISE EXCEPTION 'Out-of-range tournament selection did not fall back: %',v_booking; END IF;

  RAISE NOTICE 'PASS: all 3 real migrations, six-staff jet booking, settlement, idempotency, commercial fallback and profile checks';
END $$;
ROLLBACK;
