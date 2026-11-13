-- Direct tournament transfer v2: route comparison, hotel nights and morale.
-- No existing player record is altered during installation.
create table if not exists public.player_direct_transfer_morale_state (
  player_id uuid primary key references public.players(id) on delete cascade,
  applied_penalty smallint not null default 0 check(applied_penalty between 0 and 2),
  last_processed_absolute_day integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.player_direct_transfer_morale_state enable row level security;
revoke all on public.player_direct_transfer_morale_state from public,anon,authenticated;

create or replace function public.apply_direct_transfer_morale_v1(
  p_player_id uuid, p_absolute_day integer
) returns jsonb language plpgsql security definer
set search_path='public','pg_temp'
as $function$
declare
  v_previous integer:=0;v_last_day integer:=0;v_desired integer:=0;v_actual integer:=0;
  v_last_home_day integer;v_away_start integer;v_direct_depart integer;
  v_location public.player_location_state%rowtype;
  v_morale integer;v_updated integer;v_new_applied integer;v_at_home boolean:=false;
begin
  if not exists(select 1 from public.players p
    where p.id=p_player_id and p.player_type='human' and p.owner_user_id is not null)
  then return jsonb_build_object('status','not_human'); end if;
  insert into public.player_direct_transfer_morale_state(player_id)
  values(p_player_id) on conflict do nothing;
  select applied_penalty,last_processed_absolute_day into v_previous,v_last_day
  from public.player_direct_transfer_morale_state
  where player_id=p_player_id for update;
  if p_absolute_day<=v_last_day then
    return jsonb_build_object('status','already_processed','applied_penalty',v_previous);
  end if;
  select * into v_location from public.player_location_state where player_id=p_player_id;
  v_at_home:=coalesce(v_location.location_type='home',true);
  if v_at_home then
    -- Restore a maximum of one morale point per genuine game day at home.
    v_desired:=greatest(0,v_previous-1);
  else
    select max(l.arrival_absolute_day) into v_last_home_day
    from public.player_travel_legs l
    where l.player_id=p_player_id and l.status='completed'
      and l.destination_location_type='home' and l.arrival_absolute_day<=p_absolute_day;
    select min(l.departure_absolute_day) into v_direct_depart
    from public.player_travel_legs l
    join public.player_tournament_transfer_preferences pref
      on pref.player_id=l.player_id and pref.source_competition_id::text=l.source_reference_id
      and pref.competition_id::text=l.destination_reference_id and pref.route_choice='direct'
    where l.player_id=p_player_id and l.status='completed'
      and l.source_location_type='tournament' and l.destination_location_type='tournament'
      and l.arrival_absolute_day<=p_absolute_day
      and (v_last_home_day is null or l.arrival_absolute_day>v_last_home_day);
    if v_direct_depart is not null then
      select min(l.departure_absolute_day) into v_away_start
      from public.player_travel_legs l
      where l.player_id=p_player_id and l.status='completed'
        and l.source_location_type='home'
        and l.destination_location_type<>'home'
        and l.departure_absolute_day<=p_absolute_day
        and (v_last_home_day is null or l.departure_absolute_day>v_last_home_day);
      v_away_start:=coalesce(v_away_start,v_direct_depart);
      v_desired:=case when p_absolute_day-v_away_start+1>=15 then 2
                      when p_absolute_day-v_away_start+1>=8 then 1 else 0 end;
    else
      v_desired:=0;
    end if;
  end if;
  select morale into v_morale from public.player_skills where player_id=p_player_id for update;
  if v_morale is null then return jsonb_build_object('status','no_skills'); end if;
  v_updated:=greatest(1,least(100,v_morale+v_previous-v_desired));
  v_new_applied:=greatest(0,least(2,v_previous+v_morale-v_updated));
  update public.player_skills set morale=v_updated,updated_at=now()
  where player_id=p_player_id and morale<>v_updated;
  update public.player_direct_transfer_morale_state
  set applied_penalty=v_new_applied,last_processed_absolute_day=p_absolute_day,updated_at=now()
  where player_id=p_player_id;
  return jsonb_build_object('status','processed','morale_before',v_morale,
    'morale_after',v_updated,'applied_penalty',v_new_applied,'days_away',
    case when v_at_home or v_away_start is null then 0 else p_absolute_day-v_away_start+1 end);
end;
$function$;
revoke all on function public.apply_direct_transfer_morale_v1(uuid,integer) from public,anon,authenticated;

create or replace function public.quote_tournament_transfer_options_v1(
  p_player_id uuid, p_competition_id uuid,
  p_player_travel_class text default 'Economy',
  p_staff_travel_class text default 'Economy',
  p_hotel_tier text default 'Standard',
  p_selected_staff_contract_ids uuid[] default '{}'::uuid[]
) returns jsonb language plpgsql stable security definer
set search_path='public','pg_temp'
as $function$
declare
  v_context jsonb;
  v_source record;v_target record;
  v_home jsonb;v_src jsonb;v_dest jsonb;
  v_direct jsonb;v_staff jsonb;v_to_home jsonb;v_home_to_dest jsonb;
  v_staff_to_home jsonb;v_staff_home_dest jsonb;v_hotel jsonb;v_hotel_tier public.travel_stay_tiers%rowtype;
  v_jet jsonb:='{}'::jsonb;v_mode text;v_asset_id uuid;
  v_staff_count integer:=0;v_leg_cost integer:=0;v_home_cost integer:=0;
  v_extra_nights integer:=0;v_hotel_extra integer:=0;v_hours numeric:=0;
  v_arrival_day integer:=0;v_net_fatigue integer:=0;v_direct_mode text:='commercial';
begin
  v_context:=public.get_tournament_transfer_preference_v1(p_player_id,p_competition_id);
  if not coalesce((v_context->>'available')::boolean,false) then
    return v_context||jsonb_build_object('quote_available',false);
  end if;
  -- Validation of classes, hotel tier and staff authorization uses the existing quote contract.
  perform public.quote_tournament_preparation_v1(p_player_id,p_competition_id,
    p_player_travel_class,p_staff_travel_class,p_hotel_tier,p_selected_staff_contract_ids);
  select * into v_source from public.player_commitment_locations_v1(p_player_id)
    where commitment_type='tournament'
      and reference_id=v_context->>'source_competition_id' limit 1;
  select * into v_target from public.player_commitment_locations_v1(p_player_id)
    where commitment_type='tournament'
      and reference_id=p_competition_id::text limit 1;
  if v_source.reference_id is null or v_target.reference_id is null then
    return jsonb_build_object('quote_available',false,'reason','commitment_not_found');
  end if;
  v_staff_count:=coalesce(cardinality(p_selected_staff_contract_ids),0);
  v_home:=public.get_player_home_base_v1(p_player_id);
  v_src:=public.resolve_location_coordinates_v1(v_source.city,v_source.country_code,v_source.latitude,v_source.longitude);
  v_dest:=public.resolve_location_coordinates_v1(v_target.city,v_target.country_code,v_target.latitude,v_target.longitude);
  v_direct:=public.quote_travel_v2(v_source.city,v_source.country_code,
    nullif(v_src->>'latitude','')::double precision,nullif(v_src->>'longitude','')::double precision,
    v_target.city,v_target.country_code,
    nullif(v_dest->>'latitude','')::double precision,nullif(v_dest->>'longitude','')::double precision,
    p_player_travel_class,'one_way');
  v_staff:=public.quote_travel_v2(v_source.city,v_source.country_code,
    nullif(v_src->>'latitude','')::double precision,nullif(v_src->>'longitude','')::double precision,
    v_target.city,v_target.country_code,
    nullif(v_dest->>'latitude','')::double precision,nullif(v_dest->>'longitude','')::double precision,
    p_staff_travel_class,'one_way');
  v_to_home:=public.quote_travel_v2(v_source.city,v_source.country_code,null,null,
    v_home->>'city',v_home->>'country_code',null,null,p_player_travel_class,'one_way');
  v_home_to_dest:=public.quote_travel_v2(v_home->>'city',v_home->>'country_code',null,null,
    v_target.city,v_target.country_code,null,null,p_player_travel_class,'one_way');
  v_staff_to_home:=public.quote_travel_v2(v_source.city,v_source.country_code,null,null,
    v_home->>'city',v_home->>'country_code',null,null,p_staff_travel_class,'one_way');
  v_staff_home_dest:=public.quote_travel_v2(v_home->>'city',v_home->>'country_code',null,null,
    v_target.city,v_target.country_code,null,null,p_staff_travel_class,'one_way');
  v_home_cost:=coalesce((v_to_home->>'cost')::integer,0)+coalesce((v_home_to_dest->>'cost')::integer,0)
    +v_staff_count*(coalesce((v_staff_to_home->>'cost')::integer,0)+coalesce((v_staff_home_dest->>'cost')::integer,0));
  v_leg_cost:=coalesce((v_direct->>'cost')::integer,0)
    +v_staff_count*coalesce((v_staff->>'cost')::integer,0);
  v_hours:=coalesce((v_direct->>'estimated_hours_one_way')::numeric,0);
  v_net_fatigue:=coalesce((v_direct->>'arrival_fatigue')::integer,0);
  select travel_mode,owned_jet_asset_id into v_mode,v_asset_id
  from public.player_tournament_travel_selection
  where player_id=p_player_id and competition_id=p_competition_id;
  if v_mode is null then
    select case when preferred_travel_mode='best_owned_jet' then 'private_jet'
                else 'commercial' end into v_mode
    from public.player_lifestyle_state where player_id=p_player_id;
  end if;
  if v_mode='private_jet' then
    v_jet:=public.quote_private_jet_leg_v1(p_player_id,v_source.city,v_source.country_code,
      v_target.city,v_target.country_code,coalesce((v_direct->>'distance_km')::integer,0),
      v_staff_count,v_asset_id,v_source.end_absolute_day+1);
    if coalesce((v_jet->>'active')::boolean,false) then
      v_leg_cost:=(v_jet->>'cost_one_way')::integer;
      v_hours:=coalesce((v_jet->>'estimated_hours')::numeric,v_hours);
      v_net_fatigue:=greatest(1,round(v_net_fatigue::numeric*
        (10000-coalesce((v_jet->>'reduction_bps')::integer,0))/10000)::integer);
      v_direct_mode:='private_jet';
    end if;
  end if;
  select * into v_hotel_tier from public.travel_stay_tiers where tier_name=p_hotel_tier;
  v_arrival_day:=v_source.end_absolute_day+1+greatest(0,floor((9+v_hours)/24)::integer);
  v_extra_nights:=greatest(0,v_target.start_absolute_day-v_arrival_day);
  if v_extra_nights>0 then
    v_hotel:=public.quote_accommodation_v1(v_target.city,v_target.country_code,
      v_hotel_tier.base_nightly_cost,v_extra_nights,1+v_staff_count,'night');
    v_hotel_extra:=coalesce((v_hotel->>'total')::integer,0);
  end if;
  return jsonb_build_object(
    'quote_available',true,'source_city',v_source.city,'destination_city',v_target.city,
    'home_city',v_home->>'city',
    'direct_distance_km',coalesce((v_direct->>'distance_km')::integer,0),
    'direct_flight_mode',v_direct_mode,
    'direct_flight_cost',v_leg_cost,
    'commercial_via_home_cost',v_home_cost,
    'extra_hotel_nights',v_extra_nights,
    'extra_hotel_cost',v_hotel_extra,
    'direct_total_cost',v_leg_cost+v_hotel_extra,
    'estimated_arrival_absolute_day',v_arrival_day,
    'estimated_departure_absolute_day',v_source.end_absolute_day+1,
    'estimated_flight_hours',v_hours,
    'arrival_fatigue',v_net_fatigue,
    'jet',v_jet,
    'comparison_is_commercial_only',true,
    'potential_tight_connection',v_arrival_day>=v_target.start_absolute_day,
    'estimate_changes_after_last_match',true
  );
end;
$function$;
revoke all on function public.quote_tournament_transfer_options_v1(uuid,uuid,text,text,text,uuid[]) from public,anon;
grant execute on function public.quote_tournament_transfer_options_v1(uuid,uuid,text,text,text,uuid[]) to authenticated;

CREATE OR REPLACE FUNCTION public.process_tournament_hotel_day_v1(p_player_id uuid, p_absolute_day integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c record; v_result jsonb:='{}'::jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id and player_type='human' and owner_user_id is not null) then
    return jsonb_build_object('status','skipped');
  end if;
  select * into c from public.player_commitment_locations_v1(p_player_id)
  where commitment_type='tournament' and p_absolute_day between start_absolute_day and end_absolute_day
  order by start_absolute_day limit 1;
  if c.reference_id is null then
    -- A direct flight may arrive several days before the draw starts.
    -- Charge these nights exactly once by the existing idempotent hotel ledger.
    select l.destination_reference_id into c
    from public.player_travel_legs l
    join public.player_tournament_transfer_preferences pref
      on pref.player_id=l.player_id and pref.competition_id::text=l.destination_reference_id
      and pref.source_competition_id::text=l.source_reference_id and pref.route_choice='direct'
    join lateral public.player_commitment_locations_v1(p_player_id) target
      on target.commitment_type='tournament'
      and target.reference_id=l.destination_reference_id
    where l.player_id=p_player_id and l.status='completed'
      and l.source_location_type='tournament' and l.destination_location_type='tournament'
      and l.arrival_absolute_day<=p_absolute_day
      and p_absolute_day<target.start_absolute_day
      and not exists (
        select 1 from public.player_travel_legs away
        where away.player_id=p_player_id and away.status='completed'
          and away.source_reference_id=l.destination_reference_id
          and away.departure_absolute_day<=p_absolute_day
          and away.arrival_absolute_day>=l.arrival_absolute_day
      )
    order by l.arrival_absolute_day desc limit 1;
    if c.destination_reference_id is null then
      return jsonb_build_object('status','no_tournament');
    end if;
    v_result:=public.post_tournament_hotel_night_v1(p_player_id,c.destination_reference_id::uuid,p_absolute_day);
    return v_result;
  end if;
  v_result:=public.post_tournament_hotel_night_v1(p_player_id,c.reference_id::uuid,p_absolute_day);
  return v_result;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.process_player_daily_activity_v1(p_player_id uuid, p_season integer, p_month smallint, p_day smallint, p_processed_by text DEFAULT 'daily_engine'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_activity text; v_row public.player_daily_activity%rowtype; v_abs integer; v_travel jsonb; v_hotel jsonb; v_tax jsonb; v_health jsonb:='{}'::jsonb; v_is_human boolean:=false; v_summary jsonb;
begin
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);
  v_tax:=public.process_due_career_tax_v1(p_player_id,v_abs);
  v_travel:=public.process_due_travel_legs_v1(p_player_id,v_abs);
  v_hotel:=public.process_tournament_hotel_day_v1(p_player_id,v_abs);
  select (player_type='human' and owner_user_id is not null) into v_is_human from public.players where id=p_player_id;
  if v_is_human then
    perform public.apply_direct_transfer_morale_v1(p_player_id,v_abs);
    v_health:=public.roll_player_illness_v1(p_player_id);
  end if;
  select * into v_row from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day for update;
  v_activity:=coalesce(v_row.activity_type,'home');
  if v_activity='home' and public.player_has_confirmed_tournament_match_on_day_v1(p_player_id,v_abs) then v_activity:='tournament'; end if;

  if v_activity in ('home','training_camp') and public.player_training_blocked_by_health_v1(p_player_id,v_abs) then
    v_summary:=public.get_player_health_summary_v1(p_player_id,v_abs);
    update public.player_daily_activity
      set activity_type='injured',effects_applied_at=coalesce(effects_applied_at,now()),
          effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object('health_blocked',true,'health',v_summary,'planned_activity',v_activity),updated_at=now()
    where player_id=p_player_id and season=p_season and month=p_month and day=p_day;
    return jsonb_build_object('status','health_blocked','activity_type','injured','planned_activity',v_activity,'health',v_summary,'tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'health_processing',v_health,'reason','Medical restriction blocks training on this game day.');
  end if;

  if v_activity='home' then return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'health_processing',v_health); end if;
  if v_activity='travel' then return jsonb_build_object('status','completed','activity_type','travel','tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'health_processing',v_health,'effect_summary',v_row.effect_summary); end if;
  if v_activity='training_camp' then return public.process_training_camp_day_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'health_processing',v_health); end if;
  return jsonb_build_object('status','delegated','activity_type',v_activity,'tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'health_processing',v_health,'reason',case v_activity when 'tournament' then 'Confirmed tournament match; the match engine owns this day and regular training is blocked.' when 'injured' then 'Health/recovery engine owns this day; regular training is blocked.' else 'Regular training is blocked.' end);
end;
$function$
;
