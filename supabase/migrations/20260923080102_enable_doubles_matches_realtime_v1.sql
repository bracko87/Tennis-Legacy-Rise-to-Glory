-- Enable live tournament order-of-play updates for doubles matches.
do $$
begin
  if not exists(
    select 1
    from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='tournament_doubles_matches'
  ) then
    alter publication supabase_realtime add table public.tournament_doubles_matches;
  end if;
end
$$;