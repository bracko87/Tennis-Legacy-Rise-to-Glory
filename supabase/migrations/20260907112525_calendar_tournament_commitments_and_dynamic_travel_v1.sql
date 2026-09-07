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
    coalesce(first_player.first_day,draw_start.draw_start_absolute_day,tb.phase_start_absolute_day)::integer start_absolute_day,
    case
      when tb.entry_status='eliminated' then coalesce(elimination.elimination_absolute_day,tb.phase_end_absolute_day)::integer
      when tb.entry_status='champion' then coalesce(completion.last_completed_absolute_day,tb.phase_end_absolute_day)::integer
      else tb.phase_end_absolute_day
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
    select min(
      ((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
    )::integer draw_start_absolute_day
    from public.tournament_matches m
    where m.competition_id=tb.competition_id
      and m.draw_type=tb.draw_type
  ) draw_start on true
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
)
select * from camps
union all
select * from tournaments;
$$;

create or replace function public.get_player_calendar_activity_v1(p_season integer,p_month smallint)
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
      a.season,
      a.month,
      a.day,
      a.activity_type,
      a.source,
      a.note,
      a.reference_id
    from public.player_daily_activity a
    where a.player_id=v_player_id
      and a.season=p_season
      and a.month=p_month
      and not (a.activity_type='travel' and a.source='travel_plan')
      and a.activity_type<>'tournament'
  ), travel_rows as (
    select
      gd.season,
      gd.month,
      gd.day,
      'travel'::text activity_type,
      case when l.status='completed' then 'travel_completed' else 'travel_plan' end::text source,
      format('Travel to %s',coalesce(nullif(l.destination_city,''),l.destination_country_code))::text note,
      l.id::text reference_id
    from public.player_travel_legs l
    cross join lateral generate_series(
      l.departure_absolute_day,
      greatest(l.departure_absolute_day,l.arrival_absolute_day)
    ) as g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where l.player_id=v_player_id
      and l.status in ('planned','completed')
      and gd.season=p_season
      and gd.month=p_month
  ), tournament_rows as (
    select
      gd.season,
      gd.month,
      gd.day,
      'tournament'::text activity_type,
      case when te.entry_status in ('eliminated','champion') then 'tournament_completed' else 'tournament_plan' end::text source,
      ts.name::text note,
      c.reference_id::text reference_id
    from public.player_commitment_locations_v1(v_player_id) c
    join public.tournament_entries te
      on te.player_id=v_player_id
      and te.competition_id=c.reference_id::uuid
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    cross join lateral generate_series(c.start_absolute_day,c.end_absolute_day) as g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where c.commitment_type='tournament'
      and gd.season=p_season
      and gd.month=p_month
  ), combined as (
    select * from base_rows
    union all
    select * from travel_rows
    union all
    select * from tournament_rows
  )
  select c.season,c.month,c.day,c.activity_type,c.source,c.note,c.reference_id
  from combined c
  order by
    c.day,
    case c.activity_type
      when 'tournament' then 1
      when 'travel' then 2
      when 'training_camp' then 3
      when 'injured' then 4
      else 5
    end,
    c.note nulls last;
end;
$$;
