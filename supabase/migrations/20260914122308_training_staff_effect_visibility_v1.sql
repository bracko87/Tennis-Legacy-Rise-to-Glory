alter table public.player_training_sessions
  add column if not exists staff_effects_snapshot jsonb not null default '{}'::jsonb;

alter table public.player_training_camp_days
  add column if not exists staff_effects_snapshot jsonb not null default '{}'::jsonb;

comment on column public.player_training_sessions.staff_effects_snapshot is 'Snapshot of active staff modifiers used when this regular-training session was processed.';
comment on column public.player_training_camp_days.staff_effects_snapshot is 'Snapshot of active staff modifiers used when this training-camp day was processed.';

create or replace function public.apply_regular_training_staff_session_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_effects jsonb; v_tech numeric; v_phys numeric; v_red numeric; v_rec numeric; v_fit_rec numeric; v_combined_rec numeric;
  v_morale_pts integer; v_conf_pts integer; v_focus_pts integer; k text; val numeric; scaled jsonb:='{}'::jsonb; delta integer; extra integer; v_conf integer;
begin
  v_effects:=public.get_player_staff_effects_v1(new.player_id);
  new.staff_effects_snapshot:=coalesce(v_effects,'{}'::jsonb);
  v_tech:=coalesce((v_effects->>'technical_training_multiplier')::numeric,1);
  v_phys:=coalesce((v_effects->>'physical_training_multiplier')::numeric,1);
  if new.session_role='planned_training' then
    for k,val in select key,value::numeric from jsonb_each_text(coalesce(new.development_gains,'{}'::jsonb)) loop
      if k in ('serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash') then scaled:=scaled||jsonb_build_object(k,round(val*v_tech,4));
      elsif k in ('fitness','stamina','recovery','movement') then scaled:=scaled||jsonb_build_object(k,round(val*v_phys,4));
      else scaled:=scaled||jsonb_build_object(k,val); end if;
    end loop;
    new.development_gains:=scaled;
    v_red:=coalesce((v_effects->>'training_fatigue_reduction')::numeric,0);
    delta:=greatest(0,new.fatigue_after-new.fatigue_before); extra:=round(delta*v_red);
    if extra>0 then
      new.fatigue_after:=greatest(new.fatigue_before,new.fatigue_after-extra);
      update public.player_skills set fatigue=new.fatigue_after where player_id=new.player_id;
    end if;
  else
    v_rec:=coalesce((v_effects->>'recovery_multiplier')::numeric,1);
    v_fit_rec:=case when new.session_role='active_recovery' then coalesce((v_effects->>'active_recovery_multiplier')::numeric,1) else 1 end;
    v_combined_rec:=least(1.20,1+greatest(0,v_rec-1)+greatest(0,v_fit_rec-1));
    delta:=greatest(0,new.fatigue_before-new.fatigue_after); extra:=round(delta*(v_combined_rec-1));
    if extra>0 then
      new.fatigue_after:=greatest(0,new.fatigue_after-extra);
      update public.player_skills set fatigue=new.fatigue_after where player_id=new.player_id;
    end if;

    v_morale_pts:=coalesce((v_effects->>'morale_recovery_bonus_points')::integer,0);
    v_conf_pts:=coalesce((v_effects->>'confidence_recovery_bonus_points')::integer,0);
    v_focus_pts:=coalesce((v_effects->>'focus_recovery_bonus_points')::integer,0);
    if v_morale_pts>0 then
      new.morale_after:=least(100,new.morale_after+v_morale_pts);
      update public.player_skills set morale=new.morale_after where player_id=new.player_id;
    end if;
    if v_focus_pts>0 then
      new.focus_after:=least(100,new.focus_after+v_focus_pts);
      update public.player_skills set focus=new.focus_after where player_id=new.player_id;
    end if;
    if v_conf_pts>0 then
      select confidence into v_conf from public.player_skills where player_id=new.player_id;
      update public.player_skills set confidence=least(100,coalesce(v_conf,50)+v_conf_pts) where player_id=new.player_id;
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.apply_training_camp_staff_effects_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_effects jsonb; v_category text; v_mult numeric:=1; v_red numeric:=0; v_rec numeric:=1; v_fit_rec numeric:=1; v_combined_rec numeric:=1;
  v_bonus jsonb:='{}'::jsonb; v_result jsonb; k text; val numeric; extra numeric; merged jsonb:=coalesce(new.development_gains,'{}'::jsonb);
  delta integer; add_recovery integer; cond jsonb:=coalesce(new.condition_changes,'{}'::jsonb); fb integer; fa integer; ma integer; fo integer; cf integer;
  v_morale_pts integer; v_conf_pts integer; v_focus_pts integer; v_head boolean; v_fit boolean; v_physio boolean; v_psych boolean;
begin
  select p.category into v_category from public.player_training_camp_bookings b join public.training_camp_programs p on p.id=b.program_id where b.id=new.booking_id;
  select
    exists(select 1 from public.player_training_camp_staff where booking_id=new.booking_id and role='head_coach'),
    exists(select 1 from public.player_training_camp_staff where booking_id=new.booking_id and role='fitness_coach'),
    exists(select 1 from public.player_training_camp_staff where booking_id=new.booking_id and role='physiotherapist'),
    exists(select 1 from public.player_training_camp_staff where booking_id=new.booking_id and role='sports_psychologist')
  into v_head,v_fit,v_physio,v_psych;
  v_effects:=public.get_player_staff_effects_v1(new.player_id);
  new.staff_effects_snapshot:=coalesce(v_effects,'{}'::jsonb);

  if new.day_role='development' then
    if v_category='tennis_skills' and v_head then v_mult:=coalesce((v_effects->>'technical_camp_multiplier')::numeric,1);
    elsif v_category='physical' and v_fit then v_mult:=coalesce((v_effects->>'physical_camp_multiplier')::numeric,1); end if;
    if v_mult>1 then
      for k,val in select key,value::numeric from jsonb_each_text(coalesce(new.development_gains,'{}'::jsonb)) loop
        extra:=round(val*(v_mult-1),4);
        if extra>0 then v_bonus:=v_bonus||jsonb_build_object(k,extra); merged:=merged||jsonb_build_object(k,round(val+extra,4)); end if;
      end loop;
      v_result:=public.apply_player_effective_bonus_progress_v1(new.player_id,v_bonus);
      new.level_ups:=coalesce(new.level_ups,'{}'::jsonb)||coalesce(v_result->'level_ups','{}'::jsonb);
      new.development_gains:=merged;
    end if;
    if v_fit then v_red:=coalesce((v_effects->>'training_fatigue_reduction')::numeric,0); end if;
    fb:=coalesce((cond->>'fatigue_before')::integer,0); fa:=coalesce((cond->>'fatigue_after')::integer,fb); delta:=greatest(0,fa-fb);
    if delta>0 and v_red>0 then
      fa:=greatest(fb,fa-round(delta*v_red)); cond:=jsonb_set(cond,'{fatigue_after}',to_jsonb(fa));
      update public.player_skills set fatigue=fa where player_id=new.player_id;
    end if;
  else
    fb:=coalesce((cond->>'fatigue_before')::integer,0); fa:=coalesce((cond->>'fatigue_after')::integer,fb); delta:=greatest(0,fb-fa);
    if v_physio then v_rec:=coalesce((v_effects->>'recovery_multiplier')::numeric,1); end if;
    if v_fit then v_fit_rec:=coalesce((v_effects->>'active_recovery_multiplier')::numeric,1); end if;
    v_combined_rec:=least(1.20,1+greatest(0,v_rec-1)+greatest(0,v_fit_rec-1));
    add_recovery:=round(delta*(v_combined_rec-1));
    if add_recovery>0 then
      fa:=greatest(0,fa-add_recovery); cond:=jsonb_set(cond,'{fatigue_after}',to_jsonb(fa));
      update public.player_skills set fatigue=fa where player_id=new.player_id;
    end if;
    if v_psych then
      v_morale_pts:=coalesce((v_effects->>'morale_recovery_bonus_points')::integer,0);
      v_conf_pts:=coalesce((v_effects->>'confidence_recovery_bonus_points')::integer,0);
      v_focus_pts:=coalesce((v_effects->>'focus_recovery_bonus_points')::integer,0);
      ma:=coalesce((cond->>'morale_after')::integer,50);
      fo:=coalesce((cond->>'focus_after')::integer,50);
      if v_morale_pts>0 then ma:=least(100,ma+v_morale_pts); cond:=jsonb_set(cond,'{morale_after}',to_jsonb(ma)); update public.player_skills set morale=ma where player_id=new.player_id; end if;
      if v_focus_pts>0 then fo:=least(100,fo+v_focus_pts); cond:=jsonb_set(cond,'{focus_after}',to_jsonb(fo)); update public.player_skills set focus=fo where player_id=new.player_id; end if;
      if v_conf_pts>0 then select confidence into cf from public.player_skills where player_id=new.player_id; update public.player_skills set confidence=least(100,coalesce(cf,50)+v_conf_pts) where player_id=new.player_id; end if;
    end if;
  end if;
  new.condition_changes:=cond;
  return new;
end;
$function$;

create or replace function public.get_training_dashboard_v1()
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid;d record;v_activity text;v_plan jsonb;v_skills jsonb;v_progress jsonb;v_today jsonb;v_recent jsonb;v_eligible boolean;v_reason text;
  v_abs integer;v_day_info record;v_week_start integer;v_weekday integer:=0;v_scheduled_role text;v_health jsonb;v_staff jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid();if v_player_id is null then raise exception 'Player not found.';end if;
  select * into d from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select coalesce((select activity_type from public.player_daily_activity where player_id=v_player_id and season=d.season and month=d.month and day=d.day),'home') into v_activity;
  if v_activity='home' and public.player_has_confirmed_tournament_match_on_day_v1(v_player_id,v_abs) then v_activity:='tournament';end if;
  v_health:=public.get_player_health_summary_v1(v_player_id,v_abs);
  v_staff:=public.get_player_staff_effects_v2(v_player_id);
  v_eligible:=v_activity='home' and coalesce((v_health->>'can_train')::boolean,true);
  v_reason:=case
    when v_activity='home' and not coalesce((v_health->>'can_train')::boolean,true) then format('Health restriction — %s. Normal training is unavailable until medically cleared.',coalesce(v_health->>'label','unavailable'))
    when v_activity='home' then null
    when v_activity='travel' then 'Travel day — regular training is unavailable.'
    when v_activity='tournament' then 'Confirmed tournament match — regular training is unavailable.'
    when v_activity='training_camp' then 'Training camp active — camp training replaces regular training.'
    when v_activity='injured' then 'Health recovery day — regular training is unavailable.'
    else 'Regular training is unavailable.' end;
  select * into v_day_info from public.absolute_game_day_v1(v_abs);
  if v_day_info.season_week between 1 and 52 then v_week_start:=public.training_camp_week_start_absolute_v1(d.season,v_day_info.season_week);v_weekday:=v_abs-v_week_start+1;end if;
  v_scheduled_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);
  select to_jsonb(x) into v_plan from (select training_type,focus_attribute,intensity,focus_share,is_active,updated_at from public.player_training_plans where player_id=v_player_id) x;
  if v_plan is null or v_plan='null'::jsonb then v_plan:=jsonb_build_object('training_type','day_off','focus_attribute',null,'intensity','standard','focus_share',0.85,'is_active',true);end if;
  select to_jsonb(x) into v_skills from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement,fatigue,sharpness,morale,confidence,focus from public.player_skills where player_id=v_player_id) x;
  select to_jsonb(x) into v_progress from (select serve,forehand,backhand,return_skill,volley,slice,drop_shot,lob,smash,fitness,stamina,recovery,movement from public.player_training_progress where player_id=v_player_id) x;
  if v_progress is null or v_progress='null'::jsonb then v_progress:=jsonb_build_object('serve',0,'forehand',0,'backhand',0,'return_skill',0,'volley',0,'slice',0,'drop_shot',0,'lob',0,'smash',0,'fitness',0,'stamina',0,'recovery',0,'movement',0);end if;
  select to_jsonb(x) into v_today from (select id,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,processed_by,session_role,staff_effects_snapshot,created_at from public.player_training_sessions where player_id=v_player_id and season=d.season and month=d.month and day=d.day) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.absolute_day desc,x.created_at desc),'[]'::jsonb) into v_recent from (
    select id,season,month,day,training_type,focus_attribute,intensity,efficiency,development_gains,level_ups,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,focus_before,focus_after,session_role,staff_effects_snapshot,created_at,public.game_day_absolute_v1(season,month,day) as absolute_day
    from public.player_training_sessions where player_id=v_player_id and public.game_day_absolute_v1(season,month,day)<=v_abs order by public.game_day_absolute_v1(season,month,day) desc,created_at desc limit 3
  ) x;
  return jsonb_build_object('game_day',jsonb_build_object('season',d.season,'month',d.month,'day',d.day,'season_week',v_day_info.season_week,'weekday_in_training_week',v_weekday,'scheduled_role',v_scheduled_role),
    'activity_type',v_activity,'eligible',v_eligible,'block_reason',v_reason,'health_summary',v_health,'plan',v_plan,'skills',v_skills,'progress',v_progress,'staff_effects',v_staff,'today_session',coalesce(v_today,'null'::jsonb),'recent_sessions',v_recent,
    'rules',jsonb_build_object('focus_share',0.85,'other_share',0.15,'travel_fatigue_only',false,'travel_day_recovery_offset',3,'regular_training_states',jsonb_build_array('home'),'blocked_states',jsonb_build_array('travel','tournament','training_camp','injured'),'automatic_scheduler_enabled',true,'staff_effects_visible',true,'weekly_rhythm',jsonb_build_object('automatic_recovery_days',0,'day_off_user_controlled',true,'active_recovery_days',0,'full_rest_days',0),'camp_weekly_rhythm',jsonb_build_object('development_days',6,'recovery_days',1),'attribute_development_multiplier',jsonb_build_object('1-59',1.00,'60-69',0.90,'70-79',0.75,'80-89',0.55,'90-94',0.35,'95-99',0.20),'age_modifier_used',false));
end;
$function$;
