do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='tennis-private-life-stock-quotes-v1' limit 1;
  if v_job_id is not null then
    perform cron.alter_job(v_job_id, schedule := '*/15 12-22 * * 1-5');
  end if;
  select jobid into v_job_id from cron.job where jobname='tennis-private-life-crypto-quotes-v1' limit 1;
  if v_job_id is not null then
    perform cron.alter_job(v_job_id, schedule := '*/15 * * * *');
  end if;
end $$;

create or replace function public.get_private_life_asset_history_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_player uuid;
  v_history jsonb;
begin
  v_player := public.private_life_current_player_v1();

  select coalesce(jsonb_agg(x order by x.purchase_absolute_day desc, x.created_at desc),'[]'::jsonb)
  into v_history
  from (
    select
      o.id,
      o.catalog_code,
      c.category,
      c.name as base_name,
      case when l.code is not null then c.name||' · '||l.city else c.name end as name,
      o.acquisition_type,
      o.purchase_absolute_day,
      o.purchase_price,
      o.sold_absolute_day,
      o.sold_price,
      case when o.sold_absolute_day is null then 'owned' else 'sold' end as status,
      o.created_at,
      l.city,
      l.country_code,
      l.country_name
    from public.private_life_player_assets o
    join public.private_life_asset_catalog c on c.code=o.catalog_code
    left join public.private_life_property_locations l on l.code=o.location_code
    where o.player_id=v_player
  ) x;

  return v_history;
end;
$$;

revoke all on function public.get_private_life_asset_history_v1() from public, anon;
grant execute on function public.get_private_life_asset_history_v1() to authenticated;

create or replace function public.get_private_life_investments_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player uuid; v_account public.player_career_finance_accounts%rowtype;
  v_portfolio_value bigint:=0; v_cost_basis bigint:=0; v_realized bigint:=0;
  v_positions jsonb:='[]'::jsonb; v_instruments jsonb:='[]'::jsonb; v_trades jsonb:='[]'::jsonb;
begin
  v_player:=public.private_life_current_player_v1();
  perform public.ensure_player_career_finance_v1(v_player);
  select * into v_account from public.player_career_finance_accounts where player_id=v_player;
  select coalesce(sum(round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))),0)::bigint,coalesce(sum(p.cost_basis),0)::bigint
    into v_portfolio_value,v_cost_basis
  from public.private_life_investment_positions p left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
  where p.player_id=v_player and p.quantity>0;
  select coalesce(sum(realized_pnl),0)::bigint into v_realized from public.private_life_investment_trades where player_id=v_player and side='sell';

  select coalesce(jsonb_agg(x order by x.asset_type,x.sort_order,x.symbol),'[]'::jsonb) into v_instruments
  from (
    select i.code,i.asset_type,i.symbol,i.name,i.exchange,i.sort_order,i.metadata,q.price,q.previous_price,q.quote_as_of,q.fetched_at,q.source as quote_source,
      coalesce(q.metadata,'{}'::jsonb)||jsonb_build_object('intraday_history',coalesce(h.history,'[]'::jsonb)) as quote_metadata,
      case when q.fetched_at is null then true when i.asset_type='crypto' then q.fetched_at<now()-interval '25 minutes' else q.fetched_at<now()-interval '35 minutes' end as quote_stale,
      case when q.price is null then false when i.asset_type='crypto' then q.fetched_at>=now()-interval '60 minutes' else q.fetched_at>=now()-interval '7 days' end as tradeable,
      coalesce(p.quantity,0)::numeric as owned_quantity,coalesce(p.cost_basis,0)::bigint as cost_basis,
      case when q.price is null then 0 else round(coalesce(p.quantity,0)*q.price)::bigint end as market_value
    from public.private_life_investment_instruments i
    left join public.private_life_investment_quotes q on q.instrument_code=i.code
    left join public.private_life_investment_positions p on p.player_id=v_player and p.instrument_code=i.code
    left join lateral (
      select jsonb_agg(jsonb_build_object(
        't',extract(epoch from z.captured_at)::bigint,
        'g',case when z.metadata ? 'game_total_seconds' then (z.metadata->>'game_total_seconds')::bigint else null end,
        'p',z.price,
        'changed',coalesce((z.metadata->>'price_changed')::boolean,false)
      ) order by z.captured_at) as history
      from (select captured_at,price,metadata from public.private_life_investment_quote_history hh where hh.instrument_code=i.code order by captured_at desc limit 96) z
    ) h on true
    where i.active=true
  ) x;

  select coalesce(jsonb_agg(x order by x.market_value_precise desc,x.name),'[]'::jsonb) into v_positions
  from (
    select p.instrument_code,i.asset_type,i.symbol,i.name,i.exchange,p.quantity,p.cost_basis,q.price,q.previous_price,q.quote_as_of,q.fetched_at,q.source as quote_source,
      coalesce(q.metadata,'{}'::jsonb)||jsonb_build_object('intraday_history',coalesce(h.history,'[]'::jsonb)) as quote_metadata,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end),2) as market_value_precise,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end),2)-p.cost_basis::numeric as unrealized_pnl_precise,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))::bigint as market_value,
      round(p.quantity*coalesce(q.price,case when p.quantity>0 then p.cost_basis::numeric/p.quantity else 0 end))::bigint-p.cost_basis as unrealized_pnl,
      case when p.quantity>0 then round((p.cost_basis::numeric/p.quantity),8) else 0 end as average_buy_price,
      case when p.cost_basis>0 then round(((p.quantity*coalesce(q.price,p.cost_basis::numeric/nullif(p.quantity,0)))-p.cost_basis::numeric)*100/p.cost_basis::numeric,4) else 0 end as return_pct,
      case when q.previous_price>0 then round(((q.price-q.previous_price)*100/q.previous_price),4) else null end as daily_move_pct
    from public.private_life_investment_positions p
    join public.private_life_investment_instruments i on i.code=p.instrument_code
    left join public.private_life_investment_quotes q on q.instrument_code=p.instrument_code
    left join lateral (
      select jsonb_agg(jsonb_build_object(
        't',extract(epoch from z.captured_at)::bigint,
        'g',case when z.metadata ? 'game_total_seconds' then (z.metadata->>'game_total_seconds')::bigint else null end,
        'p',z.price,
        'changed',coalesce((z.metadata->>'price_changed')::boolean,false)
      ) order by z.captured_at) as history
      from (select captured_at,price,metadata from public.private_life_investment_quote_history hh where hh.instrument_code=i.code order by captured_at desc limit 96) z
    ) h on true
    where p.player_id=v_player and p.quantity>0
  ) x;

  select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb) into v_trades
  from (select t.id,t.instrument_code,i.asset_type,i.symbol,i.name,t.side,t.quantity,t.unit_price,t.gross_amount,t.realized_pnl,t.game_absolute_day,t.quote_as_of,t.created_at from public.private_life_investment_trades t join public.private_life_investment_instruments i on i.code=t.instrument_code where t.player_id=v_player order by t.created_at desc limit 100) x;
  return jsonb_build_object('player_id',v_player,'currency',v_account.currency,'cash_balance',v_account.balance,'portfolio_value',v_portfolio_value,'cost_basis',v_cost_basis,'unrealized_pnl',v_portfolio_value-v_cost_basis,'realized_pnl',v_realized,'positions',v_positions,'instruments',v_instruments,'trades',v_trades);
end;
$$;