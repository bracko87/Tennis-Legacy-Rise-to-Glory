create or replace function public.player_commitment_locations_v1(p_player_id uuid)
returns table(commitment_type text,reference_id text,start_absolute_day integer,end_absolute_day integer,city text,country_code text,continent text,latitude double precision,longitude double precision)
language sql stable set search_path='public' as $$
with camps as (
  select 'training_camp'::text,b.id::text,b.start_absolute_day,b.end_absolute_day,l.city,l.country_code,l.continent,l.latitude,l.longitude
  from public.player_training_camp_bookings b join public.training_camp_programs p on p.id=b.program_id join public.training_camp_locations l on l.id=p.location_id
  where b.player_id=p_player_id and b.status in ('booked','active','completed')
), tournament_base as (
  select e.competition_id,e.draw_type,e.entry_status,te.season_number,ts.city,ts.country_code,public.country_continent_v1(ts.country_code) continent,ts.latitude,ts.longitude,
    (((te.season_number-1)*366)+2+((min(ss.season_week)-1)*7))::integer week_start_absolute_day,
    (((te.season_number-1)*366)+2+((max(ss.season_week)-1)*7)+6)::integer week_end_absolute_day
  from public.tournament_entries e join public.tournament_world_competitions wc on wc.id=e.competition_id join public.tournament_editions te on te.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=te.tournament_series_id join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
  where e.player_id=p_player_id and e.entry_status in ('active','eliminated') and wc.status<>'canceled' and te.status<>'canceled'
  group by e.competition_id,e.draw_type,e.entry_status,te.season_number,ts.city,ts.country_code,ts.latitude,ts.longitude
), tournaments as (
 select 'tournament'::text,tb.competition_id::text,
   coalesce(first_player.first_day,draw_start.draw_start_absolute_day,tb.week_start_absolute_day)::integer start_absolute_day,
   case when tb.entry_status='eliminated' then coalesce(elimination.elimination_absolute_day,tb.week_end_absolute_day)::integer else tb.week_end_absolute_day end end_absolute_day,
   tb.city,tb.country_code,tb.continent,tb.latitude,tb.longitude
 from tournament_base tb
 left join lateral (
   select min(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer first_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.status not in ('bye','cancelled')
 ) first_player on true
 left join lateral (
   select min(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer draw_start_absolute_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and m.draw_type=tb.draw_type
 ) draw_start on true
 left join lateral (
   select max(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer elimination_absolute_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and m.status='completed' and (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.winner_id is not null and m.winner_id<>p_player_id
 ) elimination on true
)
select * from camps union all select * from tournaments;
$$;
