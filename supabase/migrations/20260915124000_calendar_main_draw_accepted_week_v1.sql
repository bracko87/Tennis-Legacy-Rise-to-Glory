create or replace function public.get_player_calendar_activity_v1(p_season integer, p_month smallint)
returns table(season integer, month smallint, day smallint, activity_type text, source text, note text, reference_id text)
language plpgsql
stable security definer
set search_path to 'public'
as $function$
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
  ), accepted_main_draw_context as (
    select
      te.competition_id,
      ed.season_number,
      ts.name tournament_name,
      slot.season_week
    from public.tournament_entries te
    join public.tournament_world_competitions wc on wc.id=te.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=ed.tournament_series_id
    join lateral (
      select s.season_week
      from public.tournament_schedule_slots s
      where s.tournament_edition_id=ed.id
        and s.phase in ('main_draw','full')
      order by case when s.phase='main_draw' then 0 else 1 end, s.slot_order
      limit 1
    ) slot on true
    where te.player_id=v_player_id
      and te.entry_status='active'
      and te.draw_type='main_draw'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
      and not exists (
        select 1
        from public.tournament_matches own_match
        where own_match.competition_id=te.competition_id
          and own_match.draw_type='main_draw'
          and (own_match.player1_id=v_player_id or own_match.player2_id=v_player_id)
          and own_match.status not in ('bye','cancelled')
      )
  ), accepted_main_draw_days as (
    select
      gd.season,
      gd.month,
      gd.day,
      'tournament'::text activity_type,
      'tournament_accepted'::text source,
      amdc.tournament_name::text note,
      amdc.competition_id::text reference_id,
      8 priority
    from accepted_main_draw_context amdc
    cross join generate_series(1,7) as tournament_day(day_number)
    cross join lateral (
      select (
        ((amdc.season_number-1)*366)+2+
        ((amdc.season_week-1)*7)+(tournament_day.day_number-1)
      )::integer abs_day
    ) x
    cross join lateral public.absolute_game_day_v1(x.abs_day) gd
    where x.abs_day>=v_current_abs
      and gd.season=p_season
      and gd.month=p_month
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
    select * from accepted_main_draw_days
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
$function$;
