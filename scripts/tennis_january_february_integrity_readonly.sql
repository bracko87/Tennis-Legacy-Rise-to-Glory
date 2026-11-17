-- Tennis Legacy: JANUARY / FEBRUARY gameplay integrity audit.
-- READ-ONLY. Useful both on the current test season and after a clean
-- 59-day isolated rehearsal. Every nonzero FAIL metric blocks launch.
--
-- Historical data generated before the November 17 scheduling correction
-- may fail; never rewrite completed test matches just to make these pass.
WITH
phase_weeks AS (
 SELECT wc.id competition_id,ed.season_number,wc.world,ts.name tournament_name,
   min(sl.season_week) FILTER(WHERE sl.phase='qualification') qual_week,
   min(sl.season_week) FILTER(WHERE sl.phase='main_draw') main_first_week,
   max(sl.season_week) FILTER(WHERE sl.phase='main_draw') main_last_week
 FROM public.tournament_world_competitions wc
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
 JOIN public.tournament_schedule_slots sl ON sl.tournament_edition_id=ed.id
 WHERE ed.season_number=1
 GROUP BY wc.id,ed.season_number,wc.world,ts.name
),
jan_feb_matches AS (
 SELECT m.*,pw.qual_week,pw.main_first_week,pw.main_last_week,pw.world,pw.tournament_name,
   (((pw.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day
 FROM public.tournament_matches m JOIN phase_weeks pw ON pw.competition_id=m.competition_id
 WHERE pw.season_number=1
),
match_days AS (
 SELECT m.*,gd.month,gd.day FROM jan_feb_matches m
 CROSS JOIN LATERAL public.absolute_game_day_v1(m.abs_day) gd
 WHERE gd.month IN(1,2)
),
player_slots AS (
 SELECT m.id,m.competition_id,m.abs_day,m.status,m.scheduled_start_minute,
 coalesce(m.actual_duration_minutes,
          CASE WHEN sim.match_id IS NOT NULL
            THEN public.simulated_tennis_duration_minutes_v1(sim.total_games,sim.total_points) END,
          m.estimated_duration_minutes,150) duration,
 p.player_id
 FROM match_days m LEFT JOIN public.tournament_match_simulations sim ON sim.match_id=m.id
 JOIN LATERAL (VALUES(m.player1_id),(m.player2_id)) p(player_id) ON p.player_id IS NOT NULL
 WHERE m.status IN ('scheduled','in_progress','completed') AND m.scheduled_start_minute IS NOT NULL
),
overlap_pairs AS (
 SELECT a.player_id,a.abs_day,a.competition_id a_comp,b.competition_id b_comp
 FROM player_slots a JOIN player_slots b
 ON a.player_id=b.player_id AND a.abs_day=b.abs_day AND a.id<b.id
 WHERE abs(a.scheduled_start_minute-b.scheduled_start_minute) <
       CASE WHEN a.scheduled_start_minute<=b.scheduled_start_minute
       THEN a.duration ELSE b.duration END
),
doubles_slots AS (
 SELECT dm.id,dm.competition_id,dm.status,dm.scheduled_start_minute,
 coalesce(dm.actual_duration_minutes,dm.estimated_duration_minutes,105) duration,
 (((ed.season_number-1)*366)+2+((dm.scheduled_season_week-1)*7)+(dm.scheduled_day-1))::integer abs_day,
 pl.player_id
 FROM public.tournament_doubles_matches dm
 JOIN public.tournament_world_competitions wc ON wc.id=dm.competition_id
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 JOIN public.tournament_doubles_teams t1 ON t1.id=dm.team1_id
 JOIN public.tournament_doubles_teams t2 ON t2.id=dm.team2_id
 JOIN LATERAL (VALUES(t1.player1_id),(t1.player2_id),(t2.player1_id),(t2.player2_id)) pl(player_id) ON pl.player_id IS NOT NULL
 CROSS JOIN LATERAL public.absolute_game_day_v1(
 (((ed.season_number-1)*366)+2+((dm.scheduled_season_week-1)*7)+(dm.scheduled_day-1))::integer
 ) gd
 WHERE ed.season_number=1 AND gd.month IN(1,2)
 AND dm.status IN('scheduled','completed','in_progress')
 AND dm.scheduled_start_minute IS NOT NULL
),
singles_doubles_overlaps AS (
 SELECT a.id singles_id,b.id doubles_id,a.player_id,a.abs_day
 FROM player_slots a JOIN doubles_slots b
 ON a.player_id=b.player_id AND a.abs_day=b.abs_day
 WHERE abs(a.scheduled_start_minute-b.scheduled_start_minute) <
       CASE WHEN a.scheduled_start_minute<=b.scheduled_start_minute THEN a.duration ELSE b.duration END
),
doubles_doubles_overlaps AS (
 SELECT a.id first_id,b.id second_id,a.player_id,a.abs_day
 FROM doubles_slots a JOIN doubles_slots b
 ON a.player_id=b.player_id AND a.abs_day=b.abs_day AND a.id<b.id
 WHERE abs(a.scheduled_start_minute-b.scheduled_start_minute) <
       CASE WHEN a.scheduled_start_minute<=b.scheduled_start_minute THEN a.duration ELSE b.duration END
),
metrics AS (
 SELECT 1 ord,'Qualifying matches outside configured qualifying week' metric,
 count(*) FILTER(WHERE m.draw_type='qualification' AND m.qual_week IS NOT NULL
                  AND m.scheduled_season_week<>m.qual_week AND m.status<>'bye')::bigint failures,
 count(*)::bigint records_checked
 FROM match_days m
 UNION ALL
 SELECT 2,'Main-draw matches before configured main-draw week',
 count(*) FILTER(WHERE m.draw_type='main_draw' AND m.main_first_week IS NOT NULL
                 AND m.scheduled_season_week<m.main_first_week AND m.status<>'bye')::bigint,
 count(*)::bigint
 FROM match_days m
 UNION ALL
 SELECT 3,'Main-draw matches after configured main-draw week',
 count(*) FILTER(WHERE m.draw_type='main_draw' AND m.main_last_week IS NOT NULL
                 AND m.scheduled_season_week>m.main_last_week AND m.status<>'bye')::bigint,
 count(*)::bigint
 FROM match_days m
 UNION ALL
 SELECT 4,'Overlapping matches for the same player (singles)',
 count(*)::bigint,(SELECT count(*) FROM player_slots)::bigint FROM overlap_pairs
 UNION ALL
 SELECT 5,'Overlapping matches from different tournaments',
 count(*) FILTER(WHERE a_comp<>b_comp)::bigint,
 (SELECT count(*) FROM overlap_pairs)::bigint FROM overlap_pairs
 UNION ALL
 SELECT 6,'Completed matches without a valid winner',
 count(*) FILTER(WHERE status='completed'
     AND (winner_id IS NULL OR winner_id NOT IN(player1_id,player2_id)))::bigint,
 count(*) FILTER(WHERE status='completed')::bigint FROM match_days
 UNION ALL
 SELECT 7,'Completed simulated matches with no actual simulated match duration',
 count(*) FILTER(WHERE m.status='completed' AND sim.match_id IS NOT NULL
                  AND m.actual_duration_minutes IS NULL)::bigint,
 count(*) FILTER(WHERE m.status='completed' AND sim.match_id IS NOT NULL)::bigint
 FROM match_days m LEFT JOIN public.tournament_match_simulations sim ON sim.match_id=m.id
 UNION ALL
 SELECT 8,'Duplicate payment idempotency keys',
 count(*)::bigint,(SELECT count(*) FROM public.career_finance_transactions)::bigint
 FROM (SELECT idempotency_key FROM public.career_finance_transactions
       WHERE idempotency_key IS NOT NULL GROUP BY idempotency_key HAVING count(*)>1) d
 UNION ALL
 SELECT 9,'Same player overlapping singles and doubles',
 count(*)::bigint,(SELECT count(*) FROM doubles_slots)::bigint FROM singles_doubles_overlaps
 UNION ALL
 SELECT 10,'Same player overlapping two doubles matches',
 count(*)::bigint,(SELECT count(*) FROM doubles_slots)::bigint FROM doubles_doubles_overlaps
)
SELECT ord,metric,failures,records_checked,
CASE WHEN failures=0 THEN 'PASS' ELSE 'FAIL' END status
FROM metrics ORDER BY ord;
