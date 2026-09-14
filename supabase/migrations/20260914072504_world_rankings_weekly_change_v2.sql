create or replace function public.get_world_rankings_v2(
  p_world text,
  p_offset integer default 0,
  p_limit integer default 50
)
returns table(
  rank_position bigint,
  player_id uuid,
  first_name text,
  last_name text,
  country_code text,
  image_path text,
  ranking_points integer,
  previous_week_position integer,
  rank_change integer
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with publication_days as (
    select game_absolute_day,
           row_number() over (order by game_absolute_day desc) as rn
    from (
      select distinct game_absolute_day
      from public.ranking_publication_runs
    ) d
  ),
  previous_publication as (
    select game_absolute_day
    from publication_days
    where rn = 2
  ),
  ranked as (
    select
      row_number() over (
        order by coalesce(r.ranking_points,0) desc,
                 coalesce(r.seed_rating,0) desc,
                 p.created_at asc,
                 p.id asc
      ) as rank_position,
      p.id as player_id,
      p.first_name,
      p.last_name,
      p.country_code,
      p.image_path,
      coalesce(r.ranking_points,0)::integer as ranking_points
    from public.players p
    left join public.player_rankings r on r.player_id = p.id
    where p.world = upper(p_world)
      and p.moderation_status <> 'rejected'
  )
  select
    ranked.rank_position,
    ranked.player_id,
    ranked.first_name,
    ranked.last_name,
    ranked.country_code,
    ranked.image_path,
    ranked.ranking_points,
    previous_snapshot.ranking_position::integer as previous_week_position,
    case
      when previous_snapshot.ranking_position is null then null
      else (previous_snapshot.ranking_position - ranked.rank_position)::integer
    end as rank_change
  from ranked
  left join lateral (
    select s.ranking_position
    from public.player_ranking_snapshots s
    where s.player_id = ranked.player_id
      and s.world = upper(p_world)
      and s.game_absolute_day = (select game_absolute_day from previous_publication)
    order by s.created_at desc
    limit 1
  ) previous_snapshot on true
  order by ranked.rank_position
  offset greatest(coalesce(p_offset,0),0)
  limit least(greatest(coalesce(p_limit,50),1),100);
$function$;

revoke all on function public.get_world_rankings_v2(text,integer,integer) from public, anon;
grant execute on function public.get_world_rankings_v2(text,integer,integer) to authenticated;
