-- Keep historical invitation notifications, but remove their unread marker
-- when an invitation has been accepted, declined, or automatically cancelled.
create or replace function public.clear_handled_tennis_club_invitation_notification_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp'
as $body$
begin
  if old.request_type='invitation'
     and old.status='pending'
     and new.status in ('accepted','declined','cancelled') then
    update public.user_notifications
       set read_at=coalesce(read_at,now())
     where notification_code='club.invitation.received'
       and event_key='club_invitation_received:'||new.id::text;
  end if;
  return new;
end;
$body$;
revoke all on function public.clear_handled_tennis_club_invitation_notification_v1() from public,anon,authenticated;
drop trigger if exists tennis_club_invitation_notification_handled_v1 on public.tennis_club_requests;
create trigger tennis_club_invitation_notification_handled_v1
after update of status on public.tennis_club_requests
for each row execute function public.clear_handled_tennis_club_invitation_notification_v1();
