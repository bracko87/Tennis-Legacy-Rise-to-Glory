do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_applications') then
    alter publication supabase_realtime add table public.tournament_applications;
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='tournament_entries') then
    alter publication supabase_realtime add table public.tournament_entries;
  end if;
end $$;
