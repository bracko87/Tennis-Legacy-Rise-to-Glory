-- New human tennis players begin with zero ranking points at the bottom.
-- Existing AI preseason seed order remains intact until genuine points are earned.
-- Human players with equal points/seed ratings are ordered by creation date.
-- Keep season-end snapshot ordering aligned with live ATP/WTA ranking.
CREATE OR REPLACE FUNCTION public.ensure_player_ranking_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.player_rankings(player_id,seed_rating)
  values(
    new.id,
    case when new.player_type='ai'
      then coalesce(new.ai_starting_technical_total,350)*100+coalesce(new.ai_starting_physical_total,176)
      else 0
    end
  ) on conflict(player_id) do nothing;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.capture_world_ranking_snapshot_internal_v1()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_abs integer; v_season integer;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day), d.season into v_abs,v_season from public.get_current_game_day_internal_v1() d;
  insert into public.player_ranking_snapshots(player_id,world,season,game_absolute_day,ranking_position,ranking_points)
  select p.id,p.world,v_season,v_abs,
         row_number() over(partition by p.world order by coalesce(pr.ranking_points,0) desc, coalesce(pr.seed_rating,0) desc, p.created_at asc, p.id)::integer,
         coalesce(pr.ranking_points,0)
  from public.players p
  left join public.player_rankings pr on pr.player_id=p.id
  where p.world in ('ATP','WTA')
  on conflict(player_id,game_absolute_day) do update set
    world=excluded.world,season=excluded.season,ranking_position=excluded.ranking_position,ranking_points=excluded.ranking_points;
end; $function$
;