
create or replace function private.guard_national_callup_acceptance_plans_v1()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
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
execute function private.guard_national_callup_acceptance_plans_v1();

drop function if exists public.guard_national_callup_acceptance_plans_v1();
