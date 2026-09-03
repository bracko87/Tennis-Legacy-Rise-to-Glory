create table if not exists public.player_weekly_training_plan_days (
  player_id uuid not null references public.players(id) on delete cascade,
  absolute_day integer not null check (absolute_day >= 0),
  training_type text not null check (training_type in ('technical','physical','day_off')),
  focus_attribute text,
  intensity text not null default 'standard' check (intensity in ('light','standard','hard')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (player_id, absolute_day),
  constraint player_weekly_training_plan_focus_check check (
    (training_type='technical' and focus_attribute in ('serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash')) or
    (training_type='physical' and focus_attribute in ('fitness','stamina','recovery','movement')) or
    (training_type='day_off' and focus_attribute is null)
  )
);

create index if not exists idx_player_weekly_training_plan_days_absolute
  on public.player_weekly_training_plan_days(player_id, absolute_day);

alter table public.player_weekly_training_plan_days enable row level security;
revoke all on public.player_weekly_training_plan_days from anon, authenticated;
grant select on public.player_weekly_training_plan_days to authenticated;

drop policy if exists player_weekly_training_plan_days_owner_select on public.player_weekly_training_plan_days;
create policy player_weekly_training_plan_days_owner_select
on public.player_weekly_training_plan_days for select to authenticated
using (exists (
  select 1 from public.players p
  where p.id=player_id and p.owner_user_id=auth.uid()
));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='player_weekly_training_plan_days'
  ) then
    alter publication supabase_realtime add table public.player_weekly_training_plan_days;
  end if;
end $$;

create or replace function public.assert_regular_training_choice_v1(
  p_training_type text,
  p_focus_attribute text,
  p_intensity text
) returns void
language plpgsql immutable set search_path='public' as $$
begin
  if p_training_type not in ('technical','physical','day_off') then raise exception 'Invalid training type.'; end if;
  if p_intensity not in ('light','standard','hard') then raise exception 'Invalid training intensity.'; end if;
  if p_training_type='technical' and p_focus_attribute not in ('serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash') then raise exception 'Choose a valid tennis skill.'; end if;
  if p_training_type='physical' and p_focus_attribute not in ('fitness','stamina','recovery','movement') then raise exception 'Choose a valid physical skill.'; end if;
  if p_training_type='day_off' and p_focus_attribute is not null then raise exception 'Day Off cannot have a focus attribute.'; end if;
end;
$$;

create or replace function public.set_training_week_day_v1(
  p_absolute_day integer,
  p_training_type text,
  p_focus_attribute text default null,
  p_intensity text default 'standard'
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_player_id uuid;
  d record;
  now_day record;
  v_now_abs integer;
  v_activity text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player_id is null then raise exception 'Player not found.'; end if;
  if p_training_type='day_off' then p_focus_attribute:=null; end if;
  perform public.assert_regular_training_choice_v1(p_training_type,p_focus_attribute,p_intensity);
  select * into now_day from public.get_current_game_day_internal_v1();
  v_now_abs:=public.game_day_absolute_v1(now_day.season,now_day.month,now_day.day);
  if p_absolute_day < v_now_abs then raise exception 'Past training days cannot be changed.'; end if;
  if p_absolute_day > v_now_abs+55 then raise exception 'Training can currently be planned up to eight weeks ahead.'; end if;
  select * into d from public.absolute_game_day_v1(p_absolute_day);
  select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
  if v_activity <> 'home' then raise exception 'This day is owned by % and cannot contain regular training.', replace(v_activity,'_',' '); end if;
  if exists(select 1 from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day) then raise exception 'This day has already been processed and cannot be changed.'; end if;
  insert into public.player_weekly_training_plan_days(player_id,absolute_day,training_type,focus_attribute,intensity,updated_at)
  values(v_player_id,p_absolute_day,p_training_type,p_focus_attribute,p_intensity,now())
  on conflict(player_id,absolute_day) do update set training_type=excluded.training_type,focus_attribute=excluded.focus_attribute,intensity=excluded.intensity,updated_at=now();
  return jsonb_build_object('status','saved','absolute_day',p_absolute_day,'season',d.season,'month',d.month,'day',d.day,'training_type',p_training_type,'focus_attribute',p_focus_attribute,'intensity',p_intensity);
end;
$$;

create or replace function public.set_training_week_plan_v1(
  p_week_start_absolute_day integer,
  p_training_type text,
  p_focus_attribute text default null,
  p_intensity text default 'standard'
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_player_id uuid;
  now_day record;
  v_now_abs integer;
  start_day record;
  v_expected_start integer;
  v_abs integer;
  d record;
  v_activity text;
  v_applied integer:=0;
  v_skipped integer:=0;
  i integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player_id is null then raise exception 'Player not found.'; end if;
  if p_training_type='day_off' then p_focus_attribute:=null; end if;
  perform public.assert_regular_training_choice_v1(p_training_type,p_focus_attribute,p_intensity);
  select * into now_day from public.get_current_game_day_internal_v1();
  v_now_abs:=public.game_day_absolute_v1(now_day.season,now_day.month,now_day.day);
  select * into start_day from public.absolute_game_day_v1(p_week_start_absolute_day);
  if start_day.season_week not between 1 and 52 then raise exception 'Choose a competition week.'; end if;
  v_expected_start:=public.training_camp_week_start_absolute_v1(start_day.season,start_day.season_week);
  if v_expected_start<>p_week_start_absolute_day then raise exception 'Week plan must start on Monday.'; end if;
  if p_week_start_absolute_day+6 < v_now_abs then raise exception 'Past weeks cannot be changed.'; end if;
  if p_week_start_absolute_day > v_now_abs+55 then raise exception 'Training can currently be planned up to eight weeks ahead.'; end if;
  for i in 0..6 loop
    v_abs:=p_week_start_absolute_day+i;
    select * into d from public.absolute_game_day_v1(v_abs);
    select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
    if v_abs < v_now_abs or v_activity<>'home' or exists(select 1 from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day) then
      v_skipped:=v_skipped+1;
    else
      insert into public.player_weekly_training_plan_days(player_id,absolute_day,training_type,focus_attribute,intensity,updated_at)
      values(v_player_id,v_abs,p_training_type,p_focus_attribute,p_intensity,now())
      on conflict(player_id,absolute_day) do update set training_type=excluded.training_type,focus_attribute=excluded.focus_attribute,intensity=excluded.intensity,updated_at=now();
      v_applied:=v_applied+1;
    end if;
  end loop;
  return jsonb_build_object('status','saved','week_start_absolute_day',p_week_start_absolute_day,'applied_days',v_applied,'skipped_days',v_skipped);
end;
$$;

create or replace function public.get_training_week_planner_v1(p_week_offset smallint default 0)
returns jsonb
language plpgsql stable security definer set search_path='public' as $$
declare
  v_player_id uuid;
  now_day record;
  v_now_abs integer;
  now_info record;
  v_season integer;
  v_week integer;
  v_start integer;
  v_base_plan public.player_training_plans%rowtype;
  v_days jsonb:='[]'::jsonb;
  v_abs integer;
  d record;
  a public.player_daily_activity%rowtype;
  wp public.player_weekly_training_plan_days%rowtype;
  sess public.player_training_sessions%rowtype;
  v_activity text;
  v_role text;
  v_plan_type text;
  v_plan_focus text;
  v_plan_intensity text;
  v_plan_source text;
  v_editable boolean;
  v_lock_reason text;
  v_names text[]:=array['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  i integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_week_offset < 0 or p_week_offset > 8 then raise exception 'Week offset must be between 0 and 8.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into now_day from public.get_current_game_day_internal_v1();
  v_now_abs:=public.game_day_absolute_v1(now_day.season,now_day.month,now_day.day);
  select * into now_info from public.absolute_game_day_v1(v_now_abs);
  v_season:=now_info.season;
  v_week:=greatest(1,now_info.season_week::integer)+p_week_offset;
  while v_week>52 loop v_week:=v_week-52; v_season:=v_season+1; end loop;
  v_start:=public.training_camp_week_start_absolute_v1(v_season,v_week::smallint);
  select * into v_base_plan from public.player_training_plans where player_id=v_player_id;
  if not found then v_base_plan.training_type:='day_off'; v_base_plan.focus_attribute:=null; v_base_plan.intensity:='standard'; v_base_plan.focus_share:=0.85; end if;
  for i in 0..6 loop
    v_abs:=v_start+i;
    select * into d from public.absolute_game_day_v1(v_abs);
    select * into a from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day;
    v_activity:=coalesce(a.activity_type,'home');
    select * into sess from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day;
    select * into wp from public.player_weekly_training_plan_days where player_id=v_player_id and absolute_day=v_abs;
    if wp.player_id is not null then
      v_plan_type:=wp.training_type; v_plan_focus:=wp.focus_attribute; v_plan_intensity:=wp.intensity; v_plan_source:='weekly_plan';
      v_role:=case when wp.training_type='day_off' then 'user_day_off' else 'planned_training' end;
    else
      v_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);
      if v_role in ('active_recovery','full_rest') then
        v_plan_type:='day_off'; v_plan_focus:=null; v_plan_intensity:='standard'; v_plan_source:='automatic_recovery';
      else
        v_plan_type:=v_base_plan.training_type; v_plan_focus:=v_base_plan.focus_attribute; v_plan_intensity:=v_base_plan.intensity; v_plan_source:='default_plan';
      end if;
    end if;
    v_editable:=v_abs>=v_now_abs and v_activity='home' and sess.id is null;
    v_lock_reason:=case when v_abs<v_now_abs then 'Past day' when sess.id is not null then 'Already processed' when v_activity='travel' then coalesce(a.note,'Travel day') when v_activity='tournament' then coalesce(a.note,'Tournament day') when v_activity='training_camp' then coalesce(a.note,'Training Camp') when v_activity='injured' then coalesce(a.note,'Injury / recovery') else null end;
    v_days:=v_days||jsonb_build_array(jsonb_build_object(
      'absolute_day',v_abs,'weekday',i+1,'weekday_name',v_names[i+1],'season',d.season,'season_week',d.season_week,'month',d.month,'day',d.day,
      'activity_type',v_activity,'activity_source',a.source,'activity_note',a.note,'activity_reference_id',a.reference_id,'editable',v_editable,'lock_reason',v_lock_reason,
      'plan_source',v_plan_source,'training_type',v_plan_type,'focus_attribute',v_plan_focus,'intensity',v_plan_intensity,'session_role',v_role,'processed',sess.id is not null,'session_id',sess.id
    ));
    a:=null; wp:=null; sess:=null;
  end loop;
  return jsonb_build_object('season',v_season,'season_week',v_week,'week_offset',p_week_offset,'week_start_absolute_day',v_start,'week_end_absolute_day',v_start+6,'current_absolute_day',v_now_abs,'days',v_days,'rules',jsonb_build_object('editable_activity','home','calendar_override_states',jsonb_build_array('travel','tournament','training_camp','injured'),'daily_plan_overrides_default_rhythm',true,'automatic_daily_processor_compatible',true));
end;
$$;

create or replace function public.process_regular_training_for_player_v2(
  p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine'
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  s public.player_skills%rowtype; base_plan public.player_training_plans%rowtype; day_plan public.player_weekly_training_plan_days%rowtype;
  v_activity text; v_readiness numeric; v_eff numeric; v_budget numeric; v_incidental numeric; v_target_gain numeric; v_other_gain numeric;
  v_raw_gains jsonb:='{}'::jsonb; v_gains jsonb:='{}'::jsonb; v_levels jsonb:='{}'::jsonb; v_base_fatigue integer; v_resilience numeric; v_fatigue_cost integer;
  v_fatigue_before smallint; v_sharpness_before smallint; v_morale_before smallint; v_focus_before smallint; v_fatigue_after smallint; v_sharpness_after smallint; v_morale_after smallint; v_focus_after smallint;
  v_rest_reduction integer; v_session_id uuid; k text; v_dev_result jsonb; v_abs integer; v_day_info record; v_week_start integer; v_weekday smallint:=0; v_session_role text:='planned_training';
  v_stored_training_type text; v_stored_focus text; v_weekly_dev_scale numeric:=1.0; v_raw_gain numeric; v_effective_gain numeric; v_attr_value smallint;
  v_training_type text; v_focus_attribute text; v_intensity text; v_focus_share numeric:=0.85; v_plan_source text:='default_plan';
begin
  if p_processed_by not in ('manual','daily_engine') then raise exception 'Invalid processor.'; end if;
  if exists(select 1 from public.player_training_sessions where player_id=p_player_id and season=p_season and month=p_month and day=p_day) then return (select jsonb_build_object('status','already_processed','session_id',id) from public.player_training_sessions where player_id=p_player_id and season=p_season and month=p_month and day=p_day); end if;
  select coalesce((select activity_type from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day),'home') into v_activity;
  if v_activity<>'home' then return jsonb_build_object('status','blocked','activity_type',v_activity,'reason',case v_activity when 'travel' then 'Regular training is unavailable on travel days.' when 'tournament' then 'Regular training is unavailable during tournament participation.' when 'training_camp' then 'Regular training is replaced by training-camp work.' when 'injured' then 'Regular training is unavailable while the player is injured.' else 'Regular training is unavailable today.' end); end if;
  select * into s from public.player_skills where player_id=p_player_id for update; if not found then raise exception 'Player skills are unavailable.'; end if;
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);
  select * into day_plan from public.player_weekly_training_plan_days where player_id=p_player_id and absolute_day=v_abs;
  if day_plan.player_id is not null then v_training_type:=day_plan.training_type; v_focus_attribute:=day_plan.focus_attribute; v_intensity:=day_plan.intensity; v_plan_source:='weekly_plan';
  else select * into base_plan from public.player_training_plans where player_id=p_player_id; if not found then insert into public.player_training_plans(player_id,training_type,focus_attribute,intensity) values(p_player_id,'day_off',null,'standard') returning * into base_plan; end if; v_training_type:=base_plan.training_type; v_focus_attribute:=base_plan.focus_attribute; v_intensity:=base_plan.intensity; v_focus_share:=coalesce(base_plan.focus_share,0.85); end if;
  select * into v_day_info from public.absolute_game_day_v1(v_abs); if v_day_info.season_week between 1 and 52 then v_week_start:=public.training_camp_week_start_absolute_v1(p_season,v_day_info.season_week); v_weekday:=(v_abs-v_week_start+1)::smallint; end if;
  if v_training_type='day_off' then v_session_role:='user_day_off'; elsif v_plan_source='weekly_plan' then v_session_role:='planned_training'; elsif v_weekday=6 then v_session_role:='active_recovery'; elsif v_weekday=7 then v_session_role:='full_rest'; else v_session_role:='planned_training'; end if;
  if v_day_info.season_week between 1 and 52 and v_session_role='planned_training' then v_weekly_dev_scale:=1.40; end if;
  v_fatigue_before:=s.fatigue; v_sharpness_before:=s.sharpness; v_morale_before:=s.morale; v_focus_before:=s.focus; v_readiness:=(s.morale+s.confidence+s.sharpness+s.focus+(100-s.fatigue))::numeric/500; v_eff:=round(greatest(0.70,least(1.05,0.78+0.37*v_readiness)),4); v_stored_training_type:=v_training_type; v_stored_focus:=v_focus_attribute;
  if v_session_role='user_day_off' then v_rest_reduction:=round(8+s.recovery*0.08+s.fitness*0.04); v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint; v_sharpness_after:=greatest(1,s.sharpness-2)::smallint; v_morale_after:=least(100,s.morale+1)::smallint; v_focus_after:=least(100,s.focus+1)::smallint; v_stored_training_type:='day_off'; v_stored_focus:=null;
  elsif v_session_role='active_recovery' then v_rest_reduction:=round(6+s.recovery*0.05+s.fitness*0.02); v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint; v_sharpness_after:=s.sharpness; v_morale_after:=least(100,s.morale+1)::smallint; v_focus_after:=least(100,s.focus+1)::smallint; v_stored_training_type:='day_off'; v_stored_focus:=null;
  elsif v_session_role='full_rest' then v_rest_reduction:=round(9+s.recovery*0.06+s.fitness*0.03); v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint; v_sharpness_after:=greatest(1,s.sharpness-1)::smallint; v_morale_after:=least(100,s.morale+1)::smallint; v_focus_after:=least(100,s.focus+1)::smallint; v_stored_training_type:='day_off'; v_stored_focus:=null;
  else
    if v_intensity='hard' and s.fatigue>=80 then return jsonb_build_object('status','blocked','activity_type','home','reason','Fatigue is too high for hard training. Choose Standard, Light or a Day Off.'); end if;
    if v_intensity='standard' and s.fatigue>=92 then return jsonb_build_object('status','blocked','activity_type','home','reason','Fatigue is too high for standard training. Choose Light training or a Day Off.'); end if;
    if v_training_type='technical' then
      v_budget:=(case v_intensity when 'light' then 0.100 when 'standard' then 0.160 else 0.220 end)*v_eff*v_weekly_dev_scale; v_incidental:=(case v_intensity when 'light' then 0.020 when 'standard' then 0.035 else 0.050 end)*v_eff*v_weekly_dev_scale; v_target_gain:=v_budget*v_focus_share; v_other_gain:=v_budget*(1-v_focus_share)/8;
      foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] loop v_raw_gain:=case when k=v_focus_attribute then v_target_gain else v_other_gain end; v_attr_value:=(to_jsonb(s)->>k)::smallint; v_effective_gain:=public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain); v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4)); v_gains:=v_gains||jsonb_build_object(k,v_effective_gain); end loop;
      foreach k in array array['fitness','stamina','recovery','movement'] loop v_raw_gain:=v_incidental*case k when 'fitness' then 0.20 when 'stamina' then 0.30 when 'recovery' then 0.15 else 0.35 end; v_attr_value:=(to_jsonb(s)->>k)::smallint; v_effective_gain:=public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain); v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4)); v_gains:=v_gains||jsonb_build_object(k,v_effective_gain); end loop;
      v_base_fatigue:=case v_intensity when 'light' then 3 when 'standard' then 6 else 10 end;
    else
      v_budget:=(case v_intensity when 'light' then 0.100 when 'standard' then 0.160 else 0.220 end)*v_eff*v_weekly_dev_scale; v_incidental:=(case v_intensity when 'light' then 0.018 when 'standard' then 0.025 else 0.035 end)*v_eff*v_weekly_dev_scale; v_target_gain:=v_budget*v_focus_share; v_other_gain:=v_budget*(1-v_focus_share)/3;
      foreach k in array array['fitness','stamina','recovery','movement'] loop v_raw_gain:=case when k=v_focus_attribute then v_target_gain else v_other_gain end; v_attr_value:=(to_jsonb(s)->>k)::smallint; v_effective_gain:=public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain); v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4)); v_gains:=v_gains||jsonb_build_object(k,v_effective_gain); end loop;
      foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] loop v_raw_gain:=v_incidental/9; v_attr_value:=(to_jsonb(s)->>k)::smallint; v_effective_gain:=public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain); v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4)); v_gains:=v_gains||jsonb_build_object(k,v_effective_gain); end loop;
      v_base_fatigue:=case v_intensity when 'light' then 4 when 'standard' then 7 else 11 end;
    end if;
    v_resilience:=(s.fitness+s.stamina+s.recovery)::numeric/300; v_fatigue_cost:=greatest(1,round(v_base_fatigue*(1.15-0.30*v_resilience))); v_fatigue_after:=least(100,s.fatigue+v_fatigue_cost)::smallint; v_sharpness_after:=least(100,s.sharpness+case v_intensity when 'light' then 1 when 'standard' then 2 else 3 end)::smallint; v_morale_after:=greatest(1,least(100,s.morale+case when v_intensity='hard' and s.fatigue>=70 then -1 else 0 end))::smallint; v_focus_after:=greatest(1,least(100,s.focus+case when v_training_type='technical' and v_intensity<>'hard' then 1 else 0 end))::smallint; v_dev_result:=public.apply_player_development_progress_v1(p_player_id,'regular_training',v_raw_gains); v_levels:=coalesce(v_dev_result->'level_ups','{}'::jsonb);
  end if;
  update public.player_skills set fatigue=v_fatigue_after,sharpness=v_sharpness_after,morale=v_morale_after,focus=v_focus_after,updated_at=now() where player_id=p_player_id;
  insert into public.player_training_sessions(player_id,season,month,day,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,session_role)
  values(p_player_id,p_season,p_month,p_day,v_stored_training_type,v_stored_focus,v_intensity,v_eff,v_gains,v_levels,v_fatigue_before,v_fatigue_after,v_sharpness_before,v_sharpness_after,v_morale_before,v_morale_after,v_focus_before,v_focus_after,p_processed_by,v_session_role) returning id into v_session_id;
  return jsonb_build_object('status','completed','session_id',v_session_id,'training_type',v_stored_training_type,'focus_attribute',v_stored_focus,'intensity',v_intensity,'efficiency',v_eff,'session_role',v_session_role,'weekday_in_training_week',v_weekday,'plan_source',v_plan_source,'development_gains',v_gains,'raw_development_gains',v_raw_gains,'level_ups',v_levels,'condition',jsonb_build_object('fatigue_before',v_fatigue_before,'fatigue_after',v_fatigue_after,'sharpness_before',v_sharpness_before,'sharpness_after',v_sharpness_after,'morale_before',v_morale_before,'morale_after',v_morale_after,'focus_before',v_focus_before,'focus_after',v_focus_after));
end;
$$;

create or replace function public.process_regular_training_for_player_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine')
returns jsonb language plpgsql security definer set search_path='public' as $$
begin return public.process_regular_training_for_player_v2(p_player_id,p_season,p_month,p_day,p_processed_by); end;
$$;

grant execute on function public.get_training_week_planner_v1(smallint) to authenticated;
grant execute on function public.set_training_week_day_v1(integer,text,text,text) to authenticated;
grant execute on function public.set_training_week_plan_v1(integer,text,text,text) to authenticated;
