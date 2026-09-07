create or replace function public.notify_injury_risk_if_needed_v2(
  p_player_id uuid,
  p_context text default 'general',
  p_intensity text default null,
  p_match_minutes integer default 0,
  p_heat_index numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  v_abs integer;
  v_risk jsonb;
  v_level text;
  v_owner uuid;
  v_event uuid;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  v_risk:=public.get_player_injury_risk_v1(
    p_player_id,
    p_context,
    p_intensity,
    greatest(0,coalesce(p_match_minutes,0)),
    greatest(0,coalesce(p_heat_index,0))
  );
  v_level:=v_risk->>'risk_level';

  insert into public.player_injury_risk_events(player_id,absolute_day,context,risk_percent,risk_level,reasons)
  values(p_player_id,v_abs,p_context,(v_risk->>'risk_percent')::numeric,v_level,v_risk->'reasons')
  on conflict(player_id,absolute_day,context) do update
    set risk_percent=excluded.risk_percent,
        risk_level=excluded.risk_level,
        reasons=excluded.reasons
  returning id into v_event;

  if v_level in ('elevated','high','very_high')
     and not exists(select 1 from public.player_injury_risk_events where id=v_event and notified) then
    select owner_user_id into v_owner from public.players where id=p_player_id;
    if v_owner is not null then
      perform public.emit_notification_v1(
        v_owner,
        p_player_id,
        'player.injury.risk',
        'Injury risk increased',
        format(
          'Current injury risk is %s (%s%%) for %s. Review fatigue, recovery and workload before the activity starts.',
          replace(v_level,'_',' '),
          v_risk->>'risk_percent',
          replace(p_context,'_',' ')
        ),
        '/game/injuries',
        jsonb_build_object(
          'risk',v_risk,
          'context',p_context,
          'match_minutes',greatest(0,coalesce(p_match_minutes,0)),
          'heat_index',greatest(0,coalesce(p_heat_index,0)),
          'proactive',true
        ),
        format('injury-risk:%s:%s:%s',p_player_id,v_abs,p_context)
      );
      update public.player_injury_risk_events set notified=true where id=v_event;
    end if;
  end if;

  return v_risk;
end;
$$;

create or replace function public.notify_injury_risk_if_needed_v1(
  p_player_id uuid,
  p_context text default 'general',
  p_intensity text default null
)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
begin
  return public.notify_injury_risk_if_needed_v2(p_player_id,p_context,p_intensity,0,0);
end;
$$;

create or replace function public.process_proactive_injury_risk_notifications_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  d record;
  c record;
  v_abs integer;
  v_game_minute integer;
  r record;
  w jsonb;
  v_training integer:=0;
  v_camp integer:=0;
  v_match integer:=0;
begin
  select * into d from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(d.season,d.month,d.day);
  select * into c from public.get_game_clock_v1() limit 1;
  v_game_minute:=floor(mod(c.game_total_seconds,86400)/60.0)::integer;

  for r in
    select p.id as player_id,coalesce(wp.intensity,'standard') as intensity
    from public.players p
    join public.player_weekly_training_plan_days wp on wp.player_id=p.id and wp.absolute_day=v_abs
    where p.player_type='human'
      and p.owner_user_id is not null
      and lower(coalesce(wp.training_type,'')) not in ('rest','full_rest','day_off','active_recovery')
      and not public.player_training_blocked_by_injury_v1(p.id,v_abs)
  loop
    perform public.notify_injury_risk_if_needed_v1(r.player_id,'regular_training',r.intensity);
    v_training:=v_training+1;
  end loop;

  for r in
    select distinct p.id as player_id
    from public.players p
    join public.player_training_camp_bookings b on b.player_id=p.id
    where p.player_type='human'
      and p.owner_user_id is not null
      and v_abs between b.start_absolute_day and b.end_absolute_day
      and lower(coalesce(b.status,'booked')) not in ('cancelled','completed')
      and not public.player_training_blocked_by_injury_v1(p.id,v_abs)
  loop
    perform public.notify_injury_risk_if_needed_v1(r.player_id,'training_camp','standard');
    v_camp:=v_camp+1;
  end loop;

  for r in
    select m.id as match_id,m.player1_id,m.player2_id,coalesce(m.estimated_duration_minutes,90) as estimated_minutes,m.scheduled_start_minute
    from public.tournament_matches m
    where m.status='scheduled'
      and m.player1_id is not null
      and m.player2_id is not null
      and public.tournament_match_absolute_day_v2(m.id)=v_abs
      and coalesce(m.scheduled_start_minute,600) between greatest(0,v_game_minute) and least(1439,v_game_minute+240)
  loop
    w:=public.calculate_tournament_match_weather_v1(r.match_id);

    if exists(select 1 from public.players p where p.id=r.player1_id and p.player_type='human' and p.owner_user_id is not null)
       and not public.player_tournament_blocked_by_injury_v1(r.player1_id,v_abs) then
      perform public.notify_injury_risk_if_needed_v2(
        r.player1_id,'match',null,r.estimated_minutes,coalesce((w->>'heat_index')::numeric,0)
      );
      v_match:=v_match+1;
    end if;

    if exists(select 1 from public.players p where p.id=r.player2_id and p.player_type='human' and p.owner_user_id is not null)
       and not public.player_tournament_blocked_by_injury_v1(r.player2_id,v_abs) then
      perform public.notify_injury_risk_if_needed_v2(
        r.player2_id,'match',null,r.estimated_minutes,coalesce((w->>'heat_index')::numeric,0)
      );
      v_match:=v_match+1;
    end if;
  end loop;

  return jsonb_build_object(
    'status','processed',
    'absolute_day',v_abs,
    'game_minute',v_game_minute,
    'training_checks',v_training,
    'camp_checks',v_camp,
    'match_checks',v_match
  );
end;
$$;

create or replace function public.roll_match_injury_on_completion_v1()
returns trigger
language plpgsql
security definer
set search_path='public'
as $$
declare
  sim public.tournament_match_simulations%rowtype;
  mins integer;
  w jsonb;
  heat numeric:=0;
begin
  if new.status<>'completed' or (tg_op='UPDATE' and old.status='completed') then return new;end if;
  if coalesce(new.schedule_reason,'') ilike '%walkover%' then return new;end if;

  select * into sim from public.tournament_match_simulations where match_id=new.id;
  if sim.match_id is null then return new;end if;

  mins:=coalesce((sim.metadata->>'estimated_match_minutes')::integer,90);
  w:=coalesce(sim.metadata->'weather',public.calculate_tournament_match_weather_v1(new.id));
  heat:=coalesce((w->>'heat_index')::numeric,0);

  if new.player1_id is not null then
    perform public.notify_injury_risk_if_needed_v2(new.player1_id,'match',null,mins,heat);
    perform public.roll_player_injury_v1(new.player1_id,'match',new.id,null,mins,heat);
  end if;
  if new.player2_id is not null then
    perform public.notify_injury_risk_if_needed_v2(new.player2_id,'match',null,mins,heat);
    perform public.roll_player_injury_v1(new.player2_id,'match',new.id,null,mins,heat);
  end if;
  return new;
end;
$$;

revoke all on function public.notify_injury_risk_if_needed_v2(uuid,text,text,integer,numeric) from public,anon;
revoke all on function public.process_proactive_injury_risk_notifications_v1() from public,anon;

grant execute on function public.notify_injury_risk_if_needed_v2(uuid,text,text,integer,numeric) to authenticated;

select cron.unschedule(jobid) from cron.job where jobname='tennis-injury-risk-proactive-v1';
select cron.schedule(
  'tennis-injury-risk-proactive-v1',
  '*/10 * * * *',
  $$select public.process_proactive_injury_risk_notifications_v1();$$
);
