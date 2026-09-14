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
    (select count(*) from public.players where moderation_status <> 'rejected')::bigint as active_players,
    (select count(*) from public.tournament_editions)::bigint as total_tournaments,
    (select count(*) from public.tournament_matches where status = 'completed' or winner_id is not null)::bigint as matches_completed,
    (select count(distinct country_code) from public.players where moderation_status <> 'rejected' and country_code is not null)::bigint as countries_represented;
$function$;

revoke all on function public.get_public_home_stats_v1() from public;
grant execute on function public.get_public_home_stats_v1() to anon, authenticated;

grant execute on function public.get_game_clock_v1() to anon;
