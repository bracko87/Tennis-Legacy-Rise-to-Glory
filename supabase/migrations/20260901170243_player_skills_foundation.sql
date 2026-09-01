create table if not exists public.player_skills (
  player_id uuid primary key references public.players(id) on delete cascade,
  preferred_surface text null check (preferred_surface is null or preferred_surface in ('Hard','Clay','Grass')),
  serve smallint not null default 50 check (serve between 1 and 100),
  forehand smallint not null default 50 check (forehand between 1 and 100),
  backhand smallint not null default 50 check (backhand between 1 and 100),
  return_skill smallint not null default 50 check (return_skill between 1 and 100),
  volley smallint not null default 50 check (volley between 1 and 100),
  slice smallint not null default 50 check (slice between 1 and 100),
  drop_shot smallint not null default 50 check (drop_shot between 1 and 100),
  fitness smallint not null default 50 check (fitness between 1 and 100),
  stamina smallint not null default 50 check (stamina between 1 and 100),
  recovery smallint not null default 50 check (recovery between 1 and 100),
  movement smallint not null default 50 check (movement between 1 and 100),
  fatigue smallint not null default 0 check (fatigue between 0 and 100),
  sharpness smallint not null default 50 check (sharpness between 1 and 100),
  morale smallint not null default 50 check (morale between 1 and 100),
  confidence smallint not null default 50 check (confidence between 1 and 100),
  focus smallint not null default 50 check (focus between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.player_skills enable row level security;
revoke all on table public.player_skills from anon;
grant select on table public.player_skills to authenticated;

drop policy if exists "players can read own skills" on public.player_skills;
create policy "players can read own skills"
on public.player_skills
for select
to authenticated
using (
  exists (
    select 1 from public.players p
    where p.id = player_skills.player_id
      and p.owner_user_id = (select auth.uid())
  )
);

create or replace function public.initialize_player_skills_v1()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_surface text := new.preferred_surface;
  v_serve smallint := 50;
  v_forehand smallint := 50;
  v_backhand smallint := 50;
  v_return smallint := 50;
  v_volley smallint := 50;
  v_slice smallint := 50;
  v_drop_shot smallint := 50;
begin
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

  insert into public.player_skills (
    player_id, preferred_surface,
    serve, forehand, backhand, return_skill, volley, slice, drop_shot
  ) values (
    new.id, v_surface,
    v_serve, v_forehand, v_backhand, v_return, v_volley, v_slice, v_drop_shot
  )
  on conflict (player_id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_initialize_player_skills on public.players;
create trigger trg_initialize_player_skills
after insert on public.players
for each row execute function public.initialize_player_skills_v1();

insert into public.player_skills (
  player_id, preferred_surface,
  serve, forehand, backhand, return_skill, volley, slice, drop_shot
)
select
  p.id,
  p.preferred_surface,
  case p.preferred_surface when 'Hard' then 51 when 'Clay' then 47 when 'Grass' then 54 else 50 end,
  case p.preferred_surface when 'Hard' then 52 when 'Clay' then 53 when 'Grass' then 50 else 50 end,
  case p.preferred_surface when 'Hard' then 51 when 'Clay' then 52 when 'Grass' then 48 else 50 end,
  case p.preferred_surface when 'Hard' then 52 when 'Clay' then 53 when 'Grass' then 47 else 50 end,
  case p.preferred_surface when 'Hard' then 48 when 'Clay' then 47 when 'Grass' then 54 else 50 end,
  case p.preferred_surface when 'Hard' then 48 when 'Clay' then 49 when 'Grass' then 52 else 50 end,
  case p.preferred_surface when 'Hard' then 48 when 'Clay' then 49 when 'Grass' then 45 else 50 end
from public.players p
on conflict (player_id) do nothing;
