with week3_competitions as (
  select wc.id competition_id, s.name tournament_name
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1
    and exists(select 1 from public.tournament_schedule_slots ss where ss.tournament_edition_id=ed.id and ss.season_week=3)
), ranked_all as (
  select p.id player_id,p.player_type,p.owner_user_id,p.first_name,p.last_name,
    coalesce(r.ranking_points,0)::integer ranking_points,
    row_number() over(order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc)::integer global_rank
  from public.players p
  left join public.player_rankings r on r.player_id=p.id
  where p.world='ATP' and p.moderation_status <> 'rejected'
), ranked_ai as (
  select ra.*,row_number() over(order by ra.global_rank)::integer ai_rank
  from ranked_all ra where ra.player_type='ai'
), assigned_ai as (
  select ra.*,
    case
      when ai_rank between 1 and 128 then 'Australian Grand Slam'
      when ai_rank between 129 and 160 then 'Oeiras Challenger'
      when ai_rank between 161 and 191 then 'Palm Springs Challenger'
      when ai_rank between 192 and 210 then 'Phan Thiết Challenger'
      when ai_rank between 211 and 229 then 'Itajaí Challenger'
      when ai_rank between 230 and 247 then 'Soma Bay Challenger'
      when ai_rank between 248 and 265 then 'Monastir Futures'
      when ai_rank between 266 and 283 then 'Antalya Futures'
      when ai_rank between 284 and 300 then 'Santiago Futures'
    end tournament_name
  from ranked_ai ra
)
insert into public.tournament_entries(competition_id,player_id,world,draw_type,entry_status,entry_source,ranking_position_snapshot)
select wc.competition_id,aa.player_id,'ATP','main_draw','active','week3_test_ai',aa.global_rank
from assigned_ai aa join week3_competitions wc on wc.tournament_name=aa.tournament_name
where aa.tournament_name is not null;

with ranked_all as (
  select p.id player_id,p.owner_user_id,p.first_name,p.last_name,
    coalesce(r.ranking_points,0)::integer ranking_points,
    row_number() over(order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc)::integer global_rank
  from public.players p
  left join public.player_rankings r on r.player_id=p.id
  where p.world='ATP' and p.moderation_status <> 'rejected'
), user_player as (
  select * from ranked_all where first_name='Aleksandar' and last_name='Levnajic' and owner_user_id is not null limit 1
), palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
    and exists(select 1 from public.tournament_schedule_slots ss where ss.tournament_edition_id=ed.id and ss.season_week=3)
  limit 1
)
insert into public.tournament_entries(competition_id,player_id,world,draw_type,entry_status,entry_source,ranking_position_snapshot)
select palm.competition_id,up.player_id,'ATP','main_draw','active','week3_test_user',up.global_rank
from palm cross join user_player up;

with ranked_all as (
  select p.id player_id,p.owner_user_id,p.first_name,p.last_name,
    coalesce(r.ranking_points,0)::integer ranking_points,
    row_number() over(order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc)::integer global_rank
  from public.players p
  left join public.player_rankings r on r.player_id=p.id
  where p.world='ATP' and p.moderation_status <> 'rejected'
), user_player as (
  select * from ranked_all where first_name='Aleksandar' and last_name='Levnajic' and owner_user_id is not null limit 1
), palm as (
  select wc.id competition_id
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc.world='ATP' and ed.season_number=1 and s.name='Palm Springs Challenger'
    and exists(select 1 from public.tournament_schedule_slots ss where ss.tournament_edition_id=ed.id and ss.season_week=3)
  limit 1
)
insert into public.tournament_applications(competition_id,player_id,owner_user_id,world,status,ranking_position_snapshot,ranking_points_snapshot)
select palm.competition_id,up.player_id,up.owner_user_id,'ATP','applied',up.global_rank,up.ranking_points
from palm cross join user_player up
on conflict (competition_id,player_id) do update set status='applied',ranking_position_snapshot=excluded.ranking_position_snapshot,ranking_points_snapshot=excluded.ranking_points_snapshot,updated_at=now();

with ranked_entries as (
  select e.id,e.competition_id,
    row_number() over(partition by e.competition_id order by e.ranking_position_snapshot nulls last,e.player_id)::integer local_rank,
    count(*) over(partition by e.competition_id)::integer field_count,
    c.main_draw_capacity::integer bracket_size,
    case when c.main_draw_capacity>=128 then 32 else 8 end::integer seed_limit
  from public.tournament_entries e
  join public.tournament_world_competitions wc on wc.id=e.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  join public.tournament_categories c on c.code=s.category_code
  where ed.season_number=1 and wc.world='ATP' and e.entry_source in ('week3_test_ai','week3_test_user')
), positioned as (
  select re.*,
    case
      when re.local_rank <= re.bracket_size-re.field_count then (re.local_rank*2-1)::smallint
      when re.local_rank <= (re.bracket_size-re.field_count)+(re.field_count-re.bracket_size/2)
        then (((re.bracket_size-re.field_count)+(re.local_rank-(re.bracket_size-re.field_count)))*2-1)::smallint
      else (((re.bracket_size-re.field_count)+(re.field_count-re.local_rank+1))*2)::smallint
    end bracket_slot,
    case when re.local_rank<=re.seed_limit then re.local_rank::smallint else null end seed_number
  from ranked_entries re
)
update public.tournament_entries e
set bracket_slot=p.bracket_slot,seed_number=p.seed_number,updated_at=now()
from positioned p where p.id=e.id;

with competition_meta as (
  select wc.id competition_id,c.main_draw_capacity::integer bracket_size,ss.season_week,
    case when ss.phase='main_draw' then 1 else 1+c.qualification_rounds_max end::smallint main_draw_start_day,
    case when c.main_draw_capacity=128 then 'Round of 128' else 'Round of 32' end round_label
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  join public.tournament_categories c on c.code=s.category_code
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id and ss.season_week=3
  where wc.world='ATP' and ed.season_number=1
), match_slots as (
  select cm.*,gs::smallint match_number from competition_meta cm cross join lateral generate_series(1,cm.bracket_size/2) gs
), paired as (
  select ms.competition_id,ms.bracket_size,ms.season_week,ms.main_draw_start_day,ms.round_label,ms.match_number,
    ((min(e.player_id::text) filter(where e.bracket_slot=ms.match_number*2-1))::uuid) player1_id,
    ((min(e.player_id::text) filter(where e.bracket_slot=ms.match_number*2))::uuid) player2_id
  from match_slots ms
  left join public.tournament_entries e on e.competition_id=ms.competition_id and e.draw_type='main_draw' and e.entry_source in ('week3_test_ai','week3_test_user')
  group by ms.competition_id,ms.bracket_size,ms.season_week,ms.main_draw_start_day,ms.round_label,ms.match_number
)
insert into public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,player1_id,player2_id,status)
select competition_id,'main_draw',1,round_label,match_number,bracket_size,season_week,main_draw_start_day,player1_id,player2_id,
  case when player1_id is not null and player2_id is not null then 'scheduled'
       when player1_id is not null or player2_id is not null then 'bye'
       else 'cancelled' end
from paired;
