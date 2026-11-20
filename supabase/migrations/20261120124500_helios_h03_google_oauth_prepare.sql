-- Project Helios H03 — Google OAuth preparation only; OFF until provider verified.
-- A fail-closed, server-controlled switch prevents rendering unconfigured OAuth.
ALTER TABLE public.registration_control
ADD COLUMN IF NOT EXISTS google_oauth_enabled boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.get_public_google_oauth_status_v1()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $google$
  SELECT coalesce(
    (SELECT google_oauth_enabled FROM public.registration_control WHERE singleton_id=true),
    false
  );
$google$;
REVOKE ALL ON FUNCTION public.get_public_google_oauth_status_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_google_oauth_status_v1() TO anon, authenticated;

-- Auth.users trigger: for first-time Google accounts only. Existing
-- auth.users identities are automatically linked by the provider.
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
  if v_username='' and new.raw_app_meta_data->>'provider'='google' then
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
