create or replace function public.handle_user_commerce()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.premium_memberships (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_commerce on auth.users;
create trigger on_auth_user_created_commerce
after insert on auth.users
for each row execute function public.handle_user_commerce();
