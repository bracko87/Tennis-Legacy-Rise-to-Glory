-- Project Helios H06: a birthday is optional. Empty birthdays are NULL, not fake defaults.
ALTER TABLE public.profiles
  ALTER COLUMN birthday_month DROP NOT NULL,
  ALTER COLUMN birthday_day DROP NOT NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_birthday_complete_or_blank_h06
  CHECK (
    (birthday_month IS NULL AND birthday_day IS NULL AND birthday_year IS NULL)
    OR (birthday_month IS NOT NULL AND birthday_day IS NOT NULL)
  );

-- Preserve existing immutable birthday policy, signup rules and 20-coin gift.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_username text;
  v_month integer;
  v_day integer;
  v_year integer;
  v_timezone text;
  v_birth_date date;
begin
  v_username:=btrim(coalesce(new.raw_user_meta_data->>'username',''));
  v_month:=nullif(new.raw_user_meta_data->>'birthday_month','')::integer;
  v_day:=nullif(new.raw_user_meta_data->>'birthday_day','')::integer;
  v_year:=nullif(new.raw_user_meta_data->>'birthday_year','')::integer;
  v_timezone:=coalesce(nullif(btrim(new.raw_user_meta_data->>'birthday_timezone'),''),'UTC');

  if v_username !~ '^[A-Za-z0-9_.-]{3,24}$' then
    raise exception 'Invalid username.';
  end if;

  -- Fully omitted birthday is allowed, but a partial date is never accepted.
  if (v_month is null) <> (v_day is null) then
    raise exception 'Provide both birthday month and day, or leave the birthday blank.';
  end if;
  if v_month is null and v_year is not null then
    raise exception 'A birthday year requires month and day.';
  end if;
  if v_month is not null and not v_month between 1 and 12 then
    raise exception 'Invalid birthday month.';
  end if;
  if v_day is not null and not v_day between 1 and 31 then
    raise exception 'Invalid birthday day.';
  end if;

  if v_month is null then
    -- Missing birthday is intentionally stored as NULL; no reward eligibility.
    null;
  elsif v_year is not null then
    if v_year < 1900 or v_year > extract(year from current_date)::integer then
      raise exception 'Invalid birthday year.';
    end if;

    begin
      v_birth_date:=make_date(v_year,v_month,v_day);
    exception when others then
      raise exception 'Invalid birthday date.';
    end;

    if v_birth_date>current_date then
      raise exception 'Birthday cannot be in the future.';
    end if;
  else
    begin
      perform make_date(2000,v_month,v_day);
    exception when others then
      raise exception 'Invalid birthday date.';
    end;
  end if;

  if not exists(select 1 from pg_catalog.pg_timezone_names where name=v_timezone) then
    v_timezone:='UTC';
  end if;

  insert into public.profiles(
    id,username,birthday_month,birthday_day,birthday_year,birthday_timezone
  ) values (
    new.id,v_username,v_month,v_day,v_year,v_timezone
  );

  return new;
end;
$function$
;
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
$function$
;
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
$function$
;
