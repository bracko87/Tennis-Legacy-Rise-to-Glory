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
  if not found then
    v_base_plan.training_type:='day_off';
    v_base_plan.focus_attribute:=null;
    v_base_plan.intensity:='standard';
    v_base_plan.focus_share:=0.85;
  end if;

  for i in 0..6 loop
    v_abs:=v_start+i;
    select * into d from public.absolute_game_day_v1(v_abs);
    select * into a from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day;
    v_activity:=coalesce(a.activity_type,'home');
    select * into sess from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day;
    select * into wp from public.player_weekly_training_plan_days where player_id=v_player_id and absolute_day=v_abs;

    if sess.id is not null then
      v_plan_type:=sess.training_type;
      v_plan_focus:=sess.focus_attribute;
      v_plan_intensity:=sess.intensity;
      v_plan_source:='processed_session';
      v_role:=coalesce(sess.session_role,'planned_training');
    elsif wp.player_id is not null then
      v_plan_type:=wp.training_type;
      v_plan_focus:=wp.focus_attribute;
      v_plan_intensity:=wp.intensity;
      v_plan_source:='weekly_plan';
      v_role:=case when wp.training_type='day_off' then 'user_day_off' else 'planned_training' end;
    else
      v_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);
      if v_role in ('active_recovery','full_rest') then
        v_plan_type:='day_off';
        v_plan_focus:=null;
        v_plan_intensity:='standard';
        v_plan_source:='automatic_recovery';
      else
        v_plan_type:=v_base_plan.training_type;
        v_plan_focus:=v_base_plan.focus_attribute;
        v_plan_intensity:=v_base_plan.intensity;
        v_plan_source:='default_plan';
      end if;
    end if;

    v_editable:=v_abs>=v_now_abs and v_activity='home' and sess.id is null;
    v_lock_reason:=case
      when v_abs<v_now_abs then 'Past day'
      when sess.id is not null then 'Already processed'
      when v_activity='travel' then coalesce(a.note,'Travel day')
      when v_activity='tournament' then coalesce(a.note,'Tournament day')
      when v_activity='training_camp' then coalesce(a.note,'Training Camp')
      when v_activity='injured' then coalesce(a.note,'Injury / recovery')
      else null
    end;

    v_days:=v_days||jsonb_build_array(jsonb_build_object(
      'absolute_day',v_abs,
      'weekday',i+1,
      'weekday_name',v_names[i+1],
      'season',d.season,
      'season_week',d.season_week,
      'month',d.month,
      'day',d.day,
      'activity_type',v_activity,
      'activity_source',a.source,
      'activity_note',a.note,
      'activity_reference_id',a.reference_id,
      'editable',v_editable,
      'lock_reason',v_lock_reason,
      'plan_source',v_plan_source,
      'training_type',v_plan_type,
      'focus_attribute',v_plan_focus,
      'intensity',v_plan_intensity,
      'session_role',v_role,
      'processed',sess.id is not null,
      'session_id',sess.id
    ));

    a:=null;
    wp:=null;
    sess:=null;
  end loop;

  return jsonb_build_object(
    'season',v_season,
    'season_week',v_week,
    'week_offset',p_week_offset,
    'week_start_absolute_day',v_start,
    'week_end_absolute_day',v_start+6,
    'current_absolute_day',v_now_abs,
    'days',v_days,
    'rules',jsonb_build_object(
      'editable_activity','home',
      'calendar_override_states',jsonb_build_array('travel','tournament','training_camp','injured'),
      'daily_plan_overrides_default_rhythm',true,
      'automatic_daily_processor_compatible',true
    )
  );
end;
$$;
