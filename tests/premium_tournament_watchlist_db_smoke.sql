-- Premium tournament watchlist regression (run only AFTER separately authorized deployment).
-- Rolled back: no lasting watches or game notifications.
begin;
do $qa$
declare
  v_player uuid;v_user uuid;v_world text;v_comp uuid;v_other uuid;v_cross uuid;
  v_report jsonb;v_timeline jsonb;v_now bigint;v_current_season integer;
  v_denied boolean;v_prev integer;
begin
  if not exists(select 1 from public.notification_catalog
    where code='tournament.application.watch_open' and category='tournament' and default_in_app)
  then raise exception 'Missing watchlist notification catalog';end if;
  if not exists(select 1 from cron.job where jobname='tennis-premium-tournament-watch-openings-v1')
  then raise exception 'Watchlist scheduler missing';end if;
  if has_function_privilege('anon'::regrole,
       'public.get_premium_tournament_watchlist_v1(uuid)','EXECUTE')
    or has_function_privilege('anon'::regrole,
       'public.set_premium_tournament_watch_v1(uuid,uuid,boolean)','EXECUTE')
    or has_function_privilege('authenticated'::regrole,
       'public.process_premium_tournament_watch_openings_v1()','EXECUTE')
    or has_table_privilege('authenticated'::regrole,
       'public.player_premium_tournament_watches','SELECT')
  then raise exception 'Watchlist RPC/table privileges too permissive';end if;
  select game_total_seconds into v_now from public.get_game_clock_v1();
  v_current_season := floor(v_now / (366*86400))::integer+1;

  foreach v_world in array array['ATP','WTA'] loop
    select p.id,p.owner_user_id into v_player,v_user
    from public.players p
    where p.world=v_world and p.owner_user_id is not null and p.player_type='human'
      and (exists(select 1 from public.premium_memberships pm where pm.user_id=p.owner_user_id
         and pm.plan_code='premium' and pm.status='active'
         and (pm.current_period_end is null or pm.current_period_end>now()))
        or exists(select 1 from public.tennis_premium_trials_v1 tr
         where tr.user_id=p.owner_user_id and tr.expires_at>now()))
    limit 1;
    if v_player is null then raise exception 'Missing Premium fixture for %',v_world;end if;
    perform set_config('request.jwt.claim.sub',v_user::text,true);
    v_report:=public.get_premium_tournament_watchlist_v1(v_player);
    if v_report->>'player_id'<>v_player::text or
       (v_report->>'season')::integer<>v_current_season then
      raise exception 'Invalid watchlist report for %',v_world;end if;

    -- Find an event which has not yet reached its ACTUAL opening moment.
    select wc.id into v_comp
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    where wc.world=v_world and e.season_number=v_current_season
      and e.status<>'canceled' and wc.status<>'canceled' and s.is_active
      and (public.get_tournament_entry_timeline_v1(wc.id)->>'applications_open_game_second')::bigint>v_now
      and not exists(select 1 from public.tournament_applications a
        where a.player_id=v_player and a.competition_id=wc.id
          and a.status in('applied','accepted_main_draw','accepted_qualification'))
    order by wc.id limit 1;
    if v_comp is not null then
      perform public.set_premium_tournament_watch_v1(v_player,v_comp,true);
      perform public.set_premium_tournament_watch_v1(v_player,v_comp,true);
      v_report:=public.get_premium_tournament_watchlist_v1(v_player);
      if not exists(select 1 from jsonb_array_elements(v_report->'watches') x(value)
        where value->>'competition_id'=v_comp::text and value->>'status'='upcoming')
      then raise exception 'Watched event missing from % report',v_world;end if;

      -- Cross-user write access must be blocked.
      select p.id into v_other from public.players p
        where p.owner_user_id is not null and p.owner_user_id<>v_user limit 1;
      v_denied:=false;
      begin
        perform public.set_premium_tournament_watch_v1(v_other,v_comp,true);
      exception when sqlstate '42501' then v_denied:=true;end;
      if not v_denied then raise exception 'Other user could add watch';end if;
      v_denied:=false;
      begin
        perform public.get_premium_tournament_watchlist_v1(v_other);
      exception when sqlstate '42501' then v_denied:=true;end;
      if not v_denied then raise exception 'Other user could read watchlist';end if;

      perform public.set_premium_tournament_watch_v1(v_player,v_comp,false);
      v_report:=public.get_premium_tournament_watchlist_v1(v_player);
      if exists(select 1 from jsonb_array_elements(v_report->'watches') x(value)
        where value->>'competition_id'=v_comp::text)
      then raise exception 'Unwatch failed';end if;
    end if;
  end loop;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  v_denied:=false;
  begin perform public.get_premium_tournament_watchlist_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Non-Premium access allowed';end if;
  perform set_config('request.jwt.claim.sub','',true);
  v_denied:=false;
  begin perform public.get_premium_tournament_watchlist_v1(v_player);
  exception when sqlstate '42501' then v_denied:=true;end;
  if not v_denied then raise exception 'Anonymous access allowed';end if;
end
$qa$;
rollback;
