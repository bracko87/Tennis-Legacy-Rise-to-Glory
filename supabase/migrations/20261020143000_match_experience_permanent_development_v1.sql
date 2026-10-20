-- Match-earned permanent development, starting with matches completed AFTER deployment.
-- Reuses the same fractional progression engine as regular training.
-- No backfill of completed historical matches and no modification of current ratings.
create table if not exists public.player_match_development_events (
  match_kind text not null check (match_kind in ('singles','doubles')),
  match_id uuid not null,
  player_id uuid not null references public.players(id) on delete cascade,
  outcome text not null check (outcome in ('win','loss')),
  game_season integer not null check (game_season >= 1),
  game_week smallint not null check (game_week between 0 and 52),
  match_minutes integer not null check (match_minutes between 20 and 480),
  surface text not null,
  earned_progress jsonb not null default '{}'::jsonb,
  level_ups jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (match_kind, match_id, player_id)
);
create index if not exists player_match_development_player_time_idx
  on public.player_match_development_events (player_id, game_season, game_week);
alter table public.player_match_development_events enable row level security;
revoke all on public.player_match_development_events from public, anon, authenticated;
grant select on public.player_match_development_events to authenticated;
drop policy if exists "player reads own earned match experience" on public.player_match_development_events;
create policy "player reads own earned match experience"
on public.player_match_development_events for select to authenticated
using (exists (
  select 1 from public.players p
  where p.id = player_match_development_events.player_id
    and p.owner_user_id = (select auth.uid())
));

-- Internal helper: no public RPC permission. Invoked solely from completed match triggers.
create or replace function public.award_player_match_development_v1(
  p_kind text, p_match_id uuid, p_player_id uuid, p_won boolean,
  p_minutes integer, p_games integer, p_surface text, p_opponent_rating numeric
) returns void language plpgsql security definer set search_path = public
as $function$
declare
  v_weights jsonb;
  v_gains jsonb := '{}'::jsonb;
  v_total_weight numeric;
  v_budget numeric;
  v_duration numeric;
  v_opponent_factor numeric;
  v_style text;
  v_key record;
  v_date record;
  v_week record;
  v_inserted uuid;
  v_result jsonb;
begin
  if p_kind not in ('singles','doubles') or p_match_id is null or p_player_id is null then
    raise exception 'Invalid match-development event';
  end if;
  select playing_style into v_style from public.player_skills where player_id = p_player_id;
  if not found then return; end if;

  -- Correct in-game season/week. Wall-clock timestamps are never a date source.
  select * into v_date from public.get_current_game_day_internal_v1();
  select * into v_week from public.absolute_game_day_v1(
    public.game_day_absolute_v1(v_date.season,v_date.month,v_date.day)
  );

  -- Short wins/losses award less than long competitive matches. The match award
  -- is deliberately below the base of a normal daily training session.
  v_duration := greatest(0.72,least(1.22,
    0.72 + greatest(20,least(480,coalesce(p_minutes,90)))::numeric/450.0
         + greatest(6,least(99,coalesce(p_games,20)))::numeric/260.0
  ));
  v_opponent_factor := greatest(0.90,least(1.15,
    0.90 + greatest(0,least(100,coalesce(p_opponent_rating,50)))::numeric/400.0
  ));
  v_budget := round(greatest(0.05,least(0.16,
    (case when p_kind='singles' then 0.12 else 0.085 end)::numeric
      * v_duration * v_opponent_factor
      * (case when p_won then 1.05 else 1.0 end)
  )),4);

  -- Singles emphasizes serve/return/groundstrokes; doubles gives more to
  -- net play. Small physical gains remain possible in either format.
  if p_kind = 'singles' then
    v_weights := '{"serve":25,"forehand":20,"backhand":16,"return_skill":18,"volley":3,"slice":2,"drop_shot":2,"lob":1,"smash":2,"fitness":2,"stamina":4,"recovery":1,"movement":4}'::jsonb;
  else
    v_weights := '{"serve":19,"forehand":10,"backhand":9,"return_skill":16,"volley":23,"slice":3,"drop_shot":1,"lob":1,"smash":8,"fitness":2,"stamina":2,"recovery":1,"movement":5}'::jsonb;
  end if;
  if lower(coalesce(p_surface,'hard')) = 'clay' then
    v_weights := v_weights || jsonb_build_object(
      'forehand',(v_weights->>'forehand')::numeric+4,
      'backhand',(v_weights->>'backhand')::numeric+3,
      'stamina',(v_weights->>'stamina')::numeric+4,
      'movement',(v_weights->>'movement')::numeric+3
    );
  elsif lower(coalesce(p_surface,'hard')) = 'grass' then
    v_weights := v_weights || jsonb_build_object(
      'serve',(v_weights->>'serve')::numeric+4,
      'volley',(v_weights->>'volley')::numeric+4,
      'slice',(v_weights->>'slice')::numeric+3
    );
  end if;
  if v_style = 'Serve & Volley' then
    v_weights := v_weights || jsonb_build_object(
      'serve',(v_weights->>'serve')::numeric+3,
      'volley',(v_weights->>'volley')::numeric+4
    );
  end if;

  select sum(value::numeric) into v_total_weight from jsonb_each_text(v_weights);
  for v_key in select key, value::numeric as weight from jsonb_each_text(v_weights) loop
    v_gains := v_gains || jsonb_build_object(v_key.key,round(v_budget*v_key.weight/v_total_weight,4));
  end loop;

  -- Insert BEFORE applying progress. Duplicate match updates/replays cannot
  -- award the same player a second time; the transaction is atomic on error.
  insert into public.player_match_development_events (
    match_kind,match_id,player_id,outcome,game_season,game_week,
    match_minutes,surface,earned_progress
  ) values (
    p_kind,p_match_id,p_player_id,case when p_won then 'win' else 'loss' end,
    v_date.season,v_week.season_week,
    greatest(20,least(480,coalesce(p_minutes,90))),
    lower(coalesce(p_surface,'hard')),v_gains
  ) on conflict (match_kind,match_id,player_id) do nothing
    returning player_id into v_inserted;
  if v_inserted is null then return; end if;

  -- Attribute-level slowdowns and whole-point thresholds stay centralized.
  v_result := public.apply_player_development_progress_v1(p_player_id,'match_experience',v_gains);
  update public.player_match_development_events
  set level_ups = coalesce(v_result->'level_ups','{}'::jsonb)
  where match_kind = p_kind and match_id = p_match_id and player_id = p_player_id;
end;
$function$;
revoke all on function public.award_player_match_development_v1(text,uuid,uuid,boolean,integer,integer,text,numeric)
  from public,anon,authenticated;

create or replace function public.award_singles_match_development_v1()
returns trigger language plpgsql security definer set search_path = public
as $function$
declare
  v_minutes integer;
  v_games integer;
  v_surface text;
  v_player uuid;
  v_opponent uuid;
  v_rating numeric;
  v_match record;
begin
  if new.status <> 'completed' or new.winner_id is null
     or (tg_op = 'UPDATE' and old.status = 'completed') then return new; end if;
  if new.player1_id is null or new.player2_id is null
     or new.winner_id not in (new.player1_id,new.player2_id) then return new; end if;
  select sim.metadata, sim.total_games into v_match
  from public.tournament_match_simulations sim where sim.match_id = new.id;
  if not found then return new; end if;
  -- The condition event is proof the match was actually simulated/played,
  -- rather than a bracket advance, bye, or walkover.
  v_minutes := greatest(20,least(480,coalesce((v_match.metadata->>'estimated_match_minutes')::integer,90)));
  v_games := greatest(6,least(99,coalesce(v_match.total_games,20)));
  select coalesce(ts.surface,'hard') into v_surface
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;
  for v_player in select distinct unnest(array[new.player1_id,new.player2_id]) loop
    if not exists (select 1 from public.player_match_condition_events e
                   where e.match_id=new.id and e.player_id=v_player) then continue; end if;
    v_opponent := case when v_player=new.player1_id then new.player2_id else new.player1_id end;
    select (s.serve+s.forehand+s.backhand+s.return_skill)::numeric/4.0 into v_rating
    from public.player_skills s where s.player_id=v_opponent;
    perform public.award_player_match_development_v1(
      'singles',new.id,v_player,v_player=new.winner_id,
      v_minutes,v_games,v_surface,v_rating
    );
  end loop;
  return new;
end;
$function$;
revoke all on function public.award_singles_match_development_v1() from public,anon,authenticated;
drop trigger if exists trg_award_singles_match_development_v1 on public.tournament_matches;
create trigger trg_award_singles_match_development_v1
after insert or update of status on public.tournament_matches
for each row execute function public.award_singles_match_development_v1();

create or replace function public.award_doubles_match_development_v1()
returns trigger language plpgsql security definer set search_path = public
as $function$
declare
  t1 public.tournament_doubles_teams%rowtype;
  t2 public.tournament_doubles_teams%rowtype;
  v_player uuid;
  v_rating numeric;
  v_surface text;
  v_opponents uuid[];
  v_won boolean;
begin
  if new.status <> 'completed' or new.winner_team_id is null
     or (tg_op = 'UPDATE' and old.status = 'completed') then return new; end if;
  if new.winner_team_id not in (new.team1_id,new.team2_id) then return new; end if;
  -- Prevent free experience for byes, forfeits or incomplete match records.
  if coalesce(new.actual_duration_minutes,0) < 20
     or coalesce(new.sets_played,0) < 2
     or coalesce(new.games_played,0) < 6 then return new; end if;
  select * into t1 from public.tournament_doubles_teams where id=new.team1_id;
  if not found then return new; end if;
  select * into t2 from public.tournament_doubles_teams where id=new.team2_id;
  if not found then return new; end if;
  select coalesce(ts.surface,'hard') into v_surface
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  where wc.id=new.competition_id;
  for v_player in select distinct unnest(array[
    t1.player1_id,t1.player2_id,t2.player1_id,t2.player2_id
  ]) loop
    if v_player is null or not exists (
      select 1 from public.player_doubles_match_condition_events e
      where e.doubles_match_id=new.id and e.player_id=v_player
    ) then continue; end if;
    v_won := (new.winner_team_id=t1.id and v_player in (t1.player1_id,t1.player2_id))
          or (new.winner_team_id=t2.id and v_player in (t2.player1_id,t2.player2_id));
    v_opponents := case
      when v_player in (t1.player1_id,t1.player2_id)
        then array[t2.player1_id,t2.player2_id]
      else array[t1.player1_id,t1.player2_id] end;
    select avg((s.serve+s.forehand+s.backhand+s.return_skill)::numeric/4.0)
      into v_rating from public.player_skills s
      where s.player_id=any(v_opponents);
    perform public.award_player_match_development_v1(
      'doubles',new.id,v_player,v_won,
      greatest(20,least(480,coalesce(new.actual_duration_minutes::integer,90))),
      greatest(6,least(99,coalesce(new.games_played,20))),
      v_surface,v_rating
    );
  end loop;
  return new;
end;
$function$;
revoke all on function public.award_doubles_match_development_v1() from public,anon,authenticated;
drop trigger if exists trg_award_doubles_match_development_v1 on public.tournament_doubles_matches;
create trigger trg_award_doubles_match_development_v1
after update of status on public.tournament_doubles_matches
for each row execute function public.award_doubles_match_development_v1();
