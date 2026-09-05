-- Replace numbered repeat tournament identities from June-December with unique same-country cities.
-- Categories, surfaces, environments, schedule slots, editions, prize money and competition IDs remain unchanged.

update public.tournament_series
set name = case name
  when 'Kingston 2 Challenger' then 'Montego Bay Challenger'
  when 'Roehampton 2 Challenger' then 'Bristol Challenger'
  when 'Plovdiv 3 Challenger' then 'Varna Challenger'
  when 'Phan Thiết 3 Challenger' then 'Nha Trang Challenger'
  when 'Phan Thiết 4 Challenger' then 'Da Lat Challenger'
  when 'Santa Cruz 2 Challenger' then 'Tarija Challenger'
  when 'Bratislava 2 Challenger' then 'Žilina Challenger'
  when 'Brisbane 3 Challenger' then 'Port Macquarie Challenger'
  when 'Monastir 1 Challenger' then 'Sousse Challenger'
  when 'Monastir 2 Challenger' then 'Hammamet Challenger'
  else name
end,
city = case name
  when 'Kingston 2 Challenger' then 'Montego Bay'
  when 'Roehampton 2 Challenger' then 'Bristol'
  when 'Plovdiv 3 Challenger' then 'Varna'
  when 'Phan Thiết 3 Challenger' then 'Nha Trang'
  when 'Phan Thiết 4 Challenger' then 'Da Lat'
  when 'Santa Cruz 2 Challenger' then 'Tarija'
  when 'Bratislava 2 Challenger' then 'Žilina'
  when 'Brisbane 3 Challenger' then 'Port Macquarie'
  when 'Monastir 1 Challenger' then 'Sousse'
  when 'Monastir 2 Challenger' then 'Hammamet'
  else city
end,
slug = case name
  when 'Kingston 2 Challenger' then 'montego-bay-challenger'
  when 'Roehampton 2 Challenger' then 'bristol-challenger'
  when 'Plovdiv 3 Challenger' then 'varna-challenger'
  when 'Phan Thiết 3 Challenger' then 'nha-trang-challenger'
  when 'Phan Thiết 4 Challenger' then 'da-lat-challenger'
  when 'Santa Cruz 2 Challenger' then 'tarija-challenger'
  when 'Bratislava 2 Challenger' then 'zilina-challenger'
  when 'Brisbane 3 Challenger' then 'port-macquarie-challenger'
  when 'Monastir 1 Challenger' then 'sousse-challenger'
  when 'Monastir 2 Challenger' then 'hammamet-challenger'
  else slug
end
where name in (
  'Kingston 2 Challenger','Roehampton 2 Challenger','Plovdiv 3 Challenger',
  'Phan Thiết 3 Challenger','Phan Thiết 4 Challenger','Santa Cruz 2 Challenger',
  'Bratislava 2 Challenger','Brisbane 3 Challenger','Monastir 1 Challenger','Monastir 2 Challenger'
);

-- Australia had no unused city left in the current travel-location seed, so add Port Macquarie
-- using the same country-reference coordinate model currently used for Australian tournament cities.
insert into public.travel_locations (
  id, city, country_code, latitude, longitude, coordinate_basis,
  hotel_cost_index, cost_tier, source, is_active
)
select gen_random_uuid(), 'Port Macquarie', 'AU', -27, 133, 'country_reference', 1.064, 'standard', 'tournament', true
where not exists (
  select 1 from public.travel_locations
  where country_code = 'AU' and lower(city) = lower('Port Macquarie')
);
