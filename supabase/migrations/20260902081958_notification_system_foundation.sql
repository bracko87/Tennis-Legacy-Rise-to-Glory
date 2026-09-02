create table if not exists public.notification_catalog (
  code text primary key,
  category text not null,
  label text not null,
  reason text not null,
  trigger_event text not null,
  trigger_condition text not null,
  trigger_mechanism text not null,
  source_name text,
  title_template text not null,
  message_template text not null,
  default_route text,
  severity text not null default 'info' check (severity in ('info','success','warning','error')),
  default_in_app boolean not null default true,
  default_email boolean not null default false,
  default_push boolean not null default false,
  is_user_configurable boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.notification_catalog is 'Central registry for every Tennis Legacy notification type: why it exists, exactly when/how it triggers, message templates, severity and default delivery channels.';
comment on column public.notification_catalog.reason is 'User-facing/product reason for this notification to exist.';
comment on column public.notification_catalog.trigger_event is 'Business event that causes the notification.';
comment on column public.notification_catalog.trigger_condition is 'Exact condition that must become true before the notification is emitted.';
comment on column public.notification_catalog.trigger_mechanism is 'Technical mechanism responsible for emitting the notification, e.g. database_trigger, scheduled_job, system_event or manual.';

create table if not exists public.notification_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  notification_code text not null references public.notification_catalog(code) on delete cascade,
  in_app_enabled boolean,
  email_enabled boolean,
  push_enabled boolean,
  updated_at timestamptz not null default now(),
  primary key (user_id, notification_code)
);

comment on table public.notification_preferences is 'Optional per-user channel overrides. NULL means inherit the default from notification_catalog.';

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid references public.players(id) on delete cascade,
  notification_code text not null references public.notification_catalog(code),
  title text not null,
  message text not null,
  severity text not null default 'info' check (severity in ('info','success','warning','error')),
  route text,
  payload jsonb not null default '{}'::jsonb,
  event_key text,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  archived_at timestamptz
);

comment on table public.user_notifications is 'Materialized notifications delivered to a specific Tennis Legacy account. Rows are created by server/database notification emitters and read by the in-game Notification Center.';

create index if not exists user_notifications_user_created_idx
  on public.user_notifications(user_id, created_at desc);
create index if not exists user_notifications_user_unread_idx
  on public.user_notifications(user_id, created_at desc)
  where read_at is null and archived_at is null;
create unique index if not exists user_notifications_event_key_uidx
  on public.user_notifications(user_id, event_key)
  where event_key is not null;

alter table public.notification_catalog enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.user_notifications enable row level security;

revoke all on public.notification_catalog from anon, authenticated;
revoke all on public.notification_preferences from anon, authenticated;
revoke all on public.user_notifications from anon, authenticated;

grant select on public.notification_catalog to authenticated;
grant select, insert, update, delete on public.notification_preferences to authenticated;
grant select on public.user_notifications to authenticated;
grant update (read_at, archived_at) on public.user_notifications to authenticated;

drop policy if exists notification_catalog_authenticated_read on public.notification_catalog;
create policy notification_catalog_authenticated_read
  on public.notification_catalog
  for select
  to authenticated
  using (is_active = true);

drop policy if exists notification_preferences_select_own on public.notification_preferences;
create policy notification_preferences_select_own
  on public.notification_preferences
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists notification_preferences_insert_own on public.notification_preferences;
create policy notification_preferences_insert_own
  on public.notification_preferences
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists notification_preferences_update_own on public.notification_preferences;
create policy notification_preferences_update_own
  on public.notification_preferences
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists notification_preferences_delete_own on public.notification_preferences;
create policy notification_preferences_delete_own
  on public.notification_preferences
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists user_notifications_select_own on public.user_notifications;
create policy user_notifications_select_own
  on public.user_notifications
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists user_notifications_update_own on public.user_notifications;
create policy user_notifications_update_own
  on public.user_notifications
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into public.notification_catalog (
  code, category, label, reason,
  trigger_event, trigger_condition, trigger_mechanism, source_name,
  title_template, message_template, default_route, severity,
  default_in_app, default_email, default_push, is_user_configurable, is_active
) values
  (
    'player.skill.increased',
    'player_development',
    'Skill improved',
    'Inform the player whenever one of the nine permanent tennis skills improves.',
    'A tennis skill value increases.',
    'NEW skill value is greater than OLD skill value on public.player_skills.',
    'database_trigger',
    'public.player_skills',
    '{{skill}} improved',
    '{{skill}} increased from {{old_value}} to {{new_value}} ({{delta}}).',
    '/game/skills',
    'success',
    true, false, false, true, true
  ),
  (
    'player.skill.decreased',
    'player_development',
    'Skill decreased',
    'Inform the player whenever one of the nine permanent tennis skills drops so the change is never hidden.',
    'A tennis skill value decreases.',
    'NEW skill value is lower than OLD skill value on public.player_skills.',
    'database_trigger',
    'public.player_skills',
    '{{skill}} decreased',
    '{{skill}} decreased from {{old_value}} to {{new_value}} ({{delta}}).',
    '/game/skills',
    'warning',
    true, false, false, true, true
  )
on conflict (code) do update set
  category = excluded.category,
  label = excluded.label,
  reason = excluded.reason,
  trigger_event = excluded.trigger_event,
  trigger_condition = excluded.trigger_condition,
  trigger_mechanism = excluded.trigger_mechanism,
  source_name = excluded.source_name,
  title_template = excluded.title_template,
  message_template = excluded.message_template,
  default_route = excluded.default_route,
  severity = excluded.severity,
  default_in_app = excluded.default_in_app,
  default_email = excluded.default_email,
  default_push = excluded.default_push,
  is_user_configurable = excluded.is_user_configurable,
  is_active = excluded.is_active,
  updated_at = now();

create or replace function public.emit_notification_v1(
  p_user_id uuid,
  p_player_id uuid,
  p_notification_code text,
  p_title text,
  p_message text,
  p_route text default null,
  p_payload jsonb default '{}'::jsonb,
  p_event_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_catalog public.notification_catalog%rowtype;
  v_preference public.notification_preferences%rowtype;
  v_in_app boolean;
  v_notification_id uuid;
begin
  select * into v_catalog
  from public.notification_catalog
  where code = p_notification_code
    and is_active = true;

  if not found then
    raise exception 'Unknown or inactive notification code: %', p_notification_code;
  end if;

  select * into v_preference
  from public.notification_preferences
  where user_id = p_user_id
    and notification_code = p_notification_code;

  v_in_app := coalesce(v_preference.in_app_enabled, v_catalog.default_in_app);

  if not v_in_app then
    return null;
  end if;

  insert into public.user_notifications (
    user_id,
    player_id,
    notification_code,
    title,
    message,
    severity,
    route,
    payload,
    event_key
  ) values (
    p_user_id,
    p_player_id,
    p_notification_code,
    p_title,
    p_message,
    v_catalog.severity,
    coalesce(p_route, v_catalog.default_route),
    coalesce(p_payload, '{}'::jsonb),
    p_event_key
  )
  on conflict (user_id, event_key) where event_key is not null do nothing
  returning id into v_notification_id;

  return v_notification_id;
end;
$$;

revoke all on function public.emit_notification_v1(uuid, uuid, text, text, text, text, jsonb, text) from public, anon, authenticated;

create or replace function public.notify_player_skill_changes_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_columns text[] := array['serve','forehand','backhand','return_skill','volley','slice','drop_shot','lob','smash'];
  v_labels text[] := array['Serve','Forehand','Backhand','Return','Volley','Slice','Drop Shot','Lob','Smash'];
  v_index integer;
  v_old_value integer;
  v_new_value integer;
  v_delta integer;
  v_code text;
  v_title text;
  v_message text;
  v_event_key text;
begin
  select owner_user_id into v_user_id
  from public.players
  where id = new.player_id;

  if v_user_id is null then
    return new;
  end if;

  for v_index in 1..array_length(v_columns, 1) loop
    v_old_value := (to_jsonb(old) ->> v_columns[v_index])::integer;
    v_new_value := (to_jsonb(new) ->> v_columns[v_index])::integer;

    if v_new_value is distinct from v_old_value then
      v_delta := v_new_value - v_old_value;

      if v_delta > 0 then
        v_code := 'player.skill.increased';
        v_title := format('%s improved', v_labels[v_index]);
        v_message := format('%s increased from %s to %s (+%s).', v_labels[v_index], v_old_value, v_new_value, v_delta);
      else
        v_code := 'player.skill.decreased';
        v_title := format('%s decreased', v_labels[v_index]);
        v_message := format('%s decreased from %s to %s (%s).', v_labels[v_index], v_old_value, v_new_value, v_delta);
      end if;

      v_event_key := format(
        'player_skill:%s:%s:%s:%s:%s',
        new.player_id,
        v_columns[v_index],
        txid_current(),
        v_old_value,
        v_new_value
      );

      perform public.emit_notification_v1(
        v_user_id,
        new.player_id,
        v_code,
        v_title,
        v_message,
        '/game/skills',
        jsonb_build_object(
          'skill_key', v_columns[v_index],
          'skill', v_labels[v_index],
          'old_value', v_old_value,
          'new_value', v_new_value,
          'delta', v_delta,
          'direction', case when v_delta > 0 then 'up' else 'down' end
        ),
        v_event_key
      );
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function public.notify_player_skill_changes_v1() from public, anon, authenticated;

drop trigger if exists player_skill_notifications_after_update on public.player_skills;
create trigger player_skill_notifications_after_update
after update of serve, forehand, backhand, return_skill, volley, slice, drop_shot, lob, smash
on public.player_skills
for each row
execute function public.notify_player_skill_changes_v1();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'user_notifications'
     ) then
    alter publication supabase_realtime add table public.user_notifications;
  end if;
end
$$;
