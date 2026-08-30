create table if not exists public.player_avatar_reservations (
  avatar_path text primary key,
  player_id uuid not null unique references public.players(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.player_avatar_reservations enable row level security;

drop policy if exists player_avatar_reservations_authenticated_read on public.player_avatar_reservations;
create policy player_avatar_reservations_authenticated_read
  on public.player_avatar_reservations
  for select
  to authenticated
  using (true);

revoke all on table public.player_avatar_reservations from public, anon, authenticated;
grant select (avatar_path) on public.player_avatar_reservations to authenticated;

insert into public.player_avatar_reservations (avatar_path, player_id)
select p.image_path, p.id
from public.players p
where p.image_path is not null
  and (
    p.image_path like 'ATP Avatars/%'
    or p.image_path like 'WTA Avatars/%'
  )
on conflict do nothing;

create or replace function public.sync_player_avatar_reservation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.player_avatar_reservations
    where player_id = old.id;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.image_path is distinct from new.image_path then
    delete from public.player_avatar_reservations
    where player_id = old.id;
  end if;

  if new.image_path is not null
     and (
       new.image_path like 'ATP Avatars/%'
       or new.image_path like 'WTA Avatars/%'
     ) then
    insert into public.player_avatar_reservations (avatar_path, player_id)
    values (new.image_path, new.id)
    on conflict (player_id) do update
      set avatar_path = excluded.avatar_path,
          created_at = now();
  end if;

  return new;
end;
$$;

revoke all on function public.sync_player_avatar_reservation() from public, anon, authenticated;

drop trigger if exists sync_player_avatar_reservation on public.players;
create trigger sync_player_avatar_reservation
after insert or update of image_path or delete on public.players
for each row execute function public.sync_player_avatar_reservation();

create or replace function public.get_player_avatar_catalog(p_world text)
returns table(path text, is_available boolean)
language sql
stable
security invoker
set search_path = pg_catalog, public, storage
as $$
  select
    o.name::text as path,
    not exists (
      select 1
      from public.player_avatar_reservations r
      where r.avatar_path = o.name
    ) as is_available
  from storage.objects o
  where p_world in ('ATP', 'WTA')
    and o.bucket_id = 'Admin'
    and o.name like case
      when p_world = 'ATP' then 'ATP Avatars/%'
      else 'WTA Avatars/%'
    end
    and lower(o.name) ~ '\.(png|jpg|jpeg|webp)$'
  order by o.name;
$$;

revoke all on function public.get_player_avatar_catalog(text) from public, anon;
grant execute on function public.get_player_avatar_catalog(text) to authenticated;
