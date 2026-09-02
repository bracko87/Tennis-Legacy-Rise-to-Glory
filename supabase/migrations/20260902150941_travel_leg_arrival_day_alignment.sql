create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_player public.players%rowtype; v_state public.player_location_state%rowtype; v_current integer; v_gap_limit smallint:=3;
  v_source_city text; v_source_country text; v_source_type text; v_source_ref text; v_source_lat double precision; v_source_lon double precision;
  v_prev_end integer; v_had boolean:=false; c record; q jsonb; v_depart integer; v_arrive integer; v_embedded boolean; v_count integer:=0; homep jsonb;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select public.game_day_absolute_v1(season,month,day) into v_current from public.get_current_game_day_internal_v1();
  select direct_transition_max_gap_days into v_gap_limit from public.travel_engine_settings where id=1;
  select * into v_state from public.player_location_state where player_id=p_player_id;

  update public.player_daily_activity
  set activity_type='home',source=null,reference_id=null,note=null,updated_at=now()
  where player_id=p_player_id and source='travel_plan' and effects_applied_at is null
    and public.game_day_absolute_v1(season,month,day)>=v_current;
  delete from public.player_travel_legs where player_id=p_player_id and status='planned' and arrival_absolute_day>=v_current;

  if v_state.player_id is null then
    insert into public.player_location_state(player_id,current_city,current_country_code,current_continent,location_type,location_since_absolute_day,updated_at)
    values(p_player_id,v_player.home_city,v_player.country_code,public.country_continent_v1(v_player.country_code),'home',v_current,now())
    on conflict(player_id) do nothing;
    select * into v_state from public.player_location_state where player_id=p_player_id;
  end if;

  v_source_city:=coalesce(v_state.current_city,v_player.home_city);
  v_source_country:=coalesce(v_state.current_country_code,v_player.country_code);
  v_source_type:=coalesce(v_state.location_type,'home');
  v_source_ref:=v_state.source_reference_id;
  q:=public.resolve_location_coordinates_v1(v_source_city,v_source_country,v_state.current_latitude,v_state.current_longitude);
  v_source_lat:=nullif(q->>'latitude','')::double precision; v_source_lon:=nullif(q->>'longitude','')::double precision;
  v_prev_end:=v_current-1;

  for c in
    select * from public.player_commitment_locations_v1(p_player_id)
    where end_absolute_day>=v_current
    order by start_absolute_day,end_absolute_day,commitment_type
  loop
    if c.start_absolute_day<=v_current and c.end_absolute_day>=v_current then
      q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
      v_source_city:=c.city; v_source_country:=c.country_code; v_source_type:=c.commitment_type; v_source_ref:=c.reference_id;
      v_source_lat:=nullif(q->>'latitude','')::double precision; v_source_lon:=nullif(q->>'longitude','')::double precision;
      update public.player_location_state set current_city=c.city,current_country_code=c.country_code,current_continent=c.continent,current_latitude=v_source_lat,current_longitude=v_source_lon,location_type=c.commitment_type,source_reference_id=c.reference_id,location_since_absolute_day=coalesce(location_since_absolute_day,v_current),updated_at=now() where player_id=p_player_id;
      v_prev_end:=c.end_absolute_day; v_had:=true; continue;
    end if;

    if v_had and v_source_type<>'home' and (c.start_absolute_day-v_prev_end-1)>v_gap_limit then
      homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);
      v_depart:=greatest(v_current,v_prev_end+1);
      perform public.insert_planned_travel_leg_v1(p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,'home',v_player.home_city,v_player.country_code,nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,v_depart,v_depart,false);
      v_count:=v_count+1;
      v_source_city:=v_player.home_city; v_source_country:=v_player.country_code; v_source_type:='home'; v_source_ref:=null; v_source_lat:=nullif(homep->>'latitude','')::double precision; v_source_lon:=nullif(homep->>'longitude','')::double precision;
    end if;

    q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
    v_depart:=greatest(v_current,c.start_absolute_day-1);
    v_embedded:=v_depart<=v_prev_end or v_depart>=c.start_absolute_day;
    v_arrive:=case when v_embedded then c.start_absolute_day else v_depart end;
    if public.insert_planned_travel_leg_v1(p_player_id,c.commitment_type,v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,c.commitment_type,c.city,c.country_code,nullif(q->>'latitude','')::double precision,nullif(q->>'longitude','')::double precision,c.reference_id,v_depart,v_arrive,v_embedded) is not null then v_count:=v_count+1; end if;
    v_source_city:=c.city; v_source_country:=c.country_code; v_source_type:=c.commitment_type; v_source_ref:=c.reference_id; v_source_lat:=nullif(q->>'latitude','')::double precision; v_source_lon:=nullif(q->>'longitude','')::double precision; v_prev_end:=c.end_absolute_day; v_had:=true;
  end loop;

  if v_had and v_source_type<>'home' then
    homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);
    v_depart:=greatest(v_current,v_prev_end+1);
    if public.insert_planned_travel_leg_v1(p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,'home',v_player.home_city,v_player.country_code,nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,v_depart,v_depart,false) is not null then v_count:=v_count+1; end if;
  end if;

  return jsonb_build_object('status','rebuilt','travel_legs',v_count,'direct_transition_max_gap_days',v_gap_limit);
end; $$;

do $$ declare p record; begin
  for p in select id from public.players loop perform public.rebuild_player_travel_plan_v1(p.id); end loop;
end $$;