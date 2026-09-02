alter table public.player_daily_activity
  add column if not exists effects_applied_at timestamptz,
  add column if not exists effect_summary jsonb not null default '{}'::jsonb;

create or replace function public.process_player_daily_activity_v1(
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
  v_activity text;
  v_row public.player_daily_activity%rowtype;
  v_before smallint;
  v_after smallint;
  v_summary jsonb;
begin
  select * into v_row from public.player_daily_activity
  where player_id=p_player_id and season=p_season and month=p_month and day=p_day
  for update;

  v_activity := coalesce(v_row.activity_type,'home');

  if v_activity='home' then
    return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by);
  end if;

  if v_activity='travel' then
    if v_row.effects_applied_at is not null then
      return jsonb_build_object('status','already_processed','activity_type','travel','effect_summary',v_row.effect_summary);
    end if;

    select fatigue into v_before from public.player_skills where player_id=p_player_id for update;
    if v_before is null then raise exception 'Player skills are unavailable.'; end if;
    v_after:=least(100,v_before+6)::smallint;
    update public.player_skills set fatigue=v_after,updated_at=now() where player_id=p_player_id;
    v_summary:=jsonb_build_object('fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before,'skill_development',0);
    update public.player_daily_activity set effects_applied_at=now(),effect_summary=v_summary,updated_at=now()
      where player_id=p_player_id and season=p_season and month=p_month and day=p_day;
    return jsonb_build_object('status','completed','activity_type','travel','effect_summary',v_summary);
  end if;

  return jsonb_build_object('status','delegated','activity_type',v_activity,'reason',
    case v_activity
      when 'tournament' then 'Tournament/match engine owns this day; regular training is blocked.'
      when 'training_camp' then 'Training-camp engine owns this day; regular training is blocked.'
      when 'injured' then 'Injury/recovery engine owns this day; regular training is blocked.'
      else 'Regular training is blocked.' end);
end;
$$;

create or replace function public.process_current_game_day_for_all_players_internal_v1()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  d record;
  p record;
  v_count integer:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();
  for p in select id from public.players loop
    perform public.process_player_daily_activity_v1(p.id,d.season,d.month,d.day,'daily_engine');
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

create or replace function public.get_training_dashboard_v1()
returns jsonb
language plpgsql
security definer
stable
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
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid();
  if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into d from public.get_current_game_day_internal_v1();
  select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
  v_eligible := v_activity='home';
  v_reason := case v_activity when 'home' then null when 'travel' then 'Travel day — regular training is unavailable.' when 'tournament' then 'Tournament participation — regular training is unavailable.' when 'training_camp' then 'Training camp active — camp training replaces regular training.' when 'injured' then 'Player is injured — regular training is unavailable.' else 'Regular training is unavailable.' end;

  select to_jsonb(x) into v_plan from (select training_type,focus_attribute,intensity,focus_share,is_active,updated_at from public.player_training_plans where player_id=v_player_id) x;
  if v_plan is null or v_plan='null'::jsonb then
    v_plan:=jsonb_build_object('training_type','day_off','focus_attribute',null,'intensity','standard','focus_share',0.85,'is_active',true);
  end if;

  select to_jsonb(x) into v_skills from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus from public.player_skills where player_id=v_player_id) x;

  select to_jsonb(x) into v_progress from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement from public.player_training_progress where player_id=v_player_id) x;
  if v_progress is null or v_progress='null'::jsonb then
    v_progress:=jsonb_build_object('serve',0,'forehand',0,'backhand',0,'return_skill',0,'volley',0,'slice',0,'drop_shot',0,'lob',0,'smash',0,'fitness',0,'stamina',0,'recovery',0,'movement',0);
  end if;

  select to_jsonb(x) into v_today from (select id,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,created_at from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb) into v_recent from (select id,season,month,day,training_type,focus_attribute,intensity,efficiency,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,created_at from public.player_training_sessions where player_id=v_player_id order by created_at desc limit 10) x;

  return jsonb_build_object('game_day',jsonb_build_object('season',d.season,'month',d.month,'day',d.day),'activity_type',v_activity,'eligible',v_eligible,'block_reason',v_reason,'plan',v_plan,'skills',v_skills,'progress',v_progress,'today_session',coalesce(v_today,'null'::jsonb),'recent_sessions',v_recent,
    'rules',jsonb_build_object('focus_share',0.85,'other_share',0.15,'travel_fatigue_only',true,'travel_fatigue_cost',6,'regular_training_states',jsonb_build_array('home'),'blocked_states',jsonb_build_array('travel','tournament','training_camp','injured'),'automatic_scheduler_enabled',false));
end;
$$;

revoke all on function public.process_player_daily_activity_v1(uuid,integer,smallint,smallint,text) from public, anon, authenticated;
revoke all on function public.process_current_game_day_for_all_players_internal_v1() from public, anon, authenticated;
revoke all on function public.get_training_dashboard_v1() from public, anon;
grant execute on function public.get_training_dashboard_v1() to authenticated;
