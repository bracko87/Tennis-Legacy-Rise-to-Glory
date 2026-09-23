
create or replace function public.schedule_national_window_pairings_v1(
  p_window_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  w public.national_team_windows%rowtype;
  d record;
  team record;
  pending uuid:=null;
  v_count integer:=0;
  v_country text;
  v_city text;
  v_lat double precision;
  v_lon double precision;
begin
  select * into w from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;

  for d in
    select id
    from public.national_team_divisions
    where world=w.world and is_active
    order by tier_level,sort_order,division_code
  loop
    pending:=null;

    for team in
      select e.association_id
      from public.national_team_division_entries e
      join public.national_associations a on a.id=e.association_id
      left join public.national_team_division_standings s
        on s.division_id=e.division_id
       and s.season_number=e.season_number
       and s.association_id=e.association_id
      where e.division_id=d.id
        and e.season_number=w.season_number
        and e.status='active'
        and a.status in ('active','renewal_required')
      order by
        coalesce(s.standings_points,0) desc,
        coalesce(s.ties_won,0) desc,
        a.country_code
    loop
      if pending is null then
        pending:=team.association_id;
      else
        select a.country_code into v_country
        from public.national_associations a
        where a.id=pending;

        v_city:=null;
        v_lat:=null;
        v_lon:=null;

        select h.city,h.latitude,h.longitude
        into v_city,v_lat,v_lon
        from public.player_home_city_options h
        where h.country_code=v_country and h.is_active
        order by h.sort_order,h.city
        limit 1;

        if v_city is null then
          select l.city,l.latitude,l.longitude
          into v_city,v_lat,v_lon
          from public.travel_locations l
          where l.country_code=v_country and l.is_active
          order by l.city
          limit 1;
        end if;

        if v_city is null then
          select c.name into v_city
          from public.countries c
          where c.code=v_country;
        end if;

        perform public.create_national_team_fixture_v1(
          w.id,
          pending,
          team.association_id,
          d.id,
          pending,
          null,
          v_city,
          v_country,
          v_lat,
          v_lon,
          'hard',
          'indoor',
          w.start_absolute_day,
          'five_match_standard'
        );

        v_count:=v_count+1;
        pending:=null;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

create or replace function public.check_player_national_window_availability_v1(
  p_player_id uuid,
  p_fixture_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  p public.players%rowtype;
  v_block record;
  v_existing public.player_calendar_commitments%rowtype;
  v_location_key text;
begin
  select * into f
  from public.national_team_fixtures
  where id=p_fixture_id;

  if not found then
    return jsonb_build_object('available',false,'reason','fixture_missing');
  end if;

  select * into w
  from public.national_team_windows
  where id=f.window_id;

  select * into p
  from public.players
  where id=p_player_id;

  if p.id is null or p.moderation_status='rejected' then
    return jsonb_build_object('available',false,'reason','player_unavailable');
  end if;

  if p.world<>w.world then
    return jsonb_build_object('available',false,'reason','different_world');
  end if;

  v_location_key:=format(
    'national:%s:%s:%s',
    w.id,
    f.host_country_code,
    lower(regexp_replace(f.host_city,'\s+','-','g'))
  );

  select c.* into v_existing
  from public.player_calendar_commitments c
  where c.player_id=p_player_id
    and c.source_type='national_team'
    and c.source_id=w.id
    and c.status='committed'
  limit 1;

  if v_existing.id is not null then
    if v_existing.location_key is distinct from v_location_key then
      return jsonb_build_object(
        'available',false,
        'reason','national_window_different_location',
        'existing_location_key',v_existing.location_key,
        'requested_location_key',v_location_key
      );
    end if;

    return jsonb_build_object(
      'available',true,
      'reason','already_committed_same_national_window',
      'window_id',w.id,
      'start_absolute_day',w.start_absolute_day,
      'end_absolute_day',w.end_absolute_day,
      'location_key',v_location_key
    );
  end if;

  select b.id,b.start_absolute_day,b.end_absolute_day
  into v_block
  from public.player_training_camp_bookings b
  where b.player_id=p_player_id
    and b.status in ('booked','active')
    and b.start_absolute_day<=w.end_absolute_day
    and b.end_absolute_day>=w.start_absolute_day
  order by b.start_absolute_day
  limit 1;

  if v_block.id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','training_camp_overlap',
      'blocking_training_camp_id',v_block.id,
      'blocking_start_absolute_day',v_block.start_absolute_day,
      'blocking_end_absolute_day',v_block.end_absolute_day
    );
  end if;

  v_block:=null;

  select te.competition_id,ts.name,ts.city
  into v_block
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(te.competition_id) cw
  where te.player_id=p_player_id
    and te.entry_status='active'
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
    and not public.is_national_team_engine_competition_v1(te.competition_id)
  order by cw.start_absolute_day
  limit 1;

  if v_block.competition_id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','singles_entry_overlap',
      'blocking_competition_id',v_block.competition_id,
      'blocking_tournament',v_block.name,
      'blocking_city',v_block.city
    );
  end if;

  v_block:=null;

  select a.competition_id,ts.name,ts.city
  into v_block
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id=a.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) cw
  where a.player_id=p_player_id
    and a.status in ('accepted_main_draw','accepted_qualification')
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
  order by cw.start_absolute_day
  limit 1;

  if v_block.competition_id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','accepted_singles_overlap',
      'blocking_competition_id',v_block.competition_id,
      'blocking_tournament',v_block.name,
      'blocking_city',v_block.city
    );
  end if;

  v_block:=null;

  select dt.competition_id,ts.name,ts.city
  into v_block
  from public.tournament_doubles_teams dt
  join public.tournament_world_competitions wc on wc.id=dt.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(dt.competition_id) cw
  where (dt.player1_id=p_player_id or dt.player2_id=p_player_id)
    and dt.status in ('confirmed','active','alternate')
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
    and not public.is_national_team_engine_competition_v1(dt.competition_id)
  order by cw.start_absolute_day
  limit 1;

  if v_block.competition_id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','doubles_entry_overlap',
      'blocking_competition_id',v_block.competition_id,
      'blocking_tournament',v_block.name,
      'blocking_city',v_block.city
    );
  end if;

  if exists(
    select 1
    from public.player_calendar_commitments c
    where c.player_id=p_player_id
      and c.status='committed'
      and not (c.source_type='national_team' and c.source_id=w.id)
      and c.starts_absolute_day<=w.end_absolute_day
      and c.ends_absolute_day>=w.start_absolute_day
  ) then
    return jsonb_build_object(
      'available',false,
      'reason','calendar_commitment_overlap'
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'reason','available',
    'window_id',w.id,
    'start_absolute_day',w.start_absolute_day,
    'end_absolute_day',w.end_absolute_day,
    'location_key',v_location_key
  );
end;
$$;

revoke execute on function public.schedule_national_window_pairings_v1(uuid) from anon,authenticated;
revoke execute on function public.check_player_national_window_availability_v1(uuid,uuid) from anon,authenticated;
