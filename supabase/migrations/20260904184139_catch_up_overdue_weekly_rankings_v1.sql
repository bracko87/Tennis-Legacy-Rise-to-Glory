do $$
declare
  v_now_abs integer;
  v_pub_day integer;
  v_published integer;
  v_date record;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_now_abs
  from public.get_current_game_day_internal_v1() d;

  for v_pub_day in
    select distinct ranking_publish_absolute_day
    from public.player_tournament_results
    where ranking_publish_status='pending'
      and ranking_publish_absolute_day is not null
      and ranking_publish_absolute_day<=v_now_abs
    order by ranking_publish_absolute_day
  loop
    update public.player_tournament_results
    set ranking_publish_status='published',
        ranking_published_at=coalesce(ranking_published_at,now()),
        updated_at=now()
    where ranking_publish_status='pending'
      and ranking_publish_absolute_day=v_pub_day;
    get diagnostics v_published=row_count;

    with points as (
      select p.id player_id,p.world,coalesce(pr.seed_rating,0) seed_rating,
             coalesce(sum(r.ranking_points_earned) filter (
               where r.ranking_publish_status='published'
                 and r.ranking_publish_absolute_day<=v_pub_day
                 and r.ranking_publish_absolute_day>v_pub_day-364
             ),0)::integer ranking_points
      from public.players p
      left join public.player_rankings pr on pr.player_id=p.id
      left join public.player_tournament_results r on r.player_id=p.id
      where p.world in ('ATP','WTA') and p.moderation_status<>'rejected'
      group by p.id,p.world,pr.seed_rating
    ), ranked as (
      select player_id,world,ranking_points,
             row_number() over(partition by world order by ranking_points desc,seed_rating desc,player_id)::integer ranking_position
      from points
    )
    insert into public.player_ranking_snapshots(player_id,world,season,game_absolute_day,ranking_position,ranking_points)
    select ranked.player_id,ranked.world,(public.absolute_game_day_v1(v_pub_day)).season,v_pub_day,ranked.ranking_position,ranked.ranking_points
    from ranked
    on conflict(player_id,game_absolute_day) do update set
      world=excluded.world,
      season=excluded.season,
      ranking_position=excluded.ranking_position,
      ranking_points=excluded.ranking_points;

    select * into v_date from public.absolute_game_day_v1(v_pub_day);
    insert into public.ranking_publication_runs(game_absolute_day,season,month,day,published_results,processed_at)
    values(v_pub_day,v_date.season,v_date.month,v_date.day,v_published,now())
    on conflict(game_absolute_day) do update set
      published_results=greatest(public.ranking_publication_runs.published_results,excluded.published_results),
      processed_at=now();
  end loop;

  update public.player_rankings pr
  set ranking_points=coalesce((
        select sum(r.ranking_points_earned)::integer
        from public.player_tournament_results r
        where r.player_id=pr.player_id
          and r.ranking_publish_status='published'
          and r.ranking_publish_absolute_day>v_now_abs-364
      ),0),
      updated_at=now();
end $$;
