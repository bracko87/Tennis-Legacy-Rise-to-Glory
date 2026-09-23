
create or replace function public.national_association_for_player_window_v1(
  p_player_id uuid,
  p_window_id uuid
)
returns uuid
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select c.association_id
  from public.national_team_callups c
  join public.national_team_fixtures f on f.id=c.fixture_id
  where c.player_id=p_player_id
    and c.status='accepted'
    and f.window_id=p_window_id
  order by c.created_at
  limit 1;
$$;

create or replace function public.reimburse_national_team_travel_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  l public.player_travel_legs%rowtype;
  v_window uuid;
  v_assoc uuid;
begin
  if new.source_type<>'travel_leg' or new.amount>=0 then return new; end if;

  begin
    select * into l
    from public.player_travel_legs
    where id=new.source_id::uuid;
  exception when invalid_text_representation then
    return new;
  end;

  if l.id is null then return new; end if;
  if l.destination_location_type<>'national_team'
     and l.source_location_type<>'national_team' then
    return new;
  end if;

  begin
    v_window:=case
      when l.destination_location_type='national_team'
        then l.destination_reference_id::uuid
      else l.source_reference_id::uuid
    end;
  exception when invalid_text_representation then
    return new;
  end;

  v_assoc:=public.national_association_for_player_window_v1(l.player_id,v_window);
  if v_assoc is null then return new; end if;

  perform public.post_national_association_finance_transaction_v1(
    v_assoc,
    new.amount,
    'travel',
    'National-team player travel',
    'travel_leg',
    l.id::text,
    'national-travel:'||l.id::text,
    jsonb_build_object(
      'player_id',l.player_id,
      'window_id',v_window,
      'distance_km',l.distance_km,
      'travel_class',l.travel_class,
      'source_city',l.source_city,
      'destination_city',l.destination_city
    ),
    l.departure_absolute_day
  );

  perform public.post_career_finance_transaction_v1(
    l.player_id,
    abs(new.amount),
    'national_team',
    'travel_reimbursement',
    'National association travel reimbursement',
    'national_travel_reimbursement',
    l.id::text,
    'national-travel-reimbursement:'||l.id::text,
    jsonb_build_object(
      'association_id',v_assoc,
      'window_id',v_window,
      'travel_leg_id',l.id,
      'taxable',false
    ),
    false,
    l.departure_absolute_day
  );

  return new;
end;
$$;

drop trigger if exists trg_reimburse_national_team_travel_v1 on public.career_finance_transactions;
create trigger trg_reimburse_national_team_travel_v1
after insert on public.career_finance_transactions
for each row
execute function public.reimburse_national_team_travel_v1();

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
    ts.longitude
  from public.tournament_entries e
  join public.tournament_world_competitions wc on wc.id=e.competition_id
  join public.tournament_editions te on te.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=te.tournament_series_id
  where e.player_id=p_player_id
    and e.entry_status in ('active','eliminated','champion')
    and wc.status<>'canceled'
    and te.status<>'canceled'
    and not public.is_national_team_engine_competition_v1(e.competition_id)
), tournaments as (
  select
    'tournament'::text,
    tb.competition_id::text,
    first_player.first_day::integer start_absolute_day,
    case
      when tb.entry_status='eliminated'
        then coalesce(elimination.elimination_absolute_day,completion.last_completed_absolute_day,first_player.first_day)::integer
      when tb.entry_status='champion'
        then coalesce(completion.last_completed_absolute_day,schedule_end.last_possible_day,first_player.first_day)::integer
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
), national as (
  select distinct on(c.source_id)
    'national_team'::text,
    c.source_id::text,
    c.starts_absolute_day,
    c.ends_absolute_day,
    f.host_city,
    f.host_country_code,
    public.country_continent_v1(f.host_country_code),
    f.host_latitude,
    f.host_longitude
  from public.player_calendar_commitments c
  join public.national_team_fixtures f
    on f.window_id=c.source_id
   and exists(
     select 1
     from public.national_team_callups nc
     where nc.fixture_id=f.id
       and nc.player_id=p_player_id
       and nc.status='accepted'
   )
  where c.player_id=p_player_id
    and c.source_type='national_team'
    and c.status in ('committed','completed')
  order by c.source_id,f.tie_start_absolute_day
)
select * from camps
union all
select * from tournaments
union all
select * from national;
$$;

create or replace function public.get_player_calendar_activity_v1(
  p_season integer,
  p_month smallint
)
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
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_season < 1 then raise exception 'Invalid season.'; end if;
  if p_month < 1 or p_month > 12 then raise exception 'Invalid month.'; end if;

  select id into v_player_id
  from public.players
  where owner_user_id=auth.uid() and player_type='human';

  if v_player_id is null then raise exception 'Player not found.'; end if;

  return query
  with base_rows as (
    select
      a.season,a.month,a.day,a.activity_type,a.source,a.note,a.reference_id
    from public.player_daily_activity a
    where a.player_id=v_player_id
      and a.season=p_season
      and a.month=p_month
      and not (a.activity_type='travel' and a.source='travel_plan')
      and a.activity_type<>'tournament'
  ), travel_rows as (
    select
      gd.season,gd.month,gd.day,
      'travel'::text,
      case when l.status='completed' then 'travel_completed' else 'travel_plan' end::text,
      format('Travel to %s',coalesce(nullif(l.destination_city,''),l.destination_country_code))::text,
      l.id::text
    from public.player_travel_legs l
    cross join lateral generate_series(
      l.departure_absolute_day,
      greatest(l.departure_absolute_day,l.arrival_absolute_day)
    ) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where l.player_id=v_player_id
      and l.status in ('planned','completed')
      and gd.season=p_season
      and gd.month=p_month
  ), tournament_rows as (
    select
      gd.season,gd.month,gd.day,
      'tournament'::text,
      case when te.entry_status in ('eliminated','champion') then 'tournament_completed' else 'tournament_plan' end::text,
      ts.name::text,
      c.reference_id::text
    from public.player_commitment_locations_v1(v_player_id) c
    join public.tournament_entries te
      on te.player_id=v_player_id
      and te.competition_id=c.reference_id::uuid
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    cross join lateral generate_series(c.start_absolute_day,c.end_absolute_day) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where c.commitment_type='tournament'
      and gd.season=p_season
      and gd.month=p_month
  ), national_rows as (
    select
      gd.season,gd.month,gd.day,
      'national_team'::text,
      'national_team_committed'::text,
      coalesce((
        select format('National Team · vs %s · %s',opp.name,f.host_city)
        from public.national_team_fixtures f
        join public.national_associations mya
          on mya.id in (f.home_association_id,f.away_association_id)
         and mya.country_code=(select country_code from public.players where id=v_player_id)
         and mya.world=(select world from public.players where id=v_player_id)
        join public.national_associations opp
          on opp.id=case
            when f.home_association_id=mya.id then f.away_association_id
            else f.home_association_id
          end
        where f.window_id=c.reference_id::uuid
          and exists(
            select 1
            from public.national_team_callups nc
            where nc.fixture_id=f.id
              and nc.player_id=v_player_id
              and nc.status='accepted'
          )
        order by f.tie_start_absolute_day
        limit 1
      ),'National Team')::text,
      c.reference_id::text
    from public.player_commitment_locations_v1(v_player_id) c
    cross join lateral generate_series(c.start_absolute_day,c.end_absolute_day) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where c.commitment_type='national_team'
      and gd.season=p_season
      and gd.month=p_month
  ), combined as (
    select * from base_rows
    union all select * from travel_rows
    union all select * from tournament_rows
    union all select * from national_rows
  )
  select c.season,c.month,c.day,c.activity_type,c.source,c.note,c.reference_id
  from combined c
  order by
    c.day,
    case c.activity_type
      when 'national_team' then 1
      when 'tournament' then 2
      when 'travel' then 3
      when 'training_camp' then 4
      when 'injured' then 5
      else 6
    end,
    c.note nulls last;
end;
$$;

create or replace function public.apply_late_tournament_entry_v1(
  p_competition_id uuid,
  p_accept_qualification boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player public.players%rowtype;
  v_tl jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_world text;
  v_season integer;
  v_week smallint;
  v_direct integer;
  v_qcap integer;
  v_main integer;
  v_q integer;
  v_rank integer;
  v_points integer;
  v_draw text;
  v_availability jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=auth.uid()
  limit 1;

  if v_player.id is null then raise exception 'Player profile required.'; end if;

  v_tl:=public.get_tournament_entry_timeline_v1(p_competition_id);
  v_week:=(v_tl->>'target_season_week')::smallint;

  if v_now<(v_tl->>'late_open_game_second')::bigint
     or v_now>=(v_tl->>'late_close_game_second')::bigint then
    raise exception 'Final Vacancy Entry is not open for this tournament.';
  end if;

  if exists(
    select 1
    from public.tournament_competition_entry_cycles
    where competition_id=p_competition_id
      and field_locked_at is not null
  ) then
    raise exception 'Tournament field is already locked.';
  end if;

  select
    wc.world,e.season_number,
    c.main_draw_capacity-c.default_qualifier_slots,
    c.qualifying_capacity_max
  into v_world,v_season,v_direct,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  join public.tournament_categories c on c.code=s.category_code
  where wc.id=p_competition_id;

  if v_world<>v_player.world then
    raise exception 'This tournament belongs to a different competitive world.';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(
      format('tournament-entry:%s:%s:%s',v_player.id,v_season,v_week),
      0
    )
  );

  v_availability:=public.check_player_competition_availability_v1(
    v_player.id,p_competition_id
  );

  if not coalesce((v_availability->>'available')::boolean,false) then
    raise exception 'Tournament commitment conflict: %',
      coalesce(v_availability->>'blocking_tournament',v_availability->>'reason','unavailable');
  end if;

  if exists(
    select 1
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    where te.player_id=v_player.id
      and te.entry_status='active'
      and e.season_number=v_season
      and public.tournament_application_target_week_v1(wc.id)=v_week
  ) then
    raise exception 'You are already committed to a tournament in this tournament week.';
  end if;

  update public.tournament_applications a
  set status='withdrawn',
      decision_reason='final_vacancy_replaced_pending',
      decided_at=now(),
      updated_at=now()
  where a.player_id=v_player.id
    and a.target_season_week=v_week
    and a.status='applied'
    and a.competition_id<>p_competition_id
    and exists(
      select 1
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      where wc.id=a.competition_id
        and e.season_number=v_season
    );

  select count(*) into v_main
  from public.tournament_entries
  where competition_id=p_competition_id
    and draw_type='main_draw'
    and entry_status='active';

  select count(*) into v_q
  from public.tournament_entries
  where competition_id=p_competition_id
    and draw_type='qualification'
    and entry_status='active';

  v_rank:=public.get_player_world_rank_position_v1(v_player.id);
  select coalesce(ranking_points,0) into v_points
  from public.player_rankings
  where player_id=v_player.id;

  if v_main<v_direct then
    v_draw:='main_draw';
  elsif coalesce(p_accept_qualification,true) and v_q<v_qcap then
    v_draw:='qualification';
  else
    raise exception 'No suitable Final Vacancy place is available.';
  end if;

  insert into public.tournament_entries(
    competition_id,player_id,world,draw_type,entry_status,entry_source,ranking_position_snapshot
  )
  values(
    p_competition_id,v_player.id,v_world,v_draw,'active','application',v_rank
  )
  on conflict(competition_id,player_id) do update
  set draw_type=excluded.draw_type,
      entry_status='active',
      entry_source='application',
      ranking_position_snapshot=excluded.ranking_position_snapshot,
      updated_at=now();

  insert into public.tournament_applications(
    competition_id,player_id,owner_user_id,world,status,
    ranking_position_snapshot,ranking_points_snapshot,priority,
    accept_qualification,application_source,target_season_week,
    decision_reason,decided_at,created_at,updated_at
  )
  values(
    p_competition_id,v_player.id,auth.uid(),v_world,
    case when v_draw='main_draw' then 'accepted_main_draw' else 'accepted_qualification' end,
    v_rank,coalesce(v_points,0),null,coalesce(p_accept_qualification,true),
    'human_late',v_week,'final_vacancy',now(),now(),now()
  )
  on conflict(competition_id,player_id) do update
  set status=excluded.status,
      ranking_position_snapshot=excluded.ranking_position_snapshot,
      ranking_points_snapshot=excluded.ranking_points_snapshot,
      priority=null,
      accept_qualification=excluded.accept_qualification,
      application_source='human_late',
      target_season_week=excluded.target_season_week,
      decision_reason='final_vacancy',
      decided_at=now(),
      updated_at=now();

  return jsonb_build_object(
    'status','accepted',
    'draw_type',v_draw,
    'ranking_position',v_rank
  );
end;
$$;

create or replace function public.process_current_game_day_for_all_players_internal_v1()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  d record;
  p record;
  v_count integer:=0;
begin
  perform public.process_national_association_lifecycle_v1();
  perform public.process_national_team_deadlines_v1();
  perform public.process_national_team_season_standings_v1();

  select * into d from public.get_current_game_day_internal_v1();

  for p in select id from public.players loop
    perform public.process_player_daily_activity_v1(
      p.id,d.season,d.month,d.day,'daily_engine'
    );
    v_count:=v_count+1;
  end loop;

  return v_count;
end;
$$;

revoke execute on function public.national_association_for_player_window_v1(uuid,uuid) from anon,authenticated;
revoke execute on function public.reimburse_national_team_travel_v1() from anon,authenticated;
