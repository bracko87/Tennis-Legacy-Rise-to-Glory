create table if not exists public.player_rankings (
  player_id uuid primary key references public.players(id) on delete cascade,
  ranking_points integer not null default 0 check (ranking_points >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.player_rankings (player_id)
select p.id from public.players p
on conflict (player_id) do nothing;

create or replace function public.ensure_player_ranking_v1()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.player_rankings (player_id) values (new.id)
  on conflict (player_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_ensure_player_ranking on public.players;
create trigger trg_ensure_player_ranking after insert on public.players
for each row execute function public.ensure_player_ranking_v1();

alter table public.player_rankings enable row level security;
revoke all on public.player_rankings from anon, authenticated;

create table if not exists public.player_conversations (
  id uuid primary key default gen_random_uuid(),
  player_one_id uuid not null references public.players(id) on delete cascade,
  player_two_id uuid not null references public.players(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_conversations_distinct_players check (player_one_id <> player_two_id),
  constraint player_conversations_ordered_players check (player_one_id < player_two_id),
  constraint player_conversations_unique_pair unique (player_one_id, player_two_id)
);

create table if not exists public.player_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.player_conversations(id) on delete cascade,
  sender_player_id uuid not null references public.players(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists player_messages_conversation_created_idx on public.player_messages (conversation_id, created_at desc);

alter table public.player_conversations enable row level security;
alter table public.player_messages enable row level security;
revoke all on public.player_conversations from anon, authenticated;
revoke all on public.player_messages from anon, authenticated;

create or replace function public.get_world_rankings_v1(p_world text,p_offset integer default 0,p_limit integer default 50)
returns table (rank_position bigint,player_id uuid,first_name text,last_name text,country_code text,image_path text,ranking_points integer)
language sql stable security definer set search_path = public as $$
  with ranked as (
    select row_number() over (order by coalesce(r.ranking_points, 0) desc, p.created_at asc, p.id asc) as rank_position,
      p.id as player_id,p.first_name,p.last_name,p.country_code,p.image_path,coalesce(r.ranking_points, 0)::integer as ranking_points
    from public.players p left join public.player_rankings r on r.player_id = p.id
    where p.world = upper(p_world) and p.moderation_status <> 'rejected'
  )
  select * from ranked order by rank_position
  offset greatest(coalesce(p_offset,0),0) limit least(greatest(coalesce(p_limit,50),1),100);
$$;

create or replace function public.get_player_profile_v1(p_player_id uuid)
returns table (player_id uuid,first_name text,last_name text,world text,country_code text,image_path text,ranking_points integer,rank_position bigint,is_own_player boolean)
language sql stable security definer set search_path = public as $$
  with target as (select p.* from public.players p where p.id = p_player_id and p.moderation_status <> 'rejected'),
  ranked as (
    select p.id,row_number() over (order by coalesce(r.ranking_points,0) desc, p.created_at asc, p.id asc) as rank_position
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.world = (select world from target) and p.moderation_status <> 'rejected'
  )
  select t.id,t.first_name,t.last_name,t.world,t.country_code,t.image_path,coalesce(pr.ranking_points,0)::integer,ranked.rank_position,(t.owner_user_id = auth.uid())
  from target t left join public.player_rankings pr on pr.player_id=t.id left join ranked on ranked.id=t.id;
$$;

create or replace function public.get_or_create_player_conversation_v1(p_target_player_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid; v_one uuid; v_two uuid; v_id uuid;
begin
  select id into v_me from public.players where owner_user_id = auth.uid();
  if v_me is null then raise exception 'Current player not found'; end if;
  if p_target_player_id = v_me then raise exception 'You cannot message yourself'; end if;
  if not exists (select 1 from public.players where id=p_target_player_id and moderation_status <> 'rejected') then raise exception 'Target player not found'; end if;
  v_one := least(v_me,p_target_player_id); v_two := greatest(v_me,p_target_player_id);
  insert into public.player_conversations(player_one_id,player_two_id) values(v_one,v_two)
  on conflict (player_one_id,player_two_id) do update set updated_at=public.player_conversations.updated_at returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.send_player_message_v1(p_conversation_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid; v_id uuid;
begin
  select id into v_me from public.players where owner_user_id=auth.uid();
  if v_me is null then raise exception 'Current player not found'; end if;
  if char_length(btrim(coalesce(p_body,''))) < 1 or char_length(btrim(p_body)) > 2000 then raise exception 'Message must contain 1 to 2000 characters'; end if;
  if not exists(select 1 from public.player_conversations c where c.id=p_conversation_id and v_me in (c.player_one_id,c.player_two_id)) then raise exception 'Conversation not found'; end if;
  insert into public.player_messages(conversation_id,sender_player_id,body) values(p_conversation_id,v_me,btrim(p_body)) returning id into v_id;
  update public.player_conversations set updated_at=now() where id=p_conversation_id;
  return v_id;
end;
$$;

create or replace function public.get_player_inbox_v1()
returns table (conversation_id uuid,other_player_id uuid,other_first_name text,other_last_name text,other_world text,other_country_code text,other_image_path text,last_message text,last_message_at timestamptz,unread_count bigint)
language sql stable security definer set search_path = public as $$
  with me as (select id from public.players where owner_user_id=auth.uid()),
  conv as (
    select c.*,case when c.player_one_id=(select id from me) then c.player_two_id else c.player_one_id end other_id
    from public.player_conversations c where (select id from me) in (c.player_one_id,c.player_two_id)
  )
  select c.id,p.id,p.first_name,p.last_name,p.world,p.country_code,p.image_path,lm.body,lm.created_at,
    (select count(*) from public.player_messages m where m.conversation_id=c.id and m.sender_player_id<>(select id from me) and m.read_at is null)
  from conv c join public.players p on p.id=c.other_id
  left join lateral (select m.body,m.created_at from public.player_messages m where m.conversation_id=c.id order by m.created_at desc limit 1) lm on true
  order by coalesce(lm.created_at,c.updated_at) desc;
$$;

create or replace function public.get_player_conversation_messages_v1(p_conversation_id uuid)
returns table (message_id uuid,sender_player_id uuid,body text,created_at timestamptz,is_mine boolean)
language plpgsql security definer set search_path = public as $$
declare v_me uuid;
begin
  select id into v_me from public.players where owner_user_id=auth.uid();
  if v_me is null or not exists(select 1 from public.player_conversations c where c.id=p_conversation_id and v_me in(c.player_one_id,c.player_two_id)) then raise exception 'Conversation not found'; end if;
  update public.player_messages set read_at=coalesce(read_at,now()) where conversation_id=p_conversation_id and sender_player_id<>v_me and read_at is null;
  return query select m.id,m.sender_player_id,m.body,m.created_at,(m.sender_player_id=v_me) from public.player_messages m where m.conversation_id=p_conversation_id order by m.created_at asc;
end;
$$;

revoke all on function public.get_world_rankings_v1(text,integer,integer) from public;
revoke all on function public.get_player_profile_v1(uuid) from public;
revoke all on function public.get_or_create_player_conversation_v1(uuid) from public;
revoke all on function public.send_player_message_v1(uuid,text) from public;
revoke all on function public.get_player_inbox_v1() from public;
revoke all on function public.get_player_conversation_messages_v1(uuid) from public;
grant execute on function public.get_world_rankings_v1(text,integer,integer) to authenticated;
grant execute on function public.get_player_profile_v1(uuid) to authenticated;
grant execute on function public.get_or_create_player_conversation_v1(uuid) to authenticated;
grant execute on function public.send_player_message_v1(uuid,text) to authenticated;
grant execute on function public.get_player_inbox_v1() to authenticated;
grant execute on function public.get_player_conversation_messages_v1(uuid) to authenticated;
