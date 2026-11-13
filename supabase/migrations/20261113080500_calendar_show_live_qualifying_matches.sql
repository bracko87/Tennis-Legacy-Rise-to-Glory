-- Mark active qualifying AND main-draw player matches as Live in
-- Season Calendar. Previously all non-completed matches were Confirmed.
-- This is read-only display logic: no changes to matches, results,
-- player commitments, entries, dates, finances or the running clock.
CREATE OR REPLACE FUNCTION public.get_player_calendar_activity_v1(p_season integer, p_month smallint)
 RETURNS TABLE(season integer, month smallint, day smallint, activity_type text, source text, note text, reference_id text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  ),
  travel_rows as (
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
  ),
  accepted_rows as (
    select
      gd.season,gd.month,gd.day,
      'tournament'::text,
      'tournament_accepted'::text,
      ts.name::text,
      te.competition_id::text
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    cross join lateral public.get_competition_window_v1(te.competition_id) cw
    cross join lateral generate_series(cw.start_absolute_day,cw.end_absolute_day) g(abs_day)
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where te.player_id=v_player_id
      and te.entry_status='active'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
      and gd.season=p_season
      and gd.month=p_month
      and not exists(
        select 1
        from public.tournament_matches m
        where m.competition_id=te.competition_id
          and (m.player1_id=v_player_id or m.player2_id=v_player_id)
          and m.status not in ('cancelled')
      )
  ),
  confirmed_rows as (
    select distinct
      gd.season,gd.month,gd.day,
      'tournament'::text,
      case
        when m.status='in_progress' then 'tournament_live'
        when m.status in ('completed','walkover') then 'tournament_completed'
        else 'tournament_confirmed'
      end::text,
      ts.name::text,
      m.competition_id::text
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    cross join lateral public.absolute_game_day_v1(
      ((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1)
    ) gd
    where (m.player1_id=v_player_id or m.player2_id=v_player_id)
      and m.status not in ('bye','cancelled')
      and gd.season=p_season
      and gd.month=p_month
  ),
  active_entries as (
    select te.competition_id,te.draw_type,ed.season_number,ts.name
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    where te.player_id=v_player_id
      and te.entry_status='active'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
  ),
  current_round as (
    select
      ae.competition_id,
      ae.draw_type,
      coalesce(max(m.round_number),0)::integer as round_number
    from active_entries ae
    left join public.tournament_matches m
      on m.competition_id=ae.competition_id
     and m.draw_type=ae.draw_type
     and (m.player1_id=v_player_id or m.player2_id=v_player_id)
     and m.status<>'cancelled'
    group by ae.competition_id,ae.draw_type
  ),
  predicted_round_days as (
    select distinct
      ae.competition_id,
      ae.name,
      m.scheduled_season_week,
      m.scheduled_day
    from active_entries ae
    join current_round cr
      on cr.competition_id=ae.competition_id
     and cr.draw_type=ae.draw_type
    join public.tournament_matches m
      on m.competition_id=ae.competition_id
     and m.draw_type=ae.draw_type
     and m.round_number>cr.round_number
     and m.status<>'cancelled'
    where not exists(
      select 1
      from public.tournament_matches actual
      where actual.competition_id=ae.competition_id
        and (actual.player1_id=v_player_id or actual.player2_id=v_player_id)
        and actual.status not in ('bye','cancelled')
        and actual.scheduled_season_week=m.scheduled_season_week
        and actual.scheduled_day=m.scheduled_day
    )
  ),
  predicted_rows as (
    select
      gd.season,gd.month,gd.day,
      'tournament'::text,
      'tournament_predicted'::text,
      prd.name::text,
      prd.competition_id::text
    from predicted_round_days prd
    join public.tournament_world_competitions wc on wc.id=prd.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    cross join lateral public.absolute_game_day_v1(
      ((ed.season_number-1)*366)+2+((prd.scheduled_season_week-1)*7)+(prd.scheduled_day-1)
    ) gd
    where gd.season=p_season
      and gd.month=p_month
  ),
  national_rows as (
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
  ),
  combined as (
    select * from base_rows
    union all select * from travel_rows
    union all select * from accepted_rows
    union all select * from confirmed_rows
    union all select * from predicted_rows
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
    case c.source
      when 'tournament_live' then 0
      when 'tournament_completed' then 1
      when 'tournament_confirmed' then 2
      when 'tournament_accepted' then 3
      when 'tournament_predicted' then 4
      else 5
    end,
    c.note nulls last;
end;
$function$
;
