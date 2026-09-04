create table if not exists public.tournament_prize_pool_rules (
  category_code text primary key references public.tournament_categories(code) on delete cascade,
  min_pool_usd bigint not null check (min_pool_usd > 0),
  max_pool_usd bigint not null check (max_pool_usd >= min_pool_usd),
  pool_rounding_usd integer not null check (pool_rounding_usd > 0),
  payout_rounding_usd integer not null check (payout_rounding_usd > 0),
  updated_at timestamptz not null default now()
);

insert into public.tournament_prize_pool_rules(category_code,min_pool_usd,max_pool_usd,pool_rounding_usd,payout_rounding_usd) values
('futures_15',15000,25000,1000,50),
('futures_25',25000,40000,1000,50),
('challenger_50',55000,75000,1000,100),
('challenger_75',90000,125000,1000,100),
('challenger_100',150000,200000,1000,100),
('challenger_125',190000,250000,1000,100),
('tour_250',550000,950000,10000,500),
('tour_500',1600000,2400000,25000,1000),
('masters_1000',4500000,7500000,50000,2500),
('grand_slam_2000',22000000,35000000,250000,5000)
on conflict(category_code) do update set min_pool_usd=excluded.min_pool_usd,max_pool_usd=excluded.max_pool_usd,pool_rounding_usd=excluded.pool_rounding_usd,payout_rounding_usd=excluded.payout_rounding_usd,updated_at=now();

create table if not exists public.tournament_ranking_point_rules (
  category_code text not null references public.tournament_categories(code) on delete cascade,
  stage_code text not null,
  stage_label text not null,
  draw_type text not null check (draw_type in ('main_draw','qualification','bonus')),
  points integer not null check (points >= 0),
  points_are_bonus boolean not null default false,
  sort_order integer not null,
  primary key(category_code,stage_code)
);
truncate public.tournament_ranking_point_rules;
with base(category_code,w,f,sf,qf,r16,r32,r64,r128,q_bonus,fq_loss,q3_loss,q2_loss,q1_loss) as (
  values
  ('futures_15',15,8,4,2,1,0,null::int,null::int,0,0,0,0,0),
  ('futures_25',25,14,7,3,1,0,null::int,null::int,0,0,0,0,0),
  ('challenger_50',50,25,14,8,4,0,null::int,null::int,3,1,0,0,0),
  ('challenger_75',75,44,22,12,6,0,null::int,null::int,4,2,0,0,0),
  ('challenger_100',100,50,25,14,7,0,null::int,null::int,4,2,0,0,0),
  ('challenger_125',125,64,35,16,8,0,null::int,null::int,5,3,0,0,0),
  ('tour_250',250,165,100,50,25,0,null::int,null::int,13,7,0,0,0),
  ('tour_500',500,330,200,100,50,0,null::int,null::int,25,13,0,0,0),
  ('masters_1000',1000,650,400,200,100,50,10,null::int,30,16,0,0,0),
  ('grand_slam_2000',2000,1300,800,400,200,100,50,10,30,16,8,0,0)
)
insert into public.tournament_ranking_point_rules(category_code,stage_code,stage_label,draw_type,points,points_are_bonus,sort_order)
select category_code,x.stage_code,x.stage_label,x.draw_type,x.points,x.points_are_bonus,x.sort_order
from base cross join lateral (values
('winner','Winner','main_draw',w,false,10),('runner_up','Finalist','main_draw',f,false,20),('semifinal','Semifinal','main_draw',sf,false,30),('quarterfinal','Quarterfinal','main_draw',qf,false,40),('round_16','Round of 16','main_draw',r16,false,50),('round_32','Round of 32','main_draw',r32,false,60),('round_64','Round of 64','main_draw',r64,false,70),('round_128','Round of 128','main_draw',r128,false,80),('qualified_bonus','Qualified to Main Draw','bonus',q_bonus,true,90),('qualifying_final_loss','Final Qualifying Round','qualification',fq_loss,false,100),('qualifying_round_3_loss','Qualifying Round 3','qualification',q3_loss,false,110),('qualifying_round_2_loss','Qualifying Round 2','qualification',q2_loss,false,120),('qualifying_round_1_loss','Qualifying Round 1','qualification',q1_loss,false,130)
) x(stage_code,stage_label,draw_type,points,points_are_bonus,sort_order) where x.points is not null;

create table if not exists public.tournament_prize_stage_weights (
  category_code text not null references public.tournament_categories(code) on delete cascade,
  stage_code text not null,stage_label text not null,draw_type text not null check (draw_type in ('main_draw','qualification')),
  finisher_count integer not null check (finisher_count > 0),weight numeric(10,4) not null check (weight > 0),sort_order integer not null,
  primary key(category_code,stage_code)
);
truncate public.tournament_prize_stage_weights;
insert into public.tournament_prize_stage_weights(category_code,stage_code,stage_label,draw_type,finisher_count,weight,sort_order)
select c,stage_code,stage_label,draw_type,finisher_count,weight,sort_order from unnest(array['futures_15','futures_25']) c cross join (values
('winner','Winner','main_draw',1,16.0,10),('runner_up','Finalist','main_draw',1,9.0,20),('semifinal','Semifinal','main_draw',2,5.5,30),('quarterfinal','Quarterfinal','main_draw',4,3.0,40),('round_16','Round of 16','main_draw',8,1.7,50),('round_32','Round of 32','main_draw',16,1.0,60),('qualifying_final_loss','Final Qualifying Round','qualification',8,0.25,100),('qualifying_round_1_loss','Qualifying Round 1','qualification',16,0.15,130)) v(stage_code,stage_label,draw_type,finisher_count,weight,sort_order);
insert into public.tournament_prize_stage_weights(category_code,stage_code,stage_label,draw_type,finisher_count,weight,sort_order)
select c,stage_code,stage_label,draw_type,finisher_count,weight,sort_order from unnest(array['challenger_50','challenger_75','challenger_100','challenger_125']) c cross join (values
('winner','Winner','main_draw',1,16.0,10),('runner_up','Finalist','main_draw',1,9.0,20),('semifinal','Semifinal','main_draw',2,5.5,30),('quarterfinal','Quarterfinal','main_draw',4,3.0,40),('round_16','Round of 16','main_draw',8,1.7,50),('round_32','Round of 32','main_draw',16,1.0,60),('qualifying_final_loss','Final Qualifying Round','qualification',6,0.45,100),('qualifying_round_1_loss','Qualifying Round 1','qualification',12,0.25,130)) v(stage_code,stage_label,draw_type,finisher_count,weight,sort_order);
insert into public.tournament_prize_stage_weights(category_code,stage_code,stage_label,draw_type,finisher_count,weight,sort_order)
select c,stage_code,stage_label,draw_type,finisher_count,weight,sort_order from unnest(array['tour_250','tour_500']) c cross join (values
('winner','Winner','main_draw',1,17.0,10),('runner_up','Finalist','main_draw',1,9.5,20),('semifinal','Semifinal','main_draw',2,5.5,30),('quarterfinal','Quarterfinal','main_draw',4,3.2,40),('round_16','Round of 16','main_draw',8,1.8,50),('round_32','Round of 32','main_draw',16,1.0,60),('qualifying_final_loss','Final Qualifying Round','qualification',8,0.60,100),('qualifying_round_1_loss','Qualifying Round 1','qualification',16,0.35,130)) v(stage_code,stage_label,draw_type,finisher_count,weight,sort_order);
insert into public.tournament_prize_stage_weights(category_code,stage_code,stage_label,draw_type,finisher_count,weight,sort_order) values
('masters_1000','winner','Winner','main_draw',1,20.0,10),('masters_1000','runner_up','Finalist','main_draw',1,12.0,20),('masters_1000','semifinal','Semifinal','main_draw',2,7.0,30),('masters_1000','quarterfinal','Quarterfinal','main_draw',4,4.0,40),('masters_1000','round_16','Round of 16','main_draw',8,2.2,50),('masters_1000','round_32','Round of 32','main_draw',16,1.2,60),('masters_1000','round_64','Round of 64','main_draw',32,0.65,70),('masters_1000','qualifying_final_loss','Final Qualifying Round','qualification',8,0.50,100),('masters_1000','qualifying_round_3_loss','Qualifying Round 3','qualification',16,0.30,110),('masters_1000','qualifying_round_2_loss','Qualifying Round 2','qualification',32,0.18,120),('masters_1000','qualifying_round_1_loss','Qualifying Round 1','qualification',64,0.10,130),
('grand_slam_2000','winner','Winner','main_draw',1,30.0,10),('grand_slam_2000','runner_up','Finalist','main_draw',1,18.0,20),('grand_slam_2000','semifinal','Semifinal','main_draw',2,10.0,30),('grand_slam_2000','quarterfinal','Quarterfinal','main_draw',4,6.0,40),('grand_slam_2000','round_16','Round of 16','main_draw',8,3.5,50),('grand_slam_2000','round_32','Round of 32','main_draw',16,2.0,60),('grand_slam_2000','round_64','Round of 64','main_draw',32,1.15,70),('grand_slam_2000','round_128','Round of 128','main_draw',64,0.70,80),('grand_slam_2000','qualifying_final_loss','Final Qualifying Round','qualification',16,0.50,100),('grand_slam_2000','qualifying_round_3_loss','Qualifying Round 3','qualification',32,0.30,110),('grand_slam_2000','qualifying_round_2_loss','Qualifying Round 2','qualification',64,0.18,120),('grand_slam_2000','qualifying_round_1_loss','Qualifying Round 1','qualification',128,0.10,130);

create table if not exists public.tournament_prize_pools (
  tournament_series_id uuid primary key references public.tournament_series(id) on delete cascade,
  announced_pool_usd bigint not null check (announced_pool_usd > 0),distributed_pool_usd bigint not null default 0 check (distributed_pool_usd >= 0),created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
insert into public.tournament_prize_pools(tournament_series_id,announced_pool_usd)
select ts.id,greatest(r.min_pool_usd,least(r.max_pool_usd,(round((r.min_pool_usd+(r.max_pool_usd-r.min_pool_usd)*((u.u1+u.u2)/2.0))/r.pool_rounding_usd)*r.pool_rounding_usd)::bigint))
from public.tournament_series ts join public.tournament_prize_pool_rules r on r.category_code=ts.category_code
cross join lateral (select ((hashtext(ts.slug||':prize-a')::bigint+2147483648)::numeric/4294967295::numeric) u1,((hashtext(ts.slug||':prize-b')::bigint+2147483648)::numeric/4294967295::numeric) u2) u
on conflict(tournament_series_id) do nothing;

create table if not exists public.tournament_prize_payouts (
 tournament_series_id uuid not null references public.tournament_series(id) on delete cascade,stage_code text not null,stage_label text not null,draw_type text not null check (draw_type in ('main_draw','qualification')),finisher_count integer not null check (finisher_count>0),payout_per_player_usd bigint not null check (payout_per_player_usd>=0),sort_order integer not null,primary key(tournament_series_id,stage_code)
);
truncate public.tournament_prize_payouts;
with weighted as (
 select ts.id tournament_series_id,ts.category_code,p.announced_pool_usd,r.payout_rounding_usd,w.stage_code,w.stage_label,w.draw_type,w.finisher_count,w.weight,w.sort_order,sum(w.weight*w.finisher_count) over(partition by ts.id) total_weight
 from public.tournament_series ts join public.tournament_prize_pools p on p.tournament_series_id=ts.id join public.tournament_prize_pool_rules r on r.category_code=ts.category_code join public.tournament_prize_stage_weights w on w.category_code=ts.category_code
),calc as (
 select *,case when stage_code='winner' then 0::bigint else (round(((announced_pool_usd*weight/total_weight)/payout_rounding_usd))*payout_rounding_usd)::bigint end payout from weighted
),sums as (
 select tournament_series_id,announced_pool_usd,sum(payout*finisher_count) nonwinner_total from calc group by tournament_series_id,announced_pool_usd
)
insert into public.tournament_prize_payouts(tournament_series_id,stage_code,stage_label,draw_type,finisher_count,payout_per_player_usd,sort_order)
select c.tournament_series_id,c.stage_code,c.stage_label,c.draw_type,c.finisher_count,case when c.stage_code='winner' then (s.announced_pool_usd-s.nonwinner_total)::bigint else c.payout end,c.sort_order from calc c join sums s using(tournament_series_id);
update public.tournament_prize_pools p set distributed_pool_usd=x.total,updated_at=now() from (select tournament_series_id,sum(finisher_count*payout_per_player_usd)::bigint total from public.tournament_prize_payouts group by tournament_series_id)x where x.tournament_series_id=p.tournament_series_id;

alter table public.player_tournament_results add column if not exists prize_money_earned bigint not null default 0 check (prize_money_earned>=0);
alter table public.player_tournament_results add column if not exists qualifying_bonus_points integer not null default 0 check (qualifying_bonus_points>=0);
alter table public.player_tournament_results add column if not exists result_stage_code text;
alter table public.player_tournament_results add column if not exists ranking_publish_status text not null default 'pending' check (ranking_publish_status in ('pending','published'));
alter table public.player_tournament_results add column if not exists ranking_publish_absolute_day integer;
alter table public.player_tournament_results add column if not exists ranking_published_at timestamptz;
create index if not exists player_tournament_results_ranking_publish_idx on public.player_tournament_results(ranking_publish_status,ranking_publish_absolute_day);
create table if not exists public.ranking_publication_runs(game_absolute_day integer primary key,season integer not null,month smallint not null,day smallint not null,published_results integer not null default 0,processed_at timestamptz not null default now());

create or replace function public.get_tournament_rewards_v1(p_competition_id uuid) returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare v_uid uuid:=auth.uid();v_world text;v_player_world text;v_series uuid;v_category text;v_name text;v_pool bigint;v_distributed bigint;v_rows jsonb;v_winner_points integer;
begin
 if v_uid is null then raise exception 'Authentication required.';end if;
 select world into v_player_world from public.players where owner_user_id=v_uid and player_type='human' order by created_at desc limit 1;
 select wc.world,ed.tournament_series_id,ts.category_code,ts.name,tc.winner_points into v_world,v_series,v_category,v_name,v_winner_points from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=ed.tournament_series_id join public.tournament_categories tc on tc.code=ts.category_code where wc.id=p_competition_id;
 if v_series is null or v_world is distinct from v_player_world then raise exception 'Tournament unavailable.';end if;
 select announced_pool_usd,distributed_pool_usd into v_pool,v_distributed from public.tournament_prize_pools where tournament_series_id=v_series;
 select coalesce(jsonb_agg(row_json order by sort_order),'[]'::jsonb) into v_rows from (
  select pp.sort_order,jsonb_build_object('stage_code',pp.stage_code,'stage_label',pp.stage_label,'draw_type',pp.draw_type,'finisher_count',pp.finisher_count,'prize_money_usd',pp.payout_per_player_usd,'ranking_points',coalesce(rp.points,0),'points_are_bonus',false) row_json from public.tournament_prize_payouts pp left join public.tournament_ranking_point_rules rp on rp.category_code=v_category and rp.stage_code=pp.stage_code where pp.tournament_series_id=v_series
  union all select rp.sort_order,jsonb_build_object('stage_code',rp.stage_code,'stage_label',rp.stage_label,'draw_type',rp.draw_type,'finisher_count',null,'prize_money_usd',0,'ranking_points',rp.points,'points_are_bonus',true) from public.tournament_ranking_point_rules rp where rp.category_code=v_category and rp.stage_code='qualified_bonus' and rp.points>0
 )q;
 return jsonb_build_object('competition_id',p_competition_id,'tournament_series_id',v_series,'tournament_name',v_name,'category_code',v_category,'currency','USD','announced_prize_pool_usd',v_pool,'distributed_prize_pool_usd',v_distributed,'winner_points',v_winner_points,'reward_rows',v_rows,'points_note','Ranking points are the total tournament result for that finishing stage. A successful qualifying bonus is added only where shown.');
end;$$;
revoke all on function public.get_tournament_rewards_v1(uuid) from public,anon;grant execute on function public.get_tournament_rewards_v1(uuid) to authenticated;

create or replace function public.get_tournament_prize_catalog_v1() returns table(tournament_name text,city text,country_code text,category_code text,category_label text,surface text,announced_prize_pool_usd bigint,winner_points integer) language sql stable security definer set search_path='public' as $$select ts.name,ts.city,ts.country_code,ts.category_code,tc.label,ts.surface,p.announced_pool_usd,tc.winner_points from public.tournament_series ts join public.tournament_categories tc on tc.code=ts.category_code join public.tournament_prize_pools p on p.tournament_series_id=ts.id where ts.is_active order by tc.sort_order,ts.name;$$;
revoke all on function public.get_tournament_prize_catalog_v1() from public,anon;grant execute on function public.get_tournament_prize_catalog_v1() to authenticated;

create or replace function public.finalize_player_tournament_result_v1(p_match_id uuid,p_player_id uuid) returns jsonb language plpgsql security definer set search_path='public' as $$
declare m public.tournament_matches%rowtype;v_series uuid;v_category text;v_tournament_name text;v_season integer;v_stage text;v_result_code text;v_base_points integer:=0;v_bonus_points integer:=0;v_prize bigint:=0;v_publish_day integer;v_match_abs integer;v_loser uuid;v_player_type text;v_reward jsonb;
begin
 select * into m from public.tournament_matches where id=p_match_id;if m.id is null or m.status<>'completed' or m.winner_id is null then return jsonb_build_object('status','not_final');end if;if p_player_id is distinct from m.player1_id and p_player_id is distinct from m.player2_id then raise exception 'Player is not in this match.';end if;v_loser:=case when m.player1_id=m.winner_id then m.player2_id else m.player1_id end;
 select ed.tournament_series_id,ts.category_code,ts.name,ed.season_number into v_series,v_category,v_tournament_name,v_season from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=ed.tournament_series_id where wc.id=m.competition_id;
 if m.draw_type='main_draw' then if p_player_id=m.winner_id then if lower(m.round_label)<>'final' then return jsonb_build_object('status','still_active');end if;v_stage:='winner';v_result_code:='champion';else v_stage:=case lower(m.round_label) when 'final' then 'runner_up' when 'semifinal' then 'semifinal' when 'quarterfinal' then 'quarterfinal' when 'round of 16' then 'round_16' when 'round of 32' then 'round_32' when 'round of 64' then 'round_64' when 'round of 128' then 'round_128' else 'other' end;v_result_code:=case v_stage when 'runner_up' then 'runner_up' when 'semifinal' then 'semifinal' when 'quarterfinal' then 'quarterfinal' when 'round_16' then 'round_16' when 'round_32' then 'round_32' when 'round_64' then 'round_64' when 'round_128' then 'round_128' else 'other' end;end if;else if p_player_id=m.winner_id then return jsonb_build_object('status','still_active');end if;if lower(m.round_label) like 'final qualifying%' then v_stage:='qualifying_final_loss';else v_stage:='qualifying_round_'||greatest(m.round_number,1)::text||'_loss';end if;v_result_code:='qualifying';end if;
 select coalesce(points,0) into v_base_points from public.tournament_ranking_point_rules where category_code=v_category and stage_code=v_stage;
 if m.draw_type='main_draw' and exists(select 1 from public.tournament_matches q where q.competition_id=m.competition_id and q.draw_type='qualification' and q.status='completed' and q.winner_id=p_player_id and lower(q.round_label) like 'final qualifying%') then select coalesce(points,0) into v_bonus_points from public.tournament_ranking_point_rules where category_code=v_category and stage_code='qualified_bonus';end if;
 select coalesce(payout_per_player_usd,0) into v_prize from public.tournament_prize_payouts where tournament_series_id=v_series and stage_code=v_stage;
 select public.training_camp_week_start_absolute_v1(v_season,max(ss.season_week)::smallint)+7 into v_publish_day from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id where wc.id=m.competition_id;
 v_match_abs:=public.training_camp_week_start_absolute_v1(v_season,m.scheduled_season_week::smallint)+m.scheduled_day-1;
 insert into public.player_tournament_results(player_id,competition_id,result_code,ranking_points_earned,prize_money_earned,qualifying_bonus_points,result_stage_code,ranking_publish_status,ranking_publish_absolute_day,completed_at,updated_at) values(p_player_id,m.competition_id,v_result_code,v_base_points+v_bonus_points,v_prize,v_bonus_points,v_stage,'pending',v_publish_day,coalesce(m.completed_at,now()),now()) on conflict(player_id,competition_id) do update set result_code=excluded.result_code,ranking_points_earned=excluded.ranking_points_earned,prize_money_earned=excluded.prize_money_earned,qualifying_bonus_points=excluded.qualifying_bonus_points,result_stage_code=excluded.result_stage_code,ranking_publish_status=case when public.player_tournament_results.ranking_publish_status='published' then 'published' else 'pending' end,ranking_publish_absolute_day=excluded.ranking_publish_absolute_day,completed_at=excluded.completed_at,updated_at=now();
 select player_type into v_player_type from public.players where id=p_player_id;if v_player_type='human' and v_prize>0 then v_reward:=public.post_career_finance_transaction_v1(p_player_id,v_prize,'prize_money',v_stage,format('%s — %s prize money',v_tournament_name,coalesce((select stage_label from public.tournament_prize_payouts where tournament_series_id=v_series and stage_code=v_stage),v_stage)),'tournament_result',m.competition_id::text,'tournament-prize:'||m.competition_id::text||':'||p_player_id::text,jsonb_build_object('tournament_name',v_tournament_name,'stage_code',v_stage,'ranking_points_earned',v_base_points+v_bonus_points,'taxable',true),false,v_match_abs);end if;
 return jsonb_build_object('status','finalized','stage_code',v_stage,'result_code',v_result_code,'ranking_points_earned',v_base_points+v_bonus_points,'qualifying_bonus_points',v_bonus_points,'prize_money_earned',v_prize,'ranking_publish_absolute_day',v_publish_day);
end;$$;
revoke all on function public.finalize_player_tournament_result_v1(uuid,uuid) from public,anon,authenticated;

create or replace function public.finalize_completed_tournament_match_v1() returns trigger language plpgsql security definer set search_path='public' as $$declare v_loser uuid;begin if new.status='completed' and new.winner_id is not null and (tg_op='INSERT' or old.status is distinct from 'completed') then v_loser:=case when new.player1_id=new.winner_id then new.player2_id else new.player1_id end;if v_loser is not null then perform public.finalize_player_tournament_result_v1(new.id,v_loser);end if;if new.draw_type='main_draw' and lower(new.round_label)='final' then perform public.finalize_player_tournament_result_v1(new.id,new.winner_id);end if;end if;return new;end;$$;
drop trigger if exists finalize_completed_tournament_match_v1 on public.tournament_matches;create trigger finalize_completed_tournament_match_v1 after insert or update of status on public.tournament_matches for each row execute function public.finalize_completed_tournament_match_v1();

create or replace function public.process_weekly_rankings_v1() returns jsonb language plpgsql security definer set search_path='public' as $$declare d record;v_abs integer;v_count integer:=0;begin select * into d from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);if mod(v_abs-2,7)<>0 then return jsonb_build_object('status','not_monday','game_absolute_day',v_abs);end if;update public.player_tournament_results set ranking_publish_status='published',ranking_published_at=coalesce(ranking_published_at,now()),updated_at=now() where ranking_publish_status='pending' and ranking_publish_absolute_day is not null and ranking_publish_absolute_day<=v_abs;get diagnostics v_count=row_count;update public.player_rankings pr set ranking_points=coalesce((select sum(r.ranking_points_earned)::integer from public.player_tournament_results r where r.player_id=pr.player_id and r.ranking_publish_status='published' and r.ranking_publish_absolute_day>v_abs-364),0),updated_at=now();perform public.capture_world_ranking_snapshot_internal_v1();insert into public.ranking_publication_runs(game_absolute_day,season,month,day,published_results,processed_at) values(v_abs,d.season,d.month,d.day,v_count,now()) on conflict(game_absolute_day) do update set published_results=public.ranking_publication_runs.published_results+excluded.published_results,processed_at=now();return jsonb_build_object('status','published','game_absolute_day',v_abs,'new_results_published',v_count);end;$$;
revoke all on function public.process_weekly_rankings_v1() from public,anon,authenticated;
select cron.unschedule(jobid) from cron.job where jobname='tennis-weekly-rankings-v1';select cron.schedule('tennis-weekly-rankings-v1','27 * * * *','select public.process_weekly_rankings_v1();');

do $$declare r record;v_loser uuid;begin for r in select * from public.tournament_matches where status='completed' and winner_id is not null loop v_loser:=case when r.player1_id=r.winner_id then r.player2_id else r.player1_id end;if v_loser is not null then perform public.finalize_player_tournament_result_v1(r.id,v_loser);end if;if r.draw_type='main_draw' and lower(r.round_label)='final' then perform public.finalize_player_tournament_result_v1(r.id,r.winner_id);end if;end loop;end $$;