-- Provisional accepted tournaments become bookable travel commitments
-- in the CURRENT season even before first-round draw publication.
-- No testing-only future Season 2 commitments are activated.
CREATE OR REPLACE FUNCTION public.player_commitment_locations_v1(p_player_id uuid)
 RETURNS TABLE(commitment_type text, reference_id text, start_absolute_day integer, end_absolute_day integer, city text, country_code text, continent text, latitude double precision, longitude double precision)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
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
    coalesce(first_player.first_day,window_dates.start_absolute_day)::integer start_absolute_day,
    case
      when tb.entry_status='eliminated'
        then coalesce(elimination.elimination_absolute_day,completion.last_completed_absolute_day,first_player.first_day)::integer
      when tb.entry_status='champion'
        then coalesce(completion.last_completed_absolute_day,schedule_end.last_possible_day,first_player.first_day)::integer
      else coalesce(schedule_end.last_possible_day,first_player.first_day,window_dates.end_absolute_day)::integer
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
  left join lateral public.get_competition_window_v1(tb.competition_id) window_dates on true
  where first_player.first_day is not null
    or (tb.entry_status='active'
      and window_dates.start_absolute_day is not null
      and tb.season_number=(select season from public.get_current_game_day_internal_v1()))
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
$function$
;
CREATE OR REPLACE FUNCTION public.process_tournament_hotel_day_v1(p_player_id uuid, p_absolute_day integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c record; v_result jsonb:='{}'::jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id and player_type='human' and owner_user_id is not null) then
    return jsonb_build_object('status','skipped');
  end if;
  select * into c from public.player_commitment_locations_v1(p_player_id)
  where commitment_type='tournament' and p_absolute_day between start_absolute_day and end_absolute_day
  order by start_absolute_day limit 1;
  if c.reference_id is null then
    -- A direct flight may arrive several days before the draw starts.
    -- Charge these nights exactly once by the existing idempotent hotel ledger.
    select l.destination_reference_id into c
    from public.player_travel_legs l
    join public.player_tournament_transfer_preferences pref
      on pref.player_id=l.player_id and pref.competition_id::text=l.destination_reference_id
      and pref.source_competition_id::text=l.source_reference_id and pref.route_choice='direct'
    join lateral public.player_commitment_locations_v1(p_player_id) target
      on target.commitment_type='tournament'
      and target.reference_id=l.destination_reference_id
    where l.player_id=p_player_id and l.status='completed'
      and l.source_location_type='tournament' and l.destination_location_type='tournament'
      and l.arrival_absolute_day<=p_absolute_day
      and p_absolute_day<target.start_absolute_day
      and not exists (
        select 1 from public.player_travel_legs away
        where away.player_id=p_player_id and away.status='completed'
          and away.source_reference_id=l.destination_reference_id
          and away.departure_absolute_day<=p_absolute_day
          and away.arrival_absolute_day>=l.arrival_absolute_day
      )
    order by l.arrival_absolute_day desc limit 1;
    if c.destination_reference_id is null then
      return jsonb_build_object('status','no_tournament');
    end if;
    v_result:=public.post_tournament_hotel_night_v1(p_player_id,c.destination_reference_id::uuid,p_absolute_day);
    return v_result;
  end if;
  -- A provisional accepted event without a published match must not charge
  -- accommodation unless an actual inbound flight has completed.
  if not exists(
    select 1 from public.tournament_matches m
    where m.competition_id=c.reference_id::uuid
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
  ) and not exists(
    select 1 from public.player_travel_legs l
    where l.player_id=p_player_id and l.status='completed'
      and l.destination_reference_id=c.reference_id
      and l.arrival_absolute_day<=p_absolute_day
  ) then
    return jsonb_build_object('status','no_arrival_yet');
  end if;
  v_result:=public.post_tournament_hotel_night_v1(p_player_id,c.reference_id::uuid,p_absolute_day);
  return v_result;
end;
$function$
;
