create or replace function public.default_tournament_match_day_v2(
  p_competition_id uuid,
  p_draw_type text,
  p_round_number integer
)
returns smallint
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_phase text;
  v_q_rounds integer;
  v_main_capacity integer;
  v_q_rest boolean;
  v_main_rest boolean;
  v_main_rounds integer;
  v_full_rest integer:=0;
  v_offset integer:=0;
  v_day integer;
begin
  if p_round_number is null or p_round_number<1 then return null; end if;
  if p_draw_type not in ('main_draw','qualification') then return null; end if;

  select sl.phase,
         tc.qualification_rounds_max,
         tc.main_draw_capacity,
         tc.qualification_rest_day_first,
         tc.main_draw_rest_day_first
  into v_phase,v_q_rounds,v_main_capacity,v_q_rest,v_main_rest
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories tc on tc.code=ts.category_code
  join public.tournament_schedule_slots sl on sl.tournament_edition_id=ed.id
  where wc.id=p_competition_id
    and sl.phase in (p_draw_type,'full')
  order by case when sl.phase=p_draw_type then 0 else 1 end,sl.slot_order
  limit 1;

  -- Dedicated qualification/main-draw weeks already have their own timing rules.
  -- This helper only normalises one-week events where qualification and main draw
  -- share the same seven-day "full" competition window.
  if v_phase is null or v_phase<>'full' then return null; end if;

  v_main_rounds:=ceil(ln(greatest(v_main_capacity,2)::numeric)/ln(2::numeric))::integer;
  if coalesce(v_q_rounds,0)+coalesce(v_main_rounds,0)<7
     and (coalesce(v_q_rest,false) or coalesce(v_main_rest,false)) then
    v_full_rest:=1;
  end if;

  if p_draw_type='qualification' then
    v_offset:=v_full_rest;
  else
    v_offset:=v_full_rest+coalesce(v_q_rounds,0);
  end if;

  v_day:=v_offset+p_round_number;
  if v_day>7 then return null; end if;
  return v_day::smallint;
end;
$$;

revoke all on function public.default_tournament_match_day_v2(uuid,text,integer) from public,anon,authenticated;

create or replace function public.apply_default_tournament_match_day_v2()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_day smallint;
begin
  if new.round_number is null then return new; end if;
  if new.schedule_reason is not null and new.schedule_reason not in ('standard','draw_publication') then return new; end if;
  v_day:=public.default_tournament_match_day_v2(new.competition_id,new.draw_type,new.round_number);
  if v_day is not null then new.scheduled_day:=v_day; end if;
  return new;
end;
$$;

drop trigger if exists trg_apply_default_tournament_match_day_v2 on public.tournament_matches;
create trigger trg_apply_default_tournament_match_day_v2
before insert on public.tournament_matches
for each row execute function public.apply_default_tournament_match_day_v2();

create or replace function public.player_tournament_commitment_unresolved_v1(
  p_player_id uuid,
  p_reference_id text
)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select case
    when coalesce(p_reference_id,'')~*'^[0-9a-f-]{36}$' then exists(
      select 1
      from public.tournament_entries e
      join public.tournament_world_competitions wc on wc.id=e.competition_id
      join public.tournament_editions ed on ed.id=wc.tournament_edition_id
      where e.player_id=p_player_id
        and e.competition_id=p_reference_id::uuid
        and e.entry_status='active'
        and wc.status<>'canceled'
        and ed.status<>'canceled'
    )
    else false
  end;
$$;

revoke all on function public.player_tournament_commitment_unresolved_v1(uuid,text) from public,anon,authenticated;

create or replace function public.rebuild_player_travel_plan_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
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
  homep jsonb;
  v_return_home boolean;
  v_unresolved_tournament boolean:=false;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.';end if;

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
      p_player_id,v_player.home_city,v_player.country_code,
      public.country_continent_v1(v_player.country_code),'home',v_current,now()
    ) on conflict(player_id) do nothing;
    select * into v_state from public.player_location_state where player_id=p_player_id;
  end if;

  v_source_city:=coalesce(v_state.current_city,v_player.home_city);
  v_source_country:=coalesce(v_state.current_country_code,v_player.country_code);
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
        v_return_home:=c.start_absolute_day>v_prev_end+1;
      else
        v_return_home:=(c.start_absolute_day-v_prev_end-1)>v_gap_limit;
      end if;
    end if;

    if v_return_home then
      homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);
      v_depart:=greatest(v_current,v_prev_end+1);
      perform public.insert_planned_travel_leg_v1(
        p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
        'home',v_player.home_city,v_player.country_code,
        nullif(homep->>'latitude','')::double precision,nullif(homep->>'longitude','')::double precision,null,
        v_depart,v_depart,false
      );
      v_count:=v_count+1;
      v_source_city:=v_player.home_city;
      v_source_country:=v_player.country_code;
      v_source_type:='home';
      v_source_ref:=null;
      v_source_lat:=nullif(homep->>'latitude','')::double precision;
      v_source_lon:=nullif(homep->>'longitude','')::double precision;
    end if;

    q:=public.resolve_location_coordinates_v1(c.city,c.country_code,c.latitude,c.longitude);
    v_depart:=greatest(v_current,c.start_absolute_day-1);
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
    homep:=public.resolve_location_coordinates_v1(v_player.home_city,v_player.country_code,null,null);
    v_depart:=greatest(v_current,v_prev_end+1);
    if public.insert_planned_travel_leg_v1(
      p_player_id,'return_home',v_source_type,v_source_city,v_source_country,v_source_lat,v_source_lon,v_source_ref,
      'home',v_player.home_city,v_player.country_code,
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
$$;

do $$
declare
  v_current integer;
begin
  select public.game_day_absolute_v1(season,month,day)
  into v_current
  from public.get_current_game_day_internal_v1();

  update public.tournament_matches m
  set scheduled_day=public.default_tournament_match_day_v2(m.competition_id,m.draw_type,m.round_number),
      updated_at=now()
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  where wc.id=m.competition_id
    and wc.status<>'canceled'
    and ed.status<>'canceled'
    and m.status in ('scheduled','bye','cancelled')
    and public.default_tournament_match_day_v2(m.competition_id,m.draw_type,m.round_number) is not null
    and m.scheduled_day is distinct from public.default_tournament_match_day_v2(m.competition_id,m.draw_type,m.round_number)
    and exists(
      select 1
      from public.tournament_schedule_slots sl
      where sl.tournament_edition_id=ed.id
        and sl.phase='full'
        and (((ed.season_number-1)*366)+2+((sl.season_week-1)*7)+6)>=v_current
    );
end;
$$;

do $$
declare
  v_current integer;
  r record;
  v_fatigue_change integer;
  v_travel_refund bigint;
  v_hotel_refund bigint;
begin
  select public.game_day_absolute_v1(season,month,day)
  into v_current
  from public.get_current_game_day_internal_v1();

  for r in
    select l.*,fm.first_day
    from public.player_travel_legs l
    join public.players p on p.id=l.player_id
    left join lateral (
      select min(public.tournament_match_absolute_day_v2(m.id))::integer first_day
      from public.tournament_matches m
      where m.competition_id=l.destination_reference_id::uuid
        and (m.player1_id=l.player_id or m.player2_id=l.player_id)
        and m.status not in ('bye','cancelled')
    ) fm on coalesce(l.destination_reference_id,'')~*'^[0-9a-f-]{36}$'
    where l.status='completed'
      and p.player_type='human'
      and p.owner_user_id is not null
      and l.destination_location_type='tournament'
      and coalesce(l.destination_reference_id,'')~*'^[0-9a-f-]{36}$'
      and fm.first_day is not null
      and fm.first_day>v_current
      and l.departure_absolute_day<fm.first_day-1
      and exists(
        select 1 from public.tournament_entries te
        where te.player_id=l.player_id
          and te.competition_id=l.destination_reference_id::uuid
          and te.entry_status='active'
      )
      and exists(
        select 1 from public.player_location_state pls
        where pls.player_id=l.player_id
          and pls.location_type='tournament'
          and pls.source_reference_id=l.destination_reference_id
      )
      and not exists(
        select 1 from public.tournament_matches played
        where played.competition_id=l.destination_reference_id::uuid
          and (played.player1_id=l.player_id or played.player2_id=l.player_id)
          and played.status in ('in_progress','completed','walkover')
      )
  loop
    select coalesce((a.effect_summary->>'fatigue_change')::integer,0)
    into v_fatigue_change
    from public.player_daily_activity a
    where a.player_id=r.player_id
      and a.source='travel_plan'
      and a.reference_id=r.id::text
    limit 1;
    v_fatigue_change:=coalesce(v_fatigue_change,0);

    select coalesce(-sum(t.amount),0)::bigint
    into v_travel_refund
    from public.career_finance_transactions t
    where t.player_id=r.player_id
      and t.source_type='travel_leg'
      and t.source_id=r.id::text
      and t.amount<0;

    if v_travel_refund>0 then
      perform public.post_career_finance_transaction_v1(
        r.player_id,v_travel_refund,'travel','schedule_adjustment_refund',
        format('Travel rescheduled to the confirmed tournament arrival window: %s',coalesce(r.destination_city,r.destination_country_code)),
        'travel_leg_reschedule',r.id::text,'travel-reschedule-refund:'||r.id::text,
        jsonb_build_object('reason','phase_aware_match_schedule_correction','original_travel_leg_id',r.id,'competition_id',r.destination_reference_id),
        false,v_current
      );
    end if;

    select coalesce(-sum(t.amount),0)::bigint
    into v_hotel_refund
    from public.career_finance_transactions t
    where t.player_id=r.player_id
      and t.source_type='tournament'
      and t.source_id=r.destination_reference_id
      and t.category='hotel'
      and t.amount<0
      and t.game_absolute_day<r.first_day-1;

    if v_hotel_refund>0 then
      perform public.post_career_finance_transaction_v1(
        r.player_id,v_hotel_refund,'hotel','schedule_adjustment_refund',
        format('Early tournament hotel charge refunded: %s',coalesce(r.destination_city,r.destination_country_code)),
        'tournament_schedule_reschedule',r.destination_reference_id,
        'tournament-early-hotel-refund:'||r.destination_reference_id||':'||r.first_day::text,
        jsonb_build_object('reason','phase_aware_match_schedule_correction','competition_id',r.destination_reference_id,'first_match_absolute_day',r.first_day),
        false,v_current
      );
    end if;

    if v_fatigue_change>0 then
      update public.player_skills
      set fatigue=greatest(0,coalesce(fatigue,0)-v_fatigue_change)::smallint,
          updated_at=now()
      where player_id=r.player_id;
    end if;

    update public.player_location_state
    set current_city=r.source_city,
        current_country_code=r.source_country_code,
        current_continent=r.source_continent,
        current_latitude=r.source_latitude,
        current_longitude=r.source_longitude,
        location_type=coalesce(r.source_location_type,'home'),
        source_reference_id=r.source_reference_id,
        location_since_absolute_day=v_current,
        updated_at=now()
    where player_id=r.player_id;

    update public.player_daily_activity
    set activity_type='home',source=null,reference_id=null,note=null,
        effects_applied_at=null,effect_summary='{}'::jsonb,updated_at=now()
    where player_id=r.player_id
      and source='travel_plan'
      and reference_id=r.id::text;

    update public.player_travel_legs
    set status='cancelled',updated_at=now()
    where id=r.id;

    perform public.rebuild_player_travel_plan_v1(r.player_id);
  end loop;
end;
$$;
