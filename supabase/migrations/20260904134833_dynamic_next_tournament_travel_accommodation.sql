create or replace function public.refresh_player_future_first_match_schedule_v1(p_player_id uuid)
returns integer
language plpgsql
security definer
set search_path='public'
as $$
declare r record;v_count integer:=0;v_now integer;
begin
  select public.game_day_absolute_v1(season,month,day) into v_now from public.get_current_game_day_internal_v1();
  for r in
    select m.id
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where m.round_number=1 and m.status='scheduled'
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))>=v_now
    order by ed.season_number,m.scheduled_season_week,m.scheduled_day,coalesce(m.scheduled_start_minute,600)
  loop
    perform public.accommodate_match_travel_v1(r.id);v_count:=v_count+1;
  end loop;
  return v_count;
end;$$;
revoke all on function public.refresh_player_future_first_match_schedule_v1(uuid) from public,anon,authenticated;

create or replace function public.sync_travel_plan_from_tournament_match_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare v_player uuid;begin
  for v_player in select distinct x.player_id from (
    select case when tg_op='DELETE' then old.player1_id else new.player1_id end player_id union all
    select case when tg_op='DELETE' then old.player2_id else new.player2_id end union all
    select case when tg_op='UPDATE' then old.player1_id else null end union all
    select case when tg_op='UPDATE' then old.player2_id else null end
  )x join public.players p on p.id=x.player_id where x.player_id is not null and p.player_type='human' and p.owner_user_id is not null
  loop
    perform public.rebuild_player_travel_plan_v1(v_player);
    if pg_trigger_depth()<=2 then perform public.refresh_player_future_first_match_schedule_v1(v_player);end if;
  end loop;
  return case when tg_op='DELETE' then old else new end;
end;$$;
revoke all on function public.sync_travel_plan_from_tournament_match_v1() from public,anon,authenticated;
