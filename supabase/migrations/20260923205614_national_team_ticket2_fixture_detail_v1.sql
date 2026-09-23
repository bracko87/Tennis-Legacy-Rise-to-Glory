
create or replace function public.get_national_team_fixture_detail_v1(
  p_fixture_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_assoc public.national_associations%rowtype;
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  v_is_captain boolean:=false;
  v_revealed boolean:=false;
  v_engine_comp uuid;
  v_eligible jsonb;
  v_squad jsonb;
  v_our_lineup jsonb;
  v_opp_lineup jsonb;
  v_matches jsonb;
  v_finance jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human'
  limit 1;

  if v_player.id is null then raise exception 'Player profile required.'; end if;

  select * into f
  from public.national_team_fixtures
  where id=p_fixture_id;

  if not found then raise exception 'Fixture not found.'; end if;

  select * into w from public.national_team_windows where id=f.window_id;

  select * into v_assoc
  from public.national_associations
  where world=v_player.world
    and country_code=v_player.country_code
    and id in (f.home_association_id,f.away_association_id)
  limit 1;

  if v_assoc.id is null then
    raise exception 'This fixture does not belong to your national association.';
  end if;

  if not exists(
    select 1
    from public.national_association_memberships m
    where m.association_id=v_assoc.id
      and m.player_id=v_player.id
      and m.status='active'
  ) then
    raise exception 'Active association membership required.';
  end if;

  v_is_captain:=public.national_fixture_association_for_captain_v1(f.id,v_uid)=v_assoc.id;

  select count(*)=2 into v_revealed
  from public.national_team_lineups l
  where l.fixture_id=f.id
    and l.revealed_at_game_second is not null;

  select competition_id into v_engine_comp
  from public.national_team_engine_competitions
  where fixture_id=f.id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'player_id',p.id,
      'first_name',p.first_name,
      'last_name',p.last_name,
      'rank_position',public.get_player_world_rank_position_v1(p.id),
      'callup_id',c.id,
      'callup_status',c.status,
      'response_deadline_absolute_day',c.response_deadline_absolute_day,
      'accepted',c.status='accepted',
      'national_appearances',coalesce(ap.appearances,0),
      'national_singles_wins',coalesce(ap.singles_wins,0),
      'national_doubles_wins',coalesce(ap.doubles_wins,0)
    )
    order by public.get_player_world_rank_position_v1(p.id) nulls last,p.last_name,p.first_name
  ),'[]'::jsonb)
  into v_eligible
  from public.national_association_memberships m
  join public.players p on p.id=m.player_id
  left join public.national_team_callups c
    on c.fixture_id=f.id and c.player_id=p.id
  left join lateral (
    select
      count(distinct a.fixture_id)::integer appearances,
      coalesce(sum(a.singles_wins),0)::integer singles_wins,
      coalesce(sum(a.doubles_wins),0)::integer doubles_wins
    from public.national_team_player_appearances a
    where a.player_id=p.id
  ) ap on true
  where m.association_id=v_assoc.id
    and m.status='active';

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'player_id',p.id,
      'first_name',p.first_name,
      'last_name',p.last_name,
      'rank_position',public.get_player_world_rank_position_v1(p.id)
    )
    order by public.get_player_world_rank_position_v1(p.id) nulls last,p.last_name,p.first_name
  ),'[]'::jsonb)
  into v_squad
  from public.national_team_squad_members s
  join public.players p on p.id=s.player_id
  where s.fixture_id=f.id
    and s.association_id=v_assoc.id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'slot_code',ls.slot_code,
      'discipline',ls.discipline,
      'player_id',p.id,
      'first_name',p.first_name,
      'last_name',p.last_name
    )
    order by case ls.slot_code
      when 'S1' then 1
      when 'S2' then 2
      when 'D1A' then 3
      when 'D1B' then 4
      when 'S3' then 5
      when 'S4' then 6
      else 9
    end
  ),'[]'::jsonb)
  into v_our_lineup
  from public.national_team_lineups l
  join public.national_team_lineup_slots ls on ls.lineup_id=l.id
  join public.players p on p.id=ls.player_id
  where l.fixture_id=f.id
    and l.association_id=v_assoc.id;

  if v_revealed then
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'slot_code',ls.slot_code,
        'discipline',ls.discipline,
        'player_id',p.id,
        'first_name',p.first_name,
        'last_name',p.last_name
      )
      order by case ls.slot_code
        when 'S1' then 1
        when 'S2' then 2
        when 'D1A' then 3
        when 'D1B' then 4
        when 'S3' then 5
        when 'S4' then 6
        else 9
      end
    ),'[]'::jsonb)
    into v_opp_lineup
    from public.national_team_lineups l
    join public.national_team_lineup_slots ls on ls.lineup_id=l.id
    join public.players p on p.id=ls.player_id
    where l.fixture_id=f.id
      and l.association_id<>v_assoc.id;
  else
    v_opp_lineup:='[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'slot_id',s.id,
      'slot_order',s.slot_order,
      'discipline',s.discipline,
      'status',s.status,
      'winner_association_id',s.winner_association_id,
      'engine_match_id',s.engine_match_id,
      'engine_doubles_match_id',s.engine_doubles_match_id,
      'home_players',jsonb_strip_nulls(jsonb_build_object(
        'player1_id',s.home_player1_id,
        'player1_name',(select trim(first_name||' '||last_name) from public.players where id=s.home_player1_id),
        'player2_id',s.home_player2_id,
        'player2_name',(select trim(first_name||' '||last_name) from public.players where id=s.home_player2_id)
      )),
      'away_players',jsonb_strip_nulls(jsonb_build_object(
        'player1_id',s.away_player1_id,
        'player1_name',(select trim(first_name||' '||last_name) from public.players where id=s.away_player1_id),
        'player2_id',s.away_player2_id,
        'player2_name',(select trim(first_name||' '||last_name) from public.players where id=s.away_player2_id)
      ))
    )
    order by s.slot_order
  ),'[]'::jsonb)
  into v_matches
  from public.national_team_fixture_match_slots s
  where s.fixture_id=f.id;

  select jsonb_build_object(
    'cash_balance_usd',t.cash_balance_usd,
    'lifetime_cash_income_usd',t.lifetime_cash_income_usd,
    'lifetime_cash_spent_usd',t.lifetime_cash_spent_usd,
    'recent_transactions',coalesce((
      select jsonb_agg(item order by created_at desc)
      from (
        select
          ft.created_at,
          jsonb_build_object(
            'id',ft.id,
            'game_absolute_day',ft.game_absolute_day,
            'category',ft.category,
            'amount_usd',ft.amount_usd,
            'balance_after_usd',ft.balance_after_usd,
            'description',ft.description
          ) item
        from public.national_association_finance_transactions ft
        where ft.association_id=v_assoc.id
        order by ft.created_at desc
        limit 10
      ) q
    ),'[]'::jsonb)
  )
  into v_finance
  from public.national_association_treasuries t
  where t.association_id=v_assoc.id;

  return jsonb_build_object(
    'fixture',jsonb_build_object(
      'id',f.id,
      'status',f.status,
      'home_association_id',f.home_association_id,
      'home_name',(select name from public.national_associations where id=f.home_association_id),
      'home_country_code',(select country_code from public.national_associations where id=f.home_association_id),
      'away_association_id',f.away_association_id,
      'away_name',(select name from public.national_associations where id=f.away_association_id),
      'away_country_code',(select country_code from public.national_associations where id=f.away_association_id),
      'opponent_name',(select name from public.national_associations where id=case when v_assoc.id=f.home_association_id then f.away_association_id else f.home_association_id end),
      'opponent_country_code',(select country_code from public.national_associations where id=case when v_assoc.id=f.home_association_id then f.away_association_id else f.home_association_id end),
      'host_city',f.host_city,
      'host_country_code',f.host_country_code,
      'surface',f.surface,
      'environment',f.environment,
      'central_event_key',f.central_event_key,
      'tie_start_absolute_day',f.tie_start_absolute_day,
      'tie_end_absolute_day',f.tie_end_absolute_day,
      'response_deadline_absolute_day',f.response_deadline_absolute_day,
      'squad_deadline_absolute_day',f.squad_deadline_absolute_day,
      'lineup_deadline_game_second',f.lineup_deadline_game_second,
      'expected_appearance_fee_usd',f.expected_appearance_fee_usd,
      'home_match_wins',f.home_match_wins,
      'away_match_wins',f.away_match_wins,
      'winner_association_id',f.winner_association_id,
      'engine_competition_id',v_engine_comp
    ),
    'window',jsonb_build_object(
      'id',w.id,
      'label',w.label,
      'season_number',w.season_number,
      'season_week',w.season_week,
      'start_absolute_day',w.start_absolute_day,
      'end_absolute_day',w.end_absolute_day,
      'status',w.status
    ),
    'association',jsonb_build_object(
      'id',v_assoc.id,
      'name',v_assoc.name,
      'country_code',v_assoc.country_code
    ),
    'is_captain',v_is_captain,
    'lineups_revealed',v_revealed,
    'eligible_members',v_eligible,
    'squad',v_squad,
    'our_lineup_status',(
      select l.status from public.national_team_lineups l
      where l.fixture_id=f.id and l.association_id=v_assoc.id
    ),
    'our_lineup',v_our_lineup,
    'opponent_lineup',v_opp_lineup,
    'matches',v_matches,
    'treasury',coalesce(v_finance,'{}'::jsonb)
  );
end;
$$;

revoke execute on function public.get_national_team_fixture_detail_v1(uuid) from anon;
grant execute on function public.get_national_team_fixture_detail_v1(uuid) to authenticated;
