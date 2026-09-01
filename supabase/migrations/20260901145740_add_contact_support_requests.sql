create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  account_email text not null,
  player_name text,
  world text,
  country_code text,
  category text not null,
  subject text not null,
  message text not null,
  page_url text,
  status text not null default 'new' check (status in ('new','in_progress','resolved','closed')),
  created_at timestamptz not null default now()
);

alter table public.contact_requests enable row level security;

revoke all on public.contact_requests from anon, authenticated;
grant select on public.contact_requests to authenticated;

create policy "Users can view own contact requests"
on public.contact_requests
for select
to authenticated
using (user_id = auth.uid());

create or replace function public.submit_contact_request_v1(
  p_category text,
  p_subject text,
  p_message text,
  p_page_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_player public.players%rowtype;
  v_request_id uuid;
  v_category text := trim(coalesce(p_category, ''));
  v_subject text := trim(coalesce(p_subject, ''));
  v_message text := trim(coalesce(p_message, ''));
  v_page_url text := nullif(trim(coalesce(p_page_url, '')), '');
begin
  if v_user_id is null then
    raise exception 'You must be signed in to contact support.';
  end if;

  select email into v_email from auth.users where id = v_user_id;
  if v_email is null or v_email = '' then
    raise exception 'No account email is available for this user.';
  end if;

  if v_category not in ('Account', 'Technical issue', 'Bug report', 'Billing / purchase', 'Feedback', 'Other') then
    raise exception 'Choose a valid support category.';
  end if;

  if char_length(v_subject) < 3 or char_length(v_subject) > 160 then
    raise exception 'Subject must be between 3 and 160 characters.';
  end if;

  if char_length(v_message) < 10 or char_length(v_message) > 5000 then
    raise exception 'Message must be between 10 and 5000 characters.';
  end if;

  if v_page_url is not null and char_length(v_page_url) > 500 then
    raise exception 'Page URL is too long.';
  end if;

  if (
    select count(*)
    from public.contact_requests
    where user_id = v_user_id
      and created_at > now() - interval '1 hour'
  ) >= 5 then
    raise exception 'Too many support requests. Please wait before sending another message.';
  end if;

  select * into v_player
  from public.players
  where owner_user_id = v_user_id
  limit 1;

  insert into public.contact_requests (
    user_id,
    player_id,
    account_email,
    player_name,
    world,
    country_code,
    category,
    subject,
    message,
    page_url
  ) values (
    v_user_id,
    v_player.id,
    nullif(v_email, ''),
    case when v_player.id is null then null else trim(v_player.first_name || ' ' || v_player.last_name) end,
    v_player.world,
    v_player.country_code,
    v_category,
    v_subject,
    v_message,
    v_page_url
  ) returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.submit_contact_request_v1(text,text,text,text) from public, anon;
grant execute on function public.submit_contact_request_v1(text,text,text,text) to authenticated;
