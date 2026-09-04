alter table public.player_travel_legs
  add column if not exists departure_minute_of_day smallint,
  add column if not exists arrival_minute_of_day smallint,
  add column if not exists estimated_travel_minutes integer,
  add column if not exists connection_status text,
  add column if not exists first_match_id uuid references public.tournament_matches(id) on delete set null;

do $$ begin alter table public.player_travel_legs add constraint player_travel_legs_departure_minute_check check (departure_minute_of_day is null or departure_minute_of_day between 0 and 1439); exception when duplicate_object then null; end $$;
do $$ begin alter table public.player_travel_legs add constraint player_travel_legs_arrival_minute_check check (arrival_minute_of_day is null or arrival_minute_of_day between 0 and 1439); exception when duplicate_object then null; end $$;
do $$ begin alter table public.player_travel_legs add constraint player_travel_legs_estimated_minutes_check check (estimated_travel_minutes is null or estimated_travel_minutes > 0); exception when duplicate_object then null; end $$;
do $$ begin alter table public.player_travel_legs add constraint player_travel_legs_connection_status_check check (connection_status is null or connection_status in ('normal','tight','at_risk')); exception when duplicate_object then null; end $$;

create or replace function public.player_commitment_locations_v1(p_player_id uuid)
returns table(commitment_type text,reference_id text,start_absolute_day integer,end_absolute_day integer,city text,country_code text,continent text,latitude double precision,longitude double precision)
language sql stable set search_path='public' as $$
with camps as (
  select 'training_camp'::text,b.id::text,b.start_absolute_day,b.end_absolute_day,l.city,l.country_code,l.continent,l.latitude,l.longitude
  from public.player_training_camp_bookings b join public.training_camp_programs p on p.id=b.program_id join public.training_camp_locations l on l.id=p.location_id
  where b.player_id=p_player_id and b.status in ('booked','active','completed')
), tournament_base as (
  select e.competition_id,e.draw_type,te.season_number,ts.city,ts.country_code,public.country_continent_v1(ts.country_code) continent,ts.latitude,ts.longitude,
    (((te.season_number-1)*366)+2+((min(ss.season_week)-1)*7))::integer week_start_absolute_day,
    (((te.season_number-1)*366)+2+((max(ss.season_week)-1)*7)+6)::integer week_end_absolute_day
  from public.tournament_entries e join public.tournament_world_competitions wc on wc.id=e.competition_id join public.tournament_editions te on te.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=te.tournament_series_id join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
  where e.player_id=p_player_id and e.entry_status in ('active','eliminated') and wc.status<>'canceled' and te.status<>'canceled'
  group by e.competition_id,e.draw_type,te.season_number,ts.city,ts.country_code,ts.latitude,ts.longitude
), tournaments as (
 select 'tournament'::text,tb.competition_id::text,
   coalesce(first_player.first_day,draw_start.draw_start_absolute_day,tb.week_start_absolute_day)::integer start_absolute_day,
   coalesce(elimination.elimination_absolute_day,draw_end.draw_end_absolute_day,tb.week_end_absolute_day)::integer end_absolute_day,
   tb.city,tb.country_code,tb.continent,tb.latitude,tb.longitude
 from tournament_base tb
 left join lateral (
   select min(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer first_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.status not in ('bye','cancelled')
 ) first_player on true
 left join lateral (
   select min(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer draw_start_absolute_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and m.draw_type=tb.draw_type
 ) draw_start on true
 left join lateral (
   select max(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer draw_end_absolute_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and m.draw_type=tb.draw_type
 ) draw_end on true
 left join lateral (
   select max(((tb.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer elimination_absolute_day
   from public.tournament_matches m where m.competition_id=tb.competition_id and m.status='completed' and (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.winner_id is not null and m.winner_id<>p_player_id
 ) elimination on true
)
select * from camps union all select * from tournaments;
$$;

create or replace function public.sync_player_tournament_travel_timing_v1(p_player_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare l record;fm record;pm record;rule public.tournament_match_scheduling_rules%rowtype;q jsonb;v_first_day integer;v_first_abs bigint;v_pref_day integer;v_depart bigint;v_prev_end bigint;v_travel integer;v_arrive bigint;v_ready bigint;v_status text;v_count integer:=0;gd record;v_existing text;
begin
 for l in select * from public.player_travel_legs where player_id=p_player_id and status='planned' and destination_location_type='tournament' and destination_reference_id~*'^[0-9a-f-]{36}$' order by departure_absolute_day,id loop
   select m.id,m.competition_id,m.scheduled_start_minute,m.scheduled_season_week,m.scheduled_day,ed.season_number,s.category_code
   into fm from public.tournament_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id
   where m.competition_id=l.destination_reference_id::uuid and (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.status not in ('bye','cancelled')
   order by ed.season_number,m.scheduled_season_week,m.scheduled_day,coalesce(m.scheduled_start_minute,600),m.match_number limit 1;
   if fm.id is null then continue;end if;
   select * into rule from public.tournament_match_scheduling_rules where category_code=fm.category_code;
   v_first_day:=(((fm.season_number-1)*366)+2+((fm.scheduled_season_week-1)*7)+(fm.scheduled_day-1))::integer;
   v_first_abs:=v_first_day::bigint*1440+coalesce(fm.scheduled_start_minute,600);v_pref_day:=v_first_day-1;v_depart:=v_pref_day::bigint*1440+540;
   select m.id match_id,m.scheduled_start_minute,coalesce(m.actual_duration_minutes,m.estimated_duration_minutes,150) duration_minutes,(((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day
   into pm from public.tournament_matches m join public.tournament_world_competitions wc on wc.id=m.competition_id join public.tournament_editions ed on ed.id=wc.tournament_edition_id
   where m.competition_id<>fm.competition_id and (m.player1_id=p_player_id or m.player2_id=p_player_id) and m.status not in ('bye','cancelled') and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*1440+coalesce(m.scheduled_start_minute,600))<v_first_abs
   order by abs_day desc,coalesce(m.scheduled_start_minute,600) desc limit 1;
   if pm.match_id is not null and pm.abs_day>=v_pref_day then v_prev_end:=pm.abs_day::bigint*1440+coalesce(pm.scheduled_start_minute,600)+pm.duration_minutes+coalesce(rule.post_match_departure_buffer_minutes,60);v_depart:=greatest(v_depart,v_prev_end);end if;
   q:=public.quote_travel_v2(l.source_city,l.source_country_code,l.source_latitude,l.source_longitude,l.destination_city,l.destination_country_code,l.destination_latitude,l.destination_longitude,l.travel_class,'one_way');
   v_travel:=greatest(30,ceil(coalesce((q->>'estimated_hours_one_way')::numeric,1)*60)::integer);v_arrive:=v_depart+v_travel;v_ready:=v_arrive+coalesce(rule.pre_match_arrival_buffer_minutes,90);
   v_status:=case when v_ready>v_first_abs then 'at_risk' when (v_arrive/1440)::integer>=v_first_day or v_depart>v_pref_day::bigint*1440+540 then 'tight' else 'normal' end;
   update public.player_travel_legs set departure_absolute_day=(v_depart/1440)::integer,departure_minute_of_day=(v_depart%1440)::smallint,arrival_absolute_day=(v_arrive/1440)::integer,arrival_minute_of_day=(v_arrive%1440)::smallint,estimated_travel_minutes=v_travel,connection_status=v_status,first_match_id=fm.id,embedded_transition=(pm.match_id is not null and pm.abs_day>=v_pref_day),updated_at=now() where id=l.id;
   delete from public.player_daily_activity where player_id=p_player_id and source='travel_plan' and reference_id=l.id::text and effects_applied_at is null;
   if not (pm.match_id is not null and pm.abs_day>=v_pref_day) then
     select * into gd from public.absolute_game_day_v1((v_depart/1440)::integer);select activity_type into v_existing from public.player_daily_activity where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;
     if v_existing is null or v_existing='home' then insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note) values(p_player_id,gd.season,gd.month,gd.day,'travel','travel_plan',l.id::text,format('Travel to %s',coalesce(l.destination_city,l.destination_country_code))) on conflict(player_id,season,month,day) do update set activity_type='travel',source='travel_plan',reference_id=l.id::text,note=excluded.note,updated_at=now() where public.player_daily_activity.effects_applied_at is null and public.player_daily_activity.activity_type='home';end if;
   end if;
   v_count:=v_count+1;
 end loop;
 return jsonb_build_object('status','synced','tournament_legs',v_count);
end;$$;
revoke all on function public.sync_player_tournament_travel_timing_v1(uuid) from public,anon,authenticated;

create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare
  v_player public.players%rowtype;v_state public.player_location_state%rowtype;v_current integer;v_gap_limit smallint:=3;
  v_source_city text;v_source_country text;v_source_type text;v_source_ref text;v_source_lat double precision;v_source_lon double precision;
  v_prev_end integer;v_had boolean:=false;c record;q jsonb;v_depart integer;v_arrive integer;v_embedded boolean;v_count integer:=0;homep jsonb;
begin
  select * into v_player from public.players where id=p_player_id;if v_player.id is null then raise exception 'Player not found.';end if;
  select public.game_day_absolute_v1(season,month,day) into v_current from public.get_current_game_day_internal_v1();select direct_transition_max_gap_days into v_gap_limit from public.travel_engine_settings where id=1;select * into v_state from public.player_location_state where player_id=p_player_id;
  update public.player_daily_activity set activity_type='home',source=null,reference_id=null,note=null,updated_at=now() where player_id=p_player_id and source='travel_plan' and effects_applied_at is null and public.game_day_absolute_v1(season,month,day)>=v_current;
  delete from public.player_travel_legs where player_id=p_player_id and status='planned' and arrival_absolute_day>=v_current;
  if v_state.player_id is null then insert into public.player_location_state(player_id,current_city,current_country_code,current_continent,location_type,location_since_absolute_day,updated_at) values(p_player_id,v_player.home_city,v_player.country_code,public.country_continent_v1(v_player.country_code),'home',v_current,now()) on conflict(player_id) do nothing;select * into v_state from public.player_location_state where player_id=p_player_id;end if;
  v_source_city:=coalesce(v_state.current_city,v_player.home_city);v_source_country:=coalesce(v_state.current_country_code,v_player.country_code);v_source_type:=coalesce(v_state.location_type,'home');v_source_ref:=v_state.source_reference_id;q:=public.resolve_location_coordinates_v1(v_source_city,v_source_country,v_state.current_latitude,v_state.current_longitude);v_source_lat:=nullif(q->>'latitude','')::double precision;v_source_lon:=nullif(q->>'longitude','')::double precision;v_prev_end:=v_current-1;
  for c in select * from public.player_commitment_locations_v1(p_player_id) where end_absolute_day>=v_current order by start_absolute_day,end_absolute_day,commitment_type loop
    if c.start_absolute_day<=v_current and c.end_absolute_day>=v_current then q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);v_source_city:=c.city;v_source_country:=c.country_code;v_source_type:=c.commitment_type;v_source_ref:=c.reference_id;v_source_lat:=nullif(q->>'latitude','')::double precision;v_source_lon:=nullif(q->>'longitude','')::double precision;update public.player_location_state set current_city=c.city,current_country_code=c.country_code,current_continent=c.continent,current_latitude=v_source_lat,current_longitude=v_source_lon,location_type=c.commitment_type,source_reference_id=c.reference_id,location_since_absolute_day=coalesce(location_since_absolute_day,v_current),updated_at=now() where player_id=p_player_id;v_prev_end:=c.end_absolute_day;v_had:=true;continue;end if;
    if v_had and v_source_type<>'home' and (c.start_absolute_day-v_prev_end-1)>v_gap_limit then homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);v_depart:=greatest(v_current,v_prev_end+1);perform public.insert_planned_travel_leg_v1(p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,'home',v_player.home_city,v_player.country_code,nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,v_depart,v_depart,false);v_count:=v_count+1;v_source_city:=v_player.home_city;v_source_country:=v_player.country_code;v_source_type:='home';v_source_ref:=null;v_source_lat:=nullif(homep->>'latitude','')::double precision;v_source_lon:=nullif(homep->>'longitude','')::double precision;end if;
    q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);v_depart:=greatest(v_current,c.start_absolute_day-1);v_embedded:=v_depart<=v_prev_end or v_depart>=c.start_absolute_day;v_arrive:=case when v_embedded then c.start_absolute_day else v_depart end;
    if public.insert_planned_travel_leg_v1(p_player_id,c.commitment_type,v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,c.commitment_type,c.city,c.country_code,nullif(q->>'latitude','')::double precision,nullif(q->>'longitude','')::double precision,c.reference_id,v_depart,v_arrive,v_embedded) is not null then v_count:=v_count+1;end if;
    v_source_city:=c.city;v_source_country:=c.country_code;v_source_type:=c.commitment_type;v_source_ref:=c.reference_id;v_source_lat:=nullif(q->>'latitude','')::double precision;v_source_lon:=nullif(q->>'longitude','')::double precision;v_prev_end:=c.end_absolute_day;v_had:=true;
  end loop;
  if v_had and v_source_type<>'home' then homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);v_depart:=greatest(v_current,v_prev_end+1);if public.insert_planned_travel_leg_v1(p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,'home',v_player.home_city,v_player.country_code,nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,v_depart,v_depart,false) is not null then v_count:=v_count+1;end if;end if;
  perform public.sync_player_tournament_travel_timing_v1(p_player_id);
  return jsonb_build_object('status','rebuilt','travel_legs',v_count,'direct_transition_max_gap_days',v_gap_limit);
end;$$;

create or replace function public.sync_travel_plan_from_tournament_match_v1()
returns trigger language plpgsql security definer set search_path='public' as $$
declare v_player uuid;begin
  for v_player in select distinct x.player_id from (
    select case when tg_op='DELETE' then old.player1_id else new.player1_id end player_id union all
    select case when tg_op='DELETE' then old.player2_id else new.player2_id end union all
    select case when tg_op='UPDATE' then old.player1_id else null end union all
    select case when tg_op='UPDATE' then old.player2_id else null end
  )x join public.players p on p.id=x.player_id where x.player_id is not null and p.player_type='human' and p.owner_user_id is not null loop perform public.rebuild_player_travel_plan_v1(v_player);end loop;
  return case when tg_op='DELETE' then old else new end;
end;$$;

drop trigger if exists tournament_match_travel_plan on public.tournament_matches;
create trigger tournament_match_travel_plan after insert or delete or update of status,winner_id,player1_id,player2_id,scheduled_season_week,scheduled_day,scheduled_start_minute,court_number,schedule_reason on public.tournament_matches for each row execute function public.sync_travel_plan_from_tournament_match_v1();
