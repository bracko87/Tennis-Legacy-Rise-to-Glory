create index if not exists tournament_applications_owner_user_idx
  on public.tournament_applications (owner_user_id);
create index if not exists tournament_applications_player_idx
  on public.tournament_applications (player_id);

drop policy if exists tournament_applications_own_read on public.tournament_applications;
create policy tournament_applications_own_read
on public.tournament_applications
for select
to authenticated
using (owner_user_id = (select auth.uid()));
