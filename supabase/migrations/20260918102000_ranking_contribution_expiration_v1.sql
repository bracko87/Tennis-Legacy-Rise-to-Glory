alter table public.player_ranking_contributions
  add column if not exists expires_absolute_day integer;

update public.player_ranking_contributions
set expires_absolute_day = awarded_absolute_day + 366
where expires_absolute_day is null;

alter table public.player_ranking_contributions
  alter column expires_absolute_day set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'player_ranking_contributions_expiry_after_award_chk'
      and conrelid = 'public.player_ranking_contributions'::regclass
  ) then
    alter table public.player_ranking_contributions
      add constraint player_ranking_contributions_expiry_after_award_chk
      check (expires_absolute_day > awarded_absolute_day);
  end if;
end $$;

create index if not exists player_ranking_contributions_active_expiry_idx
  on public.player_ranking_contributions(expires_absolute_day, player_id)
  where is_active;

comment on column public.player_ranking_contributions.expires_absolute_day is
  'Scheduled hard expiration of this ranking contribution. Normally one game season (366 game days) after its award. A matching next edition may replace it earlier; otherwise it expires automatically here.';

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
      season_number,ranking_points,awarded_absolute_day,expires_absolute_day,published_at,is_active
    )
    select
      r.player_id,r.id,r.competition_id,v_cycle.tournament_series_id,v_cycle.world,
      v_cycle.season_number,greatest(coalesce(r.ranking_points_earned,0),0),
      coalesce(r.ranking_publish_absolute_day,v_abs),
      coalesce(r.ranking_publish_absolute_day,v_abs)+366,
      coalesce(r.ranking_published_at,now()),true
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
      replacement_reason=coalesce(c.replacement_reason,'scheduled_expiration'),
      updated_at=now()
  where c.is_active
    and c.expires_absolute_day<=v_abs;
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
    'scheduled_contributions_expired',v_orphan_expired
  );
end;
$function$;

create or replace function public.get_player_ranking_expirations_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player_id uuid;
  v_world text;
  v_abs integer;
  d record;
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select p.id,p.world into v_player_id,v_world
  from public.players p
  where p.owner_user_id=v_uid and p.player_type='human'
  order by p.created_at desc
  limit 1;

  if v_player_id is null then raise exception 'Player unavailable.'; end if;

  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);

  select coalesce(jsonb_agg(jsonb_build_object(
    'contribution_id',c.id,
    'competition_id',c.competition_id,
    'tournament_series_id',c.tournament_series_id,
    'tournament_name',ts.name,
    'source_result_code',r.result_code,
    'source_result_label',public.tournament_result_label_v1(r.result_code),
    'ranking_points',c.ranking_points,
    'awarded_absolute_day',c.awarded_absolute_day,
    'expires_absolute_day',c.expires_absolute_day,
    'expiration_season',gd.season,
    'expiration_week',gd.season_week,
    'expiration_month',gd.month,
    'expiration_day',gd.day,
    'days_remaining',greatest(c.expires_absolute_day-v_abs,0),
    'next_edition_scheduled',exists(
      select 1
      from public.tournament_editions e2
      join public.tournament_world_competitions wc2
        on wc2.tournament_edition_id=e2.id
       and wc2.world=c.world
      where e2.tournament_series_id=c.tournament_series_id
        and e2.season_number=c.season_number+1
        and exists(select 1 from public.tournament_schedule_slots ss2 where ss2.tournament_edition_id=e2.id)
    )
  ) order by c.expires_absolute_day,c.ranking_points desc),'[]'::jsonb)
  into v_rows
  from public.player_ranking_contributions c
  join public.tournament_series ts on ts.id=c.tournament_series_id
  join public.player_tournament_results r on r.id=c.source_result_id
  cross join lateral public.absolute_game_day_v1(c.expires_absolute_day) gd
  where c.player_id=v_player_id
    and c.world=v_world
    and c.is_active;

  return jsonb_build_object(
    'player_id',v_player_id,
    'world',v_world,
    'game_absolute_day',v_abs,
    'contributions',v_rows
  );
end;
$function$;

revoke all on function public.get_player_ranking_expirations_v1() from public;
revoke all on function public.get_player_ranking_expirations_v1() from anon;
grant execute on function public.get_player_ranking_expirations_v1() to authenticated;

create or replace function public.get_tournament_defending_points_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player_id uuid;
  v_player_world text;
  v_world text;
  v_series uuid;
  v_season integer;
  v_previous_competition uuid;
  v_cycle_day integer;
  v_cycle_processed boolean:=false;
  v_own jsonb;
  v_participants jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select p.id,p.world into v_player_id,v_player_world
  from public.players p
  where p.owner_user_id=v_uid and p.player_type='human'
  order by p.created_at desc
  limit 1;

  select wc.world,e.tournament_series_id,e.season_number,
         public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7
  into v_world,v_series,v_season,v_cycle_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
  where wc.id=p_competition_id
  group by wc.world,e.tournament_series_id,e.season_number;

  if v_series is null or v_world is distinct from v_player_world then raise exception 'Tournament unavailable.'; end if;

  if v_season>1 then
    select wc.id into v_previous_competition
    from public.tournament_editions e
    join public.tournament_world_competitions wc on wc.tournament_edition_id=e.id and wc.world=v_world
    where e.tournament_series_id=v_series and e.season_number=v_season-1
    limit 1;
  end if;

  select exists(select 1 from public.ranking_defence_cycles dc where dc.competition_id=p_competition_id)
  into v_cycle_processed;

  with ranked as (
    select p.id,
           row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer as rank_position,
           coalesce(pr.ranking_points,0)::integer as ranking_points
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world and p.moderation_status<>'rejected'
  ), prev as (
    select r.id,r.result_code,r.ranking_points_earned
    from public.player_tournament_results r
    where r.player_id=v_player_id and r.competition_id=v_previous_competition
    limit 1
  ), cur as (
    select r.id,r.result_code,r.ranking_points_earned,r.ranking_publish_status
    from public.player_tournament_results r
    where r.player_id=v_player_id and r.competition_id=p_competition_id
    limit 1
  ), pc as (
    select c.ranking_points,c.expires_absolute_day
    from public.player_ranking_contributions c
    where c.player_id=v_player_id
      and c.tournament_series_id=v_series
      and c.world=v_world
      and c.season_number=v_season-1
      and c.is_active
    limit 1
  ), exp as (
    select gd.*
    from pc
    cross join lateral public.absolute_game_day_v1(pc.expires_absolute_day) gd
  )
  select jsonb_build_object(
    'player_id',v_player_id,
    'previous_season',case when v_season>1 then v_season-1 else null end,
    'previous_competition_id',v_previous_competition,
    'previous_result_code',(select result_code from prev),
    'previous_result_label',case when (select result_code from prev) is null then null else public.tournament_result_label_v1((select result_code from prev)) end,
    'previous_points',coalesce((select ranking_points_earned from prev),0),
    'points_defending',coalesce((select ranking_points from pc),0),
    'points_expire_absolute_day',(select expires_absolute_day from pc),
    'points_expire_season',(select season from exp),
    'points_expire_week',(select season_week from exp),
    'points_expire_month',(select month from exp),
    'points_expire_day',(select day from exp),
    'current_result_code',(select result_code from cur),
    'current_result_label',case when (select result_code from cur) is null then null else public.tournament_result_label_v1((select result_code from cur)) end,
    'current_result_points',coalesce((select ranking_points_earned from cur),0),
    'current_result_publish_status',(select ranking_publish_status from cur),
    'current_ranking_position',(select rank_position from ranked where id=v_player_id),
    'current_ranking_points',(select ranking_points from ranked where id=v_player_id)
  ) into v_own;

  with ranked as (
    select p.id,
           row_number() over(order by coalesce(pr.ranking_points,0) desc,coalesce(pr.seed_rating,0) desc,p.created_at,p.id)::integer as rank_position,
           coalesce(pr.ranking_points,0)::integer as ranking_points
    from public.players p
    left join public.player_rankings pr on pr.player_id=p.id
    where p.world=v_world and p.moderation_status<>'rejected'
  ), field as (
    select distinct te.player_id
    from public.tournament_entries te
    where te.competition_id=p_competition_id
      and te.entry_status in ('active','eliminated','champion')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'player_id',p.id,
    'first_name',p.first_name,
    'last_name',p.last_name,
    'country_code',p.country_code,
    'is_ai',p.player_type='ai',
    'current_ranking_position',rk.rank_position,
    'current_ranking_points',rk.ranking_points,
    'previous_result_code',pr.result_code,
    'previous_result_label',case when pr.result_code is null then null else public.tournament_result_label_v1(pr.result_code) end,
    'previous_points',coalesce(pr.ranking_points_earned,0),
    'points_defending',coalesce(pc.ranking_points,0),
    'points_expire_absolute_day',pc.expires_absolute_day
  ) order by coalesce(pc.ranking_points,0) desc,rk.rank_position nulls last,p.last_name,p.first_name),'[]'::jsonb)
  into v_participants
  from field f
  join public.players p on p.id=f.player_id
  left join ranked rk on rk.id=p.id
  left join public.player_tournament_results pr on pr.player_id=p.id and pr.competition_id=v_previous_competition
  left join public.player_ranking_contributions pc on pc.player_id=p.id and pc.tournament_series_id=v_series and pc.world=v_world and pc.season_number=v_season-1 and pc.is_active;

  return jsonb_build_object(
    'competition_id',p_competition_id,
    'tournament_series_id',v_series,
    'world',v_world,
    'season_number',v_season,
    'previous_season_number',case when v_season>1 then v_season-1 else null end,
    'previous_competition_id',v_previous_competition,
    'ranking_cycle_absolute_day',v_cycle_day,
    'cycle_processed',v_cycle_processed,
    'own',v_own,
    'participants',v_participants
  );
end;
$function$;
