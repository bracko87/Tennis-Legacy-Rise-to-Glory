create or replace function public.get_tournament_past_winners_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_player_world text;
  v_world text;
  v_series uuid;
  v_current_season integer;
  v_winners jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  select p.world
  into v_player_world
  from public.players p
  where p.owner_user_id = v_uid
    and p.player_type = 'human'
  order by p.created_at desc
  limit 1;

  select wc.world, e.tournament_series_id, e.season_number
  into v_world, v_series, v_current_season
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id = wc.tournament_edition_id
  where wc.id = p_competition_id
  limit 1;

  if v_series is null or v_world is distinct from v_player_world then
    raise exception 'Tournament unavailable.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'season_number', e.season_number,
        'competition_id', wc.id,
        'player_id', p.id,
        'first_name', p.first_name,
        'last_name', p.last_name,
        'country_code', p.country_code,
        'is_ai', p.player_type = 'ai'
      )
      order by e.season_number desc
    ),
    '[]'::jsonb
  )
  into v_winners
  from public.tournament_editions e
  join public.tournament_world_competitions wc
    on wc.tournament_edition_id = e.id
   and wc.world = v_world
  join public.player_tournament_results r
    on r.competition_id = wc.id
   and r.result_code = 'champion'
  join public.players p on p.id = r.player_id
  where e.tournament_series_id = v_series
    and e.season_number < v_current_season;

  return jsonb_build_object(
    'competition_id', p_competition_id,
    'tournament_series_id', v_series,
    'world', v_world,
    'current_season_number', v_current_season,
    'winners', v_winners
  );
end;
$function$;

revoke all on function public.get_tournament_past_winners_v1(uuid) from public;
revoke all on function public.get_tournament_past_winners_v1(uuid) from anon;
grant execute on function public.get_tournament_past_winners_v1(uuid) to authenticated;
