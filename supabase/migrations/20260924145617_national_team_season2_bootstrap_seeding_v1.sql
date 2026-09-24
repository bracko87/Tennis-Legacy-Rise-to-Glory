
create or replace function public.national_team_bootstrap_division_v1(
  p_association_id uuid,
  p_display_season integer
)
returns uuid
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  cfg public.national_team_competition_config%rowtype;
  a public.national_associations%rowtype;
  v_global_rank integer;
  v_regional_rank integer;
  v_group integer;
  v_division uuid;
begin
  select * into cfg from public.national_team_competition_config where id=1;
  select * into a from public.national_associations where id=p_association_id;

  if not found or a.status not in ('active','renewal_required') then return null; end if;
  if p_display_season<>cfg.official_launch_season then return null; end if;

  select count(*)::integer
  into v_global_rank
  from public.national_associations x
  where x.world=a.world
    and x.status in ('active','renewal_required')
    and (
      x.activated_game_day<a.activated_game_day
      or (x.activated_game_day=a.activated_game_day and x.id<=a.id)
    );

  if v_global_rank<=32 then
    select id into v_division
    from public.national_team_divisions
    where world=a.world and region_code='GLOBAL' and division_code='qualifier_r1' and is_active
    limit 1;
    return v_division;
  elsif v_global_rank<=64 then
    select id into v_division
    from public.national_team_divisions
    where world=a.world and region_code='GLOBAL' and division_code='world_group_i' and is_active
    limit 1;
    return v_division;
  elsif v_global_rank<=96 then
    select id into v_division
    from public.national_team_divisions
    where world=a.world and region_code='GLOBAL' and division_code='world_group_ii' and is_active
    limit 1;
    return v_division;
  end if;

  select count(*)::integer
  into v_regional_rank
  from public.national_associations x
  where x.world=a.world
    and x.region_code=a.region_code
    and x.status in ('active','renewal_required')
    and (
      (
        select count(*)::integer
        from public.national_associations y
        where y.world=x.world
          and y.status in ('active','renewal_required')
          and (
            y.activated_game_day<x.activated_game_day
            or (y.activated_game_day=x.activated_game_day and y.id<=x.id)
          )
      )>96
    )
    and (
      x.activated_game_day<a.activated_game_day
      or (x.activated_game_day=a.activated_game_day and x.id<=a.id)
    );

  v_group:=greatest(1,ceil(v_regional_rank/8.0)::integer);

  perform public.ensure_national_team_regional_capacity_v1(a.world,a.region_code);

  select id into v_division
  from public.national_team_divisions
  where world=a.world
    and region_code=a.region_code
    and division_code='regional_group_'||v_group::text
    and is_active
  limit 1;

  if v_division is null then
    select id into v_division
    from public.national_team_divisions
    where world=a.world
      and region_code=a.region_code
      and is_active
    order by tier_level desc
    limit 1;
  end if;

  return v_division;
end;
$$;

create or replace function public.get_national_team_pyramid_v1(
  p_world text,
  p_display_season integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  cfg public.national_team_competition_config%rowtype;
  v_divisions jsonb;
begin
  select * into cfg from public.national_team_competition_config where id=1;

  with placements as (
    select
      e.association_id,
      e.division_id,
      'official'::text placement_state
    from public.national_team_division_entries e
    join public.national_associations a on a.id=e.association_id
    where e.season_number=p_display_season
      and e.status in ('active','completed')
      and a.world=p_world
      and a.status in ('active','renewal_required')

    union all

    select
      a.id,
      public.national_team_bootstrap_division_v1(a.id,p_display_season),
      'projected'::text
    from public.national_associations a
    where a.world=p_world
      and a.status in ('active','renewal_required')
      and public.national_team_bootstrap_division_v1(a.id,p_display_season) is not null
      and not exists(
        select 1
        from public.national_team_division_entries e
        where e.association_id=a.id
          and e.season_number=p_display_season
          and e.status in ('active','completed')
      )
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'division_id',d.id,
      'region_code',d.region_code,
      'division_code',d.division_code,
      'label',d.label,
      'tier_level',d.tier_level,
      'capacity',d.capacity,
      'promotion_slots',d.promotion_slots,
      'relegation_slots',d.relegation_slots,
      'is_global',d.region_code='GLOBAL',
      'associations',coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'association_id',a.id,
            'name',a.name,
            'country_code',a.country_code,
            'placement_state',p.placement_state
          )
          order by a.activated_game_day,a.country_code
        )
        from placements p
        join public.national_associations a on a.id=p.association_id
        where p.division_id=d.id
      ),'[]'::jsonb)
    )
    order by d.tier_level,d.sort_order,d.region_code,d.division_code
  ),'[]'::jsonb)
  into v_divisions
  from public.national_team_divisions d
  where d.world=p_world and d.is_active;

  return jsonb_build_object(
    'world',p_world,
    'display_season',p_display_season,
    'official_launch_season',cfg.official_launch_season,
    'divisions',v_divisions
  );
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
begin
  select * into cfg from public.national_team_competition_config where id=1;
  if p_season_number<cfg.official_launch_season then return 0; end if;

  for a in
    select na.*
    from public.national_associations na
    where na.activated_game_day is not null
      and na.status in ('active','renewal_required')
    order by na.activated_game_day,na.country_code
  loop
    if exists(
      select 1
      from public.national_team_division_entries e
      where e.association_id=a.id
        and e.season_number=p_season_number
        and e.status='active'
    ) then
      continue;
    end if;

    target_division:=null;

    if p_season_number=cfg.official_launch_season then
      target_division:=public.national_team_bootstrap_division_v1(a.id,p_season_number);
    else
      select e.division_id,e.sporting_outcome,d.tier_level,d.region_code
      into prev
      from public.national_team_division_entries e
      join public.national_team_divisions d on d.id=e.division_id
      where e.association_id=a.id
        and e.season_number=p_season_number-1
      order by e.created_at desc
      limit 1;

      if prev.division_id is null then
        perform public.ensure_national_team_regional_capacity_v1(a.world,a.region_code);

        select id into target_division
        from public.national_team_divisions
        where world=a.world
          and region_code=a.region_code
          and is_active
        order by tier_level desc
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
    end if;

    if target_division is not null then
      insert into public.national_team_division_entries(
        association_id,division_id,season_number,status,entry_reason
      )
      values(
        a.id,target_division,p_season_number,'active',
        case
          when p_season_number=cfg.official_launch_season then 'bootstrap'
          when prev.division_id is null then 'new_association'
          when prev.sporting_outcome='promoted' then 'promoted'
          when prev.sporting_outcome='relegated' then 'relegated'
          else 'retained'
        end
      )
      on conflict(association_id,season_number) do nothing;

      if found then created_count:=created_count+1; end if;
    end if;
  end loop;

  return created_count;
end;
$$;

revoke all on function public.national_team_bootstrap_division_v1(uuid,integer) from public,anon,authenticated;
