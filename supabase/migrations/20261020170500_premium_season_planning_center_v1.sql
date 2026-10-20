-- Premium Season Planning Center (advisory only).
-- Does not book entries, spend coins, award ranking points or change game simulations.
create table if not exists public.player_premium_season_targets (
  player_id uuid not null references public.players(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  target_stage text not null check (target_stage in ('winner','runner_up','quarterfinal')),
  priority smallint not null default 2 check (priority between 1 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(player_id,competition_id)
);
create index if not exists ix_premium_season_targets_competition
  on public.player_premium_season_targets(competition_id);
alter table public.player_premium_season_targets enable row level security;
-- No direct Data API access. All reads and edits go through strongly gated RPCs.
revoke all on public.player_premium_season_targets from public, anon, authenticated;

create or replace function public.get_premium_season_planning_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path='public','pg_temp'
as $function$
declare
  v_player public.players%rowtype;
  v_season integer;
  v_today integer;
  v_competitions jsonb;
  v_total integer;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium membership required' using errcode='42501';
  end if;
  select * into v_player from public.players p
  where p.id=p_player_id and p.owner_user_id=auth.uid()
    and p.player_type='human' and p.moderation_status<>'rejected';
  if not found then
    raise exception 'Season planning belongs to your own career' using errcode='42501';
  end if;
  select g.season,public.game_day_absolute_v1(g.season,g.month,g.day)
  into v_season,v_today from public.get_current_game_day_internal_v1() g;
  with windows as (
    select w.id as competition_id, e.season_number,
      s.name as tournament_name,s.city,s.country_code,s.category_code,
      s.surface,s.environment,tc.label as category_label,
      tc.winner_points,s.id as series_id,
      min(sl.season_week)::integer start_week,
      max(sl.season_week)::integer end_week,
      w.status as competition_status
    from public.tournament_world_competitions w
    join public.tournament_editions e on e.id=w.tournament_edition_id
    join public.tournament_series s on s.id=e.tournament_series_id
    join public.tournament_categories tc on tc.code=s.category_code
    join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
    where w.world=v_player.world and e.season_number=v_season
      and w.status<>'canceled' and e.status<>'canceled'
    group by w.id,e.season_number,s.id,s.name,s.city,s.country_code,
      s.category_code,s.surface,s.environment,tc.label,tc.winner_points,w.status
  ), details as (
    select w.*,
      public.training_camp_week_start_absolute_v1(v_season,w.start_week::smallint) as start_day,
      pp.announced_pool_usd as pool_usd,
      (select r.points from public.tournament_ranking_point_rules r
       where r.category_code=w.category_code and r.stage_code='runner_up'
       limit 1) as finalist_points,
      (select r.points from public.tournament_ranking_point_rules r
       where r.category_code=w.category_code and r.stage_code='quarterfinal'
       limit 1) as quarterfinal_points,
      (select p.payout_per_player_usd from public.tournament_prize_payouts p
       where p.tournament_series_id=w.series_id and p.stage_code='winner'
       limit 1) as winner_prize_usd,
      (select p.payout_per_player_usd from public.tournament_prize_payouts p
       where p.tournament_series_id=w.series_id and p.stage_code='runner_up'
       limit 1) as finalist_prize_usd,
      (select p.payout_per_player_usd from public.tournament_prize_payouts p
       where p.tournament_series_id=w.series_id and p.stage_code='quarterfinal'
       limit 1) as quarterfinal_prize_usd,
      t.target_stage as planned_stage,t.priority as planned_priority,
      exists(select 1 from public.tournament_entries te where te.player_id=p_player_id
        and te.competition_id=w.competition_id and te.entry_status='active') as accepted_entry,
      exists(select 1 from public.tournament_applications ta where ta.player_id=p_player_id
        and ta.competition_id=w.competition_id and ta.status='applied') as pending_entry,
      exists(
        select 1 from public.tournament_entries te
        join public.tournament_world_competitions other_wc on other_wc.id=te.competition_id
        join public.tournament_editions other_e on other_e.id=other_wc.tournament_edition_id
        join public.tournament_schedule_slots other_sl on other_sl.tournament_edition_id=other_e.id
        where te.player_id=p_player_id and te.entry_status='active'
          and te.competition_id<>w.competition_id
          and other_e.season_number=v_season
          and other_sl.season_week between w.start_week and w.end_week
          and other_wc.status<>'canceled'
      ) as accepted_week_conflict,
      exists(
        select 1 from public.tournament_applications ta
        join public.tournament_world_competitions other_wc on other_wc.id=ta.competition_id
        join public.tournament_editions other_e on other_e.id=other_wc.tournament_edition_id
        join public.tournament_schedule_slots other_sl on other_sl.tournament_edition_id=other_e.id
        where ta.player_id=p_player_id and ta.status='applied'
          and ta.competition_id<>w.competition_id
          and other_e.season_number=v_season
          and other_sl.season_week between w.start_week and w.end_week
          and other_wc.status<>'canceled'
      ) as pending_week_conflict
    from windows w
    left join public.tournament_prize_pools pp on pp.tournament_series_id=w.series_id
    left join public.player_premium_season_targets t on t.player_id=p_player_id
      and t.competition_id=w.competition_id
  )
  select count(*)::integer,
    coalesce(jsonb_agg(jsonb_build_object(
      'competition_id',competition_id,'name',tournament_name,
      'city',city,'country_code',country_code,
      'category_code',category_code,'category_label',category_label,
      'surface',surface,'start_week',start_week,'end_week',end_week,
      'start_day',start_day,'status',competition_status,
      'winner_points',winner_points,'finalist_points',finalist_points,
      'quarterfinal_points',quarterfinal_points,
      'prize_pool_usd',pool_usd,'winner_prize_usd',winner_prize_usd,
      'finalist_prize_usd',finalist_prize_usd,
      'quarterfinal_prize_usd',quarterfinal_prize_usd,
      'planned_stage',planned_stage,'planned_priority',planned_priority,
      'accepted_entry',accepted_entry,'pending_entry',pending_entry,
      'accepted_week_conflict',accepted_week_conflict,
      'pending_week_conflict',pending_week_conflict
    ) order by start_week,winner_points desc,tournament_name),'[]'::jsonb)
  into v_total,v_competitions from details;
  return jsonb_build_object(
    'player_id',p_player_id,'world',v_player.world,'season',v_season,
    'today_absolute_day',v_today,'tournament_count',v_total,
    'limit',20,'tournaments',v_competitions,
    'methodology','Targets are private planning notes, NOT applications. Point and prize scenarios describe configured finishing-stage outcomes, not predictions, eligibility or net ranking changes. Planned overlaps, current entries and unresolved travel must be checked.'
  );
end;
$function$;

create or replace function public.save_premium_season_target_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_stage text default 'quarterfinal',
  p_priority integer default 2,
  p_remove boolean default false
) returns jsonb
language plpgsql volatile security definer
set search_path='public','pg_temp'
as $function$
declare
  v_world text;v_season integer;v_today integer;
  v_competition_season integer;v_competition_world text;v_category text;
  v_start_day integer;v_status text;v_existing boolean;
  v_current_count integer;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium membership required' using errcode='42501';
  end if;
  -- Locks the player row so concurrent requests cannot evade the 20-target cap.
  select p.world into v_world from public.players p
    where p.id=p_player_id and p.owner_user_id=auth.uid()
      and p.player_type='human' and p.moderation_status<>'rejected'
    for update;
  if not found then raise exception 'Not your player' using errcode='42501'; end if;
  select g.season,public.game_day_absolute_v1(g.season,g.month,g.day)
  into v_season,v_today from public.get_current_game_day_internal_v1() g;

  select e.season_number,w.world,s.category_code,w.status,
    min(public.training_camp_week_start_absolute_v1(e.season_number,sl.season_week))
  into v_competition_season,v_competition_world,v_category,v_status,v_start_day
  from public.tournament_world_competitions w
  join public.tournament_editions e on e.id=w.tournament_edition_id
  join public.tournament_series s on s.id=e.tournament_series_id
  join public.tournament_schedule_slots sl on sl.tournament_edition_id=e.id
  where w.id=p_competition_id and e.status<>'canceled'
  group by e.season_number,w.world,s.category_code,w.status;
  if v_competition_season is distinct from v_season
    or v_competition_world is distinct from v_world or v_status='canceled' then
    raise exception 'Invalid season or competition for this career';
  end if;

  if p_remove then
    delete from public.player_premium_season_targets
    where player_id=p_player_id and competition_id=p_competition_id;
    return jsonb_build_object('saved',true,'removed',true,'competition_id',p_competition_id);
  end if;
  if v_start_day<=v_today then
    raise exception 'Season targets can only be changed before the tournament begins';
  end if;
  if p_stage not in ('winner','runner_up','quarterfinal') or p_priority not between 1 and 3 then
    raise exception 'Invalid planning stage or priority';
  end if;
  if not exists(select 1 from public.tournament_ranking_point_rules r
    where r.category_code=v_category and r.stage_code=p_stage) then
    raise exception 'Finishing-stage points not configured for this event';
  end if;
  select exists(select 1 from public.player_premium_season_targets
    where player_id=p_player_id and competition_id=p_competition_id) into v_existing;
  select count(*)::integer into v_current_count
  from public.player_premium_season_targets t
  join public.tournament_world_competitions w on w.id=t.competition_id
  join public.tournament_editions e on e.id=w.tournament_edition_id
  where t.player_id=p_player_id and e.season_number=v_season;
  if not v_existing and v_current_count>=20 then
    raise exception 'Maximum 20 season planning targets';
  end if;
  insert into public.player_premium_season_targets(player_id,competition_id,target_stage,priority)
  values(p_player_id,p_competition_id,p_stage,p_priority)
  on conflict(player_id,competition_id) do update
    set target_stage=excluded.target_stage,
      priority=excluded.priority,updated_at=now();
  return jsonb_build_object('saved',true,'removed',false,
    'competition_id',p_competition_id,'target_stage',p_stage,'priority',p_priority);
end;
$function$;

revoke all on function public.get_premium_season_planning_v1(uuid) from public,anon,authenticated;
revoke all on function public.save_premium_season_target_v1(uuid,uuid,text,integer,boolean) from public,anon,authenticated;
grant execute on function public.get_premium_season_planning_v1(uuid) to authenticated;
grant execute on function public.save_premium_season_target_v1(uuid,uuid,text,integer,boolean) to authenticated;
