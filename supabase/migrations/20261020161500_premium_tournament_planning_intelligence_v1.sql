-- Premium Tournament Planning Intelligence v1
-- Read-only, owner- and Premium-gated comparisons based on the SAME official
-- tournament calendar as Free players. Never alters entry mechanics.
create or replace function public.get_premium_tournament_planning_v1(
  p_player_id uuid,
  p_season integer,
  p_month integer
) returns jsonb
language plpgsql stable security definer
set search_path = 'public','pg_temp'
as $fn$
declare
  v_player public.players%rowtype;
  v_rows jsonb;
  v_count integer;
  v_today record;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if not public.has_active_premium_v1() then
    raise exception 'Premium required' using errcode='42501';
  end if;
  select * into v_player
  from public.players p
  where p.id=p_player_id
    and p.owner_user_id=auth.uid()
    and p.player_type='human'
    and p.moderation_status<>'rejected';
  if not found then
    raise exception 'Tournament planning is restricted to your own career' using errcode='42501';
  end if;
  if p_month is null or p_month not between 1 and 12
     or p_season is null or p_season<1 then
    raise exception 'Invalid in-game season/month';
  end if;
  select * into v_today from public.get_current_game_day_internal_v1();
  if p_season<>v_today.season then
    raise exception 'Only the current in-game season is supported';
  end if;

  with calendar as (
    -- One row per competition, not one row per qualification/main draw slot.
    select distinct on (c.competition_id) c.*
    from public.get_tournament_calendar_v2(p_season,p_month,v_player.world) c
    order by c.competition_id,
      case c.phase when 'full' then 0 when 'main_draw' then 1 else 2 end,
      c.season_week
  ),
  calendar_windows as (
    select c.*,ed.tournament_series_id,
      (select min(sl.season_week) from public.tournament_schedule_slots sl
       where sl.tournament_edition_id=c.edition_id)::integer as first_week,
      (select max(sl.season_week) from public.tournament_schedule_slots sl
       where sl.tournament_edition_id=c.edition_id)::integer as last_week
    from calendar c
    join public.tournament_editions ed on ed.id=c.edition_id
  ),
  enriched as (
    select c.*,
      pp.announced_pool_usd as prize_pool_usd,
      (select payout_per_player_usd from public.tournament_prize_payouts p
       where p.tournament_series_id=c.tournament_series_id and p.stage_code='winner'
       order by p.sort_order limit 1) as winner_prize_usd,
      (select payout_per_player_usd from public.tournament_prize_payouts p
       where p.tournament_series_id=c.tournament_series_id and p.stage_code='runner_up'
       order by p.sort_order limit 1) as finalist_prize_usd,
      (select rp.points from public.tournament_ranking_point_rules rp
       where rp.category_code=c.category_code and rp.stage_code='runner_up'
       order by rp.sort_order limit 1) as finalist_points,
      public.player_tournament_blocked_by_health_v1(p_player_id,c.tournament_start_day::integer)
        as health_blocked,
      exists (
        select 1
        from public.tournament_entries te
        join public.tournament_world_competitions other_wc on other_wc.id=te.competition_id
        join public.tournament_editions other_ed on other_ed.id=other_wc.tournament_edition_id
        join public.tournament_schedule_slots other_sl on other_sl.tournament_edition_id=other_ed.id
        where te.player_id=p_player_id and te.competition_id<>c.competition_id
          and te.entry_status='active'
          and other_wc.status not in ('canceled','completed')
          and other_ed.status<>'canceled'
          and other_ed.season_number=p_season
          and other_sl.season_week between c.first_week and c.last_week
      ) as accepted_overlap,
      exists (
        select 1
        from public.tournament_applications ta
        join public.tournament_world_competitions other_wc on other_wc.id=ta.competition_id
        join public.tournament_editions other_ed on other_ed.id=other_wc.tournament_edition_id
        join public.tournament_schedule_slots other_sl on other_sl.tournament_edition_id=other_ed.id
        where ta.player_id=p_player_id and ta.competition_id<>c.competition_id
          and ta.status='applied'
          and other_wc.status not in ('canceled','completed')
          and other_ed.status<>'canceled'
          and other_ed.season_number=p_season
          and other_sl.season_week between c.first_week and c.last_week
      ) as pending_overlap,
      (select count(distinct peers.competition_id) from calendar_windows peers
       where peers.competition_id<>c.competition_id
         and peers.first_week<=c.last_week and peers.last_week>=c.first_week)
        as other_calendar_choices
    from calendar_windows c
    left join public.tournament_prize_pools pp on pp.tournament_series_id=c.tournament_series_id
  ),
  named as (
    select e.*,
      case
        when e.tournament_status='canceled' then 'canceled'
        when e.user_status in ('accepted_main_draw','accepted_qualification','competing') then 'entered'
        when e.health_blocked then 'health_review'
        when e.accepted_overlap then 'accepted_conflict'
        when e.pending_overlap then 'pending_conflict'
        when e.user_status='pending' then 'pending'
        when e.applications_open then 'application_window_open'
        else 'verify_entry'
      end as planning_advisory
    from enriched e
  ),
  limited as (
    select * from named
    order by first_week asc,winner_points desc,prize_pool_usd desc nulls last,tournament_name
    limit 90
  )
  select count(*),coalesce(jsonb_agg(jsonb_build_object(
    'competition_id',competition_id,
    'tournament_name',tournament_name,
    'season_week_start',first_week,'season_week_end',last_week,
    'city',city,'country_code',country_code,
    'category_code',category_code,'category_label',category_label,
    'surface',surface,'environment',environment,
    'winner_points',winner_points,'finalist_points',finalist_points,
    'prize_pool_usd',prize_pool_usd,
    'winner_prize_usd',winner_prize_usd,'finalist_prize_usd',finalist_prize_usd,
    'main_draw_capacity',main_draw_capacity,'qualifying_capacity_max',qualifying_capacity_max,
    'tournament_status',tournament_status,'user_status',user_status,
    'applications_open',applications_open,
    'health_blocked',health_blocked,
    'accepted_overlap',accepted_overlap,'pending_overlap',pending_overlap,
    'other_calendar_choices',other_calendar_choices,
    'planning_advisory',planning_advisory
  ) order by first_week asc,winner_points desc,prize_pool_usd desc nulls last,tournament_name),'[]'::jsonb)
  into v_count,v_rows from limited;
  return jsonb_build_object(
    'player_id',p_player_id,'world',v_player.world,
    'season',p_season,'month',p_month,
    'tournament_count',v_count,'tournaments',v_rows,
    'currency','USD',
    'methodology','Winner/finalist points and prize values are official configured outcomes, not expected winnings. Eligibility is advisory: the official entry process performs final checks. Calendar clashes are inferred from current active singles entries and pending singles applications; travel, doubles and uncertain draws must be reviewed separately.'
  );
end
$fn$;

revoke all on function public.get_premium_tournament_planning_v1(uuid,integer,integer)
from public,anon,authenticated;
grant execute on function public.get_premium_tournament_planning_v1(uuid,integer,integer)
to authenticated;
comment on function public.get_premium_tournament_planning_v1(uuid,integer,integer)
is 'Premium, owned-career, read-only month-level singles tournament comparisons. No application or ranking actions.';
