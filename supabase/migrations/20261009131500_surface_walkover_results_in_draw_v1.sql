-- Surface walkover results correctly in tournament draw and match detail.
-- Health walkovers are stored as completed matches with completion_reason='health_walkover'
-- and intentionally have no set rows. Expose them to the UI as walkovers.

create or replace function public.get_tournament_draw_v1(p_competition_id uuid)
returns table(
  match_id uuid,
  draw_type text,
  round_number smallint,
  round_label text,
  match_number smallint,
  bracket_size smallint,
  scheduled_season_week integer,
  scheduled_day smallint,
  scheduled_start_minute smallint,
  court_number smallint,
  schedule_reason text,
  match_status text,
  player1_id uuid,
  player1_first_name text,
  player1_last_name text,
  player1_country_code text,
  player1_seed smallint,
  player1_set_scores smallint[],
  player2_id uuid,
  player2_first_name text,
  player2_last_name text,
  player2_country_code text,
  player2_seed smallint,
  player2_set_scores smallint[],
  winner_id uuid
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  return query
  select
    m.id,
    m.draw_type,
    m.round_number,
    m.round_label,
    m.match_number,
    m.bracket_size,
    m.scheduled_season_week,
    m.scheduled_day,
    m.scheduled_start_minute,
    m.court_number,
    m.schedule_reason,
    case
      when m.status='completed' and m.completion_reason='health_walkover' then 'walkover'
      else m.status
    end::text,
    p1.id,
    p1.first_name,
    p1.last_name,
    p1.country_code,
    e1.seed_number,
    coalesce(
      (select array_agg(ms.player1_games order by ms.set_number)
       from public.tournament_match_sets ms
       where ms.match_id=m.id),
      '{}'::smallint[]
    ),
    p2.id,
    p2.first_name,
    p2.last_name,
    p2.country_code,
    e2.seed_number,
    coalesce(
      (select array_agg(ms.player2_games order by ms.set_number)
       from public.tournament_match_sets ms
       where ms.match_id=m.id),
      '{}'::smallint[]
    ),
    m.winner_id
  from public.tournament_matches m
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  left join public.tournament_entries e1
    on e1.competition_id=m.competition_id and e1.player_id=m.player1_id
  left join public.tournament_entries e2
    on e2.competition_id=m.competition_id and e2.player_id=m.player2_id
  where m.competition_id=p_competition_id
  order by m.draw_type,m.round_number,m.match_number;
end;
$function$;

create or replace function public.get_tournament_match_detail_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select jsonb_build_object(
    'match_id',m.id,
    'competition_id',m.competition_id,
    'tournament_name',s.name,
    'city',s.city,
    'country_code',s.country_code,
    'round_label',m.round_label,
    'match_number',m.match_number,
    'scheduled_season_week',m.scheduled_season_week,
    'scheduled_day',m.scheduled_day,
    'scheduled_start_minute',m.scheduled_start_minute,
    'court_number',m.court_number,
    'schedule_reason',m.schedule_reason,
    'status',case
      when m.status='completed' and m.completion_reason='health_walkover' then 'walkover'
      else m.status
    end,
    'completion_reason',m.completion_reason,
    'winner_id',m.winner_id,
    'started_at',m.started_at,
    'completed_at',m.completed_at,
    'player1',case when p1.id is null then null else jsonb_build_object(
      'id',p1.id,'first_name',p1.first_name,'last_name',p1.last_name,
      'country_code',p1.country_code,'image_path',p1.image_path,
      'ranking_position',e1.ranking_position_snapshot,'seed',e1.seed_number,
      'playing_hand',p1.playing_hand,'preferred_surface',p1.preferred_surface,
      'playing_style',p1.playing_style
    ) end,
    'player2',case when p2.id is null then null else jsonb_build_object(
      'id',p2.id,'first_name',p2.first_name,'last_name',p2.last_name,
      'country_code',p2.country_code,'image_path',p2.image_path,
      'ranking_position',e2.ranking_position_snapshot,'seed',e2.seed_number,
      'playing_hand',p2.playing_hand,'preferred_surface',p2.preferred_surface,
      'playing_style',p2.playing_style
    ) end,
    'sets',coalesce((
      select jsonb_agg(jsonb_build_object(
        'set_number',ms.set_number,
        'player1_games',ms.player1_games,
        'player2_games',ms.player2_games,
        'player1_tiebreak_points',ms.player1_tiebreak_points,
        'player2_tiebreak_points',ms.player2_tiebreak_points,
        'status',ms.status
      ) order by ms.set_number)
      from public.tournament_match_sets ms
      where ms.match_id=m.id
    ),'[]'::jsonb),
    'player1_stats',coalesce((
      select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at'
      from public.tournament_match_player_stats st
      where st.match_id=m.id and st.player_id=m.player1_id
    ),'{}'::jsonb),
    'player2_stats',coalesce((
      select to_jsonb(st)-'id'-'match_id'-'player_id'-'updated_at'
      from public.tournament_match_player_stats st
      where st.match_id=m.id and st.player_id=m.player2_id
    ),'{}'::jsonb)
  )
  into v_result
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  left join public.players p1 on p1.id=m.player1_id
  left join public.players p2 on p2.id=m.player2_id
  left join public.tournament_entries e1
    on e1.competition_id=m.competition_id and e1.player_id=m.player1_id
  left join public.tournament_entries e2
    on e2.competition_id=m.competition_id and e2.player_id=m.player2_id
  where m.id=p_match_id;

  return v_result;
end;
$function$;
