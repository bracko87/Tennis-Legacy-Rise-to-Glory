create table if not exists public.player_daily_activity (
  player_id uuid not null references public.players(id) on delete cascade,
  season integer not null check (season >= 1),
  month smallint not null check (month between 1 and 12),
  day smallint not null check (day between 1 and 31),
  activity_type text not null check (activity_type in ('home','travel','tournament','training_camp','injured')),
  source text,
  reference_id text,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (player_id, season, month, day)
);

comment on table public.player_daily_activity is 'Canonical per-player daily activity state. Missing row means home/default. Regular training is allowed only on home days.';

create table if not exists public.player_training_plans (
  player_id uuid primary key references public.players(id) on delete cascade,
  training_type text not null default 'day_off' check (training_type in ('technical','physical','day_off')),
  focus_attribute text,
  intensity text not null default 'standard' check (intensity in ('light','standard','hard')),
  focus_share numeric(4,3) not null default 0.850 check (focus_share between 0.800 and 0.900),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_training_plan_focus_check check (
    (training_type = 'day_off' and focus_attribute is null)
    or (training_type = 'technical' and focus_attribute in ('serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'))
    or (training_type = 'physical' and focus_attribute in ('fitness','stamina','recovery','movement'))
  )
);

comment on table public.player_training_plans is 'Persistent regular-training choice. Future daily automation can process this plan once per eligible home game day.';

create table if not exists public.player_training_progress (
  player_id uuid primary key references public.players(id) on delete cascade,
  serve numeric(8,4) not null default 0 check (serve >= 0 and serve < 1),
  forehand numeric(8,4) not null default 0 check (forehand >= 0 and forehand < 1),
  backhand numeric(8,4) not null default 0 check (backhand >= 0 and backhand < 1),
  return_skill numeric(8,4) not null default 0 check (return_skill >= 0 and return_skill < 1),
  volley numeric(8,4) not null default 0 check (volley >= 0 and volley < 1),
  slice numeric(8,4) not null default 0 check (slice >= 0 and slice < 1),
  drop_shot numeric(8,4) not null default 0 check (drop_shot >= 0 and drop_shot < 1),
  lob numeric(8,4) not null default 0 check (lob >= 0 and lob < 1),
  smash numeric(8,4) not null default 0 check (smash >= 0 and smash < 1),
  fitness numeric(8,4) not null default 0 check (fitness >= 0 and fitness < 1),
  stamina numeric(8,4) not null default 0 check (stamina >= 0 and stamina < 1),
  recovery numeric(8,4) not null default 0 check (recovery >= 0 and recovery < 1),
  movement numeric(8,4) not null default 0 check (movement >= 0 and movement < 1),
  updated_at timestamptz not null default now()
);

comment on table public.player_training_progress is 'Fractional development progress toward the next whole skill point. Reusable by training, matches and future development systems.';

create table if not exists public.player_training_sessions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  season integer not null check (season >= 1),
  month smallint not null check (month between 1 and 12),
  day smallint not null check (day between 1 and 31),
  training_type text not null check (training_type in ('technical','physical','day_off')),
  focus_attribute text,
  intensity text not null check (intensity in ('light','standard','hard')),
  efficiency numeric(6,4) not null check (efficiency between 0 and 2),
  development_gains jsonb not null default '{}'::jsonb,
  level_ups jsonb not null default '{}'::jsonb,
  fatigue_before smallint not null,
  fatigue_after smallint not null,
  sharpness_before smallint not null,
  sharpness_after smallint not null,
  morale_before smallint not null,
  morale_after smallint not null,
  focus_before smallint not null,
  focus_after smallint not null,
  processed_by text not null default 'manual' check (processed_by in ('manual','daily_engine')),
  created_at timestamptz not null default now(),
  unique (player_id, season, month, day)
);

create index if not exists player_training_sessions_player_day_idx on public.player_training_sessions(player_id, season desc, month desc, day desc);

alter table public.player_daily_activity enable row level security;
alter table public.player_training_plans enable row level security;
alter table public.player_training_progress enable row level security;
alter table public.player_training_sessions enable row level security;

drop policy if exists player_daily_activity_select_own on public.player_daily_activity;
create policy player_daily_activity_select_own on public.player_daily_activity for select to authenticated using (exists (select 1 from public.players p where p.id = player_id and p.owner_user_id = auth.uid()));
drop policy if exists player_training_plans_select_own on public.player_training_plans;
create policy player_training_plans_select_own on public.player_training_plans for select to authenticated using (exists (select 1 from public.players p where p.id = player_id and p.owner_user_id = auth.uid()));
drop policy if exists player_training_progress_select_own on public.player_training_progress;
create policy player_training_progress_select_own on public.player_training_progress for select to authenticated using (exists (select 1 from public.players p where p.id = player_id and p.owner_user_id = auth.uid()));
drop policy if exists player_training_sessions_select_own on public.player_training_sessions;
create policy player_training_sessions_select_own on public.player_training_sessions for select to authenticated using (exists (select 1 from public.players p where p.id = player_id and p.owner_user_id = auth.uid()));

create or replace function public.get_current_game_day_internal_v1()
returns table(season integer, month smallint, day smallint)
language plpgsql stable set search_path = public as $$
declare v_total_seconds bigint; v_day_index bigint; v_day_of_season integer;
begin
  select game_total_seconds into v_total_seconds from public.get_game_clock_v1() limit 1;
  v_day_index := floor(v_total_seconds::numeric / 86400)::bigint;
  season := (v_day_index / 366)::integer + 1;
  v_day_of_season := (v_day_index % 366)::integer;
  if v_day_of_season < 31 then month := 1; day := v_day_of_season + 1;
  elsif v_day_of_season < 60 then month := 2; day := v_day_of_season - 31 + 1;
  elsif v_day_of_season < 91 then month := 3; day := v_day_of_season - 60 + 1;
  elsif v_day_of_season < 121 then month := 4; day := v_day_of_season - 91 + 1;
  elsif v_day_of_season < 152 then month := 5; day := v_day_of_season - 121 + 1;
  elsif v_day_of_season < 182 then month := 6; day := v_day_of_season - 152 + 1;
  elsif v_day_of_season < 213 then month := 7; day := v_day_of_season - 182 + 1;
  elsif v_day_of_season < 244 then month := 8; day := v_day_of_season - 213 + 1;
  elsif v_day_of_season < 274 then month := 9; day := v_day_of_season - 244 + 1;
  elsif v_day_of_season < 305 then month := 10; day := v_day_of_season - 274 + 1;
  elsif v_day_of_season < 335 then month := 11; day := v_day_of_season - 305 + 1;
  else month := 12; day := v_day_of_season - 335 + 1; end if;
  return next;
end; $$;

create or replace function public.training_apply_progress_v1(p_value smallint,p_progress numeric,p_gain numeric)
returns table(value_out smallint,progress_out numeric,levels_gained integer)
language plpgsql immutable set search_path = public as $$
declare v_total numeric; v_possible integer;
begin
  v_total := greatest(0,coalesce(p_progress,0)+greatest(0,coalesce(p_gain,0)));
  if p_value>=100 then value_out:=100; progress_out:=0; levels_gained:=0; return next; return; end if;
  v_possible:=least(floor(v_total)::integer,100-p_value);
  value_out:=(p_value+v_possible)::smallint; levels_gained:=v_possible;
  if value_out>=100 then progress_out:=0; else progress_out:=round(v_total-v_possible,4); end if;
  return next;
end; $$;

create or replace function public.apply_player_development_progress_v1(p_player_id uuid,p_source text,p_gains jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s public.player_skills%rowtype; pr public.player_training_progress%rowtype; r record; v_level_ups jsonb:='{}'::jsonb; v_gain numeric;
begin
  select * into s from public.player_skills where player_id=p_player_id for update; if not found then raise exception 'Player skills are unavailable.'; end if;
  insert into public.player_training_progress(player_id) values(p_player_id) on conflict(player_id) do nothing;
  select * into pr from public.player_training_progress where player_id=p_player_id for update;
  v_gain:=coalesce((p_gains->>'serve')::numeric,0); select * into r from public.training_apply_progress_v1(s.serve,pr.serve,v_gain); pr.serve:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('serve',r.levels_gained); end if; s.serve:=r.value_out;
  v_gain:=coalesce((p_gains->>'forehand')::numeric,0); select * into r from public.training_apply_progress_v1(s.forehand,pr.forehand,v_gain); pr.forehand:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('forehand',r.levels_gained); end if; s.forehand:=r.value_out;
  v_gain:=coalesce((p_gains->>'backhand')::numeric,0); select * into r from public.training_apply_progress_v1(s.backhand,pr.backhand,v_gain); pr.backhand:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('backhand',r.levels_gained); end if; s.backhand:=r.value_out;
  v_gain:=coalesce((p_gains->>'return_skill')::numeric,0); select * into r from public.training_apply_progress_v1(s.return_skill,pr.return_skill,v_gain); pr.return_skill:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('return_skill',r.levels_gained); end if; s.return_skill:=r.value_out;
  v_gain:=coalesce((p_gains->>'volley')::numeric,0); select * into r from public.training_apply_progress_v1(s.volley,pr.volley,v_gain); pr.volley:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('volley',r.levels_gained); end if; s.volley:=r.value_out;
  v_gain:=coalesce((p_gains->>'slice')::numeric,0); select * into r from public.training_apply_progress_v1(s.slice,pr.slice,v_gain); pr.slice:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('slice',r.levels_gained); end if; s.slice:=r.value_out;
  v_gain:=coalesce((p_gains->>'drop_shot')::numeric,0); select * into r from public.training_apply_progress_v1(s.drop_shot,pr.drop_shot,v_gain); pr.drop_shot:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('drop_shot',r.levels_gained); end if; s.drop_shot:=r.value_out;
  v_gain:=coalesce((p_gains->>'lob')::numeric,0); select * into r from public.training_apply_progress_v1(s.lob,pr.lob,v_gain); pr.lob:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('lob',r.levels_gained); end if; s.lob:=r.value_out;
  v_gain:=coalesce((p_gains->>'smash')::numeric,0); select * into r from public.training_apply_progress_v1(s.smash,pr.smash,v_gain); pr.smash:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('smash',r.levels_gained); end if; s.smash:=r.value_out;
  v_gain:=coalesce((p_gains->>'fitness')::numeric,0); select * into r from public.training_apply_progress_v1(s.fitness,pr.fitness,v_gain); pr.fitness:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('fitness',r.levels_gained); end if; s.fitness:=r.value_out;
  v_gain:=coalesce((p_gains->>'stamina')::numeric,0); select * into r from public.training_apply_progress_v1(s.stamina,pr.stamina,v_gain); pr.stamina:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('stamina',r.levels_gained); end if; s.stamina:=r.value_out;
  v_gain:=coalesce((p_gains->>'recovery')::numeric,0); select * into r from public.training_apply_progress_v1(s.recovery,pr.recovery,v_gain); pr.recovery:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('recovery',r.levels_gained); end if; s.recovery:=r.value_out;
  v_gain:=coalesce((p_gains->>'movement')::numeric,0); select * into r from public.training_apply_progress_v1(s.movement,pr.movement,v_gain); pr.movement:=r.progress_out; if r.levels_gained>0 then v_level_ups:=v_level_ups||jsonb_build_object('movement',r.levels_gained); end if; s.movement:=r.value_out;
  update public.player_training_progress set serve=pr.serve,forehand=pr.forehand,backhand=pr.backhand,return_skill=pr.return_skill,volley=pr.volley,slice=pr.slice,drop_shot=pr.drop_shot,lob=pr.lob,smash=pr.smash,fitness=pr.fitness,stamina=pr.stamina,recovery=pr.recovery,movement=pr.movement,updated_at=now() where player_id=p_player_id;
  update public.player_skills set serve=s.serve,forehand=s.forehand,backhand=s.backhand,return_skill=s.return_skill,volley=s.volley,slice=s.slice,drop_shot=s.drop_shot,lob=s.lob,smash=s.smash,fitness=s.fitness,stamina=s.stamina,recovery=s.recovery,movement=s.movement,updated_at=now() where player_id=p_player_id;
  return jsonb_build_object('source',p_source,'level_ups',v_level_ups);
end; $$;

create or replace function public.set_regular_training_plan_v1(p_training_type text,p_focus_attribute text default null,p_intensity text default 'standard')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_player_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid(); if v_player_id is null then raise exception 'Player not found.'; end if;
  if p_training_type not in ('technical','physical','day_off') then raise exception 'Invalid training type.'; end if;
  if p_intensity not in ('light','standard','hard') then raise exception 'Invalid intensity.'; end if;
  if p_training_type='technical' and p_focus_attribute not in ('serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash') then raise exception 'Choose a valid tennis skill.'; end if;
  if p_training_type='physical' and p_focus_attribute not in ('fitness','stamina','recovery','movement') then raise exception 'Choose a valid physical skill.'; end if;
  if p_training_type='day_off' then p_focus_attribute:=null; end if;
  insert into public.player_training_plans(player_id,training_type,focus_attribute,intensity,focus_share,is_active,updated_at) values(v_player_id,p_training_type,p_focus_attribute,p_intensity,0.850,true,now())
  on conflict(player_id) do update set training_type=excluded.training_type,focus_attribute=excluded.focus_attribute,intensity=excluded.intensity,focus_share=0.850,is_active=true,updated_at=now();
  return jsonb_build_object('training_type',p_training_type,'focus_attribute',p_focus_attribute,'intensity',p_intensity,'focus_share',0.85);
end; $$;

create or replace function public.process_regular_training_for_player_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  s public.player_skills%rowtype; plan public.player_training_plans%rowtype; v_activity text; v_readiness numeric; v_eff numeric; v_budget numeric; v_incidental numeric; v_target_gain numeric; v_other_gain numeric; v_gains jsonb:='{}'::jsonb; v_levels jsonb:='{}'::jsonb; v_base_fatigue integer; v_resilience numeric; v_fatigue_cost integer; v_fatigue_before smallint; v_sharpness_before smallint; v_morale_before smallint; v_focus_before smallint; v_fatigue_after smallint; v_sharpness_after smallint; v_morale_after smallint; v_focus_after smallint; v_rest_reduction integer; v_session_id uuid; k text; v_dev_result jsonb;
begin
  if p_processed_by not in ('manual','daily_engine') then raise exception 'Invalid processor.'; end if;
  if exists(select 1 from public.player_training_sessions where player_id=p_player_id and season=p_season and month=p_month and day=p_day) then return (select jsonb_build_object('status','already_processed','session_id',id) from public.player_training_sessions where player_id=p_player_id and season=p_season and month=p_month and day=p_day); end if;
  select coalesce((select activity_type from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day),'home') into v_activity;
  if v_activity<>'home' then return jsonb_build_object('status','blocked','activity_type',v_activity,'reason',case v_activity when 'travel' then 'Regular training is unavailable on travel days.' when 'tournament' then 'Regular training is unavailable during tournament participation.' when 'training_camp' then 'Regular training is replaced by training-camp work.' when 'injured' then 'Regular training is unavailable while the player is injured.' else 'Regular training is unavailable today.' end); end if;
  select * into s from public.player_skills where player_id=p_player_id for update; if not found then raise exception 'Player skills are unavailable.'; end if;
  select * into plan from public.player_training_plans where player_id=p_player_id;
  if not found then insert into public.player_training_plans(player_id,training_type,focus_attribute,intensity) values(p_player_id,'day_off',null,'standard') returning * into plan; end if;
  v_fatigue_before:=s.fatigue; v_sharpness_before:=s.sharpness; v_morale_before:=s.morale; v_focus_before:=s.focus;
  v_readiness:=(s.morale+s.confidence+s.sharpness+s.focus+(100-s.fatigue))::numeric/500; v_eff:=round(greatest(0.70,least(1.05,0.78+0.37*v_readiness)),4);
  if plan.training_type<>'day_off' then if plan.intensity='hard' and s.fatigue>=80 then return jsonb_build_object('status','blocked','activity_type','home','reason','Fatigue is too high for hard training. Choose Standard, Light or a Day Off.'); end if; if plan.intensity='standard' and s.fatigue>=92 then return jsonb_build_object('status','blocked','activity_type','home','reason','Fatigue is too high for standard training. Choose Light training or a Day Off.'); end if; end if;
  if plan.training_type='day_off' then
    v_rest_reduction:=round(8+s.recovery*0.08+s.fitness*0.04); v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint; v_sharpness_after:=greatest(1,s.sharpness-2)::smallint; v_morale_after:=least(100,s.morale+1)::smallint; v_focus_after:=least(100,s.focus+1)::smallint;
  else
    if plan.training_type='technical' then
      v_budget:=(case plan.intensity when 'light' then 0.100 when 'standard' then 0.160 else 0.220 end)*v_eff; v_incidental:=(case plan.intensity when 'light' then 0.020 when 'standard' then 0.035 else 0.050 end)*v_eff; v_target_gain:=v_budget*plan.focus_share; v_other_gain:=v_budget*(1-plan.focus_share)/8;
      foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] loop v_gains:=v_gains||jsonb_build_object(k,round(case when k=plan.focus_attribute then v_target_gain else v_other_gain end,4)); end loop;
      v_gains:=v_gains||jsonb_build_object('fitness',round(v_incidental*0.20,4),'stamina',round(v_incidental*0.30,4),'recovery',round(v_incidental*0.15,4),'movement',round(v_incidental*0.35,4)); v_base_fatigue:=case plan.intensity when 'light' then 3 when 'standard' then 6 else 10 end;
    else
      v_budget:=(case plan.intensity when 'light' then 0.100 when 'standard' then 0.160 else 0.220 end)*v_eff; v_incidental:=(case plan.intensity when 'light' then 0.018 when 'standard' then 0.025 else 0.035 end)*v_eff; v_target_gain:=v_budget*plan.focus_share; v_other_gain:=v_budget*(1-plan.focus_share)/3;
      foreach k in array array['fitness','stamina','recovery','movement'] loop v_gains:=v_gains||jsonb_build_object(k,round(case when k=plan.focus_attribute then v_target_gain else v_other_gain end,4)); end loop;
      foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] loop v_gains:=v_gains||jsonb_build_object(k,round(v_incidental/9,4)); end loop; v_base_fatigue:=case plan.intensity when 'light' then 4 when 'standard' then 7 else 11 end;
    end if;
    v_resilience:=(s.fitness+s.stamina+s.recovery)::numeric/300; v_fatigue_cost:=greatest(1,round(v_base_fatigue*(1.15-0.30*v_resilience))); v_fatigue_after:=least(100,s.fatigue+v_fatigue_cost)::smallint; v_sharpness_after:=least(100,s.sharpness+case plan.intensity when 'light' then 1 when 'standard' then 2 else 3 end)::smallint; v_morale_after:=greatest(1,least(100,s.morale+case when plan.intensity='hard' and s.fatigue>=70 then -1 else 0 end))::smallint; v_focus_after:=greatest(1,least(100,s.focus+case when plan.training_type='technical' and plan.intensity<>'hard' then 1 else 0 end))::smallint;
    v_dev_result:=public.apply_player_development_progress_v1(p_player_id,'regular_training',v_gains); v_levels:=coalesce(v_dev_result->'level_ups','{}'::jsonb);
  end if;
  update public.player_skills set fatigue=v_fatigue_after,sharpness=v_sharpness_after,morale=v_morale_after,focus=v_focus_after,updated_at=now() where player_id=p_player_id;
  insert into public.player_training_sessions(player_id,season,month,day,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by) values(p_player_id,p_season,p_month,p_day,plan.training_type,plan.focus_attribute,plan.intensity,v_eff,v_gains,v_levels,v_fatigue_before,v_fatigue_after,v_sharpness_before,v_sharpness_after,v_morale_before,v_morale_after,v_focus_before,v_focus_after,p_processed_by) returning id into v_session_id;
  return jsonb_build_object('status','completed','session_id',v_session_id,'training_type',plan.training_type,'focus_attribute',plan.focus_attribute,'intensity',plan.intensity,'efficiency',v_eff,'development_gains',v_gains,'level_ups',v_levels,'condition',jsonb_build_object('fatigue_before',v_fatigue_before,'fatigue_after',v_fatigue_after,'sharpness_before',v_sharpness_before,'sharpness_after',v_sharpness_after,'morale_before',v_morale_before,'morale_after',v_morale_after,'focus_before',v_focus_before,'focus_after',v_focus_after));
end; $$;

create or replace function public.complete_regular_training_today_v1()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_player_id uuid; d record;
begin if auth.uid() is null then raise exception 'Authentication required.'; end if; select id into v_player_id from public.players where owner_user_id=auth.uid(); if v_player_id is null then raise exception 'Player not found.'; end if; select * into d from public.get_current_game_day_internal_v1(); return public.process_regular_training_for_player_v1(v_player_id,d.season,d.month,d.day,'manual'); end; $$;

create or replace function public.get_training_dashboard_v1()
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare v_player_id uuid; d record; v_activity text; v_plan jsonb; v_skills jsonb; v_progress jsonb; v_today jsonb; v_recent jsonb; v_eligible boolean; v_reason text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if; select id into v_player_id from public.players where owner_user_id=auth.uid(); if v_player_id is null then raise exception 'Player not found.'; end if; select * into d from public.get_current_game_day_internal_v1();
  select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity; v_eligible:=v_activity='home'; v_reason:=case v_activity when 'home' then null when 'travel' then 'Travel day — regular training is unavailable.' when 'tournament' then 'Tournament participation — regular training is unavailable.' when 'training_camp' then 'Training camp active — camp training replaces regular training.' when 'injured' then 'Player is injured — regular training is unavailable.' else 'Regular training is unavailable.' end;
  select coalesce(to_jsonb(x),'null'::jsonb) into v_plan from (select training_type,focus_attribute,intensity,focus_share,is_active,updated_at from public.player_training_plans where player_id=v_player_id) x; if v_plan='null'::jsonb then v_plan:=jsonb_build_object('training_type','day_off','focus_attribute',null,'intensity','standard','focus_share',0.85,'is_active',true); end if;
  select to_jsonb(x) into v_skills from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus from public.player_skills where player_id=v_player_id) x;
  select coalesce(to_jsonb(x),jsonb_build_object('serve',0,'forehand',0,'backhand',0,'return_skill',0,'volley',0,'slice',0,'drop_shot',0,'lob',0,'smash',0,'fitness',0,'stamina',0,'recovery',0,'movement',0)) into v_progress from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement from public.player_training_progress where player_id=v_player_id) x;
  select to_jsonb(x) into v_today from (select id,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,created_at from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_recent from (select id,season,month,day,training_type,focus_attribute,intensity,efficiency,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,created_at from public.player_training_sessions where player_id=v_player_id order by created_at desc limit 10) x;
  return jsonb_build_object('game_day',jsonb_build_object('season',d.season,'month',d.month,'day',d.day),'activity_type',v_activity,'eligible',v_eligible,'block_reason',v_reason,'plan',v_plan,'skills',v_skills,'progress',v_progress,'today_session',coalesce(v_today,'null'::jsonb),'recent_sessions',v_recent,'rules',jsonb_build_object('focus_share',0.85,'other_share',0.15,'travel_fatigue_only',true,'regular_training_states',jsonb_build_array('home'),'blocked_states',jsonb_build_array('travel','tournament','training_camp','injured')));
end; $$;

create or replace function public.set_player_daily_activity_internal_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_activity_type text,p_source text default null,p_reference_id text default null,p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin if p_activity_type not in ('home','travel','tournament','training_camp','injured') then raise exception 'Invalid activity type.'; end if; insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note,updated_at) values(p_player_id,p_season,p_month,p_day,p_activity_type,p_source,p_reference_id,p_note,now()) on conflict(player_id,season,month,day) do update set activity_type=excluded.activity_type,source=excluded.source,reference_id=excluded.reference_id,note=excluded.note,updated_at=now(); end; $$;

revoke all on function public.get_current_game_day_internal_v1() from public,anon,authenticated;
revoke all on function public.training_apply_progress_v1(smallint,numeric,numeric) from public,anon,authenticated;
revoke all on function public.apply_player_development_progress_v1(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.process_regular_training_for_player_v1(uuid,integer,smallint,smallint,text) from public,anon,authenticated;
revoke all on function public.set_player_daily_activity_internal_v1(uuid,integer,smallint,smallint,text,text,text,text) from public,anon,authenticated;
revoke all on function public.set_regular_training_plan_v1(text,text,text) from public,anon;
revoke all on function public.complete_regular_training_today_v1() from public,anon;
revoke all on function public.get_training_dashboard_v1() from public,anon;
grant execute on function public.set_regular_training_plan_v1(text,text,text) to authenticated;
grant execute on function public.complete_regular_training_today_v1() to authenticated;
grant execute on function public.get_training_dashboard_v1() to authenticated;
grant select on public.player_daily_activity,public.player_training_plans,public.player_training_progress,public.player_training_sessions to authenticated;
