create or replace function public.player_ready_for_tournament_match_v1(p_player_id uuid, p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  tm record;
  pm record;
  tl record;
  rule public.tournament_match_scheduling_rules%rowtype;
  q jsonb;
  v_class text:='Economy';
  v_target_day integer;
  v_target_abs_min bigint;
  v_travel_day integer;
  v_depart_abs_min bigint;
  v_prev_end bigint;
  v_travel_minutes integer:=0;
  v_arrival_abs_min bigint;
  v_ready_abs_min bigint;
  v_status text:='normal';
begin
  select m.*,ed.season_number,ts.city target_city,ts.country_code target_country,
         ts.latitude target_lat,ts.longitude target_lon,ts.category_code
  into tm
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where m.id=p_match_id;

  if tm.id is null then return jsonb_build_object('status','missing_match'); end if;

  select * into rule
  from public.tournament_match_scheduling_rules
  where category_code=tm.category_code;

  v_target_day:=(((tm.season_number-1)*366)+2+((tm.scheduled_season_week-1)*7)+(tm.scheduled_day-1))::integer;
  v_target_abs_min:=v_target_day::bigint*1440+coalesce(tm.scheduled_start_minute,600);
  v_travel_day:=v_target_day-1;

  -- If the travel planner has already created a real leg for this tournament,
  -- its actual departure/arrival timing is authoritative for first-match readiness.
  select l.* into tl
  from public.player_travel_legs l
  where l.player_id=p_player_id
    and l.destination_location_type='tournament'
    and l.destination_reference_id=tm.competition_id::text
    and l.status in ('planned','completed')
  order by case when l.status='planned' then 0 else 1 end,l.created_at desc
  limit 1;

  if tl.id is not null then
    v_depart_abs_min:=tl.departure_absolute_day::bigint*1440+coalesce(tl.departure_minute_of_day,540);
    v_travel_minutes:=greatest(
      0,
      coalesce(
        tl.estimated_travel_minutes,
        (tl.arrival_absolute_day::bigint*1440+coalesce(tl.arrival_minute_of_day,0)-v_depart_abs_min)::integer,
        0
      )
    );
    v_arrival_abs_min:=tl.arrival_absolute_day::bigint*1440
      +coalesce(tl.arrival_minute_of_day,(v_depart_abs_min+v_travel_minutes-tl.arrival_absolute_day::bigint*1440)::integer);
    v_ready_abs_min:=v_arrival_abs_min+coalesce(rule.pre_match_arrival_buffer_minutes,90);

    if v_ready_abs_min>v_target_abs_min then v_status:='impossible';
    elsif (v_arrival_abs_min/1440)::integer>=v_target_day
       or v_depart_abs_min>v_travel_day::bigint*1440+540 then v_status:='tight';
    else v_status:='normal'; end if;

    return jsonb_build_object(
      'status',v_status,
      'preferred_travel_day',v_travel_day,
      'departure_absolute_minute',v_depart_abs_min,
      'arrival_absolute_minute',v_arrival_abs_min,
      'ready_absolute_minute',v_ready_abs_min,
      'target_absolute_minute',v_target_abs_min,
      'travel_minutes',v_travel_minutes,
      'travel_leg_id',tl.id,
      'previous_match_id',null,
      'basis','planned_travel_leg'
    );
  end if;

  -- Fallback for a match being evaluated before a travel leg has been built.
  v_depart_abs_min:=v_travel_day::bigint*1440+540;

  select m.id match_id,m.scheduled_start_minute,
         coalesce(m.actual_duration_minutes,m.estimated_duration_minutes,150) duration_minutes,
         (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day,
         s.city,s.country_code,s.latitude,s.longitude,m.competition_id
  into pm
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where m.competition_id<>tm.competition_id
    and (m.player1_id=p_player_id or m.player2_id=p_player_id)
    and m.status not in ('bye','cancelled')
    and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*1440+coalesce(m.scheduled_start_minute,600)) < v_target_abs_min
  order by abs_day desc,coalesce(m.scheduled_start_minute,600) desc
  limit 1;

  if pm.match_id is not null and pm.abs_day>=v_travel_day then
    v_prev_end:=pm.abs_day::bigint*1440+coalesce(pm.scheduled_start_minute,600)
      +pm.duration_minutes+coalesce(rule.post_match_departure_buffer_minutes,60);
    v_depart_abs_min:=greatest(v_depart_abs_min,v_prev_end);
    select player_travel_class into v_class
    from public.player_tournament_preparation_plans
    where player_id=p_player_id and competition_id=tm.competition_id;
    v_class:=coalesce(v_class,'Economy');
    q:=public.quote_travel_v2(pm.city,pm.country_code,pm.latitude,pm.longitude,
                              tm.target_city,tm.target_country,tm.target_lat,tm.target_lon,
                              v_class,'one_way');
    v_travel_minutes:=greatest(30,ceil(coalesce((q->>'estimated_hours_one_way')::numeric,1)*60)::integer);
  end if;

  v_arrival_abs_min:=v_depart_abs_min+v_travel_minutes;
  v_ready_abs_min:=v_arrival_abs_min+coalesce(rule.pre_match_arrival_buffer_minutes,90);

  if v_ready_abs_min>v_target_abs_min then v_status:='impossible';
  elsif (v_arrival_abs_min/1440)::integer>=v_target_day
     or v_depart_abs_min>v_travel_day::bigint*1440+540 then v_status:='tight';
  else v_status:='normal'; end if;

  return jsonb_build_object(
    'status',v_status,
    'preferred_travel_day',v_travel_day,
    'departure_absolute_minute',v_depart_abs_min,
    'arrival_absolute_minute',v_arrival_abs_min,
    'ready_absolute_minute',v_ready_abs_min,
    'target_absolute_minute',v_target_abs_min,
    'travel_minutes',v_travel_minutes,
    'previous_match_id',pm.match_id,
    'basis','fallback_schedule'
  );
end;
$$;

-- Re-evaluate upcoming human first matches now that planned travel duration is authoritative.
do $$
declare r record;
begin
  for r in
    select p.id
    from public.players p
    where p.player_type='human' and p.owner_user_id is not null
  loop
    perform public.refresh_player_future_first_match_schedule_v1(r.id);
  end loop;
end;
$$;
