
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
set search_path=public,pg_temp
as $$
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

  v_in_app:=coalesce(v_preference.in_app_enabled,v_catalog.default_in_app);
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
$$;

