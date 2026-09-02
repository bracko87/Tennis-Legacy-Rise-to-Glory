create or replace function public.player_attribute_development_multiplier_v1(p_value smallint)
returns numeric
language sql
immutable
set search_path = public
as $$
  select case
    when p_value >= 100 then 0.00::numeric
    when p_value >= 95 then 0.20::numeric
    when p_value >= 90 then 0.35::numeric
    when p_value >= 80 then 0.55::numeric
    when p_value >= 70 then 0.75::numeric
    when p_value >= 60 then 0.90::numeric
    else 1.00::numeric
  end;
$$;

create or replace function public.player_attribute_effective_gain_v1(p_value smallint, p_gain numeric)
returns numeric
language sql
immutable
set search_path = public
as $$
  select round(greatest(0,coalesce(p_gain,0)) * public.player_attribute_development_multiplier_v1(p_value), 4);
$$;

create or replace function public.training_apply_progress_v1(p_value smallint, p_progress numeric, p_gain numeric)
returns table(value_out smallint, progress_out numeric, levels_gained integer)
language plpgsql
immutable
set search_path = public
as $$
declare
  v_total numeric;
  v_possible integer;
  v_effective_gain numeric;
begin
  v_effective_gain := public.player_attribute_effective_gain_v1(p_value,p_gain);
  v_total := greatest(0,coalesce(p_progress,0) + v_effective_gain);
  if p_value >= 100 then
    value_out := 100;
    progress_out := 0;
    levels_gained := 0;
    return next;
    return;
  end if;

  v_possible := least(floor(v_total)::integer, 100 - p_value);
  value_out := (p_value + v_possible)::smallint;
  levels_gained := v_possible;
  if value_out >= 100 then
    progress_out := 0;
  else
    progress_out := round(v_total - v_possible,4);
  end if;
  return next;
end;
$$;

alter table public.player_training_sessions
  add column if not exists session_role text not null default 'planned_training';

alter table public.player_training_sessions
  drop constraint if exists player_training_sessions_session_role_check;
alter table public.player_training_sessions
  add constraint player_training_sessions_session_role_check
  check (session_role in ('planned_training','active_recovery','full_rest','user_day_off'));

create or replace function public.process_regular_training_for_player_v1(
  p_player_id uuid,
  p_season integer,
  p_month smallint,
  p_day smallint,
  p_processed_by text default 'daily_engine'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s public.player_skills%rowtype;
  plan public.player_training_plans%rowtype;
  v_activity text;
  v_readiness numeric;
  v_eff numeric;
  v_budget numeric;
  v_incidental numeric;
  v_target_gain numeric;
  v_other_gain numeric;
  v_raw_gains jsonb := '{}'::jsonb;
  v_gains jsonb := '{}'::jsonb;
  v_levels jsonb := '{}'::jsonb;
  v_base_fatigue integer;
  v_resilience numeric;
  v_fatigue_cost integer;
  v_fatigue_before smallint;
  v_sharpness_before smallint;
  v_morale_before smallint;
  v_focus_before smallint;
  v_fatigue_after smallint;
  v_sharpness_after smallint;
  v_morale_after smallint;
  v_focus_after smallint;
  v_rest_reduction integer;
  v_session_id uuid;
  k text;
  v_dev_result jsonb;
  v_abs integer;
  v_day_info record;
  v_week_start integer;
  v_weekday smallint := 0;
  v_session_role text := 'planned_training';
  v_stored_training_type text;
  v_stored_focus text;
  v_weekly_dev_scale numeric := 1.0;
  v_raw_gain numeric;
  v_effective_gain numeric;
  v_attr_value smallint;
begin
  if p_processed_by not in ('manual','daily_engine') then raise exception 'Invalid processor.'; end if;

  if exists(select 1 from public.player_training_sessions where player_id=p_player_id and season=p_season and month=p_month and day=p_day) then
    return (select jsonb_build_object('status','already_processed','session_id',id) from public.player_training_sessions where player_id=p_player_id and season=p_season and month=p_month and day=p_day);
  end if;

  select coalesce((select activity_type from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day),'home') into v_activity;
  if v_activity <> 'home' then
    return jsonb_build_object('status','blocked','activity_type',v_activity,'reason',
      case v_activity
        when 'travel' then 'Regular training is unavailable on travel days.'
        when 'tournament' then 'Regular training is unavailable during tournament participation.'
        when 'training_camp' then 'Regular training is replaced by training-camp work.'
        when 'injured' then 'Regular training is unavailable while the player is injured.'
        else 'Regular training is unavailable today.' end);
  end if;

  select * into s from public.player_skills where player_id=p_player_id for update;
  if not found then raise exception 'Player skills are unavailable.'; end if;

  select * into plan from public.player_training_plans where player_id=p_player_id;
  if not found then
    insert into public.player_training_plans(player_id,training_type,focus_attribute,intensity)
    values(p_player_id,'day_off',null,'standard') returning * into plan;
  end if;

  v_abs := public.game_day_absolute_v1(p_season,p_month,p_day);
  select * into v_day_info from public.absolute_game_day_v1(v_abs);
  if v_day_info.season_week between 1 and 52 then
    v_week_start := public.training_camp_week_start_absolute_v1(p_season,v_day_info.season_week);
    v_weekday := (v_abs-v_week_start+1)::smallint;
  end if;

  if plan.training_type='day_off' then
    v_session_role := 'user_day_off';
  elsif v_weekday=6 then
    v_session_role := 'active_recovery';
  elsif v_weekday=7 then
    v_session_role := 'full_rest';
  else
    v_session_role := 'planned_training';
  end if;

  if v_day_info.season_week between 1 and 52 and v_session_role='planned_training' then
    v_weekly_dev_scale := 1.40;
  end if;

  v_fatigue_before:=s.fatigue;
  v_sharpness_before:=s.sharpness;
  v_morale_before:=s.morale;
  v_focus_before:=s.focus;
  v_readiness := (s.morale+s.confidence+s.sharpness+s.focus+(100-s.fatigue))::numeric/500;
  v_eff := round(greatest(0.70,least(1.05,0.78+0.37*v_readiness)),4);

  v_stored_training_type := plan.training_type;
  v_stored_focus := plan.focus_attribute;

  if v_session_role='user_day_off' then
    v_rest_reduction := round(8+s.recovery*0.08+s.fitness*0.04);
    v_fatigue_after := greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after := greatest(1,s.sharpness-2)::smallint;
    v_morale_after := least(100,s.morale+1)::smallint;
    v_focus_after := least(100,s.focus+1)::smallint;
    v_stored_training_type := 'day_off';
    v_stored_focus := null;
  elsif v_session_role='active_recovery' then
    v_rest_reduction := round(6+s.recovery*0.05+s.fitness*0.02);
    v_fatigue_after := greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after := s.sharpness;
    v_morale_after := least(100,s.morale+1)::smallint;
    v_focus_after := least(100,s.focus+1)::smallint;
    v_stored_training_type := 'day_off';
    v_stored_focus := null;
  elsif v_session_role='full_rest' then
    v_rest_reduction := round(9+s.recovery*0.06+s.fitness*0.03);
    v_fatigue_after := greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after := greatest(1,s.sharpness-1)::smallint;
    v_morale_after := least(100,s.morale+1)::smallint;
    v_focus_after := least(100,s.focus+1)::smallint;
    v_stored_training_type := 'day_off';
    v_stored_focus := null;
  else
    if plan.intensity='hard' and s.fatigue>=80 then return jsonb_build_object('status','blocked','activity_type','home','reason','Fatigue is too high for hard training. Choose Standard, Light or a Day Off.'); end if;
    if plan.intensity='standard' and s.fatigue>=92 then return jsonb_build_object('status','blocked','activity_type','home','reason','Fatigue is too high for standard training. Choose Light training or a Day Off.'); end if;

    if plan.training_type='technical' then
      v_budget := (case plan.intensity when 'light' then 0.100 when 'standard' then 0.160 else 0.220 end) * v_eff * v_weekly_dev_scale;
      v_incidental := (case plan.intensity when 'light' then 0.020 when 'standard' then 0.035 else 0.050 end) * v_eff * v_weekly_dev_scale;
      v_target_gain := v_budget*plan.focus_share;
      v_other_gain := v_budget*(1-plan.focus_share)/8;
      foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] loop
        v_raw_gain := case when k=plan.focus_attribute then v_target_gain else v_other_gain end;
        v_attr_value := (to_jsonb(s)->>k)::smallint;
        v_effective_gain := public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain);
        v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4));
        v_gains:=v_gains||jsonb_build_object(k,v_effective_gain);
      end loop;
      foreach k in array array['fitness','stamina','recovery','movement'] loop
        v_raw_gain := v_incidental * case k when 'fitness' then 0.20 when 'stamina' then 0.30 when 'recovery' then 0.15 else 0.35 end;
        v_attr_value := (to_jsonb(s)->>k)::smallint;
        v_effective_gain := public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain);
        v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4));
        v_gains:=v_gains||jsonb_build_object(k,v_effective_gain);
      end loop;
      v_base_fatigue:=case plan.intensity when 'light' then 3 when 'standard' then 6 else 10 end;
    else
      v_budget := (case plan.intensity when 'light' then 0.100 when 'standard' then 0.160 else 0.220 end) * v_eff * v_weekly_dev_scale;
      v_incidental := (case plan.intensity when 'light' then 0.018 when 'standard' then 0.025 else 0.035 end) * v_eff * v_weekly_dev_scale;
      v_target_gain := v_budget*plan.focus_share;
      v_other_gain := v_budget*(1-plan.focus_share)/3;
      foreach k in array array['fitness','stamina','recovery','movement'] loop
        v_raw_gain := case when k=plan.focus_attribute then v_target_gain else v_other_gain end;
        v_attr_value := (to_jsonb(s)->>k)::smallint;
        v_effective_gain := public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain);
        v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4));
        v_gains:=v_gains||jsonb_build_object(k,v_effective_gain);
      end loop;
      foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'] loop
        v_raw_gain := v_incidental/9;
        v_attr_value := (to_jsonb(s)->>k)::smallint;
        v_effective_gain := public.player_attribute_effective_gain_v1(v_attr_value,v_raw_gain);
        v_raw_gains:=v_raw_gains||jsonb_build_object(k,round(v_raw_gain,4));
        v_gains:=v_gains||jsonb_build_object(k,v_effective_gain);
      end loop;
      v_base_fatigue:=case plan.intensity when 'light' then 4 when 'standard' then 7 else 11 end;
    end if;

    v_resilience := (s.fitness+s.stamina+s.recovery)::numeric/300;
    v_fatigue_cost := greatest(1,round(v_base_fatigue*(1.15-0.30*v_resilience)));
    v_fatigue_after := least(100,s.fatigue+v_fatigue_cost)::smallint;
    v_sharpness_after := least(100,s.sharpness+case plan.intensity when 'light' then 1 when 'standard' then 2 else 3 end)::smallint;
    v_morale_after := greatest(1,least(100,s.morale+case when plan.intensity='hard' and s.fatigue>=70 then -1 else 0 end))::smallint;
    v_focus_after := greatest(1,least(100,s.focus+case when plan.training_type='technical' and plan.intensity<>'hard' then 1 else 0 end))::smallint;

    v_dev_result:=public.apply_player_development_progress_v1(p_player_id,'regular_training',v_raw_gains);
    v_levels:=coalesce(v_dev_result->'level_ups','{}'::jsonb);
  end if;

  update public.player_skills set fatigue=v_fatigue_after,sharpness=v_sharpness_after,morale=v_morale_after,focus=v_focus_after,updated_at=now() where player_id=p_player_id;

  insert into public.player_training_sessions(
    player_id,season,month,day,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,
    fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,session_role
  ) values(
    p_player_id,p_season,p_month,p_day,v_stored_training_type,v_stored_focus,plan.intensity,v_eff,v_gains,v_levels,
    v_fatigue_before,v_fatigue_after,v_sharpness_before,v_sharpness_after,v_morale_before,v_morale_after,v_focus_before,v_focus_after,p_processed_by,v_session_role
  ) returning id into v_session_id;

  return jsonb_build_object(
    'status','completed','session_id',v_session_id,'training_type',v_stored_training_type,'focus_attribute',v_stored_focus,
    'intensity',plan.intensity,'efficiency',v_eff,'session_role',v_session_role,'weekday_in_training_week',v_weekday,
    'development_gains',v_gains,'raw_development_gains',v_raw_gains,'level_ups',v_levels,
    'condition',jsonb_build_object('fatigue_before',v_fatigue_before,'fatigue_after',v_fatigue_after,'sharpness_before',v_sharpness_before,'sharpness_after',v_sharpness_after,'morale_before',v_morale_before,'morale_after',v_morale_after,'focus_before',v_focus_before,'focus_after',v_focus_after)
  );
end;
$$;

comment on function public.player_attribute_development_multiplier_v1(smallint) is 'Permanent Tennis Legacy career progression multiplier. No age or retirement modifier is used; only current attribute level slows development.';
comment on column public.player_training_sessions.session_role is 'Professional weekly rhythm: planned_training on weekdays, active_recovery on day 6, full_rest on day 7, or user_day_off.';
