-- Tennis Legacy: read-only pre-launch Season 1 reset inventory.
-- This is NOT a destructive reset script. It MUST NOT clear data.
-- Before performing a live reset, verify a recoverable, current post-migration
-- backup, rehearse on a restored copy, and review FK and trigger dependencies.
-- Keep public signup disabled throughout the pre-launch test.
--
-- Intended final target: Season 1, Jan 1, 00:00 (game_clock tracks minutes),
-- paused, no migration announcements, gameplay history reset, 417 AI per tour
-- initialized with original starting attributes, previous payment records
-- retained and reconciled, existing test accounts controlled.
--
-- 1. Access/freeze gate; all three bool columns should be true/false/false.
SELECT g.season, g.month, g.day, g.minute_of_day,
       g.is_paused AS game_clock_paused,
       r.public_signup_enabled,
       coalesce(j.active,false) AS season_auto_resume_job_active,
       m.status AS migration_notice_state
FROM public.game_clock g
CROSS JOIN public.registration_control r
CROSS JOIN control_center_private.tennis_season_maintenance_control_v1 m
LEFT JOIN cron.job j ON j.jobname='tennis-season-transition-two-day-v1'
WHERE g.id=1 AND r.singleton_id=true AND m.id=true;

-- 2. AI roster distribution. Reset MUST restore both tours to the
-- approved 417-player starting distribution with their starting abilities.
SELECT player_type,world,count(*) AS player_count
FROM public.players GROUP BY player_type,world ORDER BY player_type,world;

-- 3. Unreset progress (counts only; no names or financial data disclosed).
SELECT 'tournament_matches' AS subsystem,count(*) AS records FROM public.tournament_matches
UNION ALL SELECT 'tournament_entries',count(*) FROM public.tournament_entries
UNION ALL SELECT 'tournament_match_simulations',count(*) FROM public.tournament_match_simulations
UNION ALL SELECT 'player_training_sessions',count(*) FROM public.player_training_sessions
UNION ALL SELECT 'player_skill_history',count(*) FROM public.player_skill_history
UNION ALL SELECT 'player_ranking_contributions',count(*) FROM public.player_ranking_contributions
UNION ALL SELECT 'player_ranking_snapshots',count(*) FROM public.player_ranking_snapshots
UNION ALL SELECT 'player_doubles_ranking_snapshots',count(*) FROM public.player_doubles_ranking_snapshots
UNION ALL SELECT 'ranking_publication_runs',count(*) FROM public.ranking_publication_runs
UNION ALL SELECT 'career_finance_transactions',count(*) FROM public.career_finance_transactions
UNION ALL SELECT 'player_injuries',count(*) FROM public.player_injuries
UNION ALL SELECT 'player_tutorial_progress',count(*) FROM public.player_tutorial_progress
UNION ALL SELECT 'tournament_draw_publications',count(*) FROM public.tournament_draw_publications
ORDER BY subsystem;

-- 4. Edition source structure: Season 1 definitions must become fresh,
-- rather than leaving 597 completed/canceled editions behind.
SELECT season_number,status,count(*) AS editions
FROM public.tournament_editions GROUP BY season_number,status ORDER BY season_number,status;

-- 5. Histories and service records to preserve or reconcile independently:
-- DO NOT use TRUNCATE CASCADE on auth.users or payment tables.
SELECT 'auth.users' record_class,count(*) record_count FROM auth.users
UNION ALL SELECT 'billing_transactions',count(*) FROM public.billing_transactions
UNION ALL SELECT 'stripe_webhook_events',count(*) FROM public.stripe_webhook_events
UNION ALL SELECT 'premium_memberships',count(*) FROM public.premium_memberships
UNION ALL SELECT 'coin_ledger',count(*) FROM public.coin_ledger
ORDER BY record_class;

-- 6. Future year-end migration controls must be rearmed specifically
-- for Season 1 only AFTER the new game has passed its pre-launch smoke tests.
SELECT source_season,stop_at_total_seconds,enabled
FROM public.season_transition_boundary_guard_v1 WHERE id=true;
