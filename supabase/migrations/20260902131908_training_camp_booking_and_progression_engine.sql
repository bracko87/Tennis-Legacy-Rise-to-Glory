create table if not exists public.training_camp_locations (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  city text not null,
  country text not null,
  country_code text not null,
  continent text not null check (continent in ('Europe','Asia','Africa','North America','South America','Oceania')),
  image_url text,
  thumbnail_url text,
  description text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.training_camp_programs (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.training_camp_locations(id) on delete cascade,
  slug text not null unique,
  name text not null,
  category text not null check (category in ('tennis_skills','physical','recovery_mindset')),
  surface text check (surface is null or surface in ('hard','clay','grass')),
  quality_tier text not null check (quality_tier in ('standard','advanced','elite')),
  quality_multiplier numeric(5,3) not null check (quality_multiplier between 0.5 and 2.0),
  weekly_cost integer not null check (weekly_cost >= 0),
  rating numeric(2,1) not null default 4.0 check (rating between 1 and 5),
  development_profile jsonb not null default '{}'::jsonb,
  condition_profile jsonb not null default '{}'::jsonb,
  benefit_summary text not null,
  description text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists training_camp_programs_location_idx on public.training_camp_programs(location_id);
create index if not exists training_camp_programs_category_idx on public.training_camp_programs(category, surface, weekly_cost);

create table if not exists public.player_training_camp_bookings (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  program_id uuid not null references public.training_camp_programs(id) on delete restrict,
  start_absolute_day integer not null check (start_absolute_day >= 0),
  end_absolute_day integer not null check (end_absolute_day >= start_absolute_day),
  start_season integer not null check (start_season >= 1),
  start_month smallint not null check (start_month between 1 and 12),
  start_day smallint not null check (start_day between 1 and 31),
  end_season integer not null check (end_season >= 1),
  end_month smallint not null check (end_month between 1 and 12),
  end_day smallint not null check (end_day between 1 and 31),
  duration_weeks smallint not null check (duration_weeks between 1 and 4),
  weekly_cost integer not null check (weekly_cost >= 0),
  total_cost integer not null check (total_cost >= 0),
  status text not null default 'booked' check (status in ('booked','active','completed','cancelled')),
  booked_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists player_training_camp_bookings_player_idx on public.player_training_camp_bookings(player_id, status, start_absolute_day, end_absolute_day);

create table if not exists public.player_training_camp_days (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.player_training_camp_bookings(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  season integer not null check (season >= 1),
  month smallint not null check (month between 1 and 12),
  day smallint not null check (day between 1 and 31),
  absolute_day integer not null check (absolute_day >= 0),
  camp_day_number smallint not null check (camp_day_number >= 1),
  camp_week smallint not null check (camp_week between 1 and 4),
  efficiency numeric(6,4) not null default 1,
  development_gains jsonb not null default '{}'::jsonb,
  level_ups jsonb not null default '{}'::jsonb,
  condition_changes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (booking_id, absolute_day),
  unique (player_id, season, month, day)
);

alter table public.training_camp_locations enable row level security;
alter table public.training_camp_programs enable row level security;
alter table public.player_training_camp_bookings enable row level security;
alter table public.player_training_camp_days enable row level security;

drop policy if exists training_camp_locations_read on public.training_camp_locations;
create policy training_camp_locations_read on public.training_camp_locations for select to authenticated using (is_active);
drop policy if exists training_camp_programs_read on public.training_camp_programs;
create policy training_camp_programs_read on public.training_camp_programs for select to authenticated using (is_active and exists (select 1 from public.training_camp_locations l where l.id=location_id and l.is_active));
drop policy if exists player_training_camp_bookings_read_own on public.player_training_camp_bookings;
create policy player_training_camp_bookings_read_own on public.player_training_camp_bookings for select to authenticated using (exists (select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));
drop policy if exists player_training_camp_days_read_own on public.player_training_camp_days;
create policy player_training_camp_days_read_own on public.player_training_camp_days for select to authenticated using (exists (select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));

revoke all on public.training_camp_locations from anon;
revoke all on public.training_camp_programs from anon;
revoke all on public.player_training_camp_bookings from anon;
revoke all on public.player_training_camp_days from anon;
revoke insert, update, delete on public.training_camp_locations from authenticated;
revoke insert, update, delete on public.training_camp_programs from authenticated;
revoke insert, update, delete on public.player_training_camp_bookings from authenticated;
revoke insert, update, delete on public.player_training_camp_days from authenticated;
grant select on public.training_camp_locations to authenticated;
grant select on public.training_camp_programs to authenticated;
grant select on public.player_training_camp_bookings to authenticated;
grant select on public.player_training_camp_days to authenticated;

create or replace function public.game_day_absolute_v1(p_season integer,p_month smallint,p_day smallint) returns integer language plpgsql immutable set search_path=public as $$
declare v_lengths integer[] := array[31,29,31,30,31,30,31,31,30,31,30,31]; v_offset integer := 0; i integer;
begin
 if p_season < 1 or p_month < 1 or p_month > 12 then raise exception 'Invalid game date.'; end if;
 if p_day < 1 or p_day > v_lengths[p_month] then raise exception 'Invalid game day for month.'; end if;
 if p_month > 1 then for i in 1..p_month-1 loop v_offset := v_offset + v_lengths[i]; end loop; end if;
 return (p_season - 1) * 366 + v_offset + p_day - 1;
end; $$;

create or replace function public.absolute_game_day_v1(p_absolute_day integer) returns table(season integer, month smallint, day smallint, season_week smallint) language plpgsql immutable set search_path=public as $$
declare v_lengths integer[] := array[31,29,31,30,31,30,31,31,30,31,30,31]; v_doy integer; v_remaining integer; i integer;
begin
 if p_absolute_day < 0 then raise exception 'Absolute game day cannot be negative.'; end if;
 season := (p_absolute_day / 366) + 1; v_doy := p_absolute_day % 366; v_remaining := v_doy; month := 1;
 for i in 1..12 loop if v_remaining < v_lengths[i] then month := i::smallint; day := (v_remaining + 1)::smallint; exit; end if; v_remaining := v_remaining - v_lengths[i]; end loop;
 season_week := case when v_doy < 2 then 0 else (floor((v_doy - 2)::numeric / 7)::integer + 1)::smallint end; return next;
end; $$;

insert into public.notification_catalog(code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active) values
('training.camp.booked','training','Training camp booked','Confirm a future training-camp reservation and its dates.','Training camp booking created','A player successfully books a camp for 1–4 weeks.','Server-side booking RPC','player_training_camp_bookings','Training camp booked','{{camp_name}} is booked from {{start_date}} for {{duration_weeks}} week(s).','/game/training','info',true,false,false,true,true),
('training.camp.completed','training','Training camp completed','Inform the player when the final day of a camp has been processed.','Final training-camp day processed','The current game day equals the booking end day.','Training-camp daily engine','player_training_camp_days','Training camp completed','{{camp_name}} has been completed. Your camp development is now applied.','/game/training','success',true,false,false,true,true)
on conflict(code) do update set category=excluded.category,label=excluded.label,reason=excluded.reason,trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,title_template=excluded.title_template,message_template=excluded.message_template,default_route=excluded.default_route,severity=excluded.severity,is_active=true,updated_at=now();

create or replace function public.book_training_camp_v1(p_program_id uuid,p_start_season integer,p_start_month smallint,p_start_day smallint,p_duration_weeks smallint) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player_id uuid; v_user_id uuid := auth.uid(); v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_start_abs integer; v_end_abs integer; v_current_abs integer; v_end record; v_booking public.player_training_camp_bookings%rowtype; d record;
begin
 if v_user_id is null then raise exception 'Authentication required.'; end if;
 select id into v_player_id from public.players where owner_user_id=v_user_id; if v_player_id is null then raise exception 'Player not found.'; end if;
 select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if;
 select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active; if v_location.id is null then raise exception 'Training camp location is unavailable.'; end if;
 if p_duration_weeks not between 1 and 4 then raise exception 'Training camp duration must be between 1 and 4 weeks.'; end if;
 v_start_abs := public.game_day_absolute_v1(p_start_season,p_start_month,p_start_day); v_end_abs := v_start_abs + (p_duration_weeks * 7) - 1;
 select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs < v_current_abs then raise exception 'Training camp cannot start in the past.'; end if;
 if exists (select 1 from public.player_training_camp_bookings b where b.player_id=v_player_id and b.status in ('booked','active') and int4range(b.start_absolute_day,b.end_absolute_day,'[]') && int4range(v_start_abs,v_end_abs,'[]')) then raise exception 'Another training camp overlaps the selected dates.'; end if;
 if exists (select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_daily_activity a on a.player_id=v_player_id and a.season=gd.season and a.month=gd.month and a.day=gd.day where a.activity_type <> 'home' or a.effects_applied_at is not null) then raise exception 'The selected dates contain travel, tournament, injury, another camp, or an already processed activity.'; end if;
 if exists (select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_training_sessions s on s.player_id=v_player_id and s.season=gd.season and s.month=gd.month and s.day=gd.day) then raise exception 'Regular training has already been processed on one of the selected dates.'; end if;
 if exists (select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.tournament_editions te on te.season_number=gd.season join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id join public.tournament_applications ta on ta.competition_id=wc.id and ta.player_id=v_player_id where gd.season_week > 0 and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')) then raise exception 'A tournament application or commitment overlaps the selected camp dates.'; end if;
 select * into v_end from public.absolute_game_day_v1(v_end_abs);
 insert into public.player_training_camp_bookings(player_id,program_id,start_absolute_day,end_absolute_day,start_season,start_month,start_day,end_season,end_month,end_day,duration_weeks,weekly_cost,total_cost,status) values(v_player_id,v_program.id,v_start_abs,v_end_abs,p_start_season,p_start_month,p_start_day,v_end.season,v_end.month,v_end.day,p_duration_weeks,v_program.weekly_cost,v_program.weekly_cost*p_duration_weeks,'booked') returning * into v_booking;
 for d in select gd.* from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd loop insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note) values(v_player_id,d.season,d.month,d.day,'training_camp','training_camp_booking',v_booking.id::text,v_program.name) on conflict(player_id,season,month,day) do update set activity_type='training_camp',source='training_camp_booking',reference_id=v_booking.id::text,note=v_program.name,updated_at=now(); end loop;
 perform public.emit_notification_v1(v_user_id,v_player_id,'training.camp.booked','Training camp booked',format('%s in %s is booked for %s week%s.',v_program.name,v_location.city,p_duration_weeks,case when p_duration_weeks=1 then '' else 's' end),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city,'duration_weeks',p_duration_weeks),'training-camp-booked:'||v_booking.id::text);
 return jsonb_build_object('status','booked','booking_id',v_booking.id,'camp_name',v_program.name,'start',jsonb_build_object('season',p_start_season,'month',p_start_month,'day',p_start_day),'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost);
end; $$;

create or replace function public.cancel_training_camp_v1(p_booking_id uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player_id uuid; v_booking public.player_training_camp_bookings%rowtype; v_current_abs integer;
begin
 if auth.uid() is null then raise exception 'Authentication required.'; end if; select id into v_player_id from public.players where owner_user_id=auth.uid(); select * into v_booking from public.player_training_camp_bookings where id=p_booking_id and player_id=v_player_id for update; if v_booking.id is null then raise exception 'Training camp booking not found.'; end if;
 select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_booking.status <> 'booked' or v_current_abs >= v_booking.start_absolute_day then raise exception 'Only a future camp that has not started can be cancelled.'; end if;
 update public.player_training_camp_bookings set status='cancelled',cancelled_at=now(),updated_at=now() where id=v_booking.id; delete from public.player_daily_activity where player_id=v_player_id and source='training_camp_booking' and reference_id=v_booking.id::text and effects_applied_at is null; return jsonb_build_object('status','cancelled','booking_id',v_booking.id);
end; $$;

-- Camp days use the same fractional progression helper as regular training.
create or replace function public.process_training_camp_day_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine') returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_abs integer := public.game_day_absolute_v1(p_season,p_month,p_day); v_booking public.player_training_camp_bookings%rowtype; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; s public.player_skills%rowtype; pr public.player_training_progress%rowtype;
 v_week smallint; v_day_no smallint; v_duration_factor numeric; v_readiness numeric; v_eff numeric; v_base_budget numeric; v_gains jsonb := '{}'::jsonb; v_levelups jsonb := '{}'::jsonb; v_condition jsonb := '{}'::jsonb;
 v_fatigue_before smallint; v_sharpness_before smallint; v_morale_before smallint; v_confidence_before smallint; v_focus_before smallint; v_new_fatigue smallint; v_new_sharpness smallint; v_new_morale smallint; v_new_confidence smallint; v_new_focus smallint; r record; g numeric;
begin
 select b.* into v_booking from public.player_training_camp_bookings b where b.player_id=p_player_id and b.status in ('booked','active') and v_abs between b.start_absolute_day and b.end_absolute_day order by b.start_absolute_day limit 1 for update;
 if v_booking.id is null then return jsonb_build_object('status','blocked','reason','No active training camp owns this day.'); end if;
 if exists(select 1 from public.player_training_camp_days where booking_id=v_booking.id and absolute_day=v_abs) then return jsonb_build_object('status','already_processed','booking_id',v_booking.id); end if;
 select * into v_program from public.training_camp_programs where id=v_booking.program_id; select * into v_location from public.training_camp_locations where id=v_program.location_id; select * into s from public.player_skills where player_id=p_player_id for update; if s.player_id is null then raise exception 'Player skills are unavailable.'; end if;
 insert into public.player_training_progress(player_id) values(p_player_id) on conflict(player_id) do nothing; select * into pr from public.player_training_progress where player_id=p_player_id for update;
 v_day_no := (v_abs-v_booking.start_absolute_day+1)::smallint; v_week := (floor((v_day_no-1)::numeric/7)::integer+1)::smallint; v_duration_factor := case v_week when 1 then 1.00 when 2 then 0.95 when 3 then 0.85 else 0.75 end;
 v_readiness := (s.morale+s.confidence+s.sharpness+s.focus+(100-s.fatigue))::numeric/500; v_eff := least(1.35,greatest(0.70,(0.82+0.23*v_readiness)*v_program.quality_multiplier*v_duration_factor));
 v_fatigue_before:=s.fatigue; v_sharpness_before:=s.sharpness; v_morale_before:=s.morale; v_confidence_before:=s.confidence; v_focus_before:=s.focus;
 if v_program.category='tennis_skills' then
  v_base_budget:=0.34*v_eff;
  g:=v_base_budget*coalesce((v_program.development_profile->>'serve')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.serve,pr.serve,g); s.serve:=r.value_out; pr.serve:=r.progress_out; v_gains:=v_gains||jsonb_build_object('serve',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('serve',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'forehand')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.forehand,pr.forehand,g); s.forehand:=r.value_out; pr.forehand:=r.progress_out; v_gains:=v_gains||jsonb_build_object('forehand',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('forehand',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'backhand')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.backhand,pr.backhand,g); s.backhand:=r.value_out; pr.backhand:=r.progress_out; v_gains:=v_gains||jsonb_build_object('backhand',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('backhand',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'return_skill')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.return_skill,pr.return_skill,g); s.return_skill:=r.value_out; pr.return_skill:=r.progress_out; v_gains:=v_gains||jsonb_build_object('return_skill',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('return_skill',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'volley')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.volley,pr.volley,g); s.volley:=r.value_out; pr.volley:=r.progress_out; v_gains:=v_gains||jsonb_build_object('volley',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('volley',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'slice')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.slice,pr.slice,g); s.slice:=r.value_out; pr.slice:=r.progress_out; v_gains:=v_gains||jsonb_build_object('slice',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('slice',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'drop_shot')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.drop_shot,pr.drop_shot,g); s.drop_shot:=r.value_out; pr.drop_shot:=r.progress_out; v_gains:=v_gains||jsonb_build_object('drop_shot',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('drop_shot',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'lob')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.lob,pr.lob,g); s.lob:=r.value_out; pr.lob:=r.progress_out; v_gains:=v_gains||jsonb_build_object('lob',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('lob',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'smash')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.smash,pr.smash,g); s.smash:=r.value_out; pr.smash:=r.progress_out; v_gains:=v_gains||jsonb_build_object('smash',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('smash',r.levels_gained); end if; end if;
  v_new_fatigue:=least(100,s.fatigue+greatest(2,round(4*v_program.quality_multiplier)::integer))::smallint; v_new_sharpness:=least(100,s.sharpness+1)::smallint; v_new_morale:=s.morale; v_new_confidence:=s.confidence; v_new_focus:=least(100,s.focus+1)::smallint;
 elsif v_program.category='physical' then
  v_base_budget:=0.30*v_eff;
  g:=v_base_budget*coalesce((v_program.development_profile->>'fitness')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.fitness,pr.fitness,g); s.fitness:=r.value_out; pr.fitness:=r.progress_out; v_gains:=v_gains||jsonb_build_object('fitness',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('fitness',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'stamina')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.stamina,pr.stamina,g); s.stamina:=r.value_out; pr.stamina:=r.progress_out; v_gains:=v_gains||jsonb_build_object('stamina',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('stamina',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'recovery')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.recovery,pr.recovery,g); s.recovery:=r.value_out; pr.recovery:=r.progress_out; v_gains:=v_gains||jsonb_build_object('recovery',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('recovery',r.levels_gained); end if; end if;
  g:=v_base_budget*coalesce((v_program.development_profile->>'movement')::numeric,0); if g>0 then select * into r from public.training_apply_progress_v1(s.movement,pr.movement,g); s.movement:=r.value_out; pr.movement:=r.progress_out; v_gains:=v_gains||jsonb_build_object('movement',round(g,4)); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('movement',r.levels_gained); end if; end if;
  v_new_fatigue:=least(100,s.fatigue+greatest(3,round(6*v_program.quality_multiplier)::integer))::smallint; v_new_sharpness:=least(100,s.sharpness+1)::smallint; v_new_morale:=s.morale; v_new_confidence:=s.confidence; v_new_focus:=s.focus;
 else
  v_new_fatigue:=greatest(0,s.fatigue+coalesce((v_program.condition_profile->>'fatigue')::integer,-10))::smallint; v_new_sharpness:=least(100,greatest(0,s.sharpness+coalesce((v_program.condition_profile->>'sharpness')::integer,1)))::smallint; v_new_morale:=least(100,greatest(0,s.morale+coalesce((v_program.condition_profile->>'morale')::integer,2)))::smallint; v_new_confidence:=least(100,greatest(0,s.confidence+coalesce((v_program.condition_profile->>'confidence')::integer,1)))::smallint; v_new_focus:=least(100,greatest(0,s.focus+coalesce((v_program.condition_profile->>'focus')::integer,2)))::smallint; v_eff:=v_program.quality_multiplier*v_duration_factor;
 end if;
 update public.player_skills set serve=s.serve,forehand=s.forehand,backhand=s.backhand,return_skill=s.return_skill,volley=s.volley,slice=s.slice,drop_shot=s.drop_shot,lob=s.lob,smash=s.smash,fitness=s.fitness,stamina=s.stamina,recovery=s.recovery,movement=s.movement,fatigue=v_new_fatigue,sharpness=v_new_sharpness,morale=v_new_morale,confidence=v_new_confidence,focus=v_new_focus,updated_at=now() where player_id=p_player_id;
 update public.player_training_progress set serve=pr.serve,forehand=pr.forehand,backhand=pr.backhand,return_skill=pr.return_skill,volley=pr.volley,slice=pr.slice,drop_shot=pr.drop_shot,lob=pr.lob,smash=pr.smash,fitness=pr.fitness,stamina=pr.stamina,recovery=pr.recovery,movement=pr.movement,updated_at=now() where player_id=p_player_id;
 v_condition:=jsonb_build_object('fatigue_before',v_fatigue_before,'fatigue_after',v_new_fatigue,'sharpness_before',v_sharpness_before,'sharpness_after',v_new_sharpness,'morale_before',v_morale_before,'morale_after',v_new_morale,'confidence_before',v_confidence_before,'confidence_after',v_new_confidence,'focus_before',v_focus_before,'focus_after',v_new_focus);
 insert into public.player_training_camp_days(booking_id,player_id,season,month,day,absolute_day,camp_day_number,camp_week,efficiency,development_gains,level_ups,condition_changes) values(v_booking.id,p_player_id,p_season,p_month,p_day,v_abs,v_day_no,v_week,round(v_eff,4),v_gains,v_levelups,v_condition);
 update public.player_daily_activity set effects_applied_at=now(),effect_summary=jsonb_build_object('camp_booking_id',v_booking.id,'program_id',v_program.id,'development_gains',v_gains,'level_ups',v_levelups,'condition_changes',v_condition),updated_at=now() where player_id=p_player_id and season=p_season and month=p_month and day=p_day;
 if v_booking.status='booked' then update public.player_training_camp_bookings set status='active',started_at=coalesce(started_at,now()),updated_at=now() where id=v_booking.id; end if;
 if v_abs=v_booking.end_absolute_day then update public.player_training_camp_bookings set status='completed',completed_at=now(),updated_at=now() where id=v_booking.id; perform public.emit_notification_v1((select owner_user_id from public.players where id=p_player_id),p_player_id,'training.camp.completed','Training camp completed',format('%s in %s is complete. Your camp development has been applied.',v_program.name,v_location.city),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city),'training-camp-completed:'||v_booking.id::text); end if;
 return jsonb_build_object('status','completed','activity_type','training_camp','booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'camp_day_number',v_day_no,'camp_week',v_week,'efficiency',round(v_eff,4),'development_gains',v_gains,'level_ups',v_levelups,'condition_changes',v_condition);
end; $$;

create or replace function public.complete_training_camp_today_v1() returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player_id uuid; d record;
begin if auth.uid() is null then raise exception 'Authentication required.'; end if; select id into v_player_id from public.players where owner_user_id=auth.uid(); if v_player_id is null then raise exception 'Player not found.'; end if; select * into d from public.get_current_game_day_internal_v1(); return public.process_training_camp_day_v1(v_player_id,d.season,d.month,d.day,'manual'); end; $$;

create or replace function public.process_player_daily_activity_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine') returns jsonb language plpgsql security definer set search_path=public as $$
declare v_activity text; v_row public.player_daily_activity%rowtype; v_before smallint; v_after smallint; v_summary jsonb;
begin
 select * into v_row from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day for update; v_activity:=coalesce(v_row.activity_type,'home');
 if v_activity='home' then return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by); end if;
 if v_activity='travel' then if v_row.effects_applied_at is not null then return jsonb_build_object('status','already_processed','activity_type','travel','effect_summary',v_row.effect_summary); end if; select fatigue into v_before from public.player_skills where player_id=p_player_id for update; if v_before is null then raise exception 'Player skills are unavailable.'; end if; v_after:=least(100,v_before+6)::smallint; update public.player_skills set fatigue=v_after,updated_at=now() where player_id=p_player_id; v_summary:=jsonb_build_object('fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before,'skill_development',0); update public.player_daily_activity set effects_applied_at=now(),effect_summary=v_summary,updated_at=now() where player_id=p_player_id and season=p_season and month=p_month and day=p_day; return jsonb_build_object('status','completed','activity_type','travel','effect_summary',v_summary); end if;
 if v_activity='training_camp' then return public.process_training_camp_day_v1(p_player_id,p_season,p_month,p_day,p_processed_by); end if;
 return jsonb_build_object('status','delegated','activity_type',v_activity,'reason',case v_activity when 'tournament' then 'Tournament/match engine owns this day; regular training is blocked.' when 'injured' then 'Injury/recovery engine owns this day; regular training is blocked.' else 'Regular training is blocked.' end);
end; $$;

revoke all on function public.game_day_absolute_v1(integer,smallint,smallint) from public;
revoke all on function public.absolute_game_day_v1(integer) from public;
revoke all on function public.process_training_camp_day_v1(uuid,integer,smallint,smallint,text) from public;
revoke all on function public.process_player_daily_activity_v1(uuid,integer,smallint,smallint,text) from public;
grant execute on function public.book_training_camp_v1(uuid,integer,smallint,smallint,smallint) to authenticated;
grant execute on function public.cancel_training_camp_v1(uuid) to authenticated;
grant execute on function public.complete_training_camp_today_v1() to authenticated;
