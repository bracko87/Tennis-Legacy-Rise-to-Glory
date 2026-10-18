-- Tennis Club invitations and unread chat state. All access is resolved from auth.uid().
create table if not exists public.tennis_club_chat_read_state_v1 (
  player_id uuid primary key references public.players(id) on delete cascade,
  club_id uuid not null references public.tennis_clubs(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.tennis_club_chat_read_state_v1 enable row level security;
revoke all on public.tennis_club_chat_read_state_v1 from public, anon, authenticated;

insert into public.notification_catalog
 (code, category, label, reason, trigger_event, trigger_condition, trigger_mechanism,
  title_template, message_template, default_route, severity, default_in_app,
  default_email, default_push, is_user_configurable, is_active)
values
 ('club.invitation.received','club','Tennis Club invitation',
  'Invited player must know that a club invitation is awaiting a response.',
  'A new Tennis Club invitation is submitted', 'Valid pending invitation for a human player',
  'After-insert database trigger; unique event key per request',
  'New Tennis Club invitation', '{{inviter_name}} invited you to join {{club_name}}. Accept or decline in Tennis Club.',
  '/game/tennis-club', 'info', true, false, false, true, true)
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  is_active=true,
  updated_at=now();

create or replace function public.notify_tennis_club_invitation_v1()
returns trigger
language plpgsql security definer set search_path='public','pg_temp'
as $body$
declare
 v_user uuid;
 v_club_name text;
 v_sender text;
begin
 if new.request_type <> 'invitation' or new.status <> 'pending' then return new; end if;
 select p.owner_user_id into v_user from public.players p where p.id=new.player_id;
 if v_user is null then return new; end if;
 select c.name, concat_ws(' ',sender.first_name,sender.last_name)
 into v_club_name,v_sender
 from public.tennis_clubs c
 join public.players sender on sender.id=new.created_by_player_id
 where c.id=new.club_id;
 perform public.emit_notification_v1(
   v_user,new.player_id,'club.invitation.received',
   'New Tennis Club invitation',
   coalesce(v_sender,'A player')||' invited you to join '||coalesce(v_club_name,'a tennis club')||'. Accept or decline in Tennis Club.',
   '/game/tennis-club',
   jsonb_build_object('request_id',new.id,'club_id',new.club_id,'club_name',v_club_name,'inviter_name',v_sender),
   'club_invitation_received:'||new.id::text
 );
 return new;
end;
$body$;
revoke all on function public.notify_tennis_club_invitation_v1() from public,anon,authenticated;
drop trigger if exists tennis_club_invitation_notification_v1 on public.tennis_club_requests;
create trigger tennis_club_invitation_notification_v1
after insert on public.tennis_club_requests
for each row execute function public.notify_tennis_club_invitation_v1();

-- Also notify players about invitations that were pending when the feature shipped.
select public.emit_notification_v1(
 p.owner_user_id,r.player_id,'club.invitation.received',
 'New Tennis Club invitation',
 concat_ws(' ',sender.first_name,sender.last_name)||' invited you to join '||c.name||'. Accept or decline in Tennis Club.',
 '/game/tennis-club',
 jsonb_build_object('request_id',r.id,'club_id',r.club_id,'club_name',c.name,
                    'inviter_name',concat_ws(' ',sender.first_name,sender.last_name)),
 'club_invitation_received:'||r.id::text
)
from public.tennis_club_requests r
join public.tennis_clubs c on c.id=r.club_id
join public.players p on p.id=r.player_id
join public.players sender on sender.id=r.created_by_player_id
where r.request_type='invitation' and r.status='pending' and p.owner_user_id is not null;

create or replace function public.get_tennis_club_alert_counts_v1()
returns jsonb
language plpgsql stable security definer set search_path='public','pg_temp'
as $body$
declare
 v_player uuid;
 v_club uuid;
 v_member_created timestamptz;
 v_last_read timestamptz;
 v_invites int:=0;
 v_messages int:=0;
 v_applications int:=0;
 v_abs int;
 v_history int;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select p.id into v_player from public.players p
 where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
 if v_player is null then return jsonb_build_object('invitations',0,'messages',0,'applications',0,'total',0); end if;
 select count(*) into v_invites
 from public.tennis_club_requests r
 where r.player_id=v_player and r.request_type='invitation' and r.status='pending';
 select m.club_id,m.created_at into v_club,v_member_created
 from public.tennis_club_memberships m where m.player_id=v_player;
 if v_club is not null then
   select state.last_read_at into v_last_read
   from public.tennis_club_chat_read_state_v1 state
   where state.player_id=v_player and state.club_id=v_club;
   select public.game_day_absolute_v1(d.season,d.month,d.day)
     into v_abs from public.get_current_game_day_internal_v1() d;
   select greatest(1,coalesce(chat_history_game_days,14))
     into v_history from public.tennis_club_settings where id=1;
   select count(*) into v_messages
   from public.tennis_club_chat_messages cm
   where cm.club_id=v_club and cm.player_id<>v_player
     and cm.game_absolute_day >= v_abs-coalesce(v_history,14)+1
     and cm.created_at>greatest(coalesce(v_last_read,v_member_created),v_member_created);
   if exists (select 1 from public.tennis_club_memberships m
              where m.player_id=v_player and m.role='owner') then
      select count(*) into v_applications from public.tennis_club_requests r
      where r.club_id=v_club and r.request_type='application' and r.status='pending';
   end if;
 end if;
 return jsonb_build_object('invitations',v_invites,'messages',v_messages,
     'applications',v_applications,'total',v_invites+v_messages+v_applications);
end;
$body$;
revoke all on function public.get_tennis_club_alert_counts_v1() from public,anon;
grant execute on function public.get_tennis_club_alert_counts_v1() to authenticated;

-- Mark only the last message that was *actually loaded* as read. Do not mark
-- newly arriving messages read because the user opened the chat a moment ago.
create or replace function public.mark_tennis_club_chat_read_v1(p_last_message_id uuid)
returns jsonb
language plpgsql security definer set search_path='public','pg_temp'
as $body$
declare
 v_player uuid;
 v_club uuid;
 v_message_at timestamptz;
 v_joined_at timestamptz;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select p.id into v_player from public.players p
 where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;
 if v_player is null then raise exception 'Player not found'; end if;
 select m.club_id,m.created_at into v_club,v_joined_at
 from public.tennis_club_memberships m where m.player_id=v_player;
 if v_club is null then raise exception 'Not a club member'; end if;
 if p_last_message_id is null then
   return jsonb_build_object('status','no_messages');
 end if;
 select cm.created_at into v_message_at
 from public.tennis_club_chat_messages cm
 where cm.id=p_last_message_id and cm.club_id=v_club
   and cm.created_at>=v_joined_at;
 if v_message_at is null then raise exception 'Message not available in your club'; end if;
 insert into public.tennis_club_chat_read_state_v1(player_id,club_id,last_read_at)
 values (v_player,v_club,v_message_at)
 on conflict (player_id) do update
   set club_id=excluded.club_id,
       last_read_at=case when tennis_club_chat_read_state_v1.club_id=excluded.club_id
          then greatest(tennis_club_chat_read_state_v1.last_read_at,excluded.last_read_at)
          else excluded.last_read_at end,
       updated_at=now();
 return jsonb_build_object('status','read','read_through',v_message_at);
end;
$body$;
revoke all on function public.mark_tennis_club_chat_read_v1(uuid) from public,anon;
grant execute on function public.mark_tennis_club_chat_read_v1(uuid) to authenticated;
