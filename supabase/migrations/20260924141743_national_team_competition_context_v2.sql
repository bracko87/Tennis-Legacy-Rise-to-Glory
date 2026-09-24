
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

  with active_ranked as (
    select
      a.id,a.name,a.country_code,a.world,a.region_code,a.activated_game_day,
      row_number() over(
        partition by a.world,a.region_code
        order by a.activated_game_day,a.country_code,a.id
      )::integer activation_rank
    from public.national_associations a
    where a.world=p_world
      and a.status in ('active','renewal_required')
  ),
  placements as (
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
      ar.id,
      d.id,
      'projected'::text
    from active_ranked ar
    join public.national_team_divisions d
      on d.world=ar.world
     and d.region_code=ar.region_code
     and d.tier_level=(3+floor((ar.activation_rank-1)/8.0)::integer)+5
     and d.is_active
    where not exists(
      select 1
      from public.national_team_division_entries e
      where e.association_id=ar.id
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
          order by a.country_code
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
  where d.world=p_world
    and d.is_active;

  return jsonb_build_object(
    'world',p_world,
    'display_season',p_display_season,
    'official_launch_season',cfg.official_launch_season,
    'divisions',v_divisions
  );
end;
$$;

create or replace function public.get_my_national_team_competition_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  base jsonb;
  cfg public.national_team_competition_config%rowtype;
  v_world text;
  v_season integer;
  v_display_season integer;
  v_windows jsonb;
  v_pyramid jsonb;
  v_assoc uuid;
  v_projected_entry jsonb;
begin
  base:=public.get_my_national_team_competition_v1();

  if not coalesce((base->>'available')::boolean,false) then
    return base;
  end if;

  select * into cfg
  from public.national_team_competition_config
  where id=1;

  v_world:=base->>'world';
  v_season:=(base->>'season_number')::integer;
  v_assoc:=(base->>'association_id')::uuid;
  v_display_season:=greatest(v_season,cfg.official_launch_season);

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',w.id,
      'season_number',w.season_number,
      'window_code',w.window_code,
      'label',w.label,
      'season_week',w.season_week,
      'start_absolute_day',w.start_absolute_day,
      'end_absolute_day',w.end_absolute_day,
      'announcement_absolute_day',w.announcement_absolute_day,
      'callup_deadline_absolute_day',w.callup_deadline_absolute_day,
      'squad_deadline_absolute_day',w.squad_deadline_absolute_day,
      'status',w.status,
      'window_number',w.window_number,
      'window_mode',w.window_mode,
      'competition_phase',w.competition_phase,
      'official_from_season',w.official_from_season,
      'allows_friendlies',w.allows_friendlies
    )
    order by w.season_number,w.start_absolute_day
  ),'[]'::jsonb)
  into v_windows
  from public.national_team_windows w
  where w.world=v_world
    and w.season_number in (v_season,v_season+1)
    and w.status<>'cancelled';

  v_pyramid:=public.get_national_team_pyramid_v1(v_world,v_display_season);

  with my_assoc as (
    select a.*,
      (
        select count(*)::integer
        from public.national_associations x
        where x.world=a.world
          and x.region_code=a.region_code
          and x.status in ('active','renewal_required')
          and (
            x.activated_game_day<a.activated_game_day
            or (x.activated_game_day=a.activated_game_day and x.id<=a.id)
          )
      ) activation_rank
    from public.national_associations a
    where a.id=v_assoc
  ),
  choice as (
    select
      d.id division_id,d.division_code,d.label,d.region_code,d.tier_level,
      'official'::text placement_state,0 priority
    from my_assoc a
    join public.national_team_division_entries e
      on e.association_id=a.id
     and e.season_number=v_display_season
     and e.status in ('active','completed')
    join public.national_team_divisions d on d.id=e.division_id

    union all

    select
      d.id,d.division_code,d.label,d.region_code,d.tier_level,
      'projected'::text,1
    from my_assoc a
    join public.national_team_divisions d
      on d.world=a.world
     and d.region_code=a.region_code
     and d.tier_level=(3+floor((a.activation_rank-1)/8.0)::integer)+5
     and d.is_active
    where not exists(
      select 1
      from public.national_team_division_entries e
      where e.association_id=a.id
        and e.season_number=v_display_season
        and e.status in ('active','completed')
    )
  )
  select jsonb_build_object(
    'division_id',division_id,
    'division_code',division_code,
    'label',label,
    'region_code',region_code,
    'tier_level',tier_level,
    'season_number',v_display_season,
    'placement_state',placement_state
  )
  into v_projected_entry
  from choice
  order by priority
  limit 1;

  return base || jsonb_build_object(
    'windows',v_windows,
    'official_launch_season',cfg.official_launch_season,
    'season_mode',case
      when v_season<cfg.official_launch_season then 'association_building'
      else 'official'
    end,
    'competition_label',case
      when v_world='WTA' then 'Women''s National Team Championship'
      else 'Men''s National Team Championship'
    end,
    'pyramid_display_season',v_display_season,
    'pyramid',v_pyramid,
    'projected_entry',coalesce(v_projected_entry,'{}'::jsonb),
    'season_notice',case
      when v_season<cfg.official_launch_season then
        'Season 1 is an association-building season. There are no official standings, promotions or relegations yet. National windows are reserved for friendly ties. Official competition begins in Season 2.'
      else
        'Official national-team competition is active. Results feed division standings, promotion and relegation.'
    end
  );
end;
$$;

create or replace function public.on_national_association_became_active_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  cfg public.national_team_competition_config%rowtype;
  v_season integer:=public.national_team_current_season_v1();
begin
  if new.status='active' and old.status is distinct from 'active' then
    perform public.ensure_national_team_regional_capacity_v1(new.world,new.region_code);

    select * into cfg
    from public.national_team_competition_config
    where id=1;

    if v_season<cfg.official_launch_season then
      perform public.notify_national_association_members_v1(
        new.id,
        'national.competition.launch',
        'National-team programme: Season 1 friendlies',
        format(
          '%s is active. Season 1 is an association-building season with four national-team windows for friendly ties. Official %s competition begins in Season %s.',
          new.name,
          case when new.world='WTA' then 'women''s national-team' else 'men''s national-team' end,
          cfg.official_launch_season
        ),
        '/game/national-team?tab=competition',
        format('national-season-one-launch:%s',new.id),
        jsonb_build_object(
          'association_id',new.id,
          'season_number',v_season,
          'official_launch_season',cfg.official_launch_season,
          'action_url','/game/national-team?tab=competition'
        )
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_national_association_became_active_v1
on public.national_associations;

create trigger trg_national_association_became_active_v1
after update of status on public.national_associations
for each row
when (new.status='active' and old.status is distinct from 'active')
execute function public.on_national_association_became_active_v1();

do $$
declare
  a record;
  cfg public.national_team_competition_config%rowtype;
  v_season integer:=public.national_team_current_season_v1();
begin
  select * into cfg
  from public.national_team_competition_config
  where id=1;

  if v_season<cfg.official_launch_season then
    for a in
      select *
      from public.national_associations
      where status in ('active','renewal_required')
    loop
      perform public.notify_national_association_members_v1(
        a.id,
        'national.competition.launch',
        'National-team programme: Season 1 friendlies',
        format(
          '%s is active. Season 1 is an association-building season with four national-team windows for friendly ties. Official %s competition begins in Season %s.',
          a.name,
          case when a.world='WTA' then 'women''s national-team' else 'men''s national-team' end,
          cfg.official_launch_season
        ),
        '/game/national-team?tab=competition',
        format('national-season-one-launch:%s',a.id),
        jsonb_build_object(
          'association_id',a.id,
          'season_number',v_season,
          'official_launch_season',cfg.official_launch_season,
          'action_url','/game/national-team?tab=competition'
        )
      );
    end loop;
  end if;
end $$;

revoke all on function public.get_national_team_pyramid_v1(text,integer) from public,anon,authenticated;
revoke all on function public.get_my_national_team_competition_v2() from public,anon,authenticated;
grant execute on function public.get_my_national_team_competition_v2() to authenticated;
