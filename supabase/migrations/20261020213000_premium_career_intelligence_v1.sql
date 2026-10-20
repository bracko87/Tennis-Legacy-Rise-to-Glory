-- Career Intelligence v1. Read-only, owner and Premium gated.
-- Does not create ranking snapshots, process matches, or grant achievements.
create or replace function public.get_premium_career_intelligence_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer set search_path='public','pg_temp'
as $fn$
declare
 v_player public.players%rowtype;
 v_season integer;
 v_abs integer;
 v_weeks jsonb;
 v_seasons jsonb;
 v_surfaces jsonb;
 v_milestones jsonb;
 v_season_count integer;
 v_first_win jsonb;
 v_first_match jsonb;
 v_first_final jsonb;
 v_first_title jsonb;
 v_first_top100 jsonb;
 v_first_top50 jsonb;
 v_first_top10 jsonb;
 v_first_no1 jsonb;
begin
 if auth.uid() is null or not public.has_active_premium_v1() then
   raise exception 'Premium membership required' using errcode='42501';
 end if;
 select * into v_player from public.players p where p.id=p_player_id
   and p.owner_user_id=auth.uid() and p.player_type='human'
   and p.moderation_status<>'rejected';
 if not found then
   raise exception 'Career report restricted to your own player' using errcode='42501';
 end if;
 select g.season,public.game_day_absolute_v1(g.season,g.month,g.day)
   into v_season,v_abs from public.get_current_game_day_internal_v1() g;

 -- One most-recent ranking snapshot per recorded game week, newest 24 samples.
 -- Values are history, not reconstructed dates or inferred missing positions.
 with observed as (
   select s.season,
     greatest(1,least(52,1+floor((
       s.game_absolute_day-public.game_day_absolute_v1(s.season,1::smallint,2::smallint)
     )::numeric/7)::integer)) game_week,
     s.game_absolute_day,s.ranking_position,s.ranking_points
   from public.player_ranking_snapshots s where s.player_id=p_player_id
     and s.game_absolute_day<=v_abs
 ), latest as (
   select distinct on (season,game_week)
     season,game_week,game_absolute_day,ranking_position,ranking_points
   from observed
   order by season,game_week,game_absolute_day desc
 ), recent as (
   select * from latest order by season desc,game_week desc limit 24
 )
 select coalesce(jsonb_agg(jsonb_build_object(
    'season',season,'game_week',game_week,'absolute_day',game_absolute_day,
    'rank',ranking_position,'points',ranking_points
 ) order by season,game_week),'[]'::jsonb)
 into v_weeks from recent;

 -- Aggregated insights are additive to the Free season totals, not a second career table.
 with match_seasons as (
   select f.season,count(*)::int matches,count(*) filter(where f.won)::int wins,
     count(*) filter(where not f.won)::int losses,
     count(*) filter(where f.won and lower(f.round_label)='final')::int titles,
     count(*) filter(where lower(f.round_label)='final')::int finals,
     count(distinct f.competition_id)::int competitions,
     coalesce(round(100*count(*) filter(where f.won)::numeric/nullif(count(*),0),1),0) win_pct
   from public.statistics_player_match_facts_v1 f
   where f.player_id=p_player_id and f.season<=v_season group by f.season
 ), rank_seasons as (
   select season,min(ranking_position)::int best_rank,
     max(ranking_points)::int peak_ranking_points,
     (array_agg(ranking_position order by game_absolute_day desc))[1]::int last_observed_rank,
     count(*)::int ranking_snapshots
   from public.player_ranking_snapshots
   where player_id=p_player_id and season<=v_season and game_absolute_day<=v_abs
   group by season
 ), result_seasons as (
   select e.season_number season,
     count(*) filter(where tr.result_code='champion')::int confirmed_titles,
     count(*) filter(where tr.result_code='runner_up')::int confirmed_runner_up,
     coalesce(sum(tr.prize_money_earned),0)::bigint recorded_prize_usd,
     coalesce(sum(tr.ranking_points_earned),0)::bigint recorded_tournament_points
   from public.player_tournament_results tr
   join public.tournament_world_competitions wc on wc.id=tr.competition_id
   join public.tournament_editions e on e.id=wc.tournament_edition_id
   where tr.player_id=p_player_id and e.season_number<=v_season
   group by e.season_number
 ), all_seasons as (
   select season from match_seasons union
   select season from rank_seasons union select season from result_seasons
 ), combined as (
   select y.season,coalesce(m.matches,0) matches,coalesce(m.wins,0) wins,
     coalesce(m.losses,0) losses,coalesce(m.titles,0) on_court_titles,
     coalesce(m.finals,0) finals,coalesce(m.competitions,0) competitions,
     m.win_pct,r.best_rank,r.peak_ranking_points,r.last_observed_rank,
     coalesce(r.ranking_snapshots,0) rank_samples,
     coalesce(t.confirmed_titles,0) confirmed_titles,
     coalesce(t.confirmed_runner_up,0) confirmed_runner_up,
     coalesce(t.recorded_prize_usd,0) recorded_prize_usd,
     coalesce(t.recorded_tournament_points,0) recorded_tournament_points,
     lag(m.win_pct) over(order by y.season) previous_win_pct,
     lag(r.best_rank) over(order by y.season) previous_best_rank
   from all_seasons y left join match_seasons m on m.season=y.season
     left join rank_seasons r on r.season=y.season
     left join result_seasons t on t.season=y.season
 ), newest as (
   select * from combined order by season desc limit 12
 )
 select count(*)::int,
   coalesce(jsonb_agg(jsonb_build_object(
     'season',season,'matches',matches,'wins',wins,'losses',losses,
     'win_pct',win_pct,'finals',finals,'competitions',competitions,
     'on_court_titles',on_court_titles,'confirmed_titles',confirmed_titles,
     'confirmed_runner_up',confirmed_runner_up,'best_rank',best_rank,
     'peak_ranking_points',peak_ranking_points,
     'last_observed_rank',last_observed_rank,'ranking_snapshots',rank_samples,
     'recorded_prize_usd',recorded_prize_usd,
     'recorded_tournament_points',recorded_tournament_points,
     'win_rate_change_pp',case when win_pct is not null and previous_win_pct is not null
       then round(win_pct-previous_win_pct,1) else null end,
     'best_rank_change',case when best_rank is not null and previous_best_rank is not null
       then previous_best_rank-best_rank else null end
   ) order by season),'[]'::jsonb)
 into v_season_count,v_seasons from newest;

 -- Advanced surface-by-season insight, unlike Free all-career surface totals.
 with x as (
   select f.season,f.surface,count(*)::int matches,
     count(*) filter(where f.won)::int wins,
     count(*) filter(where not f.won)::int losses
   from public.statistics_player_match_facts_v1 f
   where f.player_id=p_player_id and f.season<=v_season
   group by f.season,f.surface
 )
 select coalesce(jsonb_agg(jsonb_build_object(
   'season',season,'surface',surface,'matches',matches,'wins',wins,'losses',losses,
   'win_pct',round(100*wins::numeric/nullif(matches,0),1)
 ) order by season,surface),'[]'::jsonb) into v_surfaces from x;

 select jsonb_build_object('kind','first_match','season',season,
   'game_week',scheduled_season_week,'name',tournament_name)
 into v_first_match from public.statistics_player_match_facts_v1 f
 where f.player_id=p_player_id
 order by season,scheduled_season_week,scheduled_day,match_id limit 1;
 select jsonb_build_object('kind','first_win','season',season,
   'game_week',scheduled_season_week,'name',tournament_name)
 into v_first_win from public.statistics_player_match_facts_v1 f
 where f.player_id=p_player_id and f.won
 order by season,scheduled_season_week,scheduled_day,match_id limit 1;
 select jsonb_build_object('kind','first_final','season',season,
   'game_week',scheduled_season_week,'name',tournament_name)
 into v_first_final from public.statistics_player_match_facts_v1 f
 where f.player_id=p_player_id and lower(f.round_label)='final'
 order by season,scheduled_season_week,scheduled_day,match_id limit 1;

 with finals as (
   select e.season_number season,
     min(sl.season_week)::integer game_week,ts.name
   from public.player_tournament_results tr
   join public.tournament_world_competitions wc on wc.id=tr.competition_id
   join public.tournament_editions e on e.id=wc.tournament_edition_id
   join public.tournament_series ts on ts.id=e.tournament_series_id
   join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
   where tr.player_id=p_player_id and tr.result_code='champion'
   group by tr.id,e.season_number,ts.name
 )
 select jsonb_build_object('kind','first_title','season',season,
   'game_week',game_week,'name',name)
 into v_first_title from finals order by season,game_week,name limit 1;

 select jsonb_build_object('kind','top_100','season',season,
   'game_week',greatest(1,least(52,1+floor(
     (game_absolute_day-public.game_day_absolute_v1(season,1::smallint,2::smallint))::numeric/7
   )::integer)),'rank',ranking_position)
 into v_first_top100 from public.player_ranking_snapshots
 where player_id=p_player_id and ranking_position<=100 and game_absolute_day<=v_abs
 order by game_absolute_day,id limit 1;
 select jsonb_build_object('kind','top_50','season',season,
   'game_week',greatest(1,least(52,1+floor(
     (game_absolute_day-public.game_day_absolute_v1(season,1::smallint,2::smallint))::numeric/7
   )::integer)),'rank',ranking_position)
 into v_first_top50 from public.player_ranking_snapshots
 where player_id=p_player_id and ranking_position<=50 and game_absolute_day<=v_abs
 order by game_absolute_day,id limit 1;
 select jsonb_build_object('kind','top_10','season',season,
   'game_week',greatest(1,least(52,1+floor(
     (game_absolute_day-public.game_day_absolute_v1(season,1::smallint,2::smallint))::numeric/7
   )::integer)),'rank',ranking_position)
 into v_first_top10 from public.player_ranking_snapshots
 where player_id=p_player_id and ranking_position<=10 and game_absolute_day<=v_abs
 order by game_absolute_day,id limit 1;
 select jsonb_build_object('kind','world_no_1','season',season,
   'game_week',greatest(1,least(52,1+floor(
     (game_absolute_day-public.game_day_absolute_v1(season,1::smallint,2::smallint))::numeric/7
   )::integer)),'rank',ranking_position)
 into v_first_no1 from public.player_ranking_snapshots
 where player_id=p_player_id and ranking_position=1 and game_absolute_day<=v_abs
 order by game_absolute_day,id limit 1;

 select coalesce(jsonb_agg(m),'[]'::jsonb) into v_milestones
 from (select unnest(array[v_first_match,v_first_win,v_first_final,v_first_title,
       v_first_top100,v_first_top50,v_first_top10,v_first_no1]) m) q
 where m is not null;

 return jsonb_build_object(
   'player_id',p_player_id,'world',v_player.world,'current_season',v_season,
   'current_absolute_day',v_abs,'season_count',v_season_count,
   'seasons',v_seasons,'surfaces_by_season',v_surfaces,
   'ranking_weeks',v_weeks,'milestones',v_milestones,
   'methodology','Season comparisons are based on completed official singles matches, results and observed rankings only. Win-rate change is percentage points versus the previous season with match data; ranking comparison is best observed rank. Missing weeks and seasons are never backfilled. Ranking milestone dates are first OBSERVED qualifying snapshots, not proven exact dates when threshold crossed. Prize money and points from result records are recorded earnings, not current live ranking score, net income or guaranteed payments. First-final milestones use completed final-round match facts. Tournament championship milestones come only from confirmed tournament results. No skill improvement can be inferred or awarded by this report.'
 );
end;
$fn$;
revoke all on function public.get_premium_career_intelligence_v1(uuid) from public,anon,authenticated;
grant execute on function public.get_premium_career_intelligence_v1(uuid) to authenticated;
