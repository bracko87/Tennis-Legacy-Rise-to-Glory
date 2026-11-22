
CREATE TABLE control_center_private.tennis_monitor_success_daily_v1(
 analytics_date date NOT NULL,process_key text NOT NULL,runs bigint NOT NULL CHECK(runs>0),duration_count bigint NOT NULL,duration_sum_ms numeric NOT NULL,max_duration_ms bigint,PRIMARY KEY(analytics_date,process_key)
);
ALTER TABLE control_center_private.tennis_monitor_success_daily_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tennis_monitor_success_daily_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE control_center_private.tennis_monitor_retention_control_v1(singleton boolean PRIMARY KEY CHECK(singleton),enabled boolean NOT NULL DEFAULT false);
INSERT INTO control_center_private.tennis_monitor_retention_control_v1 VALUES(true,false);
ALTER TABLE control_center_private.tennis_monitor_retention_control_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON control_center_private.tennis_monitor_retention_control_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION control_center_private.archive_tennis_monitor_success_v1(p_limit integer DEFAULT 5000) RETURNS bigint LANGUAGE plpgsql SET search_path='' AS $worker$
DECLARE n bigint;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM control_center_private.tennis_monitor_retention_control_v1 WHERE singleton AND enabled) THEN RETURN 0; END IF;
 IF NOT pg_try_advisory_xact_lock(817152026,15) THEN RETURN 0; END IF;
 WITH picked AS MATERIALIZED (
 SELECT id FROM public.system_monitor_runs WHERE status='success' AND finished_at IS NOT NULL AND started_at<now()-interval '30 days' AND finished_at<now()-interval '30 days' ORDER BY started_at LIMIT greatest(1,least(coalesce(p_limit,5000),5000)) FOR UPDATE SKIP LOCKED
 ), removed AS (
 DELETE FROM public.system_monitor_runs r USING picked p WHERE r.id=p.id RETURNING r.started_at,r.process_key,r.duration_ms
 ), grouped AS (
 SELECT (started_at AT TIME ZONE 'Europe/Berlin')::date AS analytics_date,process_key,count(*) AS runs,count(duration_ms) AS duration_count,coalesce(sum(duration_ms),0) AS duration_sum_ms,max(duration_ms) AS max_duration_ms FROM removed GROUP BY 1,2
 ), saved AS (
 INSERT INTO control_center_private.tennis_monitor_success_daily_v1 AS a SELECT * FROM grouped ON CONFLICT(analytics_date,process_key) DO UPDATE SET runs=a.runs+excluded.runs,duration_count=a.duration_count+excluded.duration_count,duration_sum_ms=a.duration_sum_ms+excluded.duration_sum_ms,max_duration_ms=greatest(a.max_duration_ms,excluded.max_duration_ms) RETURNING 1
 ) SELECT count(*) INTO n FROM removed;
 RETURN n;
END;
$worker$;
REVOKE ALL ON FUNCTION control_center_private.archive_tennis_monitor_success_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
