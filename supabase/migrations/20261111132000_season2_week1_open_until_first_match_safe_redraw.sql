-- Owner-approved Week 1 correction, 11 Nov 2026.
-- Jan 1 00:00 application open -> Jan 3 06:00 normal close -> Jan 3 07:00
-- late fill / lock -> Jan 3 08:00 publication -> Jan 3 10:00 first matches.
-- Applies ONLY to the FIRST season week (Season 2 and later).
-- Prevents the prior season from auto-publishing January Week 1 brackets.
-- Existing Season 2 Week 1 matches have not started. Preserve all source
-- records in a private archival table; restore no historical game results.
-- Do not touch game_clock, other seasons, Weeks 2-52, credits, rankings,
-- purchases, sponsorship or unrelated tournaments.

CREATE TABLE IF NOT EXISTS control_center_private.tennis_season2_week1_draw_deferral_archive_v1(
  competition_id uuid PRIMARY KEY,
  archived_at timestamptz NOT NULL DEFAULT now(),
  source_status text NOT NULL,
  original_data jsonb NOT NULL
);
REVOKE ALL ON control_center_private.tennis_season2_week1_draw_deferral_archive_v1
FROM PUBLIC,anon,authenticated;

DO $patch_week1$
DECLARE
  v_source text;
  v_begin integer;
  v_finish integer;
  v_replace text;
  v_needle text;
  v_count integer;
BEGIN
  -- Replace earlier two special cases (five late competitions and January
  -- Weeks 1-4) with one consistent rule for all 22 Week 1 competitions.
  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='get_tournament_entry_timeline_v1'
    AND pg_get_function_identity_arguments(p.oid)='p_competition_id uuid';
  IF v_source IS NULL THEN RAISE EXCEPTION 'Timeline procedure missing'; END IF;
  v_begin:=strpos(v_source,'  -- Protected Week 1 extension following');
  v_finish:=strpos(v_source,'  return jsonb_build_object(');
  IF v_begin<=0 OR v_finish<=v_begin THEN
    RAISE EXCEPTION 'Unexpected tournament timeline source; refusing migration';
  END IF;
  v_replace:=$week1$
  -- First week is booked entirely in its own season. No Season N booking for
  -- Season N+1 January Week 1 tournaments, including its ATP/WTA draws.
  -- Opening day 10:00 is the earliest real first-match time.
  IF v_first_week=1 AND v_season>=2 THEN
    v_open := (v_season-1)::bigint*31622400;
    v_close := v_first_start::bigint*86400 + 6*3600;
    v_group_final_close := v_close;
    v_late_open := v_close;
    v_late_close := v_first_start::bigint*86400 + 7*3600;
    v_draw := v_first_start::bigint*86400 + 8*3600;
  END IF;

$week1$;
  v_source:=substr(v_source,1,v_begin-1)||v_replace||substr(v_source,v_finish);
  v_needle:='''tournament_start'',public.game_moment_json_v1(v_first_start::bigint*86400),';
  IF strpos(v_source,v_needle)=0 THEN RAISE EXCEPTION 'Timeline tournament start expression changed'; END IF;
  v_source:=replace(v_source,v_needle,
    '''tournament_start'',public.game_moment_json_v1(v_first_start::bigint*86400 + CASE WHEN v_first_week=1 AND v_season>=2 THEN 10*3600 ELSE 0 END),');
  EXECUTE v_source;

  -- The lifecycle worker must still pick up Week 1 on its first day,
  -- prior to the first real match, for selection and final lock.
  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='process_tournament_entry_lifecycle_v2';
  v_needle:='public.training_camp_week_start_absolute_v1(season_number,first_week)>v_today';
  v_count:=(length(v_source)-length(replace(v_source,v_needle,'')))/length(v_needle);
  IF v_count<>2 THEN RAISE EXCEPTION 'Expected two lifecycle selection sites, got %',v_count; END IF;
  v_source:=replace(v_source,v_needle,
    '(public.training_camp_week_start_absolute_v1(season_number,first_week)>v_today OR (first_week=1 AND season_number>=2 AND public.training_camp_week_start_absolute_v1(season_number,first_week)=v_today AND v_now<(public.training_camp_week_start_absolute_v1(season_number,first_week)::bigint*86400+10*3600)))');
  EXECUTE v_source;

  -- The older health/recovery procedures use a deadline eight days before
  -- the event. Suppress their false alarms/actions while Week 1 is genuinely
  -- open, then allow the existing recovery mechanism after Jan 3 07:00.
  FOR v_count IN 1..2 LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_source
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=CASE WHEN v_count=1
        THEN 'check_tournament_entry_pipeline_health_v1'
        ELSE 'auto_repair_due_tournament_entry_pipelines_v1' END;
    v_needle:=CASE WHEN v_count=1 THEN E'  loop\n    if exists('
      ELSE E'  loop\n    -- A renewed application window' END;
    IF strpos(v_source,v_needle)=0 THEN
      RAISE EXCEPTION 'Entry monitoring patch site missing for part %',v_count;
    END IF;
    v_replace:=$monitor$
  loop
    IF r.season_number>=2
       AND r.start_abs=((r.season_number-1)*366+2)
       AND v_now<(public.get_tournament_entry_timeline_v1(r.competition_id)->>'late_close_game_second')::bigint
    THEN
      PERFORM public.resolve_system_incident_by_dedupe_v1(
        'business:tournament-entry-pipeline:'||r.competition_id::text,
        'Week 1 application period remains open until the first match day.'
      );
      CONTINUE;
    END IF;
$monitor$;
    -- Keep the preexisting five-event exception following our general guard.
    v_source:=replace(v_source,v_needle,v_replace||substr(v_needle,length(E'  loop\n')+1));
    EXECUTE v_source;
  END LOOP;

  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='process_minimum_tournament_fields_v1';
  v_needle:='    v_due:=((r.start_abs-8)::bigint*86400)+(18*3600);';
  IF strpos(v_source,v_needle)=0 THEN RAISE EXCEPTION 'Minimum field deadline site missing'; END IF;
  v_source:=replace(v_source,v_needle,
    '    v_due:=CASE WHEN r.start_abs>=368 AND mod(r.start_abs,366)=2 THEN (public.get_tournament_entry_timeline_v1(r.id)->>''late_close_game_second'')::bigint ELSE ((r.start_abs-8)::bigint*86400)+(18*3600) END;');
  EXECUTE v_source;
END $patch_week1$;

-- Protect the real tournament records in one atomic operation.
DO $reopen_week1$
DECLARE
  v_scope int;
  v_draws int;
  v_matches int;
  v_entries int;
  v_human_apps int;
  v_snap int;
  v_started int;
  v_bad int;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('tennis:two-day-season-transition',0));
  PERFORM pg_advisory_xact_lock(hashtextextended('tournament-entry-lifecycle-v3',0));
  IF NOT EXISTS (
    SELECT 1 FROM control_center_private.tennis_season_maintenance_control_v1 c
    JOIN public.game_clock g ON g.id=1
    WHERE c.id=true AND c.status='preseason' AND c.target_season=2
      AND g.season=2 AND g.month=1 AND g.day=1 AND g.is_paused
  ) THEN RAISE EXCEPTION 'Reopening is allowed only in the paused Season 2 January 1 preparation period'; END IF;

  WITH scope AS (
    SELECT wc.id
    FROM public.tournament_world_competitions wc
    JOIN public.tournament_editions e ON e.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=e.id
    WHERE e.season_number=2 AND ss.season_week=1
  )
  SELECT count(*),
    (SELECT count(*) FROM public.tournament_draw_publications d WHERE d.competition_id IN(SELECT id FROM scope)),
    (SELECT count(*) FROM public.tournament_matches m WHERE m.competition_id IN(SELECT id FROM scope)),
    (SELECT count(*) FROM public.tournament_entries en WHERE en.competition_id IN(SELECT id FROM scope) AND en.entry_status='active'),
    (SELECT count(*) FROM public.tournament_applications a JOIN public.players p ON p.id=a.player_id
      WHERE a.competition_id IN(SELECT id FROM scope) AND p.player_type='human'),
    (SELECT count(*) FROM public.tournament_matches m WHERE m.competition_id IN(SELECT id FROM scope)
      AND (m.status NOT IN ('scheduled','bye','cancelled') OR m.started_at IS NOT NULL OR (m.completed_at IS NOT NULL AND m.status NOT IN ('bye','cancelled')) OR (m.winner_id IS NOT NULL AND m.status<>'bye'))),
    (SELECT count(*) FROM public.player_tournament_results r WHERE r.competition_id IN(SELECT id FROM scope))
  INTO v_scope,v_draws,v_matches,v_entries,v_human_apps,v_started,v_bad
  FROM scope;

  IF (v_scope,v_draws,v_matches,v_entries,v_human_apps,v_started,v_bad)
    IS DISTINCT FROM (22,16,676,653,1,0,0)
  THEN
    RAISE EXCEPTION 'Week 1 live source changed; scope %, draws %, matches %, entries %, human applications %, played %, results %',
      v_scope,v_draws,v_matches,v_entries,v_human_apps,v_started,v_bad;
  END IF;
  IF EXISTS(
    SELECT 1 FROM public.tournament_doubles_matches m
    JOIN public.tournament_world_competitions wc ON wc.id=m.competition_id
    JOIN public.tournament_editions e ON e.id=wc.tournament_edition_id
    JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=e.id
    WHERE e.season_number=2 AND ss.season_week=1
  ) THEN RAISE EXCEPTION 'Doubles fixtures exist, refusing to reset Week 1 singles draws'; END IF;

  INSERT INTO control_center_private.tennis_season2_week1_draw_deferral_archive_v1
    (competition_id,source_status,original_data)
  SELECT wc.id,wc.status,jsonb_build_object(
    'competition',to_jsonb(wc),
    'draws',(SELECT coalesce(jsonb_agg(to_jsonb(d)),'[]'::jsonb)
       FROM public.tournament_draw_publications d WHERE d.competition_id=wc.id),
    'matches',(SELECT coalesce(jsonb_agg(to_jsonb(m) ORDER BY m.id),'[]'::jsonb)
       FROM public.tournament_matches m WHERE m.competition_id=wc.id),
    'entries',(SELECT coalesce(jsonb_agg(to_jsonb(en) ORDER BY en.id),'[]'::jsonb)
       FROM public.tournament_entries en WHERE en.competition_id=wc.id),
    'applications',(SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.id),'[]'::jsonb)
       FROM public.tournament_applications a WHERE a.competition_id=wc.id),
    'cycles',(SELECT coalesce(jsonb_agg(to_jsonb(ec)),'[]'::jsonb)
       FROM public.tournament_competition_entry_cycles ec WHERE ec.competition_id=wc.id),
    'qualifier_slots',(SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q.section_number,q.bracket_slot),'[]'::jsonb)
       FROM public.tournament_qualifier_slots q WHERE q.competition_id=wc.id),
    'travel',(SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.id),'[]'::jsonb)
       FROM public.player_travel_legs t WHERE t.first_match_id IN(
         SELECT m.id FROM public.tournament_matches m WHERE m.competition_id=wc.id))
    )
  FROM public.tournament_world_competitions wc
  JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
  JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
  WHERE ed.season_number=2 AND ss.season_week=1
  ON CONFLICT(competition_id) DO NOTHING;

  SELECT count(*) INTO v_snap FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1;
  IF v_snap<>22 THEN RAISE EXCEPTION 'Week 1 archive incomplete: %',v_snap; END IF;

  -- Clear premature brackets, accepted slot assignments and old field locks.
  -- Player applications remain preserved, with accepted choices converted
  -- back to pending so entrants can compete in the January 3 selection.
  DELETE FROM public.tournament_matches m
  USING control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE m.competition_id=arc.competition_id;

  DELETE FROM public.tournament_draw_publications d
  USING control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE d.competition_id=arc.competition_id;

  DELETE FROM public.tournament_qualifier_slots q
  USING control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE q.competition_id=arc.competition_id;

  DELETE FROM public.tournament_entries en
  USING control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE en.competition_id=arc.competition_id AND en.entry_status='active';

  UPDATE public.tournament_applications a
  SET status='applied',decision_reason=null,decided_at=null,updated_at=now()
  FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE a.competition_id=arc.competition_id
    AND a.status IN('accepted_main_draw','accepted_qualification');

  UPDATE public.tournament_competition_entry_cycles c
  SET normal_allocation_processed_at=null,normal_allocation_game_second=null,
      ai_late_fill_processed_at=null,ai_late_fill_game_second=null,
      field_locked_at=null,field_locked_game_second=null,updated_at=now()
  FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE c.competition_id=arc.competition_id;

  -- Lima ATP was automatically canceled before the new application window
  -- existed. Its original cancellation state is archived. No game was played.
  UPDATE public.tournament_world_competitions wc SET status='scheduled'
  FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1 arc
  WHERE wc.id=arc.competition_id AND wc.status='canceled';

  -- The current calendar must say Applications Open, for all 22 ATP/WTA
  -- competitions, without any January 1 game-clock time shift.
  WITH scope AS(
    SELECT competition_id AS id FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1
  )
  SELECT (SELECT count(*) FROM public.tournament_draw_publications d WHERE d.competition_id IN(SELECT id FROM scope))
      +(SELECT count(*) FROM public.tournament_matches m WHERE m.competition_id IN(SELECT id FROM scope))
      +(SELECT count(*) FROM public.tournament_entries en WHERE en.competition_id IN(SELECT id FROM scope) AND en.entry_status='active')
      +(SELECT count(*) FROM public.tournament_world_competitions wc WHERE wc.id IN(SELECT id FROM scope) AND wc.status='canceled')
      +(SELECT count(*) FROM public.tournament_competition_entry_cycles c WHERE c.competition_id IN(SELECT id FROM scope) AND c.field_locked_at IS NOT NULL)
  INTO v_bad;
  IF v_bad<>0 THEN RAISE EXCEPTION 'Week 1 reopening left % locked results/slots',v_bad; END IF;
  SELECT count(*) INTO v_human_apps
  FROM public.tournament_applications a JOIN public.players p ON p.id=a.player_id
  WHERE a.competition_id IN(
    SELECT competition_id FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1
  ) AND p.player_type='human' AND a.status='applied';
  IF v_human_apps<>1 THEN RAISE EXCEPTION 'Human tournament preference not preserved'; END IF;
END $reopen_week1$;

-- Basic postconditions are part of the committed migration.
SELECT count(*) AS archived_week1_competitions
FROM control_center_private.tennis_season2_week1_draw_deferral_archive_v1;
