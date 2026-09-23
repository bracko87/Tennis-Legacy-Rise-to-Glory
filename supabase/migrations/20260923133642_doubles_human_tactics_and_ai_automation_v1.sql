
-- Doubles match tactics: human managers control their own player while AI
-- partners/opponents use automatic playing-style tactics.

create table if not exists public.player_doubles_match_tactics (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  player_id uuid not null references public.players(id) on delete cascade,
  match_id uuid not null references public.tournament_doubles_matches(id) on delete cascade,
  tactic_preset text not null,
  tactic_approach text not null,
  tactic_rally text not null,
  tactic_serve text not null,
  tactic_return text not null,
  tactic_court_position text not null,
  tactic_target text not null,
  tactic_risk text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id,match_id)
);

alter table public.player_doubles_match_tactics enable row level security;

drop policy if exists player_doubles_match_tactics_own_read
on public.player_doubles_match_tactics;
create policy player_doubles_match_tactics_own_read
on public.player_doubles_match_tactics
for select to authenticated
using(owner_user_id=auth.uid());

revoke insert,update,delete on public.player_doubles_match_tactics from authenticated;
grant select on public.player_doubles_match_tactics to authenticated;

create or replace function public.get_automatic_doubles_tactic_v1(p_player_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_style text;
begin
  select playing_style into v_style
  from public.players
  where id=p_player_id;

  if v_style='Aggressive Baseliner' then
    return jsonb_build_object(
      'source','ai_automatic','preset','Attack','approach','Aggressive',
      'rally','Shorten points','serve','Serve + 1','returnGame','Aggressive return',
      'courtPosition','Inside baseline','target','Automatic','risk','Aggressive'
    );
  elsif v_style='Defensive Baseliner' then
    return jsonb_build_object(
      'source','ai_automatic','preset','Counterpunch','approach','Defensive',
      'rally','Extend rallies','serve','Safe first serve','returnGame','Safe return',
      'courtPosition','Deep baseline','target','Automatic','risk','Safe'
    );
  elsif v_style='Serve & Volley' then
    return jsonb_build_object(
      'source','ai_automatic','preset','Net Attack','approach','Aggressive',
      'rally','Shorten points','serve','Power serving','returnGame','Aggressive return',
      'courtPosition','Net attack','target','Automatic','risk','Aggressive'
    );
  end if;

  return jsonb_build_object(
    'source','ai_automatic','preset','Balanced','approach','Balanced',
    'rally','Balanced rallies','serve','Balanced','returnGame','Balanced',
    'courtPosition','Normal baseline','target','Automatic','risk','Balanced'
  );
end;
$$;

create or replace function public.get_effective_doubles_match_tactic_internal_v1(
  p_player_id uuid,
  p_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  o public.player_doubles_match_tactics%rowtype;
  p public.players%rowtype;
begin
  select * into o
  from public.player_doubles_match_tactics
  where player_id=p_player_id and match_id=p_match_id;

  if o.id is not null then
    return jsonb_build_object(
      'source','match_override',
      'preset',o.tactic_preset,
      'approach',o.tactic_approach,
      'rally',o.tactic_rally,
      'serve',o.tactic_serve,
      'returnGame',o.tactic_return,
      'courtPosition',o.tactic_court_position,
      'target',o.tactic_target,
      'risk',o.tactic_risk
    );
  end if;

  select * into p from public.players where id=p_player_id;
  if p.player_type='ai' then
    return public.get_automatic_doubles_tactic_v1(p_player_id);
  end if;

  return jsonb_build_object(
    'source','automatic_default','preset','Balanced','approach','Balanced',
    'rally','Balanced rallies','serve','Balanced','returnGame','Balanced',
    'courtPosition','Normal baseline','target','Automatic','risk','Balanced'
  );
end;
$$;

create or replace function public.get_tournament_doubles_match_tactic_v1(
  p_player_id uuid,
  p_match_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  m public.tournament_doubles_matches%rowtype;
  t1 public.tournament_doubles_teams%rowtype;
  t2 public.tournament_doubles_teams%rowtype;
  o public.player_doubles_match_tactics%rowtype;
  v_partner uuid;
  v_partner_name text;
  v_effective jsonb;
  v_partner_tactic jsonb;
  v_lock bigint;
  v_editable boolean;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  if not exists(
    select 1 from public.players
    where id=p_player_id and owner_user_id=v_uid
  ) then
    raise exception 'You can only manage tactics for your own player.';
  end if;

  select * into m
  from public.tournament_doubles_matches
  where id=p_match_id;

  if m.id is null then raise exception 'Doubles match unavailable.'; end if;

  select * into t1 from public.tournament_doubles_teams where id=m.team1_id;
  select * into t2 from public.tournament_doubles_teams where id=m.team2_id;

  if p_player_id not in (t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id) then
    raise exception 'Your player is not participating in this doubles match.';
  end if;

  if p_player_id=t1.player1_id then v_partner:=t1.player2_id;
  elsif p_player_id=t1.player2_id then v_partner:=t1.player1_id;
  elsif p_player_id=t2.player1_id then v_partner:=t2.player2_id;
  else v_partner:=t2.player1_id;
  end if;

  select trim(first_name||' '||last_name)
  into v_partner_name
  from public.players where id=v_partner;

  select * into o
  from public.player_doubles_match_tactics
  where player_id=p_player_id and match_id=p_match_id;

  v_effective:=public.get_effective_doubles_match_tactic_internal_v1(p_player_id,p_match_id);
  v_partner_tactic:=public.get_effective_doubles_match_tactic_internal_v1(v_partner,p_match_id);

  if m.scheduled_start_minute is not null then
    v_lock:=public.doubles_match_game_second_v1(p_match_id)-3600;
  else
    v_lock:=null;
  end if;

  v_editable:=m.status='scheduled'
    and (v_lock is null or public.current_game_second_v1()<v_lock);

  return jsonb_build_object(
    'match_id',p_match_id,
    'match_status',m.status,
    'editable',v_editable,
    'source',v_effective->>'source',
    'override',case when o.id is null then null else jsonb_build_object(
      'preset',o.tactic_preset,
      'approach',o.tactic_approach,
      'rally',o.tactic_rally,
      'serve',o.tactic_serve,
      'returnGame',o.tactic_return,
      'courtPosition',o.tactic_court_position,
      'target',o.tactic_target,
      'risk',o.tactic_risk
    ) end,
    'effective',v_effective-'source',
    'tactic_lock_game_second',v_lock,
    'partner_id',v_partner,
    'partner_name',v_partner_name,
    'partner_tactic',v_partner_tactic-'source',
    'partner_tactic_source',v_partner_tactic->>'source'
  );
end;
$$;

revoke all on function public.get_tournament_doubles_match_tactic_v1(uuid,uuid)
from public,anon;
grant execute on function public.get_tournament_doubles_match_tactic_v1(uuid,uuid)
to authenticated,service_role;

create or replace function public.save_tournament_doubles_match_tactic_v1(
  p_player_id uuid,
  p_match_id uuid,
  p_tactic_preset text,
  p_tactic_approach text,
  p_tactic_rally text,
  p_tactic_serve text,
  p_tactic_return text,
  p_tactic_court_position text,
  p_tactic_target text,
  p_tactic_risk text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_state jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  v_state:=public.get_tournament_doubles_match_tactic_v1(p_player_id,p_match_id);
  if not coalesce((v_state->>'editable')::boolean,false) then
    raise exception 'Doubles tactics are locked for this match.';
  end if;

  if p_tactic_preset not in ('Balanced','Attack','Counterpunch','Serve + 1','Defensive / Grind','Net Attack','Custom')
     or p_tactic_approach not in ('Defensive','Balanced','Aggressive')
     or p_tactic_rally not in ('Shorten points','Balanced rallies','Extend rallies')
     or p_tactic_serve not in ('Safe first serve','Balanced','Power serving','Serve + 1')
     or p_tactic_return not in ('Safe return','Balanced','Aggressive return','Attack second serve')
     or p_tactic_court_position not in ('Deep baseline','Normal baseline','Inside baseline','Net attack')
     or p_tactic_target not in ('Automatic','Backhand','Forehand','Movement','Stamina','Second serve')
     or p_tactic_risk not in ('Safe','Balanced','Aggressive') then
    raise exception 'Invalid doubles tactic selection.';
  end if;

  insert into public.player_doubles_match_tactics(
    owner_user_id,player_id,match_id,
    tactic_preset,tactic_approach,tactic_rally,tactic_serve,
    tactic_return,tactic_court_position,tactic_target,tactic_risk
  )
  values(
    v_uid,p_player_id,p_match_id,
    p_tactic_preset,p_tactic_approach,p_tactic_rally,p_tactic_serve,
    p_tactic_return,p_tactic_court_position,p_tactic_target,p_tactic_risk
  )
  on conflict(player_id,match_id) do update
  set owner_user_id=excluded.owner_user_id,
      tactic_preset=excluded.tactic_preset,
      tactic_approach=excluded.tactic_approach,
      tactic_rally=excluded.tactic_rally,
      tactic_serve=excluded.tactic_serve,
      tactic_return=excluded.tactic_return,
      tactic_court_position=excluded.tactic_court_position,
      tactic_target=excluded.tactic_target,
      tactic_risk=excluded.tactic_risk,
      updated_at=now();

  return public.get_tournament_doubles_match_tactic_v1(p_player_id,p_match_id);
end;
$$;

revoke all on function public.save_tournament_doubles_match_tactic_v1(
  uuid,uuid,text,text,text,text,text,text,text,text
) from public,anon;
grant execute on function public.save_tournament_doubles_match_tactic_v1(
  uuid,uuid,text,text,text,text,text,text,text,text
) to authenticated,service_role;

create or replace function public.clear_tournament_doubles_match_tactic_v1(
  p_player_id uuid,
  p_match_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_state jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  v_state:=public.get_tournament_doubles_match_tactic_v1(p_player_id,p_match_id);
  if not coalesce((v_state->>'editable')::boolean,false) then
    raise exception 'Doubles tactics are locked for this match.';
  end if;

  delete from public.player_doubles_match_tactics
  where owner_user_id=v_uid
    and player_id=p_player_id
    and match_id=p_match_id;

  return public.get_tournament_doubles_match_tactic_v1(p_player_id,p_match_id);
end;
$$;

revoke all on function public.clear_tournament_doubles_match_tactic_v1(uuid,uuid)
from public,anon;
grant execute on function public.clear_tournament_doubles_match_tactic_v1(uuid,uuid)
to authenticated,service_role;

create or replace function public.doubles_player_match_strength_v1(
  p_player_id uuid,
  p_match_id uuid,
  p_surface text
)
returns numeric
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  s public.player_skills%rowtype;
  e jsonb;
  t jsonb;
  v_base numeric;
  v_mod numeric;
  v_delta numeric:=0;
  v_quality numeric;
begin
  select * into s from public.player_skills where player_id=p_player_id;
  if s.player_id is null then return 0; end if;

  e:=public.get_equipment_match_modifiers_readonly_v2(p_player_id,coalesce(p_surface,'hard'));
  v_mod:=coalesce((e->>'serve_pct')::numeric,0)*0.18
       +coalesce((e->>'return_pct')::numeric,0)*0.16
       +coalesce((e->>'rally_pct')::numeric,0)*0.18
       +coalesce((e->>'net_pct')::numeric,0)*0.22
       +coalesce((e->>'movement_pct')::numeric,0)*0.10
       +coalesce((e->>'stamina_pct')::numeric,0)*0.08
       +coalesce((e->>'focus_pct')::numeric,0)*0.08;

  v_base:=s.serve*0.18+s.return_skill*0.15+s.volley*0.20+s.forehand*0.10
        +s.backhand*0.09+s.movement*0.09+s.stamina*0.07+s.focus*0.07+s.smash*0.05;
  v_base:=v_base*(1+v_mod/100.0)*greatest(0.70,1-s.fatigue*0.003);

  t:=public.get_effective_doubles_match_tactic_internal_v1(p_player_id,p_match_id);

  if t->>'approach'='Aggressive' then
    v_quality:=(s.serve+s.forehand+s.volley)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.030;
  elsif t->>'approach'='Defensive' then
    v_quality:=(s.return_skill+s.movement+s.stamina)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.030;
  end if;

  if t->>'rally'='Shorten points' then
    v_quality:=(s.serve+s.forehand+s.volley)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.020;
  elsif t->>'rally'='Extend rallies' then
    v_quality:=(s.return_skill+s.movement+s.stamina)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.020;
  end if;

  if t->>'serve'='Power serving' then
    v_delta:=v_delta+(s.serve-50)*0.025;
  elsif t->>'serve'='Serve + 1' then
    v_delta:=v_delta+(((s.serve+s.forehand)/2.0)-50)*0.022;
  elsif t->>'serve'='Safe first serve' then
    v_delta:=v_delta+(((s.serve+s.focus)/2.0)-50)*0.012;
  end if;

  if t->>'returnGame'='Aggressive return' then
    v_delta:=v_delta+(((s.return_skill+s.forehand)/2.0)-50)*0.020;
  elsif t->>'returnGame'='Attack second serve' then
    v_delta:=v_delta+(s.return_skill-50)*0.020;
  elsif t->>'returnGame'='Safe return' then
    v_delta:=v_delta+(((s.return_skill+s.focus)/2.0)-50)*0.012;
  end if;

  if t->>'courtPosition'='Net attack' then
    v_quality:=(s.volley+s.smash+s.serve)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.030;
  elsif t->>'courtPosition'='Inside baseline' then
    v_quality:=(s.forehand+s.backhand+s.movement)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.018;
  elsif t->>'courtPosition'='Deep baseline' then
    v_quality:=(s.return_skill+s.movement+s.stamina)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.015;
  end if;

  if t->>'risk'='Aggressive' then
    v_quality:=(s.focus+s.serve+s.forehand)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.014;
  elsif t->>'risk'='Safe' then
    v_quality:=(s.focus+s.stamina+s.return_skill)/3.0;
    v_delta:=v_delta+(v_quality-50)*0.012;
  end if;

  v_delta:=greatest(-3.5,least(3.5,v_delta));
  return round(greatest(1,v_base+v_delta),4);
end;
$$;

create or replace function public.doubles_team_match_strength_v1(
  p_team_id uuid,
  p_match_id uuid,
  p_surface text
)
returns numeric
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  t public.tournament_doubles_teams%rowtype;
  v_one numeric;
  v_total numeric:=0;
begin
  select * into t from public.tournament_doubles_teams where id=p_team_id;
  if t.id is null then return 0; end if;

  v_one:=public.doubles_player_match_strength_v1(t.player1_id,p_match_id,p_surface);
  v_total:=v_total+v_one;
  v_one:=public.doubles_player_match_strength_v1(t.player2_id,p_match_id,p_surface);
  v_total:=v_total+v_one;

  return round(v_total/2.0,4);
end;
$$;

create or replace function public.simulate_doubles_match_v1(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  m public.tournament_doubles_matches%rowtype;
  t1 public.tournament_doubles_teams%rowtype;
  t2 public.tournament_doubles_teams%rowtype;
  v_surface text;
  v_s1 numeric;
  v_s2 numeric;
  v_p numeric;
  v_roll numeric;
  v_winner uuid;
  v_sets smallint;
  v_games integer;
  v_minutes integer;
  v_tactics jsonb;
begin
  select * into m from public.tournament_doubles_matches where id=p_match_id for update;
  if m.id is null then return jsonb_build_object('status','missing'); end if;
  if m.status<>'scheduled' or m.team1_id is null or m.team2_id is null then
    return jsonb_build_object('status','not_ready');
  end if;

  select * into t1 from public.tournament_doubles_teams where id=m.team1_id;
  select * into t2 from public.tournament_doubles_teams where id=m.team2_id;

  select ts.surface into v_surface
  from public.tournament_world_competitions wc
  join public.tournament_editions e on e.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=e.tournament_series_id
  where wc.id=m.competition_id;

  v_s1:=greatest(1,public.doubles_team_match_strength_v1(m.team1_id,p_match_id,v_surface));
  v_s2:=greatest(1,public.doubles_team_match_strength_v1(m.team2_id,p_match_id,v_surface));

  v_p:=v_s1/(v_s1+v_s2);
  v_roll:=random();
  v_winner:=case when v_roll<=v_p then m.team1_id else m.team2_id end;

  v_sets:=case when abs(v_s1-v_s2)<8 and random()<0.55 then 3 else 2 end;
  v_games:=case when v_sets=3 then 24+floor(random()*10)::integer else 16+floor(random()*9)::integer end;
  v_minutes:=greatest(55,least(150,round(40+v_games*2.2+case when v_sets=3 then 12 else 0 end)::integer));

  v_tactics:=jsonb_build_object(
    'team1',jsonb_build_array(
      jsonb_build_object('player_id',t1.player1_id,'tactic',public.get_effective_doubles_match_tactic_internal_v1(t1.player1_id,p_match_id)),
      jsonb_build_object('player_id',t1.player2_id,'tactic',public.get_effective_doubles_match_tactic_internal_v1(t1.player2_id,p_match_id))
    ),
    'team2',jsonb_build_array(
      jsonb_build_object('player_id',t2.player1_id,'tactic',public.get_effective_doubles_match_tactic_internal_v1(t2.player1_id,p_match_id)),
      jsonb_build_object('player_id',t2.player2_id,'tactic',public.get_effective_doubles_match_tactic_internal_v1(t2.player2_id,p_match_id))
    )
  );

  update public.tournament_doubles_matches
  set status='completed',
      winner_team_id=v_winner,
      actual_duration_minutes=v_minutes,
      sets_played=v_sets,
      games_played=v_games,
      completion_reason='played',
      started_at=coalesce(started_at,now()),
      completed_at=now(),
      simulation_metadata=jsonb_build_object(
        'team1_strength',round(v_s1,2),
        'team2_strength',round(v_s2,2),
        'team1_win_probability',round(v_p,4),
        'tactics',v_tactics,
        'tactics_model','human_override_ai_automatic_v1'
      ),
      updated_at=now()
  where id=m.id;

  return jsonb_build_object(
    'status','completed',
    'winner_team_id',v_winner,
    'duration_minutes',v_minutes,
    'sets_played',v_sets,
    'games_played',v_games
  );
end;
$$;

