create or replace function public.get_private_life_investment_daily_history_v1(p_instrument_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_player uuid;
  v_result jsonb;
begin
  v_player := public.private_life_current_player_v1();
  if not exists (select 1 from public.private_life_investment_instruments where code=p_instrument_code and active=true) then
    raise exception 'Investment instrument not found.';
  end if;

  with base as (
    select
      ((h.metadata->>'game_total_seconds')::bigint / 86400)::bigint as game_day_index,
      (h.metadata->>'game_total_seconds')::bigint as game_total_seconds,
      h.price,
      h.captured_at
    from public.private_life_investment_quote_history h
    where h.instrument_code=p_instrument_code
      and h.metadata ? 'game_total_seconds'
  ), daily as (
    select
      game_day_index,
      min(game_total_seconds) as first_game_seconds,
      max(game_total_seconds) as last_game_seconds,
      (array_agg(price order by captured_at asc))[1] as open_price,
      (array_agg(price order by captured_at desc))[1] as close_price,
      min(price) as low_price,
      max(price) as high_price,
      count(*)::int as snapshots
    from base
    group by game_day_index
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'game_day_index',game_day_index,
    'game_total_seconds',last_game_seconds,
    'open',open_price,
    'close',close_price,
    'low',low_price,
    'high',high_price,
    'snapshots',snapshots
  ) order by game_day_index),'[]'::jsonb)
  into v_result
  from daily;

  return v_result;
end;
$$;
revoke all on function public.get_private_life_investment_daily_history_v1(text) from public, anon;
grant execute on function public.get_private_life_investment_daily_history_v1(text) to authenticated;

create or replace function public.get_private_life_investment_trade_history_v1()
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_player uuid;
  v_result jsonb;
begin
  v_player := public.private_life_current_player_v1();
  select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb)
  into v_result
  from (
    select t.id,t.instrument_code,i.asset_type,i.symbol,i.name,t.side,t.quantity,t.unit_price,
           t.gross_amount,t.realized_pnl,t.game_absolute_day,t.quote_as_of,t.created_at
    from public.private_life_investment_trades t
    join public.private_life_investment_instruments i on i.code=t.instrument_code
    where t.player_id=v_player
  ) x;
  return v_result;
end;
$$;
revoke all on function public.get_private_life_investment_trade_history_v1() from public, anon;
grant execute on function public.get_private_life_investment_trade_history_v1() to authenticated;
