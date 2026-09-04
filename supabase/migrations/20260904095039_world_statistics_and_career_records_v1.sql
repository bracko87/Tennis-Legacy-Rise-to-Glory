create table if not exists public.player_ranking_snapshots (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  world text not null,
  season integer not null,
  game_absolute_day integer not null,
  ranking_position integer not null check (ranking_position > 0),
  ranking_points integer not null default 0,
  created_at timestamptz not null default now(),
  unique(player_id, game_absolute_day)
);
create index if not exists player_ranking_snapshots_best_idx on public.player_ranking_snapshots(player_id, ranking_position, game_absolute_day);
alter table public.player_ranking_snapshots enable row level security;
revoke all on public.player_ranking_snapshots from anon, authenticated;

create or replace function public.capture_world_ranking_snapshot_internal_v1()
returns void language plpgsql security definer set search_path='public' as $$
declare v_abs integer; v_season integer;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day), d.season into v_abs,v_season from public.get_current_game_day_internal_v1() d;
  insert into public.player_ranking_snapshots(player_id,world,season,game_absolute_day,ranking_position,ranking_points)
  select p.id,p.world,v_season,v_abs,
         row_number() over(partition by p.world order by coalesce(pr.ranking_points,0) desc, coalesce(pr.seed_rating,0) desc, p.id)::integer,
         coalesce(pr.ranking_points,0)
  from public.players p
  left join public.player_rankings pr on pr.player_id=p.id
  where p.world in ('ATP','WTA')
  on conflict(player_id,game_absolute_day) do update set
    world=excluded.world,season=excluded.season,ranking_position=excluded.ranking_position,ranking_points=excluded.ranking_points;
end; $$;
revoke all on function public.capture_world_ranking_snapshot_internal_v1() from public, anon, authenticated;

create or replace view public.statistics_completed_matches_v1 as
select m.id as match_id,m.competition_id,m.round_label,m.round_number,m.scheduled_season_week,m.scheduled_day,
       m.player1_id,m.player2_id,m.winner_id,e.season_number as season,wc.world,
       ts.id as tournament_series_id,ts.name as tournament_name,ts.city,ts.country_code,ts.category_code,ts.surface
from public.tournament_matches m
join public.tournament_world_competitions wc on wc.id=m.competition_id
join public.tournament_editions e on e.id=wc.tournament_edition_id
join public.tournament_series ts on ts.id=e.tournament_series_id
where m.status='completed' and m.winner_id is not null and m.player1_id is not null and m.player2_id is not null;
revoke all on public.statistics_completed_matches_v1 from public, anon, authenticated;

create or replace view public.statistics_player_match_facts_v1 as
select cm.match_id,cm.competition_id,cm.season,cm.world,cm.tournament_series_id,cm.tournament_name,cm.city,cm.country_code,cm.category_code,cm.surface,cm.round_label,cm.round_number,cm.scheduled_season_week,cm.scheduled_day,
       cm.player1_id as player_id,cm.player2_id as opponent_id,(cm.winner_id=cm.player1_id) as won
from public.statistics_completed_matches_v1 cm
union all
select cm.match_id,cm.competition_id,cm.season,cm.world,cm.tournament_series_id,cm.tournament_name,cm.city,cm.country_code,cm.category_code,cm.surface,cm.round_label,cm.round_number,cm.scheduled_season_week,cm.scheduled_day,
       cm.player2_id as player_id,cm.player1_id as opponent_id,(cm.winner_id=cm.player2_id) as won
from public.statistics_completed_matches_v1 cm;
revoke all on public.statistics_player_match_facts_v1 from public, anon, authenticated;

create or replace function public.statistics_player_period_rows_internal_v1(p_world text,p_period text,p_season integer)
returns table(
  player_id uuid,first_name text,last_name text,country_code text,world text,current_rank integer,current_ranking_points integer,
  matches integer,wins integer,losses integer,win_pct numeric,titles integer,finals integer,tournament_appearances integer,
  aces bigint,double_faults bigint,winners bigint,unforced_errors bigint,total_points_won bigint,ranking_points_earned bigint
) language sql stable security definer set search_path='public' as $$
with current_ranked as (
  select p.id,p.first_name,p.last_name,p.country_code,p.world,coalesce(pr.ranking_points,0) ranking_points,
         row_number() over(partition by p.world order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.id)::integer current_rank
  from public.players p left join public.player_rankings pr on pr.player_id=p.id
  where p.world=upper(p_world)
), pm as (
  select f.player_id,count(*)::integer matches,count(*) filter(where f.won)::integer wins,count(*) filter(where not f.won)::integer losses,
         count(*) filter(where f.won and lower(f.round_label)='final')::integer titles,
         count(*) filter(where lower(f.round_label)='final')::integer finals
  from public.statistics_player_match_facts_v1 f
  where f.world=upper(p_world) and (lower(p_period)='all_time' or f.season=p_season)
  group by f.player_id
), ds as (
  select s.player_id,coalesce(sum(s.aces),0)::bigint aces,coalesce(sum(s.double_faults),0)::bigint double_faults,
         coalesce(sum(s.winners),0)::bigint winners,coalesce(sum(s.unforced_errors),0)::bigint unforced_errors,
         coalesce(sum(s.total_points_won),0)::bigint total_points_won
  from public.tournament_match_player_stats s
  join public.statistics_player_match_facts_v1 f on f.match_id=s.match_id and f.player_id=s.player_id
  where f.world=upper(p_world) and (lower(p_period)='all_time' or f.season=p_season)
  group by s.player_id
), apps as (
  select te.player_id,count(distinct te.competition_id)::integer appearances
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  where wc.world=upper(p_world) and (lower(p_period)='all_time' or e.season_number=p_season)
  group by te.player_id
), rp as (
  select r.player_id,coalesce(sum(r.ranking_points_earned),0)::bigint earned
  from public.player_tournament_results r
  join public.tournament_world_competitions wc on wc.id=r.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  where wc.world=upper(p_world) and (lower(p_period)='all_time' or e.season_number=p_season)
  group by r.player_id
)
select cr.id,cr.first_name,cr.last_name,cr.country_code,cr.world,cr.current_rank,cr.ranking_points,
       coalesce(pm.matches,0),coalesce(pm.wins,0),coalesce(pm.losses,0),
       case when coalesce(pm.matches,0)>0 then round((100.0*pm.wins/pm.matches)::numeric,1) else 0::numeric end,
       coalesce(pm.titles,0),coalesce(pm.finals,0),coalesce(apps.appearances,0),
       coalesce(ds.aces,0),coalesce(ds.double_faults,0),coalesce(ds.winners,0),coalesce(ds.unforced_errors,0),coalesce(ds.total_points_won,0),coalesce(rp.earned,0)
from current_ranked cr
left join pm on pm.player_id=cr.id left join ds on ds.player_id=cr.id left join apps on apps.player_id=cr.id left join rp on rp.player_id=cr.id;
$$;
revoke all on function public.statistics_player_period_rows_internal_v1(text,text,integer) from public, anon, authenticated;

create or replace function public.statistics_tournament_period_rows_internal_v1(p_world text,p_period text,p_season integer)
returns table(
  tournament_series_id uuid,tournament_name text,city text,country_code text,category_code text,surface text,
  editions integer,completed_matches integer,unique_players integer,total_aces bigint,total_winners bigint,total_points bigint,
  avg_aces_per_match numeric,avg_winners_per_match numeric,top_player_id uuid,top_player_name text,top_player_wins integer
) language sql stable security definer set search_path='public' as $$
with mf as (
  select * from public.statistics_completed_matches_v1 c
  where c.world=upper(p_world) and (lower(p_period)='all_time' or c.season=p_season)
), agg as (
  select mf.tournament_series_id,max(mf.tournament_name) tournament_name,max(mf.city) city,max(mf.country_code) country_code,
         max(mf.category_code) category_code,max(mf.surface) surface,count(distinct mf.competition_id)::integer editions,
         count(distinct mf.match_id)::integer completed_matches,
         count(distinct x.player_id)::integer unique_players
  from mf cross join lateral (values(mf.player1_id),(mf.player2_id)) x(player_id)
  group by mf.tournament_series_id
), detail as (
  select mf.tournament_series_id,coalesce(sum(s.aces),0)::bigint total_aces,coalesce(sum(s.winners),0)::bigint total_winners,
         coalesce(sum(s.total_points_won),0)::bigint total_points
  from mf join public.tournament_match_player_stats s on s.match_id=mf.match_id
  group by mf.tournament_series_id
), pw as (
  select f.tournament_series_id,f.player_id,count(*) filter(where f.won)::integer wins,
         row_number() over(partition by f.tournament_series_id order by count(*) filter(where f.won) desc,f.player_id)::integer rn
  from public.statistics_player_match_facts_v1 f
  where f.world=upper(p_world) and (lower(p_period)='all_time' or f.season=p_season)
  group by f.tournament_series_id,f.player_id
)
select a.tournament_series_id,a.tournament_name,a.city,a.country_code,a.category_code,a.surface,a.editions,a.completed_matches,a.unique_players,
       coalesce(d.total_aces,0),coalesce(d.total_winners,0),coalesce(d.total_points,0),
       case when a.completed_matches>0 then round((coalesce(d.total_aces,0)::numeric/a.completed_matches),1) else 0::numeric end,
       case when a.completed_matches>0 then round((coalesce(d.total_winners,0)::numeric/a.completed_matches),1) else 0::numeric end,
       pw.player_id,case when p.id is null then null else p.first_name||' '||p.last_name end,pw.wins
from agg a left join detail d on d.tournament_series_id=a.tournament_series_id
left join pw on pw.tournament_series_id=a.tournament_series_id and pw.rn=1
left join public.players p on p.id=pw.player_id;
$$;
revoke all on function public.statistics_tournament_period_rows_internal_v1(text,text,integer) from public, anon, authenticated;

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

  with base as (select * from public.statistics_player_period_rows_internal_v1(v_world,v_period,v_season)), ranked as (
    select b.*,row_number() over(order by b.wins desc,b.titles desc,b.win_pct desc,b.current_rank asc)::integer stats_rank from base b
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by r.stats_rank),'[]'::jsonb) into v_players from (select * from ranked order by stats_rank limit 50) r;

  with base as (select * from public.statistics_player_period_rows_internal_v1(v_world,v_period,v_season))
  select jsonb_build_object(
    'current_world_no1',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,current_rank,current_ranking_points from base order by current_rank limit 1) x),
    'performance_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,wins,losses,win_pct,titles from base order by wins desc,titles desc,win_pct desc,current_rank asc limit 1) x),
    'wins_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,wins from base order by wins desc,current_rank asc limit 1) x),
    'losses_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,losses from base order by losses desc,current_rank asc limit 1) x),
    'win_rate_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,win_pct,matches from base where matches>0 order by win_pct desc,matches desc,current_rank asc limit 1) x),
    'aces_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,aces from base order by aces desc,current_rank asc limit 1) x),
    'winners_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,winners from base order by winners desc,current_rank asc limit 1) x),
    'titles_leader',(select to_jsonb(x) from (select player_id,first_name,last_name,country_code,titles from base order by titles desc,wins desc,current_rank asc limit 1) x)
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
