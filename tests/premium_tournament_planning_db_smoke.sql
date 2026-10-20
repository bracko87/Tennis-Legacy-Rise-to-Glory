-- Read-only Premium Tournament Planning Intelligence regression.
-- Run against a fixture database (or a privileged connection with only SELECT).
-- Neither tournament applications nor user data are changed.
begin;
do $test$
declare
  v_uid uuid;
  v_player uuid;
  v_other uuid;
  v_season integer;
  v_month integer;
  v_report jsonb;
  v_item jsonb;
  v_denied boolean;
begin
  select p.owner_user_id,p.id into v_uid,v_player
  from public.players p
  where p.owner_user_id is not null
    and p.player_type='human'
    and (exists(select 1 from public.premium_memberships pm
      where pm.user_id=p.owner_user_id and pm.plan_code='premium'
        and pm.status='active' and (pm.current_period_end is null or pm.current_period_end>now()))
      or exists(select 1 from public.tennis_premium_trials_v1 tr
        where tr.user_id=p.owner_user_id and tr.expires_at>now()))
  limit 1;
  if v_uid is null then raise exception 'Premium fixture unavailable'; end if;
  select season,month into v_season,v_month from public.get_current_game_day_internal_v1();
  perform set_config('request.jwt.claim.sub',v_uid::text,true);
  v_report:=public.get_premium_tournament_planning_v1(v_player,v_season,v_month);
  if (v_report->>'player_id')::uuid <> v_player
    or (v_report->>'season')::integer<>v_season
    or (v_report->>'month')::integer<>v_month
    or jsonb_typeof(v_report->'tournaments') <> 'array'
    or jsonb_array_length(v_report->'tournaments') <> (v_report->>'tournament_count')::integer
    or (v_report->>'tournament_count')::integer<1
    then raise exception 'Premium planner report contract failed'; end if;
  for v_item in select value from jsonb_array_elements(v_report->'tournaments') loop
    if (v_item->>'competition_id') is null
      or (v_item->>'season_week_start')::integer not between 1 and 52
      or (v_item->>'season_week_end')::integer not between 1 and 52
      or (v_item->>'season_week_start')::integer>(v_item->>'season_week_end')::integer
      or (v_item->>'winner_points')::integer<0
      or (v_item->>'other_calendar_choices')::integer<0
      then raise exception 'Planner result contains inconsistent tournament data'; end if;
  end loop;

  select id into v_other from public.players where owner_user_id is not null
  and owner_user_id<>v_uid limit 1;
  if v_other is null then raise exception 'Cross-owner fixture unavailable'; end if;
  v_denied:=false;
  begin
    perform public.get_premium_tournament_planning_v1(v_other,v_season,v_month);
  exception when sqlstate '42501' then v_denied:=true; end;
  if not v_denied then raise exception 'Cross-owner data access allowed'; end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin
    perform public.get_premium_tournament_planning_v1(v_player,v_season,v_month);
  exception when sqlstate '42501' then v_denied:=true; end;
  if not v_denied then raise exception 'Non-Premium data access allowed'; end if;

  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin
    perform public.get_premium_tournament_planning_v1(v_player,v_season,v_month);
  exception when sqlstate '42501' then v_denied:=true; end;
  if not v_denied then raise exception 'Anonymous data access allowed'; end if;

  if has_function_privilege('anon'::regrole,
      'public.get_premium_tournament_planning_v1(uuid,integer,integer)','EXECUTE')
    then raise exception 'Anonymous SQL execute privilege is enabled'; end if;
  if not has_function_privilege('authenticated'::regrole,
      'public.get_premium_tournament_planning_v1(uuid,integer,integer)','EXECUTE')
    then raise exception 'Authenticated client is missing RPC execute privilege'; end if;
end;
$test$;
rollback;
