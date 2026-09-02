alter table public.player_training_camp_days
  add column if not exists day_role text not null default 'development';

alter table public.player_training_camp_days
  drop constraint if exists player_training_camp_days_day_role_check;
alter table public.player_training_camp_days
  add constraint player_training_camp_days_day_role_check
  check (day_role in ('development','recovery'));

create or replace function public.process_training_camp_day_v1(
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
  v_abs integer := public.game_day_absolute_v1(p_season,p_month,p_day);
  v_booking public.player_training_camp_bookings%rowtype;
  v_program public.training_camp_programs%rowtype;
  v_location public.training_camp_locations%rowtype;
  v_tier public.training_camp_accommodation_tiers%rowtype;
  s public.player_skills%rowtype;
  pr public.player_training_progress%rowtype;
  v_week smallint;
  v_day_no smallint;
  v_duration_factor numeric;
  v_readiness numeric;
  v_eff numeric;
  v_base_budget numeric;
  v_gains jsonb := '{}'::jsonb;
  v_raw_gains jsonb := '{}'::jsonb;
  v_levelups jsonb := '{}'::jsonb;
  v_condition jsonb := '{}'::jsonb;
  v_fatigue_before smallint;
  v_sharpness_before smallint;
  v_morale_before smallint;
  v_confidence_before smallint;
  v_focus_before smallint;
  v_new_fatigue smallint;
  v_new_sharpness smallint;
  v_new_morale smallint;
  v_new_confidence smallint;
  v_new_focus smallint;
  r record;
  g numeric;
  v_effective_g numeric;
  v_day_role text := 'development';
  v_rest_reduction integer;
begin
  select b.* into v_booking
  from public.player_training_camp_bookings b
  where b.player_id=p_player_id
    and b.status in ('booked','active')
    and v_abs between b.start_absolute_day and b.end_absolute_day
  order by b.start_absolute_day
  limit 1
  for update;

  if v_booking.id is null then return jsonb_build_object('status','blocked','reason','No active training camp owns this day.'); end if;
  if exists(select 1 from public.player_training_camp_days where booking_id=v_booking.id and absolute_day=v_abs) then
    return jsonb_build_object('status','already_processed','booking_id',v_booking.id);
  end if;

  select * into v_program from public.training_camp_programs where id=v_booking.program_id;
  select * into v_location from public.training_camp_locations where id=v_program.location_id;
  select * into v_tier from public.training_camp_accommodation_tiers where id=v_booking.accommodation_tier_id;
  select * into s from public.player_skills where player_id=p_player_id for update;
  if s.player_id is null then raise exception 'Player skills are unavailable.'; end if;

  insert into public.player_training_progress(player_id) values(p_player_id) on conflict(player_id) do nothing;
  select * into pr from public.player_training_progress where player_id=p_player_id for update;

  v_day_no := (v_abs-v_booking.start_absolute_day+1)::smallint;
  v_week := (floor((v_day_no-1)::numeric/7)::integer+1)::smallint;
  v_duration_factor := case v_week when 1 then 1.00 when 2 then 0.95 when 3 then 0.85 else 0.75 end;
  v_readiness := (s.morale+s.confidence+s.sharpness+s.focus+(100-s.fatigue))::numeric/500;
  v_eff := least(1.35,greatest(0.70,(0.82+0.23*v_readiness)*v_program.quality_multiplier*v_duration_factor));

  v_fatigue_before:=s.fatigue;
  v_sharpness_before:=s.sharpness;
  v_morale_before:=s.morale;
  v_confidence_before:=s.confidence;
  v_focus_before:=s.focus;

  if mod(v_day_no,7)=0 and v_program.category in ('tennis_skills','physical') then
    v_day_role := 'recovery';
    v_eff := 0;
    v_rest_reduction := round((9+s.recovery*0.06+s.fitness*0.03)*coalesce(v_tier.rest_quality,1.0));
    v_new_fatigue := greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_new_sharpness := greatest(1,s.sharpness-1)::smallint;
    v_new_morale := least(100,s.morale+1)::smallint;
    v_new_confidence := s.confidence;
    v_new_focus := least(100,s.focus+1)::smallint;
  elsif v_program.category='tennis_skills' then
    v_base_budget := 0.34 * (7.0/6.0) * v_eff;

    g:=v_base_budget*coalesce((v_program.development_profile->>'serve')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.serve,g); select * into r from public.training_apply_progress_v1(s.serve,pr.serve,g); s.serve:=r.value_out; pr.serve:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('serve',round(g,4)); v_gains:=v_gains||jsonb_build_object('serve',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('serve',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'forehand')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.forehand,g); select * into r from public.training_apply_progress_v1(s.forehand,pr.forehand,g); s.forehand:=r.value_out; pr.forehand:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('forehand',round(g,4)); v_gains:=v_gains||jsonb_build_object('forehand',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('forehand',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'backhand')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.backhand,g); select * into r from public.training_apply_progress_v1(s.backhand,pr.backhand,g); s.backhand:=r.value_out; pr.backhand:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('backhand',round(g,4)); v_gains:=v_gains||jsonb_build_object('backhand',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('backhand',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'return_skill')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.return_skill,g); select * into r from public.training_apply_progress_v1(s.return_skill,pr.return_skill,g); s.return_skill:=r.value_out; pr.return_skill:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('return_skill',round(g,4)); v_gains:=v_gains||jsonb_build_object('return_skill',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('return_skill',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'volley')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.volley,g); select * into r from public.training_apply_progress_v1(s.volley,pr.volley,g); s.volley:=r.value_out; pr.volley:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('volley',round(g,4)); v_gains:=v_gains||jsonb_build_object('volley',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('volley',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'slice')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.slice,g); select * into r from public.training_apply_progress_v1(s.slice,pr.slice,g); s.slice:=r.value_out; pr.slice:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('slice',round(g,4)); v_gains:=v_gains||jsonb_build_object('slice',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('slice',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'drop_shot')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.drop_shot,g); select * into r from public.training_apply_progress_v1(s.drop_shot,pr.drop_shot,g); s.drop_shot:=r.value_out; pr.drop_shot:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('drop_shot',round(g,4)); v_gains:=v_gains||jsonb_build_object('drop_shot',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('drop_shot',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'lob')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.lob,g); select * into r from public.training_apply_progress_v1(s.lob,pr.lob,g); s.lob:=r.value_out; pr.lob:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('lob',round(g,4)); v_gains:=v_gains||jsonb_build_object('lob',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('lob',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'smash')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.smash,g); select * into r from public.training_apply_progress_v1(s.smash,pr.smash,g); s.smash:=r.value_out; pr.smash:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('smash',round(g,4)); v_gains:=v_gains||jsonb_build_object('smash',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('smash',r.levels_gained); end if; end if;

    v_new_fatigue:=least(100,s.fatigue+greatest(2,round(4*v_program.quality_multiplier)::integer))::smallint;
    v_new_sharpness:=least(100,s.sharpness+1)::smallint;
    v_new_morale:=s.morale;
    v_new_confidence:=s.confidence;
    v_new_focus:=least(100,s.focus+1)::smallint;
  elsif v_program.category='physical' then
    v_base_budget := 0.30 * (7.0/6.0) * v_eff;

    g:=v_base_budget*coalesce((v_program.development_profile->>'fitness')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.fitness,g); select * into r from public.training_apply_progress_v1(s.fitness,pr.fitness,g); s.fitness:=r.value_out; pr.fitness:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('fitness',round(g,4)); v_gains:=v_gains||jsonb_build_object('fitness',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('fitness',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'stamina')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.stamina,g); select * into r from public.training_apply_progress_v1(s.stamina,pr.stamina,g); s.stamina:=r.value_out; pr.stamina:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('stamina',round(g,4)); v_gains:=v_gains||jsonb_build_object('stamina',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('stamina',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'recovery')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.recovery,g); select * into r from public.training_apply_progress_v1(s.recovery,pr.recovery,g); s.recovery:=r.value_out; pr.recovery:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('recovery',round(g,4)); v_gains:=v_gains||jsonb_build_object('recovery',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('recovery',r.levels_gained); end if; end if;
    g:=v_base_budget*coalesce((v_program.development_profile->>'movement')::numeric,0);
    if g>0 then v_effective_g:=public.player_attribute_effective_gain_v1(s.movement,g); select * into r from public.training_apply_progress_v1(s.movement,pr.movement,g); s.movement:=r.value_out; pr.movement:=r.progress_out; v_raw_gains:=v_raw_gains||jsonb_build_object('movement',round(g,4)); v_gains:=v_gains||jsonb_build_object('movement',v_effective_g); if r.levels_gained>0 then v_levelups:=v_levelups||jsonb_build_object('movement',r.levels_gained); end if; end if;

    v_new_fatigue:=least(100,s.fatigue+greatest(3,round(6*v_program.quality_multiplier)::integer))::smallint;
    v_new_sharpness:=least(100,s.sharpness+1)::smallint;
    v_new_morale:=s.morale;
    v_new_confidence:=s.confidence;
    v_new_focus:=s.focus;
  else
    v_day_role := 'recovery';
    v_new_fatigue:=greatest(0,s.fatigue+coalesce((v_program.condition_profile->>'fatigue')::integer,-10))::smallint;
    v_new_sharpness:=least(100,greatest(0,s.sharpness+coalesce((v_program.condition_profile->>'sharpness')::integer,1)))::smallint;
    v_new_morale:=least(100,greatest(0,s.morale+coalesce((v_program.condition_profile->>'morale')::integer,2)))::smallint;
    v_new_confidence:=least(100,greatest(0,s.confidence+coalesce((v_program.condition_profile->>'confidence')::integer,1)))::smallint;
    v_new_focus:=least(100,greatest(0,s.focus+coalesce((v_program.condition_profile->>'focus')::integer,2)))::smallint;
    v_eff:=v_program.quality_multiplier*v_duration_factor;
  end if;

  update public.player_skills set
    serve=s.serve,forehand=s.forehand,backhand=s.backhand,return_skill=s.return_skill,volley=s.volley,slice=s.slice,drop_shot=s.drop_shot,lob=s.lob,smash=s.smash,
    fitness=s.fitness,stamina=s.stamina,recovery=s.recovery,movement=s.movement,
    fatigue=v_new_fatigue,sharpness=v_new_sharpness,morale=v_new_morale,confidence=v_new_confidence,focus=v_new_focus,updated_at=now()
  where player_id=p_player_id;

  update public.player_training_progress set
    serve=pr.serve,forehand=pr.forehand,backhand=pr.backhand,return_skill=pr.return_skill,volley=pr.volley,slice=pr.slice,drop_shot=pr.drop_shot,lob=pr.lob,smash=pr.smash,
    fitness=pr.fitness,stamina=pr.stamina,recovery=pr.recovery,movement=pr.movement,updated_at=now()
  where player_id=p_player_id;

  v_condition:=jsonb_build_object(
    'fatigue_before',v_fatigue_before,'fatigue_after',v_new_fatigue,
    'sharpness_before',v_sharpness_before,'sharpness_after',v_new_sharpness,
    'morale_before',v_morale_before,'morale_after',v_new_morale,
    'confidence_before',v_confidence_before,'confidence_after',v_new_confidence,
    'focus_before',v_focus_before,'focus_after',v_new_focus
  );

  insert into public.player_training_camp_days(
    booking_id,player_id,season,month,day,absolute_day,camp_day_number,camp_week,efficiency,development_gains,level_ups,condition_changes,day_role
  ) values(
    v_booking.id,p_player_id,p_season,p_month,p_day,v_abs,v_day_no,v_week,round(v_eff,4),v_gains,v_levelups,v_condition,v_day_role
  );

  update public.player_daily_activity
  set effects_applied_at=now(),effect_summary=jsonb_build_object('camp_booking_id',v_booking.id,'program_id',v_program.id,'day_role',v_day_role,'development_gains',v_gains,'raw_development_gains',v_raw_gains,'level_ups',v_levelups,'condition_changes',v_condition),updated_at=now()
  where player_id=p_player_id and season=p_season and month=p_month and day=p_day;

  if v_booking.status='booked' then
    update public.player_training_camp_bookings set status='active',started_at=coalesce(started_at,now()),updated_at=now() where id=v_booking.id;
  end if;

  if v_abs=v_booking.end_absolute_day then
    update public.player_training_camp_bookings set status='completed',completed_at=now(),updated_at=now() where id=v_booking.id;
    perform public.emit_notification_v1((select owner_user_id from public.players where id=p_player_id),p_player_id,'training.camp.completed','Training camp completed',format('%s in %s is complete. Your camp development has been applied.',v_program.name,v_location.city),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city),'training-camp-completed:'||v_booking.id::text);
  end if;

  return jsonb_build_object(
    'status','completed','activity_type','training_camp','booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,
    'camp_day_number',v_day_no,'camp_week',v_week,'day_role',v_day_role,'efficiency',round(v_eff,4),
    'development_gains',v_gains,'raw_development_gains',v_raw_gains,'level_ups',v_levelups,'condition_changes',v_condition
  );
end;
$$;

comment on column public.player_training_camp_days.day_role is 'Training camps use six development days plus a seventh-day recovery rhythm for tennis/physical camps. Recovery & Mindset camps remain recovery-focused every day.';
