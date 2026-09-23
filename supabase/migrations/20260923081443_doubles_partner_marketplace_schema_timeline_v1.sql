-- Doubles Ticket 2: tournament-specific partner marketplace, invitation schema,
-- configurable entry windows, lifecycle state and notification catalogue.

alter table public.tournament_doubles_settings
  add column if not exists registration_open_offset_minutes integer not null default 0,
  add column if not exists registration_deadline_offset_minutes integer not null default 0,
  add column if not exists partnership_deadline_before_draw_minutes integer not null default 1440,
  add column if not exists draw_lock_offset_minutes integer not null default 0,
  add column if not exists fallback_singles_points_weight numeric(5,3) not null default 0.350;

alter table public.tournament_doubles_settings
  drop constraint if exists tournament_doubles_settings_registration_open_offset_minutes_check,
  add constraint tournament_doubles_settings_registration_open_offset_minutes_check
    check (registration_open_offset_minutes between -10080 and 10080),
  drop constraint if exists tournament_doubles_settings_registration_deadline_offset_minutes_check,
  add constraint tournament_doubles_settings_registration_deadline_offset_minutes_check
    check (registration_deadline_offset_minutes between -10080 and 10080),
  drop constraint if exists tournament_doubles_settings_partnership_deadline_before_draw_minutes_check,
  add constraint tournament_doubles_settings_partnership_deadline_before_draw_minutes_check
    check (partnership_deadline_before_draw_minutes between 0 and 10080),
  drop constraint if exists tournament_doubles_settings_draw_lock_offset_minutes_check,
  add constraint tournament_doubles_settings_draw_lock_offset_minutes_check
    check (draw_lock_offset_minutes between -10080 and 10080),
  drop constraint if exists tournament_doubles_settings_fallback_singles_points_weight_check,
  add constraint tournament_doubles_settings_fallback_singles_points_weight_check
    check (fallback_singles_points_weight between 0 and 1);

alter table public.tournament_doubles_teams
  add column if not exists entry_strength_snapshot integer not null default 0,
  add column if not exists entry_decided_at timestamptz;

create table if not exists public.tournament_doubles_partner_listings (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  owner_user_id uuid not null,
  status text not null default 'active'
    check (status in ('active','cancelled','matched','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz,
  unique(competition_id,player_id)
);
create index if not exists tournament_doubles_partner_listings_market_idx
  on public.tournament_doubles_partner_listings(competition_id,status,created_at);
create index if not exists tournament_doubles_partner_listings_owner_idx
  on public.tournament_doubles_partner_listings(owner_user_id,competition_id,status);

create table if not exists public.tournament_doubles_partner_invitations (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  inviter_player_id uuid not null references public.players(id) on delete cascade,
  invitee_player_id uuid not null references public.players(id) on delete cascade,
  inviter_user_id uuid not null,
  invitee_user_id uuid not null,
  status text not null default 'pending'
    check (status in ('pending','accepted','declined','expired','cancelled')),
  expires_game_second bigint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  responded_at timestamptz,
  check (inviter_player_id<>invitee_player_id)
);
create index if not exists tournament_doubles_partner_invitations_competition_idx
  on public.tournament_doubles_partner_invitations(competition_id,status,created_at);
create index if not exists tournament_doubles_partner_invitations_invitee_idx
  on public.tournament_doubles_partner_invitations(invitee_user_id,status,created_at);
create index if not exists tournament_doubles_partner_invitations_inviter_idx
  on public.tournament_doubles_partner_invitations(inviter_user_id,status,created_at);
create unique index if not exists tournament_doubles_partner_invitations_pending_pair_uq
  on public.tournament_doubles_partner_invitations(competition_id,inviter_player_id,invitee_player_id)
  where status='pending';

create table if not exists public.tournament_doubles_entry_lifecycle (
  competition_id uuid primary key references public.tournament_world_competitions(id) on delete cascade,
  registration_closed_at timestamptz,
  partnership_closed_at timestamptz,
  allocation_processed_at timestamptz,
  draw_processed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.tournament_doubles_partner_listings enable row level security;
alter table public.tournament_doubles_partner_invitations enable row level security;
alter table public.tournament_doubles_entry_lifecycle enable row level security;

drop policy if exists doubles_partner_listings_authenticated_read on public.tournament_doubles_partner_listings;
create policy doubles_partner_listings_authenticated_read
on public.tournament_doubles_partner_listings
for select to authenticated using (true);

drop policy if exists doubles_partner_invitations_involved_read on public.tournament_doubles_partner_invitations;
create policy doubles_partner_invitations_involved_read
on public.tournament_doubles_partner_invitations
for select to authenticated
using (auth.uid() in (inviter_user_id,invitee_user_id));

drop policy if exists doubles_entry_lifecycle_authenticated_read on public.tournament_doubles_entry_lifecycle;
create policy doubles_entry_lifecycle_authenticated_read
on public.tournament_doubles_entry_lifecycle
for select to authenticated using (true);

revoke insert,update,delete on public.tournament_doubles_partner_listings from authenticated;
revoke insert,update,delete on public.tournament_doubles_partner_invitations from authenticated;
revoke insert,update,delete on public.tournament_doubles_entry_lifecycle from authenticated;
grant select on public.tournament_doubles_partner_listings to authenticated;
grant select on public.tournament_doubles_partner_invitations to authenticated;
grant select on public.tournament_doubles_entry_lifecycle to authenticated;

create or replace function public.get_tournament_doubles_entry_timeline_v1(p_competition_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_singles jsonb;
  v_series uuid;
  v_enabled boolean;
  v_open_offset integer;
  v_registration_offset integer;
  v_partner_before integer;
  v_draw_offset integer;
  v_open bigint;
  v_registration bigint;
  v_partnership bigint;
  v_draw bigint;
  v_now bigint:=public.current_game_second_v1();
  v_window record;
  v_phase text;
begin
  select ed.tournament_series_id,ds.is_enabled,
         ds.registration_open_offset_minutes,
         ds.registration_deadline_offset_minutes,
         ds.partnership_deadline_before_draw_minutes,
         ds.draw_lock_offset_minutes
  into v_series,v_enabled,v_open_offset,v_registration_offset,v_partner_before,v_draw_offset
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_doubles_settings ds on ds.tournament_series_id=ed.tournament_series_id
  where wc.id=p_competition_id
    and wc.status<>'canceled'
    and ed.status<>'canceled';

  if v_series is null or not coalesce(v_enabled,false) then
    return jsonb_build_object('enabled',false,'competition_id',p_competition_id);
  end if;

  v_singles:=public.get_tournament_entry_timeline_v1(p_competition_id);
  select * into v_window from public.get_competition_window_v1(p_competition_id);

  v_open:=(v_singles->>'applications_open_game_second')::bigint + coalesce(v_open_offset,0)::bigint*60;
  v_registration:=(v_singles->>'late_close_game_second')::bigint + coalesce(v_registration_offset,0)::bigint*60;
  v_draw:=(v_singles->>'draw_publish_game_second')::bigint + coalesce(v_draw_offset,0)::bigint*60;
  v_partnership:=greatest(
    v_registration,
    v_draw-coalesce(v_partner_before,1440)::bigint*60
  );

  if v_now<v_open then v_phase:='not_open';
  elsif v_now<v_registration then v_phase:='marketplace_open';
  elsif v_now<v_partnership then v_phase:='partnership_resolution';
  elsif v_now<v_draw then v_phase:='entry_locked';
  else v_phase:='draw_locked';
  end if;

  return jsonb_build_object(
    'enabled',true,
    'competition_id',p_competition_id,
    'phase',v_phase,
    'registration_open_game_second',v_open,
    'registration_deadline_game_second',v_registration,
    'partnership_deadline_game_second',v_partnership,
    'draw_lock_game_second',v_draw,
    'registration_open',public.game_moment_json_v1(v_open),
    'registration_deadline',public.game_moment_json_v1(v_registration),
    'partnership_deadline',public.game_moment_json_v1(v_partnership),
    'draw_lock',public.game_moment_json_v1(v_draw),
    'tournament_start',public.game_moment_json_v1(v_window.start_absolute_day::bigint*86400),
    'tournament_end',public.game_moment_json_v1((v_window.end_absolute_day::bigint+1)*86400-60),
    'can_create_listing',v_now>=v_open and v_now<v_registration,
    'can_send_invitation',v_now>=v_open and v_now<v_partnership,
    'can_respond_invitation',v_now<v_partnership,
    'can_cancel_listing',v_now<v_partnership,
    'can_change_partnership',v_now<v_partnership,
    'entry_locked',v_now>=v_partnership,
    'draw_locked',v_now>=v_draw
  );
end;
$$;
revoke all on function public.get_tournament_doubles_entry_timeline_v1(uuid) from public,anon;
grant execute on function public.get_tournament_doubles_entry_timeline_v1(uuid) to authenticated,service_role;

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,
  title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
)
values
('doubles.partner.invitation','tournament','Doubles Partner Invitation','A player invited you to form a doubles team for a specific tournament.','doubles_partner_invitation_created','A pending tournament-specific doubles invitation is created.','Doubles partner marketplace','Doubles','Doubles partner invitation','You received a doubles partner invitation.','/game/calendar?tab=tournament-calendar','info',true,false,false,true,true),
('doubles.invitation.accepted','tournament','Doubles Invitation Accepted','Your tournament-specific doubles invitation was accepted.','doubles_partner_invitation_accepted','The invited player accepts before the partnership deadline.','Doubles partner marketplace','Doubles','Doubles invitation accepted','Your doubles invitation was accepted.','/game/calendar?tab=tournament-calendar','success',true,false,false,true,true),
('doubles.invitation.declined','tournament','Doubles Invitation Declined','Your tournament-specific doubles invitation was declined.','doubles_partner_invitation_declined','The invited player declines.','Doubles partner marketplace','Doubles','Doubles invitation declined','Your doubles invitation was declined.','/game/calendar?tab=tournament-calendar','info',true,false,false,true,true),
('doubles.invitation.expired','tournament','Doubles Invitation Expired','A pending doubles invitation reached the tournament partnership deadline.','doubles_partner_invitation_expired','A pending invitation reaches the partnership deadline.','Doubles partner lifecycle','Doubles','Doubles invitation expired','The doubles invitation expired at the tournament deadline.','/game/calendar?tab=tournament-calendar','warning',true,false,false,true,true),
('doubles.partnership.confirmed','tournament','Doubles Partnership Confirmed','A tournament-specific doubles partnership was confirmed.','doubles_partnership_created','An invitation is accepted and a doubles team is created.','Doubles partner marketplace','Doubles','Doubles partnership confirmed','Your doubles partnership is confirmed for this tournament.','/game/calendar?tab=tournament-calendar','success',true,false,false,true,true),
('doubles.entry.accepted','tournament','Doubles Entry Accepted','The doubles team received a place in the tournament draw.','doubles_entry_allocated','A confirmed team is inside the doubles draw capacity.','Doubles entry allocation','Doubles','Doubles entry accepted','Your doubles team received a place in the draw.','/game/calendar?tab=tournament-calendar','success',true,false,false,true,true),
('doubles.entry.waitlisted','tournament','Doubles Waitlisted','The doubles team is outside the current draw capacity.','doubles_entry_waitlisted','A confirmed team is ranked outside doubles draw capacity.','Doubles entry allocation','Doubles','Doubles team waitlisted','Your doubles team is on the alternate list.','/game/calendar?tab=tournament-calendar','warning',true,false,false,true,true),
('doubles.draw.published','tournament','Doubles Draw Published','The official doubles draw is available.','doubles_draw_published','The tournament doubles draw is published.','Doubles draw publication','Doubles','Doubles draw published','The official doubles draw is now available.','/game/calendar?tab=tournament-calendar','info',true,false,false,true,true),
('doubles.team.withdrawn','tournament','Doubles Team Withdrawn','A tournament doubles partnership or team was withdrawn.','doubles_team_withdrawn','One partner leaves before lock or withdraws the team after lock.','Doubles withdrawal','Doubles','Doubles team withdrawn','Your doubles team was withdrawn.','/game/calendar?tab=tournament-calendar','warning',true,false,false,true,true)
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  severity=excluded.severity,
  default_in_app=excluded.default_in_app,
  is_active=true,
  updated_at=now();

do $$
begin
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_doubles_partner_listings'
  ) then
    alter publication supabase_realtime add table public.tournament_doubles_partner_listings;
  end if;
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_doubles_partner_invitations'
  ) then
    alter publication supabase_realtime add table public.tournament_doubles_partner_invitations;
  end if;
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_doubles_teams'
  ) then
    alter publication supabase_realtime add table public.tournament_doubles_teams;
  end if;
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_doubles_entry_lifecycle'
  ) then
    alter publication supabase_realtime add table public.tournament_doubles_entry_lifecycle;
  end if;
end
$$;