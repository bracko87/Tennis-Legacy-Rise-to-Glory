-- Premium Financial Intelligence v1: read-only 13-week planning data.
-- Nothing here posts money, processes a finance event or alters game mechanics.
create or replace function public.get_premium_financial_intelligence_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path='public','pg_temp'
as $func$
declare
  v_player public.players%rowtype;
  v_today integer;
  v_season integer;
  v_balance bigint;
  v_currency text;
  v_history jsonb;
  v_future jsonb;
  v_historical_income bigint;
  v_historical_expense bigint;
  v_planned_income bigint;
  v_staff_cost bigint;
  v_travel_cost bigint;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium membership required' using errcode='42501';
  end if;
  select * into v_player from public.players p
  where p.id=p_player_id and p.owner_user_id=auth.uid()
    and p.player_type='human' and p.moderation_status<>'rejected';
  if not found then raise exception 'Financial report restricted to your own career'
    using errcode='42501'; end if;

  select g.season, public.game_day_absolute_v1(g.season,g.month,g.day)
    into v_season,v_today from public.get_current_game_day_internal_v1() g;
  select a.balance,a.currency into v_balance,v_currency
  from public.player_career_finance_accounts a
  where a.player_id=p_player_id;
  if v_balance is null then
    raise exception 'No initialized player finance account';
  end if;

  with history as (
    select week_number,
      (v_today-(13-week_number)*7-6) as from_day,
      (v_today-(13-week_number)*7) as through_day
    from generate_series(1,13) week_number
  ), sums as (
    select h.*,
      coalesce(sum(x.amount) filter(where x.amount>0
        and x.subcategory<>'opening_balance'),0)::bigint as income,
      coalesce(-sum(x.amount) filter(where x.amount<0),0)::bigint as expenses
    from history h
    left join public.career_finance_transactions x
      on x.player_id=p_player_id and x.game_absolute_day between h.from_day and h.through_day
    group by h.week_number,h.from_day,h.through_day
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'week',week_number,'from_day',from_day,'through_day',through_day,
      'income',income,'expenses',expenses,'net',income-expenses)
    order by week_number),'[]'::jsonb),
    coalesce(sum(income),0)::bigint,coalesce(sum(expenses),0)::bigint
  into v_history,v_historical_income,v_historical_expense from sums;

  with slots as (
    select n::integer as week_number,v_today+(n-1)*7 as after_day,
       v_today+n*7 as through_day from generate_series(1,13) n
  ),
  staff as (
    select c.weekly_salary::bigint amount,
      c.start_absolute_day+6 as first_due,c.end_absolute_day as last_due
    from public.player_staff_contracts c
    where c.player_id=p_player_id and c.status='active'
      and c.end_absolute_day>v_today
  ),
  sponsors as (
    select c.weekly_payment_amount::bigint amount,
      c.first_payment_absolute_day first_due,
      least(c.end_absolute_day,
        c.first_payment_absolute_day+greatest(0,c.scheduled_payment_count::integer-1)*7) last_due
    from public.player_sponsor_contracts c
    where c.player_id=p_player_id and c.status='active'
      and c.season=v_season and c.end_absolute_day>v_today
  ),
  weekly as (
    select s.week_number,s.after_day,s.through_day,
      coalesce((select sum(a.amount) from staff a,
        lateral generate_series(a.first_due,a.last_due,7) due(day)
        where due.day>s.after_day and due.day<=s.through_day),0)::bigint as staff_usd,
      coalesce((select sum(a.amount) from sponsors a,
        lateral generate_series(a.first_due,a.last_due,7) due(day)
        where due.day>s.after_day and due.day<=s.through_day),0)::bigint as sponsor_usd,
      coalesce((select sum(greatest(0,t.estimated_cost)) from public.player_travel_legs t
        where t.player_id=p_player_id and t.status='planned'
          and t.departure_absolute_day>s.after_day
          and t.departure_absolute_day<=s.through_day),0)::bigint as travel_usd
    from slots s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'week',week_number,'from_day',after_day+1,'through_day',through_day,
    'scheduled_sponsor_income',sponsor_usd,
    'contracted_staff_cost',staff_usd,'planned_travel_cost',travel_usd,
    'known_net',sponsor_usd-staff_usd-travel_usd)
    order by week_number),'[]'::jsonb),
    coalesce(sum(sponsor_usd),0)::bigint,
    coalesce(sum(staff_usd),0)::bigint,
    coalesce(sum(travel_usd),0)::bigint
  into v_future,v_planned_income,v_staff_cost,v_travel_cost from weekly;

  return jsonb_build_object(
    'player_id',p_player_id,'season',v_season,
    'current_absolute_day',v_today,'currency',coalesce(v_currency,'USD'),
    'opening_cash',v_balance,
    'historic_13_week_income',v_historical_income,
    'historic_13_week_expenses',v_historical_expense,
    'historic_weeks',v_history,
    'future_weeks',v_future,
    'scheduled_13_week_sponsor_income',v_planned_income,
    'contracted_13_week_staff_cost',v_staff_cost,
    'planned_13_week_travel_cost',v_travel_cost,
    'methodology','Historical 13-week sums exclude opening balance. Forward outlook begins after the current game day and includes only currently active staff payroll schedules, active main-sponsor contractual installments and estimated planned travel departures. It does not automatically include prize money, conditional sponsor bonuses, taxes not yet settled, hotel expenses, private-life costs, new staff, training purchases, travel changes or season-renewal income. Figures are advisory; no cash changes, winning probabilities or payment guarantees. User-input hypothetical cash flows are not official transactions.'
  );
end
$func$;
revoke all on function public.get_premium_financial_intelligence_v1(uuid)
  from public,anon,authenticated;
grant execute on function public.get_premium_financial_intelligence_v1(uuid) to authenticated;
comment on function public.get_premium_financial_intelligence_v1(uuid)
  is 'Premium owner-only read-only 13-week observed and scheduled financial outlook.';
