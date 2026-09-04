create or replace function public.get_career_finance_analytics_v1(p_granularity text default 'monthly')
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_uid uuid:=auth.uid(); v_player uuid; gd record; v_abs integer; v_start integer; v_series jsonb; v_income_cats jsonb; v_expense_cats jsonb; v_g text:=lower(coalesce(p_granularity,'monthly'));
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human'; if v_player is null then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  if v_g not in ('daily','weekly','monthly','season') then raise exception 'Invalid finance analytics granularity.'; end if;
  v_start:=case v_g
    when 'daily' then greatest(0,v_abs-13)
    when 'weekly' then greatest(0,v_abs-83)
    when 'monthly' then greatest(0,v_abs-365)
    else public.game_day_absolute_v1(greatest(1,gd.season-4)::integer,1::smallint,1::smallint)
  end;

  with tx as (
    select t.*,a.season as gd_season,a.month as gd_month,a.day as gd_day,a.season_week
    from public.career_finance_transactions t
    cross join lateral public.absolute_game_day_v1(t.game_absolute_day) a
    where t.player_id=v_player and t.game_absolute_day between v_start and v_abs and t.subcategory<>'opening_balance'
  ), grouped as (
    select
      case v_g when 'daily' then game_absolute_day when 'weekly' then ((gd_season-1)*54+season_week) when 'monthly' then ((gd_season-1)*12+gd_month) else gd_season end sort_key,
      case v_g when 'daily' then to_char(make_date(2000,gd_month::integer,gd_day::integer),'Mon DD') when 'weekly' then format('S%s W%s',gd_season,season_week) when 'monthly' then format('%s S%s',to_char(make_date(2000,gd_month::integer,1),'Mon'),gd_season) else format('Season %s',gd_season) end label,
      coalesce(sum(amount) filter(where amount>0),0)::bigint income,
      coalesce(abs(sum(amount) filter(where amount<0)),0)::bigint expenses
    from tx group by 1,2
  ) select coalesce(jsonb_agg(jsonb_build_object('key',sort_key,'label',label,'income',income,'expenses',expenses,'net',income-expenses) order by sort_key),'[]'::jsonb) into v_series from grouped;

  select coalesce(jsonb_agg(jsonb_build_object('category',category,'amount',amount) order by amount desc),'[]'::jsonb) into v_income_cats
  from (select category,sum(amount)::bigint amount from public.career_finance_transactions where player_id=v_player and game_absolute_day between v_start and v_abs and amount>0 and subcategory<>'opening_balance' group by category) x;
  select coalesce(jsonb_agg(jsonb_build_object('category',category,'amount',amount) order by amount desc),'[]'::jsonb) into v_expense_cats
  from (select category,abs(sum(amount))::bigint amount from public.career_finance_transactions where player_id=v_player and game_absolute_day between v_start and v_abs and amount<0 group by category) x;
  return jsonb_build_object('granularity',v_g,'from_absolute_day',v_start,'through_absolute_day',v_abs,'series',v_series,'income_categories',v_income_cats,'expense_categories',v_expense_cats);
end; $$;
revoke all on function public.get_career_finance_analytics_v1(text) from public,anon;
grant execute on function public.get_career_finance_analytics_v1(text) to authenticated;
