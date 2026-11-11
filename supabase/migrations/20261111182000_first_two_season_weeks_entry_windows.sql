-- Keep Week 1/Week 2 tournament application windows inside the game season.
-- Applies only to Week 1 of Season 1, plus Week 2 of every season; the
-- separately approved Season 2+ Week 1 schedule is preserved.
-- No clock, results, matches, published draws, or player accounts modified.
CREATE OR REPLACE FUNCTION public.get_tournament_entry_timeline_v1(p_competition_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_season integer;
  v_first_week smallint;
  v_last_week smallint;
  v_target_week smallint;
  v_world text;
  v_category text;
  v_fixed_wave smallint;
  v_wave_position integer;
  v_wave_count integer;
  v_first_start integer;
  v_decision_week_start integer;
  v_open bigint;
  v_close bigint;
  v_group_final_close bigint;
  v_late_open bigint;
  v_late_close bigint;
  v_draw bigint;
begin
  select e.season_number,
         min(sl.season_week)::smallint,
         max(sl.season_week)::smallint,
         coalesce(min(sl.season_week) filter(where sl.phase='main_draw'),min(sl.season_week))::smallint,
         wc.world,
         s.category_code
  into v_season,v_first_week,v_last_week,v_target_week,v_world,v_category
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
  where wc.id=p_competition_id and wc.status<>'canceled' and e.status<>'canceled'
  group by e.season_number,wc.id,wc.world,s.category_code;

  if v_first_week is null then raise exception 'Tournament competition is unavailable.'; end if;

  v_fixed_wave:=public.tournament_entry_wave_v1(v_category);
  v_first_start:=public.training_camp_week_start_absolute_v1(v_season,v_first_week);
  v_decision_week_start:=v_first_start-14;

  with competition_weeks as (
    select wc2.id,
           s2.category_code,
           min(sl2.season_week)::smallint first_week,
           coalesce(min(sl2.season_week) filter(where sl2.phase='main_draw'),min(sl2.season_week))::smallint target_week
    from public.tournament_world_competitions wc2
    join public.tournament_editions e2 on e2.id=wc2.tournament_edition_id
    join public.tournament_series s2 on s2.id=e2.tournament_series_id
    join public.tournament_schedule_slots sl2 on sl2.tournament_edition_id=e2.id
    where wc2.world=v_world
      and e2.season_number=v_season
      and wc2.status<>'canceled'
      and e2.status<>'canceled'
    group by wc2.id,s2.category_code
  ), waves as (
    select distinct public.tournament_entry_wave_v1(category_code) wave
    from competition_weeks
    where first_week=v_first_week and target_week=v_target_week
  )
  select count(*) filter(where wave<=v_fixed_wave),count(*)
  into v_wave_position,v_wave_count
  from waves;

  v_wave_position:=greatest(1,coalesce(v_wave_position,1));
  v_wave_count:=greatest(1,coalesce(v_wave_count,1));

  v_open:=greatest(0,v_first_start-21)::bigint*86400;
  v_close:=(v_decision_week_start+v_wave_position-1)::bigint*86400 + 12*3600;
  v_group_final_close:=(v_decision_week_start+v_wave_count-1)::bigint*86400 + 12*3600;
  v_late_open:=case when v_first_week<v_target_week then v_close else v_group_final_close end;
  v_late_close:=(v_decision_week_start+6)::bigint*86400 + 18*3600;
  v_draw:=(
    v_first_start
    - case when v_last_week>v_first_week then 5 else 3 end
  )::bigint*86400 + 18*3600;



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

  -- The first two calendar weeks must remain enterable after the new
  -- season opens. Their original 14-day lead time falls in the PREVIOUS
  -- season, when new careers may not yet exist.
  -- Do not touch published draws/processing state; the only effect is
  -- authoritative application, allocation and draw deadlines.
  -- Week 1 for Seasons >=2 retains its separately defined Jan 3
  -- 06:00/07:00/08:00 schedule above.
  IF (v_first_week=1 AND v_season=1) OR v_first_week=2 THEN
    v_open:=(v_season-1)::bigint * 31622400;
    v_close:=(v_first_start-1)::bigint*86400+16*3600;
    v_group_final_close:=v_close;
    v_late_open:=v_close;
    v_late_close:=(v_first_start-1)::bigint*86400+18*3600;
    v_draw:=(v_first_start-1)::bigint*86400+22*3600;
  END IF;

  return jsonb_build_object(
    'season_number',v_season,
    'tournament_start_week',v_first_week,
    'season_week',v_target_week,
    'target_season_week',v_target_week,
    'entry_model','staggered_ladder',
    'entry_wave',jsonb_build_object(
      'fixed_wave',v_fixed_wave,'position',v_wave_position,'wave_count',v_wave_count,
      'label',public.tournament_entry_wave_label_v1(v_category)
    ),
    'tournament_start',public.game_moment_json_v1(v_first_start::bigint*86400 + CASE WHEN v_first_week=1 AND v_season>=2 THEN 10*3600 ELSE 0 END),
    'applications_open',public.game_moment_json_v1(v_open),
    'normal_applications_close',public.game_moment_json_v1(v_close),
    'field_announcement',public.game_moment_json_v1(v_close),
    'late_entry_open',public.game_moment_json_v1(v_late_open),
    'late_entry_close',public.game_moment_json_v1(v_late_close),
    'draw_publish',public.game_moment_json_v1(v_draw),
    'applications_open_game_second',v_open,
    'normal_close_game_second',v_close,
    'allocation_game_second',v_close,
    'late_open_game_second',v_late_open,
    'late_close_game_second',v_late_close,
    'draw_publish_game_second',v_draw
  );
end;
$function$
;