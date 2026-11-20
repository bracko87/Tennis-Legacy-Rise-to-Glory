-- Snapshot of exact production DB function for isolated integration tests, 2026-11-20.
CREATE OR REPLACE FUNCTION public.advance_tournament_bracket_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_max_round smallint;
  v_next_no integer;
  v_next_id uuid;
  v_next_label text;
  v_loser uuid;
  v_target_slot integer;
  v_target_match integer;
  v_feeders_done integer;
  v_next_p1 uuid;
  v_next_p2 uuid;
  v_category public.tournament_categories%rowtype;
begin
  if new.status not in ('completed','bye','walkover','cancelled') then
    return new;
  end if;

  if tg_op='UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  select tc.* into v_category
  from public.tournament_world_competitions wc
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  join public.tournament_categories tc on tc.code=ts.category_code
  where wc.id=new.competition_id;

  v_max_round:=case
    when new.draw_type='main_draw'
      then ceil(log(2::numeric,greatest(new.bracket_size,2)::numeric))::smallint
    else v_category.qualification_rounds_max
  end;

  if new.winner_id is not null then
    v_loser:=case
      when new.player1_id=new.winner_id then new.player2_id
      when new.player2_id=new.winner_id then new.player1_id
      else null
    end;

    if v_loser is not null then
      update public.tournament_entries
      set entry_status='eliminated',updated_at=now()
      where competition_id=new.competition_id
        and player_id=v_loser;
    end if;
  end if;

  if new.round_number<v_max_round then
    v_next_no:=(new.match_number+1)/2;

    select id into v_next_id
    from public.tournament_matches
    where competition_id=new.competition_id
      and draw_type=new.draw_type
      and round_number=new.round_number+1
      and match_number=v_next_no;

    if v_next_id is null then
      v_next_label:=public.tournament_round_label_v1(
        new.draw_type,
        new.bracket_size,
        new.round_number+1,
        v_max_round
      );

      insert into public.tournament_matches(
        competition_id,draw_type,round_number,round_label,match_number,
        bracket_size,scheduled_season_week,scheduled_day,status
      )
      values(
        new.competition_id,new.draw_type,new.round_number+1,v_next_label,v_next_no,
        new.bracket_size,new.scheduled_season_week,least(7,new.scheduled_day+1),'scheduled'
      )
      on conflict(competition_id,draw_type,round_number,match_number) do nothing
      returning id into v_next_id;

      if v_next_id is null then
        select id into v_next_id
        from public.tournament_matches
        where competition_id=new.competition_id
          and draw_type=new.draw_type
          and round_number=new.round_number+1
          and match_number=v_next_no;
      end if;
    end if;

    -- Fast-path propagation for the current feeder. The authoritative
    -- two-feeder reconciliation below will correct both slots once both
    -- feeder matches are terminal.
    if new.winner_id is not null then
      if mod(new.match_number,2)=1 then
        update public.tournament_matches
        set player1_id=new.winner_id,updated_at=now()
        where id=v_next_id
          and player1_id is null;
      else
        update public.tournament_matches
        set player2_id=new.winner_id,updated_at=now()
        where id=v_next_id
          and player2_id is null;
      end if;
    end if;

    select count(*) into v_feeders_done
    from public.tournament_matches f
    where f.competition_id=new.competition_id
      and f.draw_type=new.draw_type
      and f.round_number=new.round_number
      and f.match_number in(v_next_no*2-1,v_next_no*2)
      and f.status in('completed','bye','walkover','cancelled');

    if v_feeders_done=2 then
      -- IMPORTANT: derive the next-round slots directly from the two feeder
      -- outcomes instead of trusting trigger execution order. A set-based
      -- UPDATE can make both feeder statuses visible before both AFTER ROW
      -- triggers have propagated their winners, which previously created
      -- false one-player byes.
      select
        (
          select f1.winner_id
          from public.tournament_matches f1
          where f1.competition_id=new.competition_id
            and f1.draw_type=new.draw_type
            and f1.round_number=new.round_number
            and f1.match_number=v_next_no*2-1
          limit 1
        ),
        (
          select f2.winner_id
          from public.tournament_matches f2
          where f2.competition_id=new.competition_id
            and f2.draw_type=new.draw_type
            and f2.round_number=new.round_number
            and f2.match_number=v_next_no*2
          limit 1
        )
      into v_next_p1,v_next_p2;

      update public.tournament_matches
      set player1_id=v_next_p1,
          player2_id=v_next_p2,
          updated_at=now()
      where id=v_next_id
        and status in ('scheduled','bye','cancelled');

      if v_next_p1 is null and v_next_p2 is null then
        update public.tournament_matches
        set status='cancelled',
            winner_id=null,
            completed_at=coalesce(completed_at,now()),
            updated_at=now()
        where id=v_next_id
          and status in ('scheduled','bye','cancelled');

      elsif (v_next_p1 is null)<>(v_next_p2 is null) then
        update public.tournament_matches
        set status='bye',
            winner_id=coalesce(v_next_p1,v_next_p2),
            completed_at=coalesce(completed_at,now()),
            updated_at=now()
        where id=v_next_id
          and status in ('scheduled','bye','cancelled');

      else
        -- Both feeders produced real winners. If an earlier trigger firing
        -- prematurely marked the next match as bye/cancelled, reopen it as
        -- the real two-player match.
        update public.tournament_matches
        set status='scheduled',
            winner_id=null,
            completed_at=null,
            updated_at=now()
        where id=v_next_id
          and status in ('bye','cancelled');
      end if;
    end if;

  else
    if new.draw_type='qualification' then
      select bracket_slot into v_target_slot
      from public.tournament_qualifier_slots
      where competition_id=new.competition_id
        and section_number=new.match_number;

      if v_target_slot is not null then
        update public.tournament_qualifier_slots
        set resolved=true,
            filled_player_id=new.winner_id
        where competition_id=new.competition_id
          and section_number=new.match_number;

        if new.winner_id is not null then
          update public.tournament_entries
          set draw_type='main_draw',
              entry_status='active',
              seed_number=null,
              bracket_slot=v_target_slot,
              updated_at=now()
          where competition_id=new.competition_id
            and player_id=new.winner_id;

          v_target_match:=(v_target_slot+1)/2;

          if mod(v_target_slot,2)=1 then
            update public.tournament_matches
            set player1_id=new.winner_id,updated_at=now()
            where competition_id=new.competition_id
              and draw_type='main_draw'
              and round_number=1
              and match_number=v_target_match;
          else
            update public.tournament_matches
            set player2_id=new.winner_id,updated_at=now()
            where competition_id=new.competition_id
              and draw_type='main_draw'
              and round_number=1
              and match_number=v_target_match;
          end if;
        end if;

        perform public.resolve_main_first_round_match_v1(
          new.competition_id,
          (v_target_slot+1)/2
        );
      end if;

    elsif new.winner_id is not null then
      update public.tournament_entries
      set entry_status='champion',updated_at=now()
      where competition_id=new.competition_id
        and player_id=new.winner_id;
    end if;
  end if;

  return new;
end;
$function$
;
