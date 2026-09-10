alter table public.staff_members add column if not exists age smallint;
alter table public.staff_members add column if not exists experience_years smallint;
alter table public.staff_members add column if not exists education text;
alter table public.staff_members add column if not exists courses jsonb;
alter table public.staff_members add column if not exists image_path text;

update public.staff_members
set age = coalesce(age, least(62, greatest(27, 27 + ((overall_rating::integer - 40) / 3) + mod(market_serial, 8)::integer))::smallint),
    experience_years = coalesce(experience_years, least(36, greatest(2, 3 + ((overall_rating::integer - 40) / 3) + mod(market_serial, 5)::integer))::smallint),
    education = coalesce(education, case role
      when 'head_coach' then 'Professional Tennis Coaching Diploma'
      when 'fitness_coach' then 'Sports Conditioning & Performance Diploma'
      when 'physiotherapist' then 'Sports Physiotherapy Qualification'
      when 'sports_psychologist' then 'Sport Psychology Qualification'
      when 'performance_analyst' then 'Performance Analysis & Data Qualification'
      when 'agent_manager' then 'Sports Management & Representation Diploma'
      else 'Professional Sports Staff Qualification' end),
    courses = coalesce(courses, jsonb_build_array(
      case role
        when 'head_coach' then 'Advanced Player Development'
        when 'fitness_coach' then 'Tennis Workload Management'
        when 'physiotherapist' then 'Tennis Injury Management'
        when 'sports_psychologist' then 'Competitive Performance Psychology'
        when 'performance_analyst' then 'Tennis Match Analysis'
        when 'agent_manager' then 'Athlete Career & Sponsorship Management'
        else 'Professional Development' end,
      case quality_tier
        when 'world_class' then 'World-Class Professional Development'
        when 'elite' then 'Elite Professional Development'
        when 'advanced' then 'Advanced Professional Development'
        when 'professional' then 'Professional Practice'
        else 'Developing Professional Practice' end
    ));

alter table public.staff_members alter column age set not null;
alter table public.staff_members alter column experience_years set not null;
alter table public.staff_members alter column education set not null;
alter table public.staff_members alter column courses set default '[]'::jsonb;
alter table public.staff_members alter column courses set not null;

create or replace function public.set_staff_profile_defaults_v1()
returns trigger
language plpgsql
set search_path to 'public','pg_temp'
as $function$
begin
  new.age := coalesce(new.age, least(62, greatest(27, 27 + ((new.overall_rating::integer - 40) / 3) + mod(new.market_serial, 8)::integer))::smallint);
  new.experience_years := coalesce(new.experience_years, least(36, greatest(2, 3 + ((new.overall_rating::integer - 40) / 3) + mod(new.market_serial, 5)::integer))::smallint);
  new.education := coalesce(new.education, case new.role
    when 'head_coach' then 'Professional Tennis Coaching Diploma'
    when 'fitness_coach' then 'Sports Conditioning & Performance Diploma'
    when 'physiotherapist' then 'Sports Physiotherapy Qualification'
    when 'sports_psychologist' then 'Sport Psychology Qualification'
    when 'performance_analyst' then 'Performance Analysis & Data Qualification'
    when 'agent_manager' then 'Sports Management & Representation Diploma'
    else 'Professional Sports Staff Qualification' end);
  new.courses := coalesce(new.courses, jsonb_build_array(
    case new.role
      when 'head_coach' then 'Advanced Player Development'
      when 'fitness_coach' then 'Tennis Workload Management'
      when 'physiotherapist' then 'Tennis Injury Management'
      when 'sports_psychologist' then 'Competitive Performance Psychology'
      when 'performance_analyst' then 'Tennis Match Analysis'
      when 'agent_manager' then 'Athlete Career & Sponsorship Management'
      else 'Professional Development' end,
    case new.quality_tier
      when 'world_class' then 'World-Class Professional Development'
      when 'elite' then 'Elite Professional Development'
      when 'advanced' then 'Advanced Professional Development'
      when 'professional' then 'Professional Practice'
      else 'Developing Professional Practice' end
  ));
  return new;
end;
$function$;

drop trigger if exists trg_staff_profile_defaults_v1 on public.staff_members;
create trigger trg_staff_profile_defaults_v1
before insert or update of overall_rating, quality_tier, role on public.staff_members
for each row execute function public.set_staff_profile_defaults_v1();

create table if not exists public.staff_role_catalog (
  role text primary key,
  label text not null,
  main_responsibility text not null,
  systems text[] not null default '{}'::text[],
  max_positions smallint not null default 1 check (max_positions > 0),
  effect_cadence text not null,
  vacancy_behavior text not null,
  stacking_rule text not null,
  facility_limited boolean not null default false,
  facility_limit_note text not null,
  attributes jsonb not null default '[]'::jsonb,
  effects jsonb not null default '[]'::jsonb,
  review_note text,
  sort_order smallint not null
);

insert into public.staff_role_catalog(role,label,main_responsibility,systems,max_positions,effect_cadence,vacancy_behavior,stacking_rule,facility_limited,facility_limit_note,attributes,effects,review_note,sort_order)
values
('head_coach','Head Coach','Leads technical development and converts tactical knowledge into a small match-preparation advantage.',array['Regular training','Training camps','Match preparation'],1,'Training-session, camp-day and match based','Training and matches continue normally, but no Head Coach development or match-preparation bonus is applied.','Only one Head Coach may be active. Their match bonus can combine with Performance Analyst and Sports Psychologist support, subject to the global +2.0% match-staff cap.',false,'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.',
 '[{"key":"technical_coaching","label":"Technical Coaching","description":"Drives technical-skill gains in regular planned training."},{"key":"tactical_knowledge","label":"Tactical Knowledge","description":"Creates a small preparation modifier for competitive matches."},{"key":"player_development","label":"Player Development","description":"Improves tennis-skill development during training camps."},{"key":"motivation","label":"Motivation","description":"Adds a smaller supporting bonus to technical training and camp development."}]'::jsonb,
 '[{"key":"technical_training","label":"Technical training effectiveness","maximum":"+12%","cadence":"Each planned training session","note":"Up to +10% from coaching/motivation, plus up to +2% when a surface-development specialty matches the player preferred surface."},{"key":"technical_camp","label":"Tennis-skill camp effectiveness","maximum":"+10%","cadence":"Each tennis-skills camp development day","note":"Up to +9% from development/motivation plus +1% matching-surface specialty."},{"key":"match_preparation","label":"Match preparation","maximum":"+0.75% match execution","cadence":"Each competitive match","note":"Part of the combined staff match modifier, globally capped at +2.0%."}]'::jsonb,
 'Kept as a distinct role. Development leadership is different from opponent analysis, so it is not merged with Performance Analyst.',1),
('fitness_coach','Fitness Coach','Improves physical development, conditioning and workload management without replacing normal rest decisions.',array['Regular training','Training camps','Active recovery'],1,'Training-session and camp-day based','Physical training, fatigue and recovery continue with base game values, but no Fitness Coach bonus is applied.','Only one Fitness Coach may be active. Active-recovery support can combine with Physiotherapist recovery, capped at +20% total recovery efficiency.',false,'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.',
 '[{"key":"conditioning","label":"Conditioning","description":"Improves physical-development output in physical training camps."},{"key":"physical_development","label":"Physical Development","description":"Drives physical-skill gains in regular planned training."},{"key":"workload_management","label":"Workload Management","description":"Reduces fatigue gained from planned training."},{"key":"recovery_knowledge","label":"Recovery Knowledge","description":"Improves fatigue recovery specifically on active-recovery sessions."}]'::jsonb,
 '[{"key":"physical_training","label":"Physical training effectiveness","maximum":"+10%","cadence":"Each planned training session"},{"key":"physical_camp","label":"Physical camp effectiveness","maximum":"+8%","cadence":"Each physical-camp development day"},{"key":"training_fatigue","label":"Training fatigue gain","maximum":"-10%","cadence":"Each planned training session"},{"key":"active_recovery","label":"Active-recovery efficiency","maximum":"+5%","cadence":"Each active-recovery session","note":"Combines with Physiotherapist recovery up to +20% total."}]'::jsonb,
 'Kept separate from Physiotherapist: Fitness Coach manages performance load and physical development; Physiotherapist manages medical recovery and injury outcomes.',2),
('physiotherapist','Physiotherapist','Supports fatigue recovery, injury prevention and safer return from injuries.',array['Recovery','Injury risk','Rehabilitation','Return to play'],1,'Recovery-session and injury-event based','Recovery and injury systems continue normally, but no medical-staff recovery, prevention or rehabilitation bonus is applied.','Only one Physiotherapist may be active. Recovery can combine with Fitness Coach active-recovery support, capped at +20% total.',false,'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.',
 '[{"key":"recovery","label":"Recovery","description":"Improves fatigue recovered during rest/recovery activity."},{"key":"injury_prevention","label":"Injury Prevention","description":"Reduces the final injury probability after normal fatigue, fitness and activity-risk factors are calculated."},{"key":"rehabilitation","label":"Rehabilitation","description":"Reduces expected time to full recovery when a new injury occurs."},{"key":"treatment","label":"Treatment","description":"Reduces training and tournament return-to-play delays when a new injury occurs."}]'::jsonb,
 '[{"key":"recovery","label":"Fatigue recovery efficiency","maximum":"+15%","cadence":"Recovery/rest sessions"},{"key":"injury_prevention","label":"Injury-risk reduction","maximum":"-12% relative risk","cadence":"Every injury-risk roll"},{"key":"rehabilitation","label":"Full-recovery duration","maximum":"-15%","cadence":"When a new injury is created"},{"key":"return_to_play","label":"Training/tournament return delay","maximum":"-10%","cadence":"When a new injury is created"}]'::jsonb,
 'Kept as the sole medical role. A separate Team Doctor would duplicate the same gameplay space at the current level of medical simulation.',3),
('sports_psychologist','Sports Psychologist','Supports morale, confidence, focus and pressure handling while keeping player attributes and match tactics decisive.',array['Recovery','Mental condition','Match pressure'],1,'Recovery-session and match based','Mental condition still changes through normal game systems, but no psychologist recovery points or pressure-match bonus is applied.','Only one Sports Psychologist may be active. Their pressure effect can combine with Head Coach and Performance Analyst support, subject to the global +2.0% match-staff cap.',false,'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.',
 '[{"key":"morale","label":"Morale","description":"Determines bonus morale points restored on recovery/rest sessions."},{"key":"confidence","label":"Confidence","description":"Determines bonus confidence points restored on recovery/rest sessions."},{"key":"focus","label":"Focus","description":"Determines bonus focus points restored on recovery/rest sessions."},{"key":"pressure_management","label":"Pressure Management","description":"Provides a small match-execution bonus under the global staff cap."}]'::jsonb,
 '[{"key":"morale","label":"Morale recovery","maximum":"+2 points","cadence":"Recovery/rest session"},{"key":"confidence","label":"Confidence recovery","maximum":"+2 points","cadence":"Recovery/rest session"},{"key":"focus","label":"Focus recovery","maximum":"+2 points","cadence":"Recovery/rest session"},{"key":"pressure","label":"Pressure-match support","maximum":"+0.50% match execution","cadence":"Each competitive match","note":"Part of the global +2.0% combined match-staff cap."}]'::jsonb,
 'Kept as a distinct mental-performance role. It does not remove pressure or guarantee results.',4),
('performance_analyst','Performance Analyst','Turns scouting and tactical analysis into more accurate opponent reports and a small match-preparation edge.',array['Opponent scouting','Player reports','Match preparation'],1,'On-demand report and match based','Opponent profiles remain available, but detailed attribute estimates are locked and no analyst match-preparation bonus is applied.','Only one Performance Analyst may be active. Match support can combine with Head Coach and Sports Psychologist support, capped globally at +2.0%.',false,'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.',
 '[{"key":"opponent_analysis","label":"Opponent Analysis","description":"Main driver of the accuracy range shown in opponent scouting reports."},{"key":"tactical_analysis","label":"Tactical Analysis","description":"Contributes to the analyst match-preparation modifier."},{"key":"match_preparation","label":"Match Preparation","description":"Contributes to the analyst match-preparation modifier."},{"key":"scouting","label":"Scouting","description":"Adds the final accuracy refinement to opponent attribute estimates."}]'::jsonb,
 '[{"key":"scouting","label":"Opponent estimate accuracy","maximum":"±1 attribute point","cadence":"Whenever an opponent report is opened","note":"Without an analyst detailed estimates are unavailable. At lower quality the estimate band can be as wide as ±10."},{"key":"match_preparation","label":"Analyst match preparation","maximum":"+0.75% match execution","cadence":"Each competitive match","note":"Part of the global +2.0% combined match-staff cap."}]'::jsonb,
 'Kept as one analysis/scouting role. A separate Scout would overlap heavily with the existing opponent-report system.',5),
('agent_manager','Career Manager','Handles commercial representation and turns negotiation, network, reputation and career-management quality into better sponsor offer value.',array['Sponsorship','Commercial career management'],1,'Sponsor-offer generation and repricing based','Sponsor offers and career decisions remain available at their normal base values, but no Career Manager value uplift is applied.','Only one Career Manager may be active. The role has one capped combined commercial effect rather than stacking several separate money multipliers.',false,'No facility cap currently applies in Tennis Legacy. The calculated staff bonus is applied in full.',
 '[{"key":"negotiation","label":"Negotiation","description":"Contributes up to 3 percentage points to the sponsor-value uplift."},{"key":"sponsorship_network","label":"Sponsorship Network","description":"Largest contributor, worth up to 4 percentage points of sponsor-value uplift."},{"key":"commercial_reputation","label":"Commercial Reputation","description":"Contributes up to 2 percentage points to sponsor-value uplift."},{"key":"career_management","label":"Career Management","description":"Contributes up to 1 percentage point to sponsor-value uplift."}]'::jsonb,
 '[{"key":"sponsorship","label":"Sponsor offer value","maximum":"+10%","cadence":"When sponsor offers are generated or repriced","note":"The four Career Manager attributes combine into one capped +10% commercial modifier."}]'::jsonb,
 'Renamed in the UI from Agent / Manager to Career Manager. No extra agent/scout/equipment role is added because each additional role must occupy a distinct gameplay system.',6)
on conflict (role) do update set
 label=excluded.label,main_responsibility=excluded.main_responsibility,systems=excluded.systems,max_positions=excluded.max_positions,effect_cadence=excluded.effect_cadence,vacancy_behavior=excluded.vacancy_behavior,stacking_rule=excluded.stacking_rule,facility_limited=excluded.facility_limited,facility_limit_note=excluded.facility_limit_note,attributes=excluded.attributes,effects=excluded.effects,review_note=excluded.review_note,sort_order=excluded.sort_order;

alter table public.staff_role_catalog enable row level security;
drop policy if exists staff_role_catalog_read_authenticated on public.staff_role_catalog;
create policy staff_role_catalog_read_authenticated on public.staff_role_catalog for select to authenticated using (true);
grant select on public.staff_role_catalog to authenticated;

create or replace function public.staff_role_label_v1(p_role text)
returns text language sql immutable set search_path to 'public'
as $function$
  select case p_role
    when 'head_coach' then 'Head Coach'
    when 'fitness_coach' then 'Fitness Coach'
    when 'physiotherapist' then 'Physiotherapist'
    when 'sports_psychologist' then 'Sports Psychologist'
    when 'performance_analyst' then 'Performance Analyst'
    when 'agent_manager' then 'Career Manager'
    else p_role end;
$function$;

create or replace function public.staff_effect_factor_v2(p_value numeric)
returns numeric language sql immutable
as $function$
  select greatest(0::numeric,least(1::numeric,(coalesce(p_value,40)-40)/60));
$function$;

create or replace function public.get_player_staff_effects_v2(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_pref text;
  v_tech numeric:=1; v_tech_camp numeric:=1; v_coach_match numeric:=1;
  v_phys numeric:=1; v_phys_camp numeric:=1; v_fatigue_red numeric:=0; v_active_recovery numeric:=1;
  v_recovery numeric:=1; v_injury numeric:=0; v_rehab_red numeric:=0; v_return_red numeric:=0;
  v_morale_pts integer:=0; v_conf_pts integer:=0; v_focus_pts integer:=0; v_pressure numeric:=0;
  v_scout_margin integer:=10; v_analyst_match numeric:=1;
  v_sponsor numeric:=1; v_negotiation numeric:=1; v_match numeric:=1;
  r record; n numeric;
begin
  select preferred_surface into v_pref from public.players where id=p_player_id;
  for r in
    select c.role,s.id as staff_id,s.overall_rating,s.specialty,s.attributes
    from public.player_staff_contracts c join public.staff_members s on s.id=c.staff_id
    where c.player_id=p_player_id and c.status='active'
  loop
    if r.role='head_coach' then
      v_tech:=1
        +0.08*public.staff_effect_factor_v2((r.attributes->>'technical_coaching')::numeric)
        +0.02*public.staff_effect_factor_v2((r.attributes->>'motivation')::numeric);
      v_tech_camp:=1
        +0.07*public.staff_effect_factor_v2((r.attributes->>'player_development')::numeric)
        +0.02*public.staff_effect_factor_v2((r.attributes->>'motivation')::numeric);
      v_coach_match:=1+0.0075*public.staff_effect_factor_v2((r.attributes->>'tactical_knowledge')::numeric);
      if (v_pref='Clay' and r.specialty='Clay Development') or (v_pref='Hard' and r.specialty='Hard Court Development') or (v_pref='Grass' and r.specialty='Grass Development') then
        v_tech:=v_tech+0.02;
        v_tech_camp:=v_tech_camp+0.01;
      end if;
    elsif r.role='fitness_coach' then
      v_phys:=1+0.10*public.staff_effect_factor_v2((r.attributes->>'physical_development')::numeric);
      v_phys_camp:=1+0.08*public.staff_effect_factor_v2((r.attributes->>'conditioning')::numeric);
      v_fatigue_red:=0.10*public.staff_effect_factor_v2((r.attributes->>'workload_management')::numeric);
      v_active_recovery:=1+0.05*public.staff_effect_factor_v2((r.attributes->>'recovery_knowledge')::numeric);
    elsif r.role='physiotherapist' then
      v_recovery:=1+0.15*public.staff_effect_factor_v2((r.attributes->>'recovery')::numeric);
      v_injury:=0.12*public.staff_effect_factor_v2((r.attributes->>'injury_prevention')::numeric);
      v_rehab_red:=0.15*public.staff_effect_factor_v2((r.attributes->>'rehabilitation')::numeric);
      v_return_red:=0.10*public.staff_effect_factor_v2((r.attributes->>'treatment')::numeric);
    elsif r.role='sports_psychologist' then
      v_morale_pts:=round(2*public.staff_effect_factor_v2((r.attributes->>'morale')::numeric))::integer;
      v_conf_pts:=round(2*public.staff_effect_factor_v2((r.attributes->>'confidence')::numeric))::integer;
      v_focus_pts:=round(2*public.staff_effect_factor_v2((r.attributes->>'focus')::numeric))::integer;
      v_pressure:=0.005*public.staff_effect_factor_v2((r.attributes->>'pressure_management')::numeric);
    elsif r.role='performance_analyst' then
      v_scout_margin:=greatest(1,round(10
        -8*public.staff_effect_factor_v2((r.attributes->>'opponent_analysis')::numeric)
        -1*public.staff_effect_factor_v2((r.attributes->>'scouting')::numeric))::integer);
      v_analyst_match:=1
        +0.00375*public.staff_effect_factor_v2((r.attributes->>'tactical_analysis')::numeric)
        +0.00375*public.staff_effect_factor_v2((r.attributes->>'match_preparation')::numeric);
    elsif r.role='agent_manager' then
      v_negotiation:=1+0.03*public.staff_effect_factor_v2((r.attributes->>'negotiation')::numeric);
      v_sponsor:=1
        +0.03*public.staff_effect_factor_v2((r.attributes->>'negotiation')::numeric)
        +0.04*public.staff_effect_factor_v2((r.attributes->>'sponsorship_network')::numeric)
        +0.02*public.staff_effect_factor_v2((r.attributes->>'commercial_reputation')::numeric)
        +0.01*public.staff_effect_factor_v2((r.attributes->>'career_management')::numeric);
    end if;
  end loop;

  v_match:=1+least(0.02,greatest(0,(v_coach_match-1)+(v_analyst_match-1)+v_pressure));

  return jsonb_build_object(
    'technical_training_multiplier',round(v_tech,4),
    'technical_camp_multiplier',round(v_tech_camp,4),
    'coach_match_preparation_multiplier',round(v_coach_match,4),
    'physical_training_multiplier',round(v_phys,4),
    'physical_camp_multiplier',round(v_phys_camp,4),
    'training_fatigue_reduction',round(v_fatigue_red,4),
    'active_recovery_multiplier',round(v_active_recovery,4),
    'recovery_multiplier',round(v_recovery,4),
    'injury_prevention_reduction',round(v_injury,4),
    'rehabilitation_duration_reduction',round(v_rehab_red,4),
    'return_to_play_duration_reduction',round(v_return_red,4),
    'rehabilitation_multiplier',round(1+v_rehab_red,4),
    'morale_recovery_bonus_points',v_morale_pts,
    'confidence_recovery_bonus_points',v_conf_pts,
    'focus_recovery_bonus_points',v_focus_pts,
    'morale_recovery_multiplier',round(1+0.15*(v_morale_pts/2.0),4),
    'confidence_recovery_multiplier',round(1+0.15*(v_conf_pts/2.0),4),
    'focus_recovery_multiplier',round(1+0.15*(v_focus_pts/2.0),4),
    'pressure_bonus',round(v_pressure,4),
    'scouting_margin',v_scout_margin,
    'analyst_match_preparation_multiplier',round(v_analyst_match,4),
    'sponsorship_multiplier',round(v_sponsor,4),
    'negotiation_multiplier',round(v_negotiation,4),
    'match_staff_multiplier',round(v_match,4),
    'facility_cap_applied',false,
    'match_staff_cap',0.02
  );
end;
$function$;

create or replace function public.get_player_staff_effects_v1(p_player_id uuid)
returns jsonb language sql stable security definer set search_path to 'public','pg_temp'
as $function$
  select public.get_player_staff_effects_v2(p_player_id);
$function$;

create or replace function public.get_staff_role_effect_summary_v1(p_player_id uuid,p_role text)
returns jsonb
language plpgsql stable security definer
set search_path to 'public','pg_temp'
as $function$
declare e jsonb; v_active boolean; v_result jsonb;
begin
  e:=public.get_player_staff_effects_v2(p_player_id);
  select exists(select 1 from public.player_staff_contracts where player_id=p_player_id and role=p_role and status='active') into v_active;
  if p_role='head_coach' then
    v_result:=jsonb_build_array(
      jsonb_build_object('label','Technical training effectiveness','current_display',case when v_active then format('+%s%%',round(((e->>'technical_training_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+12%','cadence','Each planned training session'),
      jsonb_build_object('label','Tennis-skill camp effectiveness','current_display',case when v_active then format('+%s%%',round(((e->>'technical_camp_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+10%','cadence','Each tennis-skills camp development day'),
      jsonb_build_object('label','Match preparation','current_display',case when v_active then format('+%s%%',round(((e->>'coach_match_preparation_multiplier')::numeric-1)*100,2)) else '+0%' end,'maximum_display','+0.75%','cadence','Each competitive match')
    );
  elsif p_role='fitness_coach' then
    v_result:=jsonb_build_array(
      jsonb_build_object('label','Physical training effectiveness','current_display',case when v_active then format('+%s%%',round(((e->>'physical_training_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+10%','cadence','Each planned training session'),
      jsonb_build_object('label','Physical camp effectiveness','current_display',case when v_active then format('+%s%%',round(((e->>'physical_camp_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+8%','cadence','Each physical-camp development day'),
      jsonb_build_object('label','Training fatigue gain','current_display',case when v_active then format('-%s%%',round((e->>'training_fatigue_reduction')::numeric*100,1)) else '-0%' end,'maximum_display','-10%','cadence','Each planned training session'),
      jsonb_build_object('label','Active-recovery efficiency','current_display',case when v_active then format('+%s%%',round(((e->>'active_recovery_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+5%','cadence','Each active-recovery session')
    );
  elsif p_role='physiotherapist' then
    v_result:=jsonb_build_array(
      jsonb_build_object('label','Fatigue recovery efficiency','current_display',case when v_active then format('+%s%%',round(((e->>'recovery_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+15%','cadence','Recovery/rest sessions'),
      jsonb_build_object('label','Injury-risk reduction','current_display',case when v_active then format('-%s%%',round((e->>'injury_prevention_reduction')::numeric*100,1)) else '-0%' end,'maximum_display','-12% relative risk','cadence','Every injury-risk roll'),
      jsonb_build_object('label','Full-recovery duration','current_display',case when v_active then format('-%s%%',round((e->>'rehabilitation_duration_reduction')::numeric*100,1)) else '-0%' end,'maximum_display','-15%','cadence','When a new injury occurs'),
      jsonb_build_object('label','Return-to-play delay','current_display',case when v_active then format('-%s%%',round((e->>'return_to_play_duration_reduction')::numeric*100,1)) else '-0%' end,'maximum_display','-10%','cadence','When a new injury occurs')
    );
  elsif p_role='sports_psychologist' then
    v_result:=jsonb_build_array(
      jsonb_build_object('label','Morale recovery','current_display',case when v_active then format('+%s points',(e->>'morale_recovery_bonus_points')::integer) else '+0 points' end,'maximum_display','+2 points','cadence','Recovery/rest session'),
      jsonb_build_object('label','Confidence recovery','current_display',case when v_active then format('+%s points',(e->>'confidence_recovery_bonus_points')::integer) else '+0 points' end,'maximum_display','+2 points','cadence','Recovery/rest session'),
      jsonb_build_object('label','Focus recovery','current_display',case when v_active then format('+%s points',(e->>'focus_recovery_bonus_points')::integer) else '+0 points' end,'maximum_display','+2 points','cadence','Recovery/rest session'),
      jsonb_build_object('label','Pressure-match support','current_display',case when v_active then format('+%s%%',round((e->>'pressure_bonus')::numeric*100,2)) else '+0%' end,'maximum_display','+0.50%','cadence','Each competitive match')
    );
  elsif p_role='performance_analyst' then
    v_result:=jsonb_build_array(
      jsonb_build_object('label','Opponent estimate accuracy','current_display',case when v_active then format('±%s points',(e->>'scouting_margin')::integer) else 'Detailed estimates locked' end,'maximum_display','±1 point','cadence','Whenever an opponent report is opened'),
      jsonb_build_object('label','Analyst match preparation','current_display',case when v_active then format('+%s%%',round(((e->>'analyst_match_preparation_multiplier')::numeric-1)*100,2)) else '+0%' end,'maximum_display','+0.75%','cadence','Each competitive match')
    );
  elsif p_role='agent_manager' then
    v_result:=jsonb_build_array(
      jsonb_build_object('label','Sponsor offer value','current_display',case when v_active then format('+%s%%',round(((e->>'sponsorship_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+10%','cadence','When sponsor offers are generated or repriced')
    );
  else
    v_result:='[]'::jsonb;
  end if;
  return v_result;
end;
$function$;

create or replace function public.get_staff_dashboard_v2()
returns jsonb
language plpgsql stable security definer
set search_path to 'public','pg_temp'
as $function$
declare v_player uuid; v_base jsonb; v_roles jsonb; v_effects jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  v_base:=public.get_staff_dashboard_v1();
  v_effects:=public.get_player_staff_effects_v2(v_player);
  select coalesce(jsonb_agg(to_jsonb(r) || jsonb_build_object(
    'occupied',exists(select 1 from public.player_staff_contracts c where c.player_id=v_player and c.role=r.role and c.status='active'),
    'current_effects',public.get_staff_role_effect_summary_v1(v_player,r.role)
  ) order by r.sort_order),'[]'::jsonb) into v_roles
  from public.staff_role_catalog r;
  return v_base || jsonb_build_object(
    'effects',v_effects,
    'roles',v_roles,
    'combined_effects',jsonb_build_object(
      'technical_training_display',format('+%s%%',round(((v_effects->>'technical_training_multiplier')::numeric-1)*100,1)),
      'physical_training_display',format('+%s%%',round(((v_effects->>'physical_training_multiplier')::numeric-1)*100,1)),
      'active_recovery_display',format('+%s%%',round((least(1.20,(v_effects->>'recovery_multiplier')::numeric+(v_effects->>'active_recovery_multiplier')::numeric-1)-1)*100,1)),
      'injury_risk_display',format('-%s%%',round((v_effects->>'injury_prevention_reduction')::numeric*100,1)),
      'match_support_display',format('+%s%%',round(((v_effects->>'match_staff_multiplier')::numeric-1)*100,2)),
      'sponsor_value_display',format('+%s%%',round(((v_effects->>'sponsorship_multiplier')::numeric-1)*100,1))
    )
  );
end;
$function$;

create or replace function public.get_staff_member_profile_v1(p_staff_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path to 'public','pg_temp'
as $function$
declare v_player uuid; c public.player_staff_contracts%rowtype; s public.staff_members%rowtype; r public.staff_role_catalog%rowtype; v_start jsonb; v_end jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into c from public.player_staff_contracts where player_id=v_player and staff_id=p_staff_id and status='active' order by signed_at desc limit 1;
  if c.id is null then raise exception 'Active staff member not found on your team.'; end if;
  select * into s from public.staff_members where id=p_staff_id;
  select * into r from public.staff_role_catalog where role=c.role;
  select to_jsonb(g) into v_start from public.absolute_game_day_v1(c.start_absolute_day) g;
  select to_jsonb(g) into v_end from public.absolute_game_day_v1(c.end_absolute_day) g;
  return jsonb_build_object(
    'staff',jsonb_build_object('id',s.id,'first_name',s.first_name,'last_name',s.last_name,'country_code',s.country_code,'age',s.age,'experience_years',s.experience_years,'role',s.role,'role_label',r.label,'specialty',s.specialty,'overall_rating',s.overall_rating,'quality_tier',s.quality_tier,'quality_label',public.staff_quality_label_v1(s.quality_tier),'attributes',s.attributes,'education',s.education,'courses',s.courses,'image_path',s.image_path,'status',s.status),
    'contract',jsonb_build_object('id',c.id,'weekly_salary',c.weekly_salary,'duration_weeks',c.duration_weeks,'weeks_remaining',greatest(0,ceil((c.end_absolute_day-(select public.game_day_absolute_v1(d.season,d.month,d.day) from public.get_current_game_day_internal_v1() d)+1)::numeric/7)::integer),'start_absolute_day',c.start_absolute_day,'end_absolute_day',c.end_absolute_day,'start_game_day',v_start,'end_game_day',v_end,'status',c.status,'assignment','Your professional team'),
    'role',to_jsonb(r),
    'current_effects',public.get_staff_role_effect_summary_v1(v_player,c.role),
    'facility',jsonb_build_object('limited',false,'potential_equals_applied',true,'message',r.facility_limit_note),
    'advisory',jsonb_build_object('available',false,'message','No separate Staff Advisory service is enabled for Tennis Legacy staff yet. Role effects shown here are the live gameplay effects.'),
    'current_assignment','Your professional team'
  );
end;
$function$;

revoke all on function public.get_staff_dashboard_v2() from public;
grant execute on function public.get_staff_dashboard_v2() to authenticated;
revoke all on function public.get_staff_member_profile_v1(uuid) from public;
grant execute on function public.get_staff_member_profile_v1(uuid) to authenticated;
revoke all on function public.get_staff_role_effect_summary_v1(uuid,text) from public;
grant execute on function public.get_staff_role_effect_summary_v1(uuid,text) to authenticated;
