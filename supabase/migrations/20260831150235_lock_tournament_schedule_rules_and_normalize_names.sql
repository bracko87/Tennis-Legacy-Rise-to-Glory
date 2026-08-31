alter table public.tournament_categories
  add column if not exists competition_weeks smallint not null default 1 check (competition_weeks in (1, 2)),
  add column if not exists qualification_rounds_max smallint not null default 2 check (qualification_rounds_max between 0 and 7),
  add column if not exists main_draw_rounds smallint not null default 5 check (main_draw_rounds between 1 and 8),
  add column if not exists qualification_rest_day_first boolean not null default false,
  add column if not exists main_draw_rest_day_first boolean not null default false,
  add column if not exists one_match_per_player_per_day boolean not null default true,
  add column if not exists same_city_for_qualification boolean not null default true;

update public.tournament_categories
set
  qualifying_capacity_max = case code
    when 'grand_slam_2000' then 256
    when 'masters_1000' then 128
    when 'tour_500' then 32
    when 'tour_250' then 32
    when 'challenger_125' then 24
    when 'challenger_100' then 24
    when 'challenger_75' then 24
    when 'challenger_50' then 24
    when 'futures_25' then 32
    when 'futures_15' then 32
    else qualifying_capacity_max
  end,
  default_qualifier_slots = case code
    when 'grand_slam_2000' then 16
    when 'masters_1000' then 8
    when 'tour_500' then 8
    when 'tour_250' then 8
    when 'challenger_125' then 6
    when 'challenger_100' then 6
    when 'challenger_75' then 6
    when 'challenger_50' then 6
    when 'futures_25' then 8
    when 'futures_15' then 8
    else default_qualifier_slots
  end,
  competition_weeks = case when code in ('grand_slam_2000', 'masters_1000') then 2 else 1 end,
  qualification_rounds_max = case when code in ('grand_slam_2000', 'masters_1000') then 4 else 2 end,
  main_draw_rounds = case code
    when 'grand_slam_2000' then 7
    when 'masters_1000' then 6
    else 5
  end,
  qualification_rest_day_first = code in ('grand_slam_2000', 'masters_1000'),
  main_draw_rest_day_first = code = 'masters_1000',
  one_match_per_player_per_day = true,
  same_city_for_qualification = true;

-- Masters 1000 uses one full qualification week and one full main-draw week.
update public.tournament_schedule_slots sl
set phase = 'qualification', slot_order = 1
from public.tournament_editions e
join public.tournament_series s on s.id = e.tournament_series_id
where sl.tournament_edition_id = e.id
  and e.season_number = 1
  and s.slug = 'doha-pearl-masters'
  and sl.calendar_month = 2
  and sl.month_week = 2
  and sl.phase = 'full';

insert into public.tournament_schedule_slots
  (tournament_edition_id, calendar_month, month_week, phase, slot_order)
select e.id, 2, 3, 'main_draw', 2
from public.tournament_editions e
join public.tournament_series s on s.id = e.tournament_series_id
where e.season_number = 1
  and s.slug = 'doha-pearl-masters'
on conflict (tournament_edition_id, calendar_month, month_week, phase)
do update set slot_order = excluded.slot_order;

-- Existing Season 1 names use simple city-based naming. Future tournament data should follow the same convention.
with target as (
  select
    s.id,
    s.city,
    s.category_code,
    case
      when s.category_code = 'grand_slam_2000' then 'Grand Championship'
      when s.category_code = 'masters_1000' then 'Masters'
      when s.category_code like 'tour_%' then 'Open'
      when s.category_code like 'challenger_%' then 'Challenger'
      when s.category_code like 'futures_%' then 'Futures'
      else 'Open'
    end as suffix,
    min(sl.calendar_month * 10 + sl.month_week) as first_slot
  from public.tournament_series s
  join public.tournament_editions e on e.tournament_series_id = s.id and e.season_number = 1
  join public.tournament_schedule_slots sl on sl.tournament_edition_id = e.id
  where sl.calendar_month in (1, 2)
  group by s.id, s.city, s.category_code
), ranked as (
  select
    t.*,
    count(*) over (partition by t.city, t.suffix) as duplicate_count,
    row_number() over (partition by t.city, t.suffix order by t.first_slot, t.id) as duplicate_number
  from target t
)
update public.tournament_series s
set name = r.city || ' ' || r.suffix ||
  case
    when r.duplicate_count = 1 or r.duplicate_number = 1 then ''
    when r.duplicate_number = 2 then ' II'
    when r.duplicate_number = 3 then ' III'
    when r.duplicate_number = 4 then ' IV'
    else ' ' || r.duplicate_number::text
  end
from ranked r
where s.id = r.id;

-- Expose the locked category scheduling rules to the tournament page and future engine.
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
    and e.status <> 'canceled';
$$;

revoke execute on function public.get_tournament_detail_v1(uuid) from public, anon;
grant execute on function public.get_tournament_detail_v1(uuid) to authenticated;
