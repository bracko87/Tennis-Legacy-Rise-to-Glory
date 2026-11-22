CREATE OR REPLACE FUNCTION public.award_birthday_reward_v1(p_user_id uuid, p_reward_year integer, p_local_birthday_date date, p_timezone text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_reward_id uuid;
  v_balance bigint;
  v_ledger_id uuid;
  v_reference text;
begin
  if p_reward_year is null or p_local_birthday_date is null then
    raise exception 'Birthday reward date is required.';
  end if;

  -- Temporary guest identities must never earn real-world Coins.
  if not exists (select 1 from auth.users u where u.id=p_user_id and u.deleted_at is null and u.is_anonymous is false) then
    raise exception 'Birthday rewards require a permanent account.' using errcode='42501';
  end if;

  -- No birthday, no reward. Validate server-side even for internal callers.
  if not exists (
    select 1 from public.profiles p
    where p.id=p_user_id
      and p.birthday_month is not null
      and p.birthday_day is not null
      and public.birthday_matches_local_date_v1(
        p.birthday_month,p.birthday_day,p_local_birthday_date
      )
      and p_reward_year=extract(year from p_local_birthday_date)::integer
  ) then
    raise exception 'Birthday reward not eligible.';
  end if;

  insert into public.birthday_rewards(
    user_id,reward_year,reward_amount,local_birthday_date,processing_timezone
  ) values (
    p_user_id,p_reward_year,20,p_local_birthday_date,coalesce(nullif(p_timezone,''),'UTC')
  )
  on conflict(user_id,reward_year) do nothing
  returning id into v_reward_id;

  if v_reward_id is null then
    return jsonb_build_object('status','already_awarded','user_id',p_user_id,'reward_year',p_reward_year);
  end if;

  insert into public.user_wallets(user_id)
  values(p_user_id)
  on conflict(user_id) do nothing;

  update public.user_wallets
  set coins_balance=coins_balance+20,
      lifetime_coins_earned=lifetime_coins_earned+20,
      updated_at=now()
  where user_id=p_user_id
  returning coins_balance into v_balance;

  if v_balance is null then
    raise exception 'Unable to credit birthday reward wallet.';
  end if;

  v_reference:=format('birthday:%s:%s',p_user_id,p_reward_year);

  insert into public.coin_ledger(
    user_id,amount,balance_after,entry_type,description,reference_id
  ) values (
    p_user_id,20,v_balance,'birthday_reward','Birthday Gift',v_reference
  )
  returning id into v_ledger_id;

  update public.birthday_rewards
  set coin_ledger_id=v_ledger_id,updated_at=now()
  where id=v_reward_id;

  perform public.ensure_birthday_reward_followups_v1(v_reward_id);

  return jsonb_build_object(
    'status','awarded',
    'user_id',p_user_id,
    'reward_year',p_reward_year,
    'reward_amount',20,
    'balance_after',v_balance,
    'birthday_reward_id',v_reward_id,
    'coin_ledger_id',v_ledger_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.process_real_birthday_rewards_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  r record;
  v_local_date date;
  v_year integer;
  v_awarded integer:=0;
  v_existing integer:=0;
  v_followups integer:=0;
  v_result jsonb;
begin
  for r in
    select p.id as user_id,
           p.birthday_month,
           p.birthday_day,
           coalesce(nullif(p.birthday_timezone,''),'UTC') as birthday_timezone
    from public.profiles p
    join auth.users u on u.id=p.id
    where u.deleted_at is null
      and u.is_anonymous is false
      and p.birthday_month is not null
      and p.birthday_day is not null
  loop
    begin
      v_local_date:=(now() at time zone r.birthday_timezone)::date;
    exception when others then
      v_local_date:=(now() at time zone 'UTC')::date;
    end;

    v_year:=extract(year from v_local_date)::integer;

    if public.birthday_matches_local_date_v1(
      r.birthday_month,
      r.birthday_day,
      v_local_date
    ) then
      v_result:=public.award_birthday_reward_v1(
        r.user_id,v_year,v_local_date,r.birthday_timezone
      );
      if v_result->>'status'='awarded' then
        v_awarded:=v_awarded+1;
      else
        v_existing:=v_existing+1;
      end if;
    end if;
  end loop;

  for r in
    select br.id
    from public.birthday_rewards br
    where br.notification_id is null
       or br.email_outbox_id is null
  loop
    perform public.ensure_birthday_reward_followups_v1(r.id);
    v_followups:=v_followups+1;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'awarded',v_awarded,
    'already_awarded_today',v_existing,
    'followups_checked',v_followups,
    'processed_at',now()
  );
end;
$function$;
