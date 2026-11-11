-- Future-season transition protocol. Does NOT start a transition or change
-- the active Season 2 clock. Requires an actual, verified migration run.
-- 1: year-end holds at Dec 31 23:59:59 (website locked, at least 24h)
-- 2: migration verified -> January 1 00:00 paused, public sign-in (24h)
-- 3: resume 2x automatically only after the full preparation window.
-- If migration overruns 24h, continue locking until verified, then grant the
-- complete 24h preparation window instead of cutting it short.

ALTER TABLE control_center_private.tennis_season_maintenance_control_v1
  ADD COLUMN IF NOT EXISTS preseason_starts_at timestamptz,
  ADD COLUMN IF NOT EXISTS preseason_ends_at timestamptz,
  ADD COLUMN IF NOT EXISTS resumed_at timestamptz;

ALTER TABLE control_center_private.tennis_season_maintenance_control_v1
  DROP CONSTRAINT IF EXISTS tennis_season_maintenance_control_v1_status_check;
ALTER TABLE control_center_private.tennis_season_maintenance_control_v1
  ADD CONSTRAINT tennis_season_maintenance_control_v1_status_check
  CHECK (status IN ('off','announced','active','extended','preseason'));

-- A database-level clock hold protects jobs that use the official clock even
-- if the migration runner has already written the new season to game_clock.
-- The maintenance access boundary is separate from the game-clock hold.
CREATE OR REPLACE FUNCTION public.get_game_clock_v1()
RETURNS TABLE(server_now timestamptz,speed_multiplier numeric,game_total_seconds bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $clock$
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
  SELECT cs.server_now,cs.speed_multiplier,cs.season,
    cs.base_game_seconds +
      CASE WHEN cs.is_paused THEN 0::bigint ELSE
        greatest(0::bigint,floor(extract(epoch FROM(cs.server_now-cs.real_anchor_at))*cs.speed_multiplier)::bigint)
      END AS total_seconds
  FROM clock_state cs
),guarded AS (
  SELECT r.server_now,r.speed_multiplier,r.total_seconds,
    CASE WHEN g.enabled AND g.source_season=r.season THEN g.stop_at_total_seconds
      ELSE null::bigint END AS cap_seconds
  FROM raw_time r LEFT JOIN public.season_transition_boundary_guard_v1 g ON g.id=true
),state AS (
  SELECT c.status,c.source_season,c.target_season
  FROM control_center_private.tennis_season_maintenance_control_v1 c WHERE c.id=true
)
SELECT g.server_now,
  CASE WHEN s.status IN('active','extended','preseason') THEN 0::numeric
       WHEN g.cap_seconds IS NOT NULL AND g.total_seconds>=g.cap_seconds THEN 0::numeric
       ELSE g.speed_multiplier END,
  CASE WHEN s.status IN('active','extended') THEN s.source_season::bigint*31622400-1
       WHEN s.status='preseason' THEN (s.target_season-1)::bigint*31622400
       WHEN g.cap_seconds IS NOT NULL THEN least(g.total_seconds,g.cap_seconds)
       ELSE g.total_seconds END
FROM guarded g CROSS JOIN state s
$clock$;

-- Public browser state: only phase and relevant real-world dates; no operator
-- credentials, migration journal, player data or internal execution flags.
CREATE OR REPLACE FUNCTION public.get_tennis_public_maintenance_v1()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','control_center_private'
AS $public_state$
SELECT jsonb_build_object(
  'status',c.status,
  'source_season',CASE WHEN c.status='off' THEN null ELSE c.source_season END,
  'target_season',CASE WHEN c.status='off' THEN null ELSE c.target_season END,
  'starts_at',CASE WHEN c.status='off' THEN null ELSE c.starts_at END,
  'planned_reopen_at',CASE WHEN c.status='off' THEN null ELSE c.planned_reopen_at END,
  'estimated_reopen_at',CASE WHEN c.status='off' THEN null ELSE coalesce(c.revised_reopen_at,c.planned_reopen_at) END,
  'preseason_starts_at',CASE WHEN c.status='preseason' THEN c.preseason_starts_at ELSE null END,
  'preseason_ends_at',CASE WHEN c.status='preseason' THEN c.preseason_ends_at ELSE null END,
  'preseason_active',c.status='preseason',
  'game_clock_paused',c.status IN('active','extended','preseason'),
  'maintenance_active',c.status IN('active','extended')
    OR (c.status='announced' AND now()>=c.starts_at),
  'announcement_visible',c.status='announced' AND now()<c.starts_at,
  'reopening_delayed',c.status IN('active','extended') AND now()>=coalesce(c.revised_reopen_at,c.planned_reopen_at),
  'notice',CASE WHEN c.status='off' THEN null ELSE left(coalesce(c.notice,''),500) END,
  'checked_at',now()
)
FROM control_center_private.tennis_season_maintenance_control_v1 c WHERE c.id=true
$public_state$;

REVOKE ALL ON FUNCTION public.get_tennis_public_maintenance_v1() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_tennis_public_maintenance_v1() TO anon,authenticated;

CREATE OR REPLACE FUNCTION control_center_private.tick_tennis_two_day_season_transition_v1()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','control_center_private'
AS $tick$
DECLARE
  v_control control_center_private.tennis_season_maintenance_control_v1%rowtype;
  v_clock public.game_clock%rowtype;
  v_guard public.season_transition_boundary_guard_v1%rowtype;
  v_time bigint;
  v_run record;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('tennis:two-day-season-transition',0));
  SELECT * INTO v_control FROM control_center_private.tennis_season_maintenance_control_v1 WHERE id=true FOR UPDATE;
  SELECT * INTO v_clock FROM public.game_clock WHERE id=1 FOR UPDATE;
  SELECT * INTO v_guard FROM public.season_transition_boundary_guard_v1 WHERE id=true;

  -- Activation is tied to the *next* real year-end guard, not a date in the
  -- current Season 2. The active game can never be accidentally re-migrated.
  IF v_control.status IN('off','announced') AND v_guard.enabled
     AND v_guard.source_season=v_clock.season THEN
    SELECT game_total_seconds INTO v_time FROM public.get_game_clock_v1();
    IF v_time>=v_guard.stop_at_total_seconds THEN
      UPDATE control_center_private.tennis_season_maintenance_control_v1
      SET status='active',source_season=v_clock.season,target_season=v_clock.season+1,
          starts_at=now(),planned_reopen_at=now()+interval '24 hours',
          revised_reopen_at=null,preseason_starts_at=null,preseason_ends_at=null,
          resumed_at=null,notice='We are migrating to the next season. Sign-in will reopen after the protected migration and verification window.',
          updated_at=now()
      WHERE id=true;
      RETURN jsonb_build_object('phase','migration_locked','source',v_clock.season,
        'expected_reopen_at',now()+interval '24 hours');
    END IF;
  END IF;

  -- Never move to preparation merely because the 24h timer expired.
  -- The operator's actual, approved runner MUST have completed the transition
  -- and the final postcheck, using the exact source/target pair from this run.
  IF v_control.status IN('active','extended')
     AND now()>=v_control.planned_reopen_at THEN
    SELECT r.run_id,r.status,r.finished_at,r.operator_approved,r.finance_verified,
           r.contracts_verified,r.execution_enabled
    INTO v_run
    FROM control_center_private.tennis_season_transition_runs_v1 r
    WHERE r.source_season=v_control.source_season
      AND r.target_season=v_control.target_season
      AND r.finished_at>=v_control.starts_at
      AND r.status='completed'
    ORDER BY r.finished_at DESC LIMIT 1;

    IF v_run.status='completed'
      AND v_run.finished_at>=v_control.starts_at
      AND v_run.operator_approved AND v_run.execution_enabled
      AND v_run.finance_verified AND v_run.contracts_verified
      AND v_clock.season=v_control.target_season
      AND EXISTS(
        SELECT 1 FROM control_center_private.tennis_season_transition_steps_v1 s
        WHERE s.run_id=v_run.run_id AND s.step_key='postcheck' AND s.status='completed'
      )
    THEN
      -- Migrate/verify first, then grant 24 full real hours at Jan 1 00:00.
      UPDATE public.game_clock
      SET season=v_control.target_season,month=1,day=1,minute_of_day=0,
          is_paused=true,speed_multiplier=2,real_anchor_at=now(),updated_at=now()
      WHERE id=1;

      UPDATE public.season_transition_boundary_guard_v1
      SET source_season=v_control.target_season,
          stop_at_total_seconds=v_control.target_season::bigint*31622400-1,
          enabled=true,updated_at=now()
      WHERE id=true;

      UPDATE control_center_private.tennis_season_maintenance_control_v1
      SET status='preseason',preseason_starts_at=now(),
          preseason_ends_at=now()+interval '24 hours',
          notice='Welcome to the new season! The clock is paused for 24 real hours so you can prepare and apply for January tournaments.',
          updated_at=now()
      WHERE id=true;

      RETURN jsonb_build_object('phase','preseason','target',v_control.target_season,
        'clock_resumes_at',now()+interval '24 hours');
    END IF;
    RETURN jsonb_build_object('phase','migration_delayed',
      'expected_reopen_at',v_control.planned_reopen_at,
      'reason','waiting_for_verified_completion_and_postcheck');
  END IF;

  IF v_control.status='preseason' AND now()>=v_control.preseason_ends_at THEN
    IF v_clock.season<>v_control.target_season THEN
      RAISE EXCEPTION 'Cannot resume: active game-clock season % is not expected season %',
        v_clock.season,v_control.target_season;
    END IF;
    UPDATE public.game_clock SET is_paused=false,speed_multiplier=2,
      real_anchor_at=now(),updated_at=now() WHERE id=1;
    UPDATE control_center_private.tennis_season_maintenance_control_v1
    SET status='off',resumed_at=now(),notice=null,updated_at=now() WHERE id=true;
    RETURN jsonb_build_object('phase','playing','speed',2,'season',v_control.target_season);
  END IF;
  RETURN jsonb_build_object('phase',v_control.status);
END
$tick$;

REVOKE ALL ON FUNCTION control_center_private.tick_tennis_two_day_season_transition_v1()
  FROM PUBLIC,anon,authenticated;

-- Once per minute: safe/idempotent, no migration approval or execution is invented.
SELECT cron.schedule('tennis-season-transition-two-day-v1','* * * * *',
  'select control_center_private.tick_tennis_two_day_season_transition_v1();');

COMMENT ON FUNCTION control_center_private.tick_tennis_two_day_season_transition_v1() IS
'At season boundary lock >=24h; await completed approved migration/postcheck; open full 24h frozen preseason; then resume at 2x.';
