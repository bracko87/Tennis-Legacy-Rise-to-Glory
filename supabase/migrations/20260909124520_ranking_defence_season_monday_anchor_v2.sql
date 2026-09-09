create or replace function public.process_weekly_rankings_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  d record;
  v_abs integer;
  v_season_day_index integer;
  v_cycle record;
  v_step integer:=0;
  v_new_results integer:=0;
  v_cycle_count integer:=0;
  v_expired integer:=0;
  v_activated integer:=0;
  v_orphan_expired integer:=0;
  v_cycle_expired integer:=0;
  v_cycle_activated integer:=0;
  v_cycle_published integer:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  v_season_day_index:=v_abs-((d.season-1)*366);

  -- Every season explicitly restarts its competition-week calendar with Jan 3 as Monday.
  if mod(v_season_day_index-2,7)<>0 then
    return jsonb_build_object('status','not_monday','game_absolute_day',v_abs,'season_day_index',v_season_day_index);
  end if;

  for v_cycle in
    with cycle_days as (
      select
        wc.id competition_id,
        e.tournament_series_id,
        wc.world,
        e.season_number,
        public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7 as publish_day,
        exists(select 1 from public.tournament_cancellations tc where tc.competition_id=wc.id) as is_cancelled,
        exists(
          select 1
          from public.tournament_matches tm
          where tm.competition_id=wc.id
            and tm.draw_type='main_draw'
            and lower(tm.round_label)='final'
            and tm.status in ('completed','walkover')
            and tm.winner_id is not null
        ) as final_resolved
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
      group by wc.id,e.tournament_series_id,wc.world,e.season_number
    )
    select *
    from cycle_days cd
    where cd.publish_day<=v_abs
      and (cd.is_cancelled or cd.final_resolved)
      and not exists(select 1 from public.ranking_defence_cycles dc where dc.competition_id=cd.competition_id)
    order by cd.publish_day,cd.competition_id
  loop
    v_cycle_published:=0;
    v_cycle_expired:=0;
    v_cycle_activated:=0;

    update public.player_tournament_results r
    set ranking_publish_status='published',
        ranking_published_at=coalesce(r.ranking_published_at,now()),
        updated_at=now()
    where r.competition_id=v_cycle.competition_id
      and r.ranking_publish_status='pending'
      and r.ranking_publish_absolute_day is not null
      and r.ranking_publish_absolute_day<=v_abs;
    get diagnostics v_cycle_published=row_count;
    v_new_results:=v_new_results+v_cycle_published;

    if v_cycle.season_number>1 then
      update public.player_ranking_contributions oldc
      set is_active=false,
          deactivated_absolute_day=v_abs,
          deactivated_at=now(),
          replaced_by_result_id=(
            select r.id
            from public.player_tournament_results r
            where r.competition_id=v_cycle.competition_id
              and r.player_id=oldc.player_id
              and r.ranking_publish_status='published'
            limit 1
          ),
          replaced_by_competition_id=v_cycle.competition_id,
          replacement_reason=case
            when v_cycle.is_cancelled then 'next_edition_cancelled'
            when exists(
              select 1 from public.player_tournament_results r
              where r.competition_id=v_cycle.competition_id
                and r.player_id=oldc.player_id
                and r.ranking_publish_status='published'
            ) then 'next_edition_result'
            else 'next_edition_no_result'
          end,
          updated_at=now()
      where oldc.is_active
        and oldc.tournament_series_id=v_cycle.tournament_series_id
        and oldc.world=v_cycle.world
        and oldc.season_number=v_cycle.season_number-1;
      get diagnostics v_cycle_expired=row_count;
      v_expired:=v_expired+v_cycle_expired;
    end if;

    insert into public.player_ranking_contributions(
      player_id,source_result_id,competition_id,tournament_series_id,world,
      season_number,ranking_points,awarded_absolute_day,published_at,is_active
    )
    select
      r.player_id,r.id,r.competition_id,v_cycle.tournament_series_id,v_cycle.world,
      v_cycle.season_number,greatest(coalesce(r.ranking_points_earned,0),0),
      coalesce(r.ranking_publish_absolute_day,v_abs),coalesce(r.ranking_published_at,now()),true
    from public.player_tournament_results r
    where r.competition_id=v_cycle.competition_id
      and r.ranking_publish_status='published'
      and coalesce(r.ranking_publish_absolute_day,v_abs)<=v_abs
    on conflict(source_result_id) do nothing;
    get diagnostics v_cycle_activated=row_count;
    v_activated:=v_activated+v_cycle_activated;

    insert into public.ranking_defence_cycles(
      competition_id,tournament_series_id,world,season_number,previous_season_number,
      scheduled_publish_absolute_day,processed_absolute_day,processing_reason,
      published_results,expired_contributions,activated_contributions,processed_at
    ) values (
      v_cycle.competition_id,v_cycle.tournament_series_id,v_cycle.world,v_cycle.season_number,
      case when v_cycle.season_number>1 then v_cycle.season_number-1 else null end,
      v_cycle.publish_day,v_abs,
      case when v_cycle.is_cancelled then 'edition_cancelled' else 'edition_completed' end,
      v_cycle_published,v_cycle_expired,v_cycle_activated,now()
    ) on conflict(competition_id) do nothing;
    v_cycle_count:=v_cycle_count+1;
  end loop;

  update public.player_ranking_contributions c
  set is_active=false,
      deactivated_absolute_day=v_abs,
      deactivated_at=now(),
      replacement_reason='series_removed_anniversary',
      updated_at=now()
  where c.is_active
    and c.season_number<d.season
    and c.awarded_absolute_day+366<=v_abs
    and not exists(
      select 1
      from public.tournament_editions e2
      join public.tournament_world_competitions wc2 on wc2.tournament_edition_id=e2.id and wc2.world=c.world
      where e2.tournament_series_id=c.tournament_series_id
        and e2.season_number=c.season_number+1
        and exists(select 1 from public.tournament_schedule_slots ss2 where ss2.tournament_edition_id=e2.id)
    );
  get diagnostics v_orphan_expired=row_count;

  update public.player_ranking_contributions c
  set is_active=false,
      deactivated_absolute_day=coalesce(c.deactivated_absolute_day,v_abs),
      deactivated_at=coalesce(c.deactivated_at,now()),
      replacement_reason=coalesce(c.replacement_reason,'superseded_safety'),
      updated_at=now()
  where c.is_active
    and exists(
      select 1
      from public.ranking_defence_cycles dc
      where dc.tournament_series_id=c.tournament_series_id
        and dc.world=c.world
        and dc.season_number>c.season_number
    );
  get diagnostics v_step=row_count;
  v_expired:=v_expired+v_orphan_expired+v_step;

  update public.player_rankings pr
  set ranking_points=coalesce((
    select sum(c.ranking_points)::integer
    from public.player_ranking_contributions c
    where c.player_id=pr.player_id and c.is_active
  ),0),
  updated_at=now();

  perform public.capture_world_ranking_snapshot_internal_v1();

  insert into public.ranking_publication_runs(
    game_absolute_day,season,month,day,published_results,processed_at,
    defence_cycles_processed,contributions_expired,contributions_activated,orphan_contributions_expired
  ) values (
    v_abs,d.season,d.month,d.day,v_new_results,now(),
    v_cycle_count,v_expired,v_activated,v_orphan_expired
  )
  on conflict(game_absolute_day) do update set
    published_results=public.ranking_publication_runs.published_results+excluded.published_results,
    defence_cycles_processed=public.ranking_publication_runs.defence_cycles_processed+excluded.defence_cycles_processed,
    contributions_expired=public.ranking_publication_runs.contributions_expired+excluded.contributions_expired,
    contributions_activated=public.ranking_publication_runs.contributions_activated+excluded.contributions_activated,
    orphan_contributions_expired=public.ranking_publication_runs.orphan_contributions_expired+excluded.orphan_contributions_expired,
    processed_at=now();

  return jsonb_build_object(
    'status','published',
    'game_absolute_day',v_abs,
    'season_day_index',v_season_day_index,
    'new_results_published',v_new_results,
    'defence_cycles_processed',v_cycle_count,
    'contributions_expired',v_expired,
    'contributions_activated',v_activated,
    'orphan_contributions_expired',v_orphan_expired
  );
end;
$function$;