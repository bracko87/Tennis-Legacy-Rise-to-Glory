-- Tennis Legacy: prevent 16 repeated false tournament failures between the
-- start of a game Monday and the old real-hourly rankings cron (6x game clock).
-- Due, finalized ranking results are published by the existing idempotent
-- ranking routine BEFORE tournament operations evaluates closure.
-- Keep the hourly ranking cron as a backup. No game-clock or data reset.
--
-- This is intentionally limited to game Mondays, when the existing publisher
-- is allowed to process results. If publishing fails, do not hide any real
-- warning: normal watchdog processing continues and reports the problem.
DO $align_ranking_publication$
DECLARE
  v_source text;
  v_old text;
  v_new text;
  v_anchor text;
  v_patch text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND p.proname='run_tournament_operations_watchdog_v1'
    AND pg_get_function_identity_arguments(p.oid)='';

  IF v_source IS NULL THEN
    RAISE EXCEPTION 'Tournament operations watchdog not found';
  END IF;

  IF strpos(v_source,'v_ranking_recovery jsonb;')>0 THEN
    RAISE EXCEPTION 'Tournament watchdog already contains a ranking recovery patch; review before reapplying';
  END IF;

  v_old:='  v_engine jsonb;';
  v_new:='  v_engine jsonb;'||chr(10)||'  v_ranking_recovery jsonb;';
  IF (length(v_source)-length(replace(v_source,v_old,'')))/length(v_old)<>1 THEN
    RAISE EXCEPTION 'Unexpected watchdog declaration; refusing unverified patch';
  END IF;
  v_source:=replace(v_source,v_old,v_new);

  v_anchor:=$anchor$
  for v_row in
    select * from public.tournament_operations_rows_v1('problems',30) r
$anchor$;
  v_patch:=$patch$
  -- Game time can cross a Monday boundary at 6x between hourly ranking
  -- cron runs. Publish only genuinely due results from finished/cancelled
  -- tournaments, using the ordinary ranking cycle's idempotency protections.
  -- If already published, this query is false and no extra work is done.
  IF (SELECT speed_multiplier FROM public.get_game_clock_v1())>0
     AND NOT (SELECT is_paused FROM public.game_clock WHERE id=1)
     AND EXISTS(
       SELECT 1
       FROM public.get_current_game_day_internal_v1() d
       WHERE mod(
         public.game_day_absolute_v1(d.season,d.month,d.day)
         -(d.season-1)*366-2,7
       )=0
       AND EXISTS (
         SELECT 1
         FROM public.player_tournament_results r
         WHERE r.ranking_publish_status='pending'
           AND r.ranking_publish_absolute_day IS NOT NULL
           AND r.ranking_publish_absolute_day<=public.game_day_absolute_v1(d.season,d.month,d.day)
           AND NOT EXISTS (
             SELECT 1 FROM public.ranking_defence_cycles dc
             WHERE dc.competition_id=r.competition_id
           )
           AND (
             EXISTS (
               SELECT 1 FROM public.tournament_matches fm
               WHERE fm.competition_id=r.competition_id
                 AND fm.draw_type='main_draw'
                 AND lower(fm.round_label)='final'
                 AND fm.status IN ('completed','walkover')
                 AND fm.winner_id IS NOT NULL
             )
             OR EXISTS (
               SELECT 1 FROM public.tournament_cancellations cx
               WHERE cx.competition_id=r.competition_id
             )
           )
       )
     )
  THEN
    BEGIN
      v_ranking_recovery:=public.process_weekly_rankings_v1();
    EXCEPTION WHEN OTHERS THEN
      -- Let the normal Control Center incident surface genuine failures.
      v_ranking_recovery:=jsonb_build_object(
        'status','failed',
        'error',sqlerrm
      );
    END;
  END IF;

$patch$;
  IF (length(v_source)-length(replace(v_source,v_anchor,'')))/length(v_anchor)<>1 THEN
    RAISE EXCEPTION 'Unexpected watchdog problem-query anchor; refusing patch';
  END IF;
  v_source:=replace(v_source,v_anchor,v_patch||v_anchor);

  v_old:='''engine_after_recovery'',coalesce(v_engine,''{}''::jsonb)';
  v_new:='''engine_after_recovery'',coalesce(v_engine,''{}''::jsonb),'||
    chr(10)||'      ''ranking_recovery'',coalesce(v_ranking_recovery,''{}''::jsonb)';
  IF (length(v_source)-length(replace(v_source,v_old,'')))/length(v_old)<>1 THEN
    RAISE EXCEPTION 'Unexpected watchdog monitoring metadata anchor';
  END IF;
  v_source:=replace(v_source,v_old,v_new);

  EXECUTE v_source;
END
$align_ranking_publication$;
