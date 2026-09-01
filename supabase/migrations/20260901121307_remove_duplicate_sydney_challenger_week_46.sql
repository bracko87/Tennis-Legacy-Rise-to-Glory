delete from public.tournament_schedule_slots sl
using public.tournament_editions e, public.tournament_series ts
where sl.tournament_edition_id = e.id
  and e.tournament_series_id = ts.id
  and e.season_number = 1
  and ts.slug = 'sydney-harbour-challenger'
  and sl.season_week = 46
  and sl.phase = 'full';

do $$
declare
  v_count integer;
  v_week integer;
begin
  select count(*), min(sl.season_week)
  into v_count, v_week
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id and e.season_number = 1
  join public.tournament_series ts on ts.id = e.tournament_series_id
  where ts.slug = 'sydney-harbour-challenger';

  if v_count <> 1 or v_week <> 7 then
    raise exception 'Sydney Challenger cleanup verification failed: count %, remaining week %', v_count, v_week;
  end if;
end $$;
