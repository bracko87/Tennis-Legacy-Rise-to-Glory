alter table public.player_career_finance_accounts
  add column if not exists processed_through_absolute_day integer;

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

    -- Always process overdue travel/tax independently of the cursor. This also
    -- catches an itinerary that was rebuilt after its original travel date.
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
      -- Recheck today's hotel idempotently in case the current-day commitment
      -- changed after an earlier run.
      v_hotel:=public.process_tournament_hotel_day_v1(p.id,v_abs);
    end if;

    update public.player_career_finance_accounts
    set processed_through_absolute_day=v_abs,
        updated_at=now()
    where player_id=p.id;

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

-- Run human finance catch-up independently of page visits.
do $$
begin
  if exists(select 1 from cron.job where jobname='process-human-finance-hourly-v1') then
    perform cron.unschedule('process-human-finance-hourly-v1');
  end if;
end $$;

select cron.schedule(
  'process-human-finance-hourly-v1',
  '37 * * * *',
  'select public.process_human_finance_to_current_day_v1(null);'
);

-- Catch up active human careers immediately when this migration is applied.
select public.process_human_finance_to_current_day_v1(null);
