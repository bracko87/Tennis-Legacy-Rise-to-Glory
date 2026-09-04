do $$
declare
  v_competition uuid;
begin
  select wc.id into v_competition
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_schedule_slots ss on ss.tournament_edition_id=ed.id
  where ts.name='Palm Springs Challenger'
    and wc.world='ATP'
    and ed.season_number=1
  group by wc.id
  having min(ss.season_week)=3 and max(ss.season_week)=3;

  if v_competition is null then
    raise exception 'Season 1 ATP Palm Springs Challenger Week 3 competition not found.';
  end if;

  delete from public.player_tournament_match_tactics t
  using public.tournament_matches m
  where t.match_id=m.id and m.competition_id=v_competition;

  delete from public.player_match_condition_events e
  using public.tournament_matches m
  where e.match_id=m.id and m.competition_id=v_competition;

  delete from public.player_equipment_wear_events e
  using public.tournament_matches m
  where e.match_id=m.id and m.competition_id=v_competition;

  delete from public.tournament_match_simulations s
  using public.tournament_matches m
  where s.match_id=m.id and m.competition_id=v_competition;

  delete from public.tournament_match_player_stats s
  using public.tournament_matches m
  where s.match_id=m.id and m.competition_id=v_competition;

  delete from public.tournament_match_sets s
  using public.tournament_matches m
  where s.match_id=m.id and m.competition_id=v_competition;

  delete from public.player_tournament_results
  where competition_id=v_competition;

  update public.tournament_entries
  set entry_status='active', updated_at=now()
  where competition_id=v_competition;

  update public.tournament_matches
  set status='scheduled',
      winner_id=null,
      started_at=null,
      completed_at=null,
      actual_duration_minutes=null,
      updated_at=now()
  where competition_id=v_competition
    and round_number=1;

  update public.tournament_matches
  set status='scheduled',
      player1_id=null,
      player2_id=null,
      winner_id=null,
      started_at=null,
      completed_at=null,
      actual_duration_minutes=null,
      updated_at=now()
  where competition_id=v_competition
    and round_number>1;
end $$;
