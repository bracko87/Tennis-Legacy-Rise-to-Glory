-- Only newly inserted matches use the corrected configured phase weeks.
-- No UPDATE/DELETE to existing matches, draws, results, rankings or travel.
CREATE OR REPLACE FUNCTION public.apply_multiweek_tournament_match_schedule_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
 v_slot_count integer;
 v_qual_week integer;
 v_main_first_week integer;
 v_main_last_week integer;
 v_q_rounds integer;
 v_rounds integer;
 v_main_days integer;
 v_first_day integer;
 v_event_day integer;
BEGIN
 IF new.round_number IS NULL OR new.round_number<1
    OR new.draw_type NOT IN ('qualification','main_draw') THEN RETURN new; END IF;

 SELECT count(DISTINCT ss.season_week),
        min(ss.season_week) FILTER (WHERE ss.phase='qualification'),
        min(ss.season_week) FILTER (WHERE ss.phase='main_draw'),
        max(ss.season_week) FILTER (WHERE ss.phase='main_draw'),
        tc.qualification_rounds_max
 INTO v_slot_count,v_qual_week,v_main_first_week,v_main_last_week,v_q_rounds
 FROM public.tournament_world_competitions wc
 JOIN public.tournament_editions ed ON ed.id=wc.tournament_edition_id
 JOIN public.tournament_series ts ON ts.id=ed.tournament_series_id
 JOIN public.tournament_categories tc ON tc.code=ts.category_code
 JOIN public.tournament_schedule_slots ss ON ss.tournament_edition_id=ed.id
 WHERE wc.id=new.competition_id
 GROUP BY tc.qualification_rounds_max;

 IF coalesce(v_slot_count,0)<2 THEN RETURN new; END IF;

 -- Fail closed when configured phases cannot produce a sensible calendar.
 IF v_main_first_week IS NULL OR v_main_last_week IS NULL
    OR (v_qual_week IS NOT NULL AND v_qual_week>=v_main_first_week) THEN
    RAISE EXCEPTION 'Invalid configured qualification/main-draw weeks for competition %',new.competition_id;
 END IF;

 IF new.draw_type='qualification' THEN
    IF v_qual_week IS NULL THEN RAISE EXCEPTION 'Qualification week missing for competition %',new.competition_id; END IF;
    v_q_rounds:=greatest(1,least(6,coalesce(v_q_rounds,1)));
    IF new.round_number>v_q_rounds THEN RAISE EXCEPTION 'Qualification round % exceeds configured maximum %',new.round_number,v_q_rounds; END IF;
    new.scheduled_season_week:=v_qual_week;
    new.scheduled_day:=(6-(v_q_rounds-new.round_number))::smallint;
    RETURN new;
 END IF;

 -- Main-draw rounds begin no earlier than the configured main-draw week.
 v_rounds:=ceil(log(2::numeric,greatest(new.bracket_size,2)::numeric))::integer;
 v_main_days:=(v_main_last_week-v_main_first_week+1)*7;
 IF v_rounds>v_main_days OR new.round_number>v_rounds THEN
    RAISE EXCEPTION 'Cannot place round % of % within main-draw weeks %–%',new.round_number,v_rounds,v_main_first_week,v_main_last_week;
 END IF;
 v_first_day:=CASE WHEN v_rounds>=7 THEN 1 ELSE 2 END;
 IF v_rounds=1 THEN
    v_event_day:=v_main_days;
 ELSE
    v_event_day:=round(v_first_day + ((new.round_number-1)::numeric
                       *(v_main_days-v_first_day)::numeric/(v_rounds-1)::numeric))::integer;
 END IF;
 new.scheduled_season_week:=v_main_first_week+(v_event_day-1)/7;
 new.scheduled_day:=(((v_event_day-1)%7)+1)::smallint;
 RETURN new;
END;
$function$;
