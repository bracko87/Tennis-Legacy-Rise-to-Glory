create table if not exists public.tournament_applications (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  world text not null check (world in ('ATP', 'WTA')),
  status text not null default 'applied' check (status in ('applied', 'withdrawn')),
  ranking_position_snapshot integer null check (ranking_position_snapshot is null or ranking_position_snapshot > 0),
  ranking_points_snapshot integer null check (ranking_points_snapshot is null or ranking_points_snapshot >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id, player_id)
);

create index if not exists tournament_applications_competition_active_idx
  on public.tournament_applications (competition_id, status, ranking_position_snapshot, created_at);

alter table public.tournament_applications enable row level security;

drop policy if exists tournament_applications_own_read on public.tournament_applications;
create policy tournament_applications_own_read
on public.tournament_applications
for select
to authenticated
using (owner_user_id = auth.uid());

drop trigger if exists tournament_applications_set_updated_at on public.tournament_applications;
create trigger tournament_applications_set_updated_at
before update on public.tournament_applications
for each row execute function public.set_updated_at();

create or replace function public.get_tournament_application_state_v1(
  p_competition_id uuid
)
returns table (
  applications_open boolean,
  tournament_started boolean,
  applicant_count integer,
  other_applicant_count integer,
  direct_entry_slots integer,
  qualifying_capacity integer,
  qualifier_slots integer,
  projected_main_count integer,
  projected_qualifying_count integer,
  projected_waiting_count integer,
  user_applied boolean,
  user_projection text,
  if_apply_projection text,
  projection_basis text
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select p.id as player_id, p.world
    from public.players p
    where p.owner_user_id = auth.uid()
    limit 1
  ),
  competition as (
    select
      wc.id as competition_id,
      wc.world,
      e.id as edition_id,
      e.season_number,
      c.main_draw_capacity,
      c.qualifying_capacity_max,
      c.default_qualifier_slots
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id = wc.tournament_edition_id
    join public.tournament_series s on s.id = e.tournament_series_id
    join public.tournament_categories c on c.code = s.category_code
    join me on me.world = wc.world
    where wc.id = p_competition_id
      and wc.status <> 'canceled'
      and e.status <> 'canceled'
  ),
  first_slot as (
    select
      c.*,
      min(
        ((c.season_number - 1)::bigint * 366)
        + case sl.calendar_month
            when 1 then 0 when 2 then 31 when 3 then 60 when 4 then 91
            when 5 then 121 when 6 then 152 when 7 then 182 when 8 then 213
            when 9 then 244 when 10 then 274 when 11 then 305 when 12 then 335
          end
        + case sl.month_week when 1 then 0 when 2 then 7 when 3 then 14 else 21 end
      ) as tournament_start_day
    from competition c
    join public.tournament_schedule_slots sl on sl.tournament_edition_id = c.edition_id
    group by c.competition_id, c.world, c.edition_id, c.season_number,
      c.main_draw_capacity, c.qualifying_capacity_max, c.default_qualifier_slots
  ),
  clock as (
    select floor(gc.game_total_seconds::numeric / 86400)::bigint as current_game_day
    from public.get_game_clock_v1() gc
  ),
  active_apps as (
    select a.*
    from public.tournament_applications a
    join first_slot fs on fs.competition_id = a.competition_id
    where a.status = 'applied'
  ),
  ranked_apps as (
    select
      a.*,
      row_number() over (
        order by a.ranking_position_snapshot asc nulls last, a.created_at asc, a.id asc
      )::integer as projected_position
    from active_apps a
  ),
  counts as (
    select count(*)::integer as applicant_count
    from active_apps
  ),
  user_row as (
    select ra.projected_position
    from ranked_apps ra
    join me on me.player_id = ra.player_id
    limit 1
  ),
  ranking_basis as (
    select exists (
      select 1 from active_apps where ranking_position_snapshot is not null
    ) as has_ranking_snapshot
  )
  select
    (clock.current_game_day < fs.tournament_start_day) as applications_open,
    (clock.current_game_day >= fs.tournament_start_day) as tournament_started,
    counts.applicant_count,
    greatest(counts.applicant_count - case when user_row.projected_position is null then 0 else 1 end, 0)::integer as other_applicant_count,
    greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0)::integer as direct_entry_slots,
    fs.qualifying_capacity_max::integer as qualifying_capacity,
    fs.default_qualifier_slots::integer as qualifier_slots,
    least(counts.applicant_count, greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0))::integer as projected_main_count,
    least(
      greatest(counts.applicant_count - greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0), 0),
      fs.qualifying_capacity_max
    )::integer as projected_qualifying_count,
    greatest(
      counts.applicant_count - greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) - fs.qualifying_capacity_max,
      0
    )::integer as projected_waiting_count,
    (user_row.projected_position is not null) as user_applied,
    case
      when user_row.projected_position is null then null
      when user_row.projected_position <= greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) then 'main_draw'
      when user_row.projected_position <= greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) + fs.qualifying_capacity_max then 'qualification'
      else 'waiting_list'
    end as user_projection,
    case
      when user_row.projected_position is not null then
        case
          when user_row.projected_position <= greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) then 'main_draw'
          when user_row.projected_position <= greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) + fs.qualifying_capacity_max then 'qualification'
          else 'waiting_list'
        end
      when counts.applicant_count + 1 <= greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) then 'main_draw'
      when counts.applicant_count + 1 <= greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) + fs.qualifying_capacity_max then 'qualification'
      else 'waiting_list'
    end as if_apply_projection,
    case when ranking_basis.has_ranking_snapshot then 'ranking_snapshot' else 'capacity_order' end as projection_basis
  from first_slot fs
  cross join clock
  cross join counts
  cross join ranking_basis
  left join user_row on true;
$$;

create or replace function public.apply_to_tournament_v1(
  p_competition_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player public.players%rowtype;
  v_world text;
  v_start_day bigint;
  v_current_day bigint;
  v_application_id uuid;
begin
  select * into v_player
  from public.players
  where owner_user_id = auth.uid()
  limit 1;

  if v_player.id is null then
    raise exception 'A player profile is required.';
  end if;

  select
    wc.world,
    min(
      ((e.season_number - 1)::bigint * 366)
      + case sl.calendar_month
          when 1 then 0 when 2 then 31 when 3 then 60 when 4 then 91
          when 5 then 121 when 6 then 152 when 7 then 182 when 8 then 213
          when 9 then 244 when 10 then 274 when 11 then 305 when 12 then 335
        end
      + case sl.month_week when 1 then 0 when 2 then 7 when 3 then 14 else 21 end
    )
  into v_world, v_start_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id = e.id
  where wc.id = p_competition_id
    and wc.status <> 'canceled'
    and e.status <> 'canceled'
  group by wc.world;

  if v_world is null then
    raise exception 'Tournament competition is unavailable.';
  end if;

  if v_world <> v_player.world then
    raise exception 'This tournament belongs to a different competitive world.';
  end if;

  select floor(gc.game_total_seconds::numeric / 86400)::bigint
  into v_current_day
  from public.get_game_clock_v1() gc;

  if v_current_day >= v_start_day then
    raise exception 'Applications are closed because the tournament has started.';
  end if;

  insert into public.tournament_applications (
    competition_id,
    player_id,
    owner_user_id,
    world,
    status,
    ranking_position_snapshot,
    ranking_points_snapshot,
    created_at,
    updated_at
  ) values (
    p_competition_id,
    v_player.id,
    auth.uid(),
    v_player.world,
    'applied',
    null,
    null,
    now(),
    now()
  )
  on conflict (competition_id, player_id)
  do update set
    owner_user_id = excluded.owner_user_id,
    world = excluded.world,
    status = 'applied',
    created_at = now(),
    updated_at = now()
  returning id into v_application_id;

  return v_application_id;
end;
$$;

create or replace function public.withdraw_tournament_application_v1(
  p_competition_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_updated integer;
begin
  update public.tournament_applications
  set status = 'withdrawn', updated_at = now()
  where competition_id = p_competition_id
    and owner_user_id = auth.uid()
    and status = 'applied';

  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.get_tournament_application_state_v1(uuid) from public;
revoke all on function public.apply_to_tournament_v1(uuid) from public;
revoke all on function public.withdraw_tournament_application_v1(uuid) from public;
grant execute on function public.get_tournament_application_state_v1(uuid) to authenticated;
grant execute on function public.apply_to_tournament_v1(uuid) to authenticated;
grant execute on function public.withdraw_tournament_application_v1(uuid) to authenticated;
