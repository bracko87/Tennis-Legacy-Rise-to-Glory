create or replace function public.restart_tennis_legacy_account_v1()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  delete from public.players
  where owner_user_id = v_user_id;
end;
$$;

revoke all on function public.restart_tennis_legacy_account_v1() from public;
grant execute on function public.restart_tennis_legacy_account_v1() to authenticated;

create or replace function public.delete_tennis_legacy_account_v1()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  delete from auth.users
  where id = v_user_id;

  if not found then
    raise exception 'Account not found';
  end if;
end;
$$;

revoke all on function public.delete_tennis_legacy_account_v1() from public;
grant execute on function public.delete_tennis_legacy_account_v1() to authenticated;
