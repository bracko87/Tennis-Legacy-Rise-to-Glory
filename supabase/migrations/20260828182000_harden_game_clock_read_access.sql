grant select on table public.game_clock to authenticated;

create policy game_clock_authenticated_read
on public.game_clock
for select
to authenticated
using (true);

create or replace function public.get_game_clock_v1()
returns table (
  server_now timestamptz,
  speed_multiplier numeric,
  game_total_seconds bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  with clock_state as (
    select
      now() as server_now,
      gc.speed_multiplier,
      gc.real_anchor_at,
      gc.is_paused,
      (
        (
          ((gc.season - 1)::bigint * 366)
          + (
            case gc.month
              when 1 then 0
              when 2 then 31
              when 3 then 60
              when 4 then 91
              when 5 then 121
              when 6 then 152
              when 7 then 182
              when 8 then 213
              when 9 then 244
              when 10 then 274
              when 11 then 305
              when 12 then 335
            end
            + gc.day - 1
          )::bigint
        ) * 86400
        + gc.minute_of_day::bigint * 60
      ) as base_game_seconds
    from public.game_clock gc
    where gc.id = 1
  )
  select
    cs.server_now,
    cs.speed_multiplier,
    cs.base_game_seconds
      + case
          when cs.is_paused then 0::bigint
          else greatest(
            0::bigint,
            floor(
              extract(epoch from (cs.server_now - cs.real_anchor_at))
              * cs.speed_multiplier
            )::bigint
          )
        end as game_total_seconds
  from clock_state cs;
$$;

revoke all on function public.get_game_clock_v1() from public;
revoke all on function public.get_game_clock_v1() from anon;
grant execute on function public.get_game_clock_v1() to authenticated;
