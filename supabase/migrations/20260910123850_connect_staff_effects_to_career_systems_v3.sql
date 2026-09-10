create or replace function public.apply_regular_training_staff_session_v1()
returns trigger
language plpgsql security definer
set search_path to 'public'
as $function$
declare
  v_effects jsonb; v_tech numeric; v_phys numeric; v_red numeric; v_rec numeric; v_fit_rec numeric; v_combined_rec numeric;
  v_morale_pts integer; v_conf_pts integer; v_focus_pts integer; k text; val numeric; scaled jsonb:='{}'::jsonb; delta integer; extra integer; v_conf integer;
begin
  v_effects:=public.get_player_staff_effects_v1(new.player_id);
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
language plpgsql security definer
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

create or replace function public.get_player_injury_risk_v1(p_player_id uuid, p_context text default 'general'::text, p_intensity text default null::text, p_match_minutes integer default 0, p_heat_index numeric default 0)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $function$
declare s public.player_skills%rowtype;v_base numeric;v_mult numeric:=1;v_risk numeric;v_reasons jsonb:='[]'::jsonb;v_context text:=lower(coalesce(p_context,'general'));v_active integer:=0;v_staff jsonb;v_staff_red numeric:=0;
begin
  select * into s from public.player_skills where player_id=p_player_id;
  if s.player_id is null then return jsonb_build_object('risk_percent',0,'risk_level','low','reasons','[]'::jsonb);end if;
  v_base:=case v_context when 'regular_training' then case lower(coalesce(p_intensity,'standard')) when 'light' then 0.12 when 'hard' then 0.55 else 0.25 end when 'training_camp' then 0.30 when 'match' then 0.45 else 0.18 end;
  if s.fatigue>=80 then v_mult:=v_mult*2.4;v_reasons:=v_reasons||'"Very high fatigue"'::jsonb;
  elsif s.fatigue>=65 then v_mult:=v_mult*1.75;v_reasons:=v_reasons||'"High fatigue"'::jsonb;
  elsif s.fatigue>=50 then v_mult:=v_mult*1.30;v_reasons:=v_reasons||'"Accumulated fatigue"'::jsonb;end if;
  if s.fitness<45 then v_mult:=v_mult*1.28;v_reasons:=v_reasons||'"Low fitness"'::jsonb;elsif s.fitness>=70 then v_mult:=v_mult*0.90;end if;
  if s.recovery<45 then v_mult:=v_mult*1.20;v_reasons:=v_reasons||'"Low recovery ability"'::jsonb;elsif s.recovery>=70 then v_mult:=v_mult*0.92;end if;
  if s.movement<45 and v_context in ('match','training_camp') then v_mult:=v_mult*1.12;v_reasons:=v_reasons||'"Limited movement resilience"'::jsonb;end if;
  if v_context='match' and p_match_minutes>120 then v_mult:=v_mult*(1+least(0.90,(p_match_minutes-120)::numeric/240.0));v_reasons:=v_reasons||to_jsonb(format('Long match load (%s min)',p_match_minutes));end if;
  if v_context='match' and p_heat_index>0 then v_mult:=v_mult*(1+least(0.55,p_heat_index));v_reasons:=v_reasons||'"Hot outdoor conditions"'::jsonb;end if;
  select count(*) into v_active from public.player_injuries where player_id=p_player_id and status in ('active','recovering');
  if v_active>0 then v_mult:=v_mult*1.35;v_reasons:=v_reasons||'"Existing injury / aggravation risk"'::jsonb;end if;
  v_staff:=public.get_player_staff_effects_v1(p_player_id);
  v_staff_red:=greatest(0,least(0.12,coalesce((v_staff->>'injury_prevention_reduction')::numeric,0)));
  if v_staff_red>0 then v_reasons:=v_reasons||to_jsonb(format('Physiotherapist prevention: -%s%% relative risk',round(v_staff_red*100,1))); end if;
  v_risk:=round(least(7.5,greatest(0.03,v_base*v_mult*(1-v_staff_red))),2);
  if jsonb_array_length(v_reasons)=0 then v_reasons:='["Normal tennis activity risk"]'::jsonb;end if;
  return jsonb_build_object('risk_percent',v_risk,'risk_level',public.injury_risk_level_v1(v_risk),'reasons',v_reasons,'context',v_context,'staff_modifier_applied',v_staff_red>0,'staff_injury_reduction',round(v_staff_red,4));
end;
$function$;

create or replace function public.roll_player_injury_v1(p_player_id uuid, p_context text, p_source_reference_id uuid default null::uuid, p_intensity text default null::text, p_match_minutes integer default 0, p_heat_index numeric default 0)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $function$
declare d record;v_abs integer;v_risk jsonb;v_pct numeric;v_seed text;v_roll numeric;v_pick numeric;v_total numeric;v_running numeric:=0;c public.injury_catalog%rowtype;v_train integer;v_tour integer;v_rec integer;v_owner uuid;v_id uuid;v_detail jsonb;v_staff jsonb;v_rehab_red numeric:=0;v_return_red numeric:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  if p_source_reference_id is not null and exists(select 1 from public.player_injuries where player_id=p_player_id and source_type=p_context and source_reference_id=p_source_reference_id) then return jsonb_build_object('status','already_processed');end if;
  v_risk:=public.get_player_injury_risk_v1(p_player_id,p_context,p_intensity,p_match_minutes,p_heat_index);v_pct:=(v_risk->>'risk_percent')::numeric;
  v_seed:=p_player_id::text||':'||p_context||':'||coalesce(p_source_reference_id::text,v_abs::text);
  v_roll:=public.match_engine_random_v1(v_seed||':injury',1)*100;
  insert into public.player_injury_risk_events(player_id,absolute_day,context,risk_percent,risk_level,reasons) values(p_player_id,v_abs,p_context,v_pct,v_risk->>'risk_level',v_risk->'reasons') on conflict(player_id,absolute_day,context) do update set risk_percent=excluded.risk_percent,risk_level=excluded.risk_level,reasons=excluded.reasons;
  if v_roll>=v_pct then return jsonb_build_object('status','clear','risk',v_risk,'roll',round(v_roll,2));end if;
  select sum(relative_weight) into v_total from public.injury_catalog where is_active and p_context=any(contexts);
  v_pick:=public.match_engine_random_v1(v_seed||':type',2)*greatest(v_total,1);
  for c in select * from public.injury_catalog where is_active and p_context=any(contexts) order by code loop v_running:=v_running+c.relative_weight;if v_pick<=v_running then exit;end if;end loop;
  if c.code is null then select * into c from public.injury_catalog where is_active order by code limit 1;end if;
  v_train:=c.training_out_min_days+floor(public.match_engine_random_v1(v_seed||':train',3)*(c.training_out_max_days-c.training_out_min_days+1))::integer;
  v_tour:=c.tournament_out_min_days+floor(public.match_engine_random_v1(v_seed||':tour',4)*(c.tournament_out_max_days-c.tournament_out_min_days+1))::integer;
  v_rec:=c.recovery_min_days+floor(public.match_engine_random_v1(v_seed||':recovery',5)*(c.recovery_max_days-c.recovery_min_days+1))::integer;
  v_staff:=public.get_player_staff_effects_v1(p_player_id);
  v_rehab_red:=greatest(0,least(0.15,coalesce((v_staff->>'rehabilitation_duration_reduction')::numeric,0)));
  v_return_red:=greatest(0,least(0.10,coalesce((v_staff->>'return_to_play_duration_reduction')::numeric,0)));
  if v_return_red>0 then
    v_train:=greatest(1,ceil(v_train*(1-v_return_red))::integer);
    v_tour:=greatest(1,ceil(v_tour*(1-v_return_red))::integer);
  end if;
  if v_rehab_red>0 then v_rec:=greatest(1,ceil(v_rec*(1-v_rehab_red))::integer); end if;
  v_detail:=jsonb_build_object('risk_at_onset',v_risk,'roll',round(v_roll,2),'cause_context',p_context,'intensity',p_intensity,'match_minutes',p_match_minutes,'heat_index',p_heat_index,'staff_rehabilitation_reduction',round(v_rehab_red,4),'staff_return_to_play_reduction',round(v_return_red,4));
  insert into public.player_injuries(player_id,injury_code,severity,source_type,source_reference_id,onset_absolute_day,training_return_absolute_day,tournament_return_absolute_day,expected_full_recovery_absolute_day,status,performance_penalty,aggravation_risk,treatment_code,details)
  values(p_player_id,c.code,c.severity,p_context,p_source_reference_id,v_abs,v_abs+v_train,v_abs+v_tour,v_abs+v_rec,'active',c.base_performance_penalty,c.aggravation_risk,c.treatment_code,v_detail) returning id into v_id;
  select owner_user_id into v_owner from public.players where id=p_player_id;
  if v_owner is not null then perform public.emit_notification_v1(v_owner,p_player_id,'player.injury.detected','Injury detected',format('%s — %s. Training return: %s day%s; tournament return: %s day%s; expected full recovery: %s day%s.',c.name,initcap(c.severity),v_train,case when v_train=1 then '' else 's' end,v_tour,case when v_tour=1 then '' else 's' end,v_rec,case when v_rec=1 then '' else 's' end),'/game/injuries',jsonb_build_object('injury_id',v_id,'injury_code',c.code,'severity',c.severity,'training_out_days',v_train,'tournament_out_days',v_tour,'recovery_days',v_rec),format('injury:%s:%s',p_player_id,v_id));end if;
  return jsonb_build_object('status','injured','injury_id',v_id,'injury_code',c.code,'injury_name',c.name,'severity',c.severity,'training_out_days',v_train,'tournament_out_days',v_tour,'recovery_days',v_rec,'risk',v_risk,'staff_rehabilitation_reduction',round(v_rehab_red,4),'staff_return_to_play_reduction',round(v_return_red,4));
end;
$function$;

create or replace function public.get_player_scouting_report_v1(p_target_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $function$
declare v_me uuid; v_target public.players%rowtype; sk public.player_skills%rowtype; v_margin integer; v_attrs jsonb:='{}'::jsonb; k text; v integer; v_strength text; v_weakness text; v_effects jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_me from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_me is null then raise exception 'Player not found.'; end if;
  select * into v_target from public.players where id=p_target_player_id and moderation_status<>'rejected';
  if v_target.id is null then raise exception 'Target player not found.'; end if;
  if v_target.id=v_me then return jsonb_build_object('available',false,'reason','Use your Skills page for exact personal attributes.'); end if;
  if not exists(select 1 from public.player_staff_contracts where player_id=v_me and role='performance_analyst' and status='active') then return jsonb_build_object('available',false,'reason','Hire a Performance Analyst to unlock opponent estimates.'); end if;
  v_effects:=public.get_player_staff_effects_v1(v_me);
  v_margin:=coalesce((v_effects->>'scouting_margin')::integer,10);
  select * into sk from public.player_skills where player_id=v_target.id;
  foreach k in array array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash','fitness','stamina','recovery','movement'] loop
    v:=(to_jsonb(sk)->>k)::integer;
    v_attrs:=v_attrs||jsonb_build_object(k,jsonb_build_object('min',greatest(1,v-v_margin),'max',least(100,v+v_margin)));
  end loop;
  select key into v_strength from jsonb_each_text(jsonb_build_object('serve',sk.serve,'forehand',sk.forehand,'backhand',sk.backhand,'return_skill',sk.return_skill,'volley',sk.volley,'slice',sk.slice,'drop_shot',sk.drop_shot,'lob',sk.lob,'smash',sk.smash)) order by value::integer desc,key limit 1;
  select key into v_weakness from jsonb_each_text(jsonb_build_object('serve',sk.serve,'forehand',sk.forehand,'backhand',sk.backhand,'return_skill',sk.return_skill,'volley',sk.volley,'slice',sk.slice,'drop_shot',sk.drop_shot,'lob',sk.lob,'smash',sk.smash)) order by value::integer asc,key limit 1;
  return jsonb_build_object('available',true,'estimate_margin',v_margin,'attributes',v_attrs,'identified_strength',v_strength,'identified_weakness',v_weakness,'preferred_surface',v_target.preferred_surface,'playing_style',v_target.playing_style);
end;
$function$;

alter function public.get_match_engine_profile_for_match_v2(uuid,text,uuid) rename to get_match_engine_profile_for_match_base_v2;

create or replace function public.get_match_engine_profile_for_match_v2(p_player_id uuid,p_surface text,p_match_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $function$
declare b jsonb; e jsonb; m numeric:=1; v numeric;
begin
  b:=public.get_match_engine_profile_for_match_base_v2(p_player_id,p_surface,p_match_id);
  e:=public.get_player_staff_effects_v1(p_player_id);
  m:=greatest(1,least(1.02,coalesce((e->>'match_staff_multiplier')::numeric,1)));
  if m>1 then
    foreach v in array array[(b->'ratings'->>'serve')::numeric,(b->'ratings'->>'return')::numeric,(b->'ratings'->>'rally')::numeric,(b->'ratings'->>'net')::numeric] loop null; end loop;
    b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*m,2)));
  end if;
  return b||jsonb_build_object('staff_support',jsonb_build_object('match_multiplier',round(m,4),'bonus_percent',round((m-1)*100,2),'global_cap_percent',2.0));
end;
$function$;

create or replace function public.get_tournament_match_engine_preview_v1(p_match_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $function$declare m public.tournament_matches%rowtype;sim public.tournament_match_simulations%rowtype;ts public.tournament_series%rowtype;wc public.tournament_world_competitions%rowtype;p1 jsonb;p2 jsonb;v_snapshot jsonb;w jsonb;begin
 if auth.uid() is null then raise exception 'Authentication required.';end if;select * into m from public.tournament_matches where id=p_match_id;if m.id is null then return jsonb_build_object('status','unavailable');end if;select wc0.* into wc from public.tournament_world_competitions wc0 where wc0.id=m.competition_id;select s.* into ts from public.tournament_world_competitions wc0 join public.tournament_editions ed on ed.id=wc0.tournament_edition_id join public.tournament_series s on s.id=ed.tournament_series_id where wc0.id=m.competition_id;select * into sim from public.tournament_match_simulations where match_id=p_match_id;
 if sim.match_id is not null and sim.metadata ? 'profile_snapshot' then v_snapshot:=sim.metadata->'profile_snapshot';p1:=v_snapshot->'player1';p2:=v_snapshot->'player2';w:=coalesce(sim.metadata->'weather',public.calculate_tournament_match_weather_v1(p_match_id));elsif m.player1_id is not null and m.player2_id is not null then p1:=public.get_match_engine_profile_for_match_v2(m.player1_id,ts.surface,p_match_id);p2:=public.get_match_engine_profile_for_match_v2(m.player2_id,ts.surface,p_match_id);w:=public.calculate_tournament_match_weather_v1(p_match_id);else return jsonb_build_object('status','waiting_for_players','match_status',m.status);end if;
 return jsonb_build_object('status','ready','match_status',m.status,'surface',lower(ts.surface),'world',wc.world,'category',ts.category_code,'weather',w,'player1',p1,'player2',p2,'comparison',jsonb_build_object('player1_effective_level',(p1->'ratings'->>'effective_overall')::numeric,'player2_effective_level',(p2->'ratings'->>'effective_overall')::numeric,'difference',round((p1->'ratings'->>'effective_overall')::numeric-(p2->'ratings'->>'effective_overall')::numeric,2)),'v2_scope',jsonb_build_object('equipment',false,'staff',true,'weather',true,'injuries',true,'match_tactics',true,'playing_style_outcome_modifier',true,'playing_style_replay_flavour',true,'weather_can_delay',false));
end;$function$;

alter table public.player_sponsor_offers add column if not exists base_full_season_value bigint;
alter table public.player_sponsor_offers add column if not exists staff_sponsorship_multiplier numeric(8,4) not null default 1;

create or replace function public.apply_career_manager_to_sponsor_offer_v1()
returns trigger
language plpgsql security definer
set search_path to 'public','pg_temp'
as $function$
declare e jsonb; m numeric:=1; base bigint;
begin
  if tg_op='INSERT' then
    base:=coalesce(new.base_full_season_value,new.full_season_value);
  elsif new.full_season_value is distinct from old.full_season_value then
    base:=new.full_season_value;
  else
    base:=coalesce(old.base_full_season_value,new.base_full_season_value,new.full_season_value);
  end if;
  e:=public.get_player_staff_effects_v1(new.player_id);
  m:=greatest(1,least(1.10,coalesce((e->>'sponsorship_multiplier')::numeric,1)));
  new.base_full_season_value:=base;
  new.staff_sponsorship_multiplier:=m;
  new.full_season_value:=(round((base*m)::numeric/100)*100)::bigint;
  if new.scheduled_payment_count is not null and new.scheduled_payment_count>0 then
    new.weekly_payment_amount:=greatest(50::bigint,(round((new.full_season_value::numeric/52)/10)*10)::bigint);
    new.total_contract_value:=new.weekly_payment_amount*new.scheduled_payment_count;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_apply_career_manager_to_sponsor_offer_v1 on public.player_sponsor_offers;
create trigger trg_apply_career_manager_to_sponsor_offer_v1
before insert or update of full_season_value,scheduled_payment_count on public.player_sponsor_offers
for each row execute function public.apply_career_manager_to_sponsor_offer_v1();

update public.player_sponsor_offers set base_full_season_value=full_season_value where base_full_season_value is null and status='open';
