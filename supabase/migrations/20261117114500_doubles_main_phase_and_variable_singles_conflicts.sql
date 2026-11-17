-- Restrict future doubles to the configured main-draw week and use the
-- same projected singles duration when checking doubles player/court slots.
-- Existing completed doubles results are never rewritten.
CREATE OR REPLACE FUNCTION public.player_match_slot_conflict_v1(p_player_id uuid, p_competition_id uuid, p_season integer, p_week integer, p_day integer, p_start_minute integer, p_duration_minutes integer, p_recovery_minutes integer, p_exclude_doubles_match uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    left join public.tournament_match_simulations sim on sim.match_id=m.id
    where e.season_number=p_season and m.scheduled_season_week=p_week and m.scheduled_day=p_day
      and m.status not in ('cancelled','bye') and m.scheduled_start_minute is not null
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and p_start_minute < m.scheduled_start_minute + coalesce(m.actual_duration_minutes,
        case when sim.match_id is not null then public.simulated_tennis_duration_minutes_v1(sim.total_games,sim.total_points) end,
        m.estimated_duration_minutes,150) + p_recovery_minutes
      and m.scheduled_start_minute < p_start_minute + p_duration_minutes + p_recovery_minutes
    union all
    select 1
    from public.tournament_doubles_matches dm
    join public.tournament_world_competitions wc on wc.id=dm.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    left join public.tournament_doubles_teams t1 on t1.id=dm.team1_id
    left join public.tournament_doubles_teams t2 on t2.id=dm.team2_id
    where e.season_number=p_season and dm.scheduled_season_week=p_week and dm.scheduled_day=p_day
      and dm.status not in ('cancelled','bye') and dm.scheduled_start_minute is not null
      and dm.id is distinct from p_exclude_doubles_match
      and p_player_id in (t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id)
      and p_start_minute < dm.scheduled_start_minute + coalesce(dm.actual_duration_minutes,dm.estimated_duration_minutes,105) + p_recovery_minutes
      and dm.scheduled_start_minute < p_start_minute + p_duration_minutes + p_recovery_minutes
  );
$function$
;
CREATE OR REPLACE FUNCTION public.schedule_doubles_match_v1(p_match_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  m public.tournament_doubles_matches%rowtype;
  v_season integer;v_category text;v_start_abs integer;v_end_abs integer;v_preferred_abs integer;v_abs integer;
  v_week integer;v_day integer;v_base integer;v_duration integer;v_recovery integer;v_courts integer;
  v_slots smallint[];v_slot integer;v_court integer;v_player uuid;v_players uuid[];v_conflict boolean;v_surface text;
  v_game_minute bigint:=public.current_game_second_v1()/60;
  t1 public.tournament_doubles_teams%rowtype;t2 public.tournament_doubles_teams%rowtype;
begin
  select * into m from public.tournament_doubles_matches where id=p_match_id for update;
  if m.id is null then return jsonb_build_object('status','missing'); end if;
  if m.status<>'scheduled' or m.team1_id is null or m.team2_id is null then return jsonb_build_object('status','not_ready'); end if;
  select * into t1 from public.tournament_doubles_teams where id=m.team1_id;
  select * into t2 from public.tournament_doubles_teams where id=m.team2_id;
  v_players:=array[t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id];
  select e.season_number,ts.category_code,ts.surface,
   coalesce(main_phase.main_start,w.start_absolute_day),
   coalesce(main_phase.main_end,w.end_absolute_day),
         ds.estimated_match_duration_minutes,ds.minimum_recovery_minutes,sr.court_count,
         sr.regular_slot_minutes||sr.late_slot_minutes
  into v_season,v_category,v_surface,v_start_abs,v_end_abs,v_duration,v_recovery,v_courts,v_slots
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=e.tournament_series_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id
  join public.tournament_match_scheduling_rules sr on sr.category_code=ts.category_code
  cross join lateral public.get_competition_window_v1(wc.id) w
  left join lateral (
    select (e.season_number-1)*366+2+(min(ss.season_week)-1)*7 as main_start,
           (e.season_number-1)*366+2+(max(ss.season_week)-1)*7+6 as main_end
    from public.tournament_schedule_slots ss
    where ss.tournament_edition_id=e.id and ss.phase='main_draw'
  ) main_phase on true
  where wc.id=m.competition_id;
  v_preferred_abs:=least(v_end_abs,v_start_abs+greatest(m.round_number-1,0));
  v_base:=(v_season-1)*366+2;
  for v_abs in v_preferred_abs..v_end_abs loop
    v_week:=floor((v_abs-v_base)::numeric/7)::integer+1;v_day:=mod(v_abs-v_base,7)+1;
    if v_week<1 or v_day not between 1 and 7 then continue; end if;
    foreach v_slot in array v_slots loop
      -- A newly booked/rescheduled match cannot be set in the past.
      if v_abs::bigint*1440+v_slot<=v_game_minute+10 then continue; end if;
      for v_court in 1..v_courts loop
        if exists(
          select 1 from public.tournament_matches sm
          left join public.tournament_match_simulations sim on sim.match_id=sm.id
          where sm.competition_id=m.competition_id and sm.scheduled_season_week=v_week and sm.scheduled_day=v_day
            and sm.court_number=v_court and sm.scheduled_start_minute is not null and sm.status not in ('cancelled','bye')
            and v_slot < sm.scheduled_start_minute+coalesce(sm.actual_duration_minutes,
             case when sim.match_id is not null then public.simulated_tennis_duration_minutes_v1(sim.total_games,sim.total_points) end,
             sm.estimated_duration_minutes,150)
            and sm.scheduled_start_minute < v_slot+v_duration
        ) or exists(
          select 1 from public.tournament_doubles_matches dm
          where dm.competition_id=m.competition_id and dm.id<>m.id and dm.scheduled_season_week=v_week and dm.scheduled_day=v_day
            and dm.court_number=v_court and dm.scheduled_start_minute is not null and dm.status not in ('cancelled','bye')
            and v_slot < dm.scheduled_start_minute+coalesce(dm.actual_duration_minutes,dm.estimated_duration_minutes,v_duration)
            and dm.scheduled_start_minute < v_slot+v_duration
        ) then continue; end if;
        v_conflict:=false;
        foreach v_player in array v_players loop
          if public.player_match_count_on_game_day_v1(v_player,v_season,v_week,v_day,m.id)>=2
             or public.player_match_slot_conflict_v1(v_player,m.competition_id,v_season,v_week,v_day,v_slot,v_duration,v_recovery,m.id) then
            v_conflict:=true;exit;
          end if;
        end loop;
        if not v_conflict then
          update public.tournament_doubles_matches
          set scheduled_season_week=v_week,scheduled_day=v_day,scheduled_start_minute=v_slot,court_number=v_court,
              estimated_duration_minutes=v_duration,schedule_reason=case when v_abs=v_preferred_abs then 'standard' else 'conflict_rescheduled' end,updated_at=now()
          where id=m.id;
          return jsonb_build_object('status','scheduled','season_week',v_week,'day',v_day,'start_minute',v_slot,'court_number',v_court);
        end if;
      end loop;
    end loop;
  end loop;
  update public.tournament_doubles_matches set scheduled_start_minute=null,court_number=null,schedule_reason='conflict_pending',updated_at=now() where id=m.id;
  return jsonb_build_object('status','no_valid_slot');
end;$function$
;
