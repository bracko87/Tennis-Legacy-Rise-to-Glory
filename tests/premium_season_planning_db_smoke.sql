-- Season Planning Center smoke test (use transaction rollback; no lasting player edits).
begin;
do $qa$
declare
  v_world text;v_player uuid;v_uid uuid;v_comp uuid;v_report jsonb;v_saved jsonb;
  v_row jsonb;v_other uuid;v_wrong_world uuid;v_denied boolean;
  v_all int;v_now int;v_season int;
begin
  select season,public.game_day_absolute_v1(season,month,day) into v_season,v_now
  from public.get_current_game_day_internal_v1();
  foreach v_world in array array['ATP','WTA'] loop
    select p.id,p.owner_user_id into v_player,v_uid from public.players p
    where p.world=v_world and p.player_type='human' and p.owner_user_id is not null
      and (exists(select 1 from public.premium_memberships pm
        where pm.user_id=p.owner_user_id and pm.plan_code='premium'
          and pm.status='active'
          and (pm.current_period_end is null or pm.current_period_end>now()))
       or exists(select 1 from public.tennis_premium_trials_v1 trial
        where trial.user_id=p.owner_user_id and trial.expires_at>now()))
    limit 1;
    if v_player is null then raise exception 'Missing % Premium fixture',v_world;end if;
    perform set_config('request.jwt.claim.sub',v_uid::text,true);
    v_report:=public.get_premium_season_planning_v1(v_player);
    v_all:=jsonb_array_length(v_report->'tournaments');
    if v_report->>'player_id'<>v_player::text
       or v_report->>'world'<>v_world
       or (v_report->>'season')::int<>v_season
       or v_all<>(v_report->>'tournament_count')::int or v_all<50 then
      raise exception 'Invalid % 52-week report',v_world;
    end if;
    if exists(select 1 from jsonb_array_elements(v_report->'tournaments') item(value)
      where (value->>'start_week')::int not between 1 and 52
        or (value->>'end_week')::int not between 1 and 52
        or (value->>'start_week')::int>(value->>'end_week')::int
        or (value->>'winner_points')::int<0) then
      raise exception 'Invalid in-game week or ranking points';end if;
    select value into v_row from jsonb_array_elements(v_report->'tournaments') item(value)
      where (value->>'start_day')::int>v_now+1 and value->>'quarterfinal_points' is not null
      limit 1;
    if v_row is null then raise exception 'Missing future % tournament',v_world;end if;
    v_comp:=(v_row->>'competition_id')::uuid;
    v_saved:=public.save_premium_season_target_v1(v_player,v_comp,'quarterfinal',1,false);
    if not (v_saved->>'saved')::boolean then raise exception 'Save failed';end if;
    v_report:=public.get_premium_season_planning_v1(v_player);
    if not exists(select 1 from jsonb_array_elements(v_report->'tournaments') item(value)
      where value->>'competition_id'=v_comp::text
        and value->>'planned_stage'='quarterfinal'
        and (value->>'planned_priority')::int=1) then
      raise exception 'Saved scenario missing from % report',v_world;end if;
    perform public.save_premium_season_target_v1(v_player,v_comp,'winner',2,true);
    v_report:=public.get_premium_season_planning_v1(v_player);
    if exists(select 1 from jsonb_array_elements(v_report->'tournaments') item(value)
      where value->>'competition_id'=v_comp::text
        and value->>'planned_stage' is not null) then
      raise exception 'Removing target failed';end if;
  end loop;

  select p.id into v_other from public.players p
    where p.owner_user_id is not null and p.owner_user_id<>v_uid limit 1;
  v_denied:=false;
  begin perform public.get_premium_season_planning_v1(v_other);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Cross-owner read exposed';end if;

  v_denied:=false;
  begin perform public.save_premium_season_target_v1(v_other,v_comp,'winner',2,false);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Cross-owner plan write exposed';end if;

  select w.id into v_wrong_world from public.tournament_world_competitions w
    join public.tournament_editions e on e.id=w.tournament_edition_id
    where e.season_number=v_season and w.world<>v_world limit 1;
  v_denied:=false;
  begin perform public.save_premium_season_target_v1(v_player,v_wrong_world,'winner',2,false);
  exception when others then v_denied:=true;end;
  if not v_denied then raise exception 'Wrong-world tournament target accepted';end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin perform public.get_premium_season_planning_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Non-Premium read allowed';end if;
  v_denied:=false;
  begin perform public.save_premium_season_target_v1(v_player,v_comp,'winner',2,false);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Non-Premium write allowed';end if;
  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin perform public.get_premium_season_planning_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Anonymous read allowed';end if;

  if has_function_privilege('anon'::regrole,
      'public.get_premium_season_planning_v1(uuid)','EXECUTE')
    or has_function_privilege('anon'::regrole,
      'public.save_premium_season_target_v1(uuid,uuid,text,integer,boolean)','EXECUTE')
    then raise exception 'Anonymous RPC execution allowed';end if;
  if has_table_privilege('authenticated'::regrole,
      'public.player_premium_season_targets','SELECT')
    or has_table_privilege('authenticated'::regrole,
      'public.player_premium_season_targets','INSERT')
    then raise exception 'Plan table exposed directly';end if;
end
$qa$;
rollback;
