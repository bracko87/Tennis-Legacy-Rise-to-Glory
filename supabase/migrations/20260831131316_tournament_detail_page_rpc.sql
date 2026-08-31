drop policy if exists tournament_world_competitions_authenticated_read on public.tournament_world_competitions;
create policy tournament_world_competitions_authenticated_read
on public.tournament_world_competitions
for select
to authenticated
using (
  exists (
    select 1
    from public.players p
    where p.owner_user_id = auth.uid()
      and p.world = tournament_world_competitions.world
  )
);

create or replace function public.get_tournament_detail_v1(
  p_competition_id uuid
)
returns table (
  competition_id uuid,
  tournament_id uuid,
  edition_id uuid,
  world text,
  competition_status text,
  season_number integer,
  tournament_name text,
  city text,
  country_code text,
  country_name text,
  category_code text,
  category_label text,
  winner_points integer,
  main_draw_capacity integer,
  qualifying_capacity_max integer,
  default_qualifier_slots integer,
  surface text,
  environment text,
  schedule_slots jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    wc.id,
    s.id,
    e.id,
    wc.world,
    wc.status,
    e.season_number,
    s.name,
    s.city,
    s.country_code,
    co.name,
    c.code,
    c.label,
    c.winner_points,
    c.main_draw_capacity,
    c.qualifying_capacity_max,
    c.default_qualifier_slots,
    s.surface,
    s.environment,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'calendar_month', sl.calendar_month,
            'month_week', sl.month_week,
            'phase', sl.phase,
            'slot_order', sl.slot_order
          )
          order by sl.slot_order, sl.calendar_month, sl.month_week
        )
        from public.tournament_schedule_slots sl
        where sl.tournament_edition_id = e.id
      ),
      '[]'::jsonb
    )
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  join public.tournament_series s on s.id = e.tournament_series_id and s.is_active
  join public.tournament_categories c on c.code = s.category_code
  join public.countries co on co.code = s.country_code
  where wc.id = p_competition_id
    and wc.status <> 'canceled'
    and e.status <> 'canceled'
    and exists (
      select 1
      from public.players p
      where p.owner_user_id = auth.uid()
        and p.world = wc.world
    );
$$;

revoke all on function public.get_tournament_detail_v1(uuid) from public;
grant execute on function public.get_tournament_detail_v1(uuid) to authenticated;
