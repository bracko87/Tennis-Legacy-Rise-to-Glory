alter table public.player_travel_legs
  add column if not exists gross_arrival_fatigue smallint,
  add column if not exists travel_day_recovery smallint not null default 0;

comment on column public.player_travel_legs.gross_arrival_fatigue is 'Travel fatigue after travel-class modifier and before the fixed travel-day recovery credit.';
comment on column public.player_travel_legs.travel_day_recovery is 'Recovery credit applied on the travel day before net arrival_fatigue; normally 3, limited by the +1 minimum net-fatigue floor.';
comment on column public.player_travel_legs.arrival_fatigue is 'Net fatigue applied to the player after the travel-day recovery credit.';

-- Existing completed legs remain historical under the rules used when they ran.
update public.player_travel_legs
set gross_arrival_fatigue=coalesce(gross_arrival_fatigue,arrival_fatigue),
    travel_day_recovery=coalesce(travel_day_recovery,0)
where status='completed';

-- Future/planned legs immediately adopt the new model.
update public.player_travel_legs
set gross_arrival_fatigue=coalesce(gross_arrival_fatigue,arrival_fatigue),
    travel_day_recovery=least(3,greatest(0,coalesce(gross_arrival_fatigue,arrival_fatigue)::integer-1))::smallint,
    arrival_fatigue=greatest(1,coalesce(gross_arrival_fatigue,arrival_fatigue)::integer-3)::smallint,
    updated_at=now()
where status='planned';

create or replace function public.regular_training_week_role_v1(p_season integer,p_month smallint,p_day smallint)
returns text
language sql
immutable
set search_path to 'public'
as $function$
  select 'planned_training'::text;
$function$;

comment on function public.regular_training_week_role_v1(integer,smallint,smallint)
is 'Compatibility helper. Normal weekly training no longer creates hidden Active Recovery or Full Rest days; the player explicitly chooses Day Off.';

do $$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.process_regular_training_for_player_v2(uuid,integer,smallint,smallint,text)'::regprocedure) into v_def;

  v_old := $old$if v_training_type='day_off' then
    v_session_role:='user_day_off';
  elsif v_plan_source='weekly_plan' then
    v_session_role:='planned_training';
  elsif v_weekday=6 then
    v_session_role:='active_recovery';
  elsif v_weekday=7 then
    v_session_role:='full_rest';
  else
    v_session_role:='planned_training';
  end if;$old$;
  v_new := $new$if v_training_type='day_off' then
    v_session_role:='user_day_off';
  else
    v_session_role:='planned_training';
  end if;$new$;
  if position(v_old in v_def)=0 then raise exception 'Expected hidden weekly recovery role logic not found.'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old := $old$if v_session_role='user_day_off' then
    v_rest_reduction:=round(12+s.recovery*0.10+s.fitness*0.06+s.fatigue*0.04);
    v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after:=greatest(1,s.sharpness-2)::smallint;
    v_morale_after:=least(100,s.morale+1)::smallint;
    v_focus_after:=least(100,s.focus+1)::smallint;
    v_stored_training_type:='day_off'; v_stored_focus:=null;
  elsif v_session_role='active_recovery' then
    v_rest_reduction:=round(8+s.recovery*0.07+s.fitness*0.03+s.fatigue*0.03);
    v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after:=s.sharpness;
    v_morale_after:=least(100,s.morale+1)::smallint;
    v_focus_after:=least(100,s.focus+1)::smallint;
    v_stored_training_type:='day_off'; v_stored_focus:=null;
  elsif v_session_role='full_rest' then
    v_rest_reduction:=round(15+s.recovery*0.12+s.fitness*0.06+s.fatigue*0.05);
    v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after:=greatest(1,s.sharpness-1)::smallint;
    v_morale_after:=least(100,s.morale+1)::smallint;
    v_focus_after:=least(100,s.focus+1)::smallint;
    v_stored_training_type:='day_off'; v_stored_focus:=null;
  else$old$;
  v_new := $new$if v_session_role='user_day_off' then
    v_rest_reduction:=round(14+s.recovery*0.10+s.fitness*0.05+s.fatigue*0.04);
    v_fatigue_after:=greatest(0,s.fatigue-v_rest_reduction)::smallint;
    v_sharpness_after:=greatest(1,s.sharpness-1)::smallint;
    v_morale_after:=least(100,s.morale+1)::smallint;
    v_focus_after:=least(100,s.focus+1)::smallint;
    v_stored_training_type:='day_off'; v_stored_focus:=null;
  else$new$;
  if position(v_old in v_def)=0 then raise exception 'Expected three-way recovery block not found.'; end if;
  v_def:=replace(v_def,v_old,v_new);
  execute v_def;
end $$;

comment on function public.process_regular_training_for_player_v2(uuid,integer,smallint,smallint,text)
is 'Processes player-controlled regular training. Day Off is the single normal recovery action. There are no hidden Active Recovery or Full Rest weekdays.';

do $$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef('public.get_training_week_planner_v1(smallint)'::regprocedure) into v_def;
  v_old := $old$else
      v_role:=public.regular_training_week_role_v1(d.season,d.month,d.day);
      if v_role in ('active_recovery','full_rest') then
        v_plan_type:='day_off'; v_plan_focus:=null; v_plan_intensity:='standard'; v_plan_source:='automatic_recovery';
      else
        v_plan_type:=v_base_plan.training_type; v_plan_focus:=v_base_plan.focus_attribute; v_plan_intensity:=v_base_plan.intensity; v_plan_source:='default_plan';
      end if;
    end if;$old$;
  v_new := $new$else
      v_plan_type:=v_base_plan.training_type; v_plan_focus:=v_base_plan.focus_attribute; v_plan_intensity:=v_base_plan.intensity; v_plan_source:='default_plan';
      v_role:=case when v_base_plan.training_type='day_off' then 'user_day_off' else 'planned_training' end;
    end if;$new$;
  if position(v_old in v_def)=0 then raise exception 'Expected automatic recovery planner block not found.'; end if;
  v_def:=replace(v_def,v_old,v_new);
  v_def:=replace(v_def,
    '''daily_plan_overrides_default_rhythm'',true,''automatic_daily_processor_compatible'',true',
    '''day_off_is_player_controlled'',true,''automatic_recovery_days'',0,''automatic_daily_processor_compatible'',true'
  );
  execute v_def;
end $$;

create or replace function public.quote_travel_v2(
  p_source_city text,
  p_source_country_code text,
  p_source_latitude double precision,
  p_source_longitude double precision,
  p_destination_city text,
  p_destination_country_code text,
  p_destination_latitude double precision,
  p_destination_longitude double precision,
  p_travel_class text default 'Economy'::text,
  p_trip_mode text default 'one_way'::text
)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  s jsonb; d jsonb; r public.travel_pricing_rules%rowtype; c public.travel_class_rules%rowtype;
  v_band text; v_basis text; v_km numeric; v_base numeric; v_base_cost integer; v_cost_one_way integer; v_total integer;
  v_base_fatigue integer; v_gross_fatigue integer; v_recovery_credit integer; v_fatigue integer; v_hours numeric; v_legs integer;
begin
  if p_trip_mode not in ('one_way','round_trip') then raise exception 'Invalid trip mode.'; end if;
  select * into c from public.travel_class_rules where class_name=p_travel_class;
  if c.class_name is null then raise exception 'Invalid travel class.'; end if;
  s:=public.resolve_travel_location_v1(p_source_city,p_source_country_code,p_source_latitude,p_source_longitude);
  d:=public.resolve_travel_location_v1(p_destination_city,p_destination_country_code,p_destination_latitude,p_destination_longitude);
  if upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,'')) and lower(trim(coalesce(p_source_city,'')))<>'' and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_destination_city,''))) then
    v_band:='same_city'; v_km:=0; v_basis:='exact_city_match';
  elsif upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,'')) then
    v_band:='domestic';
    if s->>'coordinate_basis'='exact' and d->>'coordinate_basis'='exact' then
      v_km:=public.great_circle_km_v1((s->>'latitude')::numeric,(s->>'longitude')::numeric,(d->>'latitude')::numeric,(d->>'longitude')::numeric); v_basis:='exact_coordinates';
    else v_km:=null; v_basis:='same_country_estimate'; end if;
  else
    if (s->>'latitude') is not null and (d->>'latitude') is not null then
      v_km:=public.great_circle_km_v1((s->>'latitude')::numeric,(s->>'longitude')::numeric,(d->>'latitude')::numeric,(d->>'longitude')::numeric);
      v_basis:=case when s->>'coordinate_basis'='exact' and d->>'coordinate_basis'='exact' then 'exact_coordinates' else 'country_reference_distance' end;
    else v_km:=null; v_basis:='continent_fallback'; end if;
    v_band:=case when public.country_continent_v1(upper(p_source_country_code))=public.country_continent_v1(upper(p_destination_country_code)) then 'regional' else 'intercontinental' end;
  end if;
  select * into r from public.travel_pricing_rules where band=v_band;
  if v_km is null then
    v_base_cost:=case v_band when 'same_city' then 20 when 'domestic' then 45 when 'regional' then 120 else 350 end;
    v_base_fatigue:=case v_band when 'same_city' then 1 when 'domestic' then 2 when 'regional' then 4 else 9 end;
  else
    v_base:=r.base_cost_one_way+v_km*r.cost_per_km;
    v_base_cost:=(round((greatest(r.minimum_cost_one_way,least(r.maximum_cost_one_way,v_base)))/10.0)*10)::integer;
    if r.fatigue_distance_step_km is null then v_base_fatigue:=r.base_fatigue;
    else v_base_fatigue:=least(r.maximum_fatigue,greatest(r.base_fatigue,r.base_fatigue+round(v_km/r.fatigue_distance_step_km::numeric)::integer)); end if;
  end if;
  v_cost_one_way:=(round((v_base_cost*c.price_multiplier)/10.0)*10)::integer;
  v_gross_fatigue:=greatest(1,round(v_base_fatigue*c.fatigue_multiplier)::integer);
  v_fatigue:=greatest(1,v_gross_fatigue-3);
  v_recovery_credit:=v_gross_fatigue-v_fatigue;
  v_legs:=case when p_trip_mode='round_trip' then 2 else 1 end;
  v_total:=v_cost_one_way*v_legs;
  v_hours:=case when v_band='same_city' then 0.5 when v_km is null then case v_band when 'domestic' then 2.5 when 'regional' then 4.0 else 10.0 end else round((case when v_band='domestic' then 1.0+v_km/500.0 when v_band='regional' then 1.5+v_km/650.0 else 2.5+v_km/800.0 end)::numeric,1) end;
  return jsonb_build_object(
    'source',s,'destination',d,'distance_km',case when v_km is null then null else v_km::integer end,
    'round_trip_km',case when v_km is null then null else (v_km*2)::integer end,
    'band',v_band,'basis',v_basis,'travel_class',c.class_name,'price_multiplier',c.price_multiplier,'fatigue_multiplier',c.fatigue_multiplier,
    'base_cost_one_way',v_base_cost,'cost_one_way',v_cost_one_way,'cost',v_total,'trip_mode',p_trip_mode,
    'base_arrival_fatigue',v_base_fatigue,'gross_arrival_fatigue',v_gross_fatigue,
    'travel_day_recovery',v_recovery_credit,'travel_day_recovery_rule',3,'minimum_net_fatigue',1,'arrival_fatigue',v_fatigue,
    'estimated_hours_one_way',v_hours,
    'formula',case v_band when 'same_city' then 'Same-city local transfer' when 'domestic' then 'Domestic fare uses distance when exact city coordinates exist; otherwise a $45 one-way estimate' when 'regional' then 'Regional one-way fare = $40 + $0.055 × km, capped $90–$350' else 'Intercontinental one-way fare = $110 + $0.05 × km, capped $250–$1,200' end
  );
end;
$function$;

create or replace function public.insert_planned_travel_leg_v1(p_player_id uuid, p_purpose text, p_source_type text, p_source_city text, p_source_country text, p_source_lat double precision, p_source_lon double precision, p_source_ref text, p_dest_type text, p_dest_city text, p_dest_country text, p_dest_lat double precision, p_dest_lon double precision, p_dest_ref text, p_departure integer, p_arrival integer, p_embedded boolean default false)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare q jsonb;v_id uuid;gd record;v_existing text;v_class text:='Economy';begin
  if upper(coalesce(p_source_country,''))=upper(coalesce(p_dest_country,'')) and lower(trim(coalesce(p_source_city,'')))<>'' and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_dest_city,''))) then return null; end if;
  if p_dest_type='tournament' and coalesce(p_dest_ref,'')~*'^[0-9a-f-]{36}$' then select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_dest_ref::uuid;
  elsif p_source_type='tournament' and coalesce(p_source_ref,'')~*'^[0-9a-f-]{36}$' then select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_source_ref::uuid; end if;
  v_class:=coalesce(v_class,'Economy');
  q:=public.quote_travel_v2(p_source_city,p_source_country,p_source_lat,p_source_lon,p_dest_city,p_dest_country,p_dest_lat,p_dest_lon,v_class,'one_way');
  insert into public.player_travel_legs(
    player_id,purpose,source_location_type,source_city,source_country_code,source_continent,source_latitude,source_longitude,
    destination_location_type,destination_city,destination_country_code,destination_continent,destination_latitude,destination_longitude,
    source_reference_id,destination_reference_id,departure_absolute_day,arrival_absolute_day,distance_km,estimated_cost,
    gross_arrival_fatigue,travel_day_recovery,arrival_fatigue,travel_band,travel_basis,embedded_transition,status,travel_class,
    base_estimated_cost,price_multiplier,base_arrival_fatigue,fatigue_multiplier
  ) values(
    p_player_id,p_purpose,p_source_type,p_source_city,p_source_country,public.country_continent_v1(p_source_country),p_source_lat,p_source_lon,
    p_dest_type,p_dest_city,p_dest_country,public.country_continent_v1(p_dest_country),p_dest_lat,p_dest_lon,p_source_ref,p_dest_ref,
    p_departure,p_arrival,nullif(q->>'distance_km','')::integer,(q->>'cost')::integer,
    (q->>'gross_arrival_fatigue')::smallint,(q->>'travel_day_recovery')::smallint,(q->>'arrival_fatigue')::smallint,
    q->>'band',q->>'basis',p_embedded,'planned',v_class,(q->>'base_cost_one_way')::integer,(q->>'price_multiplier')::numeric,
    (q->>'base_arrival_fatigue')::smallint,(q->>'fatigue_multiplier')::numeric
  ) returning id into v_id;
  if not p_embedded then
    select * into gd from public.absolute_game_day_v1(p_departure);
    select activity_type into v_existing from public.player_daily_activity where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;
    if v_existing is null or v_existing='home' then
      insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note)
      values(p_player_id,gd.season,gd.month,gd.day,'travel','travel_plan',v_id::text,format('Travel to %s',coalesce(p_dest_city,p_dest_country)))
      on conflict(player_id,season,month,day) do update set activity_type='travel',source='travel_plan',reference_id=v_id::text,note=excluded.note,updated_at=now()
      where public.player_daily_activity.effects_applied_at is null and public.player_daily_activity.activity_type='home';
    else update public.player_travel_legs set embedded_transition=true,updated_at=now() where id=v_id; end if;
  end if;
  return v_id;
end;
$function$;

create or replace function public.process_travel_leg_v1(p_leg_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  l public.player_travel_legs%rowtype;
  v_before smallint; v_after smallint; gd record; v_owner uuid; v_finance jsonb:='{}'::jsonb; v_hotel jsonb:='{}'::jsonb;
  v_human boolean:=false; v_comp uuid; v_gross integer; v_recovery integer;
begin
  select * into l from public.player_travel_legs where id=p_leg_id for update;
  if l.id is null then raise exception 'Travel leg not found.'; end if;
  if l.status='completed' then return jsonb_build_object('status','already_processed','travel_leg_id',l.id); end if;
  if l.status='cancelled' then return jsonb_build_object('status','cancelled','travel_leg_id',l.id); end if;
  select owner_user_id,(player_type='human' and owner_user_id is not null) into v_owner,v_human from public.players where id=l.player_id;
  if v_human and coalesce(l.estimated_cost,0)>0 and coalesce(l.purpose,'')<>'training_camp' and coalesce(l.source_location_type,'')<>'training_camp' then
    v_finance:=public.post_career_finance_transaction_v1(l.player_id,-l.estimated_cost,'travel',coalesce(l.purpose,'travel'),
      format('%s → %s · %s',coalesce(l.source_city,l.source_country_code),coalesce(l.destination_city,l.destination_country_code),coalesce(l.travel_class,'Economy')),
      'travel_leg',l.id::text,'travel-leg:'||l.id::text,
      jsonb_build_object('distance_km',l.distance_km,'travel_class',l.travel_class,'purpose',l.purpose,'source_city',l.source_city,'destination_city',l.destination_city),false,l.departure_absolute_day);
  end if;
  v_gross:=coalesce(l.gross_arrival_fatigue,l.arrival_fatigue);
  v_recovery:=coalesce(l.travel_day_recovery,greatest(0,v_gross-l.arrival_fatigue));
  select fatigue into v_before from public.player_skills where player_id=l.player_id for update;
  v_after:=least(100,coalesce(v_before,0)+l.arrival_fatigue)::smallint;
  update public.player_skills set fatigue=v_after,updated_at=now() where player_id=l.player_id;
  update public.player_location_state set current_city=l.destination_city,current_country_code=l.destination_country_code,current_continent=l.destination_continent,current_latitude=l.destination_latitude,current_longitude=l.destination_longitude,location_type=l.destination_location_type,source_reference_id=l.destination_reference_id,location_since_absolute_day=l.arrival_absolute_day,updated_at=now() where player_id=l.player_id;
  update public.player_travel_legs set status='completed',processed_at=now(),updated_at=now() where id=l.id;
  select * into gd from public.absolute_game_day_v1(l.departure_absolute_day);
  update public.player_daily_activity set effects_applied_at=coalesce(effects_applied_at,now()),effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object(
    'travel_leg_id',l.id,'from',jsonb_build_object('city',l.source_city,'country_code',l.source_country_code),'to',jsonb_build_object('city',l.destination_city,'country_code',l.destination_country_code),
    'distance_km',l.distance_km,'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before,'finance',v_finance),updated_at=now()
  where player_id=l.player_id and season=gd.season and month=gd.month and day=gd.day and source='travel_plan' and reference_id=l.id::text;
  if v_human and coalesce(l.destination_location_type,'')='tournament' and l.destination_reference_id is not null then
    begin v_comp:=l.destination_reference_id::uuid; v_hotel:=public.post_tournament_hotel_night_v1(l.player_id,v_comp,l.arrival_absolute_day);
    exception when invalid_text_representation then v_hotel:=jsonb_build_object('status','skipped','reason','invalid_tournament_reference'); end;
  end if;
  perform public.emit_notification_v1(v_owner,l.player_id,'travel.arrived','Travel completed',
    format('You arrived in %s. Gross travel fatigue: +%s. Travel-day rest: -%s. Net fatigue: +%s.',coalesce(l.destination_city,l.destination_country_code),v_gross,v_recovery,l.arrival_fatigue),
    '/game/schedule',jsonb_build_object('travel_leg_id',l.id,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'distance_km',l.distance_km,'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'fatigue_change',l.arrival_fatigue,'finance',v_finance),'travel-arrived:'||l.id::text);
  return jsonb_build_object('status','completed','travel_leg_id',l.id,'distance_km',l.distance_km,'estimated_cost',l.estimated_cost,
    'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'net_travel_fatigue',l.arrival_fatigue,
    'fatigue_before',v_before,'fatigue_after',v_after,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'finance',v_finance,'arrival_hotel',v_hotel);
end;
$function$;

-- Remove the old Fitness Coach Active Recovery benefit. Recovery Knowledge now
-- supports workload management inside the same capped -10% training-fatigue effect.
do $$
declare v_def text;begin
  select pg_get_functiondef('public.get_player_staff_effects_v2(uuid)'::regprocedure) into v_def;
  if position('v_fatigue_red:=0.10*public.staff_effect_factor_v2((r.attributes->>''workload_management'')::numeric);' in v_def)=0 then raise exception 'Expected Fitness Coach fatigue formula not found.'; end if;
  v_def:=replace(v_def,
    'v_fatigue_red:=0.10*public.staff_effect_factor_v2((r.attributes->>''workload_management'')::numeric);',
    'v_fatigue_red:=least(0.10,0.08*public.staff_effect_factor_v2((r.attributes->>''workload_management'')::numeric)+0.02*public.staff_effect_factor_v2((r.attributes->>''recovery_knowledge'')::numeric));'
  );
  v_def:=replace(v_def,
    'v_active_recovery:=1+0.05*public.staff_effect_factor_v2((r.attributes->>''recovery_knowledge'')::numeric);',
    'v_active_recovery:=1;'
  );
  execute v_def;
end $$;

update public.staff_role_catalog
set stacking_rule='Only one Fitness Coach may be active. Training-fatigue reduction applies to training load only and does not alter the fixed travel-day recovery credit or Day Off recovery.',
    vacancy_behavior='Physical training and fatigue still use base game values, but no Fitness Coach physical-development or training-fatigue bonus is applied.',
    attributes='[{"key":"conditioning","label":"Conditioning","description":"Improves physical-development output in physical training camps."},{"key":"physical_development","label":"Physical Development","description":"Drives physical-skill gains in regular planned training."},{"key":"workload_management","label":"Workload Management","description":"Main driver of reduced fatigue gained from planned training."},{"key":"recovery_knowledge","label":"Recovery Knowledge","description":"Supports workload management and contributes to the capped training-fatigue reduction."}]'::jsonb,
    effects='[{"key":"physical_training","label":"Physical training effectiveness","maximum":"+10%","cadence":"Each planned training session"},{"key":"physical_camp","label":"Physical camp effectiveness","maximum":"+8%","cadence":"Each physical-camp development day"},{"key":"training_fatigue","label":"Training fatigue gain","maximum":"-10%","cadence":"Each planned training session","note":"Workload Management is the main contributor; Recovery Knowledge provides the final supporting share."}]'::jsonb
where role='fitness_coach';

update public.staff_role_catalog
set stacking_rule='Only one Physiotherapist may be active. Their recovery effect strengthens player-selected Day Off recovery and does not change the fixed travel-day recovery credit.'
where role='physiotherapist';

do $$
declare v_def text; v_old text;begin
  select pg_get_functiondef('public.get_staff_role_effect_summary_v1(uuid,text)'::regprocedure) into v_def;
  v_old := $old$,
      jsonb_build_object('label','Active-recovery efficiency','current_display',case when v_active then format('+%s%%',round(((e->>'active_recovery_multiplier')::numeric-1)*100,1)) else '+0%' end,'maximum_display','+5%','cadence','Each active-recovery session')$old$;
  if position(v_old in v_def)=0 then raise exception 'Expected Active Recovery staff summary effect not found.'; end if;
  v_def:=replace(v_def,v_old,'');
  v_def:=replace(v_def,'''cadence'',''Recovery/rest sessions''','''cadence'',''Player-selected Day Off''');
  execute v_def;
end $$;

do $$
declare v_def text;begin
  select pg_get_functiondef('public.get_training_dashboard_v1()'::regprocedure) into v_def;
  v_def:=replace(v_def,'''travel_fatigue_only'',true','''travel_fatigue_only'',false,''travel_day_recovery_offset'',3');
  v_def:=replace(v_def,
    '''weekly_rhythm'',jsonb_build_object(''development_days'',5,''active_recovery_days'',1,''full_rest_days'',1)',
    '''weekly_rhythm'',jsonb_build_object(''automatic_recovery_days'',0,''day_off_user_controlled'',true,''active_recovery_days'',0,''full_rest_days'',0)'
  );
  execute v_def;
end $$;