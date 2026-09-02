alter table public.player_skills
  add column if not exists lob smallint,
  add column if not exists smash smallint;

alter table public.player_skill_history
  add column if not exists lob smallint,
  add column if not exists smash smallint;

-- Existing careers receive the new two skills from the same surface/style identity
-- rules used for new careers. This adds exactly 100 points before style modifiers,
-- and each style modifier pair nets to zero.
update public.player_skills ps
set
  lob = (
    case ps.preferred_surface
      when 'Clay' then 53
      when 'Grass' then 46
      else 50
    end
    + case ps.playing_style
        when 'Aggressive Baseliner' then -1
        when 'Defensive Baseliner' then 2
        when 'Serve & Volley' then -2
        else 0
      end
  )::smallint,
  smash = (
    case ps.preferred_surface
      when 'Clay' then 47
      when 'Grass' then 54
      else 50
    end
    + case ps.playing_style
        when 'Aggressive Baseliner' then 1
        when 'Defensive Baseliner' then -2
        when 'Serve & Volley' then 2
        else 0
      end
  )::smallint
where ps.lob is null or ps.smash is null;

-- Historical rows created before these attributes existed inherit the career's
-- initial Lob/Smash identity. Future snapshots record their real changing values.
update public.player_skill_history h
set lob = ps.lob,
    smash = ps.smash
from public.player_skills ps
where ps.player_id = h.player_id
  and (h.lob is null or h.smash is null);

update public.player_skill_history
set lob = coalesce(lob, 50),
    smash = coalesce(smash, 50)
where lob is null or smash is null;

alter table public.player_skills
  alter column lob set default 50,
  alter column smash set default 50,
  alter column lob set not null,
  alter column smash set not null;

alter table public.player_skill_history
  alter column lob set default 50,
  alter column smash set default 50,
  alter column lob set not null,
  alter column smash set not null;

alter table public.player_skills
  drop constraint if exists player_skills_lob_range,
  drop constraint if exists player_skills_smash_range,
  add constraint player_skills_lob_range check (lob between 0 and 100),
  add constraint player_skills_smash_range check (smash between 0 and 100);

alter table public.player_skill_history
  drop constraint if exists player_skill_history_lob_range,
  drop constraint if exists player_skill_history_smash_range,
  add constraint player_skill_history_lob_range check (lob between 0 and 100),
  add constraint player_skill_history_smash_range check (smash between 0 and 100);

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
  v_lob smallint := 50;
  v_smash smallint := 50;
begin
  -- Surface identity. Nine tennis skills always total 450 before style.
  if v_surface = 'Hard' then
    v_serve := 51;
    v_forehand := 52;
    v_backhand := 51;
    v_return := 52;
    v_volley := 48;
    v_slice := 48;
    v_drop_shot := 48;
    v_lob := 50;
    v_smash := 50;
  elsif v_surface = 'Clay' then
    v_serve := 47;
    v_forehand := 53;
    v_backhand := 52;
    v_return := 53;
    v_volley := 47;
    v_slice := 49;
    v_drop_shot := 49;
    v_lob := 53;
    v_smash := 47;
  elsif v_surface = 'Grass' then
    v_serve := 54;
    v_forehand := 50;
    v_backhand := 48;
    v_return := 47;
    v_volley := 54;
    v_slice := 52;
    v_drop_shot := 45;
    v_lob := 46;
    v_smash := 54;
  end if;

  -- Playing-style identity also nets to zero across all nine skills.
  if v_style = 'Aggressive Baseliner' then
    v_serve := v_serve + 1;
    v_forehand := v_forehand + 3;
    v_backhand := v_backhand + 1;
    v_volley := v_volley - 2;
    v_slice := v_slice - 1;
    v_drop_shot := v_drop_shot - 2;
    v_lob := v_lob - 1;
    v_smash := v_smash + 1;
  elsif v_style = 'Defensive Baseliner' then
    v_serve := v_serve - 2;
    v_forehand := v_forehand + 1;
    v_backhand := v_backhand + 2;
    v_return := v_return + 3;
    v_volley := v_volley - 2;
    v_slice := v_slice - 1;
    v_drop_shot := v_drop_shot - 1;
    v_lob := v_lob + 2;
    v_smash := v_smash - 2;
  elsif v_style = 'Serve & Volley' then
    v_serve := v_serve + 3;
    v_forehand := v_forehand - 1;
    v_backhand := v_backhand - 2;
    v_return := v_return - 2;
    v_volley := v_volley + 4;
    v_slice := v_slice + 1;
    v_drop_shot := v_drop_shot - 3;
    v_lob := v_lob - 2;
    v_smash := v_smash + 2;
  end if;

  insert into public.player_skills (
    player_id, preferred_surface, playing_style,
    serve, forehand, backhand, return_skill, volley, slice, drop_shot, lob, smash,
    fitness, stamina, recovery, movement, fatigue, sharpness, morale, confidence, focus
  ) values (
    new.id, v_surface, v_style,
    v_serve, v_forehand, v_backhand, v_return, v_volley, v_slice, v_drop_shot, v_lob, v_smash,
    50, 50, 50, 50, 0, 50, 50, 50, 50
  )
  on conflict (player_id) do nothing;

  return new;
end;
$$;

create or replace function public.record_player_skill_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.serve is not distinct from new.serve
     and old.forehand is not distinct from new.forehand
     and old.backhand is not distinct from new.backhand
     and old.return_skill is not distinct from new.return_skill
     and old.volley is not distinct from new.volley
     and old.slice is not distinct from new.slice
     and old.drop_shot is not distinct from new.drop_shot
     and old.lob is not distinct from new.lob
     and old.smash is not distinct from new.smash
     and old.fitness is not distinct from new.fitness
     and old.stamina is not distinct from new.stamina
     and old.recovery is not distinct from new.recovery
     and old.movement is not distinct from new.movement
     and old.fatigue is not distinct from new.fatigue
     and old.sharpness is not distinct from new.sharpness
     and old.morale is not distinct from new.morale
     and old.confidence is not distinct from new.confidence
     and old.focus is not distinct from new.focus then
    return new;
  end if;

  insert into public.player_skill_history (
    player_id, source,
    serve, forehand, backhand, return_skill, volley, slice, drop_shot, lob, smash,
    fitness, stamina, recovery, movement,
    fatigue, sharpness, morale, confidence, focus
  ) values (
    new.player_id,
    case when tg_op = 'INSERT' then 'initial' else 'skill_change' end,
    new.serve, new.forehand, new.backhand, new.return_skill, new.volley, new.slice, new.drop_shot, new.lob, new.smash,
    new.fitness, new.stamina, new.recovery, new.movement,
    new.fatigue, new.sharpness, new.morale, new.confidence, new.focus
  );

  return new;
end;
$$;