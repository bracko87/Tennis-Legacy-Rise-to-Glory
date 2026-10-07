-- Persistent pre-launch tutorial progress for Tennis Legacy.
-- Existing human players receive an "available" tutorial that they may start from Help/Settings.
-- Newly created human players receive an active tutorial automatically.

create table if not exists public.player_tutorial_progress (
  player_id uuid primary key references public.players(id) on delete cascade,
  tutorial_version text not null default 'launch-v1',
  status text not null default 'active'
    check (status in ('available','active','paused','completed','skipped')),
  current_step_id text,
  completed_step_ids text[] not null default '{}'::text[],
  locale text not null default 'en',
  started_at timestamptz,
  completed_at timestamptz,
  skipped_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_player_tutorial_progress_status
  on public.player_tutorial_progress(status);

alter table public.player_tutorial_progress enable row level security;

drop policy if exists player_tutorial_progress_select_own on public.player_tutorial_progress;
create policy player_tutorial_progress_select_own
on public.player_tutorial_progress
for select
to authenticated
using (
  exists (
    select 1
    from public.players p
    where p.id=player_tutorial_progress.player_id
      and p.owner_user_id=auth.uid()
  )
);

drop policy if exists player_tutorial_progress_insert_own on public.player_tutorial_progress;
create policy player_tutorial_progress_insert_own
on public.player_tutorial_progress
for insert
to authenticated
with check (
  exists (
    select 1
    from public.players p
    where p.id=player_tutorial_progress.player_id
      and p.owner_user_id=auth.uid()
      and p.player_type='human'
  )
);

drop policy if exists player_tutorial_progress_update_own on public.player_tutorial_progress;
create policy player_tutorial_progress_update_own
on public.player_tutorial_progress
for update
to authenticated
using (
  exists (
    select 1
    from public.players p
    where p.id=player_tutorial_progress.player_id
      and p.owner_user_id=auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.players p
    where p.id=player_tutorial_progress.player_id
      and p.owner_user_id=auth.uid()
  )
);

insert into public.player_tutorial_progress (
  player_id,tutorial_version,status,current_step_id,locale,updated_at
)
select
  p.id,'launch-v1','available',null,'en',now()
from public.players p
where p.player_type='human'
  and p.owner_user_id is not null
on conflict (player_id) do nothing;

create or replace function public.initialize_player_tutorial_progress_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.player_type='human' and new.owner_user_id is not null then
    insert into public.player_tutorial_progress (
      player_id,tutorial_version,status,current_step_id,locale,started_at,updated_at
    )
    values (
      new.id,'launch-v1','active','welcome.overview','en',now(),now()
    )
    on conflict (player_id) do nothing;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_initialize_player_tutorial_progress_v1 on public.players;
create trigger trg_initialize_player_tutorial_progress_v1
after insert on public.players
for each row
execute function public.initialize_player_tutorial_progress_v1();

revoke all on function public.initialize_player_tutorial_progress_v1() from public;
revoke all on function public.initialize_player_tutorial_progress_v1() from anon;
revoke all on function public.initialize_player_tutorial_progress_v1() from authenticated;
