with palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
  limit 1
), r1 as (
  select m.*,
    case when m.match_number in (4,6,9,12,14,16) then m.player2_id else m.player1_id end winner,
    case when m.match_number in (4,6,9,12,14,16) then m.player1_id else m.player2_id end loser
  from public.tournament_matches m join palm p on p.competition_id=m.competition_id
  where m.draw_type='main_draw' and m.round_number=1
)
update public.tournament_matches m
set winner_id=r.winner,status='completed',started_at=coalesce(m.started_at,now()),completed_at=coalesce(m.completed_at,now()),updated_at=now()
from r1 r where m.id=r.id;

with palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
  limit 1
), r1 as (
  select m.id,m.match_number,m.player1_id,m.player2_id,m.winner_id,(m.winner_id=m.player1_id) p1_won
  from public.tournament_matches m join palm p on p.competition_id=m.competition_id
  where m.draw_type='main_draw' and m.round_number=1
), patterns as (
  select r1.*,
    case
      when match_number=1 then array[[6,4],[3,6],[6,2]]::int[][]
      when match_number%4=1 then case when p1_won then array[[6,4],[6,3]]::int[][] else array[[4,6],[3,6]]::int[][] end
      when match_number%4=2 then case when p1_won then array[[7,5],[6,4]]::int[][] else array[[5,7],[4,6]]::int[][] end
      when match_number%4=3 then case when p1_won then array[[6,2],[4,6],[6,3]]::int[][] else array[[2,6],[6,4],[3,6]]::int[][] end
      else case when p1_won then array[[6,3],[6,4]]::int[][] else array[[3,6],[4,6]]::int[][] end
    end scores
  from r1
), set_rows as (
  select p.id match_id,gs set_number,p.scores[gs][1] p1_games,p.scores[gs][2] p2_games
  from patterns p cross join lateral generate_series(1,array_length(p.scores,1)) gs
)
insert into public.tournament_match_sets(match_id,set_number,player1_games,player2_games,status,updated_at)
select match_id,set_number,p1_games,p2_games,'completed',now() from set_rows
on conflict(match_id,set_number) do update set player1_games=excluded.player1_games,player2_games=excluded.player2_games,status='completed',updated_at=now();

with palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
  limit 1
), r1 as (
  select m.id,m.match_number,m.player1_id,m.player2_id,m.winner_id
  from public.tournament_matches m join palm p on p.competition_id=m.competition_id
  where m.draw_type='main_draw' and m.round_number=1
), stat_rows as (
  select id match_id,player1_id player_id,(winner_id=player1_id) won,match_number,1 side from r1
  union all
  select id,player2_id,(winner_id=player2_id),match_number,2 from r1
)
insert into public.tournament_match_player_stats(
  match_id,player_id,aces,double_faults,first_serves_in,first_serves_total,
  first_serve_points_won,first_serve_points_played,second_serve_points_won,second_serve_points_played,
  break_points_won,break_points_total,winners,unforced_errors,total_points_won,updated_at
)
select match_id,player_id,
  (3 + (match_number*side)%9 + case when won then 2 else 0 end),
  (1 + (match_number+side)%4),
  (38 + (match_number*3+side)%15),
  (58 + (match_number*2+side)%12),
  (25 + (match_number*2+side)%12 + case when won then 5 else 0 end),
  (38 + (match_number*3+side)%15),
  (12 + (match_number+side)%9 + case when won then 3 else 0 end),
  (20 + (match_number*2+side)%10),
  (2 + (match_number+side)%4 + case when won then 1 else 0 end),
  (6 + (match_number+side)%5),
  (18 + (match_number*3+side)%17 + case when won then 6 else 0 end),
  (15 + (match_number*2+side)%14 + case when won then 0 else 4 end),
  (62 + (match_number*4+side)%21 + case when won then 12 else 0 end),
  now()
from stat_rows
on conflict(match_id,player_id) do update set
  aces=excluded.aces,double_faults=excluded.double_faults,first_serves_in=excluded.first_serves_in,first_serves_total=excluded.first_serves_total,
  first_serve_points_won=excluded.first_serve_points_won,first_serve_points_played=excluded.first_serve_points_played,
  second_serve_points_won=excluded.second_serve_points_won,second_serve_points_played=excluded.second_serve_points_played,
  break_points_won=excluded.break_points_won,break_points_total=excluded.break_points_total,winners=excluded.winners,
  unforced_errors=excluded.unforced_errors,total_points_won=excluded.total_points_won,updated_at=now();

with palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
  limit 1
), r1 as (
  select m.competition_id,m.match_number,m.winner_id,case when m.winner_id=m.player1_id then m.player2_id else m.player1_id end loser_id
  from public.tournament_matches m join palm p on p.competition_id=m.competition_id
  where m.draw_type='main_draw' and m.round_number=1
)
update public.tournament_entries e set entry_status='eliminated',updated_at=now()
from r1 where e.competition_id=r1.competition_id and e.player_id=r1.loser_id;

with palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
  limit 1
), winners as (
  select m.competition_id,m.match_number,m.winner_id
  from public.tournament_matches m join palm p on p.competition_id=m.competition_id
  where m.draw_type='main_draw' and m.round_number=1 and m.status='completed'
), r16 as (
  select p.competition_id,gs::smallint match_number,w1.winner_id player1_id,w2.winner_id player2_id
  from palm p cross join generate_series(1,8) gs
  join winners w1 on w1.competition_id=p.competition_id and w1.match_number=gs*2-1
  join winners w2 on w2.competition_id=p.competition_id and w2.match_number=gs*2
)
insert into public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,status,updated_at)
select competition_id,'main_draw',2,'Round of 16',match_number,32,3,4,player1_id,player2_id,'scheduled',now() from r16
on conflict(competition_id,draw_type,round_number,match_number) do update set
  player1_id=excluded.player1_id,player2_id=excluded.player2_id,status='scheduled',winner_id=null,started_at=null,completed_at=null,updated_at=now();
