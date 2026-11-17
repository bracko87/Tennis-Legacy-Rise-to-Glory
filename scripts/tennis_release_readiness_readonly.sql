-- Read-only final-restart readiness; NEVER resets game data.
-- Scope and relationships are derived from the exact current final-reset script.
WITH reset_targets AS (
 SELECT schemaname,tablename,to_regclass(format('%I.%I',schemaname,tablename)) relid
 FROM pg_tables WHERE (schemaname='control_center_private'
  AND ((left(tablename,13)='tennis_season'
        AND tablename<>'tennis_season_maintenance_control_v1')
       OR tablename='tournament_qualification_nocontest_repairs_v1'))
OR (schemaname='public' AND (
  (left(tablename,7)='player_' AND tablename NOT IN(
    'player_skills','player_rankings','player_doubles_rankings','player_training_plans',
    'player_location_state','player_avatar_reservations','player_home_city_options','player_homepage_reviews'))
  OR (left(tablename,11)='tournament_' AND tablename NOT IN(
    'tournament_series','tournament_categories','tournament_doubles_settings',
    'tournament_doubles_ranking_point_rules','tournament_match_scheduling_rules',
    'tournament_prize_pool_rules','tournament_prize_pools','tournament_prize_payouts',
    'tournament_doubles_prize_payouts','tournament_prize_stage_weights','tournament_ranking_point_rules',
     'tournament_draw_seed_groups','tournament_draw_seed_slots'))
  OR (left(tablename,9)='national_' AND tablename NOT IN(
    'national_associations','national_association_funds','national_association_treasuries',
    'national_team_config','national_team_competition_config','national_team_country_regions',
    'national_team_regions','national_team_divisions','national_team_fixture_formats','national_team_windows'))
  OR (left(tablename,13)='private_life_' AND tablename ~
    '(_history|_events|_sale_listings|_positions|_trades|_player_assets)$')
  OR left(tablename,8)='ranking_' OR left(tablename,16)='doubles_ranking_'
  OR (left(tablename,6)='staff_' AND tablename ~ '(_events|_offers|_negotiations)$')
  OR (left(tablename,12)='tennis_club_' AND tablename<>'tennis_club_settings')
  OR tablename IN(
    'ai_weekly_injury_runs','career_finance_transactions','career_tax_periods','user_notifications',
    'birthday_rewards','birthday_email_outbox','new_player_initialization_audit',
    'technical_sponsor_equipment_claims','staff_financial_events','tennis_clubs')
))
), reset_scope AS (
 SELECT count(*)::integer n,
 count(*) FILTER(WHERE tablename IN ('tournament_draw_seed_groups','tournament_draw_seed_slots'))::integer forbidden_seed_targets,
 count(*) FILTER(WHERE tablename LIKE 'referral_%' OR tablename='referrals' OR tablename LIKE 'site_analytics_%')::integer protected_histories_in_scope
 FROM reset_targets
), reset_dependencies AS (
 SELECT count(*)::integer inbound_fks
 FROM pg_constraint c
 JOIN reset_targets tgt ON tgt.relid=c.confrelid
 LEFT JOIN reset_targets src ON src.relid=c.conrelid
 WHERE c.contype='f' AND src.relid IS NULL
), status AS (
 SELECT
 (select is_paused from public.game_clock where id=1) paused,
 (select speed_multiplier from public.game_clock where id=1) live_speed,
 (select public_signup_enabled from public.registration_control where singleton_id=true) signup,
 (select count(*) from control_center_private.tennis_prelaunch_cron_freeze_v1) frozen_job_inventory,
 (select count(*) from control_center_private.tennis_prelaunch_cron_freeze_v1 f JOIN cron.job j USING(jobid) WHERE j.active) active_game_jobs,
 (select count(*) from control_center_private.tennis_prelaunch_ai_roster_seed_v1) ai_snapshot,
 (select count(*) from control_center_private.tennis_prelaunch_s1_editions_v1) editions_snapshot,
 (select count(*) from control_center_private.tennis_prelaunch_s1_competitions_v1) competitions_snapshot,
 (select count(*) from control_center_private.tennis_prelaunch_s1_schedule_v1) schedule_snapshot,
 (select count(*) from control_center_private.tennis_prelaunch_ai_starter_assets_v1) starter_snapshot,
 (select count(*) from public.tournament_matches) old_match_count,
 (select count(*) from auth.users) auth_logins,
 (select count(*) from public.billing_transactions WHERE status='paid' AND amount_eur_cents=949) test_paid_949,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' AND p.prosecdef AND has_function_privilege('anon',p.oid,'EXECUTE')) exposed_anon_definers,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' AND p.proname like '__e2e_%') test_helpers
), seeds AS (
 SELECT count(*) FILTER(WHERE
  (select coalesce(max(seed_end),0) from public.tournament_draw_seed_groups g WHERE g.draw_size=v.size)=v.seed_count
  AND (select count(*) from public.tournament_draw_seed_slots sl WHERE sl.draw_size=v.size)=v.seed_count) correct_sizes
 FROM (VALUES(16,4),(32,8),(64,16),(128,32)) AS v(size,seed_count)
), two_week_phase_health AS (
 SELECT count(*) AS two_week_events,
   count(*) FILTER (WHERE q_count=1 AND main_count=1) AS valid_two_week_events
 FROM (
   SELECT tournament_edition_id,
      count(*) FILTER(WHERE phase='qualification') q_count,
      count(*) FILTER(WHERE phase='main_draw') main_count
   FROM control_center_private.tennis_prelaunch_s1_schedule_v1
   GROUP BY tournament_edition_id
   HAVING count(DISTINCT season_week)>1
 ) events
), checks AS (
 SELECT 1 seq,'Registration stays closed' item,
   CASE WHEN NOT signup THEN 'PASS' ELSE 'BLOCKED' END state,
   'Public signup must remain off until the final smoke test' evidence FROM status
 UNION ALL SELECT 2,'Clock paused',
   CASE WHEN paused THEN 'PASS' ELSE 'BLOCKED' END,'The clock must be frozen before any reset' FROM status
 UNION ALL SELECT 3,'Game jobs frozen',
   CASE WHEN active_game_jobs=0 AND frozen_job_inventory=33 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s of %s reset jobs remain active',active_game_jobs,frozen_job_inventory) FROM status
 UNION ALL SELECT 4,'AI and calendar seed snapshots',
   CASE WHEN ai_snapshot=834 AND editions_snapshot=597 AND competitions_snapshot=1194 AND schedule_snapshot=613 AND starter_snapshot=1668 THEN 'PASS' ELSE 'BLOCKED' END,
   format('AI=%s editions=%s competitions=%s schedule=%s assets=%s',ai_snapshot,editions_snapshot,competitions_snapshot,schedule_snapshot,starter_snapshot) FROM status
 UNION ALL SELECT 5,'Reset table scope',
   CASE WHEN n=149 AND forbidden_seed_targets=0 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s tables in planned reset; %s static seed tables accidentally included',n,forbidden_seed_targets) FROM reset_scope
 UNION ALL SELECT 6,'Seeding rules ready',
   CASE WHEN correct_sizes=4 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s of 4 main-draw sizes have correct permanent layouts',correct_sizes) FROM seeds
 UNION ALL SELECT 7,'Disposable rehearsal matches identified',
   CASE WHEN old_match_count>=1 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s historical rehearsal matches; final cutover still requires backup, rehearsal and owner approval',old_match_count) FROM status
 UNION ALL SELECT 8,'Payment and account safeguards prepared',
   'NEEDS_REHEARSAL',
   format('%s registered logins and %s matching historical test invoices. Old exact-count requirement is removed; all accounts and entitlements must survive.',auth_logins,test_paid_949) FROM status
 UNION ALL SELECT 9,'Unsafe test helpers removed',
   CASE WHEN test_helpers=0 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s public test helper functions still exist',test_helpers) FROM status
 UNION ALL SELECT 10,'Remaining privileged API security review',
   'NEEDS_REVIEW',format('%s SECURITY DEFINER functions remain callable anonymously; review each purpose',exposed_anon_definers) FROM status
 UNION ALL SELECT 11,'Launch speed agreed',
   'NEEDS_DECISION',format('Current game speed is %s; final restart needs an explicit owner-selected speed',live_speed) FROM status
 UNION ALL SELECT 12,'Restorable database backup',
   'NEEDS_EVIDENCE','Must be proven by an actual restore, not a SQL count'
 UNION ALL SELECT 13,'Isolated January-February simulation',
   'NEEDS_EVIDENCE','Need an isolated restored database with full game data and a 59-day rehearsal'
 UNION ALL SELECT 14,'Approval for destructive final reset',
   'NOT_AUTHORIZED','Do not run the final reset merely because database checks pass'
 UNION ALL SELECT 15,'No dangling foreign keys from reset scope',
   CASE WHEN inbound_fks=0 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s FK relationships still reference tables being cleared',inbound_fks) FROM reset_dependencies
 UNION ALL SELECT 16,'Referrals and website analytics remain intact',
   CASE WHEN protected_histories_in_scope=0 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s protected referral or analytics tables in reset scope',protected_histories_in_scope) FROM reset_scope
 UNION ALL SELECT 17,'Tournament repair diagnostic evidence archived',
   'READY_TO_ARCHIVE',
   format('%s diagnostic rows to be archived at final cutover; archiving has NOT happened',
      (SELECT count(*) FROM control_center_private.tournament_qualification_nocontest_repairs_v1))
 UNION ALL SELECT 18,'All Season 1 two-week tournament phases are explicit',
   CASE WHEN two_week_events=16 AND valid_two_week_events=16 THEN 'PASS' ELSE 'BLOCKED' END,
   format('%s of %s two-week tournament definitions have one qualification week and one main-draw week; required 16 of 16',
          valid_two_week_events,two_week_events) FROM two_week_phase_health
)
SELECT seq,item,state,evidence FROM checks ORDER BY seq;
