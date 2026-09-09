create or replace function public.get_player_head_to_head_v1(
  p_player1_id uuid,
  p_player2_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_meetings jsonb;
  v_player1_wins integer:=0;
  v_player2_wins integer:=0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if p_player1_id is null or p_player2_id is null or p_player1_id=p_player2_id then
    return jsonb_build_object('player1_wins',0,'player2_wins',0,'meeting_count',0,'meetings','[]'::jsonb);
  end if;

  select
    count(*) filter (where m.winner_id=p_player1_id)::integer,
    count(*) filter (where m.winner_id=p_player2_id)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'match_id',m.id,
          'competition_id',m.competition_id,
          'season_number',ed.season_number,
          'tournament_name',ts.name,
          'round_label',m.round_label,
          'winner_id',m.winner_id,
          'player1_id',m.player1_id,
          'player2_id',m.player2_id,
          'completed_at',m.completed_at,
          'sets',coalesce(s.sets,'[]'::jsonb)
        )
        order by ed.season_number desc,coalesce(m.completed_at,m.updated_at) desc,m.id
      ) filter (where m.id is not null),
      '[]'::jsonb
    )
  into v_player1_wins,v_player2_wins,v_meetings
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  left join lateral (
    select jsonb_agg(
      jsonb_build_object(
        'set_number',ms.set_number,
        'player1_games',ms.player1_games,
        'player2_games',ms.player2_games,
        'player1_tiebreak_points',ms.player1_tiebreak_points,
        'player2_tiebreak_points',ms.player2_tiebreak_points
      )
      order by ms.set_number
    ) as sets
    from public.tournament_match_sets ms
    where ms.match_id=m.id
      and ms.status='completed'
  ) s on true
  where m.status='completed'
    and m.winner_id is not null
    and (
      (m.player1_id=p_player1_id and m.player2_id=p_player2_id)
      or
      (m.player1_id=p_player2_id and m.player2_id=p_player1_id)
    );

  return jsonb_build_object(
    'player1_wins',coalesce(v_player1_wins,0),
    'player2_wins',coalesce(v_player2_wins,0),
    'meeting_count',coalesce(v_player1_wins,0)+coalesce(v_player2_wins,0),
    'meetings',coalesce(v_meetings,'[]'::jsonb)
  );
end;
$$;

grant execute on function public.get_player_head_to_head_v1(uuid,uuid) to authenticated;
revoke execute on function public.get_player_head_to_head_v1(uuid,uuid) from anon;
