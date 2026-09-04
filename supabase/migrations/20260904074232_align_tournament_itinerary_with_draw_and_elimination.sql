-- Tournament travel should match the actual required draw rather than the
-- Monday-Sunday calendar shell. Once the human player is eliminated, rebuild
-- the itinerary so the return leg is the following day.

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
set search_path=public
as $$
  with camps as (
    select
      'training_camp'::text commitment_type,
      b.id::text reference_id,
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
  ),
  tournament_base as (
    select
      e.competition_id,
      e.draw_type,
      te.season_number,
      ts.city,
      ts.country_code,
      public.country_continent_v1(ts.country_code) continent,
      ts.latitude,
      ts.longitude,
      (((te.season_number-1)*366)+2+((min(ss.season_week)-1)*7))::integer
        week_start_absolute_day,
      (((te.season_number-1)*366)+2+((max(ss.season_week)-1)*7)+6)::integer
        week_end_absolute_day
    from public.tournament_entries e
    join public.tournament_world_competitions wc on wc.id=e.competition_id
    join public.tournament_editions te on te.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=te.tournament_series_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
    where e.player_id=p_player_id
      and e.entry_status in ('active','eliminated')
      and wc.status<>'canceled'
      and te.status<>'canceled'
    group by e.competition_id,e.draw_type,te.season_number,
             ts.city,ts.country_code,ts.latitude,ts.longitude
  ),
  tournaments as (
    select
      'tournament'::text commitment_type,
      tb.competition_id::text reference_id,
      coalesce(draw_start.draw_start_absolute_day,tb.week_start_absolute_day)::integer
        start_absolute_day,
      coalesce(elimination.elimination_absolute_day,tb.week_end_absolute_day)::integer
        end_absolute_day,
      tb.city,
      tb.country_code,
      tb.continent,
      tb.latitude,
      tb.longitude
    from tournament_base tb
    left join lateral (
      select min(
        ((tb.season_number-1)*366)+2+
        ((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
      )::integer draw_start_absolute_day
      from public.tournament_matches m
      where m.competition_id=tb.competition_id
        and m.draw_type=tb.draw_type
    ) draw_start on true
    left join lateral (
      select max(
        ((tb.season_number-1)*366)+2+
        ((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
      )::integer elimination_absolute_day
      from public.tournament_matches m
      where m.competition_id=tb.competition_id
        and m.status='completed'
        and (m.player1_id=p_player_id or m.player2_id=p_player_id)
        and m.winner_id is not null
        and m.winner_id<>p_player_id
    ) elimination on true
  )
  select * from camps
  union all
  select * from tournaments;
$$;

create or replace function public.sync_travel_plan_from_tournament_match_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_player uuid;
begin
  for v_player in
    select distinct x.player_id
    from (
      select case when tg_op='DELETE' then old.player1_id else new.player1_id end player_id
      union all
      select case when tg_op='DELETE' then old.player2_id else new.player2_id end
      union all
      select case when tg_op='UPDATE' then old.player1_id else null end
      union all
      select case when tg_op='UPDATE' then old.player2_id else null end
    ) x
    join public.players p on p.id=x.player_id
    where x.player_id is not null
      and p.player_type='human'
      and p.owner_user_id is not null
  loop
    perform public.rebuild_player_travel_plan_v1(v_player);
  end loop;

  return case when tg_op='DELETE' then old else new end;
end;
$$;

drop trigger if exists tournament_match_travel_plan on public.tournament_matches;
create trigger tournament_match_travel_plan
after insert or delete or update of
  status,winner_id,player1_id,player2_id,scheduled_season_week,scheduled_day
on public.tournament_matches
for each row execute function public.sync_travel_plan_from_tournament_match_v1();

create or replace function public.sync_human_travel_plan_from_tournament_entry_v1()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_player uuid:=case when tg_op='DELETE' then old.player_id else new.player_id end;
begin
  if exists(
    select 1
    from public.players p
    where p.id=v_player
      and p.player_type='human'
      and p.owner_user_id is not null
  ) then
    perform public.rebuild_player_travel_plan_v1(v_player);
  end if;

  return case when tg_op='DELETE' then old else new end;
end;
$$;

drop trigger if exists tournament_entry_travel_plan on public.tournament_entries;
create trigger tournament_entry_travel_plan
after insert or delete or update of entry_status,competition_id,draw_type
on public.tournament_entries
for each row execute function public.sync_human_travel_plan_from_tournament_entry_v1();

-- Rebuild only future unprocessed itineraries; current game time is untouched.
select public.rebuild_player_travel_plan_v1(p.id)
from public.players p
where p.player_type='human' and p.owner_user_id is not null;
