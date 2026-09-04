-- Realistic tournament draw foundation v1
update public.tournament_categories set qualifying_capacity_max=128, default_qualifier_slots=16, qualification_rounds_max=3 where code='grand_slam_2000';
update public.tournament_categories set qualifying_capacity_max=32, default_qualifier_slots=8, qualification_rounds_max=2 where code='masters_1000';
update public.tournament_categories set qualifying_capacity_max=16, default_qualifier_slots=4, qualification_rounds_max=2 where code in ('tour_500','tour_250');

update public.tournament_ranking_point_rules set points=8,stage_label='Qualifying Round 2' where category_code='grand_slam_2000' and stage_code='qualifying_round_2_loss';
delete from public.tournament_ranking_point_rules where category_code='grand_slam_2000' and stage_code='qualifying_round_3_loss';
delete from public.tournament_ranking_point_rules where category_code='masters_1000' and stage_code in ('qualifying_round_2_loss','qualifying_round_3_loss');

update public.tournament_prize_stage_weights set finisher_count=4 where category_code in ('tour_250','tour_500') and stage_code='qualifying_final_loss';
update public.tournament_prize_stage_weights set finisher_count=8 where category_code in ('tour_250','tour_500') and stage_code='qualifying_round_1_loss';
update public.tournament_prize_stage_weights set finisher_count=8 where category_code='masters_1000' and stage_code='qualifying_final_loss';
update public.tournament_prize_stage_weights set finisher_count=16 where category_code='masters_1000' and stage_code='qualifying_round_1_loss';
delete from public.tournament_prize_stage_weights where category_code='masters_1000' and stage_code in ('qualifying_round_2_loss','qualifying_round_3_loss');
update public.tournament_prize_stage_weights set finisher_count=16 where category_code='grand_slam_2000' and stage_code='qualifying_final_loss';
update public.tournament_prize_stage_weights set finisher_count=32 where category_code='grand_slam_2000' and stage_code='qualifying_round_2_loss';
update public.tournament_prize_stage_weights set finisher_count=64 where category_code='grand_slam_2000' and stage_code='qualifying_round_1_loss';
delete from public.tournament_prize_stage_weights where category_code='grand_slam_2000' and stage_code='qualifying_round_3_loss';

truncate public.tournament_prize_payouts;
with weighted as (
  select ts.id tournament_series_id,p.announced_pool_usd,r.payout_rounding_usd,w.stage_code,w.stage_label,w.draw_type,w.finisher_count,w.weight,w.sort_order,
         sum(w.weight*w.finisher_count) over(partition by ts.id) total_weight
  from public.tournament_series ts
  join public.tournament_prize_pools p on p.tournament_series_id=ts.id
  join public.tournament_prize_pool_rules r on r.category_code=ts.category_code
  join public.tournament_prize_stage_weights w on w.category_code=ts.category_code
),calc as (
  select *,case when stage_code='winner' then 0::bigint else (round(((announced_pool_usd*weight/total_weight)/payout_rounding_usd))*payout_rounding_usd)::bigint end payout from weighted
),sums as (
  select tournament_series_id,announced_pool_usd,sum(payout*finisher_count) nonwinner_total from calc group by tournament_series_id,announced_pool_usd
)
insert into public.tournament_prize_payouts(tournament_series_id,stage_code,stage_label,draw_type,finisher_count,payout_per_player_usd,sort_order)
select c.tournament_series_id,c.stage_code,c.stage_label,c.draw_type,c.finisher_count,case when c.stage_code='winner' then (s.announced_pool_usd-s.nonwinner_total)::bigint else c.payout end,c.sort_order from calc c join sums s using(tournament_series_id);
update public.tournament_prize_pools p set distributed_pool_usd=x.total,updated_at=now() from (select tournament_series_id,sum(finisher_count*payout_per_player_usd)::bigint total from public.tournament_prize_payouts group by tournament_series_id)x where x.tournament_series_id=p.tournament_series_id;

create table if not exists public.tournament_draw_seed_groups(draw_size smallint not null,group_no smallint not null,seed_start smallint not null,seed_end smallint not null,primary key(draw_size,group_no),check(seed_start>0 and seed_end>=seed_start));
create table if not exists public.tournament_draw_seed_slots(draw_size smallint not null,group_no smallint not null,bracket_slot smallint not null,primary key(draw_size,bracket_slot),foreign key(draw_size,group_no) references public.tournament_draw_seed_groups(draw_size,group_no) on delete cascade);
truncate public.tournament_draw_seed_slots,public.tournament_draw_seed_groups cascade;
insert into public.tournament_draw_seed_groups(draw_size,group_no,seed_start,seed_end) values
(32,1,1,1),(32,2,2,2),(32,3,3,4),(32,4,5,8),
(64,1,1,1),(64,2,2,2),(64,3,3,4),(64,4,5,8),(64,5,9,12),(64,6,13,16),
(128,1,1,1),(128,2,2,2),(128,3,3,4),(128,4,5,8),(128,5,9,12),(128,6,13,16),(128,7,17,24),(128,8,25,32);
insert into public.tournament_draw_seed_slots(draw_size,group_no,bracket_slot) values
(32,1,1),(32,2,32),(32,3,9),(32,3,24),(32,4,8),(32,4,16),(32,4,17),(32,4,25),
(64,1,1),(64,2,64),(64,3,17),(64,3,48),(64,4,16),(64,4,32),(64,4,33),(64,4,49),(64,5,9),(64,5,25),(64,5,40),(64,5,56),(64,6,8),(64,6,24),(64,6,41),(64,6,57),
(128,1,1),(128,2,128),(128,3,33),(128,3,96),(128,4,32),(128,4,64),(128,4,65),(128,4,97),(128,5,17),(128,5,49),(128,5,80),(128,5,112),(128,6,16),(128,6,48),(128,6,81),(128,6,113),(128,7,9),(128,7,25),(128,7,41),(128,7,57),(128,7,72),(128,7,88),(128,7,104),(128,7,120),(128,8,8),(128,8,24),(128,8,40),(128,8,56),(128,8,73),(128,8,89),(128,8,105),(128,8,121);

create table if not exists public.tournament_draw_publications(competition_id uuid primary key references public.tournament_world_competitions(id) on delete cascade,ranking_snapshot_absolute_day integer not null,main_draw_size smallint not null,main_seed_count smallint not null,qualifying_draw_size smallint not null,qualifying_seed_count smallint not null,qualifier_slots smallint not null,randomization_key text not null,published_at timestamptz not null default now());
create table if not exists public.tournament_qualifier_slots(competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,section_number smallint not null,bracket_slot smallint not null,filled_player_id uuid references public.players(id) on delete set null,resolved boolean not null default false,primary key(competition_id,section_number),unique(competition_id,bracket_slot));
create unique index if not exists tournament_qualifier_slots_filled_unique on public.tournament_qualifier_slots(competition_id,filled_player_id) where filled_player_id is not null;
revoke all on public.tournament_draw_seed_groups,public.tournament_draw_seed_slots,public.tournament_draw_publications,public.tournament_qualifier_slots from public,anon,authenticated;

create or replace function public.tournament_round_label_v1(p_draw_type text,p_bracket_size integer,p_round_number integer,p_qualification_rounds integer default null) returns text language plpgsql immutable set search_path='public' as $$
declare v_participants integer;
begin
 if p_draw_type='qualification' then if p_round_number=coalesce(p_qualification_rounds,p_round_number) then return 'Final Qualifying Round';end if;return 'Qualifying Round '||p_round_number::text;end if;
 v_participants:=p_bracket_size/(power(2,p_round_number-1)::integer);
 return case v_participants when 2 then 'Final' when 4 then 'Semifinal' when 8 then 'Quarterfinal' else 'Round of '||v_participants::text end;
end;$$;

create or replace function public.resolve_main_first_round_match_v1(p_competition_id uuid,p_match_number integer) returns void language plpgsql security definer set search_path='public' as $$
declare m public.tournament_matches%rowtype;v_left_slot integer;v_right_slot integer;v_left_pending boolean;v_right_pending boolean;v_count integer;
begin
 select * into m from public.tournament_matches where competition_id=p_competition_id and draw_type='main_draw' and round_number=1 and match_number=p_match_number;
 if m.id is null or m.status not in ('scheduled','bye') then return;end if;
 v_left_slot:=p_match_number*2-1;v_right_slot:=p_match_number*2;
 select exists(select 1 from public.tournament_qualifier_slots q where q.competition_id=p_competition_id and q.bracket_slot=v_left_slot and not q.resolved) into v_left_pending;
 select exists(select 1 from public.tournament_qualifier_slots q where q.competition_id=p_competition_id and q.bracket_slot=v_right_slot and not q.resolved) into v_right_pending;
 if v_left_pending or v_right_pending then return;end if;
 v_count:=(case when m.player1_id is not null then 1 else 0 end)+(case when m.player2_id is not null then 1 else 0 end);
 if v_count=1 and m.status='scheduled' then update public.tournament_matches set status='bye',winner_id=coalesce(player1_id,player2_id),completed_at=coalesce(completed_at,now()),updated_at=now() where id=m.id;
 elsif v_count=0 and m.status='scheduled' then update public.tournament_matches set status='cancelled',completed_at=coalesce(completed_at,now()),updated_at=now() where id=m.id;end if;
end;$$;
revoke all on function public.resolve_main_first_round_match_v1(uuid,integer) from public,anon,authenticated;

create or replace function public.advance_tournament_bracket_v1() returns trigger language plpgsql security definer set search_path='public' as $$
declare v_max_round smallint;v_next_no integer;v_next_id uuid;v_next_label text;v_loser uuid;v_target_slot integer;v_target_match integer;v_feeders_done integer;v_next_p1 uuid;v_next_p2 uuid;v_category public.tournament_categories%rowtype;
begin
 if new.status not in ('completed','bye','walkover','cancelled') then return new;end if;
 if tg_op='UPDATE' and old.status is not distinct from new.status then return new;end if;
 select tc.* into v_category from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=ed.tournament_series_id join public.tournament_categories tc on tc.code=ts.category_code where wc.id=new.competition_id;
 v_max_round:=case when new.draw_type='main_draw' then v_category.main_draw_rounds else v_category.qualification_rounds_max end;
 if new.winner_id is not null then v_loser:=case when new.player1_id=new.winner_id then new.player2_id when new.player2_id=new.winner_id then new.player1_id else null end;if v_loser is not null then update public.tournament_entries set entry_status='eliminated',updated_at=now() where competition_id=new.competition_id and player_id=v_loser;end if;end if;
 if new.round_number<v_max_round then
   v_next_no:=(new.match_number+1)/2;select id into v_next_id from public.tournament_matches where competition_id=new.competition_id and draw_type=new.draw_type and round_number=new.round_number+1 and match_number=v_next_no;
   if v_next_id is null then v_next_label:=public.tournament_round_label_v1(new.draw_type,new.bracket_size,new.round_number+1,v_max_round);insert into public.tournament_matches(competition_id,draw_type,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,status) values(new.competition_id,new.draw_type,new.round_number+1,v_next_label,v_next_no,new.bracket_size,new.scheduled_season_week,least(7,new.scheduled_day+1),'scheduled') on conflict(competition_id,draw_type,round_number,match_number) do nothing returning id into v_next_id;if v_next_id is null then select id into v_next_id from public.tournament_matches where competition_id=new.competition_id and draw_type=new.draw_type and round_number=new.round_number+1 and match_number=v_next_no;end if;end if;
   if new.winner_id is not null then if mod(new.match_number,2)=1 then update public.tournament_matches set player1_id=new.winner_id,updated_at=now() where id=v_next_id and player1_id is null;else update public.tournament_matches set player2_id=new.winner_id,updated_at=now() where id=v_next_id and player2_id is null;end if;end if;
   select count(*) into v_feeders_done from public.tournament_matches f where f.competition_id=new.competition_id and f.draw_type=new.draw_type and f.round_number=new.round_number and f.match_number in(v_next_no*2-1,v_next_no*2) and f.status in('completed','bye','walkover','cancelled');
   if v_feeders_done=2 then select player1_id,player2_id into v_next_p1,v_next_p2 from public.tournament_matches where id=v_next_id;if v_next_p1 is null and v_next_p2 is null then update public.tournament_matches set status='cancelled',completed_at=coalesce(completed_at,now()),updated_at=now() where id=v_next_id and status='scheduled';elsif (v_next_p1 is null)<>(v_next_p2 is null) then update public.tournament_matches set status='bye',winner_id=coalesce(v_next_p1,v_next_p2),completed_at=coalesce(completed_at,now()),updated_at=now() where id=v_next_id and status='scheduled';end if;end if;
 else
   if new.draw_type='qualification' then select bracket_slot into v_target_slot from public.tournament_qualifier_slots where competition_id=new.competition_id and section_number=new.match_number;if v_target_slot is not null then update public.tournament_qualifier_slots set resolved=true,filled_player_id=new.winner_id where competition_id=new.competition_id and section_number=new.match_number;if new.winner_id is not null then update public.tournament_entries set draw_type='main_draw',entry_status='active',seed_number=null,bracket_slot=v_target_slot,updated_at=now() where competition_id=new.competition_id and player_id=new.winner_id;v_target_match:=(v_target_slot+1)/2;if mod(v_target_slot,2)=1 then update public.tournament_matches set player1_id=new.winner_id,updated_at=now() where competition_id=new.competition_id and draw_type='main_draw' and round_number=1 and match_number=v_target_match;else update public.tournament_matches set player2_id=new.winner_id,updated_at=now() where competition_id=new.competition_id and draw_type='main_draw' and round_number=1 and match_number=v_target_match;end if;end if;perform public.resolve_main_first_round_match_v1(new.competition_id,(v_target_slot+1)/2);end if;
   elsif new.winner_id is not null then update public.tournament_entries set entry_status='champion',updated_at=now() where competition_id=new.competition_id and player_id=new.winner_id;end if;
 end if;
 return new;
end;$$;
revoke all on function public.advance_tournament_bracket_v1() from public,anon,authenticated;
drop trigger if exists advance_tournament_bracket_v1 on public.tournament_matches;
create trigger advance_tournament_bracket_v1 after insert or update of status on public.tournament_matches for each row execute function public.advance_tournament_bracket_v1();