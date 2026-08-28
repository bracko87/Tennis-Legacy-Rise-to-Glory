create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  birthday_month smallint not null,
  birthday_day smallint not null,
  birthday_year smallint null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format_check check (username ~ '^[A-Za-z0-9_.-]{3,24}$'),
  constraint profiles_birthday_month_check check (birthday_month between 1 and 12),
  constraint profiles_birthday_day_check check (birthday_day between 1 and 31),
  constraint profiles_birthday_year_check check (
    birthday_year is null
    or birthday_year between 1900 and extract(year from current_date)::int
  )
);

create unique index profiles_username_lower_unique
  on public.profiles (lower(username));

create table public.players (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references auth.users(id) on delete cascade,
  world text not null,
  first_name text not null,
  last_name text not null,
  country_code text not null,
  image_path text null,
  moderation_status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint players_world_check check (world in ('ATP', 'WTA')),
  constraint players_first_name_check check (char_length(btrim(first_name)) between 2 and 60),
  constraint players_last_name_check check (char_length(btrim(last_name)) between 2 and 60),
  constraint players_country_code_check check (country_code ~ '^[A-Z]{2}$'),
  constraint players_moderation_status_check check (
    moderation_status in ('pending', 'approved', 'rejected')
  )
);

alter table public.profiles enable row level security;
alter table public.players enable row level security;

revoke all on public.profiles from anon, authenticated;
revoke all on public.players from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (username, updated_at) on public.profiles to authenticated;

grant select on public.players to authenticated;
grant insert (
  owner_user_id,
  world,
  first_name,
  last_name,
  country_code,
  image_path
) on public.players to authenticated;
grant update (
  first_name,
  last_name,
  country_code,
  image_path,
  updated_at
) on public.players to authenticated;

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy players_select_own
  on public.players
  for select
  to authenticated
  using ((select auth.uid()) = owner_user_id);

create policy players_insert_own
  on public.players
  for insert
  to authenticated
  with check ((select auth.uid()) = owner_user_id);

create policy players_update_own
  on public.players
  for update
  to authenticated
  using ((select auth.uid()) = owner_user_id)
  with check ((select auth.uid()) = owner_user_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger players_set_updated_at
before update on public.players
for each row execute function public.set_updated_at();

create or replace function public.prevent_profile_birthday_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.birthday_month is distinct from old.birthday_month
     or new.birthday_day is distinct from old.birthday_day
     or new.birthday_year is distinct from old.birthday_year then
    raise exception 'Birthday cannot be changed after registration.';
  end if;
  return new;
end;
$$;

create trigger profiles_birthday_immutable
before update on public.profiles
for each row execute function public.prevent_profile_birthday_change();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text;
  v_month int;
  v_day int;
  v_year int;
  v_validation_year int;
begin
  v_username := btrim(coalesce(new.raw_user_meta_data ->> 'username', ''));
  v_month := nullif(new.raw_user_meta_data ->> 'birthday_month', '')::int;
  v_day := nullif(new.raw_user_meta_data ->> 'birthday_day', '')::int;
  v_year := nullif(new.raw_user_meta_data ->> 'birthday_year', '')::int;

  if v_username !~ '^[A-Za-z0-9_.-]{3,24}$' then
    raise exception 'Invalid username.';
  end if;

  if v_month is null or v_month not between 1 and 12 then
    raise exception 'Invalid birthday month.';
  end if;

  if v_day is null or v_day not between 1 and 31 then
    raise exception 'Invalid birthday day.';
  end if;

  if v_year is not null
     and (v_year < 1900 or v_year > extract(year from current_date)::int) then
    raise exception 'Invalid birthday year.';
  end if;

  v_validation_year := coalesce(v_year, 2000);

  begin
    perform make_date(v_validation_year, v_month, v_day);
  exception when others then
    raise exception 'Invalid birthday date.';
  end;

  insert into public.profiles (
    id,
    username,
    birthday_month,
    birthday_day,
    birthday_year
  ) values (
    new.id,
    v_username,
    v_month,
    v_day,
    v_year
  );

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

comment on table public.profiles is
  'Manager account profile data linked one-to-one with Supabase Auth users.';
comment on table public.players is
  'One Tennis Legacy player per authenticated manager account.';
