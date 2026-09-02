create or replace function public.get_player_profile_v2(p_player_id uuid)
returns table(
  player_id uuid,first_name text,last_name text,world text,country_code text,home_city text,image_path text,
  preferred_surface text,playing_style text,ranking_points integer,rank_position bigint,is_own_player boolean,is_ai boolean
)
language sql
stable security definer
set search_path=public
as $$
  with target as(
    select p.* from public.players p where p.id=p_player_id and p.moderation_status<>'rejected'
  ), ranked as(
    select p.id,row_number() over(
      order by coalesce(r.ranking_points,0) desc,coalesce(r.seed_rating,0) desc,p.created_at asc,p.id asc
    ) rank_position
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world=(select world from target) and p.moderation_status<>'rejected'
  )
  select t.id,t.first_name,t.last_name,t.world,t.country_code,t.home_city,t.image_path,t.preferred_surface,t.playing_style,
    coalesce(pr.ranking_points,0)::integer,ranked.rank_position,coalesce(t.owner_user_id=auth.uid(),false),(t.player_type='ai')
  from target t left join public.player_rankings pr on pr.player_id=t.id left join ranked on ranked.id=t.id;
$$;
grant execute on function public.get_player_profile_v2(uuid) to authenticated;
