create or replace function public.prevent_tournament_application_during_training_camp_v1()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if lower(coalesce(new.status,'')) in ('withdrawn','declined','rejected','cancelled') then
    return new;
  end if;

  if exists (
    select 1
    from public.tournament_world_competitions wc
    join public.tournament_editions te on te.id=wc.tournament_edition_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
    join public.player_training_camp_bookings b
      on b.player_id=new.player_id and b.status in ('booked','active')
    join lateral generate_series(b.start_absolute_day,b.end_absolute_day) g(abs_day) on true
    cross join lateral public.absolute_game_day_v1(g.abs_day) gd
    where wc.id=new.competition_id
      and gd.season=te.season_number
      and gd.season_week=ss.season_week
      and gd.season_week>0
  ) then
    raise exception 'This tournament overlaps a booked training camp. Cancel the camp before applying.';
  end if;

  return new;
end;
$$;

drop trigger if exists tournament_application_training_camp_guard on public.tournament_applications;
create trigger tournament_application_training_camp_guard
before insert or update of competition_id,status on public.tournament_applications
for each row execute function public.prevent_tournament_application_during_training_camp_v1();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_training_camp_bookings'
  ) then
    alter publication supabase_realtime add table public.player_training_camp_bookings;
  end if;
  if not exists (
    select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_training_camp_days'
  ) then
    alter publication supabase_realtime add table public.player_training_camp_days;
  end if;
end $$;
