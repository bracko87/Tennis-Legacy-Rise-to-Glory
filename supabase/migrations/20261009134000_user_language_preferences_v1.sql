create table if not exists public.user_language_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  locale text not null default 'en' check (locale in ('en','sr','de','es','it','fr','ru','pt')),
  updated_at timestamptz not null default now()
);

alter table public.user_language_preferences enable row level security;

drop policy if exists "Users can read own language preference" on public.user_language_preferences;
create policy "Users can read own language preference"
on public.user_language_preferences
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert own language preference" on public.user_language_preferences;
create policy "Users can insert own language preference"
on public.user_language_preferences
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update own language preference" on public.user_language_preferences;
create policy "Users can update own language preference"
on public.user_language_preferences
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select,insert,update on public.user_language_preferences to authenticated;
