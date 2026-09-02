insert into public.notification_catalog (
  code, category, label, reason, trigger_event, trigger_condition, trigger_mechanism,
  source_name, title_template, message_template, default_route, severity,
  default_in_app, default_email, default_push, is_user_configurable, is_active, updated_at
) values
(
  'player.fatigue.tired','player_condition','Fatigue building',
  'Warn the player when accumulated load is becoming meaningful before it becomes a recovery problem.',
  'player_skills fatigue update','Fatigue crosses upward from below 60 to 60 or higher.',
  'Postgres trigger on public.player_skills','player_skills',
  'Fatigue is building','Your Fatigue has reached {{fatigue}}/100. Consider lighter training or recovery soon.',
  '/game/training','info',true,false,false,true,true,now()
),
(
  'player.fatigue.day_off_recommended','player_condition','Day Off recommended',
  'Warn the player when accumulated fatigue is high enough that regular hard training should no longer be the priority.',
  'player_skills fatigue update','Fatigue crosses upward from below 80 to 80 or higher.',
  'Postgres trigger on public.player_skills','player_skills',
  'Day Off recommended','Fatigue has reached {{fatigue}}/100. A Day Off or light recovery work is strongly recommended.',
  '/game/training','warning',true,false,false,true,true,now()
),
(
  'player.fatigue.critical','player_condition','Critical fatigue',
  'Protect the player from severe accumulated fatigue and signal that recovery must take priority.',
  'player_skills fatigue update','Fatigue crosses upward from below 90 to 90 or higher.',
  'Postgres trigger on public.player_skills','player_skills',
  'Critical fatigue','Fatigue has reached {{fatigue}}/100. Recovery should take priority before further demanding activity.',
  '/game/training','error',true,false,false,true,true,now()
),
(
  'player.injury.detected','player_health','Player injured',
  'Immediately inform the user when the player enters the injured daily activity state.',
  'player_daily_activity state change','Daily activity is inserted or changes to injured.',
  'Postgres trigger on public.player_daily_activity','player_daily_activity',
  'Player injured','Your player is injured. Regular training is unavailable until the injury state is cleared.',
  '/game/skills','error',true,true,false,false,true,now()
)
on conflict (code) do update set
  category=excluded.category,label=excluded.label,reason=excluded.reason,
  trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,
  title_template=excluded.title_template,message_template=excluded.message_template,
  default_route=excluded.default_route,severity=excluded.severity,
  default_in_app=excluded.default_in_app,default_email=excluded.default_email,
  default_push=excluded.default_push,is_user_configurable=excluded.is_user_configurable,
  is_active=excluded.is_active,updated_at=now();

create or replace function public.notify_player_fatigue_thresholds_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_code text;
  v_title text;
  v_message text;
  v_threshold integer;
begin
  if tg_op <> 'UPDATE' or new.fatigue = old.fatigue or new.fatigue < old.fatigue then
    return new;
  end if;

  select owner_user_id into v_user_id from public.players where id = new.player_id;
  if v_user_id is null then return new; end if;

  for v_threshold, v_code, v_title in
    select * from (values
      (60, 'player.fatigue.tired'::text, 'Fatigue is building'::text),
      (80, 'player.fatigue.day_off_recommended'::text, 'Day Off recommended'::text),
      (90, 'player.fatigue.critical'::text, 'Critical fatigue'::text)
    ) as x(threshold_value, code_value, title_value)
  loop
    if old.fatigue < v_threshold and new.fatigue >= v_threshold then
      v_message := case v_threshold
        when 60 then format('Your Fatigue has reached %s/100. Consider lighter training or recovery soon.', new.fatigue)
        when 80 then format('Fatigue has reached %s/100. A Day Off or light recovery work is strongly recommended.', new.fatigue)
        else format('Fatigue has reached %s/100. Recovery should take priority before further demanding activity.', new.fatigue)
      end;

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
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function public.notify_player_fatigue_thresholds_v1() from public, anon, authenticated;
grant execute on function public.notify_player_fatigue_thresholds_v1() to service_role;

drop trigger if exists trg_notify_player_fatigue_thresholds on public.player_skills;
create trigger trg_notify_player_fatigue_thresholds
after update of fatigue on public.player_skills
for each row execute function public.notify_player_fatigue_thresholds_v1();

create or replace function public.notify_player_injury_state_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_message text;
begin
  if new.activity_type <> 'injured' then return new; end if;
  if tg_op = 'UPDATE' and old.activity_type = 'injured' then return new; end if;

  select owner_user_id into v_user_id from public.players where id = new.player_id;
  if v_user_id is null then return new; end if;

  v_message := 'Your player is injured. Regular training is unavailable until the injury state is cleared.';
  if nullif(trim(coalesce(new.note,'')),'') is not null then
    v_message := v_message || ' ' || trim(new.note);
  end if;

  perform public.emit_notification_v1(
    v_user_id,
    new.player_id,
    'player.injury.detected',
    'Player injured',
    v_message,
    '/game/skills',
    jsonb_build_object('season',new.season,'month',new.month,'day',new.day,'source',new.source,'reference_id',new.reference_id),
    format('injury:%s:%s:%s:%s',new.player_id,new.season,new.month,new.day)
  );

  return new;
end;
$$;

revoke all on function public.notify_player_injury_state_v1() from public, anon, authenticated;
grant execute on function public.notify_player_injury_state_v1() to service_role;

drop trigger if exists trg_notify_player_injury_state on public.player_daily_activity;
create trigger trg_notify_player_injury_state
after insert or update of activity_type on public.player_daily_activity
for each row execute function public.notify_player_injury_state_v1();
