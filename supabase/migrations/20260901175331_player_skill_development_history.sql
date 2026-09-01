create table if not exists public.player_skill_history (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  recorded_at timestamptz not null default now(),
  source text not null default 'skill_change',
  serve smallint not null,
  forehand smallint not null,
  backhand smallint not null,
  return_skill smallint not null,
  volley smallint not null,
  slice smallint not null,
  drop_shot smallint not null,
  fitness smallint not null,
  stamina smallint not null,
  recovery smallint not null,
  movement smallint not null,
  fatigue smallint not null,
  sharpness smallint not null,
  morale smallint not null,
  confidence smallint not null,
  focus smallint not null
);

create index if not exists player_skill_history_player_recorded_idx
  on public.player_skill_history (player_id, recorded_at);

alter table public.player_skill_history enable row level security;
revoke all on table public.player_skill_history from anon;
revoke all on table public.player_skill_history from authenticated;
grant select on table public.player_skill_history to authenticated;

drop policy if exists "players can read own skill history" on public.player_skill_history;
create policy "players can read own skill history"
on public.player_skill_history
for select
to authenticated
using (
  exists (
    select 1
    from public.players p
    where p.id = player_skill_history.player_id
      and p.owner_user_id = (select auth.uid())
  )
);

insert into public.player_skill_history (
  player_id, recorded_at, source,
  serve, forehand, backhand, return_skill, volley, slice, drop_shot,
  fitness, stamina, recovery, movement,
  fatigue, sharpness, morale, confidence, focus
)
select
  ps.player_id,
  coalesce(ps.created_at, now()),
  'initial',
  ps.serve, ps.forehand, ps.backhand, ps.return_skill, ps.volley, ps.slice, ps.drop_shot,
  ps.fitness, ps.stamina, ps.recovery, ps.movement,
  ps.fatigue, ps.sharpness, ps.morale, ps.confidence, ps.focus
from public.player_skills ps
where not exists (
  select 1 from public.player_skill_history h where h.player_id = ps.player_id
);

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
    serve, forehand, backhand, return_skill, volley, slice, drop_shot,
    fitness, stamina, recovery, movement,
    fatigue, sharpness, morale, confidence, focus
  ) values (
    new.player_id,
    case when tg_op = 'INSERT' then 'initial' else 'skill_change' end,
    new.serve, new.forehand, new.backhand, new.return_skill, new.volley, new.slice, new.drop_shot,
    new.fitness, new.stamina, new.recovery, new.movement,
    new.fatigue, new.sharpness, new.morale, new.confidence, new.focus
  );

  return new;
end;
$$;

revoke all on function public.record_player_skill_history() from public;

drop trigger if exists trg_record_player_skill_history on public.player_skills;
create trigger trg_record_player_skill_history
after insert or update of
  serve, forehand, backhand, return_skill, volley, slice, drop_shot,
  fitness, stamina, recovery, movement,
  fatigue, sharpness, morale, confidence, focus
on public.player_skills
for each row execute function public.record_player_skill_history();
