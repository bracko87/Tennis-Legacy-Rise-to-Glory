create table if not exists public.player_ranking_contributions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  source_result_id uuid not null unique references public.player_tournament_results(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  tournament_series_id uuid not null references public.tournament_series(id) on delete restrict,
  world text not null check (world in ('ATP','WTA')),
  season_number integer not null check (season_number >= 1),
  ranking_points integer not null check (ranking_points >= 0),
  awarded_absolute_day integer not null,
  published_at timestamptz,
  is_active boolean not null default true,
  deactivated_absolute_day integer,
  deactivated_at timestamptz,
  replaced_by_result_id uuid references public.player_tournament_results(id) on delete set null,
  replaced_by_competition_id uuid references public.tournament_world_competitions(id) on delete set null,
  replacement_reason text check (replacement_reason is null or replacement_reason in (
    'next_edition_result','next_edition_no_result','next_edition_cancelled','series_removed_anniversary','superseded_safety'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists player_ranking_contributions_active_player_idx
  on public.player_ranking_contributions(player_id, is_active);
create index if not exists player_ranking_contributions_series_season_idx
  on public.player_ranking_contributions(tournament_series_id, world, season_number);
create index if not exists player_ranking_contributions_competition_idx
  on public.player_ranking_contributions(competition_id);

alter table public.player_ranking_contributions enable row level security;
revoke all on public.player_ranking_contributions from anon, authenticated;
grant select, insert, update, delete on public.player_ranking_contributions to service_role;

create table if not exists public.ranking_defence_cycles (
  competition_id uuid primary key references public.tournament_world_competitions(id) on delete cascade,
  tournament_series_id uuid not null references public.tournament_series(id) on delete restrict,
  world text not null check (world in ('ATP','WTA')),
  season_number integer not null check (season_number >= 1),
  previous_season_number integer,
  scheduled_publish_absolute_day integer not null,
  processed_absolute_day integer not null,
  processing_reason text not null check (processing_reason in ('edition_completed','edition_cancelled','historical_backfill')),
  published_results integer not null default 0,
  expired_contributions integer not null default 0,
  activated_contributions integer not null default 0,
  processed_at timestamptz not null default now()
);

create index if not exists ranking_defence_cycles_series_idx
  on public.ranking_defence_cycles(tournament_series_id, world, season_number);

alter table public.ranking_defence_cycles enable row level security;
revoke all on public.ranking_defence_cycles from anon, authenticated;
grant select, insert, update, delete on public.ranking_defence_cycles to service_role;

alter table public.ranking_publication_runs
  add column if not exists defence_cycles_processed integer not null default 0,
  add column if not exists contributions_expired integer not null default 0,
  add column if not exists contributions_activated integer not null default 0,
  add column if not exists orphan_contributions_expired integer not null default 0;

insert into public.player_ranking_contributions(
  player_id, source_result_id, competition_id, tournament_series_id, world,
  season_number, ranking_points, awarded_absolute_day, published_at, is_active
)
select
  r.player_id,
  r.id,
  r.competition_id,
  e.tournament_series_id,
  wc.world,
  e.season_number,
  greatest(coalesce(r.ranking_points_earned,0),0),
  r.ranking_publish_absolute_day,
  r.ranking_published_at,
  true
from public.player_tournament_results r
join public.tournament_world_competitions wc on wc.id=r.competition_id
join public.tournament_editions e on e.id=wc.tournament_edition_id
where r.ranking_publish_status='published'
  and r.ranking_publish_absolute_day is not null
on conflict(source_result_id) do nothing;

with current_game as (
  select public.game_day_absolute_v1(d.season,d.month,d.day) as game_absolute_day
  from public.get_current_game_day_internal_v1() d
), cycle_days as (
  select
    wc.id competition_id,
    e.tournament_series_id,
    wc.world,
    e.season_number,
    public.training_camp_week_start_absolute_v1(e.season_number,max(ss.season_week)::smallint)+7 as publish_day
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=e.id
  group by wc.id,e.tournament_series_id,wc.world,e.season_number
)
insert into public.ranking_defence_cycles(
  competition_id,tournament_series_id,world,season_number,previous_season_number,
  scheduled_publish_absolute_day,processed_absolute_day,processing_reason,
  published_results,expired_contributions,activated_contributions,processed_at
)
select
  cd.competition_id,
  cd.tournament_series_id,
  cd.world,
  cd.season_number,
  case when cd.season_number>1 then cd.season_number-1 else null end,
  cd.publish_day,
  cd.publish_day,
  'historical_backfill',
  (select count(*)::integer from public.player_tournament_results r where r.competition_id=cd.competition_id and r.ranking_publish_status='published'),
  0,
  (select count(*)::integer from public.player_ranking_contributions c where c.competition_id=cd.competition_id),
  now()
from cycle_days cd
cross join current_game cg
where cd.publish_day<=cg.game_absolute_day
  and (
    exists(select 1 from public.player_tournament_results r where r.competition_id=cd.competition_id and r.ranking_publish_status='published')
    or exists(select 1 from public.tournament_cancellations tc where tc.competition_id=cd.competition_id)
  )
on conflict(competition_id) do nothing;

create or replace function public.process_weekly_rankings_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  d record;
  v_abs integer;
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
  if mod(v_abs-2,7)<>0 then
    return jsonb_build_object('status','not_monday','game_absolute_day',v_abs);
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
    'new_results_published',v_new_results,
    'defence_cycles_processed',v_cycle_count,
    'contributions_expired',v_expired,
    'contributions_activated',v_activated,
    'orphan_contributions_expired',v_orphan_expired
  );
end;
$function$;

create or replace function public.get_tournament_defending_points_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
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
  )
  select jsonb_build_object(
    'player_id',v_player_id,
    'previous_season',case when v_season>1 then v_season-1 else null end,
    'previous_competition_id',v_previous_competition,
    'previous_result_code',(select result_code from prev),
    'previous_result_label',case when (select result_code from prev) is null then null else public.tournament_result_label_v1((select result_code from prev)) end,
    'previous_points',coalesce((select ranking_points_earned from prev),0),
    'points_defending',coalesce((select c.ranking_points from public.player_ranking_contributions c where c.player_id=v_player_id and c.tournament_series_id=v_series and c.world=v_world and c.season_number=v_season-1 and c.is_active limit 1),0),
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
    'points_defending',coalesce(pc.ranking_points,0)
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

revoke all on function public.get_tournament_defending_points_v1(uuid) from public, anon;
grant execute on function public.get_tournament_defending_points_v1(uuid) to authenticated, service_role;