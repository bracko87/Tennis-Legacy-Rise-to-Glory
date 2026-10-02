
-- Internal tournament draw processors are cron/monitoring primitives, not client RPCs.
revoke execute on function public.process_due_tournament_draws_v1() from public,anon,authenticated;
revoke execute on function public.auto_repair_due_tournament_draws_v1(integer) from public,anon,authenticated;
revoke execute on function public.check_tournament_draw_processor_degradation_v1() from public,anon,authenticated;
revoke execute on function public.tournament_draw_health_grace_game_seconds_v1() from public,anon,authenticated;

grant execute on function public.process_due_tournament_draws_v1() to service_role;
grant execute on function public.auto_repair_due_tournament_draws_v1(integer) to service_role;
grant execute on function public.check_tournament_draw_processor_degradation_v1() to service_role;
grant execute on function public.tournament_draw_health_grace_game_seconds_v1() to service_role;
