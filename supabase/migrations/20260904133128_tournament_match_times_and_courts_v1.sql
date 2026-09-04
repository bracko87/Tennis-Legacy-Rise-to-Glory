alter table public.tournament_matches
  add column if not exists scheduled_start_minute smallint,
  add column if not exists court_number smallint,
  add column if not exists estimated_duration_minutes smallint not null default 150,
  add column if not exists actual_duration_minutes smallint,
  add column if not exists schedule_reason text not null default 'standard';

do $$ begin
  alter table public.tournament_matches add constraint tournament_matches_start_minute_check check (scheduled_start_minute is null or scheduled_start_minute between 0 and 1439);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.tournament_matches add constraint tournament_matches_court_number_check check (court_number is null or court_number > 0);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.tournament_matches add constraint tournament_matches_estimated_duration_check check (estimated_duration_minutes between 30 and 360);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.tournament_matches add constraint tournament_matches_actual_duration_check check (actual_duration_minutes is null or actual_duration_minutes between 20 and 480);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.tournament_matches add constraint tournament_matches_schedule_reason_check check (schedule_reason in ('standard','travel_accommodation','travel_risk'));
exception when duplicate_object then null; end $$;

create table if not exists public.tournament_match_scheduling_rules(
  category_code text primary key references public.tournament_categories(code) on delete cascade,
  court_count smallint not null check (court_count > 0),
  regular_slot_minutes smallint[] not null,
  late_slot_minutes smallint[] not null,
  final_start_minute smallint not null check (final_start_minute between 0 and 1439),
  default_match_duration_minutes smallint not null check (default_match_duration_minutes between 30 and 360),
  post_match_departure_buffer_minutes smallint not null check (post_match_departure_buffer_minutes between 0 and 240),
  pre_match_arrival_buffer_minutes smallint not null check (pre_match_arrival_buffer_minutes between 0 and 240),
  updated_at timestamptz not null default now()
);

insert into public.tournament_match_scheduling_rules(category_code,court_count,regular_slot_minutes,late_slot_minutes,final_start_minute,default_match_duration_minutes,post_match_departure_buffer_minutes,pre_match_arrival_buffer_minutes) values
('grand_slam_2000',16,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('masters_1000',8,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('tour_500',6,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('tour_250',5,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('challenger_125',4,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('challenger_100',4,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('challenger_75',4,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('challenger_50',4,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('futures_25',4,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90),
('futures_15',4,array[600,750,900,1050,1200]::smallint[],array[1290]::smallint[],960,150,60,90)
on conflict(category_code) do update set court_count=excluded.court_count,regular_slot_minutes=excluded.regular_slot_minutes,late_slot_minutes=excluded.late_slot_minutes,final_start_minute=excluded.final_start_minute,default_match_duration_minutes=excluded.default_match_duration_minutes,post_match_departure_buffer_minutes=excluded.post_match_departure_buffer_minutes,pre_match_arrival_buffer_minutes=excluded.pre_match_arrival_buffer_minutes,updated_at=now();

revoke all on public.tournament_match_scheduling_rules from public,anon,authenticated;

create or replace function public.tournament_match_absolute_day_v2(p_match_id uuid)
returns integer language sql stable security definer set search_path='public' as $$
  select (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  where m.id=p_match_id;
$$;
revoke all on function public.tournament_match_absolute_day_v2(uuid) from public,anon,authenticated;

create or replace function public.player_ready_for_tournament_match_v1(p_player_id uuid,p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare
  tm record; pm record; rule public.tournament_match_scheduling_rules%rowtype; q jsonb; v_class text:='Economy';
  v_target_day integer; v_target_abs_min bigint; v_travel_day integer; v_depart_abs_min bigint; v_prev_end bigint;
  v_travel_minutes integer:=0; v_arrival_abs_min bigint; v_ready_abs_min bigint; v_status text:='normal';
begin
  select m.*,ed.season_number,ts.city target_city,ts.country_code target_country,ts.latitude target_lat,ts.longitude target_lon,ts.category_code
  into tm
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where m.id=p_match_id;
  if tm.id is null then return jsonb_build_object('status','missing_match'); end if;
  select * into rule from public.tournament_match_scheduling_rules where category_code=tm.category_code;
  v_target_day:=(((tm.season_number-1)*366)+2+((tm.scheduled_season_week-1)*7)+(tm.scheduled_day-1))::integer;
  v_target_abs_min:=v_target_day::bigint*1440+coalesce(tm.scheduled_start_minute,600);
  v_travel_day:=v_target_day-1;
  v_depart_abs_min:=v_travel_day::bigint*1440+540;

  select m.id match_id,m.scheduled_start_minute,coalesce(m.actual_duration_minutes,m.estimated_duration_minutes,150) duration_minutes,
         (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day,
         s.city,s.country_code,s.latitude,s.longitude,m.competition_id
  into pm
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where m.competition_id<>tm.competition_id
    and (m.player1_id=p_player_id or m.player2_id=p_player_id)
    and m.status not in ('bye','cancelled')
    and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*1440+coalesce(m.scheduled_start_minute,600)) < v_target_abs_min
  order by abs_day desc,coalesce(m.scheduled_start_minute,600) desc
  limit 1;

  if pm.match_id is not null and pm.abs_day>=v_travel_day then
    v_prev_end:=pm.abs_day::bigint*1440+coalesce(pm.scheduled_start_minute,600)+pm.duration_minutes+coalesce(rule.post_match_departure_buffer_minutes,60);
    v_depart_abs_min:=greatest(v_depart_abs_min,v_prev_end);
    select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=tm.competition_id;
    v_class:=coalesce(v_class,'Economy');
    q:=public.quote_travel_v2(pm.city,pm.country_code,pm.latitude,pm.longitude,tm.target_city,tm.target_country,tm.target_lat,tm.target_lon,v_class,'one_way');
    v_travel_minutes:=greatest(30,ceil(coalesce((q->>'estimated_hours_one_way')::numeric,1)*60)::integer);
  end if;

  v_arrival_abs_min:=v_depart_abs_min+v_travel_minutes;
  v_ready_abs_min:=v_arrival_abs_min+coalesce(rule.pre_match_arrival_buffer_minutes,90);
  if v_ready_abs_min>v_target_abs_min then v_status:='impossible';
  elsif (v_arrival_abs_min/1440)::integer>=v_target_day or v_depart_abs_min>v_travel_day::bigint*1440+540 then v_status:='tight';
  else v_status:='normal'; end if;

  return jsonb_build_object('status',v_status,'preferred_travel_day',v_travel_day,'departure_absolute_minute',v_depart_abs_min,'arrival_absolute_minute',v_arrival_abs_min,'ready_absolute_minute',v_ready_abs_min,'target_absolute_minute',v_target_abs_min,'travel_minutes',v_travel_minutes,'previous_match_id',pm.match_id);
end;$$;
revoke all on function public.player_ready_for_tournament_match_v1(uuid,uuid) from public,anon,authenticated;

create or replace function public.default_tournament_match_clock_v1()
returns trigger language plpgsql security definer set search_path='public' as $$
declare rule public.tournament_match_scheduling_rules%rowtype;v_idx integer;v_used_courts integer;v_label text:=lower(coalesce(new.round_label,''));
begin
  if new.scheduled_start_minute is not null and new.court_number is not null then return new; end if;
  select r.* into rule from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id join public.tournament_match_scheduling_rules r on r.category_code=s.category_code where wc.id=new.competition_id;
  if rule.category_code is null then return new; end if;
  new.estimated_duration_minutes:=coalesce(new.estimated_duration_minutes,rule.default_match_duration_minutes);
  if v_label='final' then new.scheduled_start_minute:=coalesce(new.scheduled_start_minute,rule.final_start_minute);new.court_number:=coalesce(new.court_number,1);
  elsif v_label='semifinal' then new.scheduled_start_minute:=coalesce(new.scheduled_start_minute,(840+(new.match_number-1)*210)::smallint);new.court_number:=coalesce(new.court_number,1);
  elsif v_label='quarterfinal' then v_used_courts:=least(2,rule.court_count);v_idx:=(new.match_number-1)/v_used_courts;new.scheduled_start_minute:=coalesce(new.scheduled_start_minute,(780+v_idx*210)::smallint);new.court_number:=coalesce(new.court_number,((new.match_number-1)%v_used_courts+1)::smallint);
  else v_idx:=(new.match_number-1)/rule.court_count;new.scheduled_start_minute:=coalesce(new.scheduled_start_minute,coalesce(rule.regular_slot_minutes[v_idx+1],rule.regular_slot_minutes[array_length(rule.regular_slot_minutes,1)]));new.court_number:=coalesce(new.court_number,((new.match_number-1)%rule.court_count+1)::smallint);end if;
  return new;
end;$$;
revoke all on function public.default_tournament_match_clock_v1() from public,anon,authenticated;
drop trigger if exists default_tournament_match_clock_v1 on public.tournament_matches;
create trigger default_tournament_match_clock_v1 before insert on public.tournament_matches for each row execute function public.default_tournament_match_clock_v1();

create or replace function public.accommodate_match_travel_v1(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare m public.tournament_matches%rowtype;rule public.tournament_match_scheduling_rules%rowtype;r1 jsonb;r2 jsonb;v_day integer;v_required integer;v_candidate integer;v_court integer;v_found boolean:=false;v_max integer;v_reason text:='standard';
begin
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null or m.round_number<>1 or m.status not in ('scheduled','in_progress') then return jsonb_build_object('status','not_applicable'); end if;
  select r.* into rule from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id join public.tournament_match_scheduling_rules r on r.category_code=s.category_code where wc.id=m.competition_id;
  v_day:=public.tournament_match_absolute_day_v2(m.id);v_required:=coalesce(m.scheduled_start_minute,600);
  if m.player1_id is not null then r1:=public.player_ready_for_tournament_match_v1(m.player1_id,m.id);v_required:=greatest(v_required,((r1->>'ready_absolute_minute')::bigint-v_day::bigint*1440)::integer);end if;
  if m.player2_id is not null then r2:=public.player_ready_for_tournament_match_v1(m.player2_id,m.id);v_required:=greatest(v_required,((r2->>'ready_absolute_minute')::bigint-v_day::bigint*1440)::integer);end if;
  if v_required<=coalesce(m.scheduled_start_minute,600) then return jsonb_build_object('status','unchanged','start_minute',m.scheduled_start_minute,'court',m.court_number);end if;
  for v_candidate in select unnest(rule.regular_slot_minutes||rule.late_slot_minutes) loop
    if v_candidate<v_required then continue;end if;
    for v_court in 1..rule.court_count loop
      if not exists(select 1 from public.tournament_matches x where x.competition_id=m.competition_id and x.id<>m.id and x.scheduled_season_week=m.scheduled_season_week and x.scheduled_day=m.scheduled_day and x.scheduled_start_minute=v_candidate and x.court_number=v_court and x.status<>'cancelled') then v_found:=true;exit;end if;
    end loop;
    exit when v_found;
  end loop;
  if v_found then v_reason:='travel_accommodation';update public.tournament_matches set scheduled_start_minute=v_candidate,court_number=v_court,schedule_reason=v_reason,updated_at=now() where id=m.id;
  else select max(x) into v_max from unnest(rule.regular_slot_minutes||rule.late_slot_minutes) x;v_reason:='travel_risk';update public.tournament_matches set scheduled_start_minute=v_max,schedule_reason=v_reason,updated_at=now() where id=m.id;end if;
  return jsonb_build_object('status',v_reason,'start_minute',coalesce(v_candidate,v_max),'court',coalesce(v_court,m.court_number),'required_minute',v_required);
end;$$;
revoke all on function public.accommodate_match_travel_v1(uuid) from public,anon,authenticated;

create or replace function public.schedule_tournament_match_times_v1(p_competition_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare m record;v_count integer:=0;begin
  for m in select id from public.tournament_matches where competition_id=p_competition_id order by draw_type,round_number,match_number loop update public.tournament_matches set scheduled_start_minute=scheduled_start_minute where id=m.id; end loop;
  for m in select id from public.tournament_matches where competition_id=p_competition_id and round_number=1 and status in ('scheduled','in_progress') order by draw_type,match_number loop perform public.accommodate_match_travel_v1(m.id);end loop;
  select count(*) into v_count from public.tournament_matches where competition_id=p_competition_id and scheduled_start_minute is not null and court_number is not null;
  return jsonb_build_object('status','scheduled','matches',v_count);
end;$$;
revoke all on function public.schedule_tournament_match_times_v1(uuid) from public,anon,authenticated;

create or replace function public.schedule_published_tournament_draw_v1()
returns trigger language plpgsql security definer set search_path='public' as $$ begin perform public.schedule_tournament_match_times_v1(new.competition_id);return new;end;$$;
revoke all on function public.schedule_published_tournament_draw_v1() from public,anon,authenticated;
drop trigger if exists schedule_published_tournament_draw_v1 on public.tournament_draw_publications;
create trigger schedule_published_tournament_draw_v1 after insert on public.tournament_draw_publications for each row execute function public.schedule_published_tournament_draw_v1();

update public.tournament_matches m set scheduled_start_minute=coalesce(m.scheduled_start_minute,x.start_minute),court_number=coalesce(m.court_number,x.court_no),estimated_duration_minutes=coalesce(m.estimated_duration_minutes,150),schedule_reason=coalesce(m.schedule_reason,'standard')
from (
  select m2.id,
    case lower(m2.round_label) when 'final' then 960 when 'semifinal' then 840+(m2.match_number-1)*210 when 'quarterfinal' then 780+((m2.match_number-1)/2)*210 else (array[600,750,900,1050,1200])[(m2.match_number-1)/greatest(1,r.court_count)+1] end::smallint start_minute,
    case lower(m2.round_label) when 'final' then 1 when 'semifinal' then 1 when 'quarterfinal' then ((m2.match_number-1)%least(2,r.court_count))+1 else ((m2.match_number-1)%r.court_count)+1 end::smallint court_no
  from public.tournament_matches m2 join public.tournament_world_competitions wc on wc.id=m2.competition_id join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id join public.tournament_match_scheduling_rules r on r.category_code=s.category_code
) x where x.id=m.id and (m.scheduled_start_minute is null or m.court_number is null);

drop function if exists public.get_tournament_draw_v1(uuid);
create function public.get_tournament_draw_v1(p_competition_id uuid)
returns table(match_id uuid,draw_type text,round_number smallint,round_label text,match_number smallint,bracket_size smallint,scheduled_season_week integer,scheduled_day smallint,scheduled_start_minute smallint,court_number smallint,schedule_reason text,match_status text,player1_id uuid,player1_first_name text,player1_last_name text,player1_country_code text,player1_seed smallint,player1_set_scores smallint[],player2_id uuid,player2_first_name text,player2_last_name text,player2_country_code text,player2_seed smallint,player2_set_scores smallint[],winner_id uuid)
language plpgsql stable security definer set search_path='public' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  return query select m.id,m.draw_type,m.round_number,m.round_label,m.match_number,m.bracket_size,m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number,m.schedule_reason,m.status,p1.id,p1.first_name,p1.last_name,p1.country_code,e1.seed_number,coalesce((select array_agg(ms.player1_games order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id),'{}'::smallint[]),p2.id,p2.first_name,p2.last_name,p2.country_code,e2.seed_number,coalesce((select array_agg(ms.player2_games order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id),'{}'::smallint[]),m.winner_id
  from public.tournament_matches m left join public.players p1 on p1.id=m.player1_id left join public.players p2 on p2.id=m.player2_id left join public.tournament_entries e1 on e1.competition_id=m.competition_id and e1.player_id=m.player1_id left join public.tournament_entries e2 on e2.competition_id=m.competition_id and e2.player_id=m.player2_id where m.competition_id=p_competition_id order by m.draw_type,m.round_number,m.match_number;
end;$$;
revoke all on function public.get_tournament_draw_v1(uuid) from public,anon;
grant execute on function public.get_tournament_draw_v1(uuid) to authenticated;

create or replace function public.get_tournament_match_detail_v1(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare v_result jsonb;begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  select jsonb_build_object('match_id',m.id,'competition_id',m.competition_id,'tournament_name',s.name,'city',s.city,'country_code',s.country_code,'round_label',m.round_label,'match_number',m.match_number,'scheduled_season_week',m.scheduled_season_week,'scheduled_day',m.scheduled_day,'scheduled_start_minute',m.scheduled_start_minute,'court_number',m.court_number,'schedule_reason',m.schedule_reason,'status',m.status,'winner_id',m.winner_id,'started_at',m.started_at,'completed_at',m.completed_at,
    'player1',case when p1.id is null then null else jsonb_build_object('id',p1.id,'first_name',p1.first_name,'last_name',p1.last_name,'country_code',p1.country_code,'image_path',p1.image_path,'ranking_position',e1.ranking_position_snapshot,'seed',e1.seed_number) end,
    'player2',case when p2.id is null then null else jsonb_build_object('id',p2.id,'first_name',p2.first_name,'last_name',p2.last_name,'country_code',p2.country_code,'image_path',p2.image_path,'ranking_position',e2.ranking_position_snapshot,'seed',e2.seed_number) end,
    'sets',coalesce((select jsonb_agg(jsonb_build_object('set_number',ms.set_number,'player1_games',ms.player1_games,'player2_games',ms.player2_games,'player1_tiebreak_points',ms.player1_tiebreak_points,'player2_tiebreak_points',ms.player2_tiebreak_points,'status',ms.status) order by ms.set_number) from public.tournament_match_sets ms where ms.match_id=m.id),'[]'::jsonb),
    'player1_stats',coalesce((select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at' from public.tournament_match_player_stats st where st.match_id=m.id and st.player_id=m.player1_id),'{}'::jsonb),'player2_stats',coalesce((select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at' from public.tournament_match_player_stats st where st.match_id=m.id and st.player_id=m.player2_id),'{}'::jsonb)) into v_result
  from public.tournament_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id left join public.players p1 on p1.id=m.player1_id left join public.players p2 on p2.id=m.player2_id left join public.tournament_entries e1 on e1.competition_id=m.competition_id and e1.player_id=m.player1_id left join public.tournament_entries e2 on e2.competition_id=m.competition_id and e2.player_id=m.player2_id where m.id=p_match_id;
  return v_result;
end;$$;
revoke all on function public.get_tournament_match_detail_v1(uuid) from public,anon;
grant execute on function public.get_tournament_match_detail_v1(uuid) to authenticated;

create or replace function public.get_player_next_match_v1(p_player_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare v_result jsonb;begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  if not exists(select 1 from public.players p where p.id=p_player_id and p.moderation_status<>'rejected') then raise exception 'Player not found.';end if;
  select jsonb_build_object('match_id',m.id,'competition_id',m.competition_id,'tournament_name',s.name,'city',s.city,'country_code',s.country_code,'round_label',m.round_label,'season_week',m.scheduled_season_week,'day',m.scheduled_day,'start_minute',m.scheduled_start_minute,'court_number',m.court_number,'schedule_reason',m.schedule_reason,'status',m.status,'opponent_id',case when m.player1_id=p_player_id then m.player2_id else m.player1_id end,'opponent_first_name',case when m.player1_id=p_player_id then p2.first_name else p1.first_name end,'opponent_last_name',case when m.player1_id=p_player_id then p2.last_name else p1.last_name end,'opponent_country_code',case when m.player1_id=p_player_id then p2.country_code else p1.country_code end) into v_result
  from public.tournament_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id left join public.players p1 on p1.id=m.player1_id left join public.players p2 on p2.id=m.player2_id where (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.status='scheduled' order by ed.season_number,m.scheduled_season_week,m.scheduled_day,coalesce(m.scheduled_start_minute,600),m.match_number limit 1;
  return v_result;
end;$$;
revoke all on function public.get_player_next_match_v1(uuid) from public,anon;
grant execute on function public.get_player_next_match_v1(uuid) to authenticated;
