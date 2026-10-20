-- Tennis Legacy Premium: completed-singles-match comparison, first controlled slice.
-- Keep the existing official match result, replay and public match detail RPCs Free.
-- Never reveal unfinished scores or data for matches outside the current player's career.
create or replace function public.get_premium_deep_match_analysis_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_match record;
  v_mine_first boolean;
  v_my_id uuid;
  v_their_id uuid;
  v_my_stats jsonb;
  v_their_stats jsonb;
  v_sets jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required for match analysis' using errcode = '42501';
  end if;

  if not public.has_active_premium_v1() then
    raise exception 'Premium membership required for Deep Match Analysis' using errcode = '42501';
  end if;

  select m.id,m.competition_id,m.status,m.winner_id,
         m.player1_id,m.player2_id,m.round_label,
         m.scheduled_season_week,m.scheduled_day,
         wc.world,ts.name as tournament_name,ts.surface,ts.city,
         p1.owner_user_id as first_owner,p2.owner_user_id as second_owner,
         p1.first_name as first_name_1,p1.last_name as last_name_1,p1.country_code as country_1,
         p2.first_name as first_name_2,p2.last_name as last_name_2,p2.country_code as country_2
    into v_match
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.players p1 on p1.id=m.player1_id
  join public.players p2 on p2.id=m.player2_id
  where m.id=p_match_id
    and m.status='completed'
    and m.winner_id is not null
    and (p1.owner_user_id=v_uid or p2.owner_user_id=v_uid);

  if not found then
    -- Do not expose whether a different user's match ID exists.
    raise exception 'Completed match not available for your career' using errcode = '42501';
  end if;

  v_mine_first := v_match.first_owner=v_uid;
  v_my_id := case when v_mine_first then v_match.player1_id else v_match.player2_id end;
  v_their_id := case when v_mine_first then v_match.player2_id else v_match.player1_id end;

  select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at'
    into v_my_stats
  from public.tournament_match_player_stats st
  where st.match_id=p_match_id and st.player_id=v_my_id;

  select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at'
    into v_their_stats
  from public.tournament_match_player_stats st
  where st.match_id=p_match_id and st.player_id=v_their_id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'set_number',ms.set_number,
      'my_games',case when v_mine_first then ms.player1_games else ms.player2_games end,
      'opponent_games',case when v_mine_first then ms.player2_games else ms.player1_games end,
      'my_tiebreak_points',case when v_mine_first then ms.player1_tiebreak_points else ms.player2_tiebreak_points end,
      'opponent_tiebreak_points',case when v_mine_first then ms.player2_tiebreak_points else ms.player1_tiebreak_points end
    ) order by ms.set_number
  ),'[]'::jsonb) into v_sets
  from public.tournament_match_sets ms
  where ms.match_id=p_match_id and ms.status='completed';

  return jsonb_build_object(
    'match_id',p_match_id,
    'tournament_name',v_match.tournament_name,
    'round_label',v_match.round_label,
    'surface',v_match.surface,
    'city',v_match.city,
    'world',v_match.world,
    'season_week',v_match.scheduled_season_week,
    'day',v_match.scheduled_day,
    'won',v_match.winner_id=v_my_id,
    'player',jsonb_build_object(
      'id',v_my_id,
      'first_name',case when v_mine_first then v_match.first_name_1 else v_match.first_name_2 end,
      'last_name',case when v_mine_first then v_match.last_name_1 else v_match.last_name_2 end,
      'country_code',case when v_mine_first then v_match.country_1 else v_match.country_2 end,
      'stats',v_my_stats
    ),
    'opponent',jsonb_build_object(
      'id',v_their_id,
      'first_name',case when v_mine_first then v_match.first_name_2 else v_match.first_name_1 end,
      'last_name',case when v_mine_first then v_match.last_name_2 else v_match.last_name_1 end,
      'country_code',case when v_mine_first then v_match.country_2 else v_match.country_1 end,
      'stats',v_their_stats
    ),
    'sets',v_sets
  );
end;
$function$;

revoke all on function public.get_premium_deep_match_analysis_v1(uuid) from public,anon;
grant execute on function public.get_premium_deep_match_analysis_v1(uuid) to authenticated;
comment on function public.get_premium_deep_match_analysis_v1(uuid) is
'Premium-gated player-vs-opponent stats for own completed singles matches only; no replay/result changes.';
