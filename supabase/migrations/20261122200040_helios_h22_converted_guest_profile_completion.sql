-- H22: guest-to-permanent profile completion, deployed and verified on live Supabase.
create table if not exists control_center_private.tennis_converted_profile_completion_v1 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username_confirmed_at timestamptz,
  reminder_dismissed_at timestamptz,
  updated_at timestamptz not null default clock_timestamp()
);
revoke all on control_center_private.tennis_converted_profile_completion_v1 from public, anon, authenticated;

CREATE OR REPLACE FUNCTION control_center_private.tennis_converted_profile_guard_username_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.username is distinct from old.username and exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=old.id and t.converted_at is not null
      and u.is_anonymous is false and u.deleted_at is null
  ) and exists (
    select 1 from control_center_private.tennis_converted_profile_completion_v1 c
    where c.user_id=old.id and c.username_confirmed_at is not null
  ) then
    raise exception 'Converted account username has already been confirmed.' using errcode='42501';
  end if;
  return new;
end;
$function$


CREATE OR REPLACE FUNCTION control_center_private.tennis_converted_profile_track_username_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.username is distinct from old.username and exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=new.id and t.converted_at is not null
      and u.is_anonymous is false and u.deleted_at is null
  ) then
    insert into control_center_private.tennis_converted_profile_completion_v1(user_id,username_confirmed_at)
    values (new.id,clock_timestamp())
    on conflict(user_id) do update
    set username_confirmed_at=coalesce(control_center_private.tennis_converted_profile_completion_v1.username_confirmed_at,excluded.username_confirmed_at),
        updated_at=clock_timestamp();
  end if;
  return null;
end;
$function$


CREATE OR REPLACE FUNCTION public.assign_my_tennis_converted_home_city_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid:=auth.uid(); v_player uuid; v_country text; v_existing text; v_city text;
begin
  if v_id is null or not exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=v_id and t.converted_at is not null and u.is_anonymous is false and u.deleted_at is null
  ) then raise exception 'Converted account required.' using errcode='42501'; end if;
  select id,country_code,home_city into v_player,v_country,v_existing
  from public.players where owner_user_id=v_id and player_type='human' for update;
  if v_player is null then raise exception 'Player not found.' using errcode='22023'; end if;
  if nullif(pg_catalog.btrim(coalesce(v_existing,'')),'') is not null then
    return jsonb_build_object('status','already_set','home_city',v_existing);
  end if;
  select h.city into v_city from public.player_home_city_options h
  where h.country_code=v_country and h.is_active
  order by pg_catalog.md5(v_player::text||':'||h.city),h.city limit 1;
  if v_city is null then
    return jsonb_build_object('status','no_available_city','home_city',null);
  end if;
  update public.players set home_city=v_city,updated_at=now() where id=v_player;
  return jsonb_build_object('status','assigned','home_city',v_city);
end;
$function$


CREATE OR REPLACE FUNCTION public.dismiss_my_tennis_converted_profile_reminder_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid:=auth.uid(); v_city jsonb;
begin
  if v_id is null or not exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=v_id and t.converted_at is not null and u.is_anonymous is false and u.deleted_at is null
  ) then raise exception 'Converted account required.' using errcode='42501'; end if;
  v_city:=public.assign_my_tennis_converted_home_city_v1();
  insert into control_center_private.tennis_converted_profile_completion_v1(user_id,reminder_dismissed_at)
  values(v_id,clock_timestamp())
  on conflict(user_id) do update set reminder_dismissed_at=coalesce(control_center_private.tennis_converted_profile_completion_v1.reminder_dismissed_at,excluded.reminder_dismissed_at),updated_at=clock_timestamp();
  return jsonb_build_object('status','dismissed','city',v_city);
end;
$function$


CREATE OR REPLACE FUNCTION public.get_my_tennis_converted_profile_completion_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid:=auth.uid(); v_username text; v_month integer; v_day integer;
v_city text; v_country text; v_confirmed boolean;
begin
  if v_id is null then raise exception 'Authentication required.' using errcode='42501'; end if;
  if not exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=v_id and t.converted_at is not null
      and u.is_anonymous is false and u.deleted_at is null
  ) then return jsonb_build_object('eligible',false); end if;
  select p.username,p.birthday_month,p.birthday_day into v_username,v_month,v_day
  from public.profiles p where p.id=v_id;
  select pl.home_city,pl.country_code into v_city,v_country
  from public.players pl where pl.owner_user_id=v_id and pl.player_type='human';
  select c.username_confirmed_at is not null into v_confirmed
  from control_center_private.tennis_converted_profile_completion_v1 c where c.user_id=v_id;
  return jsonb_build_object(
    'eligible',true,
    'username',v_username,
    'username_confirmed',coalesce(v_confirmed,false),
    'birthday_set',v_month is not null and v_day is not null,
    'home_city',v_city,'country_code',v_country,
    'dismissed',coalesce((
       select c.reminder_dismissed_at is not null
       from control_center_private.tennis_converted_profile_completion_v1 c where c.user_id=v_id
    ),false)
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.prevent_profile_birthday_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_birth_date date;
begin
  if new.birthday_month is distinct from old.birthday_month
     or new.birthday_day is distinct from old.birthday_day
     or new.birthday_year is distinct from old.birthday_year
     or new.birthday_timezone is distinct from old.birthday_timezone then

    -- The sole exception: a registered account converted from a real guest
    -- may fill a completely blank birthday exactly once.
    if old.birthday_month is not null or old.birthday_day is not null
       or old.birthday_year is not null
       or new.birthday_month is null or new.birthday_day is null
       or auth.uid() is distinct from old.id
       or not exists (
         select 1 from control_center_private.tennis_guest_trials_v1 t
         join auth.users u on u.id=t.user_id
         where t.user_id=old.id and t.converted_at is not null
           and u.is_anonymous is false and u.deleted_at is null
       ) then
      raise exception 'Birthday cannot be changed after it has been saved.' using errcode='42501';
    end if;
    if new.birthday_month not between 1 and 12 or new.birthday_day not between 1 and 31 then
      raise exception 'Invalid birthday.' using errcode='22023';
    end if;
    begin
      v_birth_date:=pg_catalog.make_date(coalesce(new.birthday_year::integer,2000),new.birthday_month::integer,new.birthday_day::integer);
    exception when others then
      raise exception 'Invalid birthday date.' using errcode='22023';
    end;
    if new.birthday_year is not null and v_birth_date>current_date then
      raise exception 'Birthday cannot be in the future.' using errcode='22023';
    end if;
    if new.birthday_timezone is null or not exists (
       select 1 from pg_catalog.pg_timezone_names z where z.name=new.birthday_timezone
    ) then
      raise exception 'Invalid birthday timezone.' using errcode='22023';
    end if;
  end if;
  return new;
end;
$function$


CREATE OR REPLACE FUNCTION public.set_my_tennis_converted_birthday_v1(p_month integer, p_day integer, p_year integer DEFAULT NULL::integer, p_timezone text DEFAULT 'UTC'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid:=auth.uid(); v_birth date; v_tz text:=coalesce(nullif(p_timezone,''),'UTC');
begin
  if v_id is null or not exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=v_id and t.converted_at is not null and u.is_anonymous is false and u.deleted_at is null
  ) then raise exception 'Only a converted permanent account can add a missing birthday.' using errcode='42501'; end if;
  if p_month not between 1 and 12 or p_day not between 1 and 31 or p_year is not null and p_year not between 1900 and extract(year from current_date)::integer then
    raise exception 'Invalid birthday.' using errcode='22023'; end if;
  begin v_birth:=pg_catalog.make_date(coalesce(p_year,2000),p_month,p_day);
  exception when others then raise exception 'Invalid birthday date.' using errcode='22023'; end;
  if p_year is not null and v_birth>current_date then raise exception 'Birthday cannot be in the future.' using errcode='22023'; end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=v_tz) then
    raise exception 'Invalid timezone.' using errcode='22023'; end if;
  update public.profiles set birthday_month=p_month,birthday_day=p_day,birthday_year=p_year,birthday_timezone=v_tz
  where id=v_id and birthday_month is null and birthday_day is null and birthday_year is null;
  if not found then raise exception 'Birthday was already saved and cannot be changed.' using errcode='42501'; end if;
  return jsonb_build_object('status','saved','birthday_set',true);
end;
$function$


CREATE OR REPLACE FUNCTION public.set_my_tennis_converted_username_v1(p_username text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid:=auth.uid(); v_name text:=pg_catalog.btrim(coalesce(p_username,'')); v_old text;
begin
  if v_id is null or not exists (
    select 1 from control_center_private.tennis_guest_trials_v1 t
    join auth.users u on u.id=t.user_id
    where t.user_id=v_id and t.converted_at is not null and u.is_anonymous is false and u.deleted_at is null
  ) then raise exception 'Only a converted permanent account can complete its username.' using errcode='42501'; end if;
  if v_name !~ '^[A-Za-z0-9_.-]{3,24}$' then
    raise exception 'Username must be 3–24 characters: letters, numbers, underscore, period or hyphen.' using errcode='22023';
  end if;
  select username into strict v_old from public.profiles where id=v_id for update;
  if exists (select 1 from control_center_private.tennis_converted_profile_completion_v1 where user_id=v_id and username_confirmed_at is not null) then
    raise exception 'Username was already confirmed.' using errcode='42501';
  end if;
  if v_old is distinct from v_name then
    update public.profiles set username=v_name where id=v_id;
  end if;
  insert into control_center_private.tennis_converted_profile_completion_v1(user_id,username_confirmed_at)
  values(v_id,clock_timestamp())
  on conflict(user_id) do update set username_confirmed_at=coalesce(control_center_private.tennis_converted_profile_completion_v1.username_confirmed_at,excluded.username_confirmed_at),updated_at=clock_timestamp();
  return jsonb_build_object('status','saved','username',v_name);
exception when unique_violation then
  raise exception 'That username is already taken.' using errcode='23505';
end;
$function$


drop trigger if exists tennis_converted_profile_guard_username_v1 on public.profiles;
CREATE TRIGGER tennis_converted_profile_guard_username_v1 BEFORE UPDATE OF username ON public.profiles FOR EACH ROW EXECUTE FUNCTION control_center_private.tennis_converted_profile_guard_username_v1();

drop trigger if exists tennis_converted_profile_track_username_v1 on public.profiles;
CREATE TRIGGER tennis_converted_profile_track_username_v1 AFTER UPDATE OF username ON public.profiles FOR EACH ROW EXECUTE FUNCTION control_center_private.tennis_converted_profile_track_username_v1();

revoke all on function control_center_private.tennis_converted_profile_guard_username_v1() from public,anon,authenticated;
revoke all on function control_center_private.tennis_converted_profile_track_username_v1() from public,anon,authenticated;
revoke all on function public.get_my_tennis_converted_profile_completion_v1() from public,anon,authenticated;
revoke all on function public.set_my_tennis_converted_username_v1(text) from public,anon,authenticated;
revoke all on function public.set_my_tennis_converted_birthday_v1(integer,integer,integer,text) from public,anon,authenticated;
revoke all on function public.assign_my_tennis_converted_home_city_v1() from public,anon,authenticated;
revoke all on function public.dismiss_my_tennis_converted_profile_reminder_v1() from public,anon,authenticated;
grant execute on function public.get_my_tennis_converted_profile_completion_v1(),public.set_my_tennis_converted_username_v1(text),
 public.set_my_tennis_converted_birthday_v1(integer,integer,integer,text),public.assign_my_tennis_converted_home_city_v1(),
 public.dismiss_my_tennis_converted_profile_reminder_v1() to authenticated;
