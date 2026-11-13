-- Direct journey flight mode and timing: always quote the actual transfer leg.
-- The source functions are retained for non-direct tournament journeys.
CREATE OR REPLACE FUNCTION public.quote_my_private_life_jet_v1(p_competition_id uuid, p_owned_jet_asset_id uuid, p_staff_count integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_player uuid;v_base jsonb;v_plan public.player_tournament_preparation_plans%rowtype;
 v_staff integer;v_context jsonb;v_src record;v_dst record;v_leg jsonb;
begin
 v_player:=public.private_life_current_player_v1();
 if not exists(select 1 from public.tournament_entries e
   where e.player_id=v_player and e.competition_id=p_competition_id) then
  raise exception 'This tournament is not entered.';
 end if;
 select * into v_plan from public.player_tournament_preparation_plans
   where player_id=v_player and competition_id=p_competition_id;
 v_staff:=coalesce(p_staff_count,coalesce(array_length(v_plan.selected_staff_contract_ids,1),0));
 if v_staff<0 or v_staff>6 then raise exception 'A maximum of six staff can accompany the player.'; end if;
 v_base:=public.quote_tournament_preparation_v1(
  v_player,p_competition_id,coalesce(v_plan.player_travel_class,'Economy'),
  coalesce(v_plan.staff_travel_class,'Economy'),coalesce(v_plan.hotel_tier,'Standard'),
  coalesce(v_plan.selected_staff_contract_ids,'{}'::uuid[]));
 v_context:=public.get_tournament_transfer_preference_v1(v_player,p_competition_id);
 if coalesce((v_context->>'available')::boolean,false) and v_context->>'route_choice'='direct' then
   select * into v_src from public.player_commitment_locations_v1(v_player)
    where commitment_type='tournament' and reference_id=v_context->>'source_competition_id' limit 1;
   select * into v_dst from public.player_commitment_locations_v1(v_player)
    where commitment_type='tournament' and reference_id=p_competition_id::text limit 1;
   v_leg:=public.quote_travel_v2(v_src.city,v_src.country_code,v_src.latitude,v_src.longitude,
     v_dst.city,v_dst.country_code,v_dst.latitude,v_dst.longitude,'Economy','one_way');
   return public.quote_private_jet_leg_v1(v_player,v_src.city,v_src.country_code,
     v_dst.city,v_dst.country_code,coalesce((v_leg->>'distance_km')::integer,0),
     v_staff,p_owned_jet_asset_id,v_src.end_absolute_day+1);
 end if;
 return public.quote_private_jet_leg_v1(
  v_player,v_base->'origin'->>'city',v_base->'origin'->>'country_code',
  v_base->'destination'->>'city',v_base->'destination'->>'country_code',
  coalesce((v_base->'player_travel'->>'distance_km')::integer,0),v_staff,
  p_owned_jet_asset_id,coalesce((v_base->>'arrival_absolute_day')::integer,0)-1);
end; $function$
;
CREATE OR REPLACE FUNCTION public.set_private_life_tournament_travel_v1(p_competition_id uuid, p_mode text, p_owned_jet_asset_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_player uuid; v_exists boolean; v_preparation jsonb; v_route_jet jsonb;
 v_staff_count integer:=0; v_arrive integer;
 v_requested_mode text:=p_mode; v_fallback_reason text;
 v_context jsonb;v_src record;v_dst record;v_leg jsonb;
begin
 v_player:=public.private_life_current_player_v1();
 if p_mode not in ('commercial','private_jet') then raise exception 'Invalid travel mode.'; end if;
 if not exists(select 1 from public.tournament_entries where player_id=v_player and competition_id=p_competition_id)
 then raise exception 'This tournament is not entered.'; end if;
 if p_mode='private_jet' then
  select exists(select 1 from public.private_life_player_assets a
   join public.private_life_asset_catalog c on c.code=a.catalog_code
   where a.id=p_owned_jet_asset_id and a.player_id=v_player and a.sold_absolute_day is null
   and coalesce((c.metadata->>'tournament_travel_eligible')::boolean,false)) into v_exists;
  if not v_exists then raise exception 'Select an owned travel-capable private jet.'; end if;
  -- Server-authoritative range, booked location and repositioning check.
  v_preparation:=public.quote_tournament_preparation_v1(v_player,p_competition_id);
  select coalesce(array_length(selected_staff_contract_ids,1),0)
    into v_staff_count from public.player_tournament_preparation_plans
    where player_id=v_player and competition_id=p_competition_id;
  v_arrive:=coalesce((v_preparation->>'arrival_absolute_day')::integer,0);
  v_context:=public.get_tournament_transfer_preference_v1(v_player,p_competition_id);
  if coalesce((v_context->>'available')::boolean,false) and v_context->>'route_choice'='direct' then
    select * into v_src from public.player_commitment_locations_v1(v_player)
      where commitment_type='tournament' and reference_id=v_context->>'source_competition_id' limit 1;
    select * into v_dst from public.player_commitment_locations_v1(v_player)
      where commitment_type='tournament' and reference_id=p_competition_id::text limit 1;
    v_leg:=public.quote_travel_v2(v_src.city,v_src.country_code,v_src.latitude,v_src.longitude,
      v_dst.city,v_dst.country_code,v_dst.latitude,v_dst.longitude,'Economy','one_way');
    v_route_jet:=public.quote_private_jet_leg_v1(v_player,v_src.city,v_src.country_code,
      v_dst.city,v_dst.country_code,coalesce((v_leg->>'distance_km')::integer,0),
      coalesce(v_staff_count,0),p_owned_jet_asset_id,v_src.end_absolute_day+1);
  else
    v_route_jet:=public.quote_private_jet_leg_v1(
      v_player,v_preparation->'origin'->>'city',v_preparation->'origin'->>'country_code',
      v_preparation->'destination'->>'city',v_preparation->'destination'->>'country_code',
      coalesce((v_preparation->'player_travel'->>'distance_km')::integer,0),
      coalesce(v_staff_count,0),p_owned_jet_asset_id,v_arrive-1);
  end if;
  if not coalesce((v_route_jet->>'active')::boolean,false) then
    -- If an owned plane cannot make this trip directly, use normal flights.
    -- Never invent a fuel stop or charge any private-jet operating costs.
    v_fallback_reason:=coalesce(v_route_jet->>'reason','jet_out_of_range');
    p_mode:='commercial';
    p_owned_jet_asset_id:=null;
  end if;
 end if;
 insert into public.player_tournament_travel_selection(player_id,competition_id,travel_mode,owned_jet_asset_id)
 values(v_player,p_competition_id,p_mode,case when p_mode='private_jet' then p_owned_jet_asset_id else null end)
 on conflict(player_id,competition_id) do update set travel_mode=excluded.travel_mode,
 owned_jet_asset_id=excluded.owned_jet_asset_id,updated_at=now();
 perform public.rebuild_player_travel_plan_v1(v_player);
 return jsonb_build_object('status',
 case when v_requested_mode='private_jet' and p_mode='commercial'
      then 'commercial_fallback' else 'saved' end,
 'travel_mode',p_mode,'fallback_reason',v_fallback_reason,'owned_jet_asset_id',
 case when p_mode='private_jet' then p_owned_jet_asset_id else null end);
end; $function$
;
CREATE OR REPLACE FUNCTION public.get_private_life_tournament_travel_v1(p_competition_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_player uuid;v_selection record;v_quote jsonb;v_base jsonb;v_staff integer:=0;
 v_plan public.player_tournament_preparation_plans%rowtype;
 v_commercial_player jsonb;v_commercial_staff jsonb;
 v_context jsonb;v_src record;v_dst record;v_direct jsonb;
begin
 v_player:=public.private_life_current_player_v1();
 if not exists(select 1 from public.tournament_entries where player_id=v_player and competition_id=p_competition_id)
 then raise exception 'This tournament is not entered.'; end if;
 select * into v_selection from public.player_tournament_travel_selection
 where player_id=v_player and competition_id=p_competition_id;
 if v_selection.travel_mode is null then
   select case when preferred_travel_mode='best_owned_jet' then 'private_jet'
          else 'commercial' end as travel_mode,null::uuid as owned_jet_asset_id
     into v_selection from public.player_lifestyle_state where player_id=v_player;
 end if;
 select * into v_plan from public.player_tournament_preparation_plans
 where player_id=v_player and competition_id=p_competition_id;
 v_staff:=coalesce(array_length(v_plan.selected_staff_contract_ids,1),0);
 v_base:=public.quote_tournament_preparation_v1(
  v_player,p_competition_id,coalesce(v_plan.player_travel_class,'Economy'),
  coalesce(v_plan.staff_travel_class,'Economy'),coalesce(v_plan.hotel_tier,'Standard'),
  coalesce(v_plan.selected_staff_contract_ids,'{}'::uuid[]));
 -- Always compute a separate commercial baseline, even when the selected
 -- itinerary currently uses the owned jet.
 v_commercial_player:=public.quote_travel_v2(
  v_base->'origin'->>'city',v_base->'origin'->>'country_code',
  nullif(v_base->'origin'->>'latitude','')::double precision,
  nullif(v_base->'origin'->>'longitude','')::double precision,
  v_base->'destination'->>'city',v_base->'destination'->>'country_code',
  null,null,coalesce(v_plan.player_travel_class,'Economy'),'round_trip');
 v_commercial_staff:=public.quote_travel_v2(
  v_base->'origin'->>'city',v_base->'origin'->>'country_code',
  nullif(v_base->'origin'->>'latitude','')::double precision,
  nullif(v_base->'origin'->>'longitude','')::double precision,
  v_base->'destination'->>'city',v_base->'destination'->>'country_code',
  null,null,coalesce(v_plan.staff_travel_class,'Economy'),'round_trip');
 v_quote:=public.quote_private_jet_leg_v1(v_player,v_base->'origin'->>'city',
 v_base->'origin'->>'country_code',v_base->'destination'->>'city',
 v_base->'destination'->>'country_code',coalesce((v_base->'player_travel'->>'distance_km')::integer,0),
 coalesce(v_staff,0),v_selection.owned_jet_asset_id,coalesce((v_base->>'arrival_absolute_day')::integer,0)-1);
 v_context:=public.get_tournament_transfer_preference_v1(v_player,p_competition_id);
 if coalesce((v_context->>'available')::boolean,false) and v_context->>'route_choice'='direct' then
   select * into v_src from public.player_commitment_locations_v1(v_player)
     where commitment_type='tournament' and reference_id=v_context->>'source_competition_id' limit 1;
   select * into v_dst from public.player_commitment_locations_v1(v_player)
     where commitment_type='tournament' and reference_id=p_competition_id::text limit 1;
   v_commercial_player:=public.quote_travel_v2(v_src.city,v_src.country_code,v_src.latitude,v_src.longitude,
     v_dst.city,v_dst.country_code,v_dst.latitude,v_dst.longitude,
     coalesce(v_plan.player_travel_class,'Economy'),'one_way');
   v_commercial_staff:=public.quote_travel_v2(v_src.city,v_src.country_code,v_src.latitude,v_src.longitude,
     v_dst.city,v_dst.country_code,v_dst.latitude,v_dst.longitude,
     coalesce(v_plan.staff_travel_class,'Economy'),'one_way');
   v_quote:=public.quote_private_jet_leg_v1(v_player,v_src.city,v_src.country_code,
     v_dst.city,v_dst.country_code,coalesce((v_commercial_player->>'distance_km')::integer,0),
     v_staff,v_selection.owned_jet_asset_id,v_src.end_absolute_day+1);
 end if;
 return jsonb_build_object('selected_mode',coalesce(v_selection.travel_mode,'commercial'),
 'direct_transfer_scope',coalesce((v_context->>'available')::boolean,false) and v_context->>'route_choice'='direct',
 'selected_asset_id',coalesce(v_selection.owned_jet_asset_id,(v_quote->>'owned_asset_id')::uuid),
 'private_jet_quote',v_quote,'commercial_player_cost',(v_commercial_player->>'cost')::integer,
 'commercial_staff_cost',coalesce(v_staff,0)*(v_commercial_staff->>'cost')::integer);
end; $function$
;
CREATE OR REPLACE FUNCTION public.sync_player_tournament_travel_timing_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  l record;
  fm record;
  pm record;
  rule public.tournament_match_scheduling_rules%rowtype;
  q jsonb;
  v_first_day integer;
  v_first_abs bigint;
  v_pref_day integer;
  v_depart bigint;
  v_prev_end bigint;
  v_travel integer;
  v_arrive bigint;
  v_ready bigint;
  v_status text;
  v_count integer:=0;
  gd record;
  v_existing text;
begin
  for l in
    select *
    from public.player_travel_legs
    where player_id=p_player_id
      and status='planned'
      and destination_location_type='tournament'
      and destination_reference_id~*'^[0-9a-f-]{36}$'
    order by departure_absolute_day,id
  loop
    select
      m.id,m.competition_id,m.scheduled_start_minute,m.scheduled_season_week,m.scheduled_day,
      ed.season_number,s.category_code
    into fm
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=ed.tournament_series_id
    where m.competition_id=l.destination_reference_id::uuid
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
    order by ed.season_number,m.scheduled_season_week,m.scheduled_day,
             coalesce(m.scheduled_start_minute,600),m.match_number
    limit 1;

    if fm.id is null then continue; end if;

    v_first_day:=(((fm.season_number-1)*366)+2+((fm.scheduled_season_week-1)*7)+(fm.scheduled_day-1))::integer;
    v_first_abs:=v_first_day::bigint*1440+coalesce(fm.scheduled_start_minute,600);

    if l.split_day_transition then
      v_arrive:=l.arrival_absolute_day::bigint*1440+coalesce(l.arrival_minute_of_day,1439);
      select * into rule
      from public.tournament_match_scheduling_rules
      where category_code=fm.category_code;
      v_ready:=v_arrive+coalesce(rule.pre_match_arrival_buffer_minutes,90);
      v_status:=case when v_ready>v_first_abs then 'at_risk' else 'tight' end;

      update public.player_travel_legs
      set first_match_id=fm.id,
          connection_status=v_status,
          updated_at=now()
      where id=l.id;

      v_count:=v_count+1;
      continue;
    end if;

    select * into rule
    from public.tournament_match_scheduling_rules
    where category_code=fm.category_code;

    v_pref_day:=v_first_day-1;
    v_depart:=case
      when l.source_location_type='tournament'
        and exists (
          select 1 from public.player_tournament_transfer_preferences pref
          where pref.player_id=p_player_id
            and pref.source_competition_id::text=l.source_reference_id
            and pref.competition_id::text=l.destination_reference_id
            and pref.route_choice='direct'
        )
        then least(v_pref_day,l.departure_absolute_day)::bigint*1440+540
      else v_pref_day::bigint*1440+540
    end;

    select
      m.id match_id,m.scheduled_start_minute,
      coalesce(m.actual_duration_minutes,m.estimated_duration_minutes,150) duration_minutes,
      (((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::integer abs_day
    into pm
    from public.tournament_matches m
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where m.competition_id<>fm.competition_id
      and (m.player1_id=p_player_id or m.player2_id=p_player_id)
      and m.status not in ('bye','cancelled')
      and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*1440
           +coalesce(m.scheduled_start_minute,600))<v_first_abs
    order by abs_day desc,coalesce(m.scheduled_start_minute,600) desc
    limit 1;

    if pm.match_id is not null and pm.abs_day>=v_pref_day then
      v_prev_end:=pm.abs_day::bigint*1440+coalesce(pm.scheduled_start_minute,600)
        +pm.duration_minutes+coalesce(rule.post_match_departure_buffer_minutes,60);
      v_depart:=greatest(v_depart,v_prev_end);
    end if;

    q:=public.quote_travel_v2(
      l.source_city,l.source_country_code,l.source_latitude,l.source_longitude,
      l.destination_city,l.destination_country_code,l.destination_latitude,l.destination_longitude,
      l.travel_class,'one_way'
    );
    v_travel:=greatest(30,ceil(
      case when l.travel_mode='private_jet' and l.jet_asset_id is not null
        then coalesce((l.jet_quote->>'estimated_hours')::numeric,(q->>'estimated_hours_one_way')::numeric,1)
        else coalesce((q->>'estimated_hours_one_way')::numeric,1) end
      *60)::integer);
    v_arrive:=v_depart+v_travel;
    v_ready:=v_arrive+coalesce(rule.pre_match_arrival_buffer_minutes,90);
    v_status:=case
      when v_ready>v_first_abs then 'at_risk'
      when (v_arrive/1440)::integer>=v_first_day
        or v_depart>v_pref_day::bigint*1440+540 then 'tight'
      else 'normal'
    end;

    update public.player_travel_legs
    set departure_absolute_day=(v_depart/1440)::integer,
        departure_minute_of_day=(v_depart%1440)::smallint,
        arrival_absolute_day=(v_arrive/1440)::integer,
        arrival_minute_of_day=(v_arrive%1440)::smallint,
        estimated_travel_minutes=v_travel,
        connection_status=v_status,
        first_match_id=fm.id,
        embedded_transition=(pm.match_id is not null and pm.abs_day>=v_pref_day),
        updated_at=now()
    where id=l.id;

    delete from public.player_daily_activity
    where player_id=p_player_id
      and source='travel_plan'
      and reference_id=l.id::text
      and effects_applied_at is null;

    if not (pm.match_id is not null and pm.abs_day>=v_pref_day) then
      select * into gd from public.absolute_game_day_v1((v_depart/1440)::integer);
      select activity_type into v_existing
      from public.player_daily_activity
      where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;

      if v_existing is null or v_existing='home' then
        insert into public.player_daily_activity(
          player_id,season,month,day,activity_type,source,reference_id,note
        )
        values(
          p_player_id,gd.season,gd.month,gd.day,
          'travel','travel_plan',l.id::text,
          format('Travel to %s',coalesce(l.destination_city,l.destination_country_code))
        )
        on conflict(player_id,season,month,day) do update set
          activity_type='travel',
          source='travel_plan',
          reference_id=l.id::text,
          note=excluded.note,
          updated_at=now()
        where public.player_daily_activity.effects_applied_at is null
          and public.player_daily_activity.activity_type='home';
      end if;
    end if;

    v_count:=v_count+1;
  end loop;

  return jsonb_build_object('status','synced','tournament_legs',v_count);
end;
$function$
;
