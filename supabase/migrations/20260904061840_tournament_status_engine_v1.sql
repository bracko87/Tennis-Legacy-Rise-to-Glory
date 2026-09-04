create or replace function public.get_tournament_status_v1(p_competition_id uuid)
returns table(
  tournament_status text,
  tournament_status_label text,
  applications_open boolean,
  application_open_day bigint,
  application_close_day bigint,
  tournament_start_day bigint,
  tournament_end_day bigint,
  user_status text,
  user_status_label text,
  user_entry_projection text
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
      wc.status as competition_db_status,
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
    where wc.id = p_competition_id
      and e.status <> 'canceled'
  ),
  timing_base as (
    select
      c.*,
      min(((c.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7)) as tournament_start_day,
      max(((c.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7) + 6) as tournament_end_day,
      ((c.season_number - 1)::bigint * 366) as season_start_day
    from competition c
    join public.tournament_schedule_slots sl on sl.tournament_edition_id = c.edition_id
    group by c.competition_id, c.competition_db_status, c.world, c.edition_id, c.season_number,
      c.main_draw_capacity, c.qualifying_capacity_max, c.default_qualifier_slots
  ),
  timing as (
    select
      tb.*,
      greatest(tb.season_start_day, tb.tournament_start_day - 14) as application_open_day,
      greatest(
        greatest(tb.season_start_day, tb.tournament_start_day - 14),
        case
          when tb.tournament_start_day - greatest(tb.season_start_day, tb.tournament_start_day - 14) < 4
            then tb.tournament_start_day - 1
          else tb.tournament_start_day - 3
        end
      ) as application_close_day
    from timing_base tb
  ),
  clock as (
    select floor(gc.game_total_seconds::numeric / 86400)::bigint as current_game_day
    from public.get_game_clock_v1() gc
  ),
  my_application as (
    select a.status
    from public.tournament_applications a
    join me on me.player_id = a.player_id
    where a.competition_id = p_competition_id
    limit 1
  ),
  ranked_apps as (
    select
      a.player_id,
      row_number() over (
        order by a.ranking_position_snapshot asc nulls last, a.created_at asc, a.id asc
      )::integer as projected_position
    from public.tournament_applications a
    where a.competition_id = p_competition_id
      and a.status = 'applied'
  ),
  my_ranked_app as (
    select ra.projected_position
    from ranked_apps ra
    join me on me.player_id = ra.player_id
    limit 1
  ),
  my_entry as (
    select te.draw_type, te.entry_status
    from public.tournament_entries te
    join me on me.player_id = te.player_id
    where te.competition_id = p_competition_id
    order by te.updated_at desc, te.created_at desc
    limit 1
  ),
  draw_state as (
    select exists(
      select 1
      from public.tournament_matches tm
      where tm.competition_id = p_competition_id
        and tm.round_number = 1
    ) as draw_published
  ),
  champion_state as (
    select exists(
      select 1
      from public.tournament_matches tm
      join me on me.player_id = tm.winner_id
      where tm.competition_id = p_competition_id
        and tm.round_label = 'Final'
        and tm.status = 'completed'
    ) as is_champion
  )
  select
    case
      when t.competition_db_status = 'canceled' then 'canceled'
      when clk.current_game_day > t.tournament_end_day then 'completed'
      when clk.current_game_day >= t.tournament_start_day then 'in_progress'
      when clk.current_game_day > t.application_close_day and ds.draw_published then 'draw_published'
      when clk.current_game_day > t.application_close_day then 'applications_closed'
      when clk.current_game_day >= t.application_open_day then 'applications_open'
      else 'applications_not_open'
    end as tournament_status,
    case
      when t.competition_db_status = 'canceled' then 'Canceled'
      when clk.current_game_day > t.tournament_end_day then 'Completed'
      when clk.current_game_day >= t.tournament_start_day then 'Tournament in progress'
      when clk.current_game_day > t.application_close_day and ds.draw_published then 'Draw published'
      when clk.current_game_day > t.application_close_day then 'Applications closed'
      when clk.current_game_day >= t.application_open_day then 'Applications open'
      else 'Applications not open'
    end as tournament_status_label,
    (clk.current_game_day >= t.application_open_day and clk.current_game_day <= t.application_close_day) as applications_open,
    t.application_open_day,
    t.application_close_day,
    t.tournament_start_day,
    t.tournament_end_day,
    case
      when cs.is_champion then 'champion'
      when me2.entry_status = 'eliminated' then 'eliminated'
      when clk.current_game_day > t.tournament_end_day and me2.entry_status is not null then 'completed'
      when clk.current_game_day >= t.tournament_start_day and me2.entry_status = 'active' then 'competing'
      when clk.current_game_day < t.tournament_start_day and me2.entry_status = 'active' and me2.draw_type = 'main_draw' then 'accepted_main_draw'
      when clk.current_game_day < t.tournament_start_day and me2.entry_status = 'active' and me2.draw_type = 'qualification' then 'accepted_qualification'
      when ma.status = 'withdrawn' then 'withdrawn'
      when ma.status = 'applied' and clk.current_game_day <= t.application_close_day then 'pending'
      when ma.status = 'applied' and mra.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) then 'accepted_main_draw'
      when ma.status = 'applied' and mra.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) + t.qualifying_capacity_max then 'accepted_qualification'
      when ma.status = 'applied' and clk.current_game_day > t.application_close_day then 'rejected'
      when clk.current_game_day > t.application_close_day then 'did_not_apply'
      else 'not_applied'
    end as user_status,
    case
      when cs.is_champion then 'Champion'
      when me2.entry_status = 'eliminated' then 'Eliminated'
      when clk.current_game_day > t.tournament_end_day and me2.entry_status is not null then 'Tournament completed'
      when clk.current_game_day >= t.tournament_start_day and me2.entry_status = 'active' then 'Competing'
      when clk.current_game_day < t.tournament_start_day and me2.entry_status = 'active' and me2.draw_type = 'main_draw' then 'Accepted · Main Draw'
      when clk.current_game_day < t.tournament_start_day and me2.entry_status = 'active' and me2.draw_type = 'qualification' then 'Accepted · Qualification'
      when ma.status = 'withdrawn' then 'Application withdrawn'
      when ma.status = 'applied' and clk.current_game_day <= t.application_close_day then 'Application pending'
      when ma.status = 'applied' and mra.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) then 'Accepted · Main Draw'
      when ma.status = 'applied' and mra.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) + t.qualifying_capacity_max then 'Accepted · Qualification'
      when ma.status = 'applied' and clk.current_game_day > t.application_close_day then 'Application rejected'
      when clk.current_game_day > t.application_close_day then 'Did not apply'
      else 'Not applied'
    end as user_status_label,
    case
      when me2.draw_type is not null then me2.draw_type
      when ma.status = 'applied' and mra.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) then 'main_draw'
      when ma.status = 'applied' and mra.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) + t.qualifying_capacity_max then 'qualification'
      when ma.status = 'applied' and clk.current_game_day > t.application_close_day then 'rejected'
      else null
    end as user_entry_projection
  from timing t
  cross join clock clk
  cross join draw_state ds
  cross join champion_state cs
  left join my_application ma on true
  left join my_ranked_app mra on true
  left join my_entry me2 on true;
$$;

revoke all on function public.get_tournament_status_v1(uuid) from public;
grant execute on function public.get_tournament_status_v1(uuid) to authenticated;

create or replace function public.get_tournament_calendar_v2(
  p_season_number integer,
  p_calendar_month integer,
  p_world text
)
returns table(
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
  environment text,
  tournament_status text,
  tournament_status_label text,
  applications_open boolean,
  application_open_day bigint,
  application_close_day bigint,
  tournament_start_day bigint,
  tournament_end_day bigint,
  user_status text,
  user_status_label text,
  user_entry_projection text
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
    s.environment,
    st.tournament_status,
    st.tournament_status_label,
    st.applications_open,
    st.application_open_day,
    st.application_close_day,
    st.tournament_start_day,
    st.tournament_end_day,
    st.user_status,
    st.user_status_label,
    st.user_entry_projection
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id
  join public.tournament_series s on s.id = e.tournament_series_id and s.is_active
  join public.tournament_categories c on c.code = s.category_code
  join public.countries co on co.code = s.country_code
  join public.tournament_world_competitions wc on wc.tournament_edition_id = e.id
  cross join lateral public.get_tournament_status_v1(wc.id) st
  where e.season_number = p_season_number
    and sl.calendar_month = p_calendar_month
    and wc.world = upper(p_world)
    and e.status <> 'canceled'
    and wc.status <> 'canceled'
  order by sl.month_week, c.sort_order, s.name, sl.slot_order;
$$;

revoke all on function public.get_tournament_calendar_v2(integer, integer, text) from public;
grant execute on function public.get_tournament_calendar_v2(integer, integer, text) to authenticated;

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
      min(((c.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7)) as tournament_start_day,
      ((c.season_number - 1)::bigint * 366) as season_start_day
    from competition c
    join public.tournament_schedule_slots sl on sl.tournament_edition_id = c.edition_id
    group by c.competition_id, c.world, c.edition_id, c.season_number,
      c.main_draw_capacity, c.qualifying_capacity_max, c.default_qualifier_slots
  ),
  timing as (
    select
      fs.*,
      greatest(fs.season_start_day, fs.tournament_start_day - 14) as application_open_day,
      greatest(
        greatest(fs.season_start_day, fs.tournament_start_day - 14),
        case
          when fs.tournament_start_day - greatest(fs.season_start_day, fs.tournament_start_day - 14) < 4
            then fs.tournament_start_day - 1
          else fs.tournament_start_day - 3
        end
      ) as application_close_day
    from first_slot fs
  ),
  clock as (
    select floor(gc.game_total_seconds::numeric / 86400)::bigint as current_game_day
    from public.get_game_clock_v1() gc
  ),
  active_apps as (
    select a.*
    from public.tournament_applications a
    where a.competition_id = p_competition_id
      and a.status = 'applied'
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
    select exists (select 1 from active_apps where ranking_position_snapshot is not null) as has_ranking_snapshot
  )
  select
    (clock.current_game_day >= t.application_open_day and clock.current_game_day <= t.application_close_day) as applications_open,
    (clock.current_game_day >= t.tournament_start_day) as tournament_started,
    counts.applicant_count,
    greatest(counts.applicant_count - case when user_row.projected_position is null then 0 else 1 end, 0)::integer as other_applicant_count,
    greatest(t.main_draw_capacity - t.default_qualifier_slots, 0)::integer as direct_entry_slots,
    t.qualifying_capacity_max::integer as qualifying_capacity,
    t.default_qualifier_slots::integer as qualifier_slots,
    least(counts.applicant_count, greatest(t.main_draw_capacity - t.default_qualifier_slots, 0))::integer as projected_main_count,
    least(greatest(counts.applicant_count - greatest(t.main_draw_capacity - t.default_qualifier_slots, 0), 0), t.qualifying_capacity_max)::integer as projected_qualifying_count,
    greatest(counts.applicant_count - greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) - t.qualifying_capacity_max, 0)::integer as projected_waiting_count,
    (user_row.projected_position is not null) as user_applied,
    case
      when user_row.projected_position is null then null
      when user_row.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) then 'main_draw'
      when user_row.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) + t.qualifying_capacity_max then 'qualification'
      else 'waiting_list'
    end as user_projection,
    case
      when user_row.projected_position is not null then
        case
          when user_row.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) then 'main_draw'
          when user_row.projected_position <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) + t.qualifying_capacity_max then 'qualification'
          else 'waiting_list'
        end
      when counts.applicant_count + 1 <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) then 'main_draw'
      when counts.applicant_count + 1 <= greatest(t.main_draw_capacity - t.default_qualifier_slots, 0) + t.qualifying_capacity_max then 'qualification'
      else 'waiting_list'
    end as if_apply_projection,
    case when ranking_basis.has_ranking_snapshot then 'ranking_snapshot' else 'capacity_order' end as projection_basis
  from timing t
  cross join clock
  cross join counts
  cross join ranking_basis
  left join user_row on true;
$$;

create or replace function public.apply_to_tournament_v1(p_competition_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player public.players%rowtype;
  v_world text;
  v_season_number integer;
  v_start_day bigint;
  v_season_start_day bigint;
  v_open_day bigint;
  v_close_day bigint;
  v_current_day bigint;
  v_application_id uuid;
  v_rank_position integer;
  v_rank_points integer;
begin
  select * into v_player from public.players where owner_user_id = auth.uid() limit 1;
  if v_player.id is null then raise exception 'A player profile is required.'; end if;

  select wc.world, e.season_number,
    min(((e.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7))
  into v_world, v_season_number, v_start_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id = e.id
  where wc.id = p_competition_id and wc.status <> 'canceled' and e.status <> 'canceled'
  group by wc.world, e.season_number;

  if v_world is null then raise exception 'Tournament competition is unavailable.'; end if;
  if v_world <> v_player.world then raise exception 'This tournament belongs to a different competitive world.'; end if;

  v_season_start_day := (v_season_number - 1)::bigint * 366;
  v_open_day := greatest(v_season_start_day, v_start_day - 14);
  v_close_day := greatest(v_open_day, case when v_start_day - v_open_day < 4 then v_start_day - 1 else v_start_day - 3 end);

  select floor(gc.game_total_seconds::numeric / 86400)::bigint into v_current_day from public.get_game_clock_v1() gc;
  if v_current_day < v_open_day then raise exception 'Applications are not open yet for this tournament.'; end if;
  if v_current_day > v_close_day then raise exception 'Applications are closed for this tournament.'; end if;

  select ranked.rank_position, ranked.ranking_points into v_rank_position, v_rank_points
  from (
    select p.id as player_id,
      row_number() over (order by coalesce(r.ranking_points, 0) desc, coalesce(r.seed_rating, 0) desc, p.created_at asc, p.id asc)::integer as rank_position,
      coalesce(r.ranking_points, 0)::integer as ranking_points
    from public.players p
    left join public.player_rankings r on r.player_id = p.id
    where p.world = v_player.world and p.moderation_status <> 'rejected'
  ) ranked
  where ranked.player_id = v_player.id;

  insert into public.tournament_applications (
    competition_id, player_id, owner_user_id, world, status,
    ranking_position_snapshot, ranking_points_snapshot, created_at, updated_at
  ) values (
    p_competition_id, v_player.id, auth.uid(), v_player.world, 'applied',
    v_rank_position, v_rank_points, now(), now()
  )
  on conflict (competition_id, player_id)
  do update set owner_user_id = excluded.owner_user_id, world = excluded.world,
    status = 'applied', ranking_position_snapshot = excluded.ranking_position_snapshot,
    ranking_points_snapshot = excluded.ranking_points_snapshot, created_at = now(), updated_at = now()
  returning id into v_application_id;

  return v_application_id;
end;
$$;

create or replace function public.withdraw_tournament_application_v1(p_competition_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_season_number integer;
  v_start_day bigint;
  v_season_start_day bigint;
  v_open_day bigint;
  v_close_day bigint;
  v_current_day bigint;
  v_updated integer;
begin
  select e.season_number,
    min(((e.season_number - 1)::bigint * 366) + 2 + ((sl.season_week - 1)::bigint * 7))
  into v_season_number, v_start_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id = e.id
  where wc.id = p_competition_id and wc.status <> 'canceled' and e.status <> 'canceled'
  group by e.season_number;

  if v_start_day is null then raise exception 'Tournament competition is unavailable.'; end if;

  v_season_start_day := (v_season_number - 1)::bigint * 366;
  v_open_day := greatest(v_season_start_day, v_start_day - 14);
  v_close_day := greatest(v_open_day, case when v_start_day - v_open_day < 4 then v_start_day - 1 else v_start_day - 3 end);
  select floor(gc.game_total_seconds::numeric / 86400)::bigint into v_current_day from public.get_game_clock_v1() gc;

  if v_current_day < v_open_day or v_current_day > v_close_day then
    raise exception 'Applications cannot be withdrawn outside the application window.';
  end if;

  update public.tournament_applications
  set status = 'withdrawn', updated_at = now()
  where competition_id = p_competition_id and owner_user_id = auth.uid() and status = 'applied';
  get diagnostics v_updated = row_count;
  return v_updated > 0;
end;
$$;

revoke all on function public.apply_to_tournament_v1(uuid) from public;
revoke all on function public.withdraw_tournament_application_v1(uuid) from public;
grant execute on function public.apply_to_tournament_v1(uuid) to authenticated;
grant execute on function public.withdraw_tournament_application_v1(uuid) to authenticated;
