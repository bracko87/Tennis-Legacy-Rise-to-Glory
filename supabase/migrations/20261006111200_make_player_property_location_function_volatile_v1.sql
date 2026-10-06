-- This function can call ensure_private_life_starter_home_v1, which may write a private starter location.
alter function public.private_life_property_locations_for_player_v1(uuid) volatile;
