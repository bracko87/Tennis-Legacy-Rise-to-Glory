alter table public.profiles
  add column if not exists birthday_timezone text not null default 'UTC';

comment on column public.profiles.birthday_timezone is
  'IANA timezone captured at registration for real-world birthday processing. UTC is the fallback for legacy accounts.';

alter table public.coin_ledger
  drop constraint if exists coin_ledger_entry_type_check;

alter table public.coin_ledger
  add constraint coin_ledger_entry_type_check
  check (entry_type = any (array[
    'premium_reward'::text,
    'coin_purchase'::text,
    'spend'::text,
    'admin_adjustment'::text,
    'signup_reward'::text,
    'refund'::text,
    'promo'::text,
    'referral_reward'::text,
    'birthday_reward'::text
  ]));

create unique index if not exists coin_ledger_birthday_reference_uidx
  on public.coin_ledger(reference_id)
  where entry_type='birthday_reward' and reference_id is not null;

create table if not exists public.birthday_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_year integer not null check (reward_year between 2000 and 9999),
  reward_amount integer not null default 20 check (reward_amount = 20),
  local_birthday_date date not null,
  processing_timezone text not null,
  awarded_at timestamptz not null default now(),
  coin_ledger_id uuid unique references public.coin_ledger(id) on delete restrict,
  notification_id uuid references public.user_notifications(id) on delete set null,
  email_outbox_id uuid,
  email_sent_at timestamptz,
  notification_error text,
  email_queue_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,reward_year)
);

create index if not exists birthday_rewards_user_year_idx
  on public.birthday_rewards(user_id,reward_year desc);

create table if not exists public.birthday_email_outbox (
  id uuid primary key default gen_random_uuid(),
  birthday_reward_id uuid not null unique references public.birthday_rewards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  recipient_email text not null,
  subject text not null,
  text_body text not null,
  html_body text not null,
  status text not null default 'pending' check (status in ('pending','sending','sent','failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  provider_message_id text,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.birthday_rewards
  drop constraint if exists birthday_rewards_email_outbox_id_fkey;

alter table public.birthday_rewards
  add constraint birthday_rewards_email_outbox_id_fkey
  foreign key (email_outbox_id) references public.birthday_email_outbox(id) on delete set null;

create index if not exists birthday_email_outbox_pending_idx
  on public.birthday_email_outbox(status,next_attempt_at)
  where status in ('pending','failed');

alter table public.birthday_rewards enable row level security;
alter table public.birthday_email_outbox enable row level security;

revoke all on public.birthday_rewards from anon, authenticated;
revoke all on public.birthday_email_outbox from anon, authenticated;
grant select on public.birthday_rewards to authenticated;

drop policy if exists birthday_rewards_select_own on public.birthday_rewards;
create policy birthday_rewards_select_own
  on public.birthday_rewards
  for select
  to authenticated
  using (auth.uid()=user_id);

insert into public.notification_catalog(
  code,category,label,reason,
  trigger_event,trigger_condition,trigger_mechanism,source_name,
  title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
) values (
  'account.birthday_gift',
  'account',
  'Birthday gift',
  'Celebrate the account holder birthday and confirm the annual 20-Coin gift.',
  'The account holder reaches their stored real-world birthday.',
  'Stored birthday matches the current date in the account birthday timezone and no reward exists for that calendar year.',
  'scheduled_job',
  'public.process_real_birthday_rewards_v1',
  'Happy Birthday! 🎂',
  'We wish you a fantastic birthday! As a birthday gift from Tennis Legacy, we added 20 Coins to your account.',
  '/game',
  'success',
  true,true,false,false,true
)
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  severity=excluded.severity,
  default_in_app=excluded.default_in_app,
  default_email=excluded.default_email,
  default_push=excluded.default_push,
  is_user_configurable=excluded.is_user_configurable,
  is_active=excluded.is_active,
  updated_at=now();

create or replace function public.prevent_profile_birthday_change()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  if new.birthday_month is distinct from old.birthday_month
     or new.birthday_day is distinct from old.birthday_day
     or new.birthday_year is distinct from old.birthday_year
     or new.birthday_timezone is distinct from old.birthday_timezone then
    raise exception 'Birthday cannot be changed after registration.';
  end if;
  return new;
end;
$function$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
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
  if v_month is null or v_month not between 1 and 12 then
    raise exception 'Invalid birthday month.';
  end if;
  if v_day is null or v_day not between 1 and 31 then
    raise exception 'Invalid birthday day.';
  end if;
  if v_year is null or v_year < 1900 or v_year > extract(year from current_date)::integer then
    raise exception 'A valid birthday year is required.';
  end if;

  begin
    v_birth_date:=make_date(v_year,v_month,v_day);
  exception when others then
    raise exception 'Invalid birthday date.';
  end;

  if v_birth_date>current_date then
    raise exception 'Birthday cannot be in the future.';
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
$function$;

create or replace function public.ensure_birthday_reward_followups_v1(p_reward_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_reward public.birthday_rewards%rowtype;
  v_player_id uuid;
  v_notification_id uuid;
  v_email text;
  v_outbox_id uuid;
begin
  select * into v_reward
  from public.birthday_rewards
  where id=p_reward_id
  for update;

  if not found then
    return jsonb_build_object('status','missing_reward');
  end if;

  select p.id into v_player_id
  from public.players p
  where p.owner_user_id=v_reward.user_id
    and p.player_type='human'
  order by p.created_at desc
  limit 1;

  if v_reward.notification_id is null then
    begin
      insert into public.user_notifications(
        user_id,player_id,notification_code,title,message,severity,route,payload,event_key
      ) values (
        v_reward.user_id,
        v_player_id,
        'account.birthday_gift',
        'Happy Birthday! 🎂',
        'We wish you a fantastic birthday! As a birthday gift from Tennis Legacy, we''ve added 20 Coins to your account.',
        'success',
        '/game',
        jsonb_build_object(
          'reward_amount',20,
          'reward_year',v_reward.reward_year,
          'birthday_reward_id',v_reward.id,
          'coins_added',true
        ),
        format('birthday_reward:%s',v_reward.reward_year)
      )
      on conflict(user_id,event_key) where event_key is not null
      do update set event_key=excluded.event_key
      returning id into v_notification_id;

      update public.birthday_rewards
      set notification_id=v_notification_id,
          notification_error=null,
          updated_at=now()
      where id=v_reward.id;
    exception when others then
      update public.birthday_rewards
      set notification_error=sqlerrm,updated_at=now()
      where id=v_reward.id;
    end;
  end if;

  if v_reward.email_outbox_id is null then
    begin
      select u.email into v_email
      from auth.users u
      where u.id=v_reward.user_id;

      if v_email is not null and btrim(v_email)<>'' then
        insert into public.birthday_email_outbox(
          birthday_reward_id,user_id,recipient_email,subject,text_body,html_body
        ) values (
          v_reward.id,
          v_reward.user_id,
          v_email,
          'Happy Birthday from Tennis Legacy! 🎂',
          'Happy Birthday! We wish you a fantastic birthday. As a birthday gift from Tennis Legacy, 20 Coins have already been added to your account. Log in and continue your journey to tennis greatness!',
          '<!doctype html><html><body style="margin:0;background:#f3f7fa;font-family:Arial,sans-serif;color:#173149"><div style="max-width:620px;margin:0 auto;padding:32px 18px"><div style="background:#071d2d;color:#fff;padding:22px 26px;border-radius:14px 14px 0 0"><div style="font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:#8fc7ef">Tennis Legacy</div><div style="font-size:26px;font-weight:700;margin-top:5px">Rise to Glory</div></div><div style="background:#fff;border:1px solid #dfe8ee;border-top:0;padding:30px 26px;border-radius:0 0 14px 14px"><h1 style="margin:0 0 14px;font-size:28px">Happy Birthday! 🎂</h1><p style="font-size:16px;line-height:1.6">We wish you a fantastic birthday!</p><div style="margin:24px 0;padding:18px;border-radius:10px;background:#eef9f3;border:1px solid #cce9da"><div style="font-size:12px;text-transform:uppercase;letter-spacing:.08em;color:#34755a;font-weight:700">Birthday Gift</div><div style="font-size:30px;font-weight:800;color:#148551;margin-top:4px">+20 Coins</div><p style="margin:8px 0 0;font-size:14px;color:#526b7d">The Coins have already been added to your Tennis Legacy account. No claim is required.</p></div><p style="font-size:16px;line-height:1.6">Come back to the game and continue building your tennis legacy.</p><p style="margin:26px 0 0;font-size:14px;color:#708496">— The Tennis Legacy Team</p></div></div></body></html>'
        )
        on conflict(birthday_reward_id) do update
          set recipient_email=excluded.recipient_email,
              subject=excluded.subject,
              text_body=excluded.text_body,
              html_body=excluded.html_body,
              updated_at=now()
        returning id into v_outbox_id;

        update public.birthday_rewards
        set email_outbox_id=v_outbox_id,
            email_queue_error=null,
            updated_at=now()
        where id=v_reward.id;
      end if;
    exception when others then
      update public.birthday_rewards
      set email_queue_error=sqlerrm,updated_at=now()
      where id=v_reward.id;
    end;
  end if;

  return jsonb_build_object('status','ok','reward_id',v_reward.id);
end;
$function$;

revoke all on function public.ensure_birthday_reward_followups_v1(uuid) from public,anon,authenticated;

create or replace function public.award_birthday_reward_v1(
  p_user_id uuid,
  p_reward_year integer,
  p_local_birthday_date date,
  p_timezone text
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_reward_id uuid;
  v_balance bigint;
  v_ledger_id uuid;
  v_reference text;
begin
  if p_reward_year is null or p_local_birthday_date is null then
    raise exception 'Birthday reward date is required.';
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

revoke all on function public.award_birthday_reward_v1(uuid,integer,date,text) from public,anon,authenticated;

create or replace function public.process_real_birthday_rewards_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  r record;
  v_local_date date;
  v_year integer;
  v_is_leap boolean;
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
  loop
    begin
      v_local_date:=(now() at time zone r.birthday_timezone)::date;
    exception when others then
      v_local_date:=(now() at time zone 'UTC')::date;
    end;

    v_year:=extract(year from v_local_date)::integer;
    v_is_leap:=(v_year%400=0 or (v_year%4=0 and v_year%100<>0));

    if (
      extract(month from v_local_date)::integer=r.birthday_month
      and extract(day from v_local_date)::integer=r.birthday_day
    ) or (
      r.birthday_month=2
      and r.birthday_day=29
      and not v_is_leap
      and extract(month from v_local_date)::integer=2
      and extract(day from v_local_date)::integer=28
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

revoke all on function public.process_real_birthday_rewards_v1() from public,anon,authenticated;

do $$
declare v_jobid bigint;
begin
  select jobid into v_jobid
  from cron.job
  where jobname='tennis-birthday-rewards-v1'
  limit 1;
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end $$;

select cron.schedule(
  'tennis-birthday-rewards-v1',
  '12 * * * *',
  $$select public.process_real_birthday_rewards_v1();$$
);
