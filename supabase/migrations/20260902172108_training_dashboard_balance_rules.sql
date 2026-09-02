create or replace function public.regular_training_week_role_v1(p_season integer,p_month smallint,p_day smallint)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_abs integer;
  d record;
  v_start integer;
  v_weekday integer;
begin
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);
  select * into d from public.absolute_game_day_v1(v_abs);
  if d.season_week not between 1 and 52 then return 'planned_training'; end if;
  v_start:=public.training_camp_week_start_absolute_v1(p_season,d.season_week);
  v_weekday:=v_abs-v_start+1;
  return case when v_weekday=6 then 'active_recovery' when v_weekday=7 then 'full_rest' else 'planned_training' end;
end;
$$;

create or replace function public.get_training_dashboard_v1()
returns jsonb
language plpgsql
stable security definer
set search_path = public
as $$
declare
  v_player_id uuid;
  d record;
  v_activity text;
  v_plan jsonb;
  v_skills jsonb;
  v_progress jsonb;
  v_today jsonb;
  v_recent jsonb;
  v_eligible boolean;
  v_reason text;
  v_abs integer;
  v_day_info record;
  v_week_start integer;
  v_weekday integer:=0;
  v_scheduled_role text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid();
  if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into d from public.get_current_game_day_internal_v1();
  select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
  v_eligible:=v_activity='home';
  v_reason:=case v_activity when 'home' then null when 'travel' then 'Travel day — regular training is unavailable.' when 'tournament' then 'Tournament participation — regular training is unavailable.' when 'training_camp' then 'Training camp active — camp training replaces regular training.' when 'injured' then 'Player is injured — regular training is unavailable.' else 'Regular training is unavailable.' end;

  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select * into v_day_info from public.absolute_game_day_v1(v_abs);
  if v_day_info.season_week between 1 and 52 then
    v_week_start:=public.training_camp_week_start_absolute_v1(d.season,v_day_info.season_week);
    v_weekday:=v_abs-v_week_start+1;
  end if;
  v_scheduled_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);

  select to_jsonb(x) into v_plan from (select training_type,focus_attribute,intensity,focus_share,is_active,updated_at from public.player_training_plans where player_id=v_player_id) x;
  if v_plan is null or v_plan='null'::jsonb then
    v_plan:=jsonb_build_object('training_type','day_off','focus_attribute',null,'intensity','standard','focus_share',0.85,'is_active',true);
  end if;

  select to_jsonb(x) into v_skills from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus from public.player_skills where player_id=v_player_id) x;
  select to_jsonb(x) into v_progress from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement from public.player_training_progress where player_id=v_player_id) x;
  if v_progress is null or v_progress='null'::jsonb then
    v_progress:=jsonb_build_object('serve',0,'forehand',0,'backhand',0,'return_skill',0,'volley',0,'slice',0,'drop_shot',0,'lob',0,'smash',0,'fitness',0,'stamina',0,'recovery',0,'movement',0);
  end if;

  select to_jsonb(x) into v_today from (
    select id,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,session_role,created_at
    from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day
  ) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_recent from (
    select id,season,month,day,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,session_role,created_at
    from public.player_training_sessions where player_id=v_player_id order by created_at desc limit 10
  ) x;

  return jsonb_build_object(
    'game_day',jsonb_build_object('season',d.season,'month',d.month,'day',d.day,'season_week',v_day_info.season_week,'weekday_in_training_week',v_weekday,'scheduled_role',v_scheduled_role),
    'activity_type',v_activity,'eligible',v_eligible,'block_reason',v_reason,'plan',v_plan,'skills',v_skills,'progress',v_progress,'today_session',coalesce(v_today,'null'::jsonb),'recent_sessions',v_recent,
    'rules',jsonb_build_object(
      'focus_share',0.85,'other_share',0.15,'travel_fatigue_only',true,'regular_training_states',jsonb_build_array('home'),'blocked_states',jsonb_build_array('travel','tournament','training_camp','injured'),'automatic_scheduler_enabled',false,
      'weekly_rhythm',jsonb_build_object('development_days',5,'active_recovery_days',1,'full_rest_days',1),
      'camp_weekly_rhythm',jsonb_build_object('development_days',6,'recovery_days',1),
      'attribute_development_multiplier',jsonb_build_object('1-59',1.00,'60-69',0.90,'70-79',0.75,'80-89',0.55,'90-94',0.35,'95-99',0.20),
      'age_modifier_used',false
    )
  );
end;
$$;
