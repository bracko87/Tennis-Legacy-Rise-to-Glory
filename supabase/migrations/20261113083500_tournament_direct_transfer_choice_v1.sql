-- Tournament-to-tournament direct travel, default home via existing rules.
-- Installation creates no player trips and makes no gameplay finance/match writes.
create table if not exists public.player_tournament_transfer_preferences (
 player_id uuid not null references public.players(id) on delete cascade,
 competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
 source_competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
 route_choice text not null check (route_choice in ('home','direct')),
 updated_at timestamptz not null default now(),
 primary key (player_id,competition_id)
);
alter table public.player_tournament_transfer_preferences enable row level security;
revoke all on public.player_tournament_transfer_preferences from anon,authenticated;
grant select on public.player_tournament_transfer_preferences to authenticated;
drop policy if exists tournament_transfer_owner_read on public.player_tournament_transfer_preferences;
create policy tournament_transfer_owner_read on public.player_tournament_transfer_preferences
for select to authenticated using (exists (
 select 1 from public.players p where p.id=player_id and p.owner_user_id=(select auth.uid())
));
create or replace function public.get_tournament_transfer_preference_v1(p_player_id uuid,p_competition_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public','pg_temp'
as $function$
declare
 v_dest_start integer; v_source_id uuid; v_source_end integer; v_source_city text;
 v_source_name text; v_choice text:='home'; v_now integer; v_blocked boolean:=false;
begin
 if auth.uid() is null or not exists (
   select 1 from public.players p where p.id=p_player_id and p.owner_user_id=auth.uid()
 ) then raise exception 'Player access denied.'; end if;
 select c.start_absolute_day into v_dest_start
 from public.player_commitment_locations_v1(p_player_id) c
 where c.commitment_type='tournament' and c.reference_id=p_competition_id::text limit 1;
 if v_dest_start is null then
   return jsonb_build_object('available',false,'route_choice','home','reason','no_accepted_destination');
 end if;
 select c.reference_id::uuid,c.end_absolute_day,c.city
 into v_source_id,v_source_end,v_source_city
 from public.player_commitment_locations_v1(p_player_id) c
 where c.commitment_type='tournament' and c.reference_id<>p_competition_id::text
   and c.start_absolute_day<v_dest_start and c.end_absolute_day<v_dest_start
 order by c.end_absolute_day desc,c.start_absolute_day desc limit 1;
 if v_source_id is null then
   return jsonb_build_object('available',false,'route_choice','home','reason','no_preceding_tournament');
 end if;
 select ts.name into v_source_name from public.tournament_world_competitions wc
 join public.tournament_editions ed on ed.id=wc.tournament_edition_id
 join public.tournament_series ts on ts.id=ed.tournament_series_id
 where wc.id=v_source_id;
 select public.game_day_absolute_v1(season,month,day) into v_now
 from public.get_current_game_day_internal_v1();
 v_blocked:=coalesce(v_source_end<v_now-1,false)
   or exists (select 1 from public.player_travel_legs l
     where l.player_id=p_player_id and l.status='completed'
       and l.source_reference_id=v_source_id::text and l.purpose='return_home')
   or exists (select 1 from public.player_travel_legs l
     where l.player_id=p_player_id and l.status='completed'
       and l.destination_reference_id=p_competition_id::text)
   or exists (select 1 from public.player_commitment_locations_v1(p_player_id) c
     where c.commitment_type<>'tournament'
       and c.start_absolute_day between v_source_end and (v_dest_start-1));
 select pref.route_choice into v_choice from public.player_tournament_transfer_preferences pref
 where pref.player_id=p_player_id and pref.competition_id=p_competition_id
   and pref.source_competition_id=v_source_id;
 return jsonb_build_object(
   'available',not v_blocked,
   'source_competition_id',v_source_id,
   'source_tournament_name',coalesce(v_source_name,v_source_city,'Previous tournament'),
   'source_city',v_source_city,
   'route_choice',coalesce(v_choice,'home'),
   'reason',case when v_blocked then 'journey_already_started_or_conflicting_commitment' else null end
 );
end;
$function$;
revoke all on function public.get_tournament_transfer_preference_v1(uuid,uuid) from public,anon;
grant execute on function public.get_tournament_transfer_preference_v1(uuid,uuid) to authenticated;
create or replace function public.save_tournament_transfer_preference_v1(
 p_player_id uuid,p_competition_id uuid,p_route_choice text
) returns jsonb language plpgsql security definer set search_path='public','pg_temp'
as $function$
declare v_context jsonb; v_source_id uuid;
begin
 if p_route_choice not in ('home','direct') or p_route_choice is null then
   raise exception 'Invalid transfer choice.'; end if;
 v_context:=public.get_tournament_transfer_preference_v1(p_player_id,p_competition_id);
 if not coalesce((v_context->>'available')::boolean,false) then
   raise exception 'Tournament transfer can no longer be changed.'; end if;
 v_source_id:=(v_context->>'source_competition_id')::uuid;
 insert into public.player_tournament_transfer_preferences
 (player_id,competition_id,source_competition_id,route_choice,updated_at)
 values(p_player_id,p_competition_id,v_source_id,p_route_choice,now())
 on conflict(player_id,competition_id) do update
 set source_competition_id=excluded.source_competition_id,
 route_choice=excluded.route_choice,updated_at=excluded.updated_at;
 perform public.rebuild_player_travel_plan_v1(p_player_id);
 return jsonb_build_object('saved',true,'route_choice',p_route_choice,
 'source_competition_id',v_source_id,'competition_id',p_competition_id);
end;
$function$;
revoke all on function public.save_tournament_transfer_preference_v1(uuid,uuid,text) from public,anon;
grant execute on function public.save_tournament_transfer_preference_v1(uuid,uuid,text) to authenticated;

CREATE OR REPLACE FUNCTION public.rebuild_player_travel_plan_core_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype;
  v_state public.player_location_state%rowtype;
  v_current integer;
  v_gap_limit smallint:=3;
  v_source_city text;
  v_source_country text;
  v_source_type text;
  v_source_ref text;
  v_source_lat double precision;
  v_source_lon double precision;
  v_prev_end integer;
  v_had boolean:=false;
  c record;
  q jsonb;
  v_depart integer;
  v_arrive integer;
  v_embedded boolean;
  v_count integer:=0;
  homep jsonb; v_home_city text; v_home_country text;
  v_return_home boolean;
  v_unresolved_tournament boolean:=false;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.';end if;
  homep:=public.get_player_home_base_v1(p_player_id);
  v_home_city:=homep->>'city';v_home_country:=homep->>'country_code';

  select public.game_day_absolute_v1(season,month,day)
  into v_current
  from public.get_current_game_day_internal_v1();

  select direct_transition_max_gap_days into v_gap_limit
  from public.travel_engine_settings where id=1;

  select * into v_state
  from public.player_location_state where player_id=p_player_id;

  update public.player_daily_activity
  set activity_type='home',source=null,reference_id=null,note=null,updated_at=now()
  where player_id=p_player_id
    and source='travel_plan'
    and effects_applied_at is null
    and public.game_day_absolute_v1(season,month,day)>=v_current;

  delete from public.player_travel_legs
  where player_id=p_player_id
    and status='planned'
    and arrival_absolute_day>=v_current;

  if v_state.player_id is null then
    insert into public.player_location_state(
      player_id,current_city,current_country_code,current_continent,
      location_type,location_since_absolute_day,updated_at
    ) values(
      p_player_id,v_home_city,v_home_country,
      public.country_continent_v1(v_home_country),'home',v_current,now()
    ) on conflict(player_id) do nothing;
    select * into v_state from public.player_location_state where player_id=p_player_id;
  end if;

  v_source_city:=coalesce(v_state.current_city,v_home_city);
  v_source_country:=coalesce(v_state.current_country_code,v_home_country);
  v_source_type:=coalesce(v_state.location_type,'home');
  v_source_ref:=v_state.source_reference_id;
  q:=public.resolve_location_coordinates_v1(v_source_city,v_source_country,v_state.current_latitude,v_state.current_longitude);
  v_source_lat:=nullif(q->>'latitude','')::double precision;
  v_source_lon:=nullif(q->>'longitude','')::double precision;
  v_prev_end:=v_current-1;

  for c in
    select *
    from public.player_commitment_locations_v1(p_player_id)
    where end_absolute_day>=v_current
    order by start_absolute_day,end_absolute_day,commitment_type
  loop
    v_unresolved_tournament:=c.commitment_type='tournament'
      and public.player_tournament_commitment_unresolved_v1(p_player_id,c.reference_id);

    if c.start_absolute_day<=v_current and c.end_absolute_day>=v_current then
      q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
      v_source_city:=c.city;
      v_source_country:=c.country_code;
      v_source_type:=c.commitment_type;
      v_source_ref:=c.reference_id;
      v_source_lat:=nullif(q->>'latitude','')::double precision;
      v_source_lon:=nullif(q->>'longitude','')::double precision;
      update public.player_location_state
      set current_city=c.city,current_country_code=c.country_code,current_continent=c.continent,
          current_latitude=v_source_lat,current_longitude=v_source_lon,
          location_type=c.commitment_type,source_reference_id=c.reference_id,
          location_since_absolute_day=coalesce(location_since_absolute_day,v_current),updated_at=now()
      where player_id=p_player_id;
      v_prev_end:=c.end_absolute_day;
      v_had:=true;
      exit when v_unresolved_tournament;
      continue;
    end if;

    v_return_home:=false;
    if v_had and v_source_type<>'home' and not v_unresolved_tournament then
      if v_source_type='tournament' and c.commitment_type='tournament' then
        v_return_home:=c.start_absolute_day>v_prev_end+1
          and not exists (
            select 1 from public.player_tournament_transfer_preferences pref
            where pref.player_id=p_player_id
              and pref.source_competition_id::text=v_source_ref
              and pref.competition_id::text=c.reference_id
              and pref.route_choice='direct'
          );
      else
        v_return_home:=(c.start_absolute_day-v_prev_end-1)>v_gap_limit;
      end if;
    end if;

    if v_return_home then
      homep:=public.resolve_location_coordinates_v1(v_home_city,v_home_country,null,null);
      v_depart:=greatest(v_current,v_prev_end+1);
      perform public.insert_planned_travel_leg_v1(
        p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
        'home',v_home_city,v_home_country,
        nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,
        v_depart,v_depart,false
      );
      v_count:=v_count+1;
      v_source_city:=v_home_city;
      v_source_country:=v_home_country;
      v_source_type:='home';
      v_source_ref:=null;
      v_source_lat:=nullif(homep->>'latitude','')::double precision;
      v_source_lon:=nullif(homep->>'longitude','')::double precision;
    end if;

    q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
    v_depart:=case
      when v_had and v_source_type='tournament' and c.commitment_type='tournament'
        and exists (
          select 1 from public.player_tournament_transfer_preferences pref
          where pref.player_id=p_player_id
            and pref.source_competition_id::text=v_source_ref
            and pref.competition_id::text=c.reference_id
            and pref.route_choice='direct'
        )
        then greatest(v_current,v_prev_end+1)
      else greatest(v_current,c.start_absolute_day-1)
    end;
    v_embedded:=v_depart<=v_prev_end or v_depart>=c.start_absolute_day;
    v_arrive:=case when v_embedded then c.start_absolute_day else v_depart end;

    if public.insert_planned_travel_leg_v1(
      p_player_id,c.commitment_type,
      v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
      c.commitment_type,c.city,c.country_code,
      nullif(q->>'latitude','')::double precision,nullif(q->>'longitude','')::double precision,c.reference_id,
      v_depart,v_arrive,v_embedded
    ) is not null then
      v_count:=v_count+1;
    end if;

    v_source_city:=c.city;
    v_source_country:=c.country_code;
    v_source_type:=c.commitment_type;
    v_source_ref:=c.reference_id;
    v_source_lat:=nullif(q->>'latitude','')::double precision;
    v_source_lon:=nullif(q->>'longitude','')::double precision;
    v_prev_end:=c.end_absolute_day;
    v_had:=true;

    exit when v_unresolved_tournament;
  end loop;

  if v_had and v_source_type<>'home'
     and not public.player_tournament_commitment_unresolved_v1(p_player_id,v_source_ref) then
    homep:=public.resolve_location_coordinates_v1(v_home_city,v_home_country,null,null);
    v_depart:=greatest(v_current,v_prev_end+1);
    if public.insert_planned_travel_leg_v1(
      p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
      'home',v_home_city,v_home_country,
      nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,
      v_depart,v_depart,false
    ) is not null then
      v_count:=v_count+1;
    end if;
  end if;

  perform public.sync_player_tournament_travel_timing_v1(p_player_id);
  return jsonb_build_object(
    'status','rebuilt',
    'travel_legs',v_count,
    'direct_transition_max_gap_days',v_gap_limit,
    'unresolved_tournament_rule','no return or later travel is booked until active tournament outcome is known'
  );
end;
$function$
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
    v_travel:=greatest(30,ceil(coalesce((q->>'estimated_hours_one_way')::numeric,1)*60)::integer);
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
