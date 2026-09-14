create or replace function public.get_public_home_stats_v1()
returns table(
  active_players bigint,
  total_tournaments bigint,
  matches_completed bigint,
  countries_represented bigint
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select
    ((select count(*) from public.players where owner_user_id is not null and moderation_status <> 'rejected') + 26)::bigint as active_players,
    (select count(*) from public.tournament_editions)::bigint as total_tournaments,
    (select count(*) from public.tournament_matches where status = 'completed' or winner_id is not null)::bigint as matches_completed,
    (select count(distinct country_code) from public.players where moderation_status <> 'rejected' and country_code is not null)::bigint as countries_represented;
$function$;

revoke all on function public.get_public_home_stats_v1() from public;
grant execute on function public.get_public_home_stats_v1() to anon, authenticated;

create or replace function public.get_game_clock_v1()
returns table(server_now timestamptz, speed_multiplier numeric, game_total_seconds bigint)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
            floor(extract(epoch from (cs.server_now - cs.real_anchor_at)) * cs.speed_multiplier)::bigint
          )
        end as game_total_seconds
  from clock_state cs;
$function$;

revoke all on function public.get_game_clock_v1() from public;
grant execute on function public.get_game_clock_v1() to anon, authenticated, service_role;
