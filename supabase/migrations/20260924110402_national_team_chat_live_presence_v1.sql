
create table if not exists public.national_team_chat_presence (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  membership_id uuid not null references public.national_association_memberships(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_active_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(association_id,user_id)
);

create index if not exists national_team_chat_presence_active_idx
  on public.national_team_chat_presence(association_id,last_active_at desc);

alter table public.national_team_chat_presence enable row level security;

revoke all on table public.national_team_chat_presence from public,anon,authenticated;

create or replace function public.get_my_national_team_chat_presence_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  v_my record;
  v_participants jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select m.association_id
  into v_assoc
  from public.national_association_memberships m
  where m.user_id=v_uid
    and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_assoc is null then
    return jsonb_build_object(
      'is_member',false,
      'joined',false,
      'participants','[]'::jsonb
    );
  end if;

  select
    p.joined_at,
    p.last_active_at,
    p.last_active_at + interval '10 minutes' expires_at
  into v_my
  from public.national_team_chat_presence p
  where p.association_id=v_assoc
    and p.user_id=v_uid
    and p.last_active_at > now()-interval '10 minutes'
  limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'user_id',presence.user_id,
      'player_id',player.id,
      'player_name',trim(player.first_name||' '||player.last_name),
      'joined_at',presence.joined_at,
      'last_active_at',presence.last_active_at,
      'is_me',presence.user_id=v_uid
    )
    order by presence.last_active_at desc,player.last_name,player.first_name
  ),'[]'::jsonb)
  into v_participants
  from public.national_team_chat_presence presence
  join public.players player on player.id=presence.player_id
  where presence.association_id=v_assoc
    and presence.last_active_at > now()-interval '10 minutes';

  return jsonb_build_object(
    'is_member',true,
    'joined',v_my.last_active_at is not null,
    'joined_at',v_my.joined_at,
    'last_active_at',v_my.last_active_at,
    'expires_at',v_my.expires_at,
    'timeout_minutes',10,
    'participants',v_participants
  );
end;
$$;

create or replace function public.join_my_national_team_chat_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_membership record;
  v_now timestamptz:=now();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select m.id,m.association_id,m.player_id
  into v_membership
  from public.national_association_memberships m
  where m.user_id=v_uid
    and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_membership.id is null then
    raise exception 'National association membership required.';
  end if;

  insert into public.national_team_chat_presence(
    association_id,membership_id,player_id,user_id,
    joined_at,last_active_at,updated_at
  )
  values(
    v_membership.association_id,v_membership.id,v_membership.player_id,v_uid,
    v_now,v_now,v_now
  )
  on conflict(association_id,user_id)
  do update set
    membership_id=excluded.membership_id,
    player_id=excluded.player_id,
    joined_at=v_now,
    last_active_at=v_now,
    updated_at=v_now;

  return jsonb_build_object(
    'joined',true,
    'joined_at',v_now,
    'last_active_at',v_now,
    'expires_at',v_now+interval '10 minutes',
    'timeout_minutes',10
  );
end;
$$;

create or replace function public.touch_my_national_team_chat_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  v_now timestamptz:=now();
  v_presence public.national_team_chat_presence%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select m.association_id
  into v_assoc
  from public.national_association_memberships m
  where m.user_id=v_uid
    and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_assoc is null then
    return jsonb_build_object('joined',false,'reason','membership_required');
  end if;

  select *
  into v_presence
  from public.national_team_chat_presence p
  where p.association_id=v_assoc
    and p.user_id=v_uid
  limit 1
  for update;

  if not found or v_presence.last_active_at <= v_now-interval '10 minutes' then
    return jsonb_build_object('joined',false,'expired',true,'timeout_minutes',10);
  end if;

  update public.national_team_chat_presence
  set last_active_at=v_now,
      updated_at=v_now
  where id=v_presence.id;

  return jsonb_build_object(
    'joined',true,
    'last_active_at',v_now,
    'expires_at',v_now+interval '10 minutes',
    'timeout_minutes',10
  );
end;
$$;

create or replace function public.send_national_team_chat_message_v1(p_message text)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_assoc uuid;
  v_presence_id uuid;
  v_id uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_message text:=btrim(coalesce(p_message,''));
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  if char_length(v_message)<1 or char_length(v_message)>1000 then
    raise exception 'Message must contain between 1 and 1000 characters.';
  end if;

  select m.player_id,m.association_id
  into v_player,v_assoc
  from public.national_association_memberships m
  where m.user_id=v_uid
    and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_player is null then
    raise exception 'National association membership required.';
  end if;

  select p.id
  into v_presence_id
  from public.national_team_chat_presence p
  where p.association_id=v_assoc
    and p.user_id=v_uid
    and p.last_active_at>now()-interval '10 minutes'
  limit 1
  for update;

  if v_presence_id is null then
    raise exception 'Your live chat session has expired. Join the chat again before sending a message.';
  end if;

  update public.national_team_chat_presence
  set last_active_at=now(),
      updated_at=now()
  where id=v_presence_id;

  insert into public.national_team_chat_messages(
    association_id,player_id,user_id,game_absolute_day,message
  )
  values(v_assoc,v_player,v_uid,v_day,v_message)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.get_my_national_team_chat_presence_v1() from public,anon,authenticated;
revoke all on function public.join_my_national_team_chat_v1() from public,anon,authenticated;
revoke all on function public.touch_my_national_team_chat_v1() from public,anon,authenticated;
revoke all on function public.send_national_team_chat_message_v1(text) from public,anon,authenticated;

grant execute on function public.get_my_national_team_chat_presence_v1() to authenticated;
grant execute on function public.join_my_national_team_chat_v1() to authenticated;
grant execute on function public.touch_my_national_team_chat_v1() to authenticated;
grant execute on function public.send_national_team_chat_message_v1(text) to authenticated;
