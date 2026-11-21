-- Executable, production-column-compatible CORE erasure candidate.
-- NOT a migration or scheduled worker. Deliberately fail closed on uncovered
-- dependencies; no claim of complete production data erasure.
-- No dynamic cascading: each fixed, owned scope is checked before deletion.
CREATE FUNCTION control_center_private.helios_candidate_erase_owned_scope(
 target_table regclass, target_key name, target_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'pg_catalog','pg_temp'
AS $scope$
DECLARE fk record; join_sql text; has_child boolean;
BEGIN
 IF current_user<>'postgres' OR auth.uid() IS NOT NULL THEN
   RAISE EXCEPTION 'Private server context required' USING errcode='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=target_table AND attname=target_key
       AND atttypid='uuid'::regtype AND attnum>0 AND NOT attisdropped)
 THEN RAISE EXCEPTION 'Unexpected cleanup scope schema'; END IF;
 -- Lock the exact rows; a concurrent FK insertion must serialize with delete.
 EXECUTE format('SELECT 1 FROM %s WHERE %I=$1 FOR UPDATE',target_table,target_key) USING target_id;
 FOR fk IN SELECT oid,conrelid,conkey,confkey FROM pg_constraint
           WHERE contype='f' AND confrelid=target_table
 LOOP
   SELECT string_agg(format('c.%I=p.%I', ca.attname, pa.attname),' AND ' ORDER BY k.ord)
     INTO join_sql
   FROM unnest(fk.conkey,fk.confkey) WITH ORDINALITY AS k(child_att,parent_att,ord)
   JOIN pg_attribute ca ON ca.attrelid=fk.conrelid AND ca.attnum=k.child_att
   JOIN pg_attribute pa ON pa.attrelid=target_table AND pa.attnum=k.parent_att;
   IF join_sql IS NULL THEN RAISE EXCEPTION 'Unexpected foreign key shape'; END IF;
   EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s c JOIN %s p ON %s WHERE p.%I=$1)',
                   fk.conrelid::regclass,target_table,join_sql,target_key)
     INTO has_child USING target_id;
   IF has_child THEN
      RAISE EXCEPTION 'Shared or unresolved dependent record: % -> %',fk.conrelid::regclass,target_table;
   END IF;
 END LOOP;
 EXECUTE format('DELETE FROM %s WHERE %I=$1',target_table,target_key) USING target_id;
END;
$scope$;
REVOKE ALL ON FUNCTION control_center_private.helios_candidate_erase_owned_scope(regclass,name,uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION control_center_private.helios_core_guest_erasure_candidate(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
AS $fn$
DECLARE p uuid; tbl text; key_col name; fk record; has_row boolean; claim text;
BEGIN
 IF current_user<>'postgres' OR auth.uid() IS NOT NULL THEN
   RAISE EXCEPTION 'Private server context required' USING errcode='42501';
 END IF;
 PERFORM 1 FROM auth.users WHERE id=p_user AND is_anonymous FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Not an anonymous identity' USING errcode='42501'; END IF;
 PERFORM 1 FROM control_center_private.tennis_guest_trials_v1
 WHERE user_id=p_user AND expires_at<=now() AND converted_at IS NULL AND retired_at IS NOT NULL
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Not eligible for erasure' USING errcode='42501'; END IF;
 IF EXISTS(SELECT 1 FROM public.billing_transactions WHERE user_id=p_user)
 OR EXISTS(SELECT 1 FROM public.commerce_checkout_intents WHERE user_id=p_user)
 OR EXISTS(SELECT 1 FROM public.coin_ledger WHERE user_id=p_user)
 OR EXISTS(SELECT 1 FROM public.user_wallets WHERE user_id=p_user
    AND (coins_balance<>0 OR lifetime_coins_earned<>0 OR lifetime_coins_spent<>0))
 OR EXISTS(SELECT 1 FROM public.premium_memberships WHERE user_id=p_user
 AND (plan_code IS DISTINCT FROM 'free' OR status IS DISTINCT FROM 'active'
 OR monthly_price_eur_cents<>0 OR coalesce(billing_amount_eur_cents,0)<>0
 OR current_period_end IS NOT NULL OR stripe_customer_id IS NOT NULL
 OR stripe_subscription_id IS NOT NULL OR stripe_price_id IS NOT NULL))
 THEN RAISE EXCEPTION 'Financial records need separate retention review'; END IF;
 IF EXISTS(SELECT 1 FROM storage.objects WHERE owner_id=p_user::text OR owner=p_user)
 OR EXISTS(SELECT 1 FROM public.app_admins WHERE user_id=p_user)
 THEN RAISE EXCEPTION 'Storage or privileged identity requires separate review'; END IF;
 IF (SELECT count(*) FROM public.players WHERE owner_user_id=p_user)>1
 THEN RAISE EXCEPTION 'Unexpected multiple careers'; END IF;
 SELECT id INTO p FROM public.players WHERE owner_user_id=p_user FOR UPDATE;
 IF p IS NOT NULL THEN
   IF NOT EXISTS(SELECT 1 FROM public.players WHERE id=p AND player_type='human' AND moderation_status='rejected')
   THEN RAISE EXCEPTION 'Career not retired' USING errcode='42501'; END IF;
   IF EXISTS(SELECT 1 FROM public.tournament_matches
     WHERE p IN(player1_id,player2_id) AND status IN('scheduled','in_progress'))
   OR EXISTS(SELECT 1 FROM public.tournament_doubles_matches m JOIN public.tournament_doubles_teams t
     ON t.id IN(m.team1_id,m.team2_id) WHERE p IN(t.player1_id,t.player2_id) AND m.status IN('scheduled','in_progress'))
   OR EXISTS(SELECT 1 FROM public.tournament_entries WHERE player_id=p AND entry_status='active')
   OR EXISTS(SELECT 1 FROM public.tournament_applications WHERE player_id=p AND status IN('applied','accepted_main_draw','accepted_qualification'))
   THEN RAISE EXCEPTION 'Unfinished competition activity'; END IF;
   -- Detach first: actual player UPDATE hooks can recreate personal rows.
   -- Do not change country/world or official result references.
   UPDATE public.players SET owner_user_id=NULL,first_name='Retired',last_name='Guest',
     image_path=NULL,home_city=NULL,guest_history_erased_at=now() WHERE id=p;
   FOREACH tbl IN ARRAY ARRAY['tournament_applications',
 'player_tournament_preparation_plans',
 'player_tournament_match_tactics',
 'player_doubles_match_tactics',
 'player_tournament_transfer_preferences',
 'player_tournament_travel_selection',
 'player_travel_legs',
 'player_calendar_commitments',
 'player_direct_transfer_morale_state',
 'player_equipment_accessory_loadout',
 'player_equipment_match_setups',
 'player_equipment_loadouts',
 'player_equipment_inventory',
 'player_equipment_broken_starters_v1',
 'player_equipment_wear_events',
 'player_doubles_equipment_wear_events',
 'player_tournament_match_equipment_setups',
 'player_training_plans',
 'player_training_sessions',
 'player_training_progress',
 'player_weekly_training_plan_days',
 'player_skill_history',
 'player_health_setback_events',
 'player_illness_risk_events',
 'player_illnesses',
 'player_injuries',
 'player_injury_risk_events',
 'player_lifestyle_morale_events',
 'player_lifestyle_state',
 'player_daily_activity',
 'player_career_day_processing_state',
 'player_skills',
 'player_tutorial_progress',
 'player_location_state',
 'player_avatar_reservations',
 'career_finance_transactions',
 'player_career_finance_accounts',
 'new_player_initialization_audit'] LOOP
     PERFORM control_center_private.helios_candidate_erase_owned_scope(('public.'||tbl)::regclass,'player_id',p);
   END LOOP;
 END IF;
 FOREACH tbl IN ARRAY ARRAY['user_notifications',
 'notification_preferences',
 'user_interface_preferences_v1',
 'user_language_preferences',
 'referral_codes',
 'referral_user_devices',
 'user_wallets',
 'premium_memberships',
 'tennis_premium_trials_v1',
 'profiles'] LOOP
   key_col:=CASE WHEN tbl='profiles' THEN 'id' ELSE 'user_id' END;
   PERFORM control_center_private.helios_candidate_erase_owned_scope(('public.'||tbl)::regclass,key_col,p_user);
 END LOOP;
 PERFORM control_center_private.helios_candidate_erase_owned_scope('control_center_private.tennis_active_player_presence_v1'::regclass,'user_id',p_user);
 -- Remove direct account association without changing analytics aggregates.
 UPDATE public.site_analytics_daily_sessions SET user_id=NULL WHERE user_id=p_user;
 UPDATE public.site_analytics_daily_visitors SET user_id=NULL WHERE user_id=p_user;
 claim:=md5('tennis-guest-premium-v1:'||p_user::text);
 IF NOT EXISTS(SELECT 1 FROM public.tennis_premium_trials_v1 WHERE email_claim_hash=claim) THEN
   DELETE FROM public.tennis_premium_trial_claims_v1 WHERE email_claim_hash=claim;
 END IF;
 PERFORM control_center_private.helios_candidate_erase_owned_scope('control_center_private.tennis_guest_trials_v1'::regclass,'user_id',p_user);
 -- Inspect every direct FK to the account or historical player. An unreviewed
 -- reference never becomes an implicit CASCADE/SET NULL operation.
 FOR fk IN
 SELECT c.conrelid,c.confrelid,c.confdeltype,c.conkey,c.confkey,n.nspname,r.relname,
        a.attname AS col, b.attname AS parent_col
 FROM pg_constraint c JOIN pg_class r ON r.oid=c.conrelid JOIN pg_namespace n ON n.oid=r.relnamespace
 JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=c.conkey[1]
 JOIN pg_attribute b ON b.attrelid=c.confrelid AND b.attnum=c.confkey[1]
 WHERE c.contype='f' AND c.confrelid IN('auth.users'::regclass,'public.players'::regclass)
 LOOP
   IF cardinality(fk.conkey)<>1 OR cardinality(fk.confkey)<>1 OR fk.parent_col<>'id'
   THEN RAISE EXCEPTION 'Unsupported identity foreign key'; END IF;
   IF fk.confrelid='auth.users'::regclass THEN
     -- Only Supabase-managed Auth cascades; arbitrary public/private rows block.
     IF fk.nspname='auth' AND fk.confdeltype='c'
       AND fk.relname=ANY(ARRAY['identities','mfa_factors','mfa_recovery_code_sets','oauth_authorizations','oauth_consents','one_time_tokens','sessions','webauthn_challenges','webauthn_credentials'])
     THEN CONTINUE; END IF;
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s WHERE %I=$1)',fk.conrelid::regclass,fk.col)
       INTO has_row USING p_user;
   ELSE
     IF p IS NULL THEN CONTINUE; END IF;
     IF fk.nspname='public' AND (fk.relname||'.'||fk.col)=ANY(ARRAY['tournament_matches.player1_id',
 'tournament_matches.player2_id',
 'tournament_matches.winner_id',
 'tournament_doubles_teams.player1_id',
 'tournament_doubles_teams.player2_id',
 'tournament_entries.player_id',
 'tournament_match_simulations.final_winner_id',
 'tournament_qualifier_slots.filled_player_id',
 'player_tournament_results.player_id',
 'player_doubles_tournament_results.player_id',
 'player_ranking_snapshots.player_id',
 'player_doubles_ranking_snapshots.player_id',
 'player_ranking_contributions.player_id',
 'player_doubles_ranking_contributions.player_id',
 'player_rankings.player_id',
 'player_doubles_rankings.player_id',
 'tournament_match_player_stats.player_id'])
     THEN CONTINUE; END IF;
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s WHERE %I=$1)',fk.conrelid::regclass,fk.col)
       INTO has_row USING p;
   END IF;
   IF has_row THEN RAISE EXCEPTION 'Unreviewed identity dependency: %.%.%',fk.nspname,fk.relname,fk.col; END IF;
 END LOOP;
 DELETE FROM auth.users WHERE id=p_user AND is_anonymous IS TRUE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Auth deletion failed'; END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION control_center_private.helios_core_guest_erasure_candidate(uuid) FROM PUBLIC,anon,authenticated;
