create or replace function public.reconcile_career_finance_running_balances_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_balance bigint;
  v_rows integer:=0;
begin
  if not exists(select 1 from public.players p where p.id=p_player_id and p.player_type='human' and p.owner_user_id is not null) then
    raise exception 'Human player not found.';
  end if;

  with ordered as (
    select
      t.id,
      t.amount,
      coalesce(sum(t.amount) over(
        partition by t.player_id
        order by t.game_absolute_day,t.created_at,t.id
        rows between unbounded preceding and current row
      ),0)::bigint as running_after
    from public.career_finance_transactions t
    where t.player_id=p_player_id
  )
  update public.career_finance_transactions t
  set balance_after=o.running_after,
      balance_before=o.running_after-o.amount
  from ordered o
  where t.id=o.id
    and (t.balance_after is distinct from o.running_after
      or t.balance_before is distinct from o.running_after-o.amount);

  get diagnostics v_rows=row_count;

  select coalesce(sum(t.amount),0)::bigint into v_balance
  from public.career_finance_transactions t
  where t.player_id=p_player_id;

  update public.player_career_finance_accounts
  set balance=v_balance,updated_at=now()
  where player_id=p_player_id;

  return jsonb_build_object('status','reconciled','player_id',p_player_id,'rows_updated',v_rows,'balance',v_balance);
end;
$$;

revoke all on function public.reconcile_career_finance_running_balances_v1(uuid) from public,anon,authenticated;

create or replace function public.process_human_finance_to_current_day_v1(p_player_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  gd record;
  v_abs integer;
  p record;
  v_from integer;
  v_day integer;
  v_players integer:=0;
  v_days integer:=0;
  v_travel jsonb;
  v_tax jsonb;
  v_hotel jsonb;
  v_reconcile jsonb;
begin
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  for p in
    select pl.id
    from public.players pl
    where pl.player_type='human'
      and pl.owner_user_id is not null
      and (p_player_id is null or pl.id=p_player_id)
    order by pl.created_at,pl.id
  loop
    perform public.ensure_player_career_finance_v1(p.id);

    v_travel:=public.process_due_travel_legs_v1(p.id,v_abs);
    v_tax:=public.process_due_career_tax_v1(p.id,v_abs);

    select coalesce(
      a.processed_through_absolute_day+1,
      (select min(t.game_absolute_day)
       from public.career_finance_transactions t
       where t.player_id=p.id and t.idempotency_key='career-opening-balance'),
      v_abs
    ) into v_from
    from public.player_career_finance_accounts a
    where a.player_id=p.id;

    if v_from<=v_abs then
      for v_day in select generate_series(v_from,v_abs)
      loop
        v_hotel:=public.process_tournament_hotel_day_v1(p.id,v_day);
        v_days:=v_days+1;
      end loop;
    else
      v_hotel:=public.process_tournament_hotel_day_v1(p.id,v_abs);
    end if;

    update public.player_career_finance_accounts
    set processed_through_absolute_day=v_abs,updated_at=now()
    where player_id=p.id;

    -- If an overdue transaction was inserted with an earlier game date, restore
    -- the ledger's historical running balances in game-date order.
    v_reconcile:=public.reconcile_career_finance_running_balances_v1(p.id);
    v_players:=v_players+1;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'through_absolute_day',v_abs,
    'players',v_players,
    'hotel_days_checked',v_days
  );
end;
$$;

revoke all on function public.process_human_finance_to_current_day_v1(uuid) from public,anon,authenticated;

select public.process_human_finance_to_current_day_v1(null);
