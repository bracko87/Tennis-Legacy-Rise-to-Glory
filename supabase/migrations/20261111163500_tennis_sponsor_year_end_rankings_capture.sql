
-- Capture exact 31 December singles rankings after their official publication.
-- The year-end snapshot is used for next-season sponsor offers.
CREATE OR REPLACE FUNCTION public.trg_capture_sponsor_year_end_rankings_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public,pg_temp AS $fn$
DECLARE d record;v_abs integer;
BEGIN
 IF NEW.month=12 AND NEW.day=31 THEN
   SELECT * INTO d FROM public.get_current_game_day_internal_v1();
   v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
   IF d.season=NEW.season AND d.month=12 AND d.day=31 AND v_abs=NEW.game_absolute_day THEN
     PERFORM public.capture_world_ranking_snapshot_internal_v1();
   END IF;
 END IF;
 RETURN NEW;
END $fn$;
DROP TRIGGER IF EXISTS trg_capture_sponsor_year_end_rankings_v1 ON public.ranking_publication_runs;
CREATE TRIGGER trg_capture_sponsor_year_end_rankings_v1
AFTER INSERT OR UPDATE ON public.ranking_publication_runs
FOR EACH ROW EXECUTE FUNCTION public.trg_capture_sponsor_year_end_rankings_v1();
