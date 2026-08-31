alter table public.tournament_schedule_slots
  add column if not exists season_week smallint;

update public.tournament_schedule_slots
set season_week = case
  when calendar_month = 1 then month_week
  when calendar_month = 2 then 4 + month_week
  else season_week
end
where season_week is null;

do $$
begin
  if exists (select 1 from public.tournament_schedule_slots where season_week is null) then
    raise exception 'Cannot enable continuous competition weeks: an existing schedule slot has no season_week mapping.';
  end if;
end $$;

alter table public.tournament_schedule_slots
  alter column season_week set not null;

alter table public.tournament_schedule_slots
  drop constraint if exists tournament_schedule_slots_month_week_check;

alter table public.tournament_schedule_slots
  add constraint tournament_schedule_slots_month_week_check
  check (month_week between 1 and 5);

alter table public.tournament_schedule_slots
  add constraint tournament_schedule_slots_season_week_check
  check (season_week between 1 and 52);

create or replace function public.sync_tournament_schedule_slot_calendar_v1()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_thursday date;
  v_display_month smallint;
  v_display_week smallint;
begin
  if new.season_week is null or new.season_week < 1 or new.season_week > 52 then
    raise exception 'season_week must be between 1 and 52';
  end if;

  v_thursday := date '2000-01-03' + (((new.season_week - 1) * 7) + 3);
  v_display_month := extract(month from v_thursday)::smallint;

  select count(*)::smallint
  into v_display_week
  from generate_series(1, new.season_week) as w(week_no)
  where extract(month from (date '2000-01-03' + (((w.week_no - 1) * 7) + 3)))::smallint = v_display_month;

  new.calendar_month := v_display_month;
  new.month_week := v_display_week;
  return new;
end;
$$;

drop trigger if exists sync_tournament_schedule_slot_calendar_v1 on public.tournament_schedule_slots;
create trigger sync_tournament_schedule_slot_calendar_v1
before insert or update on public.tournament_schedule_slots
for each row execute function public.sync_tournament_schedule_slot_calendar_v1();

update public.tournament_schedule_slots
set season_week = season_week;

create unique index if not exists tournament_schedule_slots_edition_season_week_phase_key
  on public.tournament_schedule_slots (tournament_edition_id, season_week, phase);

create index if not exists tournament_schedule_slots_season_week_idx
  on public.tournament_schedule_slots (season_week);

drop function if exists public.get_tournament_calendar_v1(integer, integer, text);
create function public.get_tournament_calendar_v1(
  p_season_number integer,
  p_calendar_month integer,
  p_world text
)
returns table (
  competition_id uuid,
  tournament_id uuid,
  edition_id uuid,
  schedule_slot_id uuid,
  world text,
  season_number integer,
  season_week smallint,
  calendar_month smallint,
  month_week smallint,
  phase text,
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
  environment text
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    wc.id,
    s.id,
    e.id,
    sl.id,
    wc.world,
    e.season_number,
    sl.season_week,
    sl.calendar_month,
    sl.month_week,
    sl.phase,
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
    s.environment
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id
  join public.tournament_series s on s.id = e.tournament_series_id and s.is_active
  join public.tournament_categories c on c.code = s.category_code
  join public.countries co on co.code = s.country_code
  join public.tournament_world_competitions wc on wc.tournament_edition_id = e.id
  where e.season_number = p_season_number
    and sl.calendar_month = p_calendar_month
    and wc.world = p_world
    and e.status <> 'canceled'
    and wc.status <> 'canceled'
  order by sl.month_week, c.sort_order, s.name, sl.slot_order;
$$;
revoke execute on function public.get_tournament_calendar_v1(integer, integer, text) from public, anon;
grant execute on function public.get_tournament_calendar_v1(integer, integer, text) to authenticated;

drop function if exists public.get_tournament_detail_v1(uuid);
create function public.get_tournament_detail_v1(
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
  competition_weeks smallint,
  qualification_rounds_max smallint,
  main_draw_rounds smallint,
  qualification_rest_day_first boolean,
  main_draw_rest_day_first boolean,
  one_match_per_player_per_day boolean,
  same_city_for_qualification boolean,
  surface text,
  environment text,
  schedule_slots jsonb
)
language sql
stable
security invoker
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
    c.competition_weeks,
    c.qualification_rounds_max,
    c.main_draw_rounds,
    c.qualification_rest_day_first,
    c.main_draw_rest_day_first,
    c.one_match_per_player_per_day,
    c.same_city_for_qualification,
    s.surface,
    s.environment,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'season_week', sl.season_week,
            'calendar_month', sl.calendar_month,
            'month_week', sl.month_week,
            'phase', sl.phase,
            'slot_order', sl.slot_order
          )
          order by sl.season_week, sl.slot_order
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
    and e.status <> 'canceled';
$$;
revoke execute on function public.get_tournament_detail_v1(uuid) from public, anon;
grant execute on function public.get_tournament_detail_v1(uuid) to authenticated;

create or replace function public.get_tournament_application_state_v1(p_competition_id uuid)
returns table(
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
      min(((c.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7)) as tournament_start_day
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
    least(greatest(counts.applicant_count - greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0), 0), fs.qualifying_capacity_max)::integer as projected_qualifying_count,
    greatest(counts.applicant_count - greatest(fs.main_draw_capacity - fs.default_qualifier_slots, 0) - fs.qualifying_capacity_max, 0)::integer as projected_waiting_count,
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
revoke execute on function public.get_tournament_application_state_v1(uuid) from public, anon;
grant execute on function public.get_tournament_application_state_v1(uuid) to authenticated;

create or replace function public.apply_to_tournament_v1(p_competition_id uuid)
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
    min(((e.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7))
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
revoke execute on function public.apply_to_tournament_v1(uuid) from public, anon;
grant execute on function public.apply_to_tournament_v1(uuid) to authenticated;
