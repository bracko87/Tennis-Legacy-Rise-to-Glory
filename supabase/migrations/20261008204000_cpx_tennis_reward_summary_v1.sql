-- Read-only CPX rewards summary for the signed-in Tennis Legacy player.
create or replace function public.get_my_cpx_tennis_reward_summary_v1()
returns jsonb language plpgsql stable security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_active bigint := 0;
  v_credited integer := 0;
  v_recent jsonb := '[]'::jsonb;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;
  select active_micro_usd, net_coins_applied into v_active,v_credited
  from public.cpx_tennis_reward_balances where user_id=v_user;
  v_active := coalesce(v_active,0);
  v_credited := coalesce(v_credited,0);
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'trans_id',x.trans_id,
      'reward_type',x.reward_type,
      'amount_usd', x.amount_micro_usd::numeric / 1000000,
      'status',x.status,
      'created_at',x.received_at
    ) order by x.received_at desc
  ),'[]'::jsonb) into v_recent
  from (
    select trans_id,reward_type,amount_micro_usd,status,received_at
    from public.cpx_tennis_reward_transactions
    where user_id=v_user
    order by received_at desc limit 15
  ) x;

  return jsonb_build_object(
    'total_coins',v_credited,
    'active_usd',v_active::numeric / 1000000,
    'pending_coin_fraction',
      (v_active::numeric * 15 / 1000000)
      - floor(v_active::numeric * 15 / 1000000),
    'recent',v_recent
  );
end $$;
revoke all on function public.get_my_cpx_tennis_reward_summary_v1()
  from public,anon;
grant execute on function public.get_my_cpx_tennis_reward_summary_v1()
  to authenticated;