alter table public.players
  add column if not exists preferred_surface text;

alter table public.players
  drop constraint if exists players_preferred_surface_check;

alter table public.players
  add constraint players_preferred_surface_check
  check (preferred_surface is null or preferred_surface in ('Hard','Clay','Grass'));

comment on column public.players.preferred_surface is
  'Player-selected preferred court surface. Stored at career creation; gameplay bonuses are intentionally not implemented yet.';
