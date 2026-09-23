-- Fix PL/pgSQL record/SQL alias collision in doubles ranking recalculation.

create or replace function public.process_doubles_rankings_for_day_v1(p_absolute_day integer)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare c record;v_pub integer:=0;v_exp integer:=0;v_act integer:=0;v_cycles integer:=0;v_n integer;v_cycle_pub integer;v_cycle_exp integer;v_cycle_act integer;
begin
  for c in
    select wc.id competition_id,e.tournament_series_id,wc.world,e.season_number,
      public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7 publish_day
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
    where exists(select 1 from public.tournament_doubles_matches dm where dm.competition_id=wc.id and lower(dm.round_label)='final' and dm.status in ('completed','walkover') and dm.winner_team_id is not null)
    group by wc.id,e.tournament_series_id,wc.world,e.season_number
    having public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7<=p_absolute_day
       and not exists(select 1 from public.doubles_ranking_defence_cycles dc where dc.competition_id=wc.id)
  loop
    v_cycle_pub:=0;v_cycle_exp:=0;v_cycle_act:=0;
    update public.player_doubles_tournament_results r set ranking_publish_status='published',ranking_published_at=coalesce(r.ranking_published_at,now()),updated_at=now()
    where r.competition_id=c.competition_id and r.ranking_publish_status='pending' and r.ranking_publish_absolute_day<=p_absolute_day;
    get diagnostics v_n=row_count;v_cycle_pub:=v_n;v_pub:=v_pub+v_n;
    if c.season_number>1 then
      update public.player_doubles_ranking_contributions oldc set is_active=false,deactivated_absolute_day=p_absolute_day,deactivated_at=now(),
        replaced_by_result_id=(select r.id from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.player_id=oldc.player_id and r.ranking_publish_status='published' limit 1),
        replaced_by_competition_id=c.competition_id,replacement_reason=case when exists(select 1 from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.player_id=oldc.player_id and r.ranking_publish_status='published') then 'next_edition_result' else 'next_edition_no_result' end,updated_at=now()
      where oldc.is_active and oldc.tournament_series_id=c.tournament_series_id and oldc.world=c.world and oldc.season_number=c.season_number-1;
      get diagnostics v_n=row_count;v_cycle_exp:=v_n;v_exp:=v_exp+v_n;
    end if;
    insert into public.player_doubles_ranking_contributions(player_id,source_result_id,competition_id,tournament_series_id,world,season_number,ranking_points,awarded_absolute_day,expires_absolute_day,published_at,is_active)
    select r.player_id,r.id,r.competition_id,c.tournament_series_id,c.world,c.season_number,r.ranking_points_earned,coalesce(r.ranking_publish_absolute_day,p_absolute_day),coalesce(r.ranking_publish_absolute_day,p_absolute_day)+366,coalesce(r.ranking_published_at,now()),true
    from public.player_doubles_tournament_results r where r.competition_id=c.competition_id and r.ranking_publish_status='published'
    on conflict(source_result_id) do nothing;
    get diagnostics v_n=row_count;v_cycle_act:=v_n;v_act:=v_act+v_n;
    insert into public.doubles_ranking_defence_cycles(competition_id,tournament_series_id,world,season_number,scheduled_publish_absolute_day,processed_absolute_day,published_results,expired_contributions,activated_contributions)
    values(c.competition_id,c.tournament_series_id,c.world,c.season_number,c.publish_day,p_absolute_day,v_cycle_pub,v_cycle_exp,v_cycle_act) on conflict(competition_id) do nothing;
    v_cycles:=v_cycles+1;
  end loop;

  update public.player_doubles_ranking_contributions
  set is_active=false,deactivated_absolute_day=p_absolute_day,deactivated_at=now(),replacement_reason=coalesce(replacement_reason,'scheduled_expiration'),updated_at=now()
  where is_active and expires_absolute_day<=p_absolute_day;
  get diagnostics v_n=row_count;v_exp:=v_exp+v_n;

  update public.player_doubles_rankings r
  set ranking_points=coalesce((
    select sum(rc.ranking_points)::integer
    from public.player_doubles_ranking_contributions rc
    where rc.player_id=r.player_id and rc.is_active
  ),0),
  updated_at=now();

  insert into public.player_doubles_ranking_snapshots(player_id,world,game_absolute_day,ranking_position,ranking_points)
  select player_id,world,p_absolute_day,row_number() over(partition by world order by ranking_points desc,seed_rating desc,player_id)::integer,ranking_points
  from public.player_doubles_rankings
  on conflict(player_id,game_absolute_day) do update set ranking_position=excluded.ranking_position,ranking_points=excluded.ranking_points;

  insert into public.doubles_ranking_publication_runs(game_absolute_day,published_results,defence_cycles_processed,contributions_expired,contributions_activated,processed_at)
  values(p_absolute_day,v_pub,v_cycles,v_exp,v_act,now())
  on conflict(game_absolute_day) do update set
    published_results=excluded.published_results,
    defence_cycles_processed=excluded.defence_cycles_processed,
    contributions_expired=excluded.contributions_expired,
    contributions_activated=excluded.contributions_activated,
    processed_at=now();

  return jsonb_build_object('status','published','game_absolute_day',p_absolute_day,'published_results',v_pub,'defence_cycles_processed',v_cycles,'contributions_expired',v_exp,'contributions_activated',v_act);
end;
$$;