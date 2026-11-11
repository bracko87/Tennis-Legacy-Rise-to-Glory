-- Season 2 Week 1 transition recovery: five undrawn competitions only.
-- Normal applications: Jan 1 00:00 through Jan 2 16:00 (game time).
-- Late entries/AI fill: Jan 2 16:00-18:00.
-- Field lock: Jan 2 18:00. Official draw: Jan 2 22:00.
-- Matches start Jan 3 at 10:00. All 16 already published draws remain untouched.
-- The fix is isolated to five verified competitions. Requires separate authorized
-- production migration; committing this file to main does NOT execute it.
CREATE TABLE IF NOT EXISTS control_center_private.tennis_season2_week1_recovery_windows_v1(
  competition_id uuid PRIMARY KEY REFERENCES public.tournament_world_competitions(id),
  planned_from timestamptz NOT NULL DEFAULT now(),
  reason text NOT NULL DEFAULT 'Season 2 January entry deadline extension'
);
REVOKE ALL ON control_center_private.tennis_season2_week1_recovery_windows_v1 FROM public, anon, authenticated;

DO $verify_targets$
DECLARE
  n integer;
BEGIN
  WITH expected(tournament_name, tour) AS (
    VALUES ('Cape Town Challenger','WTA'),('Nonthaburi Challenger','WTA'),
           ('Nottingham Challenger','ATP'),('Orlando Futures','ATP'),
           ('Orlando Futures','WTA')
  ), target AS (
    SELECT wc.id
    FROM expected exp
    JOIN public.tournament_series ts ON ts.name=exp.tournament_name
    JOIN public.tournament_editions ed ON ed.tournament_series_id=ts.id
      AND ed.season_number=2 AND ed.status='scheduled'
    JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
      AND ss.season_week=1
    JOIN public.tournament_world_competitions wc ON wc.tournament_edition_id=ed.id
      AND wc.world=exp.tour AND wc.status='scheduled'
  )
  SELECT count(DISTINCT id) INTO n FROM target;
  IF n <> 5 THEN RAISE EXCEPTION 'Expected five unique Season 2 Week 1 undrawn competitions, found %',n; END IF;
  IF EXISTS(
    SELECT 1 FROM public.tournament_world_competitions wc
    JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
    JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
    JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
    WHERE ed.season_number=2 AND ss.season_week=1
      AND (ts.name,wc.world) IN(
        ('Cape Town Challenger','WTA'),('Nonthaburi Challenger','WTA'),
        ('Nottingham Challenger','ATP'),('Orlando Futures','ATP'),('Orlando Futures','WTA')
      ) AND (
        EXISTS(SELECT 1 FROM public.tournament_draw_publications dp WHERE dp.competition_id=wc.id)
        OR EXISTS(SELECT 1 FROM public.tournament_matches m WHERE m.competition_id=wc.id)
        OR EXISTS(SELECT 1 FROM public.player_tournament_results r WHERE r.competition_id=wc.id)
        OR EXISTS(SELECT 1 FROM public.tournament_entries te WHERE te.competition_id=wc.id AND te.entry_status='active')
      )
  ) THEN
    RAISE EXCEPTION 'Refusing to reopen a competition with a published draw, real match, result or active entrant';
  END IF;
END
$verify_targets$;

INSERT INTO control_center_private.tennis_season2_week1_recovery_windows_v1(competition_id)
SELECT DISTINCT wc.id
FROM public.tournament_world_competitions wc
JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
WHERE ed.season_number=2 AND ed.status='scheduled'
  AND wc.status='scheduled' AND ss.season_week=1
  AND (ts.name,wc.world) IN (
    ('Cape Town Challenger','WTA'),('Nonthaburi Challenger','WTA'),
    ('Nottingham Challenger','ATP'),('Orlando Futures','ATP'),('Orlando Futures','WTA')
  )
ON CONFLICT(competition_id) DO NOTHING;

-- These five competitions have no accepted entries or draws, but their old
-- entry lifecycle was prematurely marked processed/locked before migration.
-- Leave prior withdrawn application history intact.
UPDATE public.tournament_competition_entry_cycles ec
SET normal_allocation_processed_at=null,
    normal_allocation_game_second=null,
    ai_late_fill_processed_at=null,
    ai_late_fill_game_second=null,
    field_locked_at=null,
    field_locked_game_second=null,
    updated_at=now()
WHERE ec.competition_id IN (
  SELECT competition_id FROM control_center_private.tennis_season2_week1_recovery_windows_v1
);

DO $patch_procedures$
DECLARE
  v_source text;
  v_original text;
  v_replacement text;
  v_hits integer;
  v_name text;
BEGIN
  -- The currently installed function definitions are used as source: this
  -- retains later fixes instead of reinstalling an older historical function.
  FOR v_name IN SELECT unnest(ARRAY[
      'get_tournament_entry_timeline_v1',
      'auto_repair_due_tournament_entry_pipelines_v1',
      'check_tournament_entry_pipeline_health_v1',
      'process_minimum_tournament_fields_v1'
    ])
  LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_source
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=v_name;
    IF v_source IS NULL THEN RAISE EXCEPTION 'Expected function % missing',v_name; END IF;

    IF v_name='get_tournament_entry_timeline_v1' THEN
      v_original := E'  return jsonb_build_object(\n    ''season_number''';
      v_replacement := $timeline$
  -- Protected Week 1 extension following the Season 1 to 2 transition.
  -- Use only the five specifically approved undrawn competitions.
  if v_season=2 and v_first_week=1 and exists(
    select 1 from control_center_private.tennis_season2_week1_recovery_windows_v1
    where competition_id=p_competition_id
  ) then
    v_open := (v_first_start-2)::bigint * 86400;
    v_close := (v_first_start-1)::bigint * 86400 + 16*3600;
    v_group_final_close := v_close;
    v_late_open := v_close;
    v_late_close := (v_first_start-1)::bigint * 86400 + 18*3600;
    v_draw := (v_first_start-1)::bigint * 86400 + 22*3600;
  end if;

  return jsonb_build_object(
    'season_number'$timeline$;
    ELSIF v_name='auto_repair_due_tournament_entry_pipelines_v1' THEN
      v_original := E'  loop\n    select * into v_cycle';
      v_replacement := $entry_auto$
  loop
    -- A renewed application window is not a failed entry pipeline.
    if exists(
      select 1 from control_center_private.tennis_season2_week1_recovery_windows_v1
      where competition_id=r.competition_id
    ) and v_now<(public.get_tournament_entry_timeline_v1(r.competition_id)->>'late_close_game_second')::bigint then
      continue;
    end if;
    select * into v_cycle$entry_auto$;
    ELSIF v_name='check_tournament_entry_pipeline_health_v1' THEN
      v_original := E'  loop\n    v_due:=';
      v_replacement := $health$
  loop
    if exists(
      select 1 from control_center_private.tennis_season2_week1_recovery_windows_v1
      where competition_id=r.competition_id
    ) and v_now<(public.get_tournament_entry_timeline_v1(r.competition_id)->>'late_close_game_second')::bigint then
      perform public.resolve_system_incident_by_dedupe_v1(
        'business:tournament-entry-pipeline:'||r.competition_id::text,
        'Week 1 deadline was extended and entry processing is not due yet.'
      );
      continue;
    end if;
    v_due:=$health$;
    ELSE
      v_original := E'  loop\n    v_due:=';
      v_replacement := $minimum$
  loop
    if exists(
      select 1 from control_center_private.tennis_season2_week1_recovery_windows_v1
      where competition_id=r.id
    ) and v_game_seconds<(public.get_tournament_entry_timeline_v1(r.id)->>'late_close_game_second')::bigint then
      continue;
    end if;
    v_due:=$minimum$;
    END IF;

    v_hits := (length(v_source)-length(replace(v_source,v_original,'')))/length(v_original);
    IF v_hits<>1 THEN RAISE EXCEPTION 'Unexpected function % signature / patch site count %',v_name,v_hits; END IF;
    EXECUTE replace(v_source,v_original,v_replacement);
  END LOOP;
END
$patch_procedures$;

-- Assert the new deadlines and protected scope. The statement must fail
-- rather than silently apply if a different date calculation is in place.
DO $verify_window$
DECLARE
  rec record;
  t jsonb;
  n integer:=0;
BEGIN
  FOR rec IN SELECT competition_id FROM control_center_private.tennis_season2_week1_recovery_windows_v1 LOOP
    t:=public.get_tournament_entry_timeline_v1(rec.competition_id);
    IF (t->>'applications_open_game_second')::bigint<>366*86400
       OR (t->>'normal_close_game_second')::bigint<>367*86400+16*3600
       OR (t->>'late_close_game_second')::bigint<>367*86400+18*3600
       OR (t->>'draw_publish_game_second')::bigint<>367*86400+22*3600
    THEN RAISE EXCEPTION 'Incorrect Week 1 recovery timeline for %',rec.competition_id; END IF;
    n:=n+1;
  END LOOP;
  IF n<>5 THEN RAISE EXCEPTION 'Incorrect number of extended windows: %',n; END IF;
END
$verify_window$;
