create or replace function public.get_career_finance_dashboard_v1(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid(); v_player uuid; v_abs integer; gd record;
  a public.player_career_finance_accounts%rowtype;
  v_income bigint; v_expenses bigint; v_recent jsonb; v_categories jsonb; v_upcoming jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  perform public.ensure_player_career_finance_v1(v_player);
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  select * into a from public.player_career_finance_accounts where player_id=v_player;

  select coalesce(sum(amount) filter(where amount>0),0),coalesce(abs(sum(amount) filter(where amount<0)),0)
  into v_income,v_expenses
  from public.career_finance_transactions
  where player_id=v_player and season=gd.season
    and not (category='career' and subcategory='opening_balance');

  select coalesce(jsonb_agg(x order by x.game_absolute_day desc,x.created_at desc),'[]'::jsonb)
  into v_recent
  from (
    select id,game_absolute_day,season,month,day,category,subcategory,amount,balance_before,balance_after,description,source_type,source_id,metadata,created_at
    from public.career_finance_transactions
    where player_id=v_player
    order by game_absolute_day desc,created_at desc
    limit greatest(1,least(coalesce(p_limit,50),100))
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('category',category,'income',income,'expenses',expenses,'net',income-expenses) order by category),'[]'::jsonb)
  into v_categories
  from (
    select category,coalesce(sum(amount) filter(where amount>0),0) income,coalesce(abs(sum(amount) filter(where amount<0)),0) expenses
    from public.career_finance_transactions
    where player_id=v_player and season=gd.season
      and not (category='career' and subcategory='opening_balance')
    group by category
  ) c;

  select coalesce(jsonb_agg(u order by u.due_absolute_day,u.kind),'[]'::jsonb)
  into v_upcoming
  from (
    select 'travel'::text kind,l.departure_absolute_day due_absolute_day,
      format('%s → %s',coalesce(l.source_city,l.source_country_code),coalesce(l.destination_city,l.destination_country_code)) description,
      l.estimated_cost::bigint amount,
      jsonb_build_object('travel_leg_id',l.id,'purpose',l.purpose,'travel_class',l.travel_class) metadata
    from public.player_travel_legs l
    where l.player_id=v_player and l.status='planned' and l.departure_absolute_day>=v_abs
    union all
    select 'staff_salary',
      (c.start_absolute_day+6 + greatest(0,ceil((v_abs-(c.start_absolute_day+6))::numeric/7))::integer*7)::integer,
      format('%s weekly salary',s.first_name||' '||s.last_name),c.weekly_salary::bigint,
      jsonb_build_object('contract_id',c.id,'staff_id',s.id)
    from public.player_staff_contracts c
    join public.staff_members s on s.id=c.staff_id
    where c.player_id=v_player and c.status='active'
      and (c.start_absolute_day+6 + greatest(0,ceil((v_abs-(c.start_absolute_day+6))::numeric/7))::integer*7)<=c.end_absolute_day
  ) u
  where u.due_absolute_day<=v_abs+60;

  return jsonb_build_object('player_id',v_player,'currency',a.currency,'balance',a.balance,'is_live',a.is_live,'current_absolute_day',v_abs,'season',gd.season,'month',gd.month,'day',gd.day,'season_income',v_income,'season_expenses',v_expenses,'season_net',v_income-v_expenses,'category_totals',v_categories,'upcoming_commitments',v_upcoming,'recent_transactions',v_recent);
end;
$$;

revoke all on function public.get_career_finance_dashboard_v1(integer) from public,anon;
grant execute on function public.get_career_finance_dashboard_v1(integer) to authenticated;