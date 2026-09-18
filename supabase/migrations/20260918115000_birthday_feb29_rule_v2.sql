create or replace function public.birthday_matches_local_date_v1(
  p_birth_month integer,
  p_birth_day integer,
  p_local_date date
)
returns boolean
language sql
immutable
set search_path=public,pg_temp
as $function$
  select
    (
      extract(month from p_local_date)::integer=p_birth_month
      and extract(day from p_local_date)::integer=p_birth_day
    )
    or
    (
      p_birth_month=2
      and p_birth_day=29
      and not (
        extract(year from p_local_date)::integer%400=0
        or (
          extract(year from p_local_date)::integer%4=0
          and extract(year from p_local_date)::integer%100<>0
        )
      )
      and extract(month from p_local_date)::integer=2
      and extract(day from p_local_date)::integer=28
    );
$function$;

revoke all on function public.birthday_matches_local_date_v1(integer,integer,date) from public,anon,authenticated;

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

revoke all on function public.process_real_birthday_rewards_v1() from public,anon,authenticated;
