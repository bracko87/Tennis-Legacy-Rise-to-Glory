create or replace function public.validate_player_home_city_v1()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  if new.home_city is null or btrim(new.home_city) = '' then
    if tg_op = 'INSERT' then
      raise exception 'Choose a home city before creating the player.';
    end if;
    return new;
  end if;

  if not exists (
    select 1
    from public.player_home_city_options h
    where h.country_code = upper(new.country_code)
      and lower(h.city) = lower(btrim(new.home_city))
      and h.is_active
  ) then
    raise exception 'The selected home city is not available for this country.';
  end if;

  select h.city into new.home_city
  from public.player_home_city_options h
  where h.country_code = upper(new.country_code)
    and lower(h.city) = lower(btrim(new.home_city))
    and h.is_active
  order by h.sort_order
  limit 1;

  return new;
end;
$$;

revoke all on function public.get_player_creation_countries_v1() from public;
revoke all on function public.get_player_home_city_options_v1(text) from public;
grant execute on function public.get_player_creation_countries_v1() to authenticated;
grant execute on function public.get_player_home_city_options_v1(text) to authenticated;
