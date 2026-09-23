CREATE OR REPLACE FUNCTION public.get_my_national_association_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_player record;
  v_assoc public.national_associations%rowtype;
  v_membership public.national_association_memberships%rowtype;
  v_cfg public.national_team_config%rowtype;
  v_day integer := public.national_team_current_abs_day_v1();
  v_season integer := (public.national_team_current_abs_day_v1() / 366) + 1;
  v_member_count integer;
  v_activation jsonb;
  v_renewal jsonb;
  v_division jsonb;
  v_captain jsonb;
  v_election jsonb;
  v_roster jsonb;
  v_history jsonb;
  v_treasury bigint;
  v_my_total integer;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  select p.id, p.world, p.country_code, p.first_name, p.last_name
  into v_player
  from public.players p
  where p.owner_user_id = v_uid
  limit 1;

  if not found then
    return jsonb_build_object('available', false, 'reason', 'player_required');
  end if;

  select * into v_assoc
  from public.national_associations a
  where a.country_code = v_player.country_code
    and a.world = v_player.world
  limit 1;

  if not found then
    return jsonb_build_object('available', false, 'reason', 'association_missing');
  end if;

  select * into v_membership
  from public.national_association_memberships m
  where m.player_id = v_player.id
    and m.association_id = v_assoc.id
    and m.status = 'active'
  limit 1;

  select * into v_cfg from public.national_team_config where id = 1;

  select count(*)::integer into v_member_count
  from public.national_association_memberships
  where association_id = v_assoc.id and status = 'active';

  select jsonb_build_object(
    'id', f.id,
    'target', f.target_amount,
    'contributed', f.contributed_amount,
    'status', f.status,
    'completed_game_day', f.completed_game_day
  )
  into v_activation
  from public.national_association_funds f
  where f.association_id = v_assoc.id
    and f.fund_type = 'activation'
  limit 1;

  select jsonb_build_object(
    'id', f.id,
    'season_number', f.season_number,
    'target', f.target_amount,
    'contributed', f.contributed_amount,
    'status', f.status,
    'opens_game_day', f.opens_game_day,
    'deadline_game_day', f.deadline_game_day,
    'deadline_date', (
      select jsonb_build_object('season', g.season, 'month', g.month, 'day', g.day)
      from public.absolute_game_day_v1(f.deadline_game_day) g
    )
  )
  into v_renewal
  from public.national_association_funds f
  where f.association_id = v_assoc.id
    and f.fund_type = 'season_renewal'
  order by f.season_number desc
  limit 1;

  select jsonb_build_object(
    'entry_id', e.id,
    'division_id', d.id,
    'division_code', d.division_code,
    'label', d.label,
    'tier_level', d.tier_level,
    'region_code', d.region_code,
    'entry_reason', e.entry_reason,
    'status', e.status,
    'final_position', e.final_position
  )
  into v_division
  from public.national_team_division_entries e
  join public.national_team_divisions d on d.id = e.division_id
  where e.association_id = v_assoc.id
    and e.season_number = v_season
  order by e.created_at desc
  limit 1;

  select jsonb_build_object(
    'term_id', t.id,
    'season_number', t.season_number,
    'player_id', p.id,
    'first_name', p.first_name,
    'last_name', p.last_name,
    'status', t.status
  )
  into v_captain
  from public.national_captain_terms t
  join public.players p on p.id = t.player_id
  where t.association_id = v_assoc.id
    and t.status = 'active'
  order by t.season_number desc
  limit 1;

  select jsonb_build_object(
    'id', e.id,
    'season_number', e.season_number,
    'status', e.status,
    'current_round', e.current_round,
    'registration_start_game_day', e.registration_start_game_day,
    'registration_end_game_day', e.registration_end_game_day,
    'campaign_end_game_day', e.campaign_end_game_day,
    'voting_end_game_day', e.voting_end_game_day,
    'runoff_end_game_day', e.runoff_end_game_day,
    'winning_candidate_id', e.winning_candidate_id,
    'my_candidate_id', (
      select c.id
      from public.national_captain_candidates c
      where c.election_id = e.id and c.user_id = v_uid
      limit 1
    ),
    'my_vote_candidate_id', (
      select v.candidate_id
      from public.national_captain_votes v
      where v.election_id = e.id
        and v.round_number = e.current_round
        and v.voter_user_id = v_uid
      limit 1
    ),
    'candidates', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'candidate_id', c.id,
          'player_id', p.id,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'manifesto', c.manifesto,
          'in_current_runoff', case
            when e.status <> 'runoff' then true
            else exists (
              select 1
              from public.national_captain_runoff_candidates rc
              where rc.election_id = e.id
                and rc.round_number = e.current_round
                and rc.candidate_id = c.id
            )
          end,
          'vote_total', case
            when e.status = 'completed' then (
              select count(*)::integer
              from public.national_captain_votes v
              where v.election_id = e.id
                and v.round_number = e.current_round
                and v.candidate_id = c.id
            )
            else null
          end
        )
        order by p.last_name, p.first_name
      )
      from public.national_captain_candidates c
      join public.players p on p.id = c.player_id
      where c.election_id = e.id
        and c.status = 'active'
    ), '[]'::jsonb)
  )
  into v_election
  from public.national_captain_elections e
  where e.association_id = v_assoc.id
    and e.season_number = v_season
  limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'membership_id', m.id,
      'player_id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'captain_eligible', m.captain_eligible,
      'joined_game_day', m.joined_game_day,
      'national_appearances', (select count(distinct na.fixture_id)::integer from public.national_team_player_appearances na where na.player_id=p.id)
    )
    order by p.last_name, p.first_name
  ), '[]'::jsonb)
  into v_roster
  from public.national_association_memberships m
  join public.players p on p.id = m.player_id
  where m.association_id = v_assoc.id
    and m.status = 'active';

  select coalesce(jsonb_agg(x.item order by x.game_day desc), '[]'::jsonb)
  into v_history
  from (
    select
      e.game_day,
      jsonb_build_object(
        'id', e.id,
        'season_number', e.season_number,
        'game_day', e.game_day,
        'event_type', e.event_type,
        'details', e.details
      ) as item
    from public.national_association_events e
    where e.association_id = v_assoc.id
    order by e.game_day desc, e.created_at desc
    limit 12
  ) x;

  select coins_balance into v_treasury
  from public.national_association_treasuries
  where association_id = v_assoc.id;

  select coalesce(sum(c.amount), 0)::integer into v_my_total
  from public.national_association_contributions c
  where c.association_id = v_assoc.id
    and c.user_id = v_uid;

  return jsonb_build_object(
    'available', true,
    'game_day', v_day,
    'season_number', v_season,
    'association', jsonb_build_object(
      'id', v_assoc.id,
      'name', v_assoc.name,
      'country_code', v_assoc.country_code,
      'world', v_assoc.world,
      'region_code', v_assoc.region_code,
      'status', v_assoc.status,
      'activated_game_day', v_assoc.activated_game_day,
      'activated_season', v_assoc.activated_season,
      'member_count', v_member_count,
      'minimum_activation_members', v_cfg.activation_min_members,
      'is_member', v_membership.id is not null,
      'captain_eligible', coalesce(v_membership.captain_eligible, false)
    ),
    'activation_fund', coalesce(v_activation, '{}'::jsonb),
    'renewal_fund', coalesce(v_renewal, '{}'::jsonb),
    'division', coalesce(v_division, '{}'::jsonb),
    'captain', coalesce(v_captain, '{}'::jsonb),
    'election', coalesce(v_election, '{}'::jsonb),
    'roster', v_roster,
    'history', v_history,
    'treasury_balance', coalesce(v_treasury, 0),
    'my_total_contributions', v_my_total,
    'rules', jsonb_build_object(
      'activation_cost', v_cfg.activation_cost,
      'activation_min_members', v_cfg.activation_min_members,
      'renewal_cost', v_cfg.renewal_cost,
      'voting_days', v_cfg.voting_days,
      'runoff_days', v_cfg.runoff_days
    )
  );
end;
$function$
