create or replace function public.lock_match_simulation_payload_v1()
returns trigger language plpgsql set search_path='public' as $$
begin
  if old.engine_version is distinct from new.engine_version
     or old.engine_seed is distinct from new.engine_seed
     or old.replay_schema_version is distinct from new.replay_schema_version
     or old.replay_duration_seconds is distinct from new.replay_duration_seconds
     or old.total_points is distinct from new.total_points
     or old.total_games is distinct from new.total_games
     or old.final_winner_id is distinct from new.final_winner_id
     or old.final_score is distinct from new.final_score
     or old.sets_payload is distinct from new.sets_payload
     or old.player1_stats is distinct from new.player1_stats
     or old.player2_stats is distinct from new.player2_stats
     or old.events_payload is distinct from new.events_payload
     or old.metadata is distinct from new.metadata
  then raise exception 'Match simulation payload is immutable after registration.';end if;
  if old.simulation_status='completed' and new.simulation_status<>'completed' then raise exception 'Completed simulation cannot be reopened.';end if;
  if old.simulation_status='live' and new.simulation_status='prepared' then raise exception 'Live simulation cannot return to prepared.';end if;
  return new;
end;$$;
revoke all on function public.lock_match_simulation_payload_v1() from public,anon,authenticated;
drop trigger if exists lock_match_simulation_payload_v1 on public.tournament_match_simulations;
create trigger lock_match_simulation_payload_v1 before update on public.tournament_match_simulations for each row execute function public.lock_match_simulation_payload_v1();
