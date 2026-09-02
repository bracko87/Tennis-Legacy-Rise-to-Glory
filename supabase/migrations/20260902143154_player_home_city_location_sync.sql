create or replace function public.sync_player_home_location_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  insert into public.player_location_state(player_id,current_city,current_country_code,current_continent,location_type,updated_at)
  values(new.id,new.home_city,new.country_code,public.country_continent_v1(new.country_code),'home',now())
  on conflict(player_id) do update set
    current_city=case when public.player_location_state.location_type='home' then excluded.current_city else public.player_location_state.current_city end,
    current_country_code=case when public.player_location_state.location_type='home' then excluded.current_country_code else public.player_location_state.current_country_code end,
    current_continent=case when public.player_location_state.location_type='home' then excluded.current_continent else public.player_location_state.current_continent end,
    updated_at=now();
  return new;
end;
$$;

drop trigger if exists trg_players_sync_home_location on public.players;
create trigger trg_players_sync_home_location
after insert or update of home_city,country_code on public.players
for each row execute function public.sync_player_home_location_v1();

create or replace function public.set_player_home_city_v1(p_home_city text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_player_id uuid; v_city text:=nullif(trim(coalesce(p_home_city,'')),'');
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if v_city is not null and length(v_city)>80 then raise exception 'Home city is too long.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid();
  if v_player_id is null then raise exception 'Player not found.'; end if;
  update public.players set home_city=v_city,updated_at=now() where id=v_player_id;
  return jsonb_build_object('status','updated','home_city',v_city);
end;
$$;
grant execute on function public.set_player_home_city_v1(text) to authenticated;
