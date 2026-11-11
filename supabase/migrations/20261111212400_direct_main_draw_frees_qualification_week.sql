-- The dates occupied by an existing SINGLE-player tennis entry.
-- In a multi-week event whose first week is qualification, a direct
-- main-draw entrant does not occupy qualification week unless the
-- player actually participated in qualifying.
CREATE OR REPLACE FUNCTION public.get_player_effective_competition_window_v1(
  p_player_id uuid,p_competition_id uuid
)
RETURNS TABLE(start_absolute_day integer,end_absolute_day integer)
LANGUAGE sql STABLE
SET search_path TO 'public','pg_temp'
AS $function$
WITH event_window AS(
  SELECT w.start_absolute_day,w.end_absolute_day,w.season_number
  FROM public.get_competition_window_v1(p_competition_id) w
), phases AS (
  SELECT min(ss.season_week) FILTER(WHERE ss.phase='qualification') qualification_week,
    min(ss.season_week) FILTER(WHERE ss.phase='main_draw') main_draw_week
  FROM public.tournament_schedule_slots ss
  JOIN public.tournament_world_competitions wc ON wc.tournament_edition_id=ss.tournament_edition_id
  WHERE wc.id=p_competition_id
), admitted AS (
 SELECT EXISTS(
   SELECT 1 FROM public.tournament_entries te
   WHERE te.player_id=p_player_id AND te.competition_id=p_competition_id
     AND te.draw_type='main_draw' AND te.entry_status='active'
 ) AS direct_main
), qualifiers AS (
 SELECT EXISTS(
   SELECT 1 FROM public.tournament_matches m
   WHERE m.competition_id=p_competition_id AND m.draw_type='qualification'
     AND (m.player1_id=p_player_id OR m.player2_id=p_player_id)
     AND m.status NOT IN ('cancelled')
 ) AS did_qualify
)
SELECT CASE WHEN a.direct_main AND NOT q.did_qualify
  AND ph.qualification_week IS NOT NULL AND ph.main_draw_week>ph.qualification_week
  THEN greatest(e.start_absolute_day,
    public.training_camp_week_start_absolute_v1(e.season_number,ph.main_draw_week::smallint))
  ELSE e.start_absolute_day END,
  e.end_absolute_day
FROM event_window e CROSS JOIN phases ph CROSS JOIN admitted a CROSS JOIN qualifiers q
$function$;
-- Accessed through existing authorized application/availability functions.
REVOKE ALL ON FUNCTION public.get_player_effective_competition_window_v1(uuid,uuid)
FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.check_player_competition_availability_v1(p_player_id uuid, p_competition_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  t record;
  v_player_world text;
  v_block_comp uuid;
  v_block_name text;
  v_block_city text;
begin
  select * into t
  from public.get_competition_window_v1(p_competition_id);

  if t.competition_id is null then
    return jsonb_build_object('available',false,'reason','competition_unavailable');
  end if;

  select world
  into v_player_world
  from public.players
  where id=p_player_id
    and moderation_status<>'rejected';

  if v_player_world is null then
    return jsonb_build_object('available',false,'reason','player_unavailable');
  end if;

  if v_player_world<>t.world then
    return jsonb_build_object('available',false,'reason','different_world');
  end if;

  v_block_comp:=null;
  v_block_name:=null;
  v_block_city:=null;

  select te.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_player_effective_competition_window_v1(te.player_id,te.competition_id) w
  where te.player_id=p_player_id
    and te.entry_status='active'
    and te.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','singles_entry_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  v_block_comp:=null;
  v_block_name:=null;
  v_block_city:=null;

  select a.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id=a.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_player_effective_competition_window_v1(a.player_id,a.competition_id) w
  where a.player_id=p_player_id
    and a.status in ('accepted_main_draw','accepted_qualification')
    and a.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by
    case a.status
      when 'accepted_main_draw' then 1
      when 'accepted_qualification' then 2
      else 3
    end,
    w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','accepted_singles_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  v_block_comp:=null;
  v_block_name:=null;
  v_block_city:=null;

  select dt.competition_id,s.name,s.city
  into v_block_comp,v_block_name,v_block_city
  from public.tournament_doubles_teams dt
  join public.tournament_world_competitions wc on wc.id=dt.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  cross join lateral public.get_competition_window_v1(dt.competition_id) w
  where (dt.player1_id=p_player_id or dt.player2_id=p_player_id)
    and dt.status in ('confirmed','active','alternate')
    and dt.competition_id<>p_competition_id
    and w.start_absolute_day<=t.end_absolute_day
    and w.end_absolute_day>=t.start_absolute_day
  order by w.start_absolute_day
  limit 1;

  if v_block_comp is not null then
    return jsonb_build_object(
      'available',false,
      'reason','doubles_entry_overlap',
      'blocking_competition_id',v_block_comp,
      'blocking_tournament',v_block_name,
      'blocking_city',v_block_city
    );
  end if;

  if exists(
    select 1
    from public.player_calendar_commitments c
    where c.player_id=p_player_id
      and c.status='committed'
      and (c.competition_id is null or c.competition_id<>p_competition_id)
      and c.starts_absolute_day<=t.end_absolute_day
      and c.ends_absolute_day>=t.start_absolute_day
  ) then
    return jsonb_build_object(
      'available',false,
      'reason','calendar_commitment_overlap'
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'reason','available',
    'start_absolute_day',t.start_absolute_day,
    'end_absolute_day',t.end_absolute_day,
    'location_key',t.location_key
  );
end;
$function$
;