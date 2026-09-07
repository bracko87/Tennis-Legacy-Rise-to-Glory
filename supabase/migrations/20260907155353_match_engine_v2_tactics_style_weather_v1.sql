create table if not exists public.tournament_match_weather (
  match_id uuid primary key references public.tournament_matches(id) on delete cascade,
  environment text not null,
  condition_label text not null,
  temperature_c numeric not null,
  wind_kmh numeric not null,
  precipitation text not null,
  heat_index numeric not null default 0,
  wind_index numeric not null default 0,
  generated_seed text not null,
  created_at timestamptz not null default now()
);

alter table public.tournament_match_weather enable row level security;
drop policy if exists tournament_match_weather_authenticated_read on public.tournament_match_weather;
create policy tournament_match_weather_authenticated_read
  on public.tournament_match_weather for select to authenticated using(true);
grant select on public.tournament_match_weather to authenticated;

create or replace function public.calculate_tournament_match_weather_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  m public.tournament_matches%rowtype;
  wc public.tournament_world_competitions%rowtype;
  ed public.tournament_editions%rowtype;
  ts public.tournament_series%rowtype;
  gd record;
  v_abs integer;
  v_month integer;
  v_lat numeric;
  v_seed text;
  r1 numeric;
  r2 numeric;
  r3 numeric;
  season_factor numeric;
  base_temp numeric;
  temp numeric;
  wind numeric;
  cond text;
  precip text;
  heat numeric;
  wind_idx numeric;
  env text;
begin
  select * into m from public.tournament_matches where id=p_match_id;
  if m.id is null then return jsonb_build_object('status','unavailable'); end if;

  select * into wc from public.tournament_world_competitions where id=m.competition_id;
  select * into ed from public.tournament_editions where id=wc.tournament_edition_id;
  select * into ts from public.tournament_series where id=ed.tournament_series_id;

  env:=lower(coalesce(ts.environment,'outdoor'));
  v_seed:=md5(p_match_id::text||':weather-v1');

  if env='indoor' then
    return jsonb_build_object(
      'status','ready','environment','indoor','condition','Indoor',
      'temperature_c',21,'wind_kmh',0,'precipitation','none',
      'heat_index',0,'wind_index',0,'seed',v_seed,
      'affects_match',false,'can_delay_match',false
    );
  end if;

  v_abs:=public.tournament_match_absolute_day_v2(p_match_id);
  select * into gd from public.absolute_game_day_v1(v_abs);
  v_month:=gd.month;
  v_lat:=coalesce(ts.latitude,20);
  r1:=public.match_engine_random_v1(v_seed,1);
  r2:=public.match_engine_random_v1(v_seed,2);
  r3:=public.match_engine_random_v1(v_seed,3);

  season_factor:=cos(2*pi()*(v_month-7)/12.0)*case when v_lat<0 then -1 else 1 end;
  base_temp:=23-greatest(0,abs(v_lat)-15)*0.10+season_factor*least(10,greatest(3,abs(v_lat)*0.18));
  temp:=round(greatest(7,least(39,base_temp+(r1-0.5)*8 + case when coalesce(m.scheduled_start_minute,720) between 720 and 1020 then 2 else 0 end))::numeric,1);
  wind:=round((3+r2*23)::numeric,1);

  if r3<0.08 then cond:='Light drizzle'; precip:='light_drizzle';
  elsif r3<0.28 then cond:='Cloudy'; precip:='none';
  elsif r3<0.58 then cond:='Partly cloudy'; precip:='none';
  elsif r3<0.82 then cond:='Sunny'; precip:='none';
  else cond:='Clear'; precip:='none';
  end if;

  heat:=round(greatest(0,least(0.55,(temp-29)/18 + case when cond='Sunny' and temp>=30 then 0.04 else 0 end))::numeric,3);
  wind_idx:=round(greatest(0,least(0.45,(wind-7)/42))::numeric,3);

  return jsonb_build_object(
    'status','ready','environment','outdoor','condition',cond,
    'temperature_c',temp,'wind_kmh',wind,'precipitation',precip,
    'heat_index',heat,'wind_index',wind_idx,'seed',v_seed,
    'affects_match',true,'can_delay_match',false
  );
end;
$$;

create or replace function public.ensure_tournament_match_weather_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare w jsonb;
begin
  select jsonb_build_object(
    'status','ready','environment',environment,'condition',condition_label,
    'temperature_c',temperature_c,'wind_kmh',wind_kmh,'precipitation',precipitation,
    'heat_index',heat_index,'wind_index',wind_index,'seed',generated_seed,
    'affects_match',environment='outdoor','can_delay_match',false
  ) into w
  from public.tournament_match_weather
  where match_id=p_match_id;

  if w is not null then return w; end if;
  w:=public.calculate_tournament_match_weather_v1(p_match_id);

  insert into public.tournament_match_weather(
    match_id,environment,condition_label,temperature_c,wind_kmh,
    precipitation,heat_index,wind_index,generated_seed
  ) values(
    p_match_id,w->>'environment',w->>'condition',(w->>'temperature_c')::numeric,
    (w->>'wind_kmh')::numeric,w->>'precipitation',(w->>'heat_index')::numeric,
    (w->>'wind_index')::numeric,w->>'seed'
  ) on conflict(match_id) do nothing;

  return w;
end;
$$;

create or replace function public.get_tournament_match_weather_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare w jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select jsonb_build_object(
    'status','ready','environment',environment,'condition',condition_label,
    'temperature_c',temperature_c,'wind_kmh',wind_kmh,'precipitation',precipitation,
    'heat_index',heat_index,'wind_index',wind_index,
    'affects_match',environment='outdoor','can_delay_match',false
  ) into w
  from public.tournament_match_weather
  where match_id=p_match_id;
  return coalesce(w,public.calculate_tournament_match_weather_v1(p_match_id));
end;
$$;

revoke all on function public.get_tournament_match_weather_v1(uuid) from public,anon;
grant execute on function public.get_tournament_match_weather_v1(uuid) to authenticated;

create or replace function public.get_effective_match_tactic_internal_v2(p_player_id uuid,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  m public.tournament_matches%rowtype;
  o public.player_tournament_match_tactics%rowtype;
  p public.player_tournament_preparation_plans%rowtype;
begin
  select * into m from public.tournament_matches where id=p_match_id;
  select * into o from public.player_tournament_match_tactics where player_id=p_player_id and match_id=p_match_id;
  if o.id is not null then
    return jsonb_build_object(
      'source','match_override','preset',o.tactic_preset,'approach',o.tactic_approach,
      'rally',o.tactic_rally,'serve',o.tactic_serve,'returnGame',o.tactic_return,
      'courtPosition',o.tactic_court_position,'target',o.tactic_target,'risk',o.tactic_risk
    );
  end if;

  select * into p from public.player_tournament_preparation_plans
  where player_id=p_player_id and competition_id=m.competition_id;
  if p.id is not null then
    return jsonb_build_object(
      'source','tournament_default','preset',p.tactic_preset,'approach',p.tactic_approach,
      'rally',p.tactic_rally,'serve',p.tactic_serve,'returnGame',p.tactic_return,
      'courtPosition',p.tactic_court_position,'target',p.tactic_target,'risk',p.tactic_risk
    );
  end if;

  return jsonb_build_object(
    'source','automatic_default','preset','Balanced','approach','Balanced',
    'rally','Balanced rallies','serve','Balanced','returnGame','Balanced',
    'courtPosition','Normal baseline','target','Automatic','risk','Balanced'
  );
end;
$$;

create or replace function public.get_match_engine_profile_for_match_v2(p_player_id uuid,p_surface text,p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  b jsonb;
  t jsonb;
  w jsonb;
  inj jsonb;
  style text;
  serve numeric;
  ret numeric;
  rally numeric;
  net numeric;
  fh numeric;
  bh numeric;
  vol numeric;
  slicev numeric;
  smash numeric;
  move numeric;
  stam numeric;
  focusv numeric;
  fat numeric;
  ue_delta numeric:=0;
  first_delta numeric:=0;
  ace_delta numeric:=0;
  df_delta numeric:=0;
  heat_pen numeric:=0;
  wind_pen numeric:=0;
  target text;
  approach text;
  rally_t text;
  serve_t text;
  return_t text;
  court_t text;
  risk_t text;
  skillmods jsonb;
  modv numeric;
begin
  b:=public.get_match_engine_profile_v1(p_player_id,p_surface);
  t:=public.get_effective_match_tactic_internal_v2(p_player_id,p_match_id);
  w:=public.calculate_tournament_match_weather_v1(p_match_id);
  inj:=public.get_player_active_injury_effects_v1(p_player_id,public.tournament_match_absolute_day_v2(p_match_id));

  style:=coalesce(b->>'playing_style','All-court');
  serve:=(b->'ratings'->>'serve')::numeric;
  ret:=(b->'ratings'->>'return')::numeric;
  rally:=(b->'ratings'->>'rally')::numeric;
  net:=(b->'ratings'->>'net')::numeric;
  fh:=(b->'technical'->>'forehand')::numeric;
  bh:=(b->'technical'->>'backhand')::numeric;
  vol:=(b->'technical'->>'volley')::numeric;
  slicev:=(b->'technical'->>'slice')::numeric;
  smash:=(b->'technical'->>'smash')::numeric;
  move:=(b->'physical'->>'movement')::numeric;
  stam:=(b->'physical'->>'stamina')::numeric;
  focusv:=(b->'condition'->>'focus')::numeric;
  fat:=(b->'condition'->>'fatigue')::numeric;

  if style='Aggressive Baseliner' then
    rally:=0.72*rally+0.28*(0.48*fh+0.34*bh+0.10*move+0.08*stam);
    serve:=serve+greatest(-0.8,least(1.0,(fh-50)*0.025));
    net:=net-0.35;
    ue_delta:=ue_delta+0.010;
  elsif style='Defensive Baseliner' then
    rally:=0.70*rally+0.30*(0.26*fh+0.26*bh+0.18*(b->'technical'->>'return_skill')::numeric+0.18*move+0.12*stam);
    ret:=ret+greatest(-0.5,least(1.1,(move+stam-100)*0.018));
    serve:=serve-0.25;
    ue_delta:=ue_delta-0.010;
  elsif style='Serve & Volley' then
    net:=0.55*net+0.45*(0.47*vol+0.25*smash+0.16*serve+0.12*move);
    serve:=serve+greatest(-0.7,least(1.2,(vol+smash-100)*0.018));
    rally:=0.82*rally+0.18*(0.30*fh+0.24*bh+0.20*slicev+0.14*vol+0.12*move);
    ue_delta:=ue_delta+0.005;
  end if;

  approach:=coalesce(t->>'approach','Balanced');
  rally_t:=coalesce(t->>'rally','Balanced rallies');
  serve_t:=coalesce(t->>'serve','Balanced');
  return_t:=coalesce(t->>'returnGame','Balanced');
  court_t:=coalesce(t->>'courtPosition','Normal baseline');
  target:=coalesce(t->>'target','Automatic');
  risk_t:=coalesce(t->>'risk','Balanced');

  if approach='Aggressive' then
    serve:=serve+0.35; rally:=rally+0.55; ret:=ret+0.20; ue_delta:=ue_delta+0.012;
  elsif approach='Conservative' then
    serve:=serve-0.25; rally:=rally+0.25; ret:=ret+0.30; ue_delta:=ue_delta-0.010;
  end if;

  if rally_t='Short points' then
    serve:=serve+0.35; net:=net+0.45; rally:=rally-0.15; ue_delta:=ue_delta+0.008;
  elsif rally_t='Long points' then
    rally:=rally+0.45+greatest(-0.25,least(0.35,(stam+move-100)*0.008));
    ret:=ret+0.25; serve:=serve-0.15; ue_delta:=ue_delta-0.004;
  end if;

  if serve_t='Aggressive first serve' then
    serve:=serve+0.65; first_delta:=first_delta-0.035; ace_delta:=ace_delta+0.018; df_delta:=df_delta+0.010;
  elsif serve_t='High percentage' then
    serve:=serve-0.30; first_delta:=first_delta+0.040; ace_delta:=ace_delta-0.010; df_delta:=df_delta-0.008;
  end if;

  if return_t='Attack second serve' then
    ret:=ret+0.55; ue_delta:=ue_delta+0.007;
  elsif return_t='Deep neutral return' then
    ret:=ret+0.28; ue_delta:=ue_delta-0.005;
  end if;

  if court_t='Step inside' then
    ret:=ret+0.18; net:=net+0.30; ue_delta:=ue_delta+0.005;
  elsif court_t='Deep baseline' then
    ret:=ret+0.20; rally:=rally+0.18; net:=net-0.15;
  end if;

  if risk_t='High risk' then
    serve:=serve+0.20; rally:=rally+0.25; ret:=ret+0.15; ue_delta:=ue_delta+0.022;
  elsif risk_t='Low risk' then
    serve:=serve-0.15; rally:=rally+0.05; ret:=ret+0.08; ue_delta:=ue_delta-0.020;
  end if;

  if w->>'environment'='outdoor' then
    heat_pen:=coalesce((w->>'heat_index')::numeric,0)*power(fat/100.0,1.45)*greatest(0.55,1-(stam-50)/160.0);
    serve:=serve*(1-heat_pen*0.035);
    ret:=ret*(1-heat_pen*0.045);
    rally:=rally*(1-heat_pen*0.055);
    net:=net*(1-heat_pen*0.030);

    wind_pen:=coalesce((w->>'wind_index')::numeric,0)*greatest(0.55,1-(focusv-50)/120.0);
    serve:=serve*(1-wind_pen*0.025);
    ret:=ret*(1-wind_pen*0.018);
    rally:=rally*(1-wind_pen*0.020);
    ue_delta:=ue_delta+wind_pen*0.018;

    if w->>'precipitation'='light_drizzle' then
      rally:=rally*0.996;
      net:=net*0.997;
      ue_delta:=ue_delta+0.003;
    end if;
  end if;

  skillmods:=coalesce(inj->'skill_modifiers','{}'::jsonb);
  modv:=coalesce((skillmods->>'serve')::numeric,0)+0.35*coalesce((skillmods->>'movement')::numeric,0);
  serve:=serve*(1+modv);

  modv:=coalesce((skillmods->>'return_skill')::numeric,0)
    +0.55*coalesce((skillmods->>'movement')::numeric,0)
    +0.15*coalesce((skillmods->>'backhand')::numeric,0)
    +0.15*coalesce((skillmods->>'forehand')::numeric,0);
  ret:=ret*(1+modv);

  modv:=0.30*coalesce((skillmods->>'forehand')::numeric,0)
    +0.30*coalesce((skillmods->>'backhand')::numeric,0)
    +0.25*coalesce((skillmods->>'movement')::numeric,0)
    +0.15*coalesce((skillmods->>'stamina')::numeric,0);
  rally:=rally*(1+modv);

  modv:=0.45*coalesce((skillmods->>'volley')::numeric,0)
    +0.30*coalesce((skillmods->>'smash')::numeric,0)
    +0.25*coalesce((skillmods->>'movement')::numeric,0);
  net:=net*(1+modv);

  b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round(serve,2)));
  b:=jsonb_set(b,'{ratings,return}',to_jsonb(round(ret,2)));
  b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round(rally,2)));
  b:=jsonb_set(b,'{ratings,net}',to_jsonb(round(net,2)));
  b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round(((serve+ret+rally+net)/4)*(b->'condition'->>'expression_multiplier')::numeric,2)));

  return b||jsonb_build_object(
    'match_tactic',t,
    'weather',w,
    'injury_effects',inj,
    'match_modifiers',jsonb_build_object(
      'ue_delta',round(ue_delta,4),
      'first_serve_delta',round(first_delta,4),
      'ace_delta',round(ace_delta,4),
      'double_fault_delta',round(df_delta,4),
      'target',target,
      'heat_penalty',round(heat_pen,4),
      'wind_penalty',round(wind_pen,4),
      'style',style
    )
  );
end;
$$;

create or replace function public.match_engine_first_serve_in_probability_v2(p_profile jsonb)
returns numeric language sql immutable set search_path='public' as $$
  select greatest(0.47,least(0.78,
    public.match_engine_first_serve_in_probability_v1(p_profile)
    +coalesce((p_profile->'match_modifiers'->>'first_serve_delta')::numeric,0)
  ));
$$;

create or replace function public.match_engine_double_fault_probability_v2(p_profile jsonb)
returns numeric language sql immutable set search_path='public' as $$
  select greatest(0.006,least(0.14,
    public.match_engine_double_fault_probability_v1(p_profile)
    +coalesce((p_profile->'match_modifiers'->>'double_fault_delta')::numeric,0)
  ));
$$;

create or replace function public.match_engine_ace_probability_v2(p_server jsonb,p_receiver jsonb,p_surface text)
returns numeric language sql immutable set search_path='public' as $$
  select greatest(0.003,least(0.20,
    public.match_engine_ace_probability_v1(p_server,p_receiver,p_surface)
    +coalesce((p_server->'match_modifiers'->>'ace_delta')::numeric,0)
  ));
$$;

create or replace function public.match_engine_server_point_probability_v2(
  p_server jsonb,p_receiver jsonb,p_total_points integer,p_max_points integer,p_surface text,p_first_serve boolean
)
returns numeric
language plpgsql
immutable
set search_path='public'
as $$
declare
  v numeric;
  target text;
  oppwing numeric;
  oppavg numeric;
  adj numeric:=0;
begin
  v:=public.match_engine_server_point_probability_v1(p_server,p_receiver,p_total_points,p_max_points,p_surface,p_first_serve);
  target:=coalesce(p_server->'match_modifiers'->>'target','Automatic');
  oppavg:=((p_receiver->'technical'->>'forehand')::numeric+(p_receiver->'technical'->>'backhand')::numeric)/2;

  if target='Forehand' then
    oppwing:=(p_receiver->'technical'->>'forehand')::numeric;
    adj:=greatest(-0.010,least(0.010,(oppavg-oppwing)*0.0015));
  elsif target='Backhand' then
    oppwing:=(p_receiver->'technical'->>'backhand')::numeric;
    adj:=greatest(-0.010,least(0.010,(oppavg-oppwing)*0.0015));
  end if;

  return greatest(0.36,least(0.90,v+adj));
end;
$$;

-- Clone the proven point engine, changing only the profile source, tactic/weather
-- helpers, deciding Grand Slam tiebreak target, and engine seed/version.
do $$
declare d text;
begin
  select pg_get_functiondef(oid) into d
  from pg_proc
  where pronamespace='public'::regnamespace and proname='simulate_tournament_match_raw_v1';

  d:=replace(d,'simulate_tournament_match_raw_v1','simulate_tournament_match_raw_v2');
  d:=replace(d,'public.get_match_engine_profile_v1(m.player1_id,ts.surface)','public.get_match_engine_profile_for_match_v2(m.player1_id,ts.surface,p_match_id)');
  d:=replace(d,'public.get_match_engine_profile_v1(m.player2_id,ts.surface)','public.get_match_engine_profile_for_match_v2(m.player2_id,ts.surface,p_match_id)');
  d:=replace(d,'public.match_engine_first_serve_in_probability_v1','public.match_engine_first_serve_in_probability_v2');
  d:=replace(d,'public.match_engine_double_fault_probability_v1','public.match_engine_double_fault_probability_v2');
  d:=replace(d,'public.match_engine_ace_probability_v1','public.match_engine_ace_probability_v2');
  d:=replace(d,'public.match_engine_server_point_probability_v1','public.match_engine_server_point_probability_v2');
  d:=replace(d,':base-v1.0',':base-v2.0');
  d:=replace(d,'''engine_version'',''base-v1.0''','''engine_version'',''base-v2.0''');
  d:=replace(
    d,
    'ue_prob:=greatest(0.10,least(0.34,0.22+loser_fatigue*0.0010-loser_sharp*0.0007-loser_focus*0.0004));',
    'ue_prob:=greatest(0.07,least(0.39,0.22+loser_fatigue*0.0010-loser_sharp*0.0007-loser_focus*0.0004+coalesce(((case when point_winner=1 then b else a end)->''match_modifiers''->>''ue_delta'')::numeric,0)));'
  );
  d:=replace(
    d,
    'exit when (tb1>=7 or tb2>=7) and abs(tb1-tb2)>=2;',
    'exit when (tb1>=case when ts.category_code=''grand_slam_2000'' and set_no=(2*sets_needed-1) then 10 else 7 end or tb2>=case when ts.category_code=''grand_slam_2000'' and set_no=(2*sets_needed-1) then 10 else 7 end) and abs(tb1-tb2)>=2;'
  );
  execute d;
end$$;

do $$
declare d text;
begin
  select pg_get_functiondef(oid) into d
  from pg_proc
  where pronamespace='public'::regnamespace and proname='simulate_tournament_match_v1';

  d:=replace(d,'simulate_tournament_match_v1','simulate_tournament_match_v2');
  d:=replace(d,'simulate_tournament_match_raw_v1','simulate_tournament_match_raw_v2');
  d:=replace(d,'''base-v1.1''','''base-v2.0''');
  d:=replace(d,'''winner / unforced error / forced error v1''','''winner / unforced error / forced error v2 · tactics/style/weather/injury aware''');
  execute d;
end$$;

create or replace function public.prepare_tournament_match_simulation_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  sim jsonb;
  existing public.tournament_match_simulations%rowtype;
  r jsonb;
  w jsonb;
begin
  select * into existing from public.tournament_match_simulations where match_id=p_match_id;
  if existing.match_id is not null then
    return jsonb_build_object('status',existing.simulation_status,'match_id',p_match_id,'already_exists',true);
  end if;

  w:=public.ensure_tournament_match_weather_v1(p_match_id);
  sim:=public.simulate_tournament_match_v2(p_match_id,null);
  sim:=jsonb_set(
    sim,
    '{metadata}',
    coalesce(sim->'metadata','{}'::jsonb)||jsonb_build_object(
      'weather',w,
      'engine_scope',jsonb_build_object(
        'tactics',true,'playing_style',true,'weather',true,'injuries',true,
        'equipment',false,'staff',false
      )
    )
  );

  r:=public.register_tournament_match_simulation_v1(
    p_match_id,sim->>'engine_version',sim->>'engine_seed',(sim->>'winner_id')::uuid,
    sim->'final_score',sim->'sets',sim->'player1_stats',sim->'player2_stats',sim->'events',
    (sim->>'replay_duration_seconds')::integer,(sim->>'total_points')::integer,
    (sim->>'total_games')::integer,sim->'metadata'
  );
  return r||jsonb_build_object('engine_version',sim->>'engine_version');
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
  if new.status<>'completed' or (tg_op='UPDATE' and old.status='completed') then return new; end if;
  select * into sim from public.tournament_match_simulations where match_id=new.id;
  mins:=coalesce((sim.metadata->>'estimated_match_minutes')::integer,90);
  w:=coalesce(sim.metadata->'weather',public.calculate_tournament_match_weather_v1(new.id));
  heat:=coalesce((w->>'heat_index')::numeric,0);
  if new.player1_id is not null then
    perform public.notify_injury_risk_if_needed_v1(new.player1_id,'match',null);
    perform public.roll_player_injury_v1(new.player1_id,'match',new.id,null,mins,heat);
  end if;
  if new.player2_id is not null then
    perform public.notify_injury_risk_if_needed_v1(new.player2_id,'match',null);
    perform public.roll_player_injury_v1(new.player2_id,'match',new.id,null,mins,heat);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_roll_match_injury_on_completion on public.tournament_matches;
create trigger trg_roll_match_injury_on_completion
  after update of status on public.tournament_matches
  for each row execute function public.roll_match_injury_on_completion_v1();

create or replace function public.get_tournament_match_engine_preview_v1(p_match_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path='public'
as $$
declare
  m public.tournament_matches%rowtype;
  sim public.tournament_match_simulations%rowtype;
  ts public.tournament_series%rowtype;
  wc public.tournament_world_competitions%rowtype;
  p1 jsonb;
  p2 jsonb;
  v_snapshot jsonb;
  w jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select * into m from public.tournament_matches where id=p_match_id;
  if m.id is null then return jsonb_build_object('status','unavailable'); end if;

  select wc0.* into wc from public.tournament_world_competitions wc0 where wc0.id=m.competition_id;
  select s.* into ts
  from public.tournament_world_competitions wc0
  join public.tournament_editions ed on ed.id=wc0.tournament_edition_id
  join public.tournament_series s on s.id=ed.tournament_series_id
  where wc0.id=m.competition_id;
  select * into sim from public.tournament_match_simulations where match_id=p_match_id;

  if sim.match_id is not null and sim.metadata ? 'profile_snapshot' then
    v_snapshot:=sim.metadata->'profile_snapshot';
    p1:=v_snapshot->'player1';
    p2:=v_snapshot->'player2';
    w:=coalesce(sim.metadata->'weather',public.calculate_tournament_match_weather_v1(p_match_id));
  elsif m.player1_id is not null and m.player2_id is not null then
    p1:=public.get_match_engine_profile_for_match_v2(m.player1_id,ts.surface,p_match_id);
    p2:=public.get_match_engine_profile_for_match_v2(m.player2_id,ts.surface,p_match_id);
    w:=public.calculate_tournament_match_weather_v1(p_match_id);
  else
    return jsonb_build_object('status','waiting_for_players','match_status',m.status);
  end if;

  return jsonb_build_object(
    'status','ready','match_status',m.status,'surface',lower(ts.surface),
    'world',wc.world,'category',ts.category_code,'weather',w,'player1',p1,'player2',p2,
    'comparison',jsonb_build_object(
      'player1_effective_level',(p1->'ratings'->>'effective_overall')::numeric,
      'player2_effective_level',(p2->'ratings'->>'effective_overall')::numeric,
      'difference',round((p1->'ratings'->>'effective_overall')::numeric-(p2->'ratings'->>'effective_overall')::numeric,2)
    ),
    'v2_scope',jsonb_build_object(
      'equipment',false,'staff',false,'weather',true,'injuries',true,
      'match_tactics',true,'playing_style_outcome_modifier',true,
      'playing_style_replay_flavour',true,'weather_can_delay',false
    )
  );
end;
$$;
