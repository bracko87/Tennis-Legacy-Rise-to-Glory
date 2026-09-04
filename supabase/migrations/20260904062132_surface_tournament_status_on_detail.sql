create or replace function public.get_tournament_detail_v1(p_competition_id uuid)
returns table(
  competition_id uuid,
  tournament_id uuid,
  edition_id uuid,
  world text,
  competition_status text,
  season_number integer,
  tournament_name text,
  logo_url text,
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
security definer
set search_path = public
as $$
  select
    wc.id,
    s.id,
    e.id,
    wc.world,
    st.tournament_status_label || ' · You: ' || st.user_status_label,
    e.season_number,
    s.name,
    s.logo_url,
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
  cross join lateral public.get_tournament_status_v1(wc.id) st
  where wc.id = p_competition_id
    and wc.status <> 'canceled'
    and e.status <> 'canceled';
$$;

revoke all on function public.get_tournament_detail_v1(uuid) from public;
grant execute on function public.get_tournament_detail_v1(uuid) to authenticated;
