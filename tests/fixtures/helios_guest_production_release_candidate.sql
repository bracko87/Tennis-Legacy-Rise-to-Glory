-- Helios production release candidate. Installation is inert by default.
-- Public registration gate is not changed; the erasure gate is independent.
DO $guard$
BEGIN
 IF EXISTS(SELECT 1 FROM public.registration_control WHERE singleton_id AND guest_test_enabled)
 OR EXISTS(SELECT 1 FROM auth.users WHERE is_anonymous)
 OR EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1)
 THEN RAISE EXCEPTION 'Installation requires disabled Guest Mode and no existing guests'; END IF;
END $guard$;
CREATE TABLE control_center_private.tennis_guest_erasure_control_v1(
 singleton_id boolean PRIMARY KEY CHECK(singleton_id),
 enabled boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE control_center_private.tennis_guest_erasure_control_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tennis_guest_erasure_control_v1 FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO control_center_private.tennis_guest_erasure_control_v1(singleton_id,enabled) VALUES(true,false);
ALTER TABLE control_center_private.tennis_guest_trials_v1
 ADD COLUMN erasure_attempts integer NOT NULL DEFAULT 0 CHECK(erasure_attempts>=0),
 ADD COLUMN erasure_last_attempt_at timestamptz,
 ADD COLUMN erasure_next_attempt_at timestamptz,
 ADD COLUMN erasure_hold_code text;
ALTER TABLE public.players ADD COLUMN guest_history_erased_at timestamptz;
ALTER TABLE public.players DROP CONSTRAINT players_owner_by_type_check;
ALTER TABLE public.players ADD CONSTRAINT players_owner_by_type_check CHECK (
 (player_type='human' AND owner_user_id IS NOT NULL AND guest_history_erased_at IS NULL)
 OR (player_type='ai' AND owner_user_id IS NULL AND guest_history_erased_at IS NULL)
 OR (player_type='human' AND owner_user_id IS NULL AND guest_history_erased_at IS NOT NULL
     AND moderation_status='rejected' AND first_name='Retired' AND last_name='Guest'
     AND image_path IS NULL AND home_city IS NULL)
);
CREATE FUNCTION control_center_private.guard_tennis_guest_history_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
AS $guard$
BEGIN
 IF TG_OP='INSERT' THEN
   IF NEW.guest_history_erased_at IS NOT NULL THEN
     RAISE EXCEPTION 'Historical guest markers are server generated' USING errcode='42501';
   END IF;
   RETURN NEW;
 END IF;
 IF OLD.guest_history_erased_at IS NOT NULL THEN
   IF NEW.guest_history_erased_at IS DISTINCT FROM OLD.guest_history_erased_at
      OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
      OR NEW.first_name IS DISTINCT FROM OLD.first_name
      OR NEW.last_name IS DISTINCT FROM OLD.last_name
      OR NEW.country_code IS DISTINCT FROM OLD.country_code
      OR NEW.world IS DISTINCT FROM OLD.world
      OR NEW.player_type IS DISTINCT FROM OLD.player_type
      OR NEW.image_path IS DISTINCT FROM OLD.image_path
      OR NEW.home_city IS DISTINCT FROM OLD.home_city
      OR NEW.moderation_status IS DISTINCT FROM OLD.moderation_status
   THEN RAISE EXCEPTION 'Erased historical identity cannot be reassigned or reactivated' USING errcode='42501'; END IF;
   RETURN NEW;
 END IF;
 IF NEW.guest_history_erased_at IS NOT NULL THEN
   -- Neither a signed-in user nor a user-invoked SECURITY DEFINER RPC may
   -- manufacture an erased identity. Server-only migration/worker context.
   IF current_user <> 'postgres' OR auth.uid() IS NOT NULL THEN
     RAISE EXCEPTION 'Historical erasure requires a private server context' USING errcode='42501';
   END IF;
   IF OLD.owner_user_id IS NULL OR OLD.player_type<>'human'
      OR OLD.moderation_status<>'rejected'
      OR NOT EXISTS(
        SELECT 1 FROM auth.users u
        JOIN control_center_private.tennis_guest_trials_v1 g ON g.user_id=u.id
        WHERE u.id=OLD.owner_user_id AND u.is_anonymous
          AND g.retired_at IS NOT NULL AND g.expires_at<=now() AND g.converted_at IS NULL
      )
   THEN RAISE EXCEPTION 'Only a retired, unconverted guest can become a history-only identity' USING errcode='42501'; END IF;
 END IF;
 RETURN NEW;
END;
$guard$;
REVOKE ALL ON FUNCTION control_center_private.guard_tennis_guest_history_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER aa_guard_tennis_guest_history_v1
BEFORE INSERT OR UPDATE ON public.players FOR EACH ROW
EXECUTE FUNCTION control_center_private.guard_tennis_guest_history_v1();

CREATE FUNCTION control_center_private.erase_tennis_guest_owned_scope_v1(
 target_table regclass, target_key name, target_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'pg_catalog','pg_temp'
AS $scope$
DECLARE fk record; join_sql text; has_child boolean; has_target boolean;
BEGIN
 IF current_user<>'postgres' OR auth.uid() IS NOT NULL THEN
   RAISE EXCEPTION 'Private server context required' USING errcode='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=target_table AND attname=target_key
       AND atttypid='uuid'::regtype AND attnum>0 AND NOT attisdropped)
 THEN RAISE EXCEPTION 'Unexpected cleanup scope schema'; END IF;
 EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s WHERE %I=$1)',target_table,target_key) INTO has_target USING target_id;
 IF NOT has_target THEN RETURN; END IF;
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
REVOKE ALL ON FUNCTION control_center_private.erase_tennis_guest_owned_scope_v1(regclass,name,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION control_center_private.erase_retired_tennis_guest_v1(p_user uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
AS $fn$
DECLARE p uuid; tbl text; key_col name; fk record; has_row boolean; claim text; child_id uuid; shared record;
BEGIN
 IF current_user<>'postgres' OR auth.uid() IS NOT NULL THEN
   RAISE EXCEPTION 'Private server context required' USING errcode='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_erasure_control_v1 WHERE singleton_id AND enabled)
 THEN RAISE EXCEPTION 'Guest erasure disabled' USING errcode='42501'; END IF;
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
   -- Shared governance is deliberately not reassigned by a cleanup job.
   IF EXISTS(SELECT 1 FROM public.tennis_clubs WHERE owner_player_id=p)
   OR EXISTS(SELECT 1 FROM public.national_captain_terms WHERE player_id=p OR user_id=p_user)
   OR EXISTS(SELECT 1 FROM public.national_captain_candidates WHERE player_id=p OR user_id=p_user)
   OR EXISTS(SELECT 1 FROM public.national_association_contributions WHERE user_id=p_user)
   OR EXISTS(SELECT 1 FROM public.national_captain_votes WHERE voter_user_id=p_user)
   THEN RAISE EXCEPTION 'Shared governance requires operator review'; END IF;
   -- Detach first: actual player UPDATE hooks can recreate personal rows.
   -- Do not change country/world or official result references.
   UPDATE public.players SET owner_user_id=NULL,first_name='Retired',last_name='Guest',
     image_path=NULL,home_city=NULL,guest_history_erased_at=now() WHERE id=p;
   -- Clear owned children before deleting their parents; the helper refuses
   -- any still-referencing child (including a different player's data).
   FOR child_id IN SELECT id FROM public.player_training_camp_bookings WHERE player_id=p FOR UPDATE LOOP
     PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.player_training_camp_staff'::regclass,'booking_id',child_id);
   END LOOP;
   FOR child_id IN SELECT id FROM public.player_equipment_match_setups WHERE player_id=p FOR UPDATE LOOP
     PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.player_equipment_match_setup_accessories'::regclass,'setup_id',child_id);
   END LOOP;
   -- Lock staff before removing contracts; do not release anyone under a different career.
   FOR shared IN SELECT id FROM public.staff_members WHERE current_player_id=p FOR UPDATE LOOP
     IF EXISTS(SELECT 1 FROM public.player_staff_contracts WHERE staff_id=shared.id AND player_id<>p AND status='active')
     THEN RAISE EXCEPTION 'Shared staff contract requires review'; END IF;
     UPDATE public.staff_members SET current_player_id=NULL,status='available',updated_at=now()
       WHERE id=shared.id AND current_player_id=p;
   END LOOP;
   -- Remove guest-authored private messages, not the other player's messages.
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.player_messages'::regclass,'sender_player_id',p);
   FOR child_id IN SELECT id FROM public.player_conversations c WHERE p IN(c.player_one_id,c.player_two_id)
     AND NOT EXISTS(SELECT 1 FROM public.player_messages m WHERE m.conversation_id=c.id) FOR UPDATE LOOP
     PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.player_conversations'::regclass,'id',child_id);
   END LOOP;
   -- Relationship requests may be removed for the departing participant; no
   -- existing club or other member is deleted.
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.tennis_club_requests'::regclass,'player_id',p);
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.tennis_club_requests'::regclass,'created_by_player_id',p);
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.tournament_doubles_partner_invitations'::regclass,'inviter_player_id',p);
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.tournament_doubles_partner_invitations'::regclass,'invitee_player_id',p);
   -- Break only this guest's sponsor renewal links; other careers still block.
   UPDATE public.player_sponsor_offers SET renewal_previous_contract_id=NULL
     WHERE player_id=p AND renewal_previous_contract_id IN(SELECT id FROM public.player_sponsor_contracts WHERE player_id=p);
   FOREACH tbl IN ARRAY ARRAY['technical_sponsor_equipment_claims',
 'player_sponsor_renewal_reservations_v1',
 'player_sponsor_objectives',
 'player_sponsor_contracts',
 'player_sponsor_offers',
 'player_technical_sponsor_contracts',
 'player_technical_sponsor_offers',
 'player_training_camp_days',
 'player_training_camp_bookings',
 'staff_negotiation_offers',
 'staff_negotiations',
 'staff_financial_events',
 'player_staff_contracts',
 'national_team_chat_presence',
 'national_team_chat_messages',
 'national_association_memberships',
 'tennis_club_chat_messages',
 'tennis_club_chat_read_state_v1',
 'tennis_club_memberships',
 'player_opponent_scouting_tasks',
 'tournament_doubles_partner_listings',
 'player_premium_season_targets',
 'player_premium_tournament_watches',
 'player_match_condition_events',
 'player_doubles_match_condition_events'] LOOP
     PERFORM control_center_private.erase_tennis_guest_owned_scope_v1(('public.'||tbl)::regclass,'player_id',p);
   END LOOP;
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
 'player_private_jet_positions',
 'private_life_asset_events',
 'private_life_asset_sale_listings',
 'private_life_investment_trades',
 'private_life_investment_positions',
 'private_life_player_assets',
 'career_tax_periods',
 'career_finance_transactions',
 'player_career_finance_accounts',
 'new_player_initialization_audit'] LOOP
     PERFORM control_center_private.erase_tennis_guest_owned_scope_v1(('public.'||tbl)::regclass,'player_id',p);
   END LOOP;
 END IF;
 FOR child_id IN SELECT id FROM public.avatar_replacement_requests WHERE user_id=p_user FOR UPDATE LOOP
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('public.avatar_replacement_request_history'::regclass,'request_id',child_id);
 END LOOP;
 FOREACH tbl IN ARRAY ARRAY['referral_activity_days',
 'birthday_email_outbox',
 'avatar_replacement_requests','user_notifications',
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
   PERFORM control_center_private.erase_tennis_guest_owned_scope_v1(('public.'||tbl)::regclass,key_col,p_user);
 END LOOP;
 PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('control_center_private.tennis_active_player_presence_v1'::regclass,'user_id',p_user);
 -- Remove direct account association without changing analytics aggregates.
 UPDATE public.site_analytics_daily_sessions SET user_id=NULL WHERE user_id=p_user;
 UPDATE public.site_analytics_daily_visitors SET user_id=NULL WHERE user_id=p_user;
 claim:=md5('tennis-guest-premium-v1:'||p_user::text);
 IF NOT EXISTS(SELECT 1 FROM public.tennis_premium_trials_v1 WHERE email_claim_hash=claim) THEN
   DELETE FROM public.tennis_premium_trial_claims_v1 WHERE email_claim_hash=claim;
 END IF;
 PERFORM control_center_private.erase_tennis_guest_owned_scope_v1('control_center_private.tennis_guest_trials_v1'::regclass,'user_id',p_user);
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
 'tournament_match_player_stats.player_id','player_conversations.player_one_id','player_conversations.player_two_id'])
     THEN CONTINUE; END IF;
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s WHERE %I=$1)',fk.conrelid::regclass,fk.col)
       INTO has_row USING p;
   END IF;
   IF has_row THEN RAISE EXCEPTION 'Unreviewed identity dependency: %.%.%',fk.nspname,fk.relname,fk.col; END IF;
 END LOOP;
 -- Explicit non-FK identity columns must not silently leak an old account ID.
 FOR fk IN SELECT n.nspname,r.relname,a.attname AS col
 FROM pg_attribute a JOIN pg_class r ON r.oid=a.attrelid
 JOIN pg_namespace n ON n.oid=r.relnamespace
 WHERE n.nspname IN('public','control_center_private') AND r.relkind IN('r','p')
   AND a.attnum>0 AND NOT a.attisdropped AND a.atttypid='uuid'::regtype
   AND a.attname ~ '(user_id|player_id|player[12]_id|owner_id|sender_id|recipient_id)$'
   AND NOT EXISTS(SELECT 1 FROM pg_constraint con WHERE con.conrelid=r.oid AND con.contype='f' AND a.attnum=ANY(con.conkey))
 LOOP
   IF fk.col ~ '(user_id|owner_id|sender_id|recipient_id)$' THEN
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I WHERE %I=$1)',fk.nspname,fk.relname,fk.col) INTO has_row USING p_user;
   ELSIF p IS NOT NULL THEN
     IF fk.nspname='public' AND fk.relname='tournament_qualifier_slots' AND fk.col='filled_player_id' THEN CONTINUE; END IF;
     EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I.%I WHERE %I=$1)',fk.nspname,fk.relname,fk.col) INTO has_row USING p;
   ELSE CONTINUE; END IF;
   IF has_row THEN RAISE EXCEPTION 'Unreviewed non-FK identity dependency: %.%.%',fk.nspname,fk.relname,fk.col; END IF;
 END LOOP;
 DELETE FROM auth.users WHERE id=p_user AND is_anonymous IS TRUE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Auth deletion failed'; END IF;
END;
$fn$;
REVOKE ALL ON FUNCTION control_center_private.erase_retired_tennis_guest_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;


CREATE FUNCTION control_center_private.erase_expired_tennis_guests_v1(p_max integer DEFAULT 20)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog','pg_temp'
SET lock_timeout TO '1s'
AS $batch$
DECLARE g record; erased integer:=0; held integer:=0; hold_code text; state text; message text;
BEGIN
 IF current_user<>'postgres' OR auth.uid() IS NOT NULL THEN
   RAISE EXCEPTION 'Private server context required' USING errcode='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_erasure_control_v1 WHERE singleton_id AND enabled FOR SHARE)
 THEN RETURN jsonb_build_object('status','disabled','erased',0,'held',0); END IF;
 IF NOT pg_try_advisory_xact_lock(hashtextextended('helios-guest-erasure-batch-v1',0)) THEN
   RETURN jsonb_build_object('status','busy','erased',0,'held',0);
 END IF;
 FOR g IN SELECT t.user_id FROM control_center_private.tennis_guest_trials_v1 t
   JOIN auth.users u ON u.id=t.user_id
   WHERE u.is_anonymous AND t.converted_at IS NULL AND t.retired_at IS NOT NULL AND t.expires_at<=now()
   AND (t.erasure_next_attempt_at IS NULL OR t.erasure_next_attempt_at<=now())
   ORDER BY t.erasure_next_attempt_at NULLS FIRST,t.expires_at,t.user_id
   LIMIT least(greatest(coalesce(p_max,20),1),20)
   FOR UPDATE OF u SKIP LOCKED
 LOOP
   BEGIN
     PERFORM control_center_private.erase_retired_tennis_guest_v1(g.user_id);
     erased:=erased+1;
   EXCEPTION WHEN OTHERS THEN
     GET STACKED DIAGNOSTICS state=RETURNED_SQLSTATE,message=MESSAGE_TEXT;
     -- Never record SQLERRM or guest data. Store only a bounded diagnostic code.
     hold_code:=CASE
       WHEN message='Financial records need separate retention review' THEN 'financial'
       WHEN message='Shared governance requires operator review' THEN 'governance'
       WHEN message='Storage or privileged identity requires separate review' THEN 'storage_or_privileged'
       WHEN message='Unfinished competition activity' THEN 'unfinished_match'
       WHEN message LIKE 'Shared or unresolved dependent record:%' OR message LIKE 'Unreviewed identity dependency:%' OR message LIKE 'Unreviewed non-FK identity dependency:%' OR message='Shared staff contract requires review' THEN 'shared_dependency'
       WHEN state IN('55P03','40P01','40001') THEN 'transient_lock'
       ELSE 'unexpected_error' END;
     UPDATE control_center_private.tennis_guest_trials_v1
     SET erasure_attempts=least(erasure_attempts,1000000)+1,
         erasure_last_attempt_at=now(),
         erasure_next_attempt_at=now()+CASE WHEN hold_code IN('unfinished_match','transient_lock') THEN interval '15 minutes' ELSE interval '24 hours' END,
         erasure_hold_code=hold_code
     WHERE user_id=g.user_id AND converted_at IS NULL AND retired_at IS NOT NULL;
     held:=held+1;
   END;
 END LOOP;
 RETURN jsonb_build_object('status','processed','erased',erased,'held',held);
END;
$batch$;
REVOKE ALL ON FUNCTION control_center_private.erase_expired_tennis_guests_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
-- Cron starts inert: the independent private switch remains false.
SELECT cron.schedule('helios-expired-guest-erasure-v1','*/5 * * * *',
 'SET statement_timeout = ''45s''; SELECT control_center_private.erase_expired_tennis_guests_v1(20);');
