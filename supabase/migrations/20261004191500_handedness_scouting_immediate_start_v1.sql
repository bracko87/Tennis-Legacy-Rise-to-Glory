-- Immediate opponent-scouting start + identity immutability.
-- pg_cron remains the independent recovery path; this trigger starts preparation
-- at the moment both players become known instead of waiting for the next cron tick.

create or replace function public.start_match_opponent_scouting_v1()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $$
declare
  v_player_id uuid;
  v_target_player_id uuid;
  v_staff_id uuid;
  v_now bigint:=public.current_game_second_v1();
begin
  if new.status<>'scheduled'
     or new.player1_id is null
     or new.player2_id is null then
    return new;
  end if;

  foreach v_player_id in array array[new.player1_id,new.player2_id] loop
    select sm.id
    into v_staff_id
    from public.players hp
    join public.player_staff_contracts c
      on c.player_id=hp.id
     and c.role='performance_analyst'
     and c.status='active'
    join public.staff_members sm on sm.id=c.staff_id
    where hp.id=v_player_id
      and hp.player_type='human'
      and hp.owner_user_id is not null
    order by c.signed_at desc
    limit 1;

    if v_staff_id is not null then
      v_target_player_id:=case
        when v_player_id=new.player1_id then new.player2_id
        else new.player1_id
      end;

      insert into public.player_opponent_scouting_tasks(
        player_id,target_player_id,match_id,analyst_staff_id,started_game_second
      )
      values(
        v_player_id,v_target_player_id,new.id,v_staff_id,v_now
      )
      on conflict(player_id,match_id) do update
        set target_player_id=excluded.target_player_id,
            analyst_staff_id=excluded.analyst_staff_id,
            updated_at=now();
    end if;

    v_staff_id:=null;
  end loop;

  return new;
end;
$$;

drop trigger if exists start_match_opponent_scouting_v1 on public.tournament_matches;
create trigger start_match_opponent_scouting_v1
after insert or update of player1_id,player2_id,status
on public.tournament_matches
for each row
when (
  new.status='scheduled'
  and new.player1_id is not null
  and new.player2_id is not null
)
execute function public.start_match_opponent_scouting_v1();

create or replace function public.protect_human_playing_hand_v1()
returns trigger
language plpgsql
set search_path to 'public','pg_temp'
as $$
begin
  if old.player_type='human'
     and old.playing_hand is distinct from new.playing_hand
     and coalesce(auth.role(),'')<>'service_role' then
    raise exception 'Playing hand is fixed after career creation.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_human_playing_hand_v1 on public.players;
create trigger protect_human_playing_hand_v1
before update of playing_hand
on public.players
for each row
execute function public.protect_human_playing_hand_v1();

select public.ensure_due_opponent_scouting_tasks_v1();
select public.check_player_identity_tactics_health_v1();
