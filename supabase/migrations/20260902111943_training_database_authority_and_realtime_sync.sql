-- Make the database the authoritative source for Training and prevent direct client-side mutation.
revoke all privileges on table public.player_daily_activity from anon;
revoke all privileges on table public.player_training_plans from anon;
revoke all privileges on table public.player_training_progress from anon;
revoke all privileges on table public.player_training_sessions from anon;

revoke insert, update, delete, truncate, references, trigger on table public.player_daily_activity from authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.player_training_plans from authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.player_training_progress from authenticated;
revoke insert, update, delete, truncate, references, trigger on table public.player_training_sessions from authenticated;

grant select on table public.player_daily_activity to authenticated;
grant select on table public.player_training_plans to authenticated;
grant select on table public.player_training_progress to authenticated;
grant select on table public.player_training_sessions to authenticated;

comment on table public.player_training_plans is 'Server-authoritative persistent regular-training choice. Shared across devices through the authenticated Tennis Legacy account; clients may read but must use validated RPCs to change it.';
comment on table public.player_training_progress is 'Server-authoritative fractional development progress. Shared across devices and mutated only by trusted development engines.';
comment on table public.player_training_sessions is 'Server-authoritative completed daily training/recovery history. Shared across devices and written only by trusted training engines.';
comment on table public.player_daily_activity is 'Canonical server-authoritative daily player state. Missing row means home/default; travel, tournament, camp and injury states block regular training.';

-- Publish Training and core player-skill state so another signed-in device can refresh immediately.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_training_plans') then
    alter publication supabase_realtime add table public.player_training_plans;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_training_progress') then
    alter publication supabase_realtime add table public.player_training_progress;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_training_sessions') then
    alter publication supabase_realtime add table public.player_training_sessions;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_daily_activity') then
    alter publication supabase_realtime add table public.player_daily_activity;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_skills') then
    alter publication supabase_realtime add table public.player_skills;
  end if;
end $$;
