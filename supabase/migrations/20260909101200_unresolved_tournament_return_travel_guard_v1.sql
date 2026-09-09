create or replace function public.prevent_premature_tournament_return_travel_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if new.status='planned'
     and new.purpose='return_home'
     and new.source_location_type='tournament'
     and new.source_reference_id is not null
     and new.source_reference_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and exists (
       select 1
       from public.tournament_entries e
       join public.tournament_world_competitions wc on wc.id=e.competition_id
       join public.tournament_editions ed on ed.id=wc.tournament_edition_id
       where e.player_id=new.player_id
         and e.competition_id=new.source_reference_id::uuid
         and e.entry_status='active'
         and wc.status<>'canceled'
         and ed.status<>'canceled'
     ) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_premature_tournament_return_travel_v1 on public.player_travel_legs;
create trigger trg_prevent_premature_tournament_return_travel_v1
before insert or update on public.player_travel_legs
for each row execute function public.prevent_premature_tournament_return_travel_v1();

delete from public.player_travel_legs l
where l.status='planned'
  and l.purpose='return_home'
  and l.source_location_type='tournament'
  and l.source_reference_id is not null
  and l.source_reference_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1
    from public.tournament_entries e
    join public.tournament_world_competitions wc on wc.id=e.competition_id
    join public.tournament_editions ed on ed.id=wc.tournament_edition_id
    where e.player_id=l.player_id
      and e.competition_id=l.source_reference_id::uuid
      and e.entry_status='active'
      and wc.status<>'canceled'
      and ed.status<>'canceled'
  );