-- Complete the sovereign-state onboarding list with Vatican City.
insert into public.player_home_city_options(
  country_code,city,sort_order,latitude,longitude,is_active
)
values('VA','Vatican City',1,41.9029,12.4534,true)
on conflict(country_code,city) do update
set sort_order=excluded.sort_order,
    latitude=excluded.latitude,
    longitude=excluded.longitude,
    is_active=true,
    updated_at=now();

select public.check_player_identity_tactics_health_v1();
