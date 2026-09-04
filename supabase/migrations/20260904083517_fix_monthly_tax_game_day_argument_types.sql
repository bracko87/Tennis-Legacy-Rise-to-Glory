create or replace function public.process_due_career_tax_v1(p_player_id uuid,p_through_absolute_day integer default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_through integer; v_opening integer; v_rate numeric(6,4); v_count integer:=0; v_total bigint:=0;
  curgd record; r record; v_income bigint; v_tax bigint; v_post jsonb; v_tx uuid;
begin
  if not exists(select 1 from public.players p where p.id=p_player_id and p.player_type='human' and p.owner_user_id is not null) then return jsonb_build_object('status','skipped','reason','not_human_player'); end if;
  select tax_rate into v_rate from public.career_tax_settings where id=1;
  v_through:=coalesce(p_through_absolute_day,public.game_day_absolute_v1(d.season,d.month,d.day)) from public.get_current_game_day_internal_v1() d;
  select min(game_absolute_day) into v_opening from public.career_finance_transactions where player_id=p_player_id;
  if v_opening is null then perform public.ensure_player_career_finance_v1(p_player_id); select min(game_absolute_day) into v_opening from public.career_finance_transactions where player_id=p_player_id; end if;
  select * into curgd from public.absolute_game_day_v1(v_through);
  for r in
    select s.season::integer as season,m.month::smallint as month,
      public.game_day_absolute_v1((case when m.month=12 then s.season+1 else s.season end)::integer,(case when m.month=12 then 1 else m.month+1 end)::smallint,1::smallint) due_abs
    from generate_series(1,curgd.season::integer) s(season)
    cross join generate_series(1,12) m(month)
    where public.game_day_absolute_v1((case when m.month=12 then s.season+1 else s.season end)::integer,(case when m.month=12 then 1 else m.month+1 end)::smallint,1::smallint)<=v_through
      and public.game_day_absolute_v1((case when m.month=12 then s.season+1 else s.season end)::integer,(case when m.month=12 then 1 else m.month+1 end)::smallint,1::smallint)>v_opening
    order by s.season,m.month
  loop
    if not exists(select 1 from public.career_tax_periods p where p.player_id=p_player_id and p.season=r.season and p.month=r.month) then
      select coalesce(sum(amount),0) into v_income from public.career_finance_transactions where player_id=p_player_id and season=r.season and month=r.month and amount>0 and is_taxable;
      v_tax:=round(v_income*v_rate)::bigint;
      v_tx:=null;
      if v_tax>0 then
        v_post:=public.post_career_finance_transaction_v1(p_player_id,-v_tax,'tax','monthly_income_tax',format('Monthly income tax — Season %s, %s',r.season,to_char(make_date(2000,r.month,1),'FMMonth')),'career_tax',format('%s-%s',r.season,r.month),format('monthly-tax:%s:%s',r.season,r.month),jsonb_build_object('taxable_income',v_income,'tax_rate',v_rate,'tax_period_season',r.season,'tax_period_month',r.month),false,r.due_abs);
        v_tx:=(v_post->>'transaction_id')::uuid;
      end if;
      insert into public.career_tax_periods(player_id,season,month,taxable_income,tax_rate,tax_amount,due_absolute_day,settled_absolute_day,transaction_id)
      values(p_player_id,r.season,r.month,v_income,v_rate,v_tax,r.due_abs,v_through,v_tx)
      on conflict(player_id,season,month) do nothing;
      v_count:=v_count+1; v_total:=v_total+v_tax;
    end if;
  end loop;
  return jsonb_build_object('status','processed','periods_settled',v_count,'tax_posted',v_total,'through_absolute_day',v_through,'tax_rate',v_rate);
end; $$;
revoke all on function public.process_due_career_tax_v1(uuid,integer) from public,anon,authenticated;

create or replace function public.get_career_finance_dashboard_v1(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_player uuid; v_abs integer; gd record; a public.player_career_finance_accounts%rowtype; v_income bigint; v_expenses bigint; v_recent jsonb; v_categories jsonb; v_upcoming jsonb; v_tax_rate numeric(6,4); v_taxable bigint; v_tax_est bigint; v_tax_history jsonb; v_next_due integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human'; if v_player is null then raise exception 'Player not found.'; end if;
  perform public.ensure_player_career_finance_v1(v_player);
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day); select * into a from public.player_career_finance_accounts where player_id=v_player;
  select coalesce(sum(amount) filter(where amount>0 and subcategory<>'opening_balance'),0),coalesce(abs(sum(amount) filter(where amount<0)),0) into v_income,v_expenses from public.career_finance_transactions where player_id=v_player and season=gd.season;
  select coalesce(jsonb_agg(x order by x.game_absolute_day desc,x.created_at desc),'[]'::jsonb) into v_recent from (select id,game_absolute_day,season,month,day,category,subcategory,amount,balance_before,balance_after,description,source_type,source_id,metadata,is_taxable,created_at from public.career_finance_transactions where player_id=v_player order by game_absolute_day desc,created_at desc limit greatest(1,least(coalesce(p_limit,100),500))) x;
  select coalesce(jsonb_agg(jsonb_build_object('category',category,'income',income,'expenses',expenses,'net',income-expenses) order by category),'[]'::jsonb) into v_categories from (select category,coalesce(sum(amount) filter(where amount>0 and subcategory<>'opening_balance'),0) income,coalesce(abs(sum(amount) filter(where amount<0)),0) expenses from public.career_finance_transactions where player_id=v_player and season=gd.season group by category having coalesce(sum(amount) filter(where subcategory<>'opening_balance'),0)<>0) c;
  select coalesce(jsonb_agg(u order by u.due_absolute_day,u.kind),'[]'::jsonb) into v_upcoming from (
    select 'travel'::text kind,l.departure_absolute_day due_absolute_day,format('%s → %s',coalesce(l.source_city,l.source_country_code),coalesce(l.destination_city,l.destination_country_code)) description,l.estimated_cost::bigint amount,jsonb_build_object('travel_leg_id',l.id,'purpose',l.purpose,'travel_class',l.travel_class) metadata from public.player_travel_legs l where l.player_id=v_player and l.status='planned' and l.departure_absolute_day>=v_abs
    union all
    select 'staff_salary',(c.start_absolute_day+6 + greatest(0,ceil((v_abs-(c.start_absolute_day+6))::numeric/7))::integer*7)::integer,format('%s weekly salary',s.first_name||' '||s.last_name),c.weekly_salary::bigint,jsonb_build_object('contract_id',c.id,'staff_id',s.id) from public.player_staff_contracts c join public.staff_members s on s.id=c.staff_id where c.player_id=v_player and c.status='active' and (c.start_absolute_day+6 + greatest(0,ceil((v_abs-(c.start_absolute_day+6))::numeric/7))::integer*7)<=c.end_absolute_day
  ) u where u.due_absolute_day<=v_abs+60;
  select tax_rate into v_tax_rate from public.career_tax_settings where id=1;
  select coalesce(sum(amount),0) into v_taxable from public.career_finance_transactions where player_id=v_player and season=gd.season and month=gd.month and amount>0 and is_taxable;
  v_tax_est:=round(v_taxable*v_tax_rate)::bigint;
  v_next_due:=public.game_day_absolute_v1((case when gd.month=12 then gd.season+1 else gd.season end)::integer,(case when gd.month=12 then 1 else gd.month+1 end)::smallint,1::smallint);
  select coalesce(jsonb_agg(x order by x.season desc,x.month desc),'[]'::jsonb) into v_tax_history from (select season,month,taxable_income,tax_rate,tax_amount,due_absolute_day,settled_absolute_day from public.career_tax_periods where player_id=v_player order by season desc,month desc limit 24) x;
  return jsonb_build_object('player_id',v_player,'currency','USD','balance',a.balance,'is_live',a.is_live,'current_absolute_day',v_abs,'season',gd.season,'month',gd.month,'day',gd.day,'season_income',v_income,'season_expenses',v_expenses,'season_net',v_income-v_expenses,'category_totals',v_categories,'upcoming_commitments',v_upcoming,'recent_transactions',v_recent,'tax',jsonb_build_object('rate',v_tax_rate,'current_month_taxable_income',v_taxable,'current_month_estimated_tax',v_tax_est,'next_settlement_absolute_day',v_next_due,'history',v_tax_history));
end; $$;
revoke all on function public.get_career_finance_dashboard_v1(integer) from public,anon;
grant execute on function public.get_career_finance_dashboard_v1(integer) to authenticated;
