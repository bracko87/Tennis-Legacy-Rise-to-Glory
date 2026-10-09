-- Fix tournament completion status and AI tournament hierarchy / deep-rank participation.
-- 1) Completed finals now mark competitions (and editions when both worlds are done) completed.
-- 2) AI planning respects category prestige before lower tiers.
-- 3) Lower-tier AI eligibility extends beyond rank 300.
-- 4) Late vacancy fill respects real overlapping tournament commitments.
-- 5) Repair the current Season 1 Monte Carlo ATP field before draw publication.

create or replace function public.ai_tournament_rank_ceiling_v1(p_category text)
returns integer
language sql
immutable
set search_path to 'public'
as $function$
  select case p_category
    when 'grand_slam_2000' then 280
    when 'masters_1000' then 120
    when 'tour_500' then 200
    when 'tour_250' then 280
    when 'challenger_125' then 340
    when 'challenger_100' then 370
    when 'challenger_75' then 400
    when 'challenger_50' then 430
    when 'futures_25' then 500
    when 'futures_15' then 10000
    else 10000
  end;
$function$;

create or replace function public.ai_tournament_fit_score_v1(
  p_rank integer,
  p_category text,
  p_preferred_surface text,
  p_surface text,
  p_player_id uuid,
  p_competition_id uuid,
  p_same_country boolean
)
returns integer
language plpgsql
immutable
set search_path to 'public'
as $function$
declare
  v_ideal integer;
  v_score integer;
  v_noise integer;
  v_prestige integer;
begin
  if p_rank is null
     or p_rank < public.ai_tournament_rank_floor_v1(p_category)
     or p_rank > public.ai_tournament_rank_ceiling_v1(p_category)
  then
    return -100000;
  end if;

  v_ideal:=case p_category
    when 'grand_slam_2000' then 70
    when 'masters_1000' then 70
    when 'tour_500' then 120
    when 'tour_250' then 170
    when 'challenger_125' then 210
    when 'challenger_100' then 235
    when 'challenger_75' then 275
    when 'challenger_50' then 315
    when 'futures_25' then 360
    else 400
  end;

  v_prestige:=case p_category
    when 'grand_slam_2000' then 600
    when 'masters_1000' then 400
    when 'tour_500' then 250
    when 'tour_250' then 150
    when 'challenger_125' then 80
    when 'challenger_100' then 60
    when 'challenger_75' then 40
    when 'challenger_50' then 20
    when 'futures_25' then 10
    else 0
  end;

  v_noise:=mod((hashtext(p_player_id::text||':'||p_competition_id::text)::bigint & 2147483647),81)::integer;
  v_score:=1000+v_prestige-abs(p_rank-v_ideal)*3+v_noise;

  if lower(coalesce(p_preferred_surface,''))=lower(coalesce(p_surface,'')) then
    v_score:=v_score+45;
  end if;
  if p_same_country then
    v_score:=v_score+25;
  end if;

  return v_score;
end;
$function$;

create or replace function public.fill_ai_late_tournament_vacancies_v1(p_competition_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_cycle public.tournament_competition_entry_cycles%rowtype;
  v_tl jsonb;
  v_now bigint:=public.current_game_second_v1();
  v_world text;
  v_season integer;
  v_week smallint;
  v_category text;
  v_surface text;
  v_country text;
  v_direct integer;
  v_qcap integer;
  v_main integer;
  v_q integer;
  r record;
  v_added_main integer:=0;
  v_added_q integer:=0;
begin
  if exists(select 1 from public.tournament_matches where competition_id=p_competition_id)
     or exists(select 1 from public.tournament_draw_publications where competition_id=p_competition_id) then
    return jsonb_build_object('status','draw_already_exists');
  end if;

  v_tl:=public.get_tournament_entry_timeline_v1(p_competition_id);
  if v_now>=(v_tl->'tournament_start'->>'game_second')::bigint then
    return jsonb_build_object('status','tournament_started');
  end if;

  insert into public.tournament_competition_entry_cycles(competition_id)
  values(p_competition_id)
  on conflict do nothing;

  select * into v_cycle
  from public.tournament_competition_entry_cycles
  where competition_id=p_competition_id
  for update;

  if v_cycle.ai_late_fill_processed_at is not null then
    return jsonb_build_object('status','already_processed');
  end if;
  if v_now<(v_tl->>'late_close_game_second')::bigint-300 then
    return jsonb_build_object('status','not_due');
  end if;

  select wc.world,e.season_number,s.category_code,s.surface,s.country_code,
         c.main_draw_capacity-c.default_qualifier_slots,c.qualifying_capacity_max
  into v_world,v_season,v_category,v_surface,v_country,v_direct,v_qcap
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  join public.tournament_categories c on c.code=s.category_code
  where wc.id=p_competition_id;

  v_week:=(v_tl->>'target_season_week')::smallint;

  select count(*) into v_main
  from public.tournament_entries
  where competition_id=p_competition_id and draw_type='main_draw' and entry_status='active';

  select count(*) into v_q
  from public.tournament_entries
  where competition_id=p_competition_id and draw_type='qualification' and entry_status='active';

  for r in
    with ranked as (
      select p.id,p.country_code,p.preferred_surface,
             row_number() over(
               order by coalesce(pr.ranking_points,0) desc,
                        coalesce(pr.seed_rating,0) desc,
                        p.created_at,p.id
             )::integer rank_pos,
             coalesce(pr.ranking_points,0)::integer points
      from public.players p
      left join public.player_rankings pr on pr.player_id=p.id
      where p.world=v_world
        and p.player_type='ai'
        and p.moderation_status<>'rejected'
    )
    select *,
      public.ai_tournament_fit_score_v1(
        rank_pos,v_category,preferred_surface,v_surface,id,p_competition_id,country_code=v_country
      ) score
    from ranked
    where public.ai_tournament_fit_score_v1(
            rank_pos,v_category,preferred_surface,v_surface,id,p_competition_id,country_code=v_country
          )>-100000
      and coalesce(
            (public.check_player_competition_availability_v1(id,p_competition_id)->>'available')::boolean,
            false
          )
    order by score desc,rank_pos,id
  loop
    exit when v_main>=v_direct and v_q>=v_qcap;

    perform pg_advisory_xact_lock(
      hashtextextended(format('tournament-entry:%s:%s:%s',r.id,v_season,v_week),0)
    );

    if v_main<v_direct then
      insert into public.tournament_entries(
        competition_id,player_id,world,draw_type,entry_status,entry_source,ranking_position_snapshot
      )
      values(
        p_competition_id,r.id,v_world,'main_draw','active','application',r.rank_pos
      )
      on conflict do nothing;

      if found then
        v_main:=v_main+1;
        v_added_main:=v_added_main+1;

        insert into public.tournament_applications(
          competition_id,player_id,owner_user_id,world,status,
          ranking_position_snapshot,ranking_points_snapshot,priority,accept_qualification,
          application_source,target_season_week,decision_reason,decided_at
        )
        values(
          p_competition_id,r.id,null,v_world,'accepted_main_draw',
          r.rank_pos,r.points,null,true,'ai_late_fill',v_week,'final_vacancy_fill',now()
        )
        on conflict(competition_id,player_id) do update
        set status='accepted_main_draw',
            application_source='ai_late_fill',
            priority=null,
            decision_reason='final_vacancy_fill',
            decided_at=now(),
            ranking_position_snapshot=excluded.ranking_position_snapshot,
            ranking_points_snapshot=excluded.ranking_points_snapshot,
            updated_at=now();
      end if;

    elsif v_q<v_qcap then
      insert into public.tournament_entries(
        competition_id,player_id,world,draw_type,entry_status,entry_source,ranking_position_snapshot
      )
      values(
        p_competition_id,r.id,v_world,'qualification','active','application',r.rank_pos
      )
      on conflict do nothing;

      if found then
        v_q:=v_q+1;
        v_added_q:=v_added_q+1;

        insert into public.tournament_applications(
          competition_id,player_id,owner_user_id,world,status,
          ranking_position_snapshot,ranking_points_snapshot,priority,accept_qualification,
          application_source,target_season_week,decision_reason,decided_at
        )
        values(
          p_competition_id,r.id,null,v_world,'accepted_qualification',
          r.rank_pos,r.points,null,true,'ai_late_fill',v_week,'final_vacancy_fill',now()
        )
        on conflict(competition_id,player_id) do update
        set status='accepted_qualification',
            application_source='ai_late_fill',
            priority=null,
            decision_reason='final_vacancy_fill',
            decided_at=now(),
            ranking_position_snapshot=excluded.ranking_position_snapshot,
            ranking_points_snapshot=excluded.ranking_points_snapshot,
            updated_at=now();
      end if;
    end if;
  end loop;

  update public.tournament_competition_entry_cycles
  set ai_late_fill_processed_at=now(),
      ai_late_fill_game_second=v_now,
      updated_at=now()
  where competition_id=p_competition_id;

  return jsonb_build_object(
    'status','processed',
    'main_draw_added',v_added_main,
    'qualification_added',v_added_q,
    'main_draw_total',v_main,
    'qualification_total',v_q
  );
end;
$function$;

create or replace function public.process_tournament_entry_lifecycle_v2()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_now bigint:=public.current_game_second_v1();
  v_today integer:=floor(public.current_game_second_v1()::numeric/86400)::integer;
  g record;
  r record;
  res jsonb;
  v_apps integer:=0;
  v_alloc integer:=0;
  v_fill integer:=0;
  v_lock integer:=0;
  v_alloc_round integer;
  v_wave_close bigint;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('tournament-entry-lifecycle-v3',0)) then
    return jsonb_build_object('status','busy','game_second',v_now);
  end if;

  -- Process groups containing the strongest tournament category first.
  -- This matters for multi-week events (for example Monte Carlo) whose target
  -- main-draw week differs from lower tournaments that overlap its first week.
  for g in
    with comps as (
      select wc.id,wc.world,e.season_number,
             min(sl.season_week)::smallint first_week,
             coalesce(
               min(sl.season_week) filter(where sl.phase='main_draw'),
               min(sl.season_week)
             )::smallint target_week,
             tc.sort_order::integer category_order
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      join public.tournament_series s on s.id=e.tournament_series_id
      join public.tournament_categories tc on tc.code=s.category_code
      join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
      where wc.status<>'canceled'
        and e.status<>'canceled'
        and not exists(
          select 1 from public.tournament_draw_publications d where d.competition_id=wc.id
        )
        and not exists(
          select 1 from public.tournament_matches m where m.competition_id=wc.id
        )
      group by wc.id,wc.world,e.season_number,tc.sort_order
    )
    select season_number,target_week,world,min(category_order)::integer strongest_category_order
    from comps
    where public.training_camp_week_start_absolute_v1(season_number,first_week)>v_today
      and public.training_camp_week_start_absolute_v1(season_number,first_week)<=v_today+21
      and v_now>=(public.get_tournament_entry_timeline_v1(id)->>'applications_open_game_second')::bigint
    group by season_number,target_week,world
    order by min(category_order),target_week,world
  loop
    loop
      res:=public.refresh_ai_tournament_applications_v2(
        g.season_number,g.target_week,g.world
      );
      v_apps:=v_apps+coalesce((res->>'applications_touched')::integer,0);
      v_wave_close:=nullif(res->>'wave_close_game_second','')::bigint;
      v_alloc_round:=0;

      if v_wave_close is not null and v_now>=v_wave_close then
        for r in
          with comps as (
            select wc.id,
                   coalesce(
                     min(sl.season_week) filter(where sl.phase='main_draw'),
                     min(sl.season_week)
                   )::smallint target_week,
                   tc.sort_order::integer category_order
            from public.tournament_world_competitions wc
            join public.tournament_editions e on e.id=wc.tournament_edition_id
            join public.tournament_series s on s.id=e.tournament_series_id
            join public.tournament_categories tc on tc.code=s.category_code
            join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
            where wc.world=g.world
              and e.season_number=g.season_number
              and wc.status<>'canceled'
              and e.status<>'canceled'
              and not exists(
                select 1 from public.tournament_draw_publications d where d.competition_id=wc.id
              )
              and not exists(
                select 1 from public.tournament_matches m where m.competition_id=wc.id
              )
            group by wc.id,tc.sort_order
          )
          select id
          from comps
          where target_week=g.target_week
            and not exists(
              select 1
              from public.tournament_competition_entry_cycles c
              where c.competition_id=id
                and c.normal_allocation_processed_at is not null
            )
            and (public.get_tournament_entry_timeline_v1(id)->>'normal_close_game_second')::bigint=v_wave_close
          order by category_order,id
        loop
          res:=public.allocate_tournament_applications_v3(r.id);
          if res->>'status'='processed' then
            v_alloc:=v_alloc+1;
            v_alloc_round:=v_alloc_round+1;
          end if;
        end loop;
      end if;

      exit when v_alloc_round=0;
    end loop;
  end loop;

  -- Late fills are also processed strongest category first, and the late-fill
  -- function now checks real overlapping tournament windows.
  for r in
    with comps as (
      select wc.id,e.season_number,min(sl.season_week)::smallint first_week,
             tc.sort_order::integer category_order
      from public.tournament_world_competitions wc
      join public.tournament_editions e on e.id=wc.tournament_edition_id
      join public.tournament_series s on s.id=e.tournament_series_id
      join public.tournament_categories tc on tc.code=s.category_code
      join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
      where wc.status<>'canceled'
        and e.status<>'canceled'
        and not exists(
          select 1 from public.tournament_draw_publications d where d.competition_id=wc.id
        )
        and not exists(
          select 1 from public.tournament_matches m where m.competition_id=wc.id
        )
      group by wc.id,e.season_number,tc.sort_order
    )
    select id
    from comps
    where public.training_camp_week_start_absolute_v1(season_number,first_week)>v_today
      and public.training_camp_week_start_absolute_v1(season_number,first_week)<=v_today+21
    order by category_order,id
  loop
    if v_now>=(public.get_tournament_entry_timeline_v1(r.id)->>'late_close_game_second')::bigint-300
       and not exists(
         select 1
         from public.tournament_competition_entry_cycles c
         where c.competition_id=r.id and c.ai_late_fill_processed_at is not null
       )
    then
      res:=public.fill_ai_late_tournament_vacancies_v1(r.id);
      if res->>'status'='processed' then v_fill:=v_fill+1; end if;
    end if;

    if v_now>=(public.get_tournament_entry_timeline_v1(r.id)->>'late_close_game_second')::bigint
       and not exists(
         select 1
         from public.tournament_competition_entry_cycles c
         where c.competition_id=r.id and c.field_locked_at is not null
       )
    then
      res:=public.lock_tournament_field_v1(r.id);
      if res->>'status'='locked' then v_lock:=v_lock+1; end if;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'ai_applications_touched',v_apps,
    'allocations_processed',v_alloc,
    'late_fills_processed',v_fill,
    'fields_locked',v_lock,
    'game_second',v_now
  );
end;
$function$;

create or replace function public.sync_completed_tournament_status_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_edition uuid;
begin
  if new.draw_type='main_draw'
     and lower(coalesce(new.round_label,''))='final'
     and new.status in ('completed','walkover','bye')
     and new.winner_id is not null
  then
    update public.tournament_world_competitions
    set status='completed'
    where id=new.competition_id
      and status<>'canceled';

    select tournament_edition_id
    into v_edition
    from public.tournament_world_competitions
    where id=new.competition_id;

    if v_edition is not null
       and not exists(
         select 1
         from public.tournament_world_competitions wc
         where wc.tournament_edition_id=v_edition
           and wc.status not in ('completed','canceled')
       )
    then
      update public.tournament_editions
      set status='completed'
      where id=v_edition
        and status<>'canceled';
    end if;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_sync_completed_tournament_status_v1
on public.tournament_matches;

create trigger trg_sync_completed_tournament_status_v1
after insert or update of status,winner_id
on public.tournament_matches
for each row
execute function public.sync_completed_tournament_status_v1();

revoke all on function public.sync_completed_tournament_status_v1() from public;
revoke all on function public.sync_completed_tournament_status_v1() from anon;
revoke all on function public.sync_completed_tournament_status_v1() from authenticated;

-- Repair historical competitions whose official main-draw final is already terminal.
update public.tournament_world_competitions wc
set status='completed'
where wc.status<>'canceled'
  and exists(
    select 1
    from public.tournament_matches m
    where m.competition_id=wc.id
      and m.draw_type='main_draw'
      and lower(m.round_label)='final'
      and m.status in ('completed','walkover','bye')
      and m.winner_id is not null
  );

update public.tournament_editions ed
set status='completed'
where ed.status<>'canceled'
  and exists(
    select 1
    from public.tournament_world_competitions wc
    where wc.tournament_edition_id=ed.id
  )
  and not exists(
    select 1
    from public.tournament_world_competitions wc
    where wc.tournament_edition_id=ed.id
      and wc.status not in ('completed','canceled')
  );

-- One-time repair for the current ATP Monte Carlo field before its draw exists.
do $repair$
declare
  v_monte uuid:='2886db15-be11-4b3c-896e-5afa5ed1fb4c'::uuid;
  v_result jsonb;
begin
  if not exists(select 1 from public.tournament_draw_publications where competition_id=v_monte)
     and not exists(select 1 from public.tournament_matches where competition_id=v_monte)
     and public.current_game_second_v1()
         < (public.get_tournament_entry_timeline_v1(v_monte)->'tournament_start'->>'game_second')::bigint
  then
    -- Release weaker, overlapping AI commitments for players who had chosen Monte Carlo.
    delete from public.tournament_entries te
    where te.player_id in (
      select a.player_id
      from public.tournament_applications a
      where a.competition_id=v_monte
        and a.application_source like 'ai%'
    )
      and te.competition_id<>v_monte
      and te.entry_status='active'
      and exists(
        select 1
        from public.tournament_applications a2
        where a2.competition_id=te.competition_id
          and a2.player_id=te.player_id
          and a2.application_source like 'ai%'
      )
      and not exists(
        select 1 from public.tournament_draw_publications dp
        where dp.competition_id=te.competition_id
      )
      and not exists(
        select 1 from public.tournament_matches tm
        where tm.competition_id=te.competition_id
      )
      and exists(
        select 1
        from public.tournament_world_competitions wc_other
        join public.tournament_editions ed_other on ed_other.id=wc_other.tournament_edition_id
        join public.tournament_series s_other on s_other.id=ed_other.tournament_series_id
        join public.tournament_categories c_other on c_other.code=s_other.category_code
        cross join lateral public.get_competition_window_v1(te.competition_id) w_other
        cross join lateral public.get_competition_window_v1(v_monte) w_monte
        where wc_other.id=te.competition_id
          and c_other.sort_order>(
            select c_target.sort_order
            from public.tournament_world_competitions wc_target
            join public.tournament_editions ed_target on ed_target.id=wc_target.tournament_edition_id
            join public.tournament_series s_target on s_target.id=ed_target.tournament_series_id
            join public.tournament_categories c_target on c_target.code=s_target.category_code
            where wc_target.id=v_monte
          )
          and w_other.start_absolute_day<=w_monte.end_absolute_day
          and w_other.end_absolute_day>=w_monte.start_absolute_day
      );

    update public.tournament_applications a
    set status='superseded',
        decision_reason='ai_moved_to_higher_category',
        decided_at=now(),
        updated_at=now()
    where a.application_source like 'ai%'
      and a.competition_id<>v_monte
      and a.player_id in (
        select ma.player_id
        from public.tournament_applications ma
        where ma.competition_id=v_monte
          and ma.application_source like 'ai%'
      )
      and a.status in ('applied','accepted_main_draw','accepted_qualification')
      and not exists(
        select 1
        from public.tournament_entries te
        where te.competition_id=a.competition_id
          and te.player_id=a.player_id
          and te.entry_status='active'
      );

    -- Rebuild the Monte Carlo AI field from the original AI candidate pool.
    delete from public.tournament_entries te
    using public.players p
    where te.competition_id=v_monte
      and p.id=te.player_id
      and p.player_type='ai';

    update public.tournament_applications
    set status='applied',
        decision_reason=null,
        decided_at=null,
        accept_qualification=true,
        updated_at=now()
    where competition_id=v_monte
      and application_source like 'ai%';

    insert into public.tournament_competition_entry_cycles(competition_id)
    values(v_monte)
    on conflict do nothing;

    update public.tournament_competition_entry_cycles
    set normal_allocation_processed_at=null,
        normal_allocation_game_second=null,
        ai_late_fill_processed_at=null,
        ai_late_fill_game_second=null,
        field_locked_at=null,
        field_locked_game_second=null,
        updated_at=now()
    where competition_id=v_monte;

    v_result:=public.allocate_tournament_applications_v3(v_monte);
  end if;
end;
$repair$;

-- Re-plan still-open ATP week 15 events with the corrected rank ceilings and hierarchy.
select public.refresh_ai_tournament_applications_v2(1,15,'ATP');
