
create or replace function public.get_national_team_division_browser_v1(
  p_division_id uuid default null,
  p_group_code text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  v_world text;
  v_season integer:=public.national_team_current_season_v1();
  v_display_season integer;
  v_launch integer;
  v_my_division uuid;
  v_selected uuid;
  v_selected_row public.national_team_divisions%rowtype;
  v_group text;
  v_format text;
  v_options jsonb;
  v_participants jsonb;
  v_fixtures jsonb;
  v_standings jsonb;
  v_groups jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select m.association_id,a.world
  into v_assoc,v_world
  from public.national_association_memberships m
  join public.national_associations a on a.id=m.association_id
  where m.user_id=v_uid and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_assoc is null then return jsonb_build_object('available',false); end if;

  select official_launch_season into v_launch
  from public.national_team_competition_config
  where id=1;

  v_display_season:=greatest(v_season,v_launch);

  select e.division_id
  into v_my_division
  from public.national_team_division_entries e
  where e.association_id=v_assoc
    and e.season_number=v_display_season
    and e.status in ('active','completed')
  order by e.created_at desc
  limit 1;

  if v_my_division is null then
    v_my_division:=public.national_team_bootstrap_division_v1(v_assoc,v_display_season);
  end if;

  v_selected:=coalesce(p_division_id,v_my_division);

  select * into v_selected_row
  from public.national_team_divisions
  where id=v_selected and world=v_world and is_active;

  if not found then
    v_selected:=v_my_division;
    select * into v_selected_row
    from public.national_team_divisions
    where id=v_selected;
  end if;

  v_format:=case
    when v_selected_row.division_code in ('qualifier_r1','qualifier_r2','final_8') then 'knockout'
    else 'group'
  end;

  with opts as (
    select
      d.id,d.region_code,d.division_code,d.label,d.tier_level,d.capacity,d.sort_order,
      case
        when d.division_code in ('qualifier_r1','qualifier_r2','final_8') then 'knockout'
        else 'group'
      end format_kind,
      case
        when d.region_code='GLOBAL' and d.tier_level<=3 then 'Qualifiers'
        when d.region_code='GLOBAL' then 'World Groups'
        else 'Regional'
      end tier_family,
      case when d.region_code='GLOBAL' then null else d.region_code end selector_region,
      case
        when d.division_code in ('world_group_i','world_group_ii') then greatest(1,ceil(d.capacity/4.0)::integer)
        when d.region_code<>'GLOBAL' then greatest(1,ceil(d.capacity/4.0)::integer)
        else 0
      end group_count
    from public.national_team_divisions d
    where d.world=v_world and d.is_active
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'division_id',id,'region_code',region_code,'division_code',division_code,
    'label',label,'tier_level',tier_level,'capacity',capacity,
    'format_kind',format_kind,'tier_family',tier_family,
    'selector_region',selector_region,'group_count',group_count
  ) order by tier_level,sort_order,region_code,label),'[]'::jsonb)
  into v_options
  from opts;

  with actual as (
    select
      a.id association_id,a.name,a.country_code,a.activated_game_day,
      'official'::text placement_state
    from public.national_team_division_entries e
    join public.national_associations a on a.id=e.association_id
    where e.division_id=v_selected
      and e.season_number=v_display_season
      and e.status in ('active','completed')
      and a.status in ('active','renewal_required')
  ),
  projected as (
    select
      a.id association_id,a.name,a.country_code,a.activated_game_day,
      'projected'::text placement_state
    from public.national_associations a
    where a.world=v_world
      and a.status in ('active','renewal_required')
      and public.national_team_bootstrap_division_v1(a.id,v_display_season)=v_selected
      and not exists(
        select 1
        from public.national_team_division_entries e
        where e.association_id=a.id
          and e.season_number=v_display_season
          and e.status in ('active','completed')
      )
  ),
  combined as (
    select * from actual
    union all
    select * from projected
  ),
  ranked as (
    select
      c.*,
      row_number() over(order by c.activated_game_day,c.country_code,c.association_id)::integer seed_position,
      case when v_format='group'
        then chr(65 + floor((row_number() over(order by c.activated_game_day,c.country_code,c.association_id)-1)/4.0)::integer)
        else null
      end group_code
    from combined c
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'association_id',association_id,'name',name,'country_code',country_code,
    'placement_state',placement_state,'seed_position',seed_position,
    'group_code',group_code,'is_mine',association_id=v_assoc
  ) order by seed_position),'[]'::jsonb)
  into v_participants
  from ranked;

  if v_format='group' then
    with participant_rows as (
      select
        (x->>'association_id')::uuid association_id,
        x->>'group_code' group_code
      from jsonb_array_elements(v_participants) x
    )
    select coalesce(
      nullif(trim(p_group_code),''),
      (select group_code from participant_rows where association_id=v_assoc limit 1),
      'A'
    )
    into v_group;

    with participant_rows as (
      select x->>'group_code' group_code
      from jsonb_array_elements(v_participants) x
    )
    select coalesce(jsonb_agg(distinct group_code order by group_code),'[]'::jsonb)
    into v_groups
    from participant_rows
    where group_code is not null;

    with participant_rows as (
      select
        (x->>'association_id')::uuid association_id,
        x->>'group_code' group_code
      from jsonb_array_elements(v_participants) x
    ),
    grp as (
      select association_id from participant_rows where group_code=v_group
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'fixture_id',f.id,'status',f.status,'fixture_kind',f.fixture_kind,
      'home_association_id',f.home_association_id,'home_name',ha.name,
      'home_country_code',ha.country_code,
      'away_association_id',f.away_association_id,'away_name',aa.name,
      'away_country_code',aa.country_code,
      'home_match_wins',f.home_match_wins,'away_match_wins',f.away_match_wins,
      'winner_association_id',f.winner_association_id,
      'tie_start_absolute_day',f.tie_start_absolute_day,
      'tie_end_absolute_day',f.tie_end_absolute_day,
      'window_tie_slot',f.window_tie_slot
    ) order by f.tie_start_absolute_day,f.created_at),'[]'::jsonb)
    into v_fixtures
    from public.national_team_fixtures f
    join public.national_associations ha on ha.id=f.home_association_id
    join public.national_associations aa on aa.id=f.away_association_id
    join public.national_team_windows w on w.id=f.window_id
    where f.division_id=v_selected
      and w.season_number=v_display_season
      and f.status<>'cancelled'
      and f.home_association_id in (select association_id from grp)
      and f.away_association_id in (select association_id from grp);

    with participant_rows as (
      select
        (x->>'association_id')::uuid association_id,
        x->>'name' association_name,
        x->>'country_code' country_code,
        x->>'group_code' group_code,
        coalesce((x->>'is_mine')::boolean,false) is_mine
      from jsonb_array_elements(v_participants) x
    ),
    grp as (
      select * from participant_rows where group_code=v_group
    ),
    ranked_standings as (
      select
        g.association_id,g.association_name,g.country_code,g.is_mine,
        coalesce(s.ties_played,0) ties_played,
        coalesce(s.ties_won,0) ties_won,
        coalesce(s.ties_lost,0) ties_lost,
        coalesce(s.matches_won,0) matches_won,
        coalesce(s.matches_lost,0) matches_lost,
        coalesce(s.standings_points,0) standings_points,
        row_number() over(
          order by coalesce(s.standings_points,0) desc,
                   coalesce(s.ties_won,0) desc,
                   (coalesce(s.matches_won,0)-coalesce(s.matches_lost,0)) desc,
                   g.association_name
        )::integer rank_position
      from grp g
      left join public.national_team_division_standings s
        on s.division_id=v_selected
       and s.season_number=v_display_season
       and s.association_id=g.association_id
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'rank_position',rank_position,'association_id',association_id,
      'association_name',association_name,'country_code',country_code,
      'ties_played',ties_played,'ties_won',ties_won,'ties_lost',ties_lost,
      'matches_won',matches_won,'matches_lost',matches_lost,
      'standings_points',standings_points,'is_mine',is_mine
    ) order by rank_position),'[]'::jsonb)
    into v_standings
    from ranked_standings;
  else
    v_group:=null;
    v_groups:='[]'::jsonb;

    select coalesce(jsonb_agg(jsonb_build_object(
      'fixture_id',f.id,'division_code',d.division_code,
      'status',f.status,'fixture_kind',f.fixture_kind,
      'home_association_id',f.home_association_id,'home_name',ha.name,
      'home_country_code',ha.country_code,
      'away_association_id',f.away_association_id,'away_name',aa.name,
      'away_country_code',aa.country_code,
      'home_match_wins',f.home_match_wins,'away_match_wins',f.away_match_wins,
      'winner_association_id',f.winner_association_id,
      'tie_start_absolute_day',f.tie_start_absolute_day,
      'tie_end_absolute_day',f.tie_end_absolute_day
    ) order by d.tier_level desc,f.tie_start_absolute_day,f.created_at),'[]'::jsonb)
    into v_fixtures
    from public.national_team_fixtures f
    join public.national_team_divisions d on d.id=f.division_id
    join public.national_associations ha on ha.id=f.home_association_id
    join public.national_associations aa on aa.id=f.away_association_id
    join public.national_team_windows w on w.id=f.window_id
    where d.world=v_world
      and d.division_code in ('qualifier_r1','qualifier_r2','final_8')
      and w.season_number=v_display_season
      and f.status<>'cancelled';

    v_standings:='[]'::jsonb;
  end if;

  return jsonb_build_object(
    'available',true,'world',v_world,'season_number',v_display_season,
    'my_association_id',v_assoc,'my_division_id',v_my_division,
    'selected_division',jsonb_build_object(
      'division_id',v_selected_row.id,'division_code',v_selected_row.division_code,
      'label',v_selected_row.label,'region_code',v_selected_row.region_code,
      'tier_level',v_selected_row.tier_level,'capacity',v_selected_row.capacity,
      'promotion_slots',v_selected_row.promotion_slots,
      'relegation_slots',v_selected_row.relegation_slots,'format_kind',v_format
    ),
    'selected_group_code',v_group,'group_codes',v_groups,
    'competition_options',v_options,'participants',v_participants,
    'fixtures',v_fixtures,'standings',v_standings
  );
end;
$$;
