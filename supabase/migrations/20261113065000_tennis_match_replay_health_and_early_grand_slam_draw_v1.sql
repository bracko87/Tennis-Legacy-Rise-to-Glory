-- Tennis Legacy: keep the singles replay watchdog sensitive to actual
-- stalls, without reporting an active, normally finishing replay as stuck.
-- Correct January Grand Slam Week 2 multi-week draw windows for the already
-- existing qualification schedule in Week 1 (Jan 6 onward).
--
-- No change to stored match results, live replay clocks, ranking points,
-- player balances, game speed, previously published draws, or seasons.
DO $repair_replay_health$
DECLARE
  v_sql text;
  v_old text;
  v_new text;
  v_hits int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_sql
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='run_system_health_watchdog_v1'
    AND pg_get_function_identity_arguments(p.oid)='';

  IF v_sql IS NULL THEN
    RAISE EXCEPTION 'System health watchdog is missing';
  END IF;

  v_old:=$old$
  -- Singles matches substantially overdue.
  select count(*) into v_count
  from public.tournament_matches m
  where m.status in ('scheduled','in_progress')
    and m.player1_id is not null and m.player2_id is not null
    and public.tournament_match_game_second_v1(m.id) < v_now_second-21600;
$old$;
  v_new:=$new$
  -- Singles matches genuinely stuck. At 6x a legitimate replay can span
  -- many in-game hours, especially when a late qualification draw caused
  -- a backlog. The real completion deadline of a live replay is authoritative.
  -- Unstarted matches past the game deadline or replays stalled for >5 real
  -- minutes after their expected completion still raise a critical alert.
  select count(*) into v_count
  from public.tournament_matches m
  left join public.tournament_match_simulations sim on sim.match_id=m.id
  where m.status in ('scheduled','in_progress')
    and m.player1_id is not null and m.player2_id is not null
    and public.tournament_match_game_second_v1(m.id) < v_now_second-21600
    and (
      m.status='scheduled'
      or (m.status='in_progress' and (
        sim.match_id is null
        or sim.simulation_status is distinct from 'live'
        or sim.live_ends_at is null
        or sim.live_ends_at < now()-interval '5 minutes'
      ))
    );
$new$;
  v_hits:=(length(v_sql)-length(replace(v_sql,v_old,'')))/length(v_old);
  IF v_hits<>1 THEN
    RAISE EXCEPTION 'Unexpected watchdog source: expected one singles check, got %',v_hits;
  END IF;
  v_sql:=replace(v_sql,v_old,v_new);

  IF strpos(v_sql,'More than 6 game-hours after their expected start.')>0 THEN
    RAISE EXCEPTION 'Unexpected watchdog copy - review before modifying source';
  END IF;
  v_sql:=replace(
    v_sql,
    'tournament match(es) are still scheduled/in progress more than 6 game-hours after their expected start.',
    'tournament match(es) have not started or have stalled beyond their replay deadline.'
  );
  EXECUTE v_sql;
END
$repair_replay_health$;

DO $repair_january_grand_slam_calendar$
DECLARE
  v_sql text;
  v_anchor text;
  v_guard text;
  v_hits int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_sql
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_tournament_entry_timeline_v1'
    AND pg_get_function_identity_arguments(p.oid)='p_competition_id uuid';

  IF v_sql IS NULL THEN
    RAISE EXCEPTION 'Tournament application timeline function is missing';
  END IF;

  v_anchor:=$a$
  return jsonb_build_object(
$a$;
  v_hits:=(length(v_sql)-length(replace(v_sql,v_anchor,'')))/length(v_anchor);
  IF v_hits<>1 THEN
    RAISE EXCEPTION 'Unexpected tournament timeline source: % return sites',v_hits;
  END IF;

  v_guard:=$g$
  -- A multi-week January Grand Slam has Week 1 qualifying fixtures
  -- (Jan 6-8) before its Week 2 main event starts. A Jan 9 draw generates
  -- already-overdue qualifiers, so close the field and publish the draw
  -- on Jan 5. This applies to first seasons and future restarts alike;
  -- the previously published tournament records themselves are untouched.
  IF v_first_week=2 AND v_last_week>v_first_week
     AND v_category='grand_slam_2000' THEN
    v_open := (v_season-1)::bigint*31622400;
    v_close := (v_first_start-5)::bigint*86400 + 16*3600;
    v_group_final_close := v_close;
    v_late_open := v_close;
    v_late_close := (v_first_start-5)::bigint*86400 + 18*3600;
    v_draw := (v_first_start-5)::bigint*86400 + 22*3600;
  END IF;

$g$;

  v_sql:=replace(v_sql,v_anchor,v_guard||v_anchor);
  EXECUTE v_sql;
END
$repair_january_grand_slam_calendar$;
