
create or replace function public.schedule_national_window_pairings_v1(p_window_id uuid)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  w public.national_team_windows%rowtype;
  cfg public.national_team_competition_config%rowtype;
  d record;
  team record;
  pending uuid:=null;
  v_count integer:=0;
  v_country text;
  v_city text;
  v_lat double precision;
  v_lon double precision;
  v_fixture uuid;
begin
  select * into w from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;

  select * into cfg from public.national_team_competition_config where id=1;

  if w.season_number<cfg.official_launch_season or w.window_mode='friendly_only' then
    pending:=null;

    for team in
      select a.id association_id
      from public.national_associations a
      where a.world=w.world
        and a.status in ('active','renewal_required')
      order by a.activated_game_day,a.country_code
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
          select country_code into v_country
          from public.national_associations
          where id=pending;

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
            select name into v_city from public.countries where code=v_country;
          end if;

          v_fixture:=public.create_national_team_fixture_v1(
            w.id,pending,team.association_id,null,pending,null,
            v_city,v_country,v_lat,v_lon,'hard','indoor',
            w.start_absolute_day,'five_match_standard'
          );

          update public.national_team_fixtures
          set fixture_kind='friendly',updated_at=now()
          where id=v_fixture;

          v_count:=v_count+1;
        end if;
        pending:=null;
      end if;
    end loop;

    return v_count;
  end if;

  for d in
    select id,region_code,tier_level
    from public.national_team_divisions
    where world=w.world
      and is_active
      and (
        (w.window_number=1 and region_code='GLOBAL' and tier_level between 3 and 5)
        or
        (w.window_number=2 and region_code<>'GLOBAL')
        or
        (w.window_number=3 and region_code='GLOBAL' and tier_level between 2 and 5)
        or
        (w.window_number=4 and region_code='GLOBAL' and tier_level=1)
      )
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
      order by coalesce(s.standings_points,0) desc,
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
          select country_code into v_country
          from public.national_associations
          where id=pending;

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
            select name into v_city from public.countries where code=v_country;
          end if;

          v_fixture:=public.create_national_team_fixture_v1(
            w.id,pending,team.association_id,d.id,pending,null,
            v_city,v_country,v_lat,v_lon,'hard','indoor',
            w.start_absolute_day,'five_match_standard'
          );

          update public.national_team_fixtures
          set fixture_kind='official',updated_at=now()
          where id=v_fixture;

          v_count:=v_count+1;
        end if;
        pending:=null;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

create or replace function public.prepare_national_team_division_entries_v1(p_season_number integer)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  cfg public.national_team_competition_config%rowtype;
  a record;
  prev record;
  target_division uuid;
  target_tier integer;
  created_count integer:=0;
  activation_rank integer;
  group_no integer;
begin
  select * into cfg from public.national_team_competition_config where id=1;

  if p_season_number<cfg.official_launch_season then
    return 0;
  end if;

  for a in
    select na.*
    from public.national_associations na
    where na.activated_game_day is not null
      and na.status in ('active','renewal_required')
      and (
        p_season_number=na.activated_season
        or exists(
          select 1
          from public.national_association_funds f
          where f.association_id=na.id
            and f.fund_type='season_renewal'
            and f.season_number=p_season_number
            and f.status='completed'
        )
      )
    order by na.activated_game_day,na.country_code
  loop
    perform public.ensure_national_team_regional_capacity_v1(a.world,a.region_code);

    if exists(
      select 1
      from public.national_team_division_entries e
      where e.association_id=a.id
        and e.season_number=p_season_number
        and e.status='active'
    ) then
      continue;
    end if;

    select e.division_id,e.sporting_outcome,d.tier_level,d.region_code
    into prev
    from public.national_team_division_entries e
    join public.national_team_divisions d on d.id=e.division_id
    where e.association_id=a.id
      and e.season_number=p_season_number-1
    order by e.created_at desc
    limit 1;

    target_division:=null;

    if prev.division_id is null then
      select count(*)::integer+1 into activation_rank
      from public.national_associations x
      where x.world=a.world
        and x.region_code=a.region_code
        and x.status in ('active','renewal_required')
        and (
          x.activated_game_day<a.activated_game_day
          or (x.activated_game_day=a.activated_game_day and x.id<a.id)
        );

      group_no:=3+floor((activation_rank-1)/8.0)::integer;

      select d.id into target_division
      from public.national_team_divisions d
      where d.world=a.world
        and d.region_code=a.region_code
        and d.tier_level=group_no+5
        and d.is_active
      limit 1;
    elsif prev.sporting_outcome='promoted' then
      if prev.region_code<>'GLOBAL' and prev.tier_level=6 then
        select id into target_division
        from public.national_team_divisions
        where world=a.world and region_code='GLOBAL' and tier_level=5 and is_active
        limit 1;
      else
        target_tier:=greatest(1,prev.tier_level-1);
        select id into target_division
        from public.national_team_divisions
        where world=a.world
          and region_code=prev.region_code
          and tier_level=target_tier
          and is_active
        limit 1;
      end if;
    elsif prev.sporting_outcome='relegated' then
      if prev.region_code='GLOBAL' and prev.tier_level=5 then
        select id into target_division
        from public.national_team_divisions
        where world=a.world and region_code=a.region_code and tier_level=6 and is_active
        limit 1;
      else
        target_tier:=prev.tier_level+1;
        select id into target_division
        from public.national_team_divisions
        where world=a.world
          and region_code=case when prev.region_code='GLOBAL' then 'GLOBAL' else a.region_code end
          and tier_level=target_tier
          and is_active
        limit 1;

        if target_division is null and prev.region_code<>'GLOBAL' then
          perform public.ensure_national_team_regional_capacity_v1(a.world,a.region_code);

          select id into target_division
          from public.national_team_divisions
          where world=a.world and region_code=a.region_code and is_active
          order by tier_level desc
          limit 1;
        end if;
      end if;
    else
      target_division:=prev.division_id;
    end if;

    if target_division is not null then
      insert into public.national_team_division_entries(
        association_id,division_id,season_number,status,entry_reason
      )
      values(
        a.id,target_division,p_season_number,'active',
        case
          when prev.division_id is null then 'new_association'
          when prev.sporting_outcome='promoted' then 'promoted'
          when prev.sporting_outcome='relegated' then 'relegated'
          else 'retained'
        end
      )
      on conflict(association_id,season_number) do nothing;

      if found then
        created_count:=created_count+1;
      end if;
    end if;
  end loop;

  return created_count;
end;
$$;

revoke all on function public.schedule_national_window_pairings_v1(uuid) from public,anon,authenticated;
revoke all on function public.prepare_national_team_division_entries_v1(integer) from public,anon,authenticated;
