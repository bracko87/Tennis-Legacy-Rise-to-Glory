create or replace function public.player_has_confirmed_tournament_match_on_day_v1(
  p_player_id uuid,
  p_absolute_day integer
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists(
    select 1
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
      and (
        ((ed.season_number-1)*366)+2+
        ((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
      )::integer=p_absolute_day
  );
$$;

revoke all on function public.player_has_confirmed_tournament_match_on_day_v1(uuid,integer) from public, anon, authenticated;

create or replace function public.player_commitment_locations_v1(p_player_id uuid)
returns table(
  commitment_type text,
  reference_id text,
  start_absolute_day integer,
  end_absolute_day integer,
  city text,
  country_code text,
  continent text,
  latitude double precision,
  longitude double precision
)
language sql
stable
set search_path to 'public'
as $$
with camps as (
  select
    'training_camp'::text,
    b.id::text,
    b.start_absolute_day,
    b.end_absolute_day,
    l.city,
    l.country_code,
    l.continent,
    l.latitude,
    l.longitude
  from public.player_training_camp_bookings b
  join public.training_camp_programs p on p.id=b.program_id
  join public.training_camp_locations l on l.id=p.location_id
  where b.player_id=p_player_id
    and b.status in ('booked','active','completed')
), tournament_base as (
  select
    e.competition_id,
    e.draw_type,
    e.entry_status,
    te.season_number,
    ts.city,
    ts.country_code,
    public.country_continent_v1(ts.country_code) continent,
    ts.latitude,
    ts.longitude,
    (
      ((te.season_number-1)*366)+2+
      ((coalesce(
        min(ss.season_week) filter (where ss.phase='full' or ss.phase=e.draw_type),
        min(ss.season_week)
      )-1)*7)
    )::integer phase_start_absolute_day,
    (
      ((te.season_number-1)*366)+2+
      ((coalesce(
        max(ss.season_week) filter (where ss.phase='full' or ss.phase=e.draw_type),
        max(ss.season_week)
      )-1)*7)+6
    )::integer phase_end_absolute_day
  from public.tournament_entries e
  join public.tournament_world_competitions wc on wc.id=e.competition_id
  join public.tournament_editions te on te.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=te.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
  where e.player_id=p_player_id
    and e.entry_status in ('active','eliminated','champion')
    and wc.status<>'canceled'
    and te.status<>'canceled'
  group by
    e.competition_id,e.draw_type,e.entry_status,te.season_number,
    ts.city,ts.country_code,ts.latitude,ts.longitude
), tournaments as (
  select
    'tournament'::text,
    tb.competition_id::text,
    first_player.first_day::integer start_absolute_day,
    case
      when tb.entry_status='eliminated' then coalesce(elimination.elimination_absolute_day,completion.last_completed_absolute_day,first_player.first_day)::integer
      when tb.entry_status='champion' then coalesce(completion.last_completed_absolute_day,schedule_end.last_possible_day,first_player.first_day)::integer
      else coalesce(schedule_end.last_possible_day,first_player.first_day)::integer
    end end_absolute_day,
    tb.city,
    tb.country_code,
    tb.continent,
    tb.latitude,
    tb.longitude
  from tournament_base tb
  left join lateral (
    select min(
      ((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
    )::integer first_day
    from public.tournament_matches m
    where m.competition_id=tb.competition_id
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
  ) first_player on true
  left join lateral (
    select max(
      ((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
    )::integer last_possible_day
    from public.tournament_matches m
    where m.competition_id=tb.competition_id
      and m.draw_type=tb.draw_type
      and m.status<>'cancelled'
  ) schedule_end on true
  left join lateral (
    select max(
      ((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
    )::integer elimination_absolute_day
    from public.tournament_matches m
    where m.competition_id=tb.competition_id
      and m.status='completed'
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.winner_id is not null
      and m.winner_id<>p_player_id
  ) elimination on true
  left join lateral (
    select max(
      ((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
    )::integer last_completed_absolute_day
    from public.tournament_matches m
    where m.competition_id=tb.competition_id
      and m.status='completed'
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
  ) completion on true
  where first_player.first_day is not null
)
select * from camps
union all
select * from tournaments;
$$;

create or replace function public.get_player_calendar_activity_v1(p_season integer, p_month smallint)
returns table(
  season integer,
  month smallint,
  day smallint,
  activity_type text,
  source text,
  note text,
  reference_id text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid;
  v_current_abs integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_season < 1 then raise exception 'Invalid season.'; end if;
  if p_month < 1 or p_month > 12 then raise exception 'Invalid month.'; end if;

  select id into v_player_id
  from public.players
  where owner_user_id=auth.uid() and player_type='human';

  if v_player_id is null then raise exception 'Player not found.'; end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_current_abs
  from public.get_current_game_day_internal_v1() d;

  return query
  with base_rows as (
    select
      a.season,
      a.month,
      a.day,
      a.activity_type,
      a.source,
      a.note,
      a.reference_id,
      case a.activity_type
        when 'injured' then 1
        when 'training_camp' then 4
        else 6
      end priority
    from public.player_daily_activity a
    where a.player_id=v_player_id
      and a.season=p_season
      and a.month=p_month
      and a.activity_type not in ('home','tournament','travel')
  ), travel_rows as (
    select
      gd.season,
      gd.month,
      gd.day,
      'travel'::text activity_type,
      case when l.status='completed' then 'travel_completed' else 'travel_plan' end::text source,
      format('Travel to %s',coalesce(nullif(l.destination_city,''),l.destination_country_code))::text note,
      l.id::text reference_id,
      3 priority
    from public.player_travel_legs l
    cross join lateral public.absolute_game_day_v1(l.departure_absolute_day) gd
    where l.player_id=v_player_id
      and l.status in ('planned','completed')
      and gd.season=p_season
      and gd.month=p_month
  ), confirmed_match_days as (
    select
      gd.season,
      gd.month,
      gd.day,
      'tournament'::text activity_type,
      case
        when bool_and(m.status='completed') or min(x.abs_day)<v_current_abs then 'tournament_completed'
        else 'tournament_confirmed'
      end::text source,
      format('%s · %s',ts.name,string_agg(distinct m.round_label,' + '))::text note,
      m.competition_id::text reference_id,
      2 priority
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    cross join lateral (
      select (
        ((ed.season_number-1)*366)+2+
        ((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
      )::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where (m.player1_id=v_player_id or m.player2_id=v_player_id)
      and m.status not in ('bye','cancelled')
      and gd.season=p_season
      and gd.month=p_month
    group by gd.season,gd.month,gd.day,ts.name,m.competition_id
  ), entry_context as (
    select
      te.competition_id,
      te.draw_type,
      ed.season_number,
      ts.name tournament_name,
      (
        select min(pm.round_number)
        from public.tournament_matches pm
        where pm.competition_id=te.competition_id
          and pm.draw_type=te.draw_type
          and (pm.player1_id=v_player_id or pm.player2_id=v_player_id)
          and pm.status not in ('bye','cancelled')
      ) first_playable_round
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    where te.player_id=v_player_id
      and te.entry_status='active'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
  ), predicted_round_days as (
    select distinct
      gd.season,
      gd.month,
      gd.day,
      'tournament'::text activity_type,
      'tournament_predicted'::text source,
      format('%s · Possible %s',ec.tournament_name,r.round_label)::text note,
      ec.competition_id::text reference_id,
      9 priority
    from entry_context ec
    join public.tournament_matches r
      on r.competition_id=ec.competition_id
      and r.draw_type=ec.draw_type
      and ec.first_playable_round is not null
      and r.round_number>ec.first_playable_round
      and r.status<>'cancelled'
    cross join lateral (
      select (
        ((ec.season_number-1)*366)+2+
        ((r.scheduled_season_week-1)*7)+(r.scheduled_day-1)
      )::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where x.abs_day>=v_current_abs
      and gd.season=p_season
      and gd.month=p_month
      and not exists(
        select 1
        from public.tournament_matches own_round
        where own_round.competition_id=ec.competition_id
          and own_round.draw_type=ec.draw_type
          and own_round.round_number=r.round_number
          and (own_round.player1_id=v_player_id or own_round.player2_id=v_player_id)
      )
  ), combined as (
    select * from base_rows
    union all
    select * from travel_rows
    union all
    select * from confirmed_match_days
    union all
    select * from predicted_round_days
  ), ranked as (
    select c.*,
      row_number() over(
        partition by c.season,c.month,c.day
        order by c.priority,c.activity_type,c.note nulls last
      ) rn
    from combined c
  )
  select r.season,r.month,r.day,r.activity_type,r.source,r.note,r.reference_id
  from ranked r
  where r.rn=1
  order by r.day;
end;
$$;

create or replace function public.refresh_player_future_first_match_schedule_v1(p_player_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  r record;
  v_count integer:=0;
  v_now integer;
begin
  select public.game_day_absolute_v1(season,month,day)
  into v_now
  from public.get_current_game_day_internal_v1();

  for r in
    with playable as (
      select
        m.id,
        m.competition_id,
        m.status,
        (
          ((ed.season_number-1)*366)+2+
          ((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
        )::integer abs_day,
        row_number() over(
          partition by m.competition_id
          order by m.scheduled_season_week,m.scheduled_day,coalesce(m.scheduled_start_minute,600),m.match_number
        ) rn
      from public.tournament_matches m
      join public.tournament_world_competitions wc on wc.id=m.competition_id
      join public.tournament_editions ed on ed.id=wc.tournament_edition_id
      where (m.player1_id=p_player_id or m.player2_id=p_player_id)
        and m.status not in ('bye','cancelled')
    )
    select id
    from playable
    where rn=1 and status='scheduled' and abs_day>=v_now
    order by abs_day
  loop
    perform public.accommodate_match_travel_v1(r.id);
    v_count:=v_count+1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.accommodate_match_travel_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  m public.tournament_matches%rowtype;
  rule public.tournament_match_scheduling_rules%rowtype;
  r1 jsonb;
  r2 jsonb;
  v_day integer;
  v_required integer;
  v_candidate integer;
  v_court integer;
  v_selected_start integer;
  v_selected_court integer;
  v_found boolean:=false;
  v_max integer;
  v_reason text:='standard';
  v_first1 boolean:=false;
  v_first2 boolean:=false;
begin
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null or m.status not in ('scheduled','in_progress') then
    return jsonb_build_object('status','not_applicable');
  end if;

  if m.player1_id is not null then
    select not exists(
      select 1 from public.tournament_matches x
      where x.competition_id=m.competition_id
        and (x.player1_id=m.player1_id or x.player2_id=m.player1_id)
        and x.status not in ('bye','cancelled')
        and (
          x.scheduled_season_week<m.scheduled_season_week
          or (x.scheduled_season_week=m.scheduled_season_week and x.scheduled_day<m.scheduled_day)
          or (x.scheduled_season_week=m.scheduled_season_week and x.scheduled_day=m.scheduled_day and coalesce(x.scheduled_start_minute,600)<coalesce(m.scheduled_start_minute,600))
        )
    ) into v_first1;
  end if;

  if m.player2_id is not null then
    select not exists(
      select 1 from public.tournament_matches x
      where x.competition_id=m.competition_id
        and (x.player1_id=m.player2_id or x.player2_id=m.player2_id)
        and x.status not in ('bye','cancelled')
        and (
          x.scheduled_season_week<m.scheduled_season_week
          or (x.scheduled_season_week=m.scheduled_season_week and x.scheduled_day<m.scheduled_day)
          or (x.scheduled_season_week=m.scheduled_season_week and x.scheduled_day=m.scheduled_day and coalesce(x.scheduled_start_minute,600)<coalesce(m.scheduled_start_minute,600))
        )
    ) into v_first2;
  end if;

  if not coalesce(v_first1,false) and not coalesce(v_first2,false) then
    return jsonb_build_object('status','not_applicable','reason','not_first_playable_match');
  end if;

  select r.* into rule
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  join public.tournament_match_scheduling_rules r on r.category_code=s.category_code
  where wc.id=m.competition_id;

  v_day:=public.tournament_match_absolute_day_v2(m.id);
  v_required:=coalesce(m.scheduled_start_minute,600);

  if v_first1 then
    r1:=public.player_ready_for_tournament_match_v1(m.player1_id,m.id);
    v_required:=greatest(v_required,((r1->>'ready_absolute_minute')::bigint-v_day::bigint*1440)::integer);
  end if;
  if v_first2 then
    r2:=public.player_ready_for_tournament_match_v1(m.player2_id,m.id);
    v_required:=greatest(v_required,((r2->>'ready_absolute_minute')::bigint-v_day::bigint*1440)::integer);
  end if;

  if v_required<=coalesce(m.scheduled_start_minute,600) then
    return jsonb_build_object('status','unchanged','start_minute',m.scheduled_start_minute,'court',m.court_number);
  end if;

  for v_candidate in select unnest(rule.regular_slot_minutes||rule.late_slot_minutes) loop
    if v_candidate<v_required then continue; end if;
    for v_court in 1..rule.court_count loop
      if not exists(
        select 1 from public.tournament_matches x
        where x.competition_id=m.competition_id
          and x.id<>m.id
          and x.scheduled_season_week=m.scheduled_season_week
          and x.scheduled_day=m.scheduled_day
          and x.scheduled_start_minute=v_candidate
          and x.court_number=v_court
          and x.status<>'cancelled'
      ) then
        v_selected_start:=v_candidate;
        v_selected_court:=v_court;
        v_found:=true;
        exit;
      end if;
    end loop;
    exit when v_found;
  end loop;

  if v_found then
    v_reason:='travel_accommodation';
    if (m.scheduled_start_minute,m.court_number,m.schedule_reason) is distinct from (v_selected_start::smallint,v_selected_court::smallint,v_reason) then
      update public.tournament_matches
      set scheduled_start_minute=v_selected_start,court_number=v_selected_court,schedule_reason=v_reason,updated_at=now()
      where id=m.id;
    end if;
  else
    select max(x) into v_max from unnest(rule.regular_slot_minutes||rule.late_slot_minutes) x;
    v_reason:='travel_risk';
    v_selected_start:=v_max;
    v_selected_court:=coalesce(m.court_number,1);
    if (m.scheduled_start_minute,m.court_number,m.schedule_reason) is distinct from (v_selected_start::smallint,v_selected_court::smallint,v_reason) then
      update public.tournament_matches
      set scheduled_start_minute=v_selected_start,court_number=v_selected_court,schedule_reason=v_reason,updated_at=now()
      where id=m.id;
    end if;
  end if;

  return jsonb_build_object('status',v_reason,'start_minute',v_selected_start,'court',v_selected_court,'required_minute',v_required);
end;
$$;

create or replace function public.get_training_dashboard_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid;
  d record;
  v_activity text;
  v_plan jsonb;
  v_skills jsonb;
  v_progress jsonb;
  v_today jsonb;
  v_recent jsonb;
  v_eligible boolean;
  v_reason text;
  v_abs integer;
  v_day_info record;
  v_week_start integer;
  v_weekday integer:=0;
  v_scheduled_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid();
  if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
  if v_activity='home' and public.player_has_confirmed_tournament_match_on_day_v1(v_player_id,v_abs) then v_activity:='tournament'; end if;
  v_eligible:=v_activity='home';
  v_reason:=case v_activity when 'home' then null when 'travel' then 'Travel day — regular training is unavailable.' when 'tournament' then 'Confirmed tournament match — regular training is unavailable.' when 'training_camp' then 'Training camp active — camp training replaces regular training.' when 'injured' then 'Player is injured — regular training is unavailable.' else 'Regular training is unavailable.' end;

  select * into v_day_info from public.absolute_game_day_v1(v_abs);
  if v_day_info.season_week between 1 and 52 then
    v_week_start:=public.training_camp_week_start_absolute_v1(d.season,v_day_info.season_week);
    v_weekday:=v_abs-v_week_start+1;
  end if;
  v_scheduled_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);

  select to_jsonb(x) into v_plan from (select training_type,focus_attribute,intensity,focus_share,is_active,updated_at from public.player_training_plans where player_id=v_player_id) x;
  if v_plan is null or v_plan='null'::jsonb then
    v_plan:=jsonb_build_object('training_type','day_off','focus_attribute',null,'intensity','standard','focus_share',0.85,'is_active',true);
  end if;

  select to_jsonb(x) into v_skills from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus from public.player_skills where player_id=v_player_id) x;
  select to_jsonb(x) into v_progress from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement from public.player_training_progress where player_id=v_player_id) x;
  if v_progress is null or v_progress='null'::jsonb then
    v_progress:=jsonb_build_object('serve',0,'forehand',0,'backhand',0,'return_skill',0,'volley',0,'slice',0,'drop_shot',0,'lob',0,'smash',0,'fitness',0,'stamina',0,'recovery',0,'movement',0);
  end if;

  select to_jsonb(x) into v_today from (
    select id,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,session_role,created_at
    from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day
  ) x;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.absolute_day desc, x.created_at desc),'[]'::jsonb) into v_recent from (
    select id,season,month,day,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,
           fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,
           session_role,created_at,
           public.game_day_absolute_v1(season,month,day) as absolute_day
    from public.player_training_sessions
    where player_id=v_player_id
      and public.game_day_absolute_v1(season,month,day) <= v_abs
    order by public.game_day_absolute_v1(season,month,day) desc, created_at desc
    limit 3
  ) x;

  return jsonb_build_object(
    'game_day',jsonb_build_object('season',d.season,'month',d.month,'day',d.day,'season_week',v_day_info.season_week,'weekday_in_training_week',v_weekday,'scheduled_role',v_scheduled_role),
    'activity_type',v_activity,'eligible',v_eligible,'block_reason',v_reason,'plan',v_plan,'skills',v_skills,'progress',v_progress,'today_session',coalesce(v_today,'null'::jsonb),'recent_sessions',v_recent,
    'rules',jsonb_build_object(
      'focus_share',0.85,'other_share',0.15,'travel_fatigue_only',true,'regular_training_states',jsonb_build_array('home'),'blocked_states',jsonb_build_array('travel','tournament','training_camp','injured'),'automatic_scheduler_enabled',false,
      'weekly_rhythm',jsonb_build_object('development_days',5,'active_recovery_days',1,'full_rest_days',1),
      'camp_weekly_rhythm',jsonb_build_object('development_days',6,'recovery_days',1),
      'attribute_development_multiplier',jsonb_build_object('1-59',1.00,'60-69',0.90,'70-79',0.75,'80-89',0.55,'90-94',0.35,'95-99',0.20),
      'age_modifier_used',false
    )
  );
end;
$$;

create or replace function public.get_training_week_planner_v1(p_week_offset smallint default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid;
  now_day record;
  v_now_abs integer;
  now_info record;
  v_season integer;
  v_week integer;
  v_start integer;
  v_base_plan public.player_training_plans%rowtype;
  v_days jsonb:='[]'::jsonb;
  v_abs integer;
  d record;
  a public.player_daily_activity%rowtype;
  wp public.player_weekly_training_plan_days%rowtype;
  sess public.player_training_sessions%rowtype;
  v_activity text;
  v_role text;
  v_plan_type text;
  v_plan_focus text;
  v_plan_intensity text;
  v_plan_source text;
  v_editable boolean;
  v_lock_reason text;
  v_confirmed_match boolean;
  v_names text[]:=array['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  i integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_week_offset < 0 or p_week_offset > 8 then raise exception 'Week offset must be between 0 and 8.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player_id is null then raise exception 'Player not found.'; end if;

  select * into now_day from public.get_current_game_day_internal_v1();
  v_now_abs:=public.game_day_absolute_v1(now_day.season,now_day.month,now_day.day);
  select * into now_info from public.absolute_game_day_v1(v_now_abs);
  v_season:=now_info.season;
  v_week:=greatest(1,now_info.season_week::integer)+p_week_offset;
  while v_week>52 loop v_week:=v_week-52; v_season:=v_season+1; end loop;
  v_start:=public.training_camp_week_start_absolute_v1(v_season,v_week::smallint);

  select * into v_base_plan from public.player_training_plans where player_id=v_player_id;
  if not found then
    v_base_plan.training_type:='day_off'; v_base_plan.focus_attribute:=null; v_base_plan.intensity:='standard'; v_base_plan.focus_share:=0.85;
  end if;

  for i in 0..6 loop
    v_abs:=v_start+i;
    select * into d from public.absolute_game_day_v1(v_abs);
    select * into a from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day;
    v_activity:=coalesce(a.activity_type,'home');
    v_confirmed_match:=public.player_has_confirmed_tournament_match_on_day_v1(v_player_id,v_abs);
    if v_activity='home' and v_confirmed_match then v_activity:='tournament'; end if;
    select * into sess from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day;
    select * into wp from public.player_weekly_training_plan_days where player_id=v_player_id and absolute_day=v_abs;

    if sess.id is not null then
      v_plan_type:=sess.training_type;
      v_plan_focus:=sess.focus_attribute;
      v_plan_intensity:=sess.intensity;
      v_plan_source:='processed_session';
      v_role:=coalesce(sess.session_role,'planned_training');
    elsif wp.player_id is not null then
      v_plan_type:=wp.training_type; v_plan_focus:=wp.focus_attribute; v_plan_intensity:=wp.intensity; v_plan_source:='weekly_plan';
      v_role:=case when wp.training_type='day_off' then 'user_day_off' else 'planned_training' end;
    else
      v_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);
      if v_role in ('active_recovery','full_rest') then
        v_plan_type:='day_off'; v_plan_focus:=null; v_plan_intensity:='standard'; v_plan_source:='automatic_recovery';
      else
        v_plan_type:=v_base_plan.training_type; v_plan_focus:=v_base_plan.focus_attribute; v_plan_intensity:=v_base_plan.intensity; v_plan_source:='default_plan';
      end if;
    end if;

    v_editable:=v_abs>=v_now_abs and v_activity='home' and sess.id is null;
    v_lock_reason:=case
      when v_abs<v_now_abs then 'Past day'
      when sess.id is not null then 'Already processed'
      when v_activity='travel' then coalesce(a.note,'Travel day')
      when v_activity='tournament' then 'Confirmed tournament match'
      when v_activity='training_camp' then coalesce(a.note,'Training Camp')
      when v_activity='injured' then coalesce(a.note,'Injury / recovery')
      else null end;

    v_days:=v_days||jsonb_build_array(jsonb_build_object(
      'absolute_day',v_abs,'weekday',i+1,'weekday_name',v_names[i+1],
      'season',d.season,'season_week',d.season_week,'month',d.month,'day',d.day,
      'activity_type',v_activity,
      'activity_source',case when v_confirmed_match and coalesce(a.activity_type,'home')='home' then 'tournament_confirmed' else a.source end,
      'activity_note',case when v_confirmed_match and coalesce(a.activity_type,'home')='home' then 'Confirmed tournament match' else a.note end,
      'activity_reference_id',a.reference_id,
      'editable',v_editable,'lock_reason',v_lock_reason,
      'plan_source',v_plan_source,'training_type',v_plan_type,'focus_attribute',v_plan_focus,'intensity',v_plan_intensity,'session_role',v_role,
      'processed',sess.id is not null,'session_id',sess.id
    ));

    a:=null; wp:=null; sess:=null;
  end loop;

  return jsonb_build_object(
    'season',v_season,'season_week',v_week,'week_offset',p_week_offset,'week_start_absolute_day',v_start,'week_end_absolute_day',v_start+6,
    'current_absolute_day',v_now_abs,'days',v_days,
    'rules',jsonb_build_object(
      'editable_activity','home','calendar_override_states',jsonb_build_array('travel','tournament','training_camp','injured'),
      'predicted_tournament_days_block_training',false,
      'confirmed_tournament_match_days_block_training',true,
      'daily_plan_overrides_default_rhythm',true,'automatic_daily_processor_compatible',true
    )
  );
end;
$$;

create or replace function public.set_training_week_day_v1(p_absolute_day integer, p_training_type text, p_focus_attribute text default null, p_intensity text default 'standard')
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player_id uuid;
  d record;
  now_day record;
  v_now_abs integer;
  v_activity text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player_id is null then raise exception 'Player not found.'; end if;

  if p_training_type='day_off' then p_focus_attribute:=null; end if;
  perform public.assert_regular_training_choice_v1(p_training_type,p_focus_attribute,p_intensity);

  select * into now_day from public.get_current_game_day_internal_v1();
  v_now_abs:=public.game_day_absolute_v1(now_day.season,now_day.month,now_day.day);
  if p_absolute_day < v_now_abs then raise exception 'Past training days cannot be changed.'; end if;
  if p_absolute_day > v_now_abs+55 then raise exception 'Training can currently be planned up to eight weeks ahead.'; end if;

  select * into d from public.absolute_game_day_v1(p_absolute_day);
  select coalesce((select activity_type from public.player_daily_activity
    where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
  if v_activity='home' and public.player_has_confirmed_tournament_match_on_day_v1(v_player_id,p_absolute_day) then v_activity:='tournament'; end if;

  if v_activity <> 'home' then
    raise exception 'This day is owned by % and cannot contain regular training.', replace(v_activity,'_',' ');
  end if;
  if exists(select 1 from public.player_training_sessions
    where player_id=v_player_id and season=d.season and month=d.month and day=d.day) then
    raise exception 'This day has already been processed and cannot be changed.';
  end if;

  insert into public.player_weekly_training_plan_days(player_id,absolute_day,training_type,focus_attribute,intensity,updated_at)
  values(v_player_id,p_absolute_day,p_training_type,p_focus_attribute,p_intensity,now())
  on conflict(player_id,absolute_day) do update set
    training_type=excluded.training_type,
    focus_attribute=excluded.focus_attribute,
    intensity=excluded.intensity,
    updated_at=now();

  return jsonb_build_object(
    'status','saved','absolute_day',p_absolute_day,'season',d.season,'month',d.month,'day',d.day,
    'training_type',p_training_type,'focus_attribute',p_focus_attribute,'intensity',p_intensity
  );
end;
$$;

create or replace function public.process_player_daily_activity_v1(p_player_id uuid, p_season integer, p_month smallint, p_day smallint, p_processed_by text default 'daily_engine')
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_activity text;
  v_row public.player_daily_activity%rowtype;
  v_abs integer;
  v_travel jsonb;
  v_hotel jsonb;
  v_tax jsonb;
begin
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);
  v_tax:=public.process_due_career_tax_v1(p_player_id,v_abs);
  v_travel:=public.process_due_travel_legs_v1(p_player_id,v_abs);
  v_hotel:=public.process_tournament_hotel_day_v1(p_player_id,v_abs);
  select * into v_row from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day for update;
  v_activity:=coalesce(v_row.activity_type,'home');
  if v_activity='home' and public.player_has_confirmed_tournament_match_on_day_v1(p_player_id,v_abs) then v_activity:='tournament'; end if;
  if v_activity='home' then return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel); end if;
  if v_activity='travel' then return jsonb_build_object('status','completed','activity_type','travel','tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'effect_summary',v_row.effect_summary); end if;
  if v_activity='training_camp' then return public.process_training_camp_day_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel); end if;
  return jsonb_build_object('status','delegated','activity_type',v_activity,'tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'reason',case v_activity when 'tournament' then 'Confirmed tournament match; the match engine owns this day and regular training is blocked.' when 'injured' then 'Injury/recovery engine owns this day; regular training is blocked.' else 'Regular training is blocked.' end);
end;
$$;

do $$
declare r record;
begin
  for r in
    select id from public.players
    where player_type='human' and owner_user_id is not null
  loop
    perform public.rebuild_player_travel_plan_v1(r.id);
    perform public.refresh_player_future_first_match_schedule_v1(r.id);
  end loop;
end $$;
