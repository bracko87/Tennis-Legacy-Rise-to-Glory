alter table public.player_location_state
  add column if not exists current_latitude double precision,
  add column if not exists current_longitude double precision,
  add column if not exists location_since_absolute_day integer;

alter table public.training_camp_locations
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

create table if not exists public.player_travel_legs (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  purpose text not null check (purpose in ('training_camp','tournament','return_home','other')),
  source_location_type text not null default 'home',
  source_city text,
  source_country_code text,
  source_continent text,
  source_latitude double precision,
  source_longitude double precision,
  destination_location_type text not null,
  destination_city text,
  destination_country_code text,
  destination_continent text,
  destination_latitude double precision,
  destination_longitude double precision,
  source_reference_id text,
  destination_reference_id text,
  departure_absolute_day integer not null,
  arrival_absolute_day integer not null,
  distance_km integer,
  estimated_cost integer not null default 0,
  arrival_fatigue smallint not null default 0,
  travel_band text,
  travel_basis text,
  embedded_transition boolean not null default false,
  status text not null default 'planned' check (status in ('planned','completed','cancelled')),
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_travel_leg_dates_chk check (arrival_absolute_day >= departure_absolute_day)
);

create index if not exists player_travel_legs_player_day_idx
  on public.player_travel_legs(player_id, arrival_absolute_day, departure_absolute_day);
create index if not exists player_travel_legs_player_status_idx
  on public.player_travel_legs(player_id, status);

alter table public.player_travel_legs enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='player_travel_legs' and policyname='player_travel_legs_owner_read'
  ) then
    create policy player_travel_legs_owner_read on public.player_travel_legs
      for select to authenticated
      using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));
  end if;
end $$;

create table if not exists public.travel_engine_settings (
  id smallint primary key default 1 check (id=1),
  direct_transition_max_gap_days smallint not null default 3 check (direct_transition_max_gap_days between 0 and 14),
  updated_at timestamptz not null default now()
);
insert into public.travel_engine_settings(id,direct_transition_max_gap_days)
values(1,3)
on conflict(id) do nothing;

alter table public.travel_engine_settings enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname='public' and tablename='travel_engine_settings' and policyname='travel_engine_settings_read'
  ) then
    create policy travel_engine_settings_read on public.travel_engine_settings for select to authenticated using (true);
  end if;
end $$;

create or replace function public.resolve_location_coordinates_v1(
  p_city text,
  p_country_code text,
  p_latitude double precision default null,
  p_longitude double precision default null
) returns jsonb
language plpgsql stable
set search_path to 'public'
as $$
declare v_ref public.training_travel_country_reference%rowtype;
begin
  if p_latitude is not null and p_longitude is not null then
    return jsonb_build_object('city',p_city,'country_code',upper(p_country_code),'latitude',p_latitude,'longitude',p_longitude,'basis','exact');
  end if;
  select * into v_ref from public.training_travel_country_reference where country_code=upper(coalesce(p_country_code,''));
  return jsonb_build_object(
    'city',p_city,'country_code',upper(p_country_code),
    'latitude',v_ref.latitude,'longitude',v_ref.longitude,
    'basis',case when v_ref.country_code is null then 'unknown' else 'country_reference' end
  );
end; $$;

create or replace function public.travel_leg_quote_v1(
  p_source_city text,
  p_source_country_code text,
  p_source_latitude double precision,
  p_source_longitude double precision,
  p_destination_city text,
  p_destination_country_code text,
  p_destination_latitude double precision,
  p_destination_longitude double precision
) returns jsonb
language plpgsql stable
set search_path to 'public'
as $$
declare
  s jsonb; d jsonb; v_km numeric; v_cost integer; v_fatigue integer; v_band text; v_basis text;
begin
  s:=public.resolve_location_coordinates_v1(p_source_city,p_source_country_code,p_source_latitude,p_source_longitude);
  d:=public.resolve_location_coordinates_v1(p_destination_city,p_destination_country_code,p_destination_latitude,p_destination_longitude);

  if upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,''))
     and lower(trim(coalesce(p_source_city,'')))<>''
     and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_destination_city,''))) then
    return jsonb_build_object('distance_km',0,'cost',20,'arrival_fatigue',1,'band','same_city','basis','exact_city_match');
  end if;

  if (s->>'latitude') is null or (d->>'latitude') is null then
    return jsonb_build_object(
      'distance_km',null,
      'cost',greatest(20,round(public.training_camp_travel_cost_v1(p_source_city,p_source_country_code,public.country_continent_v1(p_source_country_code),p_destination_city,p_destination_country_code,public.country_continent_v1(p_destination_country_code))/2.0)::integer),
      'arrival_fatigue',case when public.country_continent_v1(p_source_country_code)=public.country_continent_v1(p_destination_country_code) then 3 else 8 end,
      'band',case when upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,'')) then 'domestic' when public.country_continent_v1(p_source_country_code)=public.country_continent_v1(p_destination_country_code) then 'regional' else 'intercontinental' end,
      'basis','fallback'
    );
  end if;

  v_km:=public.great_circle_km_v1((s->>'latitude')::numeric,(s->>'longitude')::numeric,(d->>'latitude')::numeric,(d->>'longitude')::numeric);
  v_basis:=case when s->>'basis'='exact' and d->>'basis'='exact' then 'exact_coordinates' else 'country_reference_distance' end;

  if upper(coalesce(p_source_country_code,''))=upper(coalesce(p_destination_country_code,'')) then
    v_band:='domestic'; v_cost:=greatest(30,least(220,round((30+v_km*0.035)/10.0)::integer*10)); v_fatigue:=least(4,greatest(1,1+round(v_km/900.0)::integer));
  elsif public.country_continent_v1(p_source_country_code)=public.country_continent_v1(p_destination_country_code) then
    v_band:='regional'; v_cost:=greatest(90,least(350,round((40+v_km*0.055)/10.0)::integer*10)); v_fatigue:=least(6,greatest(2,2+round(v_km/1800.0)::integer));
  else
    v_band:='intercontinental'; v_cost:=greatest(250,least(1200,round((110+v_km*0.05)/10.0)::integer*10)); v_fatigue:=least(14,greatest(5,5+round(v_km/2200.0)::integer));
  end if;

  return jsonb_build_object('distance_km',v_km::integer,'cost',v_cost,'arrival_fatigue',v_fatigue,'band',v_band,'basis',v_basis);
end; $$;

create or replace function public.player_commitment_locations_v1(p_player_id uuid)
returns table(
  commitment_type text,
  reference_id text,
  start_absolute_day integer,
  end_absolute_day integer,
  city text,
  country_code text,
  continent text,
  latitude double precision,
  longitude double precision
)
language sql stable
set search_path to 'public'
as $$
  with camps as (
    select
      'training_camp'::text commitment_type,
      b.id::text reference_id,
      b.start_absolute_day,
      b.end_absolute_day,
      l.city,
      l.country_code,
      l.continent,
      l.latitude,
      l.longitude
    from public.player_training_camp_bookings b
    join public.training_camp_programs p on p.id=b.program_id
    join public.training_camp_locations l on l.id=p.location_id
    where b.player_id=p_player_id
      and b.status in ('booked','active','completed')
  ),
  tournaments as (
    select
      'tournament'::text commitment_type,
      ta.competition_id::text reference_id,
      (((te.season_number-1)*366)+2+((min(ss.season_week)-1)*7))::integer start_absolute_day,
      (((te.season_number-1)*366)+2+((max(ss.season_week)-1)*7)+6)::integer end_absolute_day,
      ts.city,
      ts.country_code,
      public.country_continent_v1(ts.country_code) continent,
      ts.latitude,
      ts.longitude
    from public.tournament_applications ta
    join public.tournament_world_competitions wc on wc.id=ta.competition_id
    join public.tournament_editions te on te.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=te.tournament_series_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id
    where ta.player_id=p_player_id
      and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')
      and wc.status<>'canceled' and te.status<>'canceled'
    group by ta.competition_id,te.season_number,ts.city,ts.country_code,ts.latitude,ts.longitude
  )
  select * from camps
  union all
  select * from tournaments;
$$;

create or replace function public.resolve_player_origin_before_day_v1(p_player_id uuid,p_target_absolute_day integer)
returns jsonb
language plpgsql stable security definer
set search_path to 'public'
as $$
declare
  v_player public.players%rowtype; v_state public.player_location_state%rowtype; v_current integer; v_gap smallint:=3; c record; p jsonb;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into v_state from public.player_location_state where player_id=p_player_id;
  select public.game_day_absolute_v1(season,month,day) into v_current from public.get_current_game_day_internal_v1();
  select direct_transition_max_gap_days into v_gap from public.travel_engine_settings where id=1;

  if p_target_absolute_day<=v_current+1 and v_state.player_id is not null then
    p:=public.resolve_location_coordinates_v1(v_state.current_city,v_state.current_country_code,v_state.current_latitude,v_state.current_longitude);
    return p||jsonb_build_object('continent',coalesce(v_state.current_continent,public.country_continent_v1(v_state.current_country_code)),'location_type',v_state.location_type,'reference_id',v_state.source_reference_id,'continuity','current_location');
  end if;

  select * into c
  from public.player_commitment_locations_v1(p_player_id) x
  where x.end_absolute_day < p_target_absolute_day
    and x.end_absolute_day >= v_current-1
  order by x.end_absolute_day desc
  limit 1;

  if c.reference_id is not null and (p_target_absolute_day-c.end_absolute_day-1)<=v_gap then
    p:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
    return p||jsonb_build_object('continent',c.continent,'location_type',c.commitment_type,'reference_id',c.reference_id,'continuity','direct_from_previous_commitment','gap_days',p_target_absolute_day-c.end_absolute_day-1);
  end if;

  p:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);
  return p||jsonb_build_object('continent',public.country_continent_v1(v_player.country_code),'location_type','home','reference_id',null,'continuity','home_base');
end; $$;

create or replace function public.insert_planned_travel_leg_v1(
  p_player_id uuid,
  p_purpose text,
  p_source_type text,
  p_source_city text,
  p_source_country text,
  p_source_lat double precision,
  p_source_lon double precision,
  p_source_ref text,
  p_dest_type text,
  p_dest_city text,
  p_dest_country text,
  p_dest_lat double precision,
  p_dest_lon double precision,
  p_dest_ref text,
  p_departure integer,
  p_arrival integer,
  p_embedded boolean default false
) returns uuid
language plpgsql security definer
set search_path to 'public'
as $$
declare q jsonb; v_id uuid; gd record; v_existing text;
begin
  if upper(coalesce(p_source_country,''))=upper(coalesce(p_dest_country,''))
     and lower(trim(coalesce(p_source_city,'')))<>''
     and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_dest_city,''))) then
    return null;
  end if;

  q:=public.travel_leg_quote_v1(p_source_city,p_source_country,p_source_lat,p_source_lon,p_dest_city,p_dest_country,p_dest_lat,p_dest_lon);
  insert into public.player_travel_legs(
    player_id,purpose,source_location_type,source_city,source_country_code,source_continent,source_latitude,source_longitude,
    destination_location_type,destination_city,destination_country_code,destination_continent,destination_latitude,destination_longitude,
    source_reference_id,destination_reference_id,departure_absolute_day,arrival_absolute_day,distance_km,estimated_cost,arrival_fatigue,travel_band,travel_basis,embedded_transition,status
  ) values(
    p_player_id,p_purpose,p_source_type,p_source_city,p_source_country,public.country_continent_v1(p_source_country),p_source_lat,p_source_lon,
    p_dest_type,p_dest_city,p_dest_country,public.country_continent_v1(p_dest_country),p_dest_lat,p_dest_lon,
    p_source_ref,p_dest_ref,p_departure,p_arrival,nullif(q->>'distance_km','')::integer,(q->>'cost')::integer,(q->>'arrival_fatigue')::smallint,q->>'band',q->>'basis',p_embedded,'planned'
  ) returning id into v_id;

  if not p_embedded then
    select * into gd from public.absolute_game_day_v1(p_departure);
    select activity_type into v_existing from public.player_daily_activity where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;
    if v_existing is null or v_existing='home' then
      insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note)
      values(p_player_id,gd.season,gd.month,gd.day,'travel','travel_plan',v_id::text,format('Travel to %s',coalesce(p_dest_city,p_dest_country)))
      on conflict(player_id,season,month,day) do update
      set activity_type='travel',source='travel_plan',reference_id=v_id::text,note=excluded.note,updated_at=now()
      where public.player_daily_activity.effects_applied_at is null and public.player_daily_activity.activity_type='home';
    else
      update public.player_travel_legs set embedded_transition=true,updated_at=now() where id=v_id;
    end if;
  end if;
  return v_id;
end; $$;

create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_player public.players%rowtype; v_state public.player_location_state%rowtype; v_current integer; v_gap_limit smallint:=3;
  v_source_city text; v_source_country text; v_source_type text; v_source_ref text; v_source_lat double precision; v_source_lon double precision;
  v_prev_end integer; v_had boolean:=false; c record; q jsonb; v_depart integer; v_embedded boolean; v_count integer:=0; homep jsonb;
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
    if public.insert_planned_travel_leg_v1(p_player_id,c.commitment_type,v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,c.commitment_type,c.city,c.country_code,nullif(q->>'latitude','')::double precision,nullif(q->>'longitude','')::double precision,c.reference_id,v_depart,c.start_absolute_day,v_embedded) is not null then v_count:=v_count+1; end if;
    v_source_city:=c.city; v_source_country:=c.country_code; v_source_type:=c.commitment_type; v_source_ref:=c.reference_id; v_source_lat:=nullif(q->>'latitude','')::double precision; v_source_lon:=nullif(q->>'longitude','')::double precision; v_prev_end:=c.end_absolute_day; v_had:=true;
  end loop;

  if v_had and v_source_type<>'home' then
    homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);
    v_depart:=greatest(v_current,v_prev_end+1);
    if public.insert_planned_travel_leg_v1(p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,'home',v_player.home_city,v_player.country_code,nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,v_depart,v_depart,false) is not null then v_count:=v_count+1; end if;
  end if;

  return jsonb_build_object('status','rebuilt','travel_legs',v_count,'direct_transition_max_gap_days',v_gap_limit);
end; $$;

create or replace function public.process_travel_leg_v1(p_leg_id uuid)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare l public.player_travel_legs%rowtype; v_before smallint; v_after smallint; gd record; v_owner uuid;
begin
  select * into l from public.player_travel_legs where id=p_leg_id for update;
  if l.id is null then raise exception 'Travel leg not found.'; end if;
  if l.status='completed' then return jsonb_build_object('status','already_processed','travel_leg_id',l.id); end if;
  if l.status='cancelled' then return jsonb_build_object('status','cancelled','travel_leg_id',l.id); end if;

  select fatigue into v_before from public.player_skills where player_id=l.player_id for update;
  v_after:=least(100,coalesce(v_before,0)+l.arrival_fatigue)::smallint;
  update public.player_skills set fatigue=v_after,updated_at=now() where player_id=l.player_id;
  update public.player_location_state set current_city=l.destination_city,current_country_code=l.destination_country_code,current_continent=l.destination_continent,current_latitude=l.destination_latitude,current_longitude=l.destination_longitude,location_type=l.destination_location_type,source_reference_id=l.destination_reference_id,location_since_absolute_day=l.arrival_absolute_day,updated_at=now() where player_id=l.player_id;
  update public.player_travel_legs set status='completed',processed_at=now(),updated_at=now() where id=l.id;

  select * into gd from public.absolute_game_day_v1(l.departure_absolute_day);
  update public.player_daily_activity set effects_applied_at=coalesce(effects_applied_at,now()),effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object('travel_leg_id',l.id,'from',jsonb_build_object('city',l.source_city,'country_code',l.source_country_code),'to',jsonb_build_object('city',l.destination_city,'country_code',l.destination_country_code),'distance_km',l.distance_km,'fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before),updated_at=now()
  where player_id=l.player_id and season=gd.season and month=gd.month and day=gd.day and source='travel_plan' and reference_id=l.id::text;

  select owner_user_id into v_owner from public.players where id=l.player_id;
  perform public.emit_notification_v1(v_owner,l.player_id,'travel.arrived','Travel completed',format('You arrived in %s. Travel fatigue: +%s.',coalesce(l.destination_city,l.destination_country_code),l.arrival_fatigue),'/game/schedule',jsonb_build_object('travel_leg_id',l.id,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'distance_km',l.distance_km,'fatigue_change',l.arrival_fatigue),'travel-arrived:'||l.id::text);
  return jsonb_build_object('status','completed','travel_leg_id',l.id,'distance_km',l.distance_km,'estimated_cost',l.estimated_cost,'fatigue_before',v_before,'fatigue_after',v_after,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code);
end; $$;

create or replace function public.process_due_travel_legs_v1(p_player_id uuid,p_through_absolute_day integer)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare l record; v_count integer:=0; v_last jsonb:='{}'::jsonb;
begin
  for l in select id from public.player_travel_legs where player_id=p_player_id and status='planned' and arrival_absolute_day<=p_through_absolute_day order by arrival_absolute_day,created_at loop
    v_last:=public.process_travel_leg_v1(l.id); v_count:=v_count+1;
  end loop;
  return jsonb_build_object('processed',v_count,'last',v_last);
end; $$;

create or replace function public.sync_travel_plan_from_commitment_v1()
returns trigger
language plpgsql security definer
set search_path to 'public'
as $$
declare v_player uuid;
begin
  v_player:=coalesce(new.player_id,old.player_id);
  perform public.rebuild_player_travel_plan_v1(v_player);
  return coalesce(new,old);
end; $$;

drop trigger if exists player_training_camp_booking_travel_plan on public.player_training_camp_bookings;
create trigger player_training_camp_booking_travel_plan
after insert or update of status,start_absolute_day,end_absolute_day on public.player_training_camp_bookings
for each row execute function public.sync_travel_plan_from_commitment_v1();

drop trigger if exists tournament_application_travel_plan on public.tournament_applications;
create trigger tournament_application_travel_plan
after insert or update of status,competition_id or delete on public.tournament_applications
for each row execute function public.sync_travel_plan_from_commitment_v1();

create or replace function public.process_player_daily_activity_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine'::text)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_activity text; v_row public.player_daily_activity%rowtype; v_abs integer; v_travel jsonb;
begin
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);
  v_travel:=public.process_due_travel_legs_v1(p_player_id,v_abs);
  select * into v_row from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day for update;
  v_activity:=coalesce(v_row.activity_type,'home');
  if v_activity='home' then return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by); end if;
  if v_activity='travel' then
    return jsonb_build_object('status','completed','activity_type','travel','travel_processing',v_travel,'effect_summary',v_row.effect_summary);
  end if;
  if v_activity='training_camp' then return public.process_training_camp_day_v1(p_player_id,p_season,p_month,p_day,p_processed_by); end if;
  return jsonb_build_object('status','delegated','activity_type',v_activity,'travel_processing',v_travel,'reason',case v_activity when 'tournament' then 'Tournament/match engine owns this day; regular training is blocked.' when 'injured' then 'Injury/recovery engine owns this day; regular training is blocked.' else 'Regular training is blocked.' end);
end; $$;

create or replace function public.complete_training_camp_today_v1()
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare v_player_id uuid; d record; v_current_abs integer; v_booking public.player_training_camp_bookings%rowtype; g integer; gd record; v_result jsonb:='{}'::jsonb; v_processed integer:=0; v_travel jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=auth.uid(); if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into d from public.get_current_game_day_internal_v1(); v_current_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  v_travel:=public.process_due_travel_legs_v1(v_player_id,v_current_abs);
  select * into v_booking from public.player_training_camp_bookings where player_id=v_player_id and status in ('booked','active') and start_absolute_day<=v_current_abs order by start_absolute_day limit 1;
  if v_booking.id is null then return jsonb_build_object('status','blocked','reason','No training camp is due for processing today.','travel_processing',v_travel); end if;
  for g in v_booking.start_absolute_day..least(v_current_abs,v_booking.end_absolute_day) loop
    if not exists(select 1 from public.player_training_camp_days where booking_id=v_booking.id and absolute_day=g) then
      select * into gd from public.absolute_game_day_v1(g); v_result:=public.process_training_camp_day_v1(v_player_id,gd.season,gd.month,gd.day,'manual'); if v_result->>'status'='completed' then v_processed:=v_processed+1; end if;
    end if;
  end loop;
  if v_processed=0 then return jsonb_build_object('status','already_processed','booking_id',v_booking.id,'processed_days',0,'travel_processing',v_travel); end if;
  return v_result||jsonb_build_object('processed_days',v_processed,'catch_up',true,'travel_processing',v_travel);
end; $$;

create or replace function public.quote_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star'::text)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_user uuid:=auth.uid(); v_player public.players%rowtype; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_hotel public.training_camp_accommodation_tiers%rowtype;
  v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_training_total integer; v_hotel_weekly integer; v_hotel_total integer; v_travel integer; v_total integer;
  v_origin jsonb; v_travel_quote jsonb;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where owner_user_id=v_user; if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if;
  select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active;
  select * into v_hotel from public.training_camp_accommodation_tiers where slug=p_accommodation_slug and is_active; if v_hotel.id is null then raise exception 'Accommodation option not found.'; end if;
  if p_duration_weeks not between 1 and 4 then raise exception 'Training camp duration must be between 1 and 4 weeks.'; end if;
  if p_start_week not between 1 and 52 then raise exception 'Start week must be between 1 and 52.'; end if;
  if p_start_week+p_duration_weeks-1>52 then raise exception 'Training camp cannot extend beyond Season Week 52.'; end if;
  v_start_abs:=public.training_camp_week_start_absolute_v1(p_start_season,p_start_week); v_end_abs:=v_start_abs+p_duration_weeks*7-1;
  select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs<v_current_abs then raise exception 'Training camp must begin at the start of a current or future competition week.'; end if;
  select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);

  v_origin:=public.resolve_player_origin_before_day_v1(v_player.id,v_start_abs);
  v_training_total:=v_program.weekly_cost*p_duration_weeks;
  v_hotel_weekly:=round((v_hotel.base_weekly_cost*v_location.cost_index)/10.0)::integer*10; v_hotel_total:=v_hotel_weekly*p_duration_weeks;
  v_travel_quote:=public.training_camp_travel_quote_v2(v_origin->>'city',v_origin->>'country_code',v_location.city,v_location.country_code);
  v_travel:=(v_travel_quote->>'cost')::integer; v_total:=v_training_total+v_hotel_total+v_travel;
  return jsonb_build_object(
    'program_id',v_program.id,'camp_name',v_program.name,'training_quality',jsonb_build_object('tier',v_program.quality_tier,'multiplier',v_program.quality_multiplier),'quality_tier',v_program.quality_tier,'facility_rating',v_program.rating,'quality_multiplier',v_program.quality_multiplier,
    'start_season',p_start_season,'start_week',p_start_week,'start_absolute_day',v_start_abs,'end_absolute_day',v_end_abs,'start',jsonb_build_object('season',v_start.season,'month',v_start.month,'day',v_start.day),'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),'duration_weeks',p_duration_weeks,
    'origin',v_origin,
    'destination',jsonb_build_object('city',v_location.city,'country',v_location.country,'country_code',v_location.country_code,'continent',v_location.continent,'cost_index',v_location.cost_index),
    'training_fee_weekly',v_program.weekly_cost,'training_fee_total',v_training_total,
    'accommodation',jsonb_build_object('id',v_hotel.id,'slug',v_hotel.slug,'name',v_hotel.name,'stars',v_hotel.star_rating,'base_weekly_cost',v_hotel.base_weekly_cost,'destination_cost_index',v_location.cost_index,'weekly_cost',v_hotel_weekly,'total',v_hotel_total,'rest_quality',v_hotel.rest_quality,'fatigue_mitigation',v_hotel.fatigue_mitigation,'weekly_morale_bonus',v_hotel.weekly_morale_bonus,'weekly_focus_bonus',v_hotel.weekly_focus_bonus,'description',v_hotel.description),
    'travel',v_travel_quote,'travel_cost',v_travel,'travel_type','Round-trip estimate','staff_count',0,'staff_cost',0,'grand_total',v_total
  );
end; $$;

update public.player_location_state ls
set current_latitude=r.latitude,current_longitude=r.longitude,
    location_since_absolute_day=coalesce(ls.location_since_absolute_day,(select public.game_day_absolute_v1(season,month,day) from public.get_current_game_day_internal_v1())),updated_at=now()
from public.training_travel_country_reference r
where r.country_code=upper(ls.current_country_code)
  and (ls.current_latitude is null or ls.current_longitude is null);

do $$ declare p record; begin
  for p in select id from public.players loop
    perform public.rebuild_player_travel_plan_v1(p.id);
  end loop;
end $$;

do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    begin alter publication supabase_realtime add table public.player_travel_legs; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.player_location_state; exception when duplicate_object then null; end;
  end if;
end $$;