-- Project Helios H01: safe anonymous registration preparation, DISABLED in production.
-- Postgres auth.users trigger blocks new anonymous identities while guest_test_enabled=false.
-- Existing real-account signup, Google login, paid currencies and game clock unchanged.
CREATE OR REPLACE FUNCTION public.enforce_public_registration_gate_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_signup_enabled boolean:=false;
  v_admin_override boolean:=false;
  v_guest_enabled boolean:=false;
begin
  select rc.public_signup_enabled
    into v_signup_enabled
  from public.registration_control rc
  where rc.singleton_id=true;

  -- Anonymous Auth identities are a separate, controlled signup class.
  -- Even if ordinary public registration is open, Guest Mode must explicitly
  -- be enabled before any anonymous identity can be created.
  if coalesce(new.is_anonymous,false) then
    select coalesce(rc.guest_test_enabled,false) into v_guest_enabled
      from public.registration_control rc where rc.singleton_id=true;
    if not v_guest_enabled then
      raise exception using errcode='P0001',
        message='Test player registration is not available.';
    end if;
    return new;
  end if;

  v_admin_override :=
    coalesce(new.raw_app_meta_data->>'registration_override','false')='true';

  if coalesce(v_signup_enabled,false) or v_admin_override then
    return new;
  end if;

  raise exception using
    errcode='P0001',
    message='Registration is temporarily closed.';
end;
$function$
;
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

  -- New Google identities do not include an in-game username.
  if v_username='' and coalesce(new.is_anonymous,false) then
    -- Anonymous accounts have no signup form; use a stable 22-char handle.
    v_username:='guest_'||left(replace(new.id::text,'-',''),16);
  elsif v_username='' and new.raw_app_meta_data->>'provider'='google' then
    v_username:='google_'||left(replace(new.id::text,'-',''),16);
  end if;
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
CREATE OR REPLACE FUNCTION public.grant_new_career_starting_coins_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_balance bigint;
begin
  if p_user_id is null then
    return jsonb_build_object('status','skipped','reason','missing_user');
  end if;

  -- Anonymous users receive their own separate seven-day trial later.
  -- Do not allow temporary identities to farm permanent-account signup coins.
  if exists (select 1 from auth.users u where u.id=p_user_id and u.is_anonymous) then
    return jsonb_build_object('status','skipped','reason','guest_identity_no_signup_coins');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('new-career-starting-coins:'||p_user_id::text,0));

  if exists(
    select 1
    from public.coin_ledger
    where user_id=p_user_id
      and entry_type='signup_reward'
      and reference_id='new-career-starting-coins-v1'
  ) then
    select coins_balance into v_balance
    from public.user_wallets
    where user_id=p_user_id;

    return jsonb_build_object(
      'status','already_granted',
      'amount',20,
      'balance_after',coalesce(v_balance,0)
    );
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

  insert into public.coin_ledger(
    user_id,amount,balance_after,entry_type,description,reference_id
  ) values(
    p_user_id,20,v_balance,'signup_reward',
    'New career starting Coins',
    'new-career-starting-coins-v1'
  );

  return jsonb_build_object(
    'status','granted',
    'amount',20,
    'balance_after',v_balance
  );
exception when unique_violation then
  select coins_balance into v_balance
  from public.user_wallets
  where user_id=p_user_id;
  return jsonb_build_object('status','already_granted','amount',20,'balance_after',coalesce(v_balance,0));
end;
$function$
;
CREATE OR REPLACE FUNCTION public.handle_referral_signup_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_code text;
  v_referrer uuid;
  v_browser text;
begin
  -- Temporary identities cannot claim new-account referral bonuses.
  if coalesce(new.is_anonymous,false) then return new; end if;
  v_code := upper(btrim(coalesce(new.raw_user_meta_data->>'referral_code','')));
  v_browser := nullif(btrim(coalesce(new.raw_user_meta_data->>'referral_browser_hash','')),'');
  if v_code = '' then return new; end if;
  select user_id into v_referrer from public.referral_codes where code=v_code and revoked_at is null;
  if v_referrer is null or v_referrer=new.id then return new; end if;
  insert into public.referrals(referrer_user_id,referred_user_id,referral_code,browser_hash,status,registered_at)
  values(v_referrer,new.id,v_code,v_browser,'registered',now())
  on conflict (referred_user_id) do nothing;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.handle_registration_invite_bonus_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_token text;
  v_invite public.registration_invites%rowtype;
  v_balance bigint;
begin
  -- An anonymous identity must not redeem a permanent registration invite.
  if coalesce(new.is_anonymous,false) then return new; end if;
  v_token := btrim(coalesce(new.raw_user_meta_data ->> 'registration_invite_token',''));

  if v_token = '' then
    return new;
  end if;

  select ri.*
  into v_invite
  from public.registration_invites ri
  where ri.token_hash = encode(extensions.digest(v_token, 'sha256'), 'hex')
    and ri.claimed_at is null
    and ri.expires_at > now()
  for update;

  if not found then
    raise exception 'Registration invitation is invalid or expired.';
  end if;

  if lower(btrim(v_invite.email)) <> lower(btrim(coalesce(new.email,''))) then
    raise exception 'Registration invitation email does not match.';
  end if;

  insert into public.user_wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  if v_invite.bonus_coins > 0 then
    update public.user_wallets
    set
      coins_balance = coins_balance + v_invite.bonus_coins,
      lifetime_coins_earned = lifetime_coins_earned + v_invite.bonus_coins,
      updated_at = now()
    where user_id = new.id
    returning coins_balance into v_balance;

    insert into public.coin_ledger (
      user_id,
      amount,
      balance_after,
      entry_type,
      description,
      reference_id
    ) values (
      new.id,
      v_invite.bonus_coins,
      v_balance,
      'promo',
      'Admin registration invitation bonus',
      'registration_invite:' || v_invite.id::text
    );
  end if;

  update public.registration_invites
  set
    claimed_user_id = new.id,
    claimed_at = now()
  where id = v_invite.id;

  return new;
end;
$function$
;
