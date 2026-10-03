-- Compute each eligible competition's entry timeline once per planner run.
-- Reuse the bounded candidate set for player assignment and AI rebalancing.
CREATE OR REPLACE FUNCTION public.refresh_ai_tournament_applications_v2(p_season integer, p_target_week smallint, p_world text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now bigint:=public.current_game_second_v1();
  v_wave_close bigint;
  v_selected_competition uuid;
  v_assignments integer:=0;
  v_rebalanced integer:=0;
  v_candidates jsonb:='[]'::jsonb;
  v_open_ids uuid[]:='{}'::uuid[];
  r record;
begin
  if upper(p_world) not in ('ATP','WTA') then raise exception 'Invalid world.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(format('tournament-ai-refresh:%s:%s:%s',p_season,p_target_week,upper(p_world)),0));

  -- Resolve the timeline once per eligible competition. The previous player
  -- loop recomputed it for every AI player and exhausted the cron time limit.
  with base as materialized (
    select wc.id,s.category_code,s.surface,s.country_code
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    where wc.world=upper(p_world)
      and e.season_number=p_season
      and wc.status<>'canceled' and e.status<>'canceled'
      and public.tournament_application_target_week_v1(wc.id)=p_target_week
      and not exists(select 1 from public.tournament_draw_publications d where d.competition_id=wc.id)
      and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
      and not exists(select 1 from public.tournament_competition_entry_cycles c where c.competition_id=wc.id and c.normal_allocation_processed_at is not null)
  ), timelines as materialized (
    select b.*,public.get_tournament_entry_timeline_v1(b.id) timeline
    from base b
  ), windows as materialized (
    select t.*,
      (t.timeline->>'applications_open_game_second')::bigint open_second,
      (t.timeline->>'normal_close_game_second')::bigint close_second,
      (t.timeline->'tournament_start'->>'game_second')::bigint start_second
    from timelines t
  )
  select min(close_second) filter(where v_now>=open_second and v_now<start_second),
         coalesce(jsonb_agg(jsonb_build_object(
           'competition_id',id,'category_code',category_code,'surface',surface,
           'country_code',country_code,
           'soft_cap',public.ai_tournament_application_soft_cap_v1(id)
         )) filter(where v_now>=open_second and v_now<close_second),'[]'::jsonb),
         coalesce(array_agg(id) filter(where v_now>=open_second and v_now<close_second),'{}'::uuid[])
  into v_wave_close,v_candidates,v_open_ids
  from windows;

  if v_wave_close is null then
    return jsonb_build_object('status','no_unresolved_wave','applications_touched',0,'season',p_season,'target_week',p_target_week,'world',upper(p_world));
  end if;

  -- Re-open AI planning only for competitions whose normal application window is
  -- still open. Closed-wave applications are left untouched while they await allocation.
  update public.tournament_applications a
  set status='superseded',
      decision_reason='ai_rebalanced_open_field',
      decided_at=now(),
      updated_at=now()
  where a.status='applied'
    and a.application_source like 'ai%'
    and a.target_season_week=p_target_week
    and a.world=upper(p_world)
    and a.competition_id = any(v_open_ids);
  get diagnostics v_rebalanced=row_count;

  -- Stronger players are processed first. If an event has reached its soft cap,
  -- they naturally choose their next-best still-open event. Re-running the planner
  -- therefore lets a newly stronger player replace a weaker AI applicant without
  -- ever exceeding the cap, while the displaced player can move elsewhere.
  for r in
    with ranked as (
      select p.id,p.country_code,p.preferred_surface,
             row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer rank_pos,
             coalesce(pr.ranking_points,0)::integer points
      from public.players p
      left join public.player_rankings pr on pr.player_id=p.id
      where p.world=upper(p_world) and p.player_type='ai' and p.moderation_status<>'rejected'
    )
    select *
    from ranked r0
    where not exists(
      select 1
      from public.tournament_entries te
      join public.tournament_world_competitions wc on wc.id=te.competition_id
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      where te.player_id=r0.id and te.entry_status='active'
        and e.season_number=p_season
        and public.tournament_application_target_week_v1(wc.id)=p_target_week
    )
      and not exists(
        select 1
        from public.tournament_applications a
        join public.tournament_world_competitions wc on wc.id=a.competition_id
        join public.tournament_editions e on e.id=wc.tournament_edition_id
        where a.player_id=r0.id
          and a.target_season_week=p_target_week
          and a.status='applied'
          and e.season_number=p_season
          and a.competition_id <> all(v_open_ids)
      )
    order by rank_pos,r0.id
  loop
    select candidate.competition_id
    into v_selected_competition
    from (
      select c.competition_id,
             public.ai_tournament_fit_score_v1(
               r.rank_pos,c.category_code,r.preferred_surface,c.surface,
               r.id,c.competition_id,r.country_code=c.country_code
             ) fit_score,
             c.soft_cap,
             (select count(*) from public.tournament_applications a
              where a.competition_id=c.competition_id and a.status='applied') live_count
      from jsonb_to_recordset(v_candidates)
        as c(competition_id uuid,category_code text,surface text,country_code text,soft_cap integer)
    ) candidate
    where candidate.fit_score>-100000
      and candidate.live_count<candidate.soft_cap
    order by candidate.fit_score desc,
             (candidate.live_count::numeric/nullif(candidate.soft_cap,0)) asc,
             candidate.competition_id
    limit 1;

    if v_selected_competition is null then
      continue;
    end if;

    insert into public.tournament_applications(
      competition_id,player_id,owner_user_id,world,status,
      ranking_position_snapshot,ranking_points_snapshot,priority,accept_qualification,
      application_source,target_season_week,decision_reason,decided_at,created_at,updated_at
    ) values (
      v_selected_competition,r.id,null,upper(p_world),'applied',
      r.rank_pos,r.points,null,true,'ai',p_target_week,null,null,now(),now()
    )
    on conflict(competition_id,player_id) do update
    set status='applied',
        ranking_position_snapshot=excluded.ranking_position_snapshot,
        ranking_points_snapshot=excluded.ranking_points_snapshot,
        priority=null,
        accept_qualification=true,
        application_source='ai',
        target_season_week=excluded.target_season_week,
        decision_reason=null,
        decided_at=null,
        updated_at=now();
    v_assignments:=v_assignments+1;
  end loop;

  return jsonb_build_object(
    'status','refreshed',
    'applications_touched',v_assignments,
    'applications_rebalanced',v_rebalanced,
    'wave_close_game_second',v_wave_close,
    'season',p_season,
    'target_week',p_target_week,
    'world',upper(p_world),
    'soft_cap_model','normal events 50-70 applicants, never below usable field capacity; larger events scale above capacity'
  );
end;
$function$
;
