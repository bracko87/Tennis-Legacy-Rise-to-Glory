-- Give every travelling staff role a real tournament-specific benefit.
-- Tournament benefits are active only when the staff contract is selected in the saved preparation plan.

create or replace function public.get_tournament_staff_effects_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_selected_staff_contract_ids uuid[] default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_staff_ids uuid[];
  v_selected_count integer:=0;
  v_match_raw numeric:=0;
  v_fatigue_reduction numeric:=0;
  v_injury_reduction numeric:=0;
  v_commercial_bonus numeric:=0;
  v_items jsonb:='[]'::jsonb;
  v_effect numeric:=0;
  v_label text;
  v_value text;
  v_has_effect boolean;
  r record;
begin
  if p_selected_staff_contract_ids is null then
    select selected_staff_contract_ids
    into v_staff_ids
    from public.player_tournament_preparation_plans
    where player_id=p_player_id
      and competition_id=p_competition_id;
    v_staff_ids:=coalesce(v_staff_ids,'{}'::uuid[]);
  else
    v_staff_ids:=coalesce(p_selected_staff_contract_ids,'{}'::uuid[]);
  end if;

  for r in
    select
      c.id as contract_id,
      c.role,
      s.first_name,
      s.last_name,
      s.overall_rating,
      s.attributes
    from public.player_staff_contracts c
    join public.staff_members s on s.id=c.staff_id
    where c.player_id=p_player_id
      and c.status='active'
      and c.id=any(v_staff_ids)
    order by c.role,s.last_name,s.first_name
  loop
    v_selected_count:=v_selected_count+1;
    v_effect:=0;
    v_label:='Tournament support';
    v_value:='Active while travelling';
    v_has_effect:=true;

    if r.role='head_coach' then
      v_effect:=0.0075*public.staff_effect_factor_v2((r.attributes->>'tactical_knowledge')::numeric);
      v_match_raw:=v_match_raw+v_effect;
      v_label:='Match execution';
      v_value:='+'||round(v_effect*100,2)::text||'%';

    elsif r.role='fitness_coach' then
      v_effect:=least(
        0.10,
        0.08*public.staff_effect_factor_v2((r.attributes->>'workload_management')::numeric)
        +0.02*public.staff_effect_factor_v2((r.attributes->>'recovery_knowledge')::numeric)
      );
      v_fatigue_reduction:=greatest(v_fatigue_reduction,v_effect);
      v_label:='Match fatigue gain';
      v_value:='-'||round(v_effect*100,2)::text||'%';

    elsif r.role='physiotherapist' then
      v_effect:=0.12*public.staff_effect_factor_v2((r.attributes->>'injury_prevention')::numeric);
      v_injury_reduction:=greatest(v_injury_reduction,v_effect);
      v_label:='Match injury risk';
      v_value:='-'||round(v_effect*100,2)::text||'% relative risk';

    elsif r.role='sports_psychologist' then
      v_effect:=0.005*public.staff_effect_factor_v2((r.attributes->>'pressure_management')::numeric);
      v_match_raw:=v_match_raw+v_effect;
      v_label:='Pressure-match execution';
      v_value:='+'||round(v_effect*100,2)::text||'%';

    elsif r.role='performance_analyst' then
      v_effect:=
        0.0025*public.staff_effect_factor_v2((r.attributes->>'tactical_analysis')::numeric)
        +0.0025*public.staff_effect_factor_v2((r.attributes->>'match_preparation')::numeric);
      v_match_raw:=v_match_raw+v_effect;
      v_label:='Tactical match preparation';
      v_value:='+'||round(v_effect*100,2)::text||'% match execution';

    elsif r.role='agent_manager' then
      v_effect:=least(
        0.05,
        0.02*public.staff_effect_factor_v2((r.attributes->>'career_management')::numeric)
        +0.015*public.staff_effect_factor_v2((r.attributes->>'negotiation')::numeric)
        +0.015*public.staff_effect_factor_v2((r.attributes->>'sponsorship_network')::numeric)
      );
      v_commercial_bonus:=greatest(v_commercial_bonus,v_effect);
      v_label:='Tournament sponsor objective payout';
      v_value:='+'||round(v_effect*100,2)::text||'%';
    else
      v_has_effect:=false;
      v_value:='No tournament effect';
    end if;

    v_items:=v_items||jsonb_build_array(
      jsonb_build_object(
        'contract_id',r.contract_id,
        'role',r.role,
        'name',concat_ws(' ',r.first_name,r.last_name),
        'overall_rating',r.overall_rating,
        'benefit_label',v_label,
        'benefit_value',v_value,
        'active_tournament_effect',v_has_effect
      )
    );
  end loop;

  return jsonb_build_object(
    'selected_count',v_selected_count,
    'match_staff_multiplier',round(1+least(0.02,greatest(0,v_match_raw)),4),
    'match_execution_bonus_pct',round(least(0.02,greatest(0,v_match_raw))*100,2),
    'match_fatigue_reduction',round(v_fatigue_reduction,4),
    'match_fatigue_reduction_pct',round(v_fatigue_reduction*100,2),
    'injury_prevention_reduction',round(v_injury_reduction,4),
    'injury_risk_reduction_pct',round(v_injury_reduction*100,2),
    'commercial_bonus_multiplier',round(1+v_commercial_bonus,4),
    'commercial_bonus_pct',round(v_commercial_bonus*100,2),
    'staff',v_items
  );
end;
$function$;

revoke all on function public.get_tournament_staff_effects_v1(uuid,uuid,uuid[]) from public;
revoke all on function public.get_tournament_staff_effects_v1(uuid,uuid,uuid[]) from anon;
revoke all on function public.get_tournament_staff_effects_v1(uuid,uuid,uuid[]) from authenticated;

create or replace function public.get_tournament_match_injury_risk_v1(
  p_player_id uuid,
  p_match_id uuid,
  p_match_minutes integer default 0,
  p_heat_index numeric default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_base jsonb;
  v_global jsonb;
  v_travel jsonb;
  v_competition_id uuid;
  v_global_red numeric:=0;
  v_travel_red numeric:=0;
  v_current numeric:=0;
  v_unadjusted numeric:=0;
  v_adjusted numeric:=0;
  v_reasons jsonb:='[]'::jsonb;
begin
  v_base:=public.get_player_injury_risk_v1(
    p_player_id,'match',null,greatest(0,coalesce(p_match_minutes,0)),greatest(0,coalesce(p_heat_index,0))
  );

  select competition_id
  into v_competition_id
  from public.tournament_matches
  where id=p_match_id
    and (player1_id=p_player_id or player2_id=p_player_id);

  if v_competition_id is null then
    return v_base;
  end if;

  v_global:=public.get_player_staff_effects_v1(p_player_id);
  v_global_red:=greatest(0,least(0.12,coalesce((v_global->>'injury_prevention_reduction')::numeric,0)));

  v_travel:=public.get_tournament_staff_effects_v1(p_player_id,v_competition_id,null);
  v_travel_red:=greatest(0,least(0.12,coalesce((v_travel->>'injury_prevention_reduction')::numeric,0)));

  v_current:=greatest(0.03,coalesce((v_base->>'risk_percent')::numeric,0.03));
  if v_global_red>0 and v_global_red<1 then
    v_unadjusted:=v_current/(1-v_global_red);
  else
    v_unadjusted:=v_current;
  end if;

  v_adjusted:=round(least(7.5,greatest(0.03,v_unadjusted*(1-v_travel_red))),2);

  select coalesce(jsonb_agg(to_jsonb(reason)),'[]'::jsonb)
  into v_reasons
  from jsonb_array_elements_text(coalesce(v_base->'reasons','[]'::jsonb)) x(reason)
  where reason not ilike 'Physiotherapist prevention:%';

  if v_travel_red>0 then
    v_reasons:=v_reasons||to_jsonb(format(
      'Travelling physiotherapist prevention: -%s%% relative risk',
      round(v_travel_red*100,1)
    ));
  end if;

  if jsonb_array_length(v_reasons)=0 then
    v_reasons:='["Normal tennis activity risk"]'::jsonb;
  end if;

  return v_base||jsonb_build_object(
    'risk_percent',v_adjusted,
    'risk_level',public.injury_risk_level_v1(v_adjusted),
    'reasons',v_reasons,
    'staff_modifier_applied',v_travel_red>0,
    'staff_injury_reduction',round(v_travel_red,4),
    'staff_source','travelling_tournament_staff',
    'match_id',p_match_id,
    'competition_id',v_competition_id
  );
end;
$function$;

revoke all on function public.get_tournament_match_injury_risk_v1(uuid,uuid,integer,numeric) from public;
revoke all on function public.get_tournament_match_injury_risk_v1(uuid,uuid,integer,numeric) from anon;
revoke all on function public.get_tournament_match_injury_risk_v1(uuid,uuid,integer,numeric) from authenticated;

create or replace function public.notify_match_injury_risk_if_needed_v1(
  p_player_id uuid,
  p_match_id uuid,
  p_match_minutes integer,
  p_heat_index numeric
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  v_risk:=public.get_tournament_match_injury_risk_v1(
    p_player_id,p_match_id,greatest(0,coalesce(p_match_minutes,0)),greatest(0,coalesce(p_heat_index,0))
  );
  v_level:=v_risk->>'risk_level';

  insert into public.player_injury_risk_events(
    player_id,absolute_day,context,risk_percent,risk_level,reasons
  )
  values(
    p_player_id,v_abs,'match',(v_risk->>'risk_percent')::numeric,v_level,v_risk->'reasons'
  )
  on conflict(player_id,absolute_day,context) do update
    set risk_percent=excluded.risk_percent,
        risk_level=excluded.risk_level,
        reasons=excluded.reasons
  returning id into v_event;

  if v_level in ('elevated','high','very_high')
     and not exists(select 1 from public.player_injury_risk_events where id=v_event and notified) then
    select owner_user_id into v_owner from public.players where id=p_player_id;
    if v_owner is not null then
      perform public.emit_notification_v1(
        v_owner,
        p_player_id,
        'player.injury.risk',
        'Injury risk increased',
        format(
          'Current injury risk is %s (%s%%) for this match. Review fatigue, recovery and workload before play.',
          replace(v_level,'_',' '),
          v_risk->>'risk_percent'
        ),
        '/game/injuries',
        jsonb_build_object(
          'risk',v_risk,
          'context','match',
          'match_id',p_match_id,
          'match_minutes',greatest(0,coalesce(p_match_minutes,0)),
          'heat_index',greatest(0,coalesce(p_heat_index,0)),
          'proactive',true
        ),
        format('injury-risk:%s:%s:match',p_player_id,v_abs)
      );
      update public.player_injury_risk_events set notified=true where id=v_event;
    end if;
  end if;

  return v_risk;
end;
$function$;

create or replace function public.get_tournament_match_health_status_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_player uuid; m public.tournament_matches%rowtype; v_day integer; v_summary jsonb; v_risk jsonb; v_illness jsonb; v_weather jsonb; v_heat numeric:=0; v_fatigue integer:=0; v_concern boolean:=false; v_sim boolean:=false;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into m from public.tournament_matches where id=p_match_id;
  if m.id is null then raise exception 'Match not found.';end if;
  if v_player is distinct from m.player1_id and v_player is distinct from m.player2_id then raise exception 'This is not your match.'; end if;
  v_day:=public.tournament_match_absolute_day_v2(m.id);
  v_summary:=public.get_player_health_summary_v1(v_player,v_day);
  v_weather:=public.calculate_tournament_match_weather_v1(m.id);
  v_heat:=coalesce((v_weather->>'heat_index')::numeric,0);
  v_risk:=public.get_tournament_match_injury_risk_v1(v_player,m.id,coalesce(m.estimated_duration_minutes,90),v_heat);
  v_illness:=public.get_player_illness_risk_v1(v_player);
  select fatigue into v_fatigue from public.player_skills where player_id=v_player;
  select exists(select 1 from public.tournament_match_simulations where match_id=m.id) into v_sim;
  v_concern:=coalesce(v_summary->>'state','healthy')<>'healthy'
    or coalesce(v_fatigue,0)>=65
    or (v_risk->>'risk_level') in('elevated','high','very_high')
    or (v_illness->>'risk_level') in('elevated','high','very_high');
  return jsonb_build_object(
    'match_id',m.id,'match_status',m.status,'player_id',v_player,'match_absolute_day',v_day,
    'health',v_summary,'match_injury_risk',v_risk,'illness_risk',v_illness,'fatigue',v_fatigue,
    'health_concern',v_concern,'simulation_prepared',v_sim,
    'can_surrender',m.status='scheduled' and not v_sim and v_concern,
    'surrender_reason',case
      when m.status<>'scheduled' then 'Match is no longer awaiting play.'
      when v_sim then 'Match simulation has already been prepared.'
      when not v_concern then 'No elevated health concern is currently detected.'
      else null
    end
  );
end;
$function$;

create or replace function public.roll_player_injury_v1(
  p_player_id uuid,
  p_context text,
  p_source_reference_id uuid default null::uuid,
  p_intensity text default null::text,
  p_match_minutes integer default 0,
  p_heat_index numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare d record;v_abs integer;v_risk jsonb;v_pct numeric;v_seed text;v_roll numeric;v_pick numeric;v_total numeric;v_running numeric:=0;c public.injury_catalog%rowtype;v_train integer;v_tour integer;v_rec integer;v_owner uuid;v_id uuid;v_detail jsonb;v_staff jsonb;v_rehab_red numeric:=0;v_return_red numeric:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  if p_source_reference_id is not null and exists(select 1 from public.player_injuries where player_id=p_player_id and source_type=p_context and source_reference_id=p_source_reference_id) then return jsonb_build_object('status','already_processed');end if;

  if lower(coalesce(p_context,''))='match' and p_source_reference_id is not null then
    v_risk:=public.get_tournament_match_injury_risk_v1(
      p_player_id,p_source_reference_id,p_match_minutes,p_heat_index
    );
  else
    v_risk:=public.get_player_injury_risk_v1(
      p_player_id,p_context,p_intensity,p_match_minutes,p_heat_index
    );
  end if;
  v_pct:=(v_risk->>'risk_percent')::numeric;

  v_seed:=p_player_id::text||':'||p_context||':'||coalesce(p_source_reference_id::text,v_abs::text);
  v_roll:=public.match_engine_random_v1(v_seed||':injury',1)*100;
  insert into public.player_injury_risk_events(player_id,absolute_day,context,risk_percent,risk_level,reasons)
  values(p_player_id,v_abs,p_context,v_pct,v_risk->>'risk_level',v_risk->'reasons')
  on conflict(player_id,absolute_day,context) do update
    set risk_percent=excluded.risk_percent,risk_level=excluded.risk_level,reasons=excluded.reasons;

  if v_roll>=v_pct then return jsonb_build_object('status','clear','risk',v_risk,'roll',round(v_roll,2));end if;

  select sum(relative_weight) into v_total from public.injury_catalog where is_active and p_context=any(contexts);
  v_pick:=public.match_engine_random_v1(v_seed||':type',2)*greatest(v_total,1);
  for c in select * from public.injury_catalog where is_active and p_context=any(contexts) order by code loop
    v_running:=v_running+c.relative_weight;
    if v_pick<=v_running then exit;end if;
  end loop;
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

  v_detail:=jsonb_build_object(
    'risk_at_onset',v_risk,'roll',round(v_roll,2),'cause_context',p_context,'intensity',p_intensity,
    'match_minutes',p_match_minutes,'heat_index',p_heat_index,
    'staff_rehabilitation_reduction',round(v_rehab_red,4),
    'staff_return_to_play_reduction',round(v_return_red,4)
  );

  insert into public.player_injuries(
    player_id,injury_code,severity,source_type,source_reference_id,onset_absolute_day,
    training_return_absolute_day,tournament_return_absolute_day,expected_full_recovery_absolute_day,
    status,performance_penalty,aggravation_risk,treatment_code,details
  )
  values(
    p_player_id,c.code,c.severity,p_context,p_source_reference_id,v_abs,
    v_abs+v_train,v_abs+v_tour,v_abs+v_rec,'active',c.base_performance_penalty,
    c.aggravation_risk,c.treatment_code,v_detail
  )
  returning id into v_id;

  select owner_user_id into v_owner from public.players where id=p_player_id;
  if v_owner is not null then
    perform public.emit_notification_v1(
      v_owner,p_player_id,'player.injury.detected','Injury detected',
      format(
        '%s — %s. Training return: %s day%s; tournament return: %s day%s; expected full recovery: %s day%s.',
        c.name,initcap(c.severity),v_train,case when v_train=1 then '' else 's' end,
        v_tour,case when v_tour=1 then '' else 's' end,v_rec,case when v_rec=1 then '' else 's' end
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
    'status','injured','injury_id',v_id,'injury_code',c.code,'injury_name',c.name,'severity',c.severity,
    'training_out_days',v_train,'tournament_out_days',v_tour,'recovery_days',v_rec,'risk',v_risk,
    'staff_rehabilitation_reduction',round(v_rehab_red,4),
    'staff_return_to_play_reduction',round(v_return_red,4)
  );
end;
$function$;

create or replace function public.roll_match_injury_on_completion_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sim public.tournament_match_simulations%rowtype;
  mins integer;
  w jsonb;
  heat numeric:=0;
  v_setback jsonb;
begin
  if new.status<>'completed' or (tg_op='UPDATE' and old.status='completed') then return new;end if;
  if coalesce(new.schedule_reason,'') ilike '%walkover%' then return new;end if;
  select * into sim from public.tournament_match_simulations where match_id=new.id;
  if sim.match_id is null then return new;end if;
  mins:=coalesce((sim.metadata->>'estimated_match_minutes')::integer,90);
  w:=coalesce(sim.metadata->'weather',public.calculate_tournament_match_weather_v1(new.id));
  heat:=coalesce((w->>'heat_index')::numeric,0);

  if new.player1_id is not null then
    v_setback:=public.roll_player_health_setback_v1(new.player1_id,'match',new.id,null,mins,heat);
    if coalesce(v_setback->>'status','')<>'setback' then
      perform public.notify_match_injury_risk_if_needed_v1(new.player1_id,new.id,mins,heat);
      perform public.roll_player_injury_v1(new.player1_id,'match',new.id,null,mins,heat);
    end if;
  end if;

  if new.player2_id is not null then
    v_setback:=public.roll_player_health_setback_v1(new.player2_id,'match',new.id,null,mins,heat);
    if coalesce(v_setback->>'status','')<>'setback' then
      perform public.notify_match_injury_risk_if_needed_v1(new.player2_id,new.id,mins,heat);
      perform public.roll_player_injury_v1(new.player2_id,'match',new.id,null,mins,heat);
    end if;
  end if;

  return new;
end;
$function$;

create or replace function public.apply_travelling_career_manager_sponsor_bonus_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_competition_id uuid;
  v_effects jsonb;
  v_pct numeric:=0;
  v_bonus bigint:=0;
  v_post jsonb;
begin
  if new.category<>'performance_bonus'
     or new.source_type<>'sponsor_objective'
     or new.subcategory='career_manager_travel_bonus'
     or new.amount<=0
     or coalesce(new.metadata->>'competition_id','') !~* '^[0-9a-f-]{36}$' then
    return new;
  end if;

  v_competition_id:=(new.metadata->>'competition_id')::uuid;
  v_effects:=public.get_tournament_staff_effects_v1(new.player_id,v_competition_id,null);
  v_pct:=greatest(0,least(5,coalesce((v_effects->>'commercial_bonus_pct')::numeric,0)));
  if v_pct<=0 then return new; end if;

  v_bonus:=greatest(0,round(new.amount::numeric*v_pct/100.0)::bigint);
  if v_bonus<=0 then return new; end if;

  v_post:=public.post_career_finance_transaction_v1(
    new.player_id,
    v_bonus,
    'performance_bonus',
    'career_manager_travel_bonus',
    format('Career Manager tournament commercial bonus (+%s%%)',round(v_pct,2)),
    'sponsor_objective',
    new.source_id,
    new.idempotency_key||':career-manager-travel',
    coalesce(new.metadata,'{}'::jsonb)||jsonb_build_object(
      'career_manager_travel_bonus',true,
      'career_manager_bonus_percent',round(v_pct,2),
      'base_sponsor_objective_payout',new.amount
    ),
    coalesce(new.is_taxable,false),
    new.game_absolute_day
  );

  return new;
end;
$function$;

drop trigger if exists trg_apply_travelling_career_manager_sponsor_bonus_v1
on public.career_finance_transactions;

create trigger trg_apply_travelling_career_manager_sponsor_bonus_v1
after insert on public.career_finance_transactions
for each row
execute function public.apply_travelling_career_manager_sponsor_bonus_v1();

update public.staff_role_catalog
set effects=effects||jsonb_build_array(
  jsonb_build_object(
    'key','tournament_match_execution',
    'label','Tournament match execution',
    'cadence','Each tournament match when travelling with the player',
    'maximum','+0.75%',
    'note','Uses Tactical Knowledge. Only applies when the Head Coach is selected as travelling staff.'
  )
)
where role='head_coach'
  and not exists(select 1 from jsonb_array_elements(effects) e where e->>'key'='tournament_match_execution');

update public.staff_role_catalog
set effects=effects||jsonb_build_array(
  jsonb_build_object(
    'key','tournament_match_injury_risk',
    'label','Tournament match injury-risk reduction',
    'cadence','Each tournament match when travelling with the player',
    'maximum','-12% relative risk',
    'note','Uses Injury Prevention. Only applies when the Physiotherapist is selected as travelling staff.'
  )
)
where role='physiotherapist'
  and not exists(select 1 from jsonb_array_elements(effects) e where e->>'key'='tournament_match_injury_risk');

update public.staff_role_catalog
set effects=effects||jsonb_build_array(
  jsonb_build_object(
    'key','tournament_pressure_support',
    'label','Tournament pressure-match execution',
    'cadence','Each tournament match when travelling with the player',
    'maximum','+0.50%',
    'note','Uses Pressure Management. Only applies when the Sports Psychologist is selected as travelling staff.'
  )
)
where role='sports_psychologist'
  and not exists(select 1 from jsonb_array_elements(effects) e where e->>'key'='tournament_pressure_support');

update public.staff_role_catalog
set effects=effects||jsonb_build_array(
  jsonb_build_object(
    'key','tournament_tactical_support',
    'label','Tournament tactical preparation',
    'cadence','Each tournament match when travelling with the player',
    'maximum','+0.50% match execution',
    'note','Uses Tactical Analysis and Match Preparation. This is in addition to the analyst opponent-report system.'
  )
)
where role='performance_analyst'
  and not exists(select 1 from jsonb_array_elements(effects) e where e->>'key'='tournament_tactical_support');

update public.staff_role_catalog
set effects=effects||jsonb_build_array(
  jsonb_build_object(
    'key','tournament_commercial_support',
    'label','Tournament sponsor objective payout',
    'cadence','When a tournament-specific sponsor objective is completed while travelling',
    'maximum','+5%',
    'note','Uses Career Management, Negotiation and Sponsorship Network. Only applies when the Career Manager is selected as travelling staff.'
  )
)
where role='agent_manager'
  and not exists(select 1 from jsonb_array_elements(effects) e where e->>'key'='tournament_commercial_support');
