revoke execute on function public.get_tournament_application_state_v1(uuid) from public, anon;
revoke execute on function public.apply_to_tournament_v1(uuid) from public, anon;
revoke execute on function public.withdraw_tournament_application_v1(uuid) from public, anon;

grant execute on function public.get_tournament_application_state_v1(uuid) to authenticated;
grant execute on function public.apply_to_tournament_v1(uuid) to authenticated;
grant execute on function public.withdraw_tournament_application_v1(uuid) to authenticated;
