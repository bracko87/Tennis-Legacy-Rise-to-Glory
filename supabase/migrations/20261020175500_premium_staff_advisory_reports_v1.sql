-- Premium Staff Advisory Reports v1. Analysis only; never changes staff contracts,
-- salaries, personnel effectiveness, training gains or finances.
create or replace function public.get_premium_staff_advisory_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path='public','pg_temp'
as $fn$
declare
  v_player public.players%rowtype;
  v_today integer;
  v_staff jsonb;
  v_count integer;
  v_weekly bigint;
  v_remaining bigint;
  v_posted_total bigint;
  v_posted_28 bigint;
  v_expiring integer;
  v_earliest integer;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium staff report requires membership'
      using errcode='42501';
  end if;
  select * into v_player
  from public.players p
  where p.id=p_player_id and p.owner_user_id=auth.uid()
    and p.player_type='human' and p.moderation_status<>'rejected';
  if not found then
    raise exception 'Staff report belongs to your own career'
      using errcode='42501';
  end if;

  select public.game_day_absolute_v1(g.season,g.month,g.day)
    into v_today from public.get_current_game_day_internal_v1() g;

  with employed as (
    select
      c.id as contract_id,
      c.staff_id,
      c.role,
      s.first_name,s.last_name,s.overall_rating,s.quality_tier,
      c.start_absolute_day,c.end_absolute_day,c.weekly_salary,
      c.signing_fee,c.duration_weeks,c.finance_status,
      greatest(0,c.end_absolute_day-v_today+1)::integer as days_remaining,
      greatest(0,ceil((c.end_absolute_day-v_today+1)::numeric/7))::integer
        as weeks_remaining,
      -- Paid events are actual ledger entries, not calculated salaries.
      coalesce((select sum(f.amount)
        from public.staff_financial_events f
        where f.player_id=p_player_id and f.contract_id=c.id
          and f.status='posted'),0)::bigint as posted_cost_all_time,
      coalesce((select sum(f.amount)
        from public.staff_financial_events f
        where f.player_id=p_player_id and f.contract_id=c.id
          and f.status='posted' and f.game_absolute_day between v_today-27 and v_today),0)::bigint
        as posted_cost_last_28_game_days
    from public.player_staff_contracts c
    join public.staff_members s on s.id=c.staff_id
    where c.player_id=p_player_id and c.status='active'
  ),
  detailed as (
    select e.*,
      (e.weeks_remaining::bigint*e.weekly_salary) as estimated_remaining_salaries,
      round(e.overall_rating::numeric/nullif(e.weekly_salary,0)*1000,2) as rating_per_1000_weekly_usd,
      public.get_staff_role_effect_summary_v1(p_player_id,e.role) as current_role_effects
    from employed e
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'contract_id',contract_id,'staff_id',staff_id,'role',role,
      'name',first_name||' '||last_name,'rating',overall_rating,
      'quality_tier',quality_tier,
      'start_absolute_day',start_absolute_day,
      'end_absolute_day',end_absolute_day,
      'days_remaining',days_remaining,'weeks_remaining',weeks_remaining,
      'weekly_salary',weekly_salary,'duration_weeks',duration_weeks,
      'finance_status',finance_status,
      'posted_cost_all_time',posted_cost_all_time,
      'posted_cost_last_28_game_days',posted_cost_last_28_game_days,
      'estimated_remaining_salaries',estimated_remaining_salaries,
      'rating_per_1000_weekly_usd',rating_per_1000_weekly_usd,
      'current_role_effects',current_role_effects
    ) order by weekly_salary desc,role),'[]'::jsonb),
    count(*)::integer,
    coalesce(sum(weekly_salary),0)::bigint,
    coalesce(sum(estimated_remaining_salaries),0)::bigint,
    coalesce(sum(posted_cost_all_time),0)::bigint,
    coalesce(sum(posted_cost_last_28_game_days),0)::bigint,
    count(*) filter(where days_remaining between 0 and 28)::integer,
    min(days_remaining)
  into v_staff,v_count,v_weekly,v_remaining,v_posted_total,v_posted_28,
    v_expiring,v_earliest
  from detailed;

  return jsonb_build_object(
    'player_id',p_player_id,
    'absolute_game_day',v_today,
    'staff_count',v_count,
    'staff',v_staff,
    'weekly_salary_run_rate_usd',v_weekly,
    'four_week_salary_run_rate_usd',v_weekly*4,
    'thirteen_week_salary_run_rate_usd',v_weekly*13,
    'remaining_salary_commitments_estimate_usd',v_remaining,
    'active_contract_posted_cost_total_usd',v_posted_total,
    'active_contract_posted_cost_last_28_game_days_usd',v_posted_28,
    'expiring_within_28_game_days',v_expiring,
    'earliest_expiry_days',v_earliest,
    'currency','USD',
    'methodology','Run-rate assumes unchanged weekly wages, before expiries or renewals. Remaining salary commitment is estimated using whole weeks, not a bill or a termination quote. Posted staff ledger amounts are historical, active contracts only; no attribution of player skill improvement to individual employees. Rating per 1000 USD/week is a descriptive ratio, not game-engine impact or staff ROI. Bonuses shown are currently configured effects, not separately verified past outcomes.'
  );
end
$fn$;
revoke all on function public.get_premium_staff_advisory_v1(uuid)
  from public,anon,authenticated;
grant execute on function public.get_premium_staff_advisory_v1(uuid)
  to authenticated;
comment on function public.get_premium_staff_advisory_v1(uuid) is
  'Premium owner-only read-only staffing cost, expiry and configured effects advisory. No game or financial changes.';
