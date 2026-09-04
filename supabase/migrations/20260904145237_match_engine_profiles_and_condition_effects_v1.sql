create table if not exists public.player_match_condition_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.tournament_matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  outcome text not null check (outcome in ('win','loss')),
  surface text not null,
  estimated_match_minutes integer not null check (estimated_match_minutes between 20 and 480),
  sets_played smallint not null check (sets_played between 2 and 5),
  games_played integer not null check (games_played between 6 and 99),
  fatigue_before smallint not null,
  fatigue_after smallint not null,
  sharpness_before smallint not null,
  sharpness_after smallint not null,
  morale_before smallint not null,
  morale_after smallint not null,
  confidence_before smallint not null,
  confidence_after smallint not null,
  focus_before smallint not null,
  focus_after smallint not null,
  created_at timestamptz not null default now(),
  unique(match_id,player_id)
);
alter table public.player_match_condition_events enable row level security;
revoke all on public.player_match_condition_events from public,anon,authenticated;

create or replace function public.match_engine_random_v1(p_seed text,p_index integer)
returns double precision language sql immutable set search_path='public' as $$
  select ((('x'||substr(md5(coalesce(p_seed,'')||':'||coalesce(p_index,0)::text),1,8))::bit(32)::bigint)::double precision / 4294967296.0);
$$;
revoke all on function public.match_engine_random_v1(text,integer) from public,anon,authenticated;

create or replace function public.get_match_engine_profile_v1(p_player_id uuid,p_surface text)
returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare
  s public.player_skills%rowtype;
  p public.players%rowtype;
  v_surface text:=lower(coalesce(p_surface,'hard'));
  v_pref text;
  v_serve numeric;
  v_return numeric;
  v_rally numeric;
  v_net numeric;
  v_physical numeric;
  v_mental numeric;
  v_fatigue_factor numeric;
  v_sharp_factor numeric;
  v_mental_factor numeric;
  v_condition numeric;
  v_surface_mult numeric;
  v_overall numeric;
begin
  select * into s from public.player_skills where player_id=p_player_id;
  select * into p from public.players where id=p_player_id;
  if s.player_id is null or p.id is null then raise exception 'Player skills are unavailable.';end if;
  v_pref:=lower(coalesce(s.preferred_surface,p.preferred_surface,'hard'));

  v_serve:=s.serve*0.62+s.forehand*0.14+s.backhand*0.08+s.volley*0.06+s.smash*0.05+s.movement*0.05;
  v_return:=s.return_skill*0.50+s.movement*0.18+s.forehand*0.13+s.backhand*0.13+s.slice*0.03+s.lob*0.03;
  if v_surface='clay' then
    v_rally:=s.forehand*0.25+s.backhand*0.22+s.movement*0.23+s.stamina*0.12+s.fitness*0.08+s.drop_shot*0.04+s.slice*0.03+s.lob*0.03;
  elsif v_surface='grass' then
    v_rally:=s.forehand*0.25+s.backhand*0.20+s.movement*0.15+s.volley*0.13+s.slice*0.08+s.serve*0.07+s.smash*0.05+s.stamina*0.04+s.fitness*0.03;
  else
    v_rally:=s.forehand*0.29+s.backhand*0.25+s.movement*0.18+s.stamina*0.08+s.fitness*0.07+s.volley*0.04+s.slice*0.03+s.drop_shot*0.02+s.lob*0.02+s.smash*0.02;
  end if;
  v_net:=s.volley*0.45+s.smash*0.30+s.movement*0.15+s.serve*0.10;
  v_physical:=(s.fitness+s.stamina+s.recovery+s.movement)::numeric/4.0;
  v_mental:=s.focus*0.45+s.confidence*0.30+s.morale*0.25;
  v_fatigue_factor:=1.0-0.12*power(greatest(0,least(100,s.fatigue))::numeric/100.0,1.35);
  v_sharp_factor:=0.94+0.06*(s.sharpness::numeric/100.0);
  v_mental_factor:=0.96+0.04*(v_mental/100.0);
  v_condition:=v_fatigue_factor*v_sharp_factor*v_mental_factor;
  v_surface_mult:=case when v_pref=v_surface then 1.015 else 0.995 end;
  v_overall:=((v_serve+v_return+2*v_rally)/4.0)*v_condition*v_surface_mult;

  return jsonb_build_object(
    'player_id',p_player_id,'name',concat_ws(' ',p.first_name,p.last_name),'surface',v_surface,
    'preferred_surface',s.preferred_surface,'playing_style',s.playing_style,
    'technical',jsonb_build_object('serve',s.serve,'forehand',s.forehand,'backhand',s.backhand,'return_skill',s.return_skill,'volley',s.volley,'slice',s.slice,'drop_shot',s.drop_shot,'lob',s.lob,'smash',s.smash),
    'physical',jsonb_build_object('fitness',s.fitness,'stamina',s.stamina,'recovery',s.recovery,'movement',s.movement,'rating',round(v_physical,2)),
    'condition',jsonb_build_object('fatigue',s.fatigue,'sharpness',s.sharpness,'morale',s.morale,'confidence',s.confidence,'focus',s.focus,'mental_score',round(v_mental,2),'expression_multiplier',round(v_condition,4)),
    'surface_multiplier',round(v_surface_mult,4),
    'ratings',jsonb_build_object('serve',round(v_serve,2),'return',round(v_return,2),'rally',round(v_rally,2),'net',round(v_net,2),'effective_overall',round(v_overall,2))
  );
end;$$;
revoke all on function public.get_match_engine_profile_v1(uuid,text) from public,anon,authenticated;

create or replace function public.calculate_match_fatigue_v2(
  p_match_minutes integer,p_sets_played smallint,p_games_played integer,
  p_fitness smallint,p_stamina smallint,p_recovery smallint,p_surface text default 'hard'
) returns integer language plpgsql immutable set search_path='public' as $$
declare v_base numeric;v_surface numeric;v_resilience numeric;v_recovery numeric;begin
  if p_match_minutes not between 20 and 480 then raise exception 'Match minutes must be between 20 and 480.';end if;
  if p_sets_played not between 2 and 5 then raise exception 'Sets played must be between 2 and 5.';end if;
  if p_games_played not between 6 and 99 then raise exception 'Games played must be between 6 and 99.';end if;
  if p_fitness not between 1 and 100 or p_stamina not between 1 and 100 or p_recovery not between 1 and 100 then raise exception 'Physical values must be between 1 and 100.';end if;
  v_base:=case when p_match_minutes<=70 and p_sets_played=2 then 6 when p_match_minutes<=105 and p_sets_played=2 then 8 when p_match_minutes<=145 then 11 when p_match_minutes<=205 then 15 when p_match_minutes<=285 then 19 else 23 end;
  if p_games_played>=45 then v_base:=v_base+3;elsif p_games_played>=36 then v_base:=v_base+2;elsif p_games_played>=30 then v_base:=v_base+1;end if;
  if p_sets_played>=4 then v_base:=v_base+2*(p_sets_played-3);end if;
  v_surface:=case lower(coalesce(p_surface,'hard')) when 'clay' then 1.08 when 'grass' then 0.95 else 1.00 end;
  v_resilience:=(p_fitness+p_stamina)::numeric/200.0;
  v_recovery:=1.10-0.20*(p_recovery::numeric/100.0);
  return greatest(4,least(28,round(v_base*v_surface*(1.12-0.24*v_resilience)*v_recovery)));
end;$$;
revoke all on function public.calculate_match_fatigue_v2(integer,smallint,integer,smallint,smallint,smallint,text) from public,anon,authenticated;

create or replace function public.apply_match_condition_effects_v1()
returns trigger language plpgsql security definer set search_path='public' as $$
declare
  sim public.tournament_match_simulations%rowtype;
  v_surface text:='hard';
  v_minutes integer;
  v_sets smallint;
  v_games integer;
  v_player uuid;
  s public.player_skills%rowtype;
  v_gain integer;
  v_fatigue_after smallint;
  v_sharp_after smallint;
  v_morale_after smallint;
  v_conf_after smallint;
  v_focus_after smallint;
  v_win boolean;
begin
  if new.status<>'completed' or new.winner_id is null or (tg_op='UPDATE' and old.status='completed') then return new;end if;
  select * into sim from public.tournament_match_simulations where match_id=new.id;
  if sim.match_id is null then return new;end if;
  select coalesce(ts.surface,'hard') into v_surface from public.tournament_world_competitions wc join public.tournament_editions ed on ed.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=ed.tournament_series_id where wc.id=new.competition_id;
  v_minutes:=greatest(20,least(480,coalesce((sim.metadata->>'estimated_match_minutes')::integer,90)));
  v_sets:=greatest(2,least(5,jsonb_array_length(sim.sets_payload)))::smallint;
  v_games:=greatest(6,least(99,coalesce(sim.total_games,20)));

  foreach v_player in array array[new.player1_id,new.player2_id] loop
    if v_player is null or exists(select 1 from public.player_match_condition_events where match_id=new.id and player_id=v_player) then continue;end if;
    select * into s from public.player_skills where player_id=v_player for update;
    if s.player_id is null then continue;end if;
    v_win:=v_player=new.winner_id;
    v_gain:=public.calculate_match_fatigue_v2(v_minutes,v_sets,v_games,s.fitness,s.stamina,s.recovery,v_surface);
    v_fatigue_after:=least(100,s.fatigue+v_gain)::smallint;
    v_sharp_after:=least(100,s.sharpness+case when v_minutes>=150 then 1 else 2 end)::smallint;
    v_morale_after:=greatest(1,least(100,s.morale+case when v_win then 1 else -1 end))::smallint;
    v_conf_after:=greatest(1,least(100,s.confidence+case when v_win then 3 else -1 end))::smallint;
    v_focus_after:=greatest(1,least(100,s.focus+case when v_win and v_minutes<150 then 1 when v_minutes>=180 then -1 else 0 end))::smallint;
    update public.player_skills set fatigue=v_fatigue_after,sharpness=v_sharp_after,morale=v_morale_after,confidence=v_conf_after,focus=v_focus_after,updated_at=now() where player_id=v_player;
    insert into public.player_match_condition_events(match_id,player_id,outcome,surface,estimated_match_minutes,sets_played,games_played,fatigue_before,fatigue_after,sharpness_before,sharpness_after,morale_before,morale_after,confidence_before,confidence_after,focus_before,focus_after)
    values(new.id,v_player,case when v_win then 'win' else 'loss' end,lower(v_surface),v_minutes,v_sets,v_games,s.fatigue,v_fatigue_after,s.sharpness,v_sharp_after,s.morale,v_morale_after,s.confidence,v_conf_after,s.focus,v_focus_after);
  end loop;
  return new;
end;$$;
revoke all on function public.apply_match_condition_effects_v1() from public,anon,authenticated;
drop trigger if exists apply_match_condition_effects_v1 on public.tournament_matches;
create trigger apply_match_condition_effects_v1 after insert or update of status on public.tournament_matches for each row execute function public.apply_match_condition_effects_v1();