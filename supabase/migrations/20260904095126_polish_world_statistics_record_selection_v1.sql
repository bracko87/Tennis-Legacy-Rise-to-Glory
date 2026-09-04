create or replace function public.get_world_statistics_v1(p_world text default null,p_period text default 'season')
returns jsonb language plpgsql security definer set search_path='public' as $$
declare
  v_player uuid; v_player_world text; v_world text; v_period text; v_season integer; v_abs integer;
  v_players jsonb; v_records jsonb; v_tournaments jsonb; v_career jsonb; v_surfaces jsonb; v_categories jsonb; v_seasons jsonb;
begin
  select p.id,p.world into v_player,v_player_world from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  v_world:=upper(coalesce(nullif(btrim(p_world),''),v_player_world));
  if v_world not in ('ATP','WTA') then raise exception 'World must be ATP or WTA.'; end if;
  v_period:=lower(coalesce(p_period,'season'));
  if v_period not in ('season','all_time') then raise exception 'Period must be season or all_time.'; end if;
  select d.season,public.game_day_absolute_v1(d.season,d.month,d.day) into v_season,v_abs from public.get_current_game_day_internal_v1() d;
  perform public.capture_world_ranking_snapshot_internal_v1();

  with base as (select * from public.statistics_player_period_rows_internal_v1(v_world,v_period,v_season) where matches>0), ranked as (
    select b.*,row_number() over(order by b.wins desc,b.titles desc,b.win_pct desc,b.current_rank asc)::integer stats_rank from base b
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by r.stats_rank),'[]'::jsonb) into v_players from (select * from ranked order by stats_rank limit 50) r;

  with base as (select * from public.statistics_player_period_rows_internal_v1(v_world,v_period,v_season))
  select jsonb_build_object(
    'current_world_no1',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,current_rank,current_ranking_points from base order by current_rank limit 1) x),
    'performance_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,wins,losses,win_pct,titles from base where matches>0 order by wins desc,titles desc,win_pct desc,current_rank asc limit 1) x),
    'wins_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,wins from base where wins>0 order by wins desc,current_rank asc limit 1) x),
    'losses_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,losses from base where losses>0 order by losses desc,current_rank asc limit 1) x),
    'win_rate_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,win_pct,matches from base where matches>0 order by win_pct desc,matches desc,current_rank asc limit 1) x),
    'aces_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,aces from base where aces>0 order by aces desc,current_rank asc limit 1) x),
    'winners_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,winners from base where winners>0 order by winners desc,current_rank asc limit 1) x),
    'titles_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,titles from base where titles>0 order by titles desc,wins desc,current_rank asc limit 1) x)
  ) into v_records;

  with tr as (select * from public.statistics_tournament_period_rows_internal_v1(v_world,v_period,v_season)), ranked as (
    select tr.*,row_number() over(order by tr.completed_matches desc,tr.total_winners desc,tr.tournament_name)::integer stats_rank from tr
  ) select coalesce(jsonb_agg(to_jsonb(x) order by x.stats_rank),'[]'::jsonb) into v_tournaments from (select * from ranked order by stats_rank limit 50) x;

  select coalesce(jsonb_agg(jsonb_build_object('surface',surface,'matches',matches,'wins',wins,'losses',losses,'win_pct',case when matches>0 then round((100.0*wins/matches)::numeric,1) else 0 end) order by case surface when 'hard' then 1 when 'clay' then 2 when 'grass' then 3 else 4 end),'[]'::jsonb)
  into v_surfaces
  from (select f.surface,count(*)::integer matches,count(*) filter(where f.won)::integer wins,count(*) filter(where not f.won)::integer losses from public.statistics_player_match_facts_v1 f where f.player_id=v_player group by f.surface) s;

  select coalesce(jsonb_agg(jsonb_build_object('category_code',category_code,'tournaments',tournaments,'matches',matches,'wins',wins,'losses',losses,'titles',titles,'win_pct',case when matches>0 then round((100.0*wins/matches)::numeric,1) else 0 end) order by tournaments desc,category_code),'[]'::jsonb)
  into v_categories
  from (
    select f.category_code,count(distinct f.competition_id)::integer tournaments,count(*)::integer matches,count(*) filter(where f.won)::integer wins,count(*) filter(where not f.won)::integer losses,count(*) filter(where f.won and lower(f.round_label)='final')::integer titles
    from public.statistics_player_match_facts_v1 f where f.player_id=v_player group by f.category_code
  ) c;

  select coalesce(jsonb_agg(jsonb_build_object('season',season,'matches',matches,'wins',wins,'losses',losses,'titles',titles,'win_pct',case when matches>0 then round((100.0*wins/matches)::numeric,1) else 0 end) order by season desc),'[]'::jsonb)
  into v_seasons
  from (
    select f.season,count(*)::integer matches,count(*) filter(where f.won)::integer wins,count(*) filter(where not f.won)::integer losses,count(*) filter(where f.won and lower(f.round_label)='final')::integer titles
    from public.statistics_player_match_facts_v1 f where f.player_id=v_player group by f.season
  ) s;

  with me as (select * from public.statistics_player_period_rows_internal_v1(v_player_world,'all_time',v_season) where player_id=v_player),
  ranks as (select min(ranking_position)::integer best_rank,max(ranking_points)::integer best_points from public.player_ranking_snapshots where player_id=v_player),
  money as (select coalesce(sum(amount) filter(where category='prize_money' and amount>0),0)::bigint prize_money from public.career_finance_transactions where player_id=v_player)
  select jsonb_build_object(
    'player',(select to_jsonb(m) from me m),
    'best_rank',(select best_rank from ranks),
    'best_ranking_points',(select best_points from ranks),
    'career_prize_money',(select prize_money from money),
    'surface_records',v_surfaces,
    'category_records',v_categories,
    'season_records',v_seasons
  ) into v_career;

  return jsonb_build_object('world',v_world,'period',v_period,'season',v_season,'current_absolute_day',v_abs,'records',v_records,'players',v_players,'tournaments',v_tournaments,'career',v_career);
end; $$;
revoke all on function public.get_world_statistics_v1(text,text) from public, anon;
grant execute on function public.get_world_statistics_v1(text,text) to authenticated;
