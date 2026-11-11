-- Tennis Legacy: do not treat Season 1 Weeks 1/2 as overdue before
-- their current in-game application/late-fill deadlines.
-- Scope covers the first two weeks of each season, including the unique
-- Season 1 launch rules. Everything else retains the original schedule.
-- No changes to game clock, players, entrants, tournament editions or draws.
--
-- Authoritative due time for Weeks 1-2 is the already-published timeline's
-- late_close_game_second (Jan 2 18:00 for S1 Week 1; Jan 9 18:00 for S1 Week 2;
-- Jan 3 07:00 for S2+ Week 1). Other weeks keep existing -8d +18h behavior.
DO $fix_early_weeks$
DECLARE
  v_source text;
  v_old text;
  v_new text;
  v_fn text;
  v_occurrences int;
BEGIN
  -- A shared, reviewed patch expression to keep three independently scheduled
  -- processors from making contradictory decisions on field-lock deadlines.
  FOR v_fn IN SELECT unnest(ARRAY[
    'check_tournament_entry_pipeline_health_v1',
    'auto_repair_due_tournament_entry_pipelines_v1',
    'process_minimum_tournament_fields_v1'
  ]) LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_source
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=v_fn
      AND pg_get_function_identity_arguments(p.oid)=
        CASE WHEN v_fn='auto_repair_due_tournament_entry_pipelines_v1'
             THEN 'p_limit integer' ELSE '' END;

    IF v_source IS NULL THEN
      RAISE EXCEPTION 'Expected live procedure missing: %', v_fn;
    END IF;

    IF v_fn='check_tournament_entry_pipeline_health_v1' THEN
      v_old:='v_due:=((r.start_abs-8)::bigint*86400)+(18*3600);';
      v_new:='v_due:=CASE WHEN mod(r.start_abs,366) IN (2,9)
        THEN (public.get_tournament_entry_timeline_v1(r.competition_id)->>''late_close_game_second'')::bigint
        ELSE ((r.start_abs-8)::bigint*86400)+(18*3600) END;';
    ELSIF v_fn='auto_repair_due_tournament_entry_pipelines_v1' THEN
      v_old:=$old_repair$and v_now >= (
         (min(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint))::bigint-8)*86400
         + 18*3600
       )$old_repair$;
      v_new:=$new_repair$and v_now >= (
         CASE
           WHEN min(ss.season_week) IN (1,2)
             THEN (public.get_tournament_entry_timeline_v1(wc.id)->>'late_close_game_second')::bigint
           ELSE (min(public.training_camp_week_start_absolute_v1(ed.season_number,ss.season_week::smallint))::bigint-8)*86400
                 + 18*3600
         END
       )$new_repair$;
    ELSE
      v_old:='v_due:=CASE WHEN r.start_abs>=368 AND mod(r.start_abs,366)=2 THEN (public.get_tournament_entry_timeline_v1(r.id)->>''late_close_game_second'')::bigint ELSE ((r.start_abs-8)::bigint*86400)+(18*3600) END;';
      v_new:='v_due:=CASE WHEN mod(r.start_abs,366) IN (2,9)
        THEN (public.get_tournament_entry_timeline_v1(r.id)->>''late_close_game_second'')::bigint
        ELSE ((r.start_abs-8)::bigint*86400)+(18*3600) END;';
    END IF;

    IF strpos(v_source,v_new)>0 THEN
      CONTINUE;
    END IF;

    v_occurrences:=(length(v_source)-length(replace(v_source,v_old,'')))/
      nullif(length(v_old),0);
    IF v_occurrences<>1 THEN
      RAISE EXCEPTION 'Unexpected % procedure version: expected 1 patch site, found %',
        v_fn,v_occurrences;
    END IF;
    EXECUTE replace(v_source,v_old,v_new);
  END LOOP;
END
$fix_early_weeks$;
