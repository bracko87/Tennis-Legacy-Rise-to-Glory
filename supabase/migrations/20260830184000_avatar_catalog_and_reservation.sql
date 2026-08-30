create unique index if not exists players_image_path_unique
  on public.players (image_path)
  where image_path is not null;

drop policy if exists admin_player_avatar_authenticated_read on storage.objects;
create policy admin_player_avatar_authenticated_read
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'Admin'
    and (
      name like 'ATP Avatars/%'
      or name like 'WTA Avatars/%'
    )
  );

create or replace function public.get_player_avatar_catalog(p_world text)
returns table(path text, is_available boolean)
language sql
stable
security definer
set search_path = pg_catalog, public, storage
as $$
  select
    o.name::text as path,
    not exists (
      select 1
      from public.players p
      where p.image_path = o.name
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

revoke all on function public.get_player_avatar_catalog(text) from public;
revoke all on function public.get_player_avatar_catalog(text) from anon;
grant execute on function public.get_player_avatar_catalog(text) to authenticated;
