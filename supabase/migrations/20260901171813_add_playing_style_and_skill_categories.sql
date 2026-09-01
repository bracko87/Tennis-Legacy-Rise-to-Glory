alter table public.players
  add column if not exists playing_style text;

update public.players
set playing_style = 'All-court'
where playing_style is null;

alter table public.players
  alter column playing_style set default 'All-court',
  alter column playing_style set not null;

alter table public.players
  drop constraint if exists players_playing_style_check;

alter table public.players
  add constraint players_playing_style_check
  check (playing_style in ('Aggressive Baseliner','Defensive Baseliner','All-court','Serve & Volley'));

alter table public.player_skills
  add column if not exists playing_style text;

update public.player_skills ps
set playing_style = p.playing_style
from public.players p
where p.id = ps.player_id
  and ps.playing_style is null;

alter table public.player_skills
  alter column playing_style set default 'All-court',
  alter column playing_style set not null;

alter table public.player_skills
  drop constraint if exists player_skills_playing_style_check;

alter table public.player_skills
  add constraint player_skills_playing_style_check
  check (playing_style in ('Aggressive Baseliner','Defensive Baseliner','All-court','Serve & Volley'));

comment on column public.player_skills.fitness is 'Developable physical attribute. Starts equally for all new players.';
comment on column public.player_skills.stamina is 'Developable physical attribute. Starts equally for all new players.';
comment on column public.player_skills.recovery is 'Developable physical attribute. Starts equally for all new players.';
comment on column public.player_skills.movement is 'Developable physical attribute. Starts equally for all new players.';
comment on column public.player_skills.fatigue is 'Dynamic condition value. Lower is better.';
comment on column public.player_skills.sharpness is 'Dynamic condition value.';
comment on column public.player_skills.morale is 'Dynamic condition value.';
comment on column public.player_skills.confidence is 'Dynamic condition value.';
comment on column public.player_skills.focus is 'Dynamic condition value.';

create or replace function public.initialize_player_skills_v1()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_surface text := new.preferred_surface;
  v_style text := coalesce(new.playing_style, 'All-court');
  v_serve smallint := 50;
  v_forehand smallint := 50;
  v_backhand smallint := 50;
  v_return smallint := 50;
  v_volley smallint := 50;
  v_slice smallint := 50;
  v_drop_shot smallint := 50;
begin
  -- Surface identity: total change is always 0 across the seven tennis skills.
  if v_surface = 'Hard' then
    v_serve := 51;
    v_forehand := 52;
    v_backhand := 51;
    v_return := 52;
    v_volley := 48;
    v_slice := 48;
    v_drop_shot := 48;
  elsif v_surface = 'Clay' then
    v_serve := 47;
    v_forehand := 53;
    v_backhand := 52;
    v_return := 53;
    v_volley := 47;
    v_slice := 49;
    v_drop_shot := 49;
  elsif v_surface = 'Grass' then
    v_serve := 54;
    v_forehand := 50;
    v_backhand := 48;
    v_return := 47;
    v_volley := 54;
    v_slice := 52;
    v_drop_shot := 45;
  end if;

  -- Playing style identity: modifiers also sum to 0, so total starting strength remains 350.
  if v_style = 'Aggressive Baseliner' then
    v_serve := v_serve + 1;
    v_forehand := v_forehand + 3;
    v_backhand := v_backhand + 1;
    v_volley := v_volley - 2;
    v_slice := v_slice - 1;
    v_drop_shot := v_drop_shot - 2;
  elsif v_style = 'Defensive Baseliner' then
    v_serve := v_serve - 2;
    v_forehand := v_forehand + 1;
    v_backhand := v_backhand + 2;
    v_return := v_return + 3;
    v_volley := v_volley - 2;
    v_slice := v_slice - 1;
    v_drop_shot := v_drop_shot - 1;
  elsif v_style = 'Serve & Volley' then
    v_serve := v_serve + 3;
    v_forehand := v_forehand - 1;
    v_backhand := v_backhand - 2;
    v_return := v_return - 2;
    v_volley := v_volley + 4;
    v_slice := v_slice + 1;
    v_drop_shot := v_drop_shot - 3;
  end if;

  insert into public.player_skills (
    player_id, preferred_surface, playing_style,
    serve, forehand, backhand, return_skill, volley, slice, drop_shot,
    fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus
  ) values (
    new.id, v_surface, v_style,
    v_serve, v_forehand, v_backhand, v_return, v_volley, v_slice, v_drop_shot,
    50, 50, 50, 50, 0, 50, 50, 50, 50
  )
  on conflict (player_id) do nothing;

  return new;
end;
$$;

revoke all on function public.initialize_player_skills_v1() from public, anon, authenticated;
