create table if not exists public.tournament_match_simulations (
  match_id uuid primary key references public.tournament_matches(id) on delete cascade,
  simulation_status text not null default 'prepared' check (simulation_status in ('prepared','live','completed','void')),
  engine_version text not null,
  engine_seed text not null,
  replay_schema_version smallint not null default 1,
  replay_duration_seconds integer not null check (replay_duration_seconds between 480 and 1800),
  total_points integer not null default 0 check (total_points >= 0),
  total_games integer not null default 0 check (total_games >= 0),
  final_winner_id uuid not null references public.players(id) on delete restrict,
  final_score jsonb not null default '{}'::jsonb,
  sets_payload jsonb not null default '[]'::jsonb,
  player1_stats jsonb not null default '{}'::jsonb,
  player2_stats jsonb not null default '{}'::jsonb,
  events_payload jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  generated_at timestamptz not null default now(),
  live_started_at timestamptz,
  live_ends_at timestamptz,
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(final_score)='object'),
  check (jsonb_typeof(sets_payload)='array'),
  check (jsonb_typeof(player1_stats)='object'),
  check (jsonb_typeof(player2_stats)='object'),
  check (jsonb_typeof(events_payload)='array'),
  check (jsonb_typeof(metadata)='object')
);
create index if not exists tournament_match_simulations_status_end_idx on public.tournament_match_simulations(simulation_status,live_ends_at);
alter table public.tournament_match_simulations enable row level security;
revoke all on public.tournament_match_simulations from public,anon,authenticated;

create or replace function public.calculate_match_replay_duration_v1(
  p_total_points integer,
  p_total_games integer,
  p_set_count integer,
  p_deuce_count integer default 0,
  p_tiebreak_count integer default 0,
  p_long_rally_points integer default 0
) returns integer
language sql immutable set search_path='public' as $$
  select greatest(480,least(1800,
    240
    + greatest(0,coalesce(p_total_points,0))*3
    + greatest(0,coalesce(p_total_games,0))*8
    + greatest(0,coalesce(p_deuce_count,0))*4
    + greatest(0,coalesce(p_tiebreak_count,0))*45
    + greatest(0,coalesce(p_set_count,0)-2)*90
    + greatest(0,coalesce(p_long_rally_points,0))*2
  ));
$$;
revoke all on function public.calculate_match_replay_duration_v1(integer,integer,integer,integer,integer,integer) from public,anon,authenticated;

create or replace function public.validate_match_replay_events_v1(p_events jsonb,p_duration integer)
returns boolean
language plpgsql immutable set search_path='public' as $$
declare v_count integer;v_prev integer;v_off integer;r record;
begin
  if jsonb_typeof(p_events)<>'array' then return false;end if;
  v_count:=jsonb_array_length(p_events);if v_count=0 then return false;end if;
  v_prev:=-1;
  for r in select value,ordinality from jsonb_array_elements(p_events) with ordinality loop
    if not (r.value ? 'offset_seconds') or coalesce(r.value->>'offset_seconds','') !~ '^[0-9]+$' then return false;end if;
    v_off:=(r.value->>'offset_seconds')::integer;
    if v_off<v_prev or v_off>p_duration then return false;end if;
    v_prev:=v_off;
  end loop;
  return true;
end;$$;
revoke all on function public.validate_match_replay_events_v1(jsonb,integer) from public,anon,authenticated;

create or replace function public.register_tournament_match_simulation_v1(
  p_match_id uuid,
  p_engine_version text,
  p_engine_seed text,
  p_final_winner_id uuid,
  p_final_score jsonb,
  p_sets jsonb,
  p_player1_stats jsonb,
  p_player2_stats jsonb,
  p_events jsonb,
  p_replay_duration_seconds integer,
  p_total_points integer default 0,
  p_total_games integer default 0,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare m public.tournament_matches%rowtype;
begin
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.';end if;
  if m.status<>'scheduled' then raise exception 'Only scheduled matches can receive a simulation.';end if;
  if m.player1_id is null or m.player2_id is null then raise exception 'Both players must be known before simulation.';end if;
  if p_final_winner_id not in (m.player1_id,m.player2_id) then raise exception 'Winner must be one of the match players.';end if;
  if p_replay_duration_seconds not between 480 and 1800 then raise exception 'Replay duration must be between 480 and 1800 seconds.';end if;
  if not public.validate_match_replay_events_v1(p_events,p_replay_duration_seconds) then raise exception 'Replay events are invalid.';end if;
  if jsonb_typeof(p_sets)<>'array' or jsonb_array_length(p_sets)=0 then raise exception 'Set payload is required.';end if;
  if jsonb_typeof(p_player1_stats)<>'object' or jsonb_typeof(p_player2_stats)<>'object' then raise exception 'Player stats must be JSON objects.';end if;
  insert into public.tournament_match_simulations(match_id,engine_version,engine_seed,replay_duration_seconds,total_points,total_games,final_winner_id,final_score,sets_payload,player1_stats,player2_stats,events_payload,metadata)
  values(p_match_id,trim(p_engine_version),trim(p_engine_seed),p_replay_duration_seconds,greatest(0,coalesce(p_total_points,0)),greatest(0,coalesce(p_total_games,0)),p_final_winner_id,coalesce(p_final_score,'{}'::jsonb),p_sets,p_player1_stats,p_player2_stats,p_events,coalesce(p_metadata,'{}'::jsonb));
  return jsonb_build_object('status','prepared','match_id',p_match_id,'duration_seconds',p_replay_duration_seconds);
end;$$;
revoke all on function public.register_tournament_match_simulation_v1(uuid,text,text,uuid,jsonb,jsonb,jsonb,jsonb,jsonb,integer,integer,integer,jsonb) from public,anon,authenticated;

create or replace function public.get_due_unsimulated_matches_v1()
returns table(match_id uuid,competition_id uuid,scheduled_absolute_second bigint,player1_id uuid,player2_id uuid,surface text,round_label text)
language sql stable security definer set search_path='public' as $$
  select m.id,m.competition_id,
    ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*86400 + coalesce(m.scheduled_start_minute,600)::bigint*60),
    m.player1_id,m.player2_id,ts.surface,m.round_label
  from public.tournament_matches m
  join public.tournament_world_competitions wc on wc.id=m.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  left join public.tournament_match_simulations sim on sim.match_id=m.id
  cross join lateral (select game_total_seconds from public.get_game_clock_v1() limit 1) clk
  where m.status='scheduled' and m.player1_id is not null and m.player2_id is not null
    and sim.match_id is null
    and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*86400 + coalesce(m.scheduled_start_minute,600)::bigint*60)<=clk.game_total_seconds
  order by 3,m.id;
$$;
revoke all on function public.get_due_unsimulated_matches_v1() from public,anon,authenticated;

create or replace function public.start_due_match_replays_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare r record;v_count integer:=0;v_game bigint;
begin
  select game_total_seconds into v_game from public.get_game_clock_v1() limit 1;
  for r in
    select sim.match_id,sim.replay_duration_seconds
    from public.tournament_match_simulations sim
    join public.tournament_matches m on m.id=sim.match_id
    join public.tournament_world_competitions wc on wc.id=m.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where sim.simulation_status='prepared' and m.status='scheduled'
      and m.player1_id is not null and m.player2_id is not null
      and ((((ed.season_number-1)*366)+2+((m.scheduled_season_week-1)*7)+(m.scheduled_day-1))::bigint*86400 + coalesce(m.scheduled_start_minute,600)::bigint*60)<=v_game
    order by m.scheduled_season_week,m.scheduled_day,m.scheduled_start_minute,m.court_number
    for update of sim skip locked
  loop
    update public.tournament_match_simulations
      set simulation_status='live',live_started_at=now(),live_ends_at=now()+make_interval(secs=>r.replay_duration_seconds),updated_at=now()
      where match_id=r.match_id and simulation_status='prepared';
    update public.tournament_matches set status='in_progress',started_at=coalesce(started_at,now()),updated_at=now()
      where id=r.match_id and status='scheduled';
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('status','processed','started',v_count);
end;$$;
revoke all on function public.start_due_match_replays_v1() from public,anon,authenticated;

create or replace function public.finalize_match_replay_v1(p_match_id uuid)
returns jsonb language plpgsql security definer set search_path='public' as $$
declare s public.tournament_match_simulations%rowtype;m public.tournament_matches%rowtype;x jsonb;st1 jsonb;st2 jsonb;
begin
  select * into s from public.tournament_match_simulations where match_id=p_match_id for update;
  if s.match_id is null then raise exception 'Simulation not found.';end if;
  if s.simulation_status='completed' then return jsonb_build_object('status','already_completed');end if;
  if s.simulation_status<>'live' or s.live_ends_at is null or now()<s.live_ends_at then return jsonb_build_object('status','not_due');end if;
  select * into m from public.tournament_matches where id=p_match_id for update;
  if m.id is null then raise exception 'Match not found.';end if;
  if m.status not in ('in_progress','scheduled') then raise exception 'Match cannot be finalized from status %.',m.status;end if;

  for x in select value from jsonb_array_elements(s.sets_payload) loop
    insert into public.tournament_match_sets(match_id,set_number,player1_games,player2_games,player1_tiebreak_points,player2_tiebreak_points,status)
    values(p_match_id,(x->>'set_number')::smallint,coalesce((x->>'player1_games')::smallint,0),coalesce((x->>'player2_games')::smallint,0),nullif(x->>'player1_tiebreak_points','')::smallint,nullif(x->>'player2_tiebreak_points','')::smallint,'completed')
    on conflict(match_id,set_number) do update set player1_games=excluded.player1_games,player2_games=excluded.player2_games,player1_tiebreak_points=excluded.player1_tiebreak_points,player2_tiebreak_points=excluded.player2_tiebreak_points,status='completed',updated_at=now();
  end loop;

  st1:=s.player1_stats;st2:=s.player2_stats;
  insert into public.tournament_match_player_stats(match_id,player_id,aces,double_faults,first_serves_in,first_serves_total,first_serve_points_won,first_serve_points_played,second_serve_points_won,second_serve_points_played,break_points_won,break_points_total,winners,unforced_errors,total_points_won)
  values(p_match_id,m.player1_id,coalesce((st1->>'aces')::int,0),coalesce((st1->>'double_faults')::int,0),coalesce((st1->>'first_serves_in')::int,0),coalesce((st1->>'first_serves_total')::int,0),coalesce((st1->>'first_serve_points_won')::int,0),coalesce((st1->>'first_serve_points_played')::int,0),coalesce((st1->>'second_serve_points_won')::int,0),coalesce((st1->>'second_serve_points_played')::int,0),coalesce((st1->>'break_points_won')::int,0),coalesce((st1->>'break_points_total')::int,0),coalesce((st1->>'winners')::int,0),coalesce((st1->>'unforced_errors')::int,0),coalesce((st1->>'total_points_won')::int,0))
  on conflict(match_id,player_id) do update set aces=excluded.aces,double_faults=excluded.double_faults,first_serves_in=excluded.first_serves_in,first_serves_total=excluded.first_serves_total,first_serve_points_won=excluded.first_serve_points_won,first_serve_points_played=excluded.first_serve_points_played,second_serve_points_won=excluded.second_serve_points_won,second_serve_points_played=excluded.second_serve_points_played,break_points_won=excluded.break_points_won,break_points_total=excluded.break_points_total,winners=excluded.winners,unforced_errors=excluded.unforced_errors,total_points_won=excluded.total_points_won,updated_at=now();

  insert into public.tournament_match_player_stats(match_id,player_id,aces,double_faults,first_serves_in,first_serves_total,first_serve_points_won,first_serve_points_played,second_serve_points_won,second_serve_points_played,break_points_won,break_points_total,winners,unforced_errors,total_points_won)
  values(p_match_id,m.player2_id,coalesce((st2->>'aces')::int,0),coalesce((st2->>'double_faults')::int,0),coalesce((st2->>'first_serves_in')::int,0),coalesce((st2->>'first_serves_total')::int,0),coalesce((st2->>'first_serve_points_won')::int,0),coalesce((st2->>'first_serve_points_played')::int,0),coalesce((st2->>'second_serve_points_won')::int,0),coalesce((st2->>'second_serve_points_played')::int,0),coalesce((st2->>'break_points_won')::int,0),coalesce((st2->>'break_points_total')::int,0),coalesce((st2->>'winners')::int,0),coalesce((st2->>'unforced_errors')::int,0),coalesce((st2->>'total_points_won')::int,0))
  on conflict(match_id,player_id) do update set aces=excluded.aces,double_faults=excluded.double_faults,first_serves_in=excluded.first_serves_in,first_serves_total=excluded.first_serves_total,first_serve_points_won=excluded.first_serve_points_won,first_serve_points_played=excluded.first_serve_points_played,second_serve_points_won=excluded.second_serve_points_won,second_serve_points_played=excluded.second_serve_points_played,break_points_won=excluded.break_points_won,break_points_total=excluded.break_points_total,winners=excluded.winners,unforced_errors=excluded.unforced_errors,total_points_won=excluded.total_points_won,updated_at=now();

  update public.tournament_match_simulations set simulation_status='completed',finalized_at=now(),updated_at=now() where match_id=p_match_id;
  update public.tournament_matches set winner_id=s.final_winner_id,status='completed',completed_at=now(),updated_at=now() where id=p_match_id;
  return jsonb_build_object('status','completed','match_id',p_match_id,'winner_id',s.final_winner_id);
end;$$;
revoke all on function public.finalize_match_replay_v1(uuid) from public,anon,authenticated;

create or replace function public.finalize_due_match_replays_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare r record;v_count integer:=0;v_result jsonb;
begin
  for r in select match_id from public.tournament_match_simulations where simulation_status='live' and live_ends_at<=now() order by live_ends_at for update skip locked loop
    v_result:=public.finalize_match_replay_v1(r.match_id);
    if v_result->>'status'='completed' then v_count:=v_count+1;end if;
  end loop;
  return jsonb_build_object('status','processed','completed',v_count);
end;$$;
revoke all on function public.finalize_due_match_replays_v1() from public,anon,authenticated;

create or replace function public.process_match_replay_clock_v1()
returns jsonb language plpgsql security definer set search_path='public' as $$
declare a jsonb;b jsonb;
begin
  a:=public.start_due_match_replays_v1();
  b:=public.finalize_due_match_replays_v1();
  return jsonb_build_object('started',coalesce((a->>'started')::int,0),'completed',coalesce((b->>'completed')::int,0));
end;$$;
revoke all on function public.process_match_replay_clock_v1() from public,anon,authenticated;

create or replace function public.get_tournament_match_replay_v1(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare s public.tournament_match_simulations%rowtype;m public.tournament_matches%rowtype;p1 text;p2 text;v_elapsed integer:=0;v_events jsonb:='[]'::jsonb;v_complete boolean:=false;v_last jsonb;v_remaining integer:=0;
begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  select * into m from public.tournament_matches where id=p_match_id;
  if m.id is null then return jsonb_build_object('status','unavailable');end if;
  select concat_ws(' ',a.first_name,a.last_name),concat_ws(' ',b.first_name,b.last_name) into p1,p2 from public.players a,public.players b where a.id=m.player1_id and b.id=m.player2_id;
  select * into s from public.tournament_match_simulations where match_id=p_match_id;
  if s.match_id is null then return jsonb_build_object('status','unavailable','match_status',m.status,'player1_name',p1,'player2_name',p2);end if;
  if s.simulation_status='live' then
    v_elapsed:=greatest(0,least(s.replay_duration_seconds,floor(extract(epoch from (now()-s.live_started_at)))::integer));
    select coalesce(jsonb_agg(value order by ordinality),'[]'::jsonb) into v_events from jsonb_array_elements(s.events_payload) with ordinality where coalesce((value->>'offset_seconds')::int,0)<=v_elapsed;
    v_remaining:=greatest(0,s.replay_duration_seconds-v_elapsed);
  elsif s.simulation_status='completed' then
    v_elapsed:=s.replay_duration_seconds;v_events:=s.events_payload;v_complete:=true;
  end if;
  if jsonb_array_length(v_events)>0 then v_last:=v_events->(jsonb_array_length(v_events)-1);end if;
  return jsonb_build_object(
    'status',s.simulation_status,
    'match_status',m.status,
    'controls_locked',not v_complete,
    'historical_replay',v_complete,
    'speed',case when v_complete then null else 1 end,
    'server_now',now(),
    'live_started_at',s.live_started_at,
    'live_ends_at',s.live_ends_at,
    'replay_duration_seconds',s.replay_duration_seconds,
    'elapsed_seconds',v_elapsed,
    'remaining_seconds',v_remaining,
    'player1_id',m.player1_id,'player1_name',p1,
    'player2_id',m.player2_id,'player2_name',p2,
    'events',v_events,
    'last_event',v_last,
    'final_score',case when v_complete then s.final_score else null end,
    'winner_id',case when v_complete then s.final_winner_id else null end,
    'engine_version',case when v_complete then s.engine_version else null end
  );
end;$$;
grant execute on function public.get_tournament_match_replay_v1(uuid) to authenticated;
revoke all on function public.get_tournament_match_replay_v1(uuid) from anon;

do $$begin
  if exists(select 1 from cron.job where jobname='tennis-match-replay-clock-v1') then perform cron.unschedule((select jobid from cron.job where jobname='tennis-match-replay-clock-v1' limit 1));end if;
  perform cron.schedule('tennis-match-replay-clock-v1','* * * * *','select public.process_match_replay_clock_v1();');
end$$;
