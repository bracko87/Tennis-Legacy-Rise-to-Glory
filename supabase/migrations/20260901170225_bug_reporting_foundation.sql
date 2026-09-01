create table if not exists public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid null references auth.users(id) on delete set null,
  player_id uuid null references public.players(id) on delete set null,
  page_label text not null,
  page_path text not null,
  page_url text null,
  bug_type text not null default 'other' check (bug_type in ('ui','gameplay','performance','data','other')),
  description text not null check (char_length(description) between 10 and 4000),
  expected_result text null,
  actual_result text null,
  steps_to_reproduce text null,
  severity text not null default 'medium' check (severity in ('low','medium','high')),
  browser text null,
  viewport text null,
  screenshot_path text null,
  screenshot_url text null,
  reported_from text not null default 'sidebar',
  status text not null default 'open' check (status in ('open','reviewing','resolved','closed'))
);

alter table public.bug_reports enable row level security;

revoke all on table public.bug_reports from anon;
grant insert on table public.bug_reports to authenticated;

drop policy if exists "authenticated users can insert own bug reports" on public.bug_reports;
create policy "authenticated users can insert own bug reports"
on public.bug_reports
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and (
    player_id is null
    or exists (
      select 1 from public.players p
      where p.id = player_id
        and p.owner_user_id = (select auth.uid())
    )
  )
);

insert into storage.buckets (id, name, public)
values ('bug-report-screenshots', 'bug-report-screenshots', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "authenticated users can upload own bug screenshots" on storage.objects;
create policy "authenticated users can upload own bug screenshots"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'bug-report-screenshots'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
