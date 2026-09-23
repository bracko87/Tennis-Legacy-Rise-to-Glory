
create unique index if not exists national_fixture_window_pair_uq
  on public.national_team_fixtures(
    window_id,
    least(home_association_id::text,away_association_id::text),
    greatest(home_association_id::text,away_association_id::text)
  )
  where status<>'cancelled';

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
        if not exists(
          select 1
          from public.national_team_fixtures f
          where f.window_id=w.id
            and f.status<>'cancelled'
            and (
              (f.home_association_id=pending and f.away_association_id=team.association_id)
              or
              (f.home_association_id=team.association_id and f.away_association_id=pending)
            )
        ) then
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
        end if;

        pending:=null;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

create or replace function public.process_national_team_deadlines_v1()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_day integer:=public.national_team_current_abs_day_v1();
  v_now bigint:=public.current_game_second_v1();
  w record;
  f record;
  v_home_ready boolean;
  v_away_ready boolean;
  v_announced integer:=0;
  v_pairings integer:=0;
  v_lineups integer:=0;
begin
  perform public.ensure_national_team_windows_v1((v_day/366)+1);
  perform public.ensure_national_team_windows_v1((v_day/366)+2);

  for w in
    select *
    from public.national_team_windows
    where status in ('planned','announced','in_progress')
  loop
    if w.status='planned' and v_day>=w.announcement_absolute_day then
      update public.national_team_windows
      set status=case when v_day>=w.start_absolute_day then 'in_progress' else 'announced' end,
          updated_at=now()
      where id=w.id;
      v_announced:=v_announced+1;
    end if;

    if v_day>=w.announcement_absolute_day and v_day<=w.end_absolute_day then
      v_pairings:=v_pairings+public.schedule_national_window_pairings_v1(w.id);
    end if;

    if v_day>=w.start_absolute_day and v_day<=w.end_absolute_day then
      update public.national_team_windows
      set status='in_progress',updated_at=now()
      where id=w.id and status in ('planned','announced');
    elsif v_day>w.end_absolute_day then
      update public.national_team_windows
      set status='completed',updated_at=now()
      where id=w.id and status='in_progress';
    end if;
  end loop;

  update public.national_team_callups c
  set status='expired',updated_at=now()
  where c.status='pending'
    and v_day>c.response_deadline_absolute_day;

  for f in
    select *
    from public.national_team_fixtures
    where status in ('planned','announced','lineups_pending')
  loop
    if f.status='planned' and exists(
      select 1
      from public.national_team_windows nw
      where nw.id=f.window_id and v_day>=nw.announcement_absolute_day
    ) then
      update public.national_team_fixtures
      set status='announced',announced_game_day=coalesce(announced_game_day,v_day),updated_at=now()
      where id=f.id;
    end if;

    if v_now>=f.lineup_deadline_game_second then
      if not exists(
        select 1
        from public.national_team_lineups
        where fixture_id=f.id
          and association_id=f.home_association_id
          and status in ('locked','auto_locked')
      ) then
        perform public.autofill_national_team_lineup_v1(f.id,f.home_association_id);
      end if;

      if not exists(
        select 1
        from public.national_team_lineups
        where fixture_id=f.id
          and association_id=f.away_association_id
          and status in ('locked','auto_locked')
      ) then
        perform public.autofill_national_team_lineup_v1(f.id,f.away_association_id);
      end if;

      v_home_ready:=exists(
        select 1
        from public.national_team_lineups
        where fixture_id=f.id
          and association_id=f.home_association_id
          and status in ('locked','auto_locked')
      );
      v_away_ready:=exists(
        select 1
        from public.national_team_lineups
        where fixture_id=f.id
          and association_id=f.away_association_id
          and status in ('locked','auto_locked')
      );

      if v_home_ready and v_away_ready then
        perform public.reveal_national_team_lineups_v1(f.id);
        v_lineups:=v_lineups+1;
      else
        perform public.finalize_national_fixture_forfeit_v1(
          f.id,v_home_ready,v_away_ready
        );
      end if;
    end if;
  end loop;

  for f in
    select a.id
    from public.national_associations a
    where a.status in ('active','renewal_required')
  loop
    perform public.ensure_national_association_season_grant_v1(
      f.id,(v_day/366)+1
    );
  end loop;

  return jsonb_build_object(
    'game_day',v_day,
    'windows_announced',v_announced,
    'pairings_created',v_pairings,
    'lineups_processed',v_lineups
  );
end;
$$;

revoke execute on function public.schedule_national_window_pairings_v1(uuid) from anon,authenticated;
revoke execute on function public.process_national_team_deadlines_v1() from anon,authenticated;
