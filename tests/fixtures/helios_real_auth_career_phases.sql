\set ON_ERROR_STOP on
-- Never invoke outside the CI disposable database. Guard runs before any mutation.
BEGIN;
SET LOCAL statement_timeout='40s';
SELECT set_config('helios.qa_guest', :'guest_id', true);
SELECT set_config('helios.qa_phase', :'phase', true);
DO $qa$
DECLARE uid uuid:=current_setting('helios.qa_guest')::uuid;
 ph text:=current_setting('helios.qa_phase');
 p uuid; a uuid; b uuid; c uuid; comp uuid; future_comp uuid; m uuid;
 team_guest uuid; team_other uuid; result jsonb; staff uuid; contract uuid; booking uuid; offer uuid; sponsor uuid; asset uuid; fin uuid; conv uuid; club uuid;
BEGIN
 IF to_regclass('control_center_private.helios_real_auth_ci_marker') IS NULL
 THEN RAISE EXCEPTION 'CI database marker missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM control_center_private.helios_real_auth_ci_marker WHERE id)
 THEN RAISE EXCEPTION 'Invalid CI database marker'; END IF;
 IF ph='gate_off' OR ph='gate_on' THEN
   UPDATE public.registration_control SET guest_test_enabled=(ph='gate_on') WHERE singleton_id=true;
   RETURN;
 END IF;
 SELECT id INTO STRICT p FROM public.players WHERE owner_user_id=uid AND player_type='human';
 IF ph='seed' THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND is_anonymous) THEN RAISE EXCEPTION 'Expected synthetic real Auth guest'; END IF;
   -- Production signup initializes an ordinary free membership row.
   INSERT INTO public.premium_memberships(user_id) VALUES(uid);
   INSERT INTO public.player_equipment_inventory(player_id,condition) VALUES(p,73);
   INSERT INTO public.player_equipment_loadouts(player_id,racket_inventory_id)
     SELECT p,id FROM public.player_equipment_inventory WHERE player_id=p;
   INSERT INTO public.player_skills VALUES(p);
   INSERT INTO public.player_location_state VALUES(p);
   INSERT INTO public.new_player_initialization_audit VALUES(p,uid);
   INSERT INTO public.career_finance_transactions(player_id,amount) VALUES(p,1234);
   INSERT INTO public.user_wallets(user_id) VALUES(uid);
   INSERT INTO public.site_analytics_daily_sessions(user_id) VALUES(uid);
   INSERT INTO public.site_analytics_daily_visitors(user_id) VALUES(uid);
   INSERT INTO public.player_career_finance_accounts VALUES(p,1234);
   INSERT INTO public.staff_members(current_player_id,status) VALUES(p,'employed') RETURNING id INTO staff;
   INSERT INTO public.player_staff_contracts(player_id,staff_id) VALUES(p,staff) RETURNING id INTO contract;
   INSERT INTO public.player_training_camp_bookings(player_id) VALUES(p) RETURNING id INTO booking;
   INSERT INTO public.player_training_camp_staff VALUES(booking,contract);
   INSERT INTO public.player_training_camp_days VALUES(p,booking);
   INSERT INTO public.player_sponsor_offers(player_id) VALUES(p) RETURNING id INTO offer;
   INSERT INTO public.player_sponsor_contracts(player_id,offer_id) VALUES(p,offer) RETURNING id INTO sponsor;
   UPDATE public.player_sponsor_offers SET renewal_previous_contract_id=sponsor WHERE id=offer;
   INSERT INTO public.player_sponsor_objectives VALUES(p,sponsor);
   SELECT id INTO fin FROM public.career_finance_transactions WHERE player_id=p LIMIT 1;
   INSERT INTO public.private_life_player_assets(player_id,purchase_transaction_id) VALUES(p,fin) RETURNING id INTO asset;
   INSERT INTO public.private_life_asset_events VALUES(p,asset,fin);
   INSERT INTO public.private_life_asset_sale_listings VALUES(p,asset,fin);
   SELECT id INTO a FROM public.players WHERE player_type='ai' ORDER BY id LIMIT 1;
   INSERT INTO public.player_conversations(player_one_id,player_two_id) VALUES(p,a) RETURNING id INTO conv;
   INSERT INTO public.player_messages VALUES(conv,p,'guest fixture message'),(conv,a,'other player fixture message');
   BEGIN
     UPDATE public.players SET owner_user_id=NULL,moderation_status='rejected',first_name='Retired',
       last_name='Guest',image_path=NULL,home_city=NULL,guest_history_erased_at=now() WHERE id=p;
     RAISE EXCEPTION 'Active guest history transition was not rejected';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
   BEGIN
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Active guest erasure was not rejected';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
 ELSIF ph='verify_converted' THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND NOT is_anonymous)
      OR NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=uid AND converted_at IS NOT NULL AND retired_at IS NULL)
      OR NOT EXISTS(SELECT 1 FROM public.player_equipment_inventory WHERE player_id=p AND condition=73)
      OR NOT EXISTS(SELECT 1 FROM public.player_career_finance_accounts WHERE player_id=p AND balance=1234)
      OR NOT EXISTS(SELECT 1 FROM public.tennis_premium_trials_v1 WHERE user_id=uid AND expires_at=started_at+interval '7 days')
   THEN RAISE EXCEPTION 'Conversion lost original ownership, progress or Premium'; END IF;
   BEGIN
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Converted guest erasure was not rejected';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
 ELSIF ph='expire' THEN
   SELECT id INTO a FROM public.players WHERE player_type='ai' ORDER BY id LIMIT 1;
   SELECT id INTO b FROM public.players WHERE player_type='ai' AND id<>a ORDER BY id LIMIT 1;
   SELECT id INTO c FROM public.players WHERE player_type='ai' AND id NOT IN(a,b) ORDER BY id LIMIT 1;
   SELECT id INTO STRICT comp FROM public.tournament_world_competitions WHERE world='ATP';
   INSERT INTO public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,status)
   VALUES(comp,'main_draw',1,'Semifinal',1,4,1,1,p,a,'scheduled');
   INSERT INTO public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,winner_id,status,started_at,completed_at)
   VALUES(comp,'main_draw',1,'Historical',99,2,1,1,p,b,b,'completed',now()-interval '3 hours',now()-interval '1 hour');
   INSERT INTO public.player_tournament_results VALUES(p,comp,20),(b,comp,40);
   INSERT INTO public.tournament_doubles_teams(competition_id,world,player1_id,player2_id,status,entry_source,combined_ranking_points_snapshot,entry_strength_snapshot)
   VALUES(comp,'ATP',p,b,'active','human',0,0) RETURNING id INTO team_guest;
   INSERT INTO public.player_doubles_tournament_results VALUES(p,team_guest,10),(b,team_guest,10);
   INSERT INTO public.tournament_doubles_teams(competition_id,world,player1_id,player2_id,status,entry_source,combined_ranking_points_snapshot,entry_strength_snapshot)
   VALUES(comp,'ATP',a,c,'active','ai',0,0) RETURNING id INTO team_other;
   INSERT INTO public.tournament_doubles_matches(competition_id,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,team1_id,team2_id,status)
   VALUES(comp,1,'Semifinal',1,4,1,1,team_guest,team_other,'scheduled');
   INSERT INTO public.tournament_applications(competition_id,player_id,status) VALUES(comp,p,'accepted_main_draw');
   INSERT INTO public.tournament_entries(competition_id,player_id,entry_status) VALUES(comp,p,'active');
   -- The bracket trigger eliminates a losing player in the current draw.
   -- Test withdrawal separately using a future entry with no played match.
   INSERT INTO public.tournament_world_competitions(tournament_edition_id,world)
    SELECT tournament_edition_id,world FROM public.tournament_world_competitions WHERE id=comp RETURNING id INTO future_comp;
   INSERT INTO public.tournament_entries(competition_id,player_id,entry_status) VALUES(future_comp,p,'active');
   INSERT INTO public.tournament_applications(competition_id,player_id,status) VALUES(future_comp,p,'applied');
   UPDATE control_center_private.tennis_guest_trials_v1 SET started_at=now()-interval '15 days',expires_at=now()-interval '1 day' WHERE user_id=uid AND converted_at IS NULL;
   UPDATE public.tennis_premium_trials_v1 SET started_at=now()-interval '15 days',expires_at=now()-interval '8 days' WHERE user_id=uid;
 ELSIF ph='retire' THEN
   SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'retired_guests')::int IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Expected exactly one retired real-auth guest'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_matches WHERE player1_id=p AND match_number=1 AND status='walkover' AND winner_id=player2_id)
   THEN RAISE EXCEPTION 'Singles walkover winner incorrect'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_matches WHERE player1_id=p AND match_number=99 AND status='completed' AND winner_id=player2_id)
   THEN RAISE EXCEPTION 'Completed match history changed'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_matches h JOIN public.tournament_matches n ON n.competition_id=h.competition_id AND n.round_number=2 AND (n.player1_id=h.winner_id OR n.player2_id=h.winner_id) WHERE h.player1_id=p AND h.match_number=1)
   THEN RAISE EXCEPTION 'Singles bracket advancement missing'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_doubles_teams t JOIN public.tournament_doubles_matches m ON m.team1_id=t.id WHERE t.player1_id=p AND t.status='withdrawn' AND m.status='walkover' AND m.winner_team_id=m.team2_id)
   THEN RAISE EXCEPTION 'Doubles walkover or team withdrawal incorrect'; END IF;
   IF (SELECT count(*) FROM public.tournament_applications WHERE player_id=p AND status='withdrawn')<>2
   THEN RAISE EXCEPTION 'Accepted or future application not withdrawn'; END IF;
   SELECT competition_id INTO STRICT comp FROM public.tournament_matches WHERE player1_id=p AND match_number=1;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_entries WHERE player_id=p AND competition_id=comp AND entry_status='eliminated')
   THEN RAISE EXCEPTION 'Walkover loser must be eliminated in current draw'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.tournament_entries WHERE player_id=p AND competition_id<>comp AND entry_status='withdrawn')
   THEN RAISE EXCEPTION 'Future entry must be withdrawn'; END IF;
   IF EXISTS(SELECT 1 FROM public.tournament_entries WHERE player_id=p AND entry_status='active')
   THEN RAISE EXCEPTION 'Retired player has active tournament entry'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.players WHERE id=p AND moderation_status='rejected')
   THEN RAISE EXCEPTION 'Retirement moderation marker missing'; END IF;
   SELECT control_center_private.retire_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'retired_guests')::int IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Retirement must be idempotent'; END IF;
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND is_anonymous)
     OR NOT EXISTS(SELECT 1 FROM public.player_equipment_inventory WHERE player_id=p AND condition=73)
     OR NOT EXISTS(SELECT 1 FROM public.player_career_finance_accounts WHERE player_id=p AND balance=1234)
   THEN RAISE EXCEPTION 'Retirement must not silently delete Auth or career records'; END IF;
 ELSIF ph='erase' THEN
   IF control_center_private.erase_expired_tennis_guests_v1(20)->>'status'<>'disabled' THEN RAISE EXCEPTION 'Erasure switch must default to disabled'; END IF;
   BEGIN
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Disabled direct erasure was not rejected';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid) THEN RAISE EXCEPTION 'Disabled worker modified account'; END IF;
   UPDATE control_center_private.tennis_guest_erasure_control_v1 SET enabled=true WHERE singleton_id;
   SELECT staff_id INTO STRICT staff FROM public.player_staff_contracts WHERE player_id=p;
   SELECT id INTO STRICT conv FROM public.player_conversations WHERE player_one_id=p;
   BEGIN
     INSERT INTO public.tennis_clubs(owner_player_id) VALUES(p);
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Club ownership should be held';
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM <> 'Shared governance requires operator review' THEN RAISE; END IF;
   END;
   SELECT id INTO a FROM public.players WHERE player_type='ai' ORDER BY id LIMIT 1;
   BEGIN
     INSERT INTO public.player_equipment_loadouts(player_id,racket_inventory_id)
       SELECT a,id FROM public.player_equipment_inventory WHERE player_id=p;
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Shared inventory dependency was not rejected';
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM NOT LIKE 'Shared or unresolved dependent record:%' THEN RAISE; END IF;
   END;
   BEGIN
     INSERT INTO public.helios_ci_unreviewed_dependency VALUES(p);
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Unknown FK dependency was not rejected';
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM NOT LIKE 'Unreviewed identity dependency:%' THEN RAISE; END IF;
   END;
   BEGIN
     UPDATE public.premium_memberships SET plan_code='premium',monthly_price_eur_cents=999 WHERE user_id=uid;
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Paid guest membership erasure was not rejected';
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM <> 'Financial records need separate retention review' THEN RAISE; END IF;
   END;
   BEGIN
     UPDATE public.players SET owner_user_id=NULL WHERE id=p;
     RAISE EXCEPTION 'Unmarked ownerless human was not rejected';
   EXCEPTION WHEN check_violation THEN NULL;
   END;
   -- Explicitly prove paid/unfinished records are held, using subtransactions
   -- so that the artificial blocking record is rolled back automatically.
   BEGIN
     INSERT INTO public.billing_transactions(user_id,kind,status) VALUES(uid,'premium_invoice','paid');
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'Paid guest erasure was not rejected';
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM <> 'Financial records need separate retention review' THEN RAISE; END IF;
   END;
   BEGIN
     UPDATE public.tournament_matches SET status='in_progress' WHERE player1_id=p AND match_number=99;
     PERFORM control_center_private.helios_ci_erase_retired_guest(uid);
     RAISE EXCEPTION 'In-progress guest erasure was not rejected';
   EXCEPTION WHEN raise_exception THEN
     IF SQLERRM <> 'Unfinished competition activity' THEN RAISE; END IF;
   END;
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid)
      OR NOT EXISTS(SELECT 1 FROM public.player_equipment_inventory WHERE player_id=p AND condition=73)
   THEN RAISE EXCEPTION 'Rejected erasure mutated account records'; END IF;
   -- Hold, classify and defer one synthetic account, then resolve the hold.
   INSERT INTO public.tennis_clubs(owner_player_id) VALUES(p);
   SELECT control_center_private.erase_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'held')::int IS DISTINCT FROM 1 OR (result->>'erased')::int IS DISTINCT FROM 0
     OR NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=uid AND erasure_hold_code='governance' AND erasure_attempts=1 AND erasure_next_attempt_at>now())
   THEN RAISE EXCEPTION 'Held-account classification failed: %',result; END IF;
   SELECT control_center_private.erase_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'held')::int IS DISTINCT FROM 0 OR (result->>'erased')::int IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'Retry delay failed'; END IF;
   DELETE FROM public.tennis_clubs WHERE owner_player_id=p;
   UPDATE control_center_private.tennis_guest_trials_v1 SET erasure_next_attempt_at=now()-interval '1 minute' WHERE user_id=uid;
   SELECT control_center_private.erase_expired_tennis_guests_v1(10) INTO result;
   IF (result->>'erased')::int IS DISTINCT FROM 1 OR (result->>'held')::int IS DISTINCT FROM 0
   THEN RAISE EXCEPTION 'Consolidated batch failed: %',result; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.staff_members WHERE id=staff AND status='available' AND current_player_id IS NULL)
   OR EXISTS(SELECT 1 FROM public.player_staff_contracts WHERE player_id=p)
   OR EXISTS(SELECT 1 FROM public.player_training_camp_bookings WHERE player_id=p)
   OR EXISTS(SELECT 1 FROM public.player_sponsor_contracts WHERE player_id=p)
   OR EXISTS(SELECT 1 FROM public.private_life_player_assets WHERE player_id=p)
   OR EXISTS(SELECT 1 FROM public.player_messages WHERE sender_player_id=p)
   OR NOT EXISTS(SELECT 1 FROM public.player_messages WHERE conversation_id=conv AND body='other player fixture message')
   THEN RAISE EXCEPTION 'Consolidated domain cleanup failed'; END IF;
   IF EXISTS(SELECT 1 FROM auth.users WHERE id=uid)
      OR EXISTS(SELECT 1 FROM auth.sessions WHERE user_id=uid)
      OR EXISTS(SELECT 1 FROM public.profiles WHERE id=uid)
      OR EXISTS(SELECT 1 FROM public.premium_memberships WHERE user_id=uid)
      OR EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=uid)
      OR EXISTS(SELECT 1 FROM public.tennis_premium_trials_v1 WHERE user_id=uid)
      OR EXISTS(SELECT 1 FROM public.player_equipment_inventory WHERE player_id=p)
      OR EXISTS(SELECT 1 FROM public.player_career_finance_accounts WHERE player_id=p)
      OR EXISTS(SELECT 1 FROM public.player_equipment_loadouts WHERE player_id=p)
      OR EXISTS(SELECT 1 FROM public.player_skills WHERE player_id=p)
      OR EXISTS(SELECT 1 FROM public.player_location_state WHERE player_id=p)
      OR EXISTS(SELECT 1 FROM public.new_player_initialization_audit WHERE player_id=p OR user_id=uid)
      OR EXISTS(SELECT 1 FROM public.career_finance_transactions WHERE player_id=p)
      OR EXISTS(SELECT 1 FROM public.user_wallets WHERE user_id=uid)
      OR EXISTS(SELECT 1 FROM public.site_analytics_daily_sessions WHERE user_id=uid)
      OR EXISTS(SELECT 1 FROM public.site_analytics_daily_visitors WHERE user_id=uid)
   THEN RAISE EXCEPTION 'Erased fixture identity or gameplay records remain'; END IF;
   IF NOT EXISTS(SELECT 1 FROM public.players WHERE id=p AND owner_user_id IS NULL
     AND first_name='Retired' AND last_name='Guest' AND image_path IS NULL AND moderation_status='rejected' AND guest_history_erased_at IS NOT NULL)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_matches WHERE player1_id=p AND match_number=99 AND status='completed' AND winner_id=player2_id)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_matches WHERE player1_id=p AND match_number=1 AND status='walkover' AND winner_id=player2_id)
     OR NOT EXISTS(SELECT 1 FROM public.tournament_doubles_teams t JOIN public.tournament_doubles_matches m ON m.team1_id=t.id WHERE t.player1_id=p AND m.status='walkover' AND m.winner_team_id=m.team2_id)
     OR NOT EXISTS(SELECT 1 FROM public.player_tournament_results WHERE player_id=p AND ranking_points_earned=20)
     OR NOT EXISTS(SELECT 1 FROM public.player_doubles_tournament_results WHERE player_id=p AND ranking_points_earned=10)
   THEN RAISE EXCEPTION 'Erasure must preserve pseudonymous competition history'; END IF;
   BEGIN
     UPDATE public.players SET guest_history_erased_at=NULL WHERE id=p;
     RAISE EXCEPTION 'Historical marker removed unexpectedly';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
 ELSIF ph='verify_retired' THEN
   IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=uid AND is_anonymous)
     OR NOT EXISTS(SELECT 1 FROM control_center_private.tennis_guest_trials_v1 WHERE user_id=uid AND retired_at IS NOT NULL AND converted_at IS NULL)
   THEN RAISE EXCEPTION 'Retired account was unexpectedly converted'; END IF;
 ELSE RAISE EXCEPTION 'Unknown CI phase';
 END IF;
END
$qa$;
COMMIT;
