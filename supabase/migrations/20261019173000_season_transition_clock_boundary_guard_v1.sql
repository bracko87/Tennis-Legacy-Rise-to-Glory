-- PHASE 2 safety gate — fail closed at the end of the currently active source season.
-- NOTE: This deliberately does not advance/restart the game or grant migration execution.
-- The guard is evaluated by the authoritative game clock read used by daily processors.
-- On source-season closure, the controlled migration must RE-ANCHOR the physical
-- game_clock to the new season before updating this guard, atomically.
create table if not exists public.season_transition_boundary_guard_v1 (
  id boolean primary key default true check (id),
  source_season integer not null check (source_season >= 1),
  stop_at_total_seconds bigint not null check (stop_at_total_seconds >= 0),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint correct_season_boundary check (stop_at_total_seconds = source_season::bigint * 366 * 86400 - 1)
);

revoke all on table public.season_transition_boundary_guard_v1 from public, anon, authenticated;
insert into public.season_transition_boundary_guard_v1(id, source_season, stop_at_total_seconds, enabled)
values (true, 1, 366::bigint * 86400 - 1, true)
on conflict (id) do nothing;

-- Preserve the API result signature and prior clock mathematics. Only change:
-- clamp at 23:59:59 on the source season's Dec 31 when armed, returning 0x
-- effective speed so clients do not extrapolate into an unprepared season.
create or replace function public.get_game_clock_v1()
returns table(server_now timestamptz, speed_multiplier numeric, game_total_seconds bigint)
language sql stable security definer set search_path = public, pg_temp
as $$
  with clock_state as (
    select now() as server_now, gc.speed_multiplier, gc.real_anchor_at, gc.is_paused,
      gc.season,
      (
        (
          ((gc.season - 1)::bigint * 366)
          + (
            case gc.month
              when 1 then 0 when 2 then 31 when 3 then 60 when 4 then 91
              when 5 then 121 when 6 then 152 when 7 then 182 when 8 then 213
              when 9 then 244 when 10 then 274 when 11 then 305 when 12 then 335
            end + gc.day - 1
          )::bigint
        ) * 86400
        + gc.minute_of_day::bigint * 60
      ) as base_game_seconds
    from public.game_clock gc where gc.id = 1
  ), raw_time as (
    select cs.server_now, cs.speed_multiplier, cs.season,
      cs.base_game_seconds +
        case when cs.is_paused then 0::bigint
          else greatest(0::bigint, floor(extract(epoch from (cs.server_now - cs.real_anchor_at)) * cs.speed_multiplier)::bigint)
        end as total_seconds
    from clock_state cs
  ), guarded as (
    select r.server_now,r.speed_multiplier,r.total_seconds,
      case when g.enabled and g.source_season = r.season
        then g.stop_at_total_seconds else null::bigint end as cap_seconds
    from raw_time r
    left join public.season_transition_boundary_guard_v1 g on g.id = true
  )
  select server_now,
    case when cap_seconds is not null and total_seconds >= cap_seconds
      then 0::numeric else speed_multiplier end as speed_multiplier,
    case when cap_seconds is not null
      then least(total_seconds,cap_seconds) else total_seconds end as game_total_seconds
  from guarded;
$$;

comment on table public.season_transition_boundary_guard_v1 is
  'Source-season protection. The read clock stops at Dec 31 23:59:59; migration must re-anchor the physical game_clock transactionally before moving to next season. Do not disable casually.';
