-- Matches the live Tennis Legacy function installed during the prelaunch reset.
CREATE OR REPLACE FUNCTION public.get_game_clock_v1()
 RETURNS TABLE(server_now timestamp with time zone, speed_multiplier numeric, game_total_seconds bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
WITH clock_state AS (
  SELECT now() server_now,gc.speed_multiplier,gc.real_anchor_at,gc.is_paused,gc.season,
    (((gc.season-1)::bigint*366)
       + (CASE gc.month WHEN 1 THEN 0 WHEN 2 THEN 31 WHEN 3 THEN 60
          WHEN 4 THEN 91 WHEN 5 THEN 121 WHEN 6 THEN 152 WHEN 7 THEN 182
          WHEN 8 THEN 213 WHEN 9 THEN 244 WHEN 10 THEN 274 WHEN 11 THEN 305
          WHEN 12 THEN 335 END + gc.day - 1)::bigint)*86400
       + gc.minute_of_day::bigint*60 AS base_game_seconds
  FROM public.game_clock gc WHERE gc.id=1
), raw_time AS (
  SELECT cs.server_now,cs.speed_multiplier,cs.season,cs.is_paused,
    cs.base_game_seconds +
      CASE WHEN cs.is_paused THEN 0::bigint ELSE
        greatest(0::bigint,floor(extract(epoch FROM(cs.server_now-cs.real_anchor_at))*cs.speed_multiplier)::bigint)
      END AS total_seconds
  FROM clock_state cs
),guarded AS (
  SELECT r.server_now,r.speed_multiplier,r.total_seconds,r.is_paused,r.season AS physical_season,
    CASE WHEN g.enabled AND g.source_season=r.season THEN g.stop_at_total_seconds
      ELSE null::bigint END AS cap_seconds
  FROM raw_time r LEFT JOIN public.season_transition_boundary_guard_v1 g ON g.id=true
),state AS (
  SELECT c.status,c.source_season,c.target_season
  FROM control_center_private.tennis_season_maintenance_control_v1 c WHERE c.id=true
)
SELECT g.server_now,
  CASE WHEN g.is_paused OR s.status IN('active','extended','preseason') THEN 0::numeric
       WHEN g.cap_seconds IS NOT NULL AND g.total_seconds>=g.cap_seconds THEN 0::numeric
       ELSE g.speed_multiplier END,
  CASE WHEN s.status IN('active','extended') THEN
         CASE WHEN g.physical_season=s.target_season THEN (s.target_season-1)::bigint*31622400
              ELSE s.source_season::bigint*31622400-1 END
       WHEN s.status='preseason' THEN g.total_seconds
       WHEN g.cap_seconds IS NOT NULL THEN least(g.total_seconds,g.cap_seconds)
       ELSE g.total_seconds END
FROM guarded g CROSS JOIN state s
$function$
