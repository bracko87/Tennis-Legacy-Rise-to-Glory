revoke execute on function public.get_player_creation_countries_v1() from anon;
revoke execute on function public.get_player_home_city_options_v1(text) from anon;
revoke execute on function public.get_player_creation_countries_v1() from public;
revoke execute on function public.get_player_home_city_options_v1(text) from public;
grant execute on function public.get_player_creation_countries_v1() to authenticated;
grant execute on function public.get_player_home_city_options_v1(text) to authenticated;
