create or replace function public.guard_national_callup_acceptance_plans_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  v_block record;
begin
  if new.status <> 'accepted' or old.status = 'accepted' then
    return new;
  end if;

  select * into f
  from public.national_team_fixtures
  where id = new.fixture_id;

  if not found then
    raise exception 'National-team fixture not found.';
  end if;

  select * into w
  from public.national_team_windows
  where id = f.window_id;

  select
    a.competition_id,
    s.name,
    s.city
  into v_block
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id = a.competition_id
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  join public.tournament_series s on s.id = e.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) cw
  where a.player_id = new.player_id
    and a.status = 'applied'
    and cw.start_absolute_day <= w.end_absolute_day
    and cw.end_absolute_day >= w.start_absolute_day
    and not public.is_national_team_engine_competition_v1(a.competition_id)
  order by cw.start_absolute_day, s.name
  limit 1;

  if v_block.competition_id is not null then
    raise exception 'Resolve the overlapping tournament application for % before accepting this national-team call-up.',
      v_block.name;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_national_callup_acceptance_plans_v1
  on public.national_team_callups;

create trigger trg_guard_national_callup_acceptance_plans_v1
before update of status
on public.national_team_callups
for each row
execute function public.guard_national_callup_acceptance_plans_v1();

revoke execute on function public.guard_national_callup_acceptance_plans_v1()
  from anon, authenticated;

create or replace function public.finalize_national_fixture_forfeit_v1(
  p_fixture_id uuid,
  p_home_ready boolean,
  p_away_ready boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  v_winner uuid;
  v_home integer := 0;
  v_away integer := 0;
  v_day integer := public.national_team_current_abs_day_v1();
begin
  select * into f
  from public.national_team_fixtures
  where id = p_fixture_id
  for update;

  if not found or f.status in ('completed','cancelled','forfeit') then
    return;
  end if;

  if p_home_ready and not p_away_ready then
    v_winner := f.home_association_id;
    v_home := 3;
  elsif p_away_ready and not p_home_ready then
    v_winner := f.away_association_id;
    v_away := 3;
  else
    v_winner := null;
  end if;

  update public.national_team_fixtures
  set status = case when v_winner is null then 'cancelled' else 'forfeit' end,
      winner_association_id = v_winner,
      home_match_wins = v_home,
      away_match_wins = v_away,
      completion_reason = case
        when v_winner is null then 'both_teams_incomplete'
        else 'incomplete_squad_or_lineup'
      end,
      completed_game_day = v_day,
      updated_at = now()
  where id = f.id;

  select * into w
  from public.national_team_windows
  where id = f.window_id;

  if v_winner is not null and f.division_id is not null then
    insert into public.national_team_division_standings(
      division_id, season_number, association_id,
      ties_played, ties_won, ties_lost,
      matches_won, matches_lost, standings_points
    )
    values(
      f.division_id, w.season_number, f.home_association_id,
      1,
      case when v_winner = f.home_association_id then 1 else 0 end,
      case when v_winner = f.away_association_id then 1 else 0 end,
      v_home, v_away,
      case when v_winner = f.home_association_id then 2 else 0 end
    )
    on conflict(division_id, season_number, association_id) do update
    set ties_played = public.national_team_division_standings.ties_played + 1,
        ties_won = public.national_team_division_standings.ties_won + excluded.ties_won,
        ties_lost = public.national_team_division_standings.ties_lost + excluded.ties_lost,
        matches_won = public.national_team_division_standings.matches_won + excluded.matches_won,
        matches_lost = public.national_team_division_standings.matches_lost + excluded.matches_lost,
        standings_points = public.national_team_division_standings.standings_points + excluded.standings_points,
        updated_at = now();

    insert into public.national_team_division_standings(
      division_id, season_number, association_id,
      ties_played, ties_won, ties_lost,
      matches_won, matches_lost, standings_points
    )
    values(
      f.division_id, w.season_number, f.away_association_id,
      1,
      case when v_winner = f.away_association_id then 1 else 0 end,
      case when v_winner = f.home_association_id then 1 else 0 end,
      v_away, v_home,
      case when v_winner = f.away_association_id then 2 else 0 end
    )
    on conflict(division_id, season_number, association_id) do update
    set ties_played = public.national_team_division_standings.ties_played + 1,
        ties_won = public.national_team_division_standings.ties_won + excluded.ties_won,
        ties_lost = public.national_team_division_standings.ties_lost + excluded.ties_lost,
        matches_won = public.national_team_division_standings.matches_won + excluded.matches_won,
        matches_lost = public.national_team_division_standings.matches_lost + excluded.matches_lost,
        standings_points = public.national_team_division_standings.standings_points + excluded.standings_points,
        updated_at = now();
  end if;

  if v_winner is not null then
    perform public.national_team_record_event_v1(
      f.home_association_id,
      'national_fixture_forfeit',
      jsonb_build_object(
        'fixture_id', f.id,
        'opponent_association_id', f.away_association_id,
        'home_match_wins', v_home,
        'away_match_wins', v_away,
        'winner_association_id', v_winner,
        'completion_reason', 'incomplete_squad_or_lineup'
      ),
      w.season_number
    );

    perform public.national_team_record_event_v1(
      f.away_association_id,
      'national_fixture_forfeit',
      jsonb_build_object(
        'fixture_id', f.id,
        'opponent_association_id', f.home_association_id,
        'home_match_wins', v_home,
        'away_match_wins', v_away,
        'winner_association_id', v_winner,
        'completion_reason', 'incomplete_squad_or_lineup'
      ),
      w.season_number
    );
  else
    perform public.national_team_record_event_v1(
      f.home_association_id,
      'national_fixture_cancelled',
      jsonb_build_object(
        'fixture_id', f.id,
        'opponent_association_id', f.away_association_id,
        'completion_reason', 'both_teams_incomplete'
      ),
      w.season_number
    );

    perform public.national_team_record_event_v1(
      f.away_association_id,
      'national_fixture_cancelled',
      jsonb_build_object(
        'fixture_id', f.id,
        'opponent_association_id', f.home_association_id,
        'completion_reason', 'both_teams_incomplete'
      ),
      w.season_number
    );
  end if;
end;
$$;

revoke execute on function public.finalize_national_fixture_forfeit_v1(uuid, boolean, boolean)
  from anon, authenticated;
