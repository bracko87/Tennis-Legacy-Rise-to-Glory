-- Tournament preparation: make travelling staff provide real tournament effects.
-- Staff who stay home no longer provide tournament-match bonuses through the preparation flow.

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
    v_value:='No direct tournament performance effect';
    v_has_effect:=false;

    if r.role='head_coach' then
      v_effect:=0.0075*public.staff_effect_factor_v2((r.attributes->>'tactical_knowledge')::numeric);
      v_match_raw:=v_match_raw+v_effect;
      v_label:='Match execution';
      v_value:='+'||round(v_effect*100,2)::text||'%';
      v_has_effect:=v_effect>0;
    elsif r.role='fitness_coach' then
      v_effect:=least(
        0.10,
        0.08*public.staff_effect_factor_v2((r.attributes->>'workload_management')::numeric)
        +0.02*public.staff_effect_factor_v2((r.attributes->>'recovery_knowledge')::numeric)
      );
      v_fatigue_reduction:=greatest(v_fatigue_reduction,v_effect);
      v_label:='Match fatigue gain';
      v_value:='-'||round(v_effect*100,2)::text||'%';
      v_has_effect:=v_effect>0;
    elsif r.role='physiotherapist' then
      v_label:='Recovery and injury care';
      v_value:='No additional match bonus from travel';
    elsif r.role='sports_psychologist' then
      v_effect:=0.005*public.staff_effect_factor_v2((r.attributes->>'pressure_management')::numeric);
      v_match_raw:=v_match_raw+v_effect;
      v_label:='Pressure-match execution';
      v_value:='+'||round(v_effect*100,2)::text||'%';
      v_has_effect:=v_effect>0;
    elsif r.role='performance_analyst' then
      v_label:='Opponent intelligence';
      v_value:='No direct rating bonus; scouting support remains report-based';
    elsif r.role='agent_manager' then
      v_label:='Career management';
      v_value:='No tournament performance bonus';
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
    'staff',v_items
  );
end;
$function$;

revoke all on function public.get_tournament_staff_effects_v1(uuid,uuid,uuid[]) from public;
revoke all on function public.get_tournament_staff_effects_v1(uuid,uuid,uuid[]) from anon;
revoke all on function public.get_tournament_staff_effects_v1(uuid,uuid,uuid[]) from authenticated;

create or replace function public.quote_tournament_preparation_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_player_travel_class text default 'Economy'::text,
  p_staff_travel_class text default 'Economy'::text,
  p_hotel_tier text default 'Standard'::text,
  p_selected_staff_contract_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_city text;
  v_country text;
  v_lat double precision;
  v_lon double precision;
  v_season integer;
  v_min_week integer;
  v_max_week integer;
  v_start_abs integer;
  v_end_abs integer;
  v_draw_start integer;
  v_first_match integer;
  v_arrival_abs integer;
  v_min_nights integer;
  v_max_nights integer;
  v_origin jsonb;
  v_travel jsonb;
  v_staff_travel jsonb;
  v_hotel public.travel_stay_tiers%rowtype;
  v_hotel_min jsonb;
  v_hotel_max jsonb;
  v_staff_count integer;
  v_invalid integer;
  v_draw_type text:='main_draw';
  v_party integer;
  v_player_cost integer;
  v_staff_cost integer;
  v_total_min integer;
  v_total_max integer;
  v_staff_effects jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where id=p_player_id and owner_user_id=v_uid;
  if v_player.id is null then raise exception 'Player access denied.'; end if;

  select ts.city,ts.country_code,ts.latitude,ts.longitude,te.season_number,min(ss.season_week),max(ss.season_week)
  into v_city,v_country,v_lat,v_lon,v_season,v_min_week,v_max_week
  from public.tournament_world_competitions wc
  join public.tournament_editions te on te.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=te.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
  where wc.id=p_competition_id
    and wc.world=v_player.world
    and wc.status<>'canceled'
    and te.status<>'canceled'
  group by ts.city,ts.country_code,ts.latitude,ts.longitude,te.season_number;

  if v_city is null then raise exception 'Tournament unavailable.'; end if;

  select coalesce(e.draw_type,'main_draw')
  into v_draw_type
  from public.tournament_entries e
  where e.player_id=p_player_id and e.competition_id=p_competition_id
  limit 1;
  v_draw_type:=coalesce(v_draw_type,'main_draw');

  v_start_abs:=((v_season-1)*366)+2+((v_min_week-1)*7);
  v_end_abs:=((v_season-1)*366)+2+((v_max_week-1)*7)+6;

  select min(((v_season-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))
  into v_draw_start
  from public.tournament_matches m
  where m.competition_id=p_competition_id and m.draw_type=v_draw_type;

  select min(((v_season-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))
  into v_first_match
  from public.tournament_matches m
  where m.competition_id=p_competition_id
    and (m.player1_id=p_player_id or m.player2_id=p_player_id);

  v_draw_start:=coalesce(v_draw_start,v_start_abs);
  v_arrival_abs:=v_draw_start-1;
  v_min_nights:=greatest(2,coalesce(v_first_match,v_draw_start)-v_arrival_abs+1);
  v_max_nights:=greatest(v_min_nights,v_end_abs-v_arrival_abs+1);

  v_origin:=public.resolve_player_origin_before_day_v1(p_player_id,v_arrival_abs);
  v_travel:=public.quote_travel_v2(
    v_origin->>'city',v_origin->>'country_code',
    nullif(v_origin->>'latitude','')::double precision,
    nullif(v_origin->>'longitude','')::double precision,
    v_city,v_country,v_lat,v_lon,p_player_travel_class,'round_trip'
  );

  select count(*) into v_staff_count
  from unnest(coalesce(p_selected_staff_contract_ids,'{}'::uuid[]));

  select count(*) into v_invalid
  from unnest(coalesce(p_selected_staff_contract_ids,'{}'::uuid[])) x
  left join public.player_staff_contracts c
    on c.id=x and c.player_id=p_player_id and c.status='active'
  where c.id is null;

  if v_invalid>0 then raise exception 'One or more selected staff contracts are unavailable.'; end if;
  if v_staff_count>6 then raise exception 'A maximum of six staff members can travel.'; end if;

  v_staff_effects:=public.get_tournament_staff_effects_v1(
    p_player_id,p_competition_id,coalesce(p_selected_staff_contract_ids,'{}'::uuid[])
  );

  v_staff_travel:=public.quote_travel_v2(
    v_origin->>'city',v_origin->>'country_code',
    nullif(v_origin->>'latitude','')::double precision,
    nullif(v_origin->>'longitude','')::double precision,
    v_city,v_country,v_lat,v_lon,p_staff_travel_class,'round_trip'
  );

  select * into v_hotel from public.travel_stay_tiers where tier_name=p_hotel_tier;
  if v_hotel.tier_name is null then raise exception 'Invalid hotel tier.'; end if;

  v_party:=1+v_staff_count;
  v_hotel_min:=public.quote_accommodation_v1(v_city,v_country,v_hotel.base_nightly_cost,v_min_nights,v_party,'night');
  v_hotel_max:=public.quote_accommodation_v1(v_city,v_country,v_hotel.base_nightly_cost,v_max_nights,v_party,'night');
  v_player_cost:=(v_travel->>'cost')::integer;
  v_staff_cost:=(v_staff_travel->>'cost')::integer*v_staff_count;
  v_total_min:=v_player_cost+v_staff_cost+(v_hotel_min->>'total')::integer;
  v_total_max:=v_player_cost+v_staff_cost+(v_hotel_max->>'total')::integer;

  return jsonb_build_object(
    'engine','universal_travel_stay_v1',
    'origin',v_origin,
    'destination',jsonb_build_object('city',v_city,'country_code',v_country),
    'draw_type',v_draw_type,
    'arrival_absolute_day',v_arrival_abs,
    'minimum_nights',v_min_nights,
    'maximum_nights',v_max_nights,
    'party_size',v_party,
    'staff_count',v_staff_count,
    'player_travel',v_travel,
    'staff_travel',v_staff_travel,
    'player_travel_cost',v_player_cost,
    'staff_travel_cost',v_staff_cost,
    'staff_effects',v_staff_effects,
    'hotel',jsonb_build_object(
      'tier',v_hotel.tier_name,
      'label',v_hotel.label,
      'base_nightly_cost',v_hotel.base_nightly_cost,
      'recovery_support_pct',v_hotel.recovery_support_pct,
      'minimum',v_hotel_min,
      'maximum',v_hotel_max
    ),
    'minimum_total',v_total_min,
    'maximum_total',v_total_max
  );
end;
$function$;

create or replace function public.get_match_engine_profile_for_match_v2(
  p_player_id uuid,
  p_surface text,
  p_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  b jsonb;
  e jsonb;
  eq jsonb;
  m numeric:=1;
  eq_serve numeric:=0;
  eq_return numeric:=0;
  eq_rally numeric:=0;
  eq_net numeric:=0;
  climate numeric:=0;
  temp numeric;
  eq_avg numeric:=0;
  v_competition_id uuid;
begin
  b:=public.get_match_engine_profile_for_match_base_v2(p_player_id,p_surface,p_match_id);
  eq:=public.get_equipment_match_modifiers_for_match_v3(p_player_id,p_surface,p_match_id);
  begin
    temp:=nullif(b->'weather'->>'temperature_c','')::numeric;
  exception when others then
    temp:=null;
  end;

  if temp is not null and temp>=28 then
    climate:=coalesce((eq->>'heat_resistance_pct')::numeric,0)*.35;
  elsif temp is not null and temp<=12 then
    climate:=coalesce((eq->>'cold_resistance_pct')::numeric,0)*.35;
  end if;

  eq_serve:=greatest(-4,least(4,coalesce((eq->>'serve_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.10));
  eq_return:=greatest(-4,least(4,coalesce((eq->>'return_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.12+climate));
  eq_rally:=greatest(-4,least(4,coalesce((eq->>'rally_pct')::numeric,0)+coalesce((eq->>'stamina_pct')::numeric,0)*.22+climate));
  eq_net:=greatest(-4,least(4,coalesce((eq->>'net_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.10));
  eq_avg:=(eq_serve+eq_return+eq_rally+eq_net)/4.0;

  b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*(1+eq_serve/100.0),2)));
  b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*(1+eq_return/100.0),2)));
  b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*(1+eq_rally/100.0),2)));
  b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*(1+eq_net/100.0),2)));
  b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*(1+eq_avg/100.0),2)));

  select competition_id into v_competition_id
  from public.tournament_matches
  where id=p_match_id;

  if v_competition_id is not null then
    e:=public.get_tournament_staff_effects_v1(p_player_id,v_competition_id,null);
  else
    e:=jsonb_build_object('match_staff_multiplier',1,'match_execution_bonus_pct',0);
  end if;

  m:=greatest(1,least(1.02,coalesce((e->>'match_staff_multiplier')::numeric,1)));
  if m>1 then
    b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*m,2)));
  end if;

  return b||jsonb_build_object(
    'equipment_support',eq||jsonb_build_object(
      'effective_serve_pct',round(eq_serve,2),
      'effective_return_pct',round(eq_return,2),
      'effective_rally_pct',round(eq_rally,2),
      'effective_net_pct',round(eq_net,2),
      'climate_support_pct',round(climate,2)
    ),
    'staff_support',jsonb_build_object(
      'source','travelling_tournament_staff',
      'match_multiplier',round(m,4),
      'bonus_percent',round((m-1)*100,2),
      'global_cap_percent',2.0
    )
  );
end;
$function$;

create or replace function public.apply_match_condition_effects_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  sim public.tournament_match_simulations%rowtype;
  v_surface text:='hard';
  v_minutes integer;
  v_sets smallint;
  v_games integer;
  v_player uuid;
  s public.player_skills%rowtype;
  v_gain integer;
  v_staff jsonb;
  v_staff_red numeric:=0;
  v_fatigue_after smallint;
  v_sharp_after smallint;
  v_morale_after smallint;
  v_conf_after smallint;
  v_focus_after smallint;
  v_win boolean;
begin
  if new.status<>'completed' or new.winner_id is null or (tg_op='UPDATE' and old.status='completed') then return new;end if;
  select * into sim from public.tournament_match_simulations where match_id=new.id;
  if sim.match_id is null then return new;end if;

  select coalesce(ts.surface,'hard')
  into v_surface
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;

  v_minutes:=greatest(20,least(480,coalesce((sim.metadata->>'estimated_match_minutes')::integer,90)));
  v_sets:=greatest(2,least(5,jsonb_array_length(sim.sets_payload)))::smallint;
  v_games:=greatest(6,least(99,coalesce(sim.total_games,20)));

  foreach v_player in array array[new.player1_id,new.player2_id] loop
    if v_player is null or exists(
      select 1 from public.player_match_condition_events
      where match_id=new.id and player_id=v_player
    ) then continue;end if;

    select * into s from public.player_skills where player_id=v_player for update;
    if s.player_id is null then continue;end if;

    v_win:=v_player=new.winner_id;
    v_gain:=public.calculate_match_fatigue_v2(v_minutes,v_sets,v_games,s.fitness,s.stamina,s.recovery,v_surface);

    v_staff:=public.get_tournament_staff_effects_v1(v_player,new.competition_id,null);
    v_staff_red:=greatest(0,least(0.10,coalesce((v_staff->>'match_fatigue_reduction')::numeric,0)));
    if v_staff_red>0 then
      v_gain:=greatest(0,round(v_gain*(1-v_staff_red))::integer);
    end if;

    v_fatigue_after:=least(100,s.fatigue+v_gain)::smallint;
    v_sharp_after:=least(100,s.sharpness+case when v_minutes>=150 then 1 else 2 end)::smallint;
    v_morale_after:=greatest(1,least(100,s.morale+case when v_win then 1 else -1 end))::smallint;
    v_conf_after:=greatest(1,least(100,s.confidence+case when v_win then 3 else -1 end))::smallint;
    v_focus_after:=greatest(1,least(100,s.focus+case when v_win and v_minutes<150 then 1 when v_minutes>=180 then -1 else 0 end))::smallint;

    update public.player_skills
    set fatigue=v_fatigue_after,
        sharpness=v_sharp_after,
        morale=v_morale_after,
        confidence=v_conf_after,
        focus=v_focus_after,
        updated_at=now()
    where player_id=v_player;

    insert into public.player_match_condition_events(
      match_id,player_id,outcome,surface,estimated_match_minutes,sets_played,games_played,
      fatigue_before,fatigue_after,sharpness_before,sharpness_after,
      morale_before,morale_after,confidence_before,confidence_after,focus_before,focus_after
    )
    values(
      new.id,v_player,case when v_win then 'win' else 'loss' end,lower(v_surface),v_minutes,v_sets,v_games,
      s.fatigue,v_fatigue_after,s.sharpness,v_sharp_after,
      s.morale,v_morale_after,s.confidence,v_conf_after,s.focus,v_focus_after
    );
  end loop;

  return new;
end;
$function$;

update public.staff_role_catalog
set effects=effects||jsonb_build_array(
  jsonb_build_object(
    'key','tournament_match_fatigue',
    'label','Tournament match fatigue gain',
    'cadence','Each tournament match when travelling with the player',
    'maximum','-10%',
    'note','Uses Workload Management with Recovery Knowledge support. The effect applies only when the Fitness Coach is selected as travelling staff for that tournament.'
  )
)
where role='fitness_coach'
  and not exists (
    select 1
    from jsonb_array_elements(effects) e
    where e->>'key'='tournament_match_fatigue'
  );
