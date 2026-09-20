update public.notification_catalog
set default_route='/game/pro-packages', updated_at=now()
where code='account.birthday_gift';

update public.notification_catalog
set default_route='/game/equipment?tab=sponsors', updated_at=now()
where code like 'equipment.technical_sponsor.%';

update public.user_notifications
set route='/game/pro-packages'
where notification_code='account.birthday_gift';

update public.user_notifications
set route='/game/equipment?tab=sponsors'
where notification_code like 'equipment.technical_sponsor.%';

update public.user_notifications
set route=case
  when notification_code='tournament.preparation.available'
    then '/game/schedule?competition='||(payload->>'competition_id')||'&prepare=1'
  else '/game/tournaments/'||(payload->>'competition_id')
end
where notification_code like 'tournament.%'
  and nullif(payload->>'competition_id','') is not null;

update public.user_notifications u
set payload=
  jsonb_build_object(
    'notification_category',c.category,
    'notification_label',c.label,
    'action_url',u.route
  ) || coalesce(u.payload,'{}'::jsonb)
from public.notification_catalog c
where c.code=u.notification_code;

create or replace function public.emit_notification_v1(
  p_user_id uuid,
  p_player_id uuid,
  p_notification_code text,
  p_title text,
  p_message text,
  p_route text default null::text,
  p_payload jsonb default '{}'::jsonb,
  p_event_key text default null::text
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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

create or replace function public.notify_player_fatigue_thresholds_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid;
  v_code text;
  v_title text;
  v_message text;
  v_threshold integer;
begin
  if tg_op<>'UPDATE' or new.fatigue=old.fatigue or new.fatigue<old.fatigue then
    return new;
  end if;

  select owner_user_id into v_user_id
  from public.players
  where id=new.player_id;

  if v_user_id is null then return new; end if;

  if old.fatigue<90 and new.fatigue>=90 then
    v_threshold:=90;
    v_code:='player.fatigue.critical';
    v_title:='Critical fatigue';
    v_message:=format('Fatigue has reached %s/100. Recovery should take priority before further demanding activity.',new.fatigue);
  elsif old.fatigue<80 and new.fatigue>=80 then
    v_threshold:=80;
    v_code:='player.fatigue.day_off_recommended';
    v_title:='Day Off recommended';
    v_message:=format('Fatigue has reached %s/100. A Day Off or light recovery work is strongly recommended.',new.fatigue);
  elsif old.fatigue<60 and new.fatigue>=60 then
    v_threshold:=60;
    v_code:='player.fatigue.tired';
    v_title:='Fatigue is building';
    v_message:=format('Your Fatigue has reached %s/100. Consider lighter training or recovery soon.',new.fatigue);
  else
    return new;
  end if;

  perform public.emit_notification_v1(
    v_user_id,
    new.player_id,
    v_code,
    v_title,
    v_message,
    '/game/training',
    jsonb_build_object('fatigue_before',old.fatigue,'fatigue_after',new.fatigue,'threshold',v_threshold),
    format('fatigue:%s:%s:%s',new.player_id,v_threshold,extract(epoch from clock_timestamp())::bigint)
  );

  return new;
end;
$function$;

update public.user_notifications lower_alert
set archived_at=coalesce(lower_alert.archived_at,now())
where lower_alert.archived_at is null
  and lower_alert.notification_code in ('player.fatigue.tired','player.fatigue.day_off_recommended')
  and exists(
    select 1
    from public.user_notifications higher_alert
    where higher_alert.user_id=lower_alert.user_id
      and higher_alert.player_id is not distinct from lower_alert.player_id
      and higher_alert.created_at=lower_alert.created_at
      and higher_alert.payload->>'fatigue_after'=lower_alert.payload->>'fatigue_after'
      and (
        (lower_alert.notification_code='player.fatigue.tired'
          and higher_alert.notification_code in ('player.fatigue.day_off_recommended','player.fatigue.critical'))
        or
        (lower_alert.notification_code='player.fatigue.day_off_recommended'
          and higher_alert.notification_code='player.fatigue.critical')
      )
  );
