-- Account-wide interface settings and canonical, per-event notification preferences.
-- Uses the existing notification_catalog and notification_preferences tables.
create table if not exists public.user_interface_preferences_v1 (
  user_id uuid primary key references auth.users(id) on delete cascade,
  table_density text not null default 'comfortable'
    check (table_density in ('comfortable','compact')),
  reduce_animations boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.user_interface_preferences_v1 enable row level security;
grant select,insert,update on public.user_interface_preferences_v1 to authenticated;
revoke all on public.user_interface_preferences_v1 from anon;
drop policy if exists user_interface_preferences_v1_read on public.user_interface_preferences_v1;
create policy user_interface_preferences_v1_read on public.user_interface_preferences_v1
  for select to authenticated using (auth.uid()=user_id);
drop policy if exists user_interface_preferences_v1_insert on public.user_interface_preferences_v1;
create policy user_interface_preferences_v1_insert on public.user_interface_preferences_v1
  for insert to authenticated with check (auth.uid()=user_id);
drop policy if exists user_interface_preferences_v1_update on public.user_interface_preferences_v1;
create policy user_interface_preferences_v1_update on public.user_interface_preferences_v1
  for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);

-- Defense in depth: existing RLS allows own-row writes, so essential event types
-- must also be protected at the table boundary, not merely disabled in the UI.
create or replace function public.guard_essential_notification_preference_v1()
returns trigger language plpgsql set search_path='public','pg_temp'
as $body$
declare v_catalog public.notification_catalog%rowtype;
begin
 select * into v_catalog from public.notification_catalog
  where code=new.notification_code and is_active=true;
 if not found then raise exception 'Unknown or inactive notification code'; end if;
 if not v_catalog.is_user_configurable and (
   (new.in_app_enabled is not null and new.in_app_enabled<>v_catalog.default_in_app)
   or (new.email_enabled is not null and new.email_enabled<>v_catalog.default_email)
   or (new.push_enabled is not null and new.push_enabled<>v_catalog.default_push)
 ) then raise exception 'Essential notifications cannot be disabled'; end if;
 return new;
end;
$body$;
drop trigger if exists guard_essential_notification_preference_v1 on public.notification_preferences;
create trigger guard_essential_notification_preference_v1
before insert or update on public.notification_preferences
for each row execute function public.guard_essential_notification_preference_v1();

-- Optional categories reflect the actual notification catalog; nonexistent
-- staff/ranking/youth/audio channels do not produce pretend controls.
create or replace function public.get_my_notification_category_preferences_v1()
returns jsonb language sql stable security definer set search_path='public','pg_temp'
as $fn$
 with optional as (
   select c.category, c.code,
          coalesce(p.in_app_enabled,c.default_in_app) as enabled
   from public.notification_catalog c
   left join public.notification_preferences p
     on p.notification_code=c.code and p.user_id=auth.uid()
   where c.is_active and c.is_user_configurable
 ),
 grouped as (
   select category, count(*)::int as event_types,
          count(*) filter(where enabled)::int as enabled_types
   from optional group by category
 )
 select coalesce(jsonb_agg(jsonb_build_object(
   'category',category,'event_types',event_types,'enabled_types',enabled_types,
   'enabled',enabled_types=event_types,'mixed',enabled_types>0 and enabled_types<event_types
 ) order by category),'[]'::jsonb) from grouped;
$fn$;
revoke all on function public.get_my_notification_category_preferences_v1() from public,anon;
grant execute on function public.get_my_notification_category_preferences_v1() to authenticated;

create or replace function public.set_my_notification_category_enabled_v1(
 p_category text, p_enabled boolean
) returns jsonb language plpgsql security definer set search_path='public','pg_temp'
as $fn$
declare v_user uuid:=auth.uid(); v_count int;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if p_category is null or p_enabled is null then raise exception 'Invalid preference'; end if;
 -- Serialize overlapping saves for one account and keep all event types in sync.
 perform pg_advisory_xact_lock(hashtext('tennis_notification_preferences:'||v_user::text));
 insert into public.notification_preferences(user_id,notification_code,in_app_enabled,updated_at)
 select v_user,c.code,p_enabled,now()
 from public.notification_catalog c
 where c.category=p_category and c.is_active and c.is_user_configurable
 on conflict(user_id,notification_code) do update
   set in_app_enabled=excluded.in_app_enabled,updated_at=now();
 get diagnostics v_count=row_count;
 if v_count=0 then raise exception 'No configurable notifications in this category'; end if;
 return jsonb_build_object('category',p_category,'enabled',p_enabled,'updated_types',v_count);
end;
$fn$;
revoke all on function public.set_my_notification_category_enabled_v1(text,boolean) from public,anon;
grant execute on function public.set_my_notification_category_enabled_v1(text,boolean) to authenticated;

-- The application currently only emits in-app notifications. Email and push
-- defaults exist in the catalog, but no player-facing controls are added
-- until reliable delivery and opt-out enforcement are wired end-to-end.
