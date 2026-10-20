-- Premium tournament application watchlist. Source-only: deploy only with owner's explicit authorization.
-- Works from the authoritative tournament entry timeline and global game clock.
create table if not exists public.player_premium_tournament_watches (
  player_id uuid not null references public.players(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (player_id, competition_id)
);
create index if not exists player_premium_tournament_watches_comp_idx
  on public.player_premium_tournament_watches(competition_id);
alter table public.player_premium_tournament_watches enable row level security;
-- RPC-only access, no policies granting direct API access.
revoke all on public.player_premium_tournament_watches from public, anon, authenticated;

insert into public.notification_catalog(
  code, category, label, reason, trigger_event, trigger_condition,
  trigger_mechanism, source_name, title_template, message_template,
  default_route, severity, default_in_app, default_email, default_push,
  is_user_configurable, is_active
) values (
  'tournament.application.watch_open', 'tournament',
  'Watched tournament applications open',
  'Premium manager explicitly starred a tournament to receive its opening reminder',
  'Tournament normal application window opens',
  'A watched event is open, the player has no active application or entry, and Premium is active',
  'Idempotent server cron job, using the authoritative in-game tournament entry timeline',
  'Premium Tournament Watchlist', 'Applications open · {{tournament_name}}',
  'Your watched tournament is accepting applications. Open the tournament to apply before the deadline.',
  '/game/calendar?tab=tournament-calendar', 'warning', true, false, false,
  true, true
)
on conflict(code) do update set
  category=excluded.category, label=excluded.label, reason=excluded.reason,
  trigger_event=excluded.trigger_event, trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism, source_name=excluded.source_name,
  title_template=excluded.title_template, message_template=excluded.message_template,
  default_route=excluded.default_route, severity=excluded.severity,
  default_in_app=excluded.default_in_app, default_email=excluded.default_email,
  default_push=excluded.default_push, is_user_configurable=excluded.is_user_configurable,
  is_active=excluded.is_active, updated_at=now();

create or replace function public.get_premium_tournament_watchlist_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path='public','pg_temp'
as $function$
declare
  v_player public.players%rowtype;
  v_now bigint;
  v_season integer;
  v_items jsonb;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium membership required for tournament watchlist' using errcode='42501';
  end if;
  select * into v_player from public.players p
  where p.id=p_player_id and p.owner_user_id=auth.uid()
    and p.player_type='human' and p.moderation_status<>'rejected';
  if not found then raise exception 'Watchlist belongs to your career' using errcode='42501'; end if;
  select game_total_seconds into v_now from public.get_game_clock_v1();
  v_season := floor(v_now / (366 * 86400))::integer + 1;

  with watched as (
    select w.competition_id,ts.name,ts.city,ts.category_code,e.season_number,
      wc.status as competition_status,e.status as edition_status,ts.is_active,
      x.timeline,
      exists(select 1 from public.tournament_applications a
        where a.competition_id=w.competition_id and a.player_id=p_player_id
          and a.status in ('applied','accepted_main_draw','accepted_qualification')) as already_applied,
      exists(select 1 from public.tournament_entries te
        where te.competition_id=w.competition_id and te.player_id=p_player_id
          and te.entry_status='active') as already_entered
    from public.player_premium_tournament_watches w
    join public.tournament_world_competitions wc on wc.id=w.competition_id
    join public.tournament_editions e on e.id=wc.tournament_edition_id
    join public.tournament_series ts on ts.id=e.tournament_series_id
    left join lateral (
      select public.get_tournament_entry_timeline_v1(w.competition_id) timeline
      where wc.status<>'canceled' and e.status<>'canceled' and ts.is_active
    ) x on true
    where w.player_id=p_player_id and wc.world=v_player.world and e.season_number=v_season
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'competition_id',competition_id,'name',name,'city',city,'category_code',category_code,
    'season',season_number,'open_game_second',(timeline->>'applications_open_game_second')::bigint,
    'close_game_second',(timeline->>'normal_close_game_second')::bigint,
    'already_applied',already_applied or already_entered,
    'status',case
      when timeline is null then 'canceled'
      when already_applied or already_entered then 'applied'
      when v_now<(timeline->>'applications_open_game_second')::bigint then 'upcoming'
      when v_now<(timeline->>'normal_close_game_second')::bigint then 'open'
      else 'closed' end
  ) order by (timeline->>'applications_open_game_second')::bigint,name),'[]'::jsonb)
  into v_items from watched;
  return jsonb_build_object(
    'player_id',p_player_id,'season',v_season,'now_game_second',v_now,
    'limit',60,'watches',v_items
  );
end;
$function$;

create or replace function public.set_premium_tournament_watch_v1(
  p_player_id uuid, p_competition_id uuid, p_watch boolean
) returns jsonb
language plpgsql volatile security definer
set search_path='public','pg_temp'
as $function$
declare
  v_world text;v_game_second bigint;v_season integer;v_tournament_season integer;
  v_tournament_world text;v_status text;v_edition_status text;v_active boolean;
  v_timeline jsonb;v_count integer;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium membership required for tournament watchlist' using errcode='42501';
  end if;
  select p.world into v_world from public.players p
  where p.id=p_player_id and p.owner_user_id=auth.uid()
    and p.player_type='human' and p.moderation_status<>'rejected'
  for update;
  if not found then raise exception 'Not your career' using errcode='42501'; end if;
  if p_competition_id is null or p_watch is null then raise exception 'Invalid watchlist request'; end if;

  if not p_watch then
    delete from public.player_premium_tournament_watches
    where player_id=p_player_id and competition_id=p_competition_id;
    return jsonb_build_object('saved',true,'watching',false,'competition_id',p_competition_id);
  end if;

  select e.season_number,wc.world,wc.status,e.status,ts.is_active
  into v_tournament_season,v_tournament_world,v_status,v_edition_status,v_active
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=e.tournament_series_id
  where wc.id=p_competition_id;
  select game_total_seconds into v_game_second from public.get_game_clock_v1();
  v_season:=floor(v_game_second/(366*86400))::integer+1;
  if v_tournament_season is distinct from v_season
     or v_tournament_world is distinct from v_world
     or v_status='canceled' or v_edition_status='canceled' or not coalesce(v_active,false) then
    raise exception 'Unavailable tournament for this season and player';
  end if;
  v_timeline:=public.get_tournament_entry_timeline_v1(p_competition_id);
  if v_game_second >= (v_timeline->>'applications_open_game_second')::bigint then
    raise exception 'Application window has started; only future openings can be watched';
  end if;
  if exists(select 1 from public.tournament_applications a
    where a.competition_id=p_competition_id and a.player_id=p_player_id
      and a.status in('applied','accepted_main_draw','accepted_qualification'))
    or exists(select 1 from public.tournament_entries te
      where te.competition_id=p_competition_id and te.player_id=p_player_id and te.entry_status='active')
  then raise exception 'You already applied to this tournament'; end if;
  select count(*)::integer into v_count from public.player_premium_tournament_watches tw
  join public.tournament_world_competitions wc on wc.id=tw.competition_id
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  where tw.player_id=p_player_id and e.season_number=v_season;
  if v_count>=60 and not exists(select 1 from public.player_premium_tournament_watches
    where player_id=p_player_id and competition_id=p_competition_id) then
    raise exception 'Maximum 60 watched tournaments per game season';
  end if;
  insert into public.player_premium_tournament_watches(player_id,competition_id)
  values(p_player_id,p_competition_id)
  on conflict(player_id,competition_id) do nothing;
  return jsonb_build_object('saved',true,'watching',true,'competition_id',p_competition_id);
end;
$function$;

-- Server-side processor: persists reminders even when the player is offline.
-- Idempotent via user_notifications(user_id,event_key) unique index. Never submits entries.
create or replace function public.process_premium_tournament_watch_openings_v1()
returns jsonb
language plpgsql volatile security definer
set search_path='public','pg_temp'
as $function$
declare
  v_now bigint;v_attempts integer:=0;v_sent integer:=0;
  v_open bigint;v_close bigint;v_timeline jsonb;v_id uuid;
  r record;
begin
  select game_total_seconds into v_now from public.get_game_clock_v1();
  for r in
    select tw.player_id,tw.competition_id,p.owner_user_id,ts.name,e.season_number
    from public.player_premium_tournament_watches tw
    join public.players p on p.id=tw.player_id and p.player_type='human'
      and p.owner_user_id is not null and p.moderation_status<>'rejected'
    join public.tournament_world_competitions wc on wc.id=tw.competition_id
      and wc.world=p.world and wc.status<>'canceled'
    join public.tournament_editions e on e.id=wc.tournament_edition_id and e.status<>'canceled'
    join public.tournament_series ts on ts.id=e.tournament_series_id and ts.is_active
    join lateral public.get_competition_window_v1(tw.competition_id) win on true
    where e.season_number=floor(v_now/(366*86400))::integer+1
      -- Only tournaments near their normal application period: prevents older
      -- and distant starred events from starving due reminders in the batch.
      and win.start_absolute_day between floor(v_now/86400)::integer+6
        and floor(v_now/86400)::integer+22
      and (exists(select 1 from public.premium_memberships pm
        where pm.user_id=p.owner_user_id and pm.plan_code='premium' and pm.status='active'
          and (pm.current_period_end is null or pm.current_period_end>now()))
        or exists(select 1 from public.tennis_premium_trials_v1 tr
          where tr.user_id=p.owner_user_id and tr.expires_at>now()))
      and not exists(select 1 from public.tournament_applications a
        where a.player_id=tw.player_id and a.competition_id=tw.competition_id
          and a.status in('applied','accepted_main_draw','accepted_qualification'))
      and not exists(select 1 from public.tournament_entries te
        where te.player_id=tw.player_id and te.competition_id=tw.competition_id
          and te.entry_status='active')
      and not exists(select 1 from public.user_notifications n
        where n.user_id=p.owner_user_id
          and n.event_key='premium-watch-open:'||tw.player_id::text||':'||tw.competition_id::text)
    order by tw.created_at
    limit 1500
  loop
    v_timeline:=public.get_tournament_entry_timeline_v1(r.competition_id);
    v_open:=(v_timeline->>'applications_open_game_second')::bigint;
    v_close:=(v_timeline->>'normal_close_game_second')::bigint;
    if v_now>=v_open and v_now<v_close then
      v_attempts:=v_attempts+1;
      v_id:=public.emit_notification_v1(
        r.owner_user_id,r.player_id,'tournament.application.watch_open',
        'Tournament applications open · '||r.name,
        'The application window is open for '||r.name||'. Apply before it closes.',
        '/game/tournaments/'||r.competition_id::text,
        jsonb_build_object(
          'competition_id',r.competition_id,'tournament_name',r.name,
          'season',r.season_number,'application_open_day',floor(v_open/86400),
          'application_close_day',floor(v_close/86400),
          'action_url','/game/tournaments/'||r.competition_id::text
        ),
        'premium-watch-open:'||r.player_id::text||':'||r.competition_id::text
      );
      if v_id is not null then v_sent:=v_sent+1; end if;
    end if;
  end loop;
  return jsonb_build_object('checked_open',v_attempts,'notifications_sent',v_sent);
end;
$function$;

revoke all on function public.get_premium_tournament_watchlist_v1(uuid) from public,anon,authenticated;
revoke all on function public.set_premium_tournament_watch_v1(uuid,uuid,boolean) from public,anon,authenticated;
revoke all on function public.process_premium_tournament_watch_openings_v1() from public,anon,authenticated;
grant execute on function public.get_premium_tournament_watchlist_v1(uuid) to authenticated;
grant execute on function public.set_premium_tournament_watch_v1(uuid,uuid,boolean) to authenticated;
-- Cron runs with its privileged database role; the processor is NOT exposed through the Data API.
-- Every five real minutes (up to ten in-game minutes at 2x speed).
select cron.schedule(
  'tennis-premium-tournament-watch-openings-v1',
  '*/5 * * * *',
  'select public.process_premium_tournament_watch_openings_v1();'
);
