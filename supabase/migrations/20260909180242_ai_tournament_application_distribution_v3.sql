create or replace function public.ai_tournament_application_soft_cap_v1(p_competition_id uuid)
returns integer
language sql
stable
set search_path to 'public'
as $function$
  with cfg as (
    select
      (c.main_draw_capacity-c.default_qualifier_slots+c.qualifying_capacity_max)::integer as total_entry_places,
      mod((hashtextextended(wc.id::text,0) & 2147483647),21)::integer as normal_noise,
      mod((hashtextextended(wc.id::text || ':large',0) & 2147483647),16)::integer as large_noise
    from public.tournament_world_competitions wc
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories c on c.code=s.category_code
    where wc.id=p_competition_id
  )
  select case
    when total_entry_places<=70 then greatest(total_entry_places+2,50+normal_noise)
    else total_entry_places+5+large_noise
  end
  from cfg;
$function$;

create or replace function public.refresh_ai_tournament_applications_v2(p_season integer,p_target_week smallint,p_world text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_now bigint:=public.current_game_second_v1();
  v_wave_close bigint;
  v_selected_competition uuid;
  v_assignments integer:=0;
  v_rebalanced integer:=0;
  r record;
begin
  if upper(p_world) not in ('ATP','WTA') then raise exception 'Invalid world.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(format('tournament-ai-refresh:%s:%s:%s',p_season,p_target_week,upper(p_world)),0));

  select min((public.get_tournament_entry_timeline_v1(wc.id)->>'normal_close_game_second')::bigint)
  into v_wave_close
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  where wc.world=upper(p_world)
    and e.season_number=p_season
    and wc.status<>'canceled' and e.status<>'canceled'
    and public.tournament_application_target_week_v1(wc.id)=p_target_week
    and not exists(select 1 from public.tournament_draw_publications d where d.competition_id=wc.id)
    and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
    and not exists(select 1 from public.tournament_competition_entry_cycles c where c.competition_id=wc.id and c.normal_allocation_processed_at is not null)
    and v_now>=(public.get_tournament_entry_timeline_v1(wc.id)->>'applications_open_game_second')::bigint
    and v_now<(public.get_tournament_entry_timeline_v1(wc.id)->'tournament_start'->>'game_second')::bigint;

  if v_wave_close is null then
    return jsonb_build_object('status','no_unresolved_wave','applications_touched',0,'season',p_season,'target_week',p_target_week,'world',upper(p_world));
  end if;

  update public.tournament_applications a
  set status='superseded',
      decision_reason='ai_rebalanced_open_field',
      decided_at=now(),
      updated_at=now()
  where a.status='applied'
    and a.application_source like 'ai%'
    and a.target_season_week=p_target_week
    and a.world=upper(p_world)
    and exists(
      select 1
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      where wc.id=a.competition_id
        and e.season_number=p_season
        and wc.status<>'canceled' and e.status<>'canceled'
        and not exists(select 1 from public.tournament_draw_publications d where d.competition_id=wc.id)
        and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
        and not exists(select 1 from public.tournament_competition_entry_cycles c where c.competition_id=wc.id and c.normal_allocation_processed_at is not null)
        and v_now>=(public.get_tournament_entry_timeline_v1(wc.id)->>'applications_open_game_second')::bigint
        and v_now<(public.get_tournament_entry_timeline_v1(wc.id)->>'normal_close_game_second')::bigint
    );
  get diagnostics v_rebalanced=row_count;

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
          and not (
            wc.status<>'canceled' and e.status<>'canceled'
            and not exists(select 1 from public.tournament_draw_publications d where d.competition_id=wc.id)
            and not exists(select 1 from public.tournament_matches m where m.competition_id=wc.id)
            and not exists(select 1 from public.tournament_competition_entry_cycles c where c.competition_id=wc.id and c.normal_allocation_processed_at is not null)
            and v_now>=(public.get_tournament_entry_timeline_v1(wc.id)->>'applications_open_game_second')::bigint
            and v_now<(public.get_tournament_entry_timeline_v1(wc.id)->>'normal_close_game_second')::bigint
          )
      )
    order by rank_pos,r0.id
  loop
    select candidate.competition_id
    into v_selected_competition
    from (
      select wc.id competition_id,
             public.ai_tournament_fit_score_v1(
               r.rank_pos,s.category_code,r.preferred_surface,s.surface,r.id,wc.id,r.country_code=s.country_code
             ) fit_score,
             public.ai_tournament_application_soft_cap_v1(wc.id) soft_cap,
             (select count(*) from public.tournament_applications a where a.competition_id=wc.id and a.status='applied') live_count
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
        and v_now>=(public.get_tournament_entry_timeline_v1(wc.id)->>'applications_open_game_second')::bigint
        and v_now<(public.get_tournament_entry_timeline_v1(wc.id)->>'normal_close_game_second')::bigint
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
$function$;

create or replace function public.get_tournament_application_field_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_world text;
  v_name text;
  v_main_capacity integer;
  v_qualifier_slots integer;
  v_direct_slots integer;
  v_qcap integer;
  v_phase text;
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select wc.world,ts.name,c.main_draw_capacity,c.default_qualifier_slots,
         c.main_draw_capacity-c.default_qualifier_slots,c.qualifying_capacity_max
  into v_world,v_name,v_main_capacity,v_qualifier_slots,v_direct_slots,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories c on c.code=ts.category_code
  where wc.id=p_competition_id;
  if v_world is null then raise exception 'Tournament not found.'; end if;

  v_phase:=public.get_tournament_entry_lifecycle_v2(p_competition_id)->>'phase';

  with ranked_world as (
    select p.id player_id,
           row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer current_world_rank
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world and p.moderation_status<>'rejected'
  ), base as (
    select a.id application_id,a.player_id,p.first_name,p.last_name,p.country_code,p.player_type,
           a.priority,a.accept_qualification,a.application_source,a.status application_status,a.decision_reason,
           coalesce(a.ranking_position_snapshot,rw.current_world_rank)::integer world_rank,
           rw.current_world_rank,
           te.draw_type entry_draw_type,te.entry_status,
           (p.owner_user_id=v_uid) is_user,
           row_number() over(order by coalesce(a.ranking_position_snapshot,rw.current_world_rank),a.created_at,a.id)::integer overall_order
    from public.tournament_applications a
    join public.players p on p.id=a.player_id
    join ranked_world rw on rw.player_id=a.player_id
    left join public.tournament_entries te on te.competition_id=a.competition_id and te.player_id=a.player_id
    where a.competition_id=p_competition_id
      and a.status in ('applied','accepted_main_draw','accepted_qualification')
  ), staged as (
    select b.*,
           count(*) filter(where b.overall_order>v_direct_slots and b.accept_qualification and b.application_status in ('applied','accepted_qualification'))
             over(order by b.overall_order rows between unbounded preceding and current row)::integer as qualification_order
    from base b
  ), projected as (
    select s.*,
      case
        when s.entry_draw_type='main_draw' then 'main_draw'
        when s.entry_draw_type='qualification' then 'qualification'
        when s.application_status='accepted_main_draw' then 'main_draw'
        when s.application_status='accepted_qualification' then 'qualification'
        when s.application_status='applied' and s.overall_order<=v_direct_slots then 'main_draw'
        when s.application_status='applied' and s.overall_order>v_direct_slots and s.accept_qualification and s.qualification_order<=v_qcap then 'qualification'
        else 'outside'
      end projected_group
    from staged s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'application_id',application_id,'player_id',player_id,'first_name',first_name,'last_name',last_name,
      'country_code',country_code,'player_type',player_type,'world_rank',world_rank,'current_world_rank',current_world_rank,'priority',priority,
      'accept_qualification',accept_qualification,'application_source',application_source,'application_status',application_status,
      'decision_reason',decision_reason,'entry_draw_type',entry_draw_type,'entry_status',entry_status,'is_user',is_user,
      'projected_group',projected_group
    ) order by case projected_group when 'main_draw' then 1 when 'qualification' then 2 else 3 end,world_rank,application_id),'[]'::jsonb)
  into v_rows from projected;

  return jsonb_build_object(
    'competition_id',p_competition_id,'tournament_name',v_name,'world',v_world,'phase',v_phase,
    'main_draw_total_capacity',v_main_capacity,'direct_main_draw_slots',v_direct_slots,'qualifier_slots',v_qualifier_slots,
    'qualification_capacity',v_qcap,'applicant_count',jsonb_array_length(v_rows),'applicants',v_rows
  );
end;
$function$;