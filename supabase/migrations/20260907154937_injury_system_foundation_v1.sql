create table if not exists public.injury_treatment_catalog (
  code text primary key,
  label text not null,
  description text not null,
  care_level text not null check (care_level in ('self_care','rehab','medical')),
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.injury_catalog (
  code text primary key,
  name text not null,
  body_area text not null,
  injury_group text not null,
  severity text not null check (severity in ('minor','moderate','major','severe')),
  description text not null,
  causes jsonb not null default '[]'::jsonb,
  contexts text[] not null default array['regular_training','training_camp','match']::text[],
  relative_weight numeric not null default 1.0 check (relative_weight > 0),
  treatment_code text not null references public.injury_treatment_catalog(code),
  skill_effects jsonb not null default '{}'::jsonb,
  base_performance_penalty numeric not null default 0 check (base_performance_penalty between 0 and 0.40),
  training_out_min_days smallint not null default 0,
  training_out_max_days smallint not null default 0,
  tournament_out_min_days smallint not null default 0,
  tournament_out_max_days smallint not null default 0,
  recovery_min_days smallint not null default 1,
  recovery_max_days smallint not null default 1,
  aggravation_risk numeric not null default 0.05 check (aggravation_risk between 0 and 1),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (training_out_max_days >= training_out_min_days),
  check (tournament_out_max_days >= tournament_out_min_days),
  check (recovery_max_days >= recovery_min_days)
);

create table if not exists public.player_injuries (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  injury_code text not null references public.injury_catalog(code),
  severity text not null check (severity in ('minor','moderate','major','severe')),
  source_type text not null check (source_type in ('regular_training','training_camp','match','other')),
  source_reference_id uuid,
  onset_absolute_day integer not null,
  training_return_absolute_day integer not null,
  tournament_return_absolute_day integer not null,
  expected_full_recovery_absolute_day integer not null,
  recovered_absolute_day integer,
  status text not null default 'active' check (status in ('active','recovering','recovered')),
  progress_percent smallint not null default 0 check (progress_percent between 0 and 100),
  performance_penalty numeric not null default 0 check (performance_penalty between 0 and 0.50),
  aggravation_risk numeric not null default 0 check (aggravation_risk between 0 and 1),
  treatment_code text references public.injury_treatment_catalog(code),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (training_return_absolute_day >= onset_absolute_day),
  check (tournament_return_absolute_day >= onset_absolute_day),
  check (expected_full_recovery_absolute_day >= onset_absolute_day)
);

create unique index if not exists player_injuries_source_once_idx
  on public.player_injuries(player_id,source_type,source_reference_id)
  where source_reference_id is not null;
create index if not exists player_injuries_active_idx
  on public.player_injuries(player_id,status,expected_full_recovery_absolute_day);

create table if not exists public.player_injury_risk_events (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  absolute_day integer not null,
  context text not null,
  risk_percent numeric not null,
  risk_level text not null,
  reasons jsonb not null default '[]'::jsonb,
  notified boolean not null default false,
  created_at timestamptz not null default now(),
  unique(player_id,absolute_day,context)
);

alter table public.player_injuries enable row level security;
alter table public.player_injury_risk_events enable row level security;

drop policy if exists player_injuries_owner_read on public.player_injuries;
create policy player_injuries_owner_read
  on public.player_injuries for select to authenticated
  using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));

drop policy if exists player_injury_risk_owner_read on public.player_injury_risk_events;
create policy player_injury_risk_owner_read
  on public.player_injury_risk_events for select to authenticated
  using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));

grant select on public.injury_catalog, public.injury_treatment_catalog to authenticated;
grant select on public.player_injuries, public.player_injury_risk_events to authenticated;

insert into public.injury_treatment_catalog(code,label,description,care_level,notes) values
('rest_ice','Rest, ice & load reduction','Short-term protection, cooling and reduced load while symptoms settle.','self_care','Best suited to minor soft-tissue irritation and soreness.'),
('mobility_rehab','Mobility & progressive rehabilitation','Controlled mobility, stretching and gradual return to tennis-specific movement.','rehab','Training load should increase only as symptoms improve.'),
('physio_rehab','Physiotherapy rehabilitation','Structured rehabilitation focused on strength, mobility and tennis-specific loading.','rehab','A future Physiotherapist staff role can improve recovery, but staff has no effect in this version.'),
('upper_body_rehab','Upper-body rehabilitation','Progressive shoulder, elbow or wrist rehabilitation with reduced serving and hitting load.','rehab','Avoid repeated high-load serving until the return-to-training date.'),
('medical_review','Medical assessment & protected recovery','Medical evaluation followed by protected recovery and staged return to tennis.','medical','Used for major or severe injuries with tournament unavailability.'),
('foot_care','Foot care & load management','Protect the affected area, reduce friction/load and gradually resume full court movement.','self_care','Usually short-term unless symptoms worsen.')
on conflict(code) do update set
  label=excluded.label,
  description=excluded.description,
  care_level=excluded.care_level,
  notes=excluded.notes,
  is_active=true,
  updated_at=now();

insert into public.injury_catalog(
  code,name,body_area,injury_group,severity,description,causes,contexts,relative_weight,
  treatment_code,skill_effects,base_performance_penalty,
  training_out_min_days,training_out_max_days,
  tournament_out_min_days,tournament_out_max_days,
  recovery_min_days,recovery_max_days,aggravation_risk
) values
('shoulder_tightness','Shoulder tightness','Shoulder','upper_body','minor','Overuse-related shoulder tightness that mainly affects serving and overhead work.','["Repeated serving","High training load","Accumulated fatigue"]',array['regular_training','training_camp','match'],1.25,'rest_ice','{"serve":-0.05,"smash":-0.04}',0.025,0,1,0,0,2,4,0.08),
('shoulder_strain','Shoulder strain','Shoulder','upper_body','moderate','A muscular shoulder strain that reduces power and confidence on overhead shots.','["Explosive serving","Fatigue","Sudden overhead load"]',array['regular_training','training_camp','match'],0.75,'upper_body_rehab','{"serve":-0.12,"smash":-0.10,"forehand":-0.03}',0.065,2,5,1,4,6,11,0.16),
('rotator_cuff_injury','Rotator cuff injury','Shoulder','upper_body','severe','A serious shoulder injury requiring protected recovery before normal serving can resume.','["Heavy cumulative serving load","Aggravated shoulder problem","Acute overhead movement"]',array['match','regular_training','training_camp'],0.10,'medical_review','{"serve":-0.28,"smash":-0.24,"forehand":-0.08}',0.18,12,20,10,18,21,35,0.30),
('elbow_irritation','Elbow irritation','Elbow','upper_body','minor','Tennis-elbow-type irritation causing discomfort on repeated groundstrokes and serves.','["Repeated racket load","High-volume technical work","Fatigue"]',array['regular_training','training_camp','match'],1.10,'rest_ice','{"serve":-0.03,"forehand":-0.04,"backhand":-0.04}',0.025,0,2,0,0,3,5,0.09),
('elbow_tendinopathy','Elbow tendinopathy','Elbow','upper_body','moderate','Persistent elbow tendon overload that affects repeated hitting quality.','["Chronic racket load","Insufficient recovery","Repeated high-risk hitting"]',array['regular_training','training_camp','match'],0.55,'upper_body_rehab','{"serve":-0.07,"forehand":-0.10,"backhand":-0.10,"slice":-0.05}',0.06,3,6,1,4,8,14,0.18),
('wrist_sprain','Wrist sprain','Wrist','upper_body','moderate','A wrist sprain that reduces racket control and attacking acceleration.','["Late contact","Fall or awkward movement","High racket load"]',array['match','regular_training','training_camp'],0.55,'upper_body_rehab','{"serve":-0.07,"forehand":-0.09,"backhand":-0.09,"volley":-0.05}',0.065,3,7,2,5,7,13,0.18),
('lower_back_tightness','Lower-back tightness','Lower back','trunk','minor','Muscular back tightness affecting rotation, serving comfort and movement.','["Long matches","Travel and fatigue","Repeated serving rotation"]',array['match','regular_training','training_camp'],1.10,'mobility_rehab','{"serve":-0.04,"movement":-0.04,"stamina":-0.02}',0.03,0,2,0,0,3,5,0.10),
('lower_back_strain','Lower-back strain','Lower back','trunk','major','A significant back strain that limits explosive movement and serving.','["High fatigue","Long match load","Sudden rotational movement"]',array['match','regular_training','training_camp'],0.35,'medical_review','{"serve":-0.14,"movement":-0.16,"stamina":-0.10,"fitness":-0.07}',0.11,7,12,5,10,14,22,0.24),
('abdominal_strain','Abdominal strain','Abdomen','trunk','moderate','Core-muscle strain that mainly affects serving, rotation and high-intensity movement.','["Explosive serving","Sudden rotation","Accumulated fatigue"]',array['match','regular_training','training_camp'],0.45,'physio_rehab','{"serve":-0.12,"forehand":-0.05,"movement":-0.04}',0.07,3,7,2,5,7,13,0.17),
('hip_flexor_strain','Hip flexor strain','Hip','lower_body','moderate','Hip-flexor strain reducing court coverage and acceleration.','["Repeated sprinting","Long rallies","High fatigue"]',array['match','regular_training','training_camp'],0.65,'physio_rehab','{"movement":-0.13,"stamina":-0.06,"fitness":-0.04}',0.075,3,7,2,5,7,13,0.18),
('hamstring_tightness','Hamstring tightness','Hamstring','lower_body','minor','Hamstring tightness that slightly limits acceleration and long-rally movement.','["Fatigue","Repeated sprinting","Insufficient recovery"]',array['match','regular_training','training_camp'],1.20,'rest_ice','{"movement":-0.06,"stamina":-0.03}',0.03,0,2,0,0,3,5,0.10),
('hamstring_strain','Hamstring strain','Hamstring','lower_body','major','A significant hamstring strain that prevents normal explosive court movement.','["Explosive acceleration","High fatigue","Long match load"]',array['match','regular_training','training_camp'],0.35,'medical_review','{"movement":-0.20,"stamina":-0.12,"fitness":-0.08}',0.13,8,14,6,12,15,24,0.28),
('knee_irritation','Knee irritation','Knee','lower_body','minor','Load-related knee irritation causing mild movement and endurance limitations.','["Repeated hard-court movement","High weekly load","Fatigue"]',array['match','regular_training','training_camp'],0.95,'mobility_rehab','{"movement":-0.06,"stamina":-0.02}',0.03,1,3,0,1,4,7,0.11),
('knee_sprain','Knee sprain','Knee','lower_body','major','A knee sprain with meaningful restrictions on movement and competitive availability.','["Awkward change of direction","Slip","Explosive defensive movement"]',array['match','regular_training','training_camp'],0.22,'medical_review','{"movement":-0.22,"stamina":-0.10,"fitness":-0.08}',0.14,9,16,7,14,17,28,0.30),
('ankle_sprain','Ankle sprain','Ankle','lower_body','moderate','An ankle sprain reducing lateral movement, balance and court coverage.','["Awkward landing","Rapid change of direction","Slip"]',array['match','regular_training','training_camp'],0.65,'physio_rehab','{"movement":-0.16,"stamina":-0.05}',0.09,4,8,3,6,9,15,0.22),
('calf_strain','Calf strain','Calf','lower_body','moderate','Calf-muscle strain limiting acceleration and repeated movement.','["Explosive push-off","Long rallies","High fatigue"]',array['match','regular_training','training_camp'],0.70,'physio_rehab','{"movement":-0.13,"stamina":-0.07}',0.075,3,7,2,5,7,13,0.18),
('foot_blister','Foot blister','Foot','lower_body','minor','A friction-related foot problem that is painful but usually short-lived.','["Long matches","Extended court time","Repeated training load"]',array['match','regular_training','training_camp'],1.25,'foot_care','{"movement":-0.04}',0.02,0,1,0,0,1,3,0.05)
on conflict(code) do update set
  name=excluded.name,
  body_area=excluded.body_area,
  injury_group=excluded.injury_group,
  severity=excluded.severity,
  description=excluded.description,
  causes=excluded.causes,
  contexts=excluded.contexts,
  relative_weight=excluded.relative_weight,
  treatment_code=excluded.treatment_code,
  skill_effects=excluded.skill_effects,
  base_performance_penalty=excluded.base_performance_penalty,
  training_out_min_days=excluded.training_out_min_days,
  training_out_max_days=excluded.training_out_max_days,
  tournament_out_min_days=excluded.tournament_out_min_days,
  tournament_out_max_days=excluded.tournament_out_max_days,
  recovery_min_days=excluded.recovery_min_days,
  recovery_max_days=excluded.recovery_max_days,
  aggravation_risk=excluded.aggravation_risk,
  is_active=true,
  updated_at=now();

create or replace function public.injury_risk_level_v1(p_percent numeric)
returns text language sql immutable as $$
  select case
    when coalesce(p_percent,0)<1 then 'low'
    when p_percent<2 then 'elevated'
    when p_percent<4 then 'high'
    else 'very_high'
  end;
$$;

create or replace function public.get_player_injury_risk_v1(
  p_player_id uuid,
  p_context text default 'general',
  p_intensity text default null,
  p_match_minutes integer default 0,
  p_heat_index numeric default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  s public.player_skills%rowtype;
  v_base numeric;
  v_mult numeric:=1;
  v_risk numeric;
  v_reasons jsonb:='[]'::jsonb;
  v_context text:=lower(coalesce(p_context,'general'));
  v_active integer:=0;
begin
  select * into s from public.player_skills where player_id=p_player_id;
  if s.player_id is null then
    return jsonb_build_object('risk_percent',0,'risk_level','low','reasons','[]'::jsonb);
  end if;

  v_base:=case v_context
    when 'regular_training' then case lower(coalesce(p_intensity,'standard'))
      when 'light' then 0.12 when 'hard' then 0.55 else 0.25 end
    when 'training_camp' then 0.30
    when 'match' then 0.45
    else 0.18
  end;

  if s.fatigue>=80 then
    v_mult:=v_mult*2.4; v_reasons:=v_reasons||'"Very high fatigue"'::jsonb;
  elsif s.fatigue>=65 then
    v_mult:=v_mult*1.75; v_reasons:=v_reasons||'"High fatigue"'::jsonb;
  elsif s.fatigue>=50 then
    v_mult:=v_mult*1.30; v_reasons:=v_reasons||'"Accumulated fatigue"'::jsonb;
  end if;

  if s.fitness<45 then
    v_mult:=v_mult*1.28; v_reasons:=v_reasons||'"Low fitness"'::jsonb;
  elsif s.fitness>=70 then
    v_mult:=v_mult*0.90;
  end if;

  if s.recovery<45 then
    v_mult:=v_mult*1.20; v_reasons:=v_reasons||'"Low recovery ability"'::jsonb;
  elsif s.recovery>=70 then
    v_mult:=v_mult*0.92;
  end if;

  if s.movement<45 and v_context in ('match','training_camp') then
    v_mult:=v_mult*1.12; v_reasons:=v_reasons||'"Limited movement resilience"'::jsonb;
  end if;

  if v_context='match' and p_match_minutes>120 then
    v_mult:=v_mult*(1+least(0.90,(p_match_minutes-120)::numeric/240.0));
    v_reasons:=v_reasons||to_jsonb(format('Long match load (%s min)',p_match_minutes));
  end if;

  if v_context='match' and p_heat_index>0 then
    v_mult:=v_mult*(1+least(0.55,p_heat_index));
    v_reasons:=v_reasons||'"Hot outdoor conditions"'::jsonb;
  end if;

  select count(*) into v_active
  from public.player_injuries
  where player_id=p_player_id and status in ('active','recovering');

  if v_active>0 then
    v_mult:=v_mult*1.35;
    v_reasons:=v_reasons||'"Existing injury / aggravation risk"'::jsonb;
  end if;

  v_risk:=round(least(7.5,greatest(0.03,v_base*v_mult)),2);
  if jsonb_array_length(v_reasons)=0 then
    v_reasons:='["Normal tennis activity risk"]'::jsonb;
  end if;

  return jsonb_build_object(
    'risk_percent',v_risk,
    'risk_level',public.injury_risk_level_v1(v_risk),
    'reasons',v_reasons,
    'context',v_context,
    'staff_modifier_applied',false
  );
end;
$$;

create or replace function public.player_training_blocked_by_injury_v1(p_player_id uuid,p_absolute_day integer)
returns boolean language sql stable security definer set search_path='public' as $$
  select exists(
    select 1 from public.player_injuries i
    where i.player_id=p_player_id
      and i.status in ('active','recovering')
      and p_absolute_day < i.training_return_absolute_day
  );
$$;

create or replace function public.player_tournament_blocked_by_injury_v1(p_player_id uuid,p_absolute_day integer)
returns boolean language sql stable security definer set search_path='public' as $$
  select exists(
    select 1 from public.player_injuries i
    where i.player_id=p_player_id
      and i.status in ('active','recovering')
      and p_absolute_day < i.tournament_return_absolute_day
  );
$$;

create or replace function public.get_player_active_injury_effects_v1(p_player_id uuid,p_absolute_day integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  v_day integer:=p_absolute_day;
  v_mods jsonb:='{}'::jsonb;
  v_pen numeric:=0;
  v_train boolean:=true;
  v_comp boolean:=true;
  r record;
  k text;
  val numeric;
  cur numeric;
begin
  if v_day is null then
    select public.game_day_absolute_v1(d.season,d.month,d.day)
    into v_day
    from public.get_current_game_day_internal_v1() d;
  end if;

  for r in
    select i.*,c.skill_effects
    from public.player_injuries i
    join public.injury_catalog c on c.code=i.injury_code
    where i.player_id=p_player_id
      and i.status in ('active','recovering')
      and v_day<=i.expected_full_recovery_absolute_day
  loop
    v_pen:=least(0.35,v_pen+r.performance_penalty);
    if v_day<r.training_return_absolute_day then v_train:=false; end if;
    if v_day<r.tournament_return_absolute_day then v_comp:=false; end if;

    for k,val in select key,value::numeric from jsonb_each_text(r.skill_effects) loop
      cur:=coalesce((v_mods->>k)::numeric,0);
      v_mods:=jsonb_set(v_mods,array[k],to_jsonb(greatest(-0.40,cur+val)),true);
    end loop;
  end loop;

  return jsonb_build_object(
    'can_train',v_train,'can_compete',v_comp,
    'overall_penalty',round(v_pen,4),'skill_modifiers',v_mods
  );
end;
$$;

create or replace function public.roll_player_injury_v1(
  p_player_id uuid,
  p_context text,
  p_source_reference_id uuid default null,
  p_intensity text default null,
  p_match_minutes integer default 0,
  p_heat_index numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  v_abs integer;
  v_risk jsonb;
  v_pct numeric;
  v_seed text;
  v_roll numeric;
  v_pick numeric;
  v_total numeric;
  v_running numeric:=0;
  c public.injury_catalog%rowtype;
  v_train integer;
  v_tour integer;
  v_rec integer;
  v_owner uuid;
  v_id uuid;
  v_detail jsonb;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  if p_source_reference_id is not null and exists(
    select 1 from public.player_injuries
    where player_id=p_player_id and source_type=p_context and source_reference_id=p_source_reference_id
  ) then
    return jsonb_build_object('status','already_processed');
  end if;

  v_risk:=public.get_player_injury_risk_v1(p_player_id,p_context,p_intensity,p_match_minutes,p_heat_index);
  v_pct:=(v_risk->>'risk_percent')::numeric;
  v_seed:=p_player_id::text||':'||p_context||':'||coalesce(p_source_reference_id::text,v_abs::text);
  v_roll:=public.match_engine_random_v1(v_seed||':injury',1)*100;

  insert into public.player_injury_risk_events(player_id,absolute_day,context,risk_percent,risk_level,reasons)
  values(p_player_id,v_abs,p_context,v_pct,v_risk->>'risk_level',v_risk->'reasons')
  on conflict(player_id,absolute_day,context) do update set
    risk_percent=excluded.risk_percent,
    risk_level=excluded.risk_level,
    reasons=excluded.reasons;

  if v_roll>=v_pct then
    return jsonb_build_object('status','clear','risk',v_risk,'roll',round(v_roll,2));
  end if;

  select sum(relative_weight) into v_total
  from public.injury_catalog
  where is_active and p_context=any(contexts);

  v_pick:=public.match_engine_random_v1(v_seed||':type',2)*greatest(v_total,1);
  for c in
    select * from public.injury_catalog
    where is_active and p_context=any(contexts)
    order by code
  loop
    v_running:=v_running+c.relative_weight;
    if v_pick<=v_running then exit; end if;
  end loop;

  if c.code is null then
    select * into c from public.injury_catalog where is_active order by code limit 1;
  end if;

  v_train:=c.training_out_min_days+floor(public.match_engine_random_v1(v_seed||':train',3)*(c.training_out_max_days-c.training_out_min_days+1))::integer;
  v_tour:=c.tournament_out_min_days+floor(public.match_engine_random_v1(v_seed||':tour',4)*(c.tournament_out_max_days-c.tournament_out_min_days+1))::integer;
  v_rec:=c.recovery_min_days+floor(public.match_engine_random_v1(v_seed||':recovery',5)*(c.recovery_max_days-c.recovery_min_days+1))::integer;
  v_detail:=jsonb_build_object(
    'risk_at_onset',v_risk,'roll',round(v_roll,2),'cause_context',p_context,
    'intensity',p_intensity,'match_minutes',p_match_minutes,'heat_index',p_heat_index
  );

  insert into public.player_injuries(
    player_id,injury_code,severity,source_type,source_reference_id,onset_absolute_day,
    training_return_absolute_day,tournament_return_absolute_day,expected_full_recovery_absolute_day,
    status,performance_penalty,aggravation_risk,treatment_code,details
  ) values(
    p_player_id,c.code,c.severity,p_context,p_source_reference_id,v_abs,
    v_abs+v_train,v_abs+v_tour,v_abs+v_rec,
    'active',c.base_performance_penalty,c.aggravation_risk,c.treatment_code,v_detail
  ) returning id into v_id;

  select owner_user_id into v_owner from public.players where id=p_player_id;
  if v_owner is not null then
    perform public.emit_notification_v1(
      v_owner,p_player_id,'player.injury.detected','Injury detected',
      format(
        '%s — %s. Training return: %s day%s; tournament return: %s day%s; expected full recovery: %s day%s.',
        c.name,initcap(c.severity),
        v_train,case when v_train=1 then '' else 's' end,
        v_tour,case when v_tour=1 then '' else 's' end,
        v_rec,case when v_rec=1 then '' else 's' end
      ),
      '/game/injuries',
      jsonb_build_object(
        'injury_id',v_id,'injury_code',c.code,'severity',c.severity,
        'training_out_days',v_train,'tournament_out_days',v_tour,'recovery_days',v_rec
      ),
      format('injury:%s:%s',p_player_id,v_id)
    );
  end if;

  return jsonb_build_object(
    'status','injured','injury_id',v_id,'injury_code',c.code,'injury_name',c.name,
    'severity',c.severity,'training_out_days',v_train,'tournament_out_days',v_tour,
    'recovery_days',v_rec,'risk',v_risk
  );
end;
$$;

create or replace function public.process_due_injury_recovery_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  v_abs integer;
  r record;
  v_count integer:=0;
  v_owner uuid;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  for r in
    select i.id,i.player_id,i.injury_code,c.name,i.expected_full_recovery_absolute_day,i.onset_absolute_day
    from public.player_injuries i
    join public.injury_catalog c on c.code=i.injury_code
    where i.status in ('active','recovering')
    for update of i skip locked
  loop
    if v_abs>=r.expected_full_recovery_absolute_day then
      update public.player_injuries
      set status='recovered',progress_percent=100,recovered_absolute_day=v_abs,updated_at=now()
      where id=r.id;

      select owner_user_id into v_owner from public.players where id=r.player_id;
      if v_owner is not null then
        perform public.emit_notification_v1(
          v_owner,r.player_id,'player.injury.recovered','Fully recovered',
          format('%s has fully recovered. Normal training and tournament availability are restored.',r.name),
          '/game/injuries',jsonb_build_object('injury_id',r.id,'injury_code',r.injury_code),
          format('injury-recovered:%s',r.id)
        );
      end if;
      v_count:=v_count+1;
    else
      update public.player_injuries
      set status=case when v_abs>onset_absolute_day then 'recovering' else status end,
          progress_percent=least(99,greatest(0,round(100.0*(v_abs-onset_absolute_day)/greatest(1,expected_full_recovery_absolute_day-onset_absolute_day))))::smallint,
          updated_at=now()
      where id=r.id;
    end if;
  end loop;

  return jsonb_build_object('status','processed','recovered',v_count,'absolute_day',v_abs);
end;
$$;

create or replace function public.get_player_injury_dashboard_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  v_player uuid;
  d record;
  v_abs integer;
  v_current jsonb;
  v_history jsonb;
  v_catalog jsonb;
  v_treatments jsonb;
  v_risk jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human'
  order by created_at desc
  limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;

  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  v_risk:=public.get_player_injury_risk_v1(v_player,'general',null,0,0);

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,'injury_code',i.injury_code,'name',c.name,'body_area',c.body_area,
    'injury_group',c.injury_group,'severity',i.severity,'description',c.description,
    'causes',c.causes,'source_type',i.source_type,'onset_absolute_day',i.onset_absolute_day,
    'training_return_absolute_day',i.training_return_absolute_day,
    'tournament_return_absolute_day',i.tournament_return_absolute_day,
    'expected_full_recovery_absolute_day',i.expected_full_recovery_absolute_day,
    'progress_percent',i.progress_percent,'performance_penalty',i.performance_penalty,
    'aggravation_risk',i.aggravation_risk,'skill_effects',c.skill_effects,
    'treatment',jsonb_build_object(
      'code',t.code,'label',t.label,'description',t.description,'care_level',t.care_level,'notes',t.notes
    ),
    'can_train',v_abs>=i.training_return_absolute_day,
    'can_compete',v_abs>=i.tournament_return_absolute_day
  ) order by i.onset_absolute_day desc),'[]'::jsonb)
  into v_current
  from public.player_injuries i
  join public.injury_catalog c on c.code=i.injury_code
  join public.injury_treatment_catalog t on t.code=i.treatment_code
  where i.player_id=v_player
    and i.status in ('active','recovering')
    and v_abs<=i.expected_full_recovery_absolute_day;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',i.id,'injury_code',i.injury_code,'name',c.name,'body_area',c.body_area,
    'severity',i.severity,'source_type',i.source_type,'onset_absolute_day',i.onset_absolute_day,
    'recovered_absolute_day',i.recovered_absolute_day,
    'recovery_days',coalesce(i.recovered_absolute_day,i.expected_full_recovery_absolute_day)-i.onset_absolute_day,
    'treatment_label',t.label
  ) order by i.onset_absolute_day desc),'[]'::jsonb)
  into v_history
  from public.player_injuries i
  join public.injury_catalog c on c.code=i.injury_code
  join public.injury_treatment_catalog t on t.code=i.treatment_code
  where i.player_id=v_player and i.status='recovered';

  select coalesce(jsonb_agg(jsonb_build_object(
    'code',c.code,'name',c.name,'body_area',c.body_area,'injury_group',c.injury_group,
    'severity',c.severity,'description',c.description,'causes',c.causes,
    'skill_effects',c.skill_effects,
    'training_out_days',jsonb_build_array(c.training_out_min_days,c.training_out_max_days),
    'tournament_out_days',jsonb_build_array(c.tournament_out_min_days,c.tournament_out_max_days),
    'recovery_days',jsonb_build_array(c.recovery_min_days,c.recovery_max_days),
    'treatment_code',c.treatment_code,'treatment_label',t.label,'aggravation_risk',c.aggravation_risk
  ) order by c.body_area,c.name),'[]'::jsonb)
  into v_catalog
  from public.injury_catalog c
  join public.injury_treatment_catalog t on t.code=c.treatment_code
  where c.is_active;

  select coalesce(jsonb_agg(jsonb_build_object(
    'code',code,'label',label,'description',description,'care_level',care_level,'notes',notes
  ) order by care_level,label),'[]'::jsonb)
  into v_treatments
  from public.injury_treatment_catalog
  where is_active;

  return jsonb_build_object(
    'absolute_day',v_abs,
    'current_injuries',v_current,
    'healthy',jsonb_array_length(v_current)=0,
    'risk',v_risk,
    'history',v_history,
    'catalog',v_catalog,
    'treatments',v_treatments,
    'rules',jsonb_build_object(
      'staff_injury_modifier_active',false,
      'risk_is_per_activity',true,
      'recovery_is_game_day_based',true
    )
  );
end;
$$;

create or replace function public.notify_injury_risk_if_needed_v1(
  p_player_id uuid,p_context text default 'general',p_intensity text default null
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  v_abs integer;
  v_risk jsonb;
  v_level text;
  v_owner uuid;
  v_event uuid;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  v_risk:=public.get_player_injury_risk_v1(p_player_id,p_context,p_intensity,0,0);
  v_level:=v_risk->>'risk_level';

  insert into public.player_injury_risk_events(player_id,absolute_day,context,risk_percent,risk_level,reasons)
  values(p_player_id,v_abs,p_context,(v_risk->>'risk_percent')::numeric,v_level,v_risk->'reasons')
  on conflict(player_id,absolute_day,context) do update set
    risk_percent=excluded.risk_percent,
    risk_level=excluded.risk_level,
    reasons=excluded.reasons
  returning id into v_event;

  if v_level in ('elevated','high','very_high')
     and not exists(select 1 from public.player_injury_risk_events where id=v_event and notified) then
    select owner_user_id into v_owner from public.players where id=p_player_id;
    if v_owner is not null then
      perform public.emit_notification_v1(
        v_owner,p_player_id,'player.injury.risk','Injury risk increased',
        format(
          'Current injury risk is %s (%s%%) for %s. Review fatigue, recovery and workload before demanding activity.',
          replace(v_level,'_',' '),v_risk->>'risk_percent',replace(p_context,'_',' ')
        ),
        '/game/injuries',jsonb_build_object('risk',v_risk,'context',p_context),
        format('injury-risk:%s:%s:%s',p_player_id,v_abs,p_context)
      );
      update public.player_injury_risk_events set notified=true where id=v_event;
    end if;
  end if;

  return v_risk;
end;
$$;

create or replace function public.roll_regular_training_injury_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  if new.session_role='planned_training' then
    perform public.notify_injury_risk_if_needed_v1(new.player_id,'regular_training',new.intensity);
    perform public.roll_player_injury_v1(new.player_id,'regular_training',new.id,new.intensity,0,0);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_roll_regular_training_injury on public.player_training_sessions;
create trigger trg_roll_regular_training_injury
  after insert on public.player_training_sessions
  for each row execute function public.roll_regular_training_injury_trigger_v1();

create or replace function public.roll_training_camp_injury_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  if new.day_role='development' then
    perform public.notify_injury_risk_if_needed_v1(new.player_id,'training_camp','standard');
    perform public.roll_player_injury_v1(new.player_id,'training_camp',new.id,'standard',0,0);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_roll_training_camp_injury on public.player_training_camp_days;
create trigger trg_roll_training_camp_injury
  after insert on public.player_training_camp_days
  for each row execute function public.roll_training_camp_injury_trigger_v1();

create or replace function public.block_injured_training_session_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare v_abs integer;
begin
  v_abs:=public.game_day_absolute_v1(new.season,new.month,new.day);
  if new.session_role not in ('user_day_off','active_recovery','full_rest')
     and public.player_training_blocked_by_injury_v1(new.player_id,v_abs) then
    raise exception 'Current injury prevents normal training. Open Injury & Health on Overview for the return date and treatment details.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_block_injured_training_session on public.player_training_sessions;
create trigger trg_block_injured_training_session
  before insert on public.player_training_sessions
  for each row execute function public.block_injured_training_session_v1();

create or replace function public.block_injured_camp_day_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
begin
  if new.day_role='development'
     and public.player_training_blocked_by_injury_v1(new.player_id,new.absolute_day) then
    raise exception 'Current injury prevents training-camp development work. Review Injury & Health for the return date.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_block_injured_camp_day on public.player_training_camp_days;
create trigger trg_block_injured_camp_day
  before insert on public.player_training_camp_days
  for each row execute function public.block_injured_camp_day_v1();

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,
  title_template,message_template,default_route,severity,default_in_app,default_email,
  default_push,is_user_configurable,is_active,updated_at
) values
('player.injury.risk','player_health','Injury risk increased','Warn when workload and condition raise short-term injury risk.','injury risk calculation','Risk reaches elevated, high or very high for an activity.','Injury engine','player_injury_risk_events','Injury risk increased','Current injury risk has increased.','/game/injuries','warning',true,false,false,true,true,now()),
('player.injury.detected','player_health','Injury detected','Explain a newly generated injury and its availability consequences.','injury generated','An injury roll succeeds.','Injury engine','player_injuries','Injury detected','A new injury has been detected.','/game/injuries','error',true,true,false,false,true,now()),
('player.injury.recovered','player_health','Fully recovered','Confirm that an injury has cleared.','injury recovery processor','Expected full recovery date is reached.','Injury engine','player_injuries','Fully recovered','Your player has fully recovered.','/game/injuries','info',true,false,false,true,true,now())
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  severity=excluded.severity,
  is_active=true,
  updated_at=now();

revoke all on function public.get_player_injury_dashboard_v1() from public,anon;
grant execute on function public.get_player_injury_dashboard_v1() to authenticated;

select cron.unschedule(jobid) from cron.job where jobname='tennis-injury-recovery-hourly';
select cron.schedule(
  'tennis-injury-recovery-hourly',
  '17 * * * *',
  $$select public.process_due_injury_recovery_v1();$$
);
