create table if not exists public.tennis_club_settings (
  id smallint primary key default 1 check (id = 1),
  creation_cost_coins integer not null default 100 check (creation_cost_coins >= 0),
  chat_history_game_days smallint not null default 14 check (chat_history_game_days between 1 and 90),
  updated_at timestamptz not null default now()
);
insert into public.tennis_club_settings(id,creation_cost_coins,chat_history_game_days)
values(1,100,14)
on conflict(id) do update set creation_cost_coins=excluded.creation_cost_coins,chat_history_game_days=excluded.chat_history_game_days,updated_at=now();

create table if not exists public.tennis_clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_player_id uuid not null unique references public.players(id) on delete restrict,
  created_absolute_day integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(btrim(name)) between 3 and 40)
);
create unique index if not exists tennis_clubs_name_ci_uidx on public.tennis_clubs(lower(btrim(name)));

create table if not exists public.tennis_club_memberships (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.tennis_clubs(id) on delete cascade,
  player_id uuid not null unique references public.players(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_absolute_day integer not null,
  created_at timestamptz not null default now(),
  unique(club_id,player_id)
);
create index if not exists tennis_club_memberships_club_idx on public.tennis_club_memberships(club_id,created_at);

create table if not exists public.tennis_club_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.tennis_clubs(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  request_type text not null check (request_type in ('application','invitation')),
  created_by_player_id uuid not null references public.players(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_absolute_day integer not null,
  responded_absolute_day integer null,
  responded_by_player_id uuid null references public.players(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists tennis_club_requests_one_pending_relationship_idx
  on public.tennis_club_requests(club_id,player_id) where status='pending';
create index if not exists tennis_club_requests_player_idx on public.tennis_club_requests(player_id,status,created_at desc);
create index if not exists tennis_club_requests_club_idx on public.tennis_club_requests(club_id,status,created_at desc);

create table if not exists public.tennis_club_chat_messages (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.tennis_clubs(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  game_absolute_day integer not null,
  message text not null,
  created_at timestamptz not null default now(),
  check (char_length(btrim(message)) between 1 and 500)
);
create index if not exists tennis_club_chat_messages_club_day_idx on public.tennis_club_chat_messages(club_id,game_absolute_day desc,created_at desc);

alter table public.tennis_club_settings enable row level security;
alter table public.tennis_clubs enable row level security;
alter table public.tennis_club_memberships enable row level security;
alter table public.tennis_club_requests enable row level security;
alter table public.tennis_club_chat_messages enable row level security;

revoke all on public.tennis_club_settings from anon,authenticated;
revoke all on public.tennis_clubs from anon,authenticated;
revoke all on public.tennis_club_memberships from anon,authenticated;
revoke all on public.tennis_club_requests from anon,authenticated;
revoke all on public.tennis_club_chat_messages from anon,authenticated;

create or replace function public.user_is_tennis_club_member_v1(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path='public'
as $$
  select exists(
    select 1
    from public.tennis_club_memberships m
    join public.players p on p.id=m.player_id
    where m.club_id=p_club_id and p.owner_user_id=auth.uid()
  );
$$;
revoke all on function public.user_is_tennis_club_member_v1(uuid) from public,anon;
grant execute on function public.user_is_tennis_club_member_v1(uuid) to authenticated;

drop policy if exists tennis_club_chat_member_read on public.tennis_club_chat_messages;
create policy tennis_club_chat_member_read on public.tennis_club_chat_messages
for select to authenticated
using (public.user_is_tennis_club_member_v1(club_id));
grant select on public.tennis_club_chat_messages to authenticated;

create or replace function public.get_world_tennis_clubs_internal_v1(p_limit integer default 50)
returns jsonb
language sql
stable
security definer
set search_path='public'
as $$
with scores as (
  select c.id,c.name,c.owner_player_id,c.created_absolute_day,
         coalesce(sum(coalesce(r.ranking_points,0)),0)::bigint as points,
         count(m.player_id)::integer as member_count,
         count(m.player_id) filter (where upper(coalesce(p.world,''))='ATP')::integer as atp_members,
         count(m.player_id) filter (where upper(coalesce(p.world,''))='WTA')::integer as wta_members
  from public.tennis_clubs c
  left join public.tennis_club_memberships m on m.club_id=c.id
  left join public.players p on p.id=m.player_id
  left join public.player_rankings r on r.player_id=p.id
  group by c.id,c.name,c.owner_player_id,c.created_absolute_day
), ranked as (
  select s.*,row_number() over(order by s.points desc,s.member_count desc,lower(s.name),s.id)::integer as world_rank
  from scores s
)
select coalesce(jsonb_agg(jsonb_build_object(
  'id',id,'name',name,'world_rank',world_rank,'points',points,
  'member_count',member_count,'atp_members',atp_members,'wta_members',wta_members,
  'owner_player_id',owner_player_id,'created_absolute_day',created_absolute_day
) order by world_rank),'[]'::jsonb)
from ranked where world_rank <= greatest(1,least(coalesce(p_limit,50),50));
$$;
revoke all on function public.get_world_tennis_clubs_internal_v1(integer) from public,anon,authenticated;

create or replace function public.prune_tennis_club_chat_internal_v1()
returns integer
language plpgsql
security definer
set search_path='public'
as $$
declare v_abs integer; v_days integer; v_count integer;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  select chat_history_game_days into v_days from public.tennis_club_settings where id=1;
  delete from public.tennis_club_chat_messages where game_absolute_day < v_abs - greatest(1,coalesce(v_days,14)) + 1;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.prune_tennis_club_chat_internal_v1() from public,anon,authenticated;

create or replace function public.get_tennis_club_chat_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_player uuid; v_club uuid; v_abs integer; v_days integer; v_messages jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  select m.club_id into v_club from public.tennis_club_memberships m where m.player_id=v_player;
  if v_club is null then return jsonb_build_object('club_id',null,'messages','[]'::jsonb); end if;
  perform public.prune_tennis_club_chat_internal_v1();
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  select chat_history_game_days into v_days from public.tennis_club_settings where id=1;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',q.id,'player_id',q.player_id,'first_name',q.first_name,'last_name',q.last_name,
      'world',q.world,'game_absolute_day',q.game_absolute_day,'season',q.season,'month',q.month,'day',q.day,
      'message',q.message,'created_at',q.created_at
    ) order by q.game_absolute_day,q.created_at),'[]'::jsonb)
  into v_messages
  from (
    select cm.id,cm.player_id,p.first_name,p.last_name,p.world,cm.game_absolute_day,gd.season,gd.month,gd.day,cm.message,cm.created_at
    from public.tennis_club_chat_messages cm
    join public.players p on p.id=cm.player_id
    cross join lateral public.absolute_game_day_v1(cm.game_absolute_day) gd
    where cm.club_id=v_club and cm.game_absolute_day >= v_abs - greatest(1,coalesce(v_days,14)) + 1
    order by cm.game_absolute_day,cm.created_at
  ) q;
  return jsonb_build_object('club_id',v_club,'history_game_days',coalesce(v_days,14),'messages',v_messages);
end;
$$;
revoke all on function public.get_tennis_club_chat_v1() from public,anon;
grant execute on function public.get_tennis_club_chat_v1() to authenticated;

create or replace function public.get_tennis_club_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_player record; v_abs integer; v_cost integer; v_days integer; v_coins bigint:=0;
  v_club_id uuid; v_role text; v_club jsonb:=null; v_members jsonb:='[]'::jsonb;
  v_invites jsonb:='[]'::jsonb; v_apps jsonb:='[]'::jsonb; v_incoming jsonb:='[]'::jsonb;
  v_world jsonb:='[]'::jsonb; v_chat jsonb; v_points bigint:=0; v_rank integer:=null;
begin
  select p.id,p.owner_user_id,p.first_name,p.last_name,p.world,coalesce(r.ranking_points,0) ranking_points
  into v_player
  from public.players p left join public.player_rankings r on r.player_id=p.id
  where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  select creation_cost_coins,chat_history_game_days into v_cost,v_days from public.tennis_club_settings where id=1;
  insert into public.user_wallets(user_id) values(v_player.owner_user_id) on conflict(user_id) do nothing;
  select coins_balance into v_coins from public.user_wallets where user_id=v_player.owner_user_id;
  select m.club_id,m.role into v_club_id,v_role from public.tennis_club_memberships m where m.player_id=v_player.id;
  v_world:=public.get_world_tennis_clubs_internal_v1(50);

  select coalesce(jsonb_agg(jsonb_build_object(
    'request_id',r.id,'club_id',c.id,'club_name',c.name,'created_absolute_day',r.created_absolute_day,
    'owner_name',op.first_name||' '||op.last_name
  ) order by r.created_at desc),'[]'::jsonb)
  into v_invites
  from public.tennis_club_requests r join public.tennis_clubs c on c.id=r.club_id join public.players op on op.id=c.owner_player_id
  where r.player_id=v_player.id and r.request_type='invitation' and r.status='pending';

  select coalesce(jsonb_agg(jsonb_build_object(
    'request_id',r.id,'club_id',c.id,'club_name',c.name,'created_absolute_day',r.created_absolute_day
  ) order by r.created_at desc),'[]'::jsonb)
  into v_apps
  from public.tennis_club_requests r join public.tennis_clubs c on c.id=r.club_id
  where r.player_id=v_player.id and r.request_type='application' and r.status='pending';

  if v_club_id is not null then
    with scores as (
      select c.id,coalesce(sum(coalesce(pr.ranking_points,0)),0)::bigint points,count(m.player_id)::int member_count
      from public.tennis_clubs c left join public.tennis_club_memberships m on m.club_id=c.id
      left join public.player_rankings pr on pr.player_id=m.player_id group by c.id
    ), ranked as (
      select s.*,row_number() over(order by s.points desc,s.member_count desc,c2.name,s.id)::int world_rank
      from scores s join public.tennis_clubs c2 on c2.id=s.id
    ) select points,world_rank into v_points,v_rank from ranked where id=v_club_id;

    select jsonb_build_object(
      'id',c.id,'name',c.name,'owner_player_id',c.owner_player_id,'role',v_role,
      'created_absolute_day',c.created_absolute_day,'points',coalesce(v_points,0),'world_rank',v_rank,
      'member_count',(select count(*) from public.tennis_club_memberships m where m.club_id=c.id),
      'atp_members',(select count(*) from public.tennis_club_memberships m join public.players p on p.id=m.player_id where m.club_id=c.id and upper(coalesce(p.world,''))='ATP'),
      'wta_members',(select count(*) from public.tennis_club_memberships m join public.players p on p.id=m.player_id where m.club_id=c.id and upper(coalesce(p.world,''))='WTA')
    ) into v_club from public.tennis_clubs c where c.id=v_club_id;

    select coalesce(jsonb_agg(jsonb_build_object(
      'player_id',p.id,'first_name',p.first_name,'last_name',p.last_name,'world',p.world,
      'role',m.role,'ranking_points',coalesce(pr.ranking_points,0),'joined_absolute_day',m.joined_absolute_day
    ) order by case when m.role='owner' then 0 else 1 end,coalesce(pr.ranking_points,0) desc,p.last_name,p.first_name),'[]'::jsonb)
    into v_members
    from public.tennis_club_memberships m join public.players p on p.id=m.player_id left join public.player_rankings pr on pr.player_id=p.id
    where m.club_id=v_club_id;

    if v_role='owner' then
      select coalesce(jsonb_agg(jsonb_build_object(
        'request_id',r.id,'player_id',p.id,'first_name',p.first_name,'last_name',p.last_name,'world',p.world,
        'ranking_points',coalesce(pr.ranking_points,0),'created_absolute_day',r.created_absolute_day
      ) order by r.created_at),'[]'::jsonb)
      into v_incoming
      from public.tennis_club_requests r join public.players p on p.id=r.player_id left join public.player_rankings pr on pr.player_id=p.id
      where r.club_id=v_club_id and r.request_type='application' and r.status='pending';
    end if;
  end if;

  v_chat:=public.get_tennis_club_chat_v1();
  return jsonb_build_object(
    'player',jsonb_build_object('id',v_player.id,'first_name',v_player.first_name,'last_name',v_player.last_name,'world',v_player.world,'ranking_points',v_player.ranking_points),
    'coins_balance',coalesce(v_coins,0),
    'settings',jsonb_build_object('creation_cost_coins',coalesce(v_cost,100),'chat_history_game_days',coalesce(v_days,14)),
    'club',v_club,'members',v_members,'invitations',v_invites,'applications',v_apps,'incoming_applications',v_incoming,
    'world_clubs',v_world,'chat',v_chat,'current_absolute_day',v_abs
  );
end;
$$;
revoke all on function public.get_tennis_club_dashboard_v1() from public,anon;
grant execute on function public.get_tennis_club_dashboard_v1() to authenticated;

create or replace function public.create_tennis_club_v1(p_name text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_player record; v_name text:=btrim(coalesce(p_name,'')); v_abs integer; v_cost integer; v_balance bigint; v_club uuid;
begin
  select p.id,p.owner_user_id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  if char_length(v_name)<3 or char_length(v_name)>40 then raise exception 'Club name must contain 3 to 40 characters.'; end if;
  if exists(select 1 from public.tennis_club_memberships where player_id=v_player.id) then raise exception 'You already belong to a tennis club.'; end if;
  select creation_cost_coins into v_cost from public.tennis_club_settings where id=1;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  insert into public.user_wallets(user_id) values(v_player.owner_user_id) on conflict(user_id) do nothing;
  select coins_balance into v_balance from public.user_wallets where user_id=v_player.owner_user_id for update;
  if coalesce(v_balance,0)<coalesce(v_cost,100) then raise exception 'Creating a Tennis Club costs % coins. Available: %.',coalesce(v_cost,100),coalesce(v_balance,0); end if;
  insert into public.tennis_clubs(name,owner_player_id,created_absolute_day) values(v_name,v_player.id,v_abs) returning id into v_club;
  insert into public.tennis_club_memberships(club_id,player_id,role,joined_absolute_day) values(v_club,v_player.id,'owner',v_abs);
  update public.user_wallets set coins_balance=coins_balance-v_cost,lifetime_coins_spent=lifetime_coins_spent+v_cost,updated_at=now() where user_id=v_player.owner_user_id returning coins_balance into v_balance;
  insert into public.coin_ledger(user_id,amount,balance_after,entry_type,description,reference_id)
  values(v_player.owner_user_id,-v_cost,v_balance,'spend','Create Tennis Club: '||v_name,'tennis_club:'||v_club::text);
  update public.tennis_club_requests set status='cancelled',responded_absolute_day=v_abs,responded_by_player_id=v_player.id,updated_at=now() where player_id=v_player.id and status='pending';
  return jsonb_build_object('status','created','club_id',v_club,'club_name',v_name,'coins_spent',v_cost,'coins_balance',v_balance);
exception when unique_violation then
  raise exception 'A Tennis Club with this name already exists.';
end;
$$;
revoke all on function public.create_tennis_club_v1(text) from public,anon;
grant execute on function public.create_tennis_club_v1(text) to authenticated;

create or replace function public.apply_to_tennis_club_v1(p_club_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_player uuid; v_abs integer; v_request uuid; v_name text;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_player is null then raise exception 'Player not found.'; end if;
  if exists(select 1 from public.tennis_club_memberships where player_id=v_player) then raise exception 'You already belong to a tennis club.'; end if;
  select name into v_name from public.tennis_clubs where id=p_club_id;
  if v_name is null then raise exception 'Tennis Club not found.'; end if;
  if exists(select 1 from public.tennis_club_requests where club_id=p_club_id and player_id=v_player and status='pending') then raise exception 'You already have a pending request with this club.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  insert into public.tennis_club_requests(club_id,player_id,request_type,created_by_player_id,status,created_absolute_day)
  values(p_club_id,v_player,'application',v_player,'pending',v_abs) returning id into v_request;
  return jsonb_build_object('status','applied','request_id',v_request,'club_id',p_club_id,'club_name',v_name);
end;
$$;
revoke all on function public.apply_to_tennis_club_v1(uuid) from public,anon;
grant execute on function public.apply_to_tennis_club_v1(uuid) to authenticated;

create or replace function public.search_tennis_club_invite_candidates_v1(p_query text default '')
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_player uuid; v_club uuid; v_result jsonb;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  select c.id into v_club from public.tennis_clubs c where c.owner_player_id=v_player;
  if v_club is null then raise exception 'Only a club owner can invite players.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'player_id',q.id,'first_name',q.first_name,'last_name',q.last_name,'world',q.world,'ranking_points',q.ranking_points
  ) order by q.ranking_points desc,q.last_name,q.first_name),'[]'::jsonb)
  into v_result
  from (
    select p.id,p.first_name,p.last_name,p.world,coalesce(r.ranking_points,0) ranking_points
    from public.players p left join public.player_rankings r on r.player_id=p.id
    where p.owner_user_id is not null and p.id<>v_player
      and not exists(select 1 from public.tennis_club_memberships m where m.player_id=p.id)
      and (btrim(coalesce(p_query,''))='' or (p.first_name||' '||p.last_name) ilike '%'||btrim(p_query)||'%')
    order by coalesce(r.ranking_points,0) desc,p.last_name,p.first_name limit 20
  ) q;
  return v_result;
end;
$$;
revoke all on function public.search_tennis_club_invite_candidates_v1(text) from public,anon;
grant execute on function public.search_tennis_club_invite_candidates_v1(text) to authenticated;

create or replace function public.invite_to_tennis_club_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_owner uuid; v_club uuid; v_abs integer; v_request uuid; v_target record;
begin
  select p.id into v_owner from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  select c.id into v_club from public.tennis_clubs c where c.owner_player_id=v_owner;
  if v_club is null then raise exception 'Only a club owner can invite players.'; end if;
  select p.id,p.first_name,p.last_name into v_target from public.players p where p.id=p_player_id and p.owner_user_id is not null;
  if v_target.id is null then raise exception 'Player not found.'; end if;
  if v_target.id=v_owner then raise exception 'You are already the club owner.'; end if;
  if exists(select 1 from public.tennis_club_memberships where player_id=p_player_id) then raise exception 'This player already belongs to a tennis club.'; end if;
  if exists(select 1 from public.tennis_club_requests where club_id=v_club and player_id=p_player_id and status='pending') then raise exception 'A pending request already exists for this player.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  insert into public.tennis_club_requests(club_id,player_id,request_type,created_by_player_id,status,created_absolute_day)
  values(v_club,p_player_id,'invitation',v_owner,'pending',v_abs) returning id into v_request;
  return jsonb_build_object('status','invited','request_id',v_request,'player_id',p_player_id,'player_name',v_target.first_name||' '||v_target.last_name);
end;
$$;
revoke all on function public.invite_to_tennis_club_v1(uuid) from public,anon;
grant execute on function public.invite_to_tennis_club_v1(uuid) to authenticated;

create or replace function public.respond_tennis_club_request_v1(p_request_id uuid,p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_actor uuid; v_abs integer; r public.tennis_club_requests%rowtype; v_owner uuid;
begin
  select p.id into v_actor from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_actor is null then raise exception 'Player not found.'; end if;
  select * into r from public.tennis_club_requests where id=p_request_id for update;
  if r.id is null then raise exception 'Club request not found.'; end if;
  if r.status<>'pending' then raise exception 'This club request is no longer pending.'; end if;
  select owner_player_id into v_owner from public.tennis_clubs where id=r.club_id;
  if r.request_type='invitation' and r.player_id<>v_actor then raise exception 'Only the invited player can respond to this invitation.'; end if;
  if r.request_type='application' and v_owner<>v_actor then raise exception 'Only the club owner can respond to this application.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  if not coalesce(p_accept,false) then
    update public.tennis_club_requests set status='declined',responded_absolute_day=v_abs,responded_by_player_id=v_actor,updated_at=now() where id=r.id;
    return jsonb_build_object('status','declined','request_id',r.id);
  end if;
  if exists(select 1 from public.tennis_club_memberships where player_id=r.player_id) then raise exception 'This player already belongs to a tennis club.'; end if;
  insert into public.tennis_club_memberships(club_id,player_id,role,joined_absolute_day) values(r.club_id,r.player_id,'member',v_abs);
  update public.tennis_club_requests set status='accepted',responded_absolute_day=v_abs,responded_by_player_id=v_actor,updated_at=now() where id=r.id;
  update public.tennis_club_requests set status='cancelled',responded_absolute_day=v_abs,responded_by_player_id=v_actor,updated_at=now() where player_id=r.player_id and status='pending' and id<>r.id;
  return jsonb_build_object('status','accepted','request_id',r.id,'club_id',r.club_id,'player_id',r.player_id);
end;
$$;
revoke all on function public.respond_tennis_club_request_v1(uuid,boolean) from public,anon;
grant execute on function public.respond_tennis_club_request_v1(uuid,boolean) to authenticated;

create or replace function public.send_tennis_club_chat_message_v1(p_message text)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare v_player record; v_club uuid; v_abs integer; v_message text:=btrim(coalesce(p_message,'')); v_id uuid; gd record;
begin
  if char_length(v_message)<1 or char_length(v_message)>500 then raise exception 'Club chat messages must contain 1 to 500 characters.'; end if;
  select p.id,p.first_name,p.last_name,p.world into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select m.club_id into v_club from public.tennis_club_memberships m where m.player_id=v_player.id;
  if v_club is null then raise exception 'You must belong to a Tennis Club to use Club Chat.'; end if;
  perform public.prune_tennis_club_chat_internal_v1();
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  insert into public.tennis_club_chat_messages(club_id,player_id,game_absolute_day,message) values(v_club,v_player.id,v_abs,v_message) returning id into v_id;
  select * into gd from public.absolute_game_day_v1(v_abs);
  return jsonb_build_object('status','sent','message',jsonb_build_object('id',v_id,'player_id',v_player.id,'first_name',v_player.first_name,'last_name',v_player.last_name,'world',v_player.world,'game_absolute_day',v_abs,'season',gd.season,'month',gd.month,'day',gd.day,'message',v_message));
end;
$$;
revoke all on function public.send_tennis_club_chat_message_v1(text) from public,anon;
grant execute on function public.send_tennis_club_chat_message_v1(text) to authenticated;

DO $$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='tennis_club_chat_messages') then
    alter publication supabase_realtime add table public.tennis_club_chat_messages;
  end if;
end $$;
