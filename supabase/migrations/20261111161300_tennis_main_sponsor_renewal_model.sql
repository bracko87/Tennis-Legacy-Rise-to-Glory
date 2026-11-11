
-- Tennis Legacy: main-sponsor renewal offer/reservation model.
-- No renewal is automatic: an eligible player must explicitly accept the offer.
ALTER TABLE public.player_sponsor_offers
  ADD COLUMN IF NOT EXISTS is_renewal boolean NOT NULL DEFAULT false;
ALTER TABLE public.player_sponsor_offers
  ADD COLUMN IF NOT EXISTS renewal_previous_contract_id uuid
  REFERENCES public.player_sponsor_contracts(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.player_sponsor_renewal_reservations_v1 (
 player_id uuid NOT NULL REFERENCES public.players(id) ON DELETE CASCADE,
 target_season integer NOT NULL CHECK(target_season>=2),
 offer_id uuid NOT NULL UNIQUE REFERENCES public.player_sponsor_offers(id) ON DELETE CASCADE,
 accepted_absolute_day integer NOT NULL,
 activated_contract_id uuid REFERENCES public.player_sponsor_contracts(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 activated_at timestamptz,
 PRIMARY KEY(player_id,target_season)
);
ALTER TABLE public.player_sponsor_renewal_reservations_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.player_sponsor_renewal_reservations_v1 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ensure_player_main_sponsor_renewal_v1(p_player_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $fn$
DECLARE
 v_owner uuid; v_player_type text; v_country text; d record;
 v_current_abs integer; v_target_season integer; v_previous_season integer;
 v_target_start integer; v_target_end integer; v_rank integer; v_progress numeric;
 v_market numeric; v_growth numeric; v_value bigint; v_weekly bigint; v_count smallint;
 v_market_group text; v_previous public.player_sponsor_contracts%rowtype;
 v_sponsor public.sponsor_companies%rowtype;
 v_rule public.sponsor_offer_rules%rowtype; v_offer_id uuid;
BEGIN
 SELECT owner_user_id,player_type,country_code INTO v_owner,v_player_type,v_country
 FROM public.players WHERE id=p_player_id;
 IF v_player_type IS NULL OR v_player_type<>'human' OR v_owner IS NULL THEN
   RETURN jsonb_build_object('status','not_human'); END IF;
 IF auth.uid() IS NOT NULL AND auth.uid()<>v_owner THEN
   RAISE EXCEPTION 'Not authorized for this player'; END IF;

 SELECT * INTO d FROM public.get_current_game_day_internal_v1();
 IF d.month=12 AND d.day=31 THEN
   v_target_season:=d.season+1;
 ELSIF d.month=1 AND d.day<=7 AND d.season>1 THEN
   v_target_season:=d.season;
 ELSE
   RETURN jsonb_build_object('status','outside_year_end_window');
 END IF;
 v_previous_season:=v_target_season-1;
 v_current_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
 v_target_start:=public.game_day_absolute_v1(v_target_season,1::smallint,1::smallint);
 v_target_end:=public.game_day_absolute_v1(v_target_season,12::smallint,31::smallint);

 SELECT * INTO v_previous FROM public.player_sponsor_contracts
 WHERE player_id=p_player_id AND season=v_previous_season AND status IN('active','completed')
 ORDER BY created_at DESC LIMIT 1;
 IF v_previous.id IS NULL THEN RETURN jsonb_build_object('status','no_previous_sponsor'); END IF;
 IF EXISTS(SELECT 1 FROM public.player_sponsor_contracts
      WHERE player_id=p_player_id AND season=v_target_season)
 OR EXISTS(SELECT 1 FROM public.player_sponsor_renewal_reservations_v1
      WHERE player_id=p_player_id AND target_season=v_target_season) THEN
   RETURN jsonb_build_object('status','already_signed_or_reserved'); END IF;

 -- A renewal is offered only after the official previous-season Dec 31 snapshot.
 SELECT ranking_position INTO v_rank FROM public.player_ranking_snapshots
 WHERE player_id=p_player_id AND season=v_previous_season
   AND game_absolute_day=public.game_day_absolute_v1(v_previous_season,12::smallint,31::smallint)
 ORDER BY created_at DESC LIMIT 1;
 IF v_rank IS NULL THEN RETURN jsonb_build_object('status','awaiting_final_rankings'); END IF;

 SELECT * INTO v_sponsor FROM public.sponsor_companies WHERE id=v_previous.sponsor_company_id;
 IF v_sponsor.id IS NULL OR NOT v_sponsor.is_active THEN
   RETURN jsonb_build_object('status','previous_sponsor_unavailable'); END IF;
 -- Below 301 there can be no worldwide offers, including renewals.
 IF v_rank>300 AND v_sponsor.is_worldwide THEN
   RETURN jsonb_build_object('status','worldwide_renewal_not_eligible'); END IF;

 SELECT group_code INTO v_market_group FROM public.sponsor_market_group_members
 WHERE country_code=v_country;
 IF v_market_group IS NULL THEN RAISE EXCEPTION 'Sponsor market not configured'; END IF;
 IF NOT v_sponsor.is_worldwide AND NOT EXISTS (
   SELECT 1 FROM public.sponsor_market_group_members
   WHERE country_code=v_sponsor.country_code AND group_code=v_market_group
 ) THEN RETURN jsonb_build_object('status','outside_current_market'); END IF;

 SELECT * INTO v_rule FROM public.sponsor_offer_rules
 WHERE is_active AND v_rank>=rank_min AND (rank_max IS NULL OR v_rank<=rank_max)
 ORDER BY rank_min DESC LIMIT 1;
 IF v_rule.code IS NULL THEN RAISE EXCEPTION 'No sponsor rule for rank %',v_rank; END IF;

 IF v_rule.rank_max IS NULL THEN
   v_progress:=least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/699));
 ELSE
   v_progress:=least(1::numeric,greatest(0::numeric,
       (v_rank-v_rule.rank_min)::numeric/greatest(1,v_rule.rank_max-v_rule.rank_min)::numeric));
 END IF;
 v_market:=v_rule.full_season_value_max-v_progress*
      (v_rule.full_season_value_max-v_rule.full_season_value_min);
 v_growth:=least(.50::numeric,greatest(0::numeric,
     (coalesce(v_previous.player_rank_at_sign,v_rank)-v_rank)::numeric/
      greatest(1,coalesce(v_previous.player_rank_at_sign,v_rank))::numeric*.50));
 v_value:=greatest(v_rule.full_season_value_min,least(v_rule.full_season_value_max,
      (round(greatest(
        v_previous.full_season_value*(1+v_growth),
        v_market*(.95+.10*public.sponsor_hash_unit_v1(
           'main-renewal:'||p_player_id::text||':'||v_target_season::text||':'||v_sponsor.id::text))
       )/100)*100)::bigint));
 v_weekly:=greatest(50::bigint,(round((v_value::numeric/52)/10)*10)::bigint);
 v_count:=(floor((v_target_end-(v_target_start+6))::numeric/7)+1)::smallint;

 INSERT INTO public.player_sponsor_offers(
   player_id,sponsor_company_id,season,offer_rule_code,offer_week_start_absolute_day,
   generated_absolute_day,expires_absolute_day,first_payment_absolute_day,player_rank,
   player_market_group_code,source_pool,full_season_value,weekly_payment_amount,
   scheduled_payment_count,total_contract_value,is_renewal,renewal_previous_contract_id)
 VALUES(p_player_id,v_sponsor.id,v_target_season,v_rule.code,v_target_start,
   v_current_abs,v_target_start+6,v_target_start+6,v_rank,v_market_group,
   CASE WHEN v_sponsor.is_worldwide THEN 'worldwide' ELSE 'market' END,
   v_value,v_weekly,v_count,v_weekly*v_count,true,v_previous.id)
 ON CONFLICT DO NOTHING RETURNING id INTO v_offer_id;

 IF v_offer_id IS NULL THEN
   SELECT id INTO v_offer_id FROM public.player_sponsor_offers
   WHERE player_id=p_player_id AND sponsor_company_id=v_sponsor.id
      AND season=v_target_season AND offer_week_start_absolute_day=v_target_start
      AND is_renewal=true AND status='open'
   LIMIT 1;
 END IF;
 RETURN jsonb_build_object('status',case when v_offer_id IS NULL then 'already_present'
     else 'renewal_offer_ready' end,'offer_id',v_offer_id,
     'target_season',v_target_season,'final_year_end_rank',v_rank);
END $fn$;
REVOKE ALL ON FUNCTION public.ensure_player_main_sponsor_renewal_v1(uuid)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.activate_player_main_sponsor_renewal_v1(
 p_player_id uuid,p_through_absolute_day integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $fn$
DECLARE
 v_owner uuid; v_current_season integer; v_start integer;
 v_booking public.player_sponsor_renewal_reservations_v1%rowtype;
 v_offer public.player_sponsor_offers%rowtype; v_new uuid; v_existing uuid;
BEGIN
 SELECT owner_user_id INTO v_owner FROM public.players
 WHERE id=p_player_id AND player_type='human';
 IF v_owner IS NULL THEN RETURN jsonb_build_object('status','no_human_player'); END IF;
 IF auth.uid() IS NOT NULL AND auth.uid()<>v_owner THEN
   RAISE EXCEPTION 'Not authorized for this player'; END IF;
 SELECT season INTO v_current_season FROM public.game_clock WHERE id=1;
 v_start:=public.game_day_absolute_v1(v_current_season,1::smallint,1::smallint);
 IF p_through_absolute_day<v_start THEN
   RETURN jsonb_build_object('status','not_due'); END IF;

 SELECT * INTO v_booking FROM public.player_sponsor_renewal_reservations_v1
 WHERE player_id=p_player_id AND target_season=v_current_season
 FOR UPDATE;
 IF v_booking.offer_id IS NULL THEN RETURN jsonb_build_object('status','no_reservation'); END IF;
 IF v_booking.activated_contract_id IS NOT NULL THEN
   RETURN jsonb_build_object('status','already_activated','contract_id',v_booking.activated_contract_id);
 END IF;
 SELECT * INTO v_offer FROM public.player_sponsor_offers
 WHERE id=v_booking.offer_id AND player_id=p_player_id
   AND season=v_current_season AND is_renewal=true AND status='accepted';
 IF v_offer.id IS NULL THEN RAISE EXCEPTION 'Accepted renewal offer missing'; END IF;
 SELECT id INTO v_existing FROM public.player_sponsor_contracts
 WHERE player_id=p_player_id AND season=v_current_season;
 IF v_existing IS NOT NULL THEN
   RAISE EXCEPTION 'Cannot activate renewal: a contract already exists for the target season';
 END IF;
 INSERT INTO public.player_sponsor_contracts(
   player_id,sponsor_company_id,offer_id,season,
   signed_absolute_day,start_absolute_day,first_payment_absolute_day,end_absolute_day,
   player_rank_at_sign,player_market_group_code,source_pool,
   full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value,
   performance_bonus_pool,objective_plan_version,status)
 VALUES(p_player_id,v_offer.sponsor_company_id,v_offer.id,v_offer.season,
   v_booking.accepted_absolute_day,v_start,v_offer.first_payment_absolute_day,
   public.game_day_absolute_v1(v_current_season,12::smallint,31::smallint),
   v_offer.player_rank,v_offer.player_market_group_code,v_offer.source_pool,
   v_offer.full_season_value,v_offer.weekly_payment_amount,v_offer.scheduled_payment_count,
   v_offer.total_contract_value,v_offer.performance_bonus_pool,2,'active')
 RETURNING id INTO v_new;
 UPDATE public.player_sponsor_renewal_reservations_v1
 SET activated_contract_id=v_new,activated_at=now()
 WHERE player_id=p_player_id AND target_season=v_current_season;
 UPDATE public.player_sponsor_offers
 SET status='expired',updated_at=now()
 WHERE player_id=p_player_id AND season=v_current_season AND status='open';
 RETURN jsonb_build_object('status','activated','contract_id',v_new,
   'target_season',v_current_season);
END $fn$;
REVOKE ALL ON FUNCTION public.activate_player_main_sponsor_renewal_v1(uuid,integer)
 FROM PUBLIC,anon,authenticated;
