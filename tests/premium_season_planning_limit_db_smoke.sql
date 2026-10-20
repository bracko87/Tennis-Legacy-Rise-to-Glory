-- Validate the maximum of 20 Premium season targets, and allow editing an existing target.
-- Run with a privileged QA connection; the entire fixture rolls back.
begin;
do $cap$
declare
  v_uid uuid;v_player uuid;v_comp uuid;v_first uuid;
  v_count integer:=0;v_denied boolean:=false;v_season integer;
begin
  select p.owner_user_id,p.id into v_uid,v_player
  from public.players p
  where p.world='ATP' and p.player_type='human'
  and (exists(select 1 from public.premium_memberships m
    where m.user_id=p.owner_user_id and m.plan_code='premium' and m.status='active'
      and (m.current_period_end is null or m.current_period_end>now()))
    or exists(select 1 from public.tennis_premium_trials_v1 t
      where t.user_id=p.owner_user_id and t.expires_at>now()))
  limit 1;
  if v_player is null then raise exception 'Missing Premium ATP QA fixture';end if;
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  select season into v_season from public.get_current_game_day_internal_v1();
  for v_comp in
    select w.id from public.tournament_world_competitions w
      join public.tournament_editions e on e.id=w.tournament_edition_id
      join public.tournament_series s on s.id=e.tournament_series_id
      join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
    where w.world='ATP' and e.season_number=v_season and w.status='scheduled'
      and public.training_camp_week_start_absolute_v1(e.season_number,sl.season_week)>
        (select public.game_day_absolute_v1(season,month,day)
         from public.get_current_game_day_internal_v1())
    group by w.id,e.season_number,s.category_code
    order by w.id limit 21
  loop
    v_count:=v_count+1;
    if v_count=1 then v_first:=v_comp;end if;
    if v_count<=20 then
      perform public.save_premium_season_target_v1(v_player,v_comp,'winner',2,false);
    else
      begin
        perform public.save_premium_season_target_v1(v_player,v_comp,'winner',2,false);
      exception when others then v_denied:=true;
      end;
    end if;
  end loop;
  if v_count<21 or not v_denied then
    raise exception 'Season target cap failed';end if;
  perform public.save_premium_season_target_v1(v_player,v_first,'runner_up',1,false);
  if (select count(*) from public.player_premium_season_targets
      where player_id=v_player)<>20 then
    raise exception 'Editing a saved target increased target count';end if;
end
$cap$;
rollback;
