-- Notification Preferences Part 2: review each active event, protect deadlines
-- and high-severity consequences, and expose individual event-level controls.

update public.notification_catalog
set is_user_configurable=false, updated_at=now()
where code in (
 'club.invitation.received',
 'equipment.technical_sponsor.expiring',
 'equipment.technical_sponsor.expired',
 'national.association.renewal',
 'national.captain.election',
 'national.captain.runoff',
 'national.captain.vacancy',
 'national.friendly.invitation',
 'player.fatigue.critical',
 'doubles.draw.published',
 'doubles.invitation.expired',
 'doubles.match.scheduled',
 'doubles.partner.invitation',
 'doubles.team.withdrawn',
 'tournament.canceled',
 'tournament.draw.published',
 'tournament.entry.accepted_main',
 'tournament.entry.accepted_qualification',
 'tournament.entry.rejected',
 'tournament.match.travel_no_show',
 'tournament.preparation.available'
) and is_active=true;

-- Clear obsolete optional overrides on events that are now required.
delete from public.notification_preferences p
using public.notification_catalog c
where c.code=p.notification_code and c.is_active
  and not c.is_user_configurable;

-- Unlike the original producer, required events bypass stale stored overrides.
CREATE OR REPLACE FUNCTION public.emit_notification_v1(p_user_id uuid, p_player_id uuid, p_notification_code text, p_title text, p_message text, p_route text DEFAULT NULL::text, p_payload jsonb DEFAULT '{}'::jsonb, p_event_key text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_catalog public.notification_catalog%rowtype;
  v_preference public.notification_preferences%rowtype;
  v_in_app boolean;
  v_notification_id uuid;
  v_route text;
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_competition_id text;
begin
  select * into v_catalog
  from public.notification_catalog
  where code=p_notification_code
    and is_active=true;

  if not found then
    raise exception 'Unknown or inactive notification code: %',p_notification_code;
  end if;

  select * into v_preference
  from public.notification_preferences
  where user_id=p_user_id
    and notification_code=p_notification_code;

  -- Required notifications bypass any legacy or malformed user preference rows.
  v_in_app:=case when not v_catalog.is_user_configurable
    then v_catalog.default_in_app
    else coalesce(v_preference.in_app_enabled,v_catalog.default_in_app) end;
  if not v_in_app then return null; end if;

  v_route:=coalesce(p_route,v_catalog.default_route);

  if coalesce(v_payload->>'action_url','') like '/game/%' then
    v_route:=v_payload->>'action_url';
  else
    v_competition_id:=nullif(v_payload->>'competition_id','');

    if p_notification_code like 'tournament.%' and v_competition_id is not null then
      if p_notification_code='tournament.preparation.available' then
        v_route:='/game/schedule?competition='||v_competition_id||'&prepare=1';
      else
        v_route:='/game/tournaments/'||v_competition_id;
      end if;
    elsif p_notification_code like 'doubles.%' and v_competition_id is not null then
      v_route:='/game/tournaments/'||v_competition_id||'/doubles';
    elsif p_notification_code='account.birthday_gift' then
      v_route:='/game/pro-packages';
    elsif p_notification_code like 'equipment.technical_sponsor.%' then
      v_route:='/game/equipment?tab=sponsors';
    end if;
  end if;

  v_payload:=
    jsonb_build_object(
      'notification_category',v_catalog.category,
      'notification_label',v_catalog.label
    ) || v_payload;

  if v_route is not null then
    v_payload:=jsonb_set(v_payload,'{action_url}',to_jsonb(v_route),true);
  end if;

  insert into public.user_notifications(
    user_id,player_id,notification_code,title,message,severity,route,payload,event_key
  ) values(
    p_user_id,p_player_id,p_notification_code,p_title,p_message,v_catalog.severity,v_route,v_payload,p_event_key
  )
  on conflict(user_id,event_key) where event_key is not null do nothing
  returning id into v_notification_id;

  return v_notification_id;
end;
$function$;


create or replace function public.get_my_notification_inventory_v2()
returns jsonb language sql stable security definer set search_path='public','pg_temp'
as $fn$
  with notices as (
    select c.category,c.code,c.label,c.reason,c.trigger_event,c.trigger_condition,
           c.trigger_mechanism,c.severity,c.is_user_configurable,
           c.default_in_app,
           case when not c.is_user_configurable then c.default_in_app
             else coalesce(p.in_app_enabled,c.default_in_app) end as enabled
    from public.notification_catalog c
    left join public.notification_preferences p
      on p.user_id=auth.uid() and p.notification_code=c.code
    where c.is_active
  ),
  sections as (
    select category,count(*)::int as total,
      count(*) filter(where is_user_configurable)::int as optional_count,
      count(*) filter(where not is_user_configurable)::int as required_count,
      count(*) filter(where is_user_configurable and enabled)::int as enabled_count,
      jsonb_agg(jsonb_build_object(
        'code',code,'label',label,'description',reason,'trigger',trigger_event,
        'condition',trigger_condition,'mechanism',trigger_mechanism,
        'severity',severity,'configurable',is_user_configurable,
        'enabled',enabled,'default_enabled',default_in_app
      ) order by is_user_configurable desc,code) as items
    from notices group by category
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'category',category,'total',total,'optional_count',optional_count,
    'required_count',required_count,'enabled_count',enabled_count,
    'all_optional_enabled',enabled_count=optional_count,
    'mixed',enabled_count>0 and enabled_count<optional_count,
    'items',items
  ) order by category),'[]'::jsonb)
  from sections
  where auth.uid() is not null;
$fn$;
revoke all on function public.get_my_notification_inventory_v2() from public,anon;
grant execute on function public.get_my_notification_inventory_v2() to authenticated;

create or replace function public.set_my_notification_type_enabled_v1(
 p_code text,p_enabled boolean
) returns jsonb language plpgsql security definer set search_path='public','pg_temp'
as $fn$
declare v_user uuid:=auth.uid(); v_catalog public.notification_catalog%rowtype;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if p_code is null or p_enabled is null then raise exception 'Invalid notification preference'; end if;
 perform pg_advisory_xact_lock(hashtext('tennis_notification_preferences:'||v_user::text));
 select * into v_catalog from public.notification_catalog
 where code=p_code and is_active=true;
 if not found then raise exception 'Unknown or inactive notification type'; end if;
 if not v_catalog.is_user_configurable then raise exception 'This notification is required'; end if;
 insert into public.notification_preferences(user_id,notification_code,in_app_enabled,updated_at)
 values(v_user,p_code,p_enabled,now())
 on conflict(user_id,notification_code) do update
 set in_app_enabled=excluded.in_app_enabled,updated_at=now();
 return jsonb_build_object('code',p_code,'enabled',p_enabled);
end;
$fn$;
revoke all on function public.set_my_notification_type_enabled_v1(text,boolean) from public,anon;
grant execute on function public.set_my_notification_type_enabled_v1(text,boolean) to authenticated;

create or replace function public.restore_my_notification_defaults_v1()
returns jsonb language plpgsql security definer set search_path='public','pg_temp'
as $fn$
declare v_user uuid:=auth.uid(); v_count int;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtext('tennis_notification_preferences:'||v_user::text));
 delete from public.notification_preferences p
 using public.notification_catalog c
 where p.user_id=v_user and c.code=p.notification_code
   and c.is_user_configurable;
 get diagnostics v_count=row_count;
 return jsonb_build_object('restored',true,'deleted_overrides',v_count);
end;
$fn$;
revoke all on function public.restore_my_notification_defaults_v1() from public,anon;
grant execute on function public.restore_my_notification_defaults_v1() to authenticated;

comment on function public.get_my_notification_inventory_v2() is
'One authoritative inventory for Settings: all active catalog event types, required protections, triggers and user preferences. Inbox is separate player-to-player messaging.';
