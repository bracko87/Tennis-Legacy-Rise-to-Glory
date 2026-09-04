alter table public.career_finance_transactions
  add column if not exists is_taxable boolean not null default false;

create table if not exists public.career_tax_settings (
  id smallint primary key default 1 check (id=1),
  tax_rate numeric(6,4) not null default 0.1800 check (tax_rate between 0 and 1),
  currency text not null default 'USD',
  updated_at timestamptz not null default now()
);
insert into public.career_tax_settings(id,tax_rate,currency)
values(1,0.1800,'USD')
on conflict(id) do update set tax_rate=excluded.tax_rate,currency='USD',updated_at=now();

create table if not exists public.career_taxable_categories (
  category text primary key,
  label text not null,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.career_taxable_categories(category,label,is_active) values
  ('prize_money','Prize money',true),
  ('sponsorship','Sponsorship income',true),
  ('appearance_fee','Appearance fees',true),
  ('performance_bonus','Performance bonuses',true),
  ('other_income','Other career income',true)
on conflict(category) do update set label=excluded.label,is_active=excluded.is_active,updated_at=now();

create table if not exists public.career_tax_periods (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  season integer not null,
  month smallint not null check(month between 1 and 12),
  taxable_income bigint not null default 0,
  tax_rate numeric(6,4) not null,
  tax_amount bigint not null default 0,
  due_absolute_day integer not null,
  settled_absolute_day integer not null,
  transaction_id uuid references public.career_finance_transactions(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(player_id,season,month)
);
create index if not exists career_tax_periods_player_period_idx
  on public.career_tax_periods(player_id,season desc,month desc);

alter table public.career_tax_periods enable row level security;
revoke all on public.career_tax_periods from public,anon,authenticated;
revoke all on public.career_tax_settings from public,anon;
revoke all on public.career_taxable_categories from public,anon;
grant select on public.career_tax_settings,public.career_taxable_categories to authenticated;

create or replace function public.post_career_finance_transaction_v1(
  p_player_id uuid,p_amount bigint,p_category text,p_subcategory text,p_description text,p_source_type text,p_source_id text,p_idempotency_key text,p_metadata jsonb default '{}'::jsonb,p_require_funds boolean default true,p_game_absolute_day integer default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.player_career_finance_accounts%rowtype; t public.career_finance_transactions%rowtype; v_abs integer; gd record; v_after bigint; v_taxable boolean:=false;
begin
  if p_idempotency_key is null or btrim(p_idempotency_key)='' then raise exception 'Finance idempotency key is required.'; end if;
  if p_amount=0 then raise exception 'Finance transaction amount cannot be zero.'; end if;
  select * into t from public.career_finance_transactions where player_id=p_player_id and idempotency_key=p_idempotency_key;
  if t.id is not null then return jsonb_build_object('status','already_posted','transaction_id',t.id,'amount',t.amount,'balance',t.balance_after); end if;
  perform public.ensure_player_career_finance_v1(p_player_id);
  select * into a from public.player_career_finance_accounts where player_id=p_player_id for update;
  if p_require_funds and p_amount<0 and a.balance+p_amount<0 then raise exception 'Insufficient career funds. Available: $%, required: $%.',a.balance,abs(p_amount); end if;
  v_after:=a.balance+p_amount;
  select coalesce((p_metadata->>'taxable')::boolean,false) or exists(
    select 1 from public.career_taxable_categories c where c.category=lower(p_category) and c.is_active
  ) into v_taxable;
  v_taxable:=v_taxable and p_amount>0;
  v_abs:=coalesce(p_game_absolute_day,public.game_day_absolute_v1(d.season,d.month,d.day)) from public.get_current_game_day_internal_v1() d;
  select * into gd from public.absolute_game_day_v1(v_abs);
  update public.player_career_finance_accounts set balance=v_after,is_live=true,currency='USD',updated_at=now() where player_id=p_player_id;
  insert into public.career_finance_transactions(player_id,game_absolute_day,season,month,day,category,subcategory,amount,balance_before,balance_after,description,source_type,source_id,idempotency_key,metadata,is_taxable)
  values(p_player_id,v_abs,gd.season,gd.month,gd.day,lower(p_category),lower(p_subcategory),p_amount,a.balance,v_after,p_description,p_source_type,p_source_id,p_idempotency_key,coalesce(p_metadata,'{}'::jsonb),v_taxable) returning * into t;
  return jsonb_build_object('status','posted','transaction_id',t.id,'amount',t.amount,'balance_before',t.balance_before,'balance',t.balance_after,'is_taxable',t.is_taxable);
end; $$;
revoke all on function public.post_career_finance_transaction_v1(uuid,bigint,text,text,text,text,text,text,jsonb,boolean,integer) from public,anon,authenticated;

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
    select s.season,m.month,
      public.game_day_absolute_v1(case when m.month=12 then s.season+1 else s.season end,case when m.month=12 then 1 else m.month+1 end,1) due_abs
    from generate_series(1,curgd.season) s(season)
    cross join generate_series(1,12) m(month)
    where public.game_day_absolute_v1(case when m.month=12 then s.season+1 else s.season end,case when m.month=12 then 1 else m.month+1 end,1)<=v_through
      and public.game_day_absolute_v1(case when m.month=12 then s.season+1 else s.season end,case when m.month=12 then 1 else m.month+1 end,1)>v_opening
    order by s.season,m.month
  loop
    if not exists(select 1 from public.career_tax_periods p where p.player_id=p_player_id and p.season=r.season and p.month=r.month) then
      select coalesce(sum(amount),0) into v_income from public.career_finance_transactions
      where player_id=p_player_id and season=r.season and month=r.month and amount>0 and is_taxable;
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

create or replace function public.get_career_finance_analytics_v1(p_granularity text default 'monthly')
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
  v_uid uuid:=auth.uid(); v_player uuid; gd record; v_abs integer; v_start integer; v_series jsonb; v_income_cats jsonb; v_expense_cats jsonb; v_g text:=lower(coalesce(p_granularity,'monthly'));
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human'; if v_player is null then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  if v_g not in ('daily','weekly','monthly','season') then raise exception 'Invalid finance analytics granularity.'; end if;
  v_start:=case v_g when 'daily' then greatest(0,v_abs-13) when 'weekly' then greatest(0,v_abs-83) when 'monthly' then greatest(0,v_abs-365) else public.game_day_absolute_v1(greatest(1,gd.season-4),1,1) end;

  with tx as (
    select t.*,a.season as gd_season,a.month as gd_month,a.day as gd_day,a.season_week
    from public.career_finance_transactions t
    cross join lateral public.absolute_game_day_v1(t.game_absolute_day) a
    where t.player_id=v_player and t.game_absolute_day between v_start and v_abs and t.subcategory<>'opening_balance'
  ), grouped as (
    select
      case v_g when 'daily' then game_absolute_day when 'weekly' then ((gd_season-1)*54+season_week) when 'monthly' then ((gd_season-1)*12+gd_month) else gd_season end sort_key,
      case v_g when 'daily' then to_char(make_date(2000,gd_month,gd_day),'Mon DD') when 'weekly' then format('S%s W%s',gd_season,season_week) when 'monthly' then format('%s S%s',to_char(make_date(2000,gd_month,1),'Mon'),gd_season) else format('Season %s',gd_season) end label,
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
  v_next_due:=public.game_day_absolute_v1(case when gd.month=12 then gd.season+1 else gd.season end,case when gd.month=12 then 1 else gd.month+1 end,1);
  select coalesce(jsonb_agg(x order by x.season desc,x.month desc),'[]'::jsonb) into v_tax_history from (select season,month,taxable_income,tax_rate,tax_amount,due_absolute_day,settled_absolute_day from public.career_tax_periods where player_id=v_player order by season desc,month desc limit 24) x;
  return jsonb_build_object('player_id',v_player,'currency','USD','balance',a.balance,'is_live',a.is_live,'current_absolute_day',v_abs,'season',gd.season,'month',gd.month,'day',gd.day,'season_income',v_income,'season_expenses',v_expenses,'season_net',v_income-v_expenses,'category_totals',v_categories,'upcoming_commitments',v_upcoming,'recent_transactions',v_recent,'tax',jsonb_build_object('rate',v_tax_rate,'current_month_taxable_income',v_taxable,'current_month_estimated_tax',v_tax_est,'next_settlement_absolute_day',v_next_due,'history',v_tax_history));
end; $$;
revoke all on function public.get_career_finance_dashboard_v1(integer) from public,anon;
grant execute on function public.get_career_finance_dashboard_v1(integer) to authenticated;

create or replace function public.process_player_daily_activity_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine')
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_activity text; v_row public.player_daily_activity%rowtype; v_abs integer; v_travel jsonb; v_hotel jsonb; v_tax jsonb;
begin
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day);
  v_tax:=public.process_due_career_tax_v1(p_player_id,v_abs);
  v_travel:=public.process_due_travel_legs_v1(p_player_id,v_abs);
  v_hotel:=public.process_tournament_hotel_day_v1(p_player_id,v_abs);
  select * into v_row from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day for update; v_activity:=coalesce(v_row.activity_type,'home');
  if v_activity='home' then return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel); end if;
  if v_activity='travel' then return jsonb_build_object('status','completed','activity_type','travel','tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'effect_summary',v_row.effect_summary); end if;
  if v_activity='training_camp' then return public.process_training_camp_day_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel); end if;
  return jsonb_build_object('status','delegated','activity_type',v_activity,'tax_processing',v_tax,'travel_processing',v_travel,'hotel_processing',v_hotel,'reason',case v_activity when 'tournament' then 'Tournament/match engine owns this day; regular training is blocked.' when 'injured' then 'Injury/recovery engine owns this day; regular training is blocked.' else 'Regular training is blocked.' end);
end; $$;
