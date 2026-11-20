-- Snapshot of exact production DB function for isolated integration tests, 2026-11-20.
CREATE OR REPLACE FUNCTION public.advance_doubles_bracket_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_max integer;v_next_no integer;v_next_id uuid;v_loser uuid;v_feeders integer;v_t1 uuid;v_t2 uuid;v_s1 text;v_s2 text;
begin
  if new.status not in ('completed','walkover','bye','cancelled') then return new; end if;
  if tg_op='UPDATE' and old.status is not distinct from new.status and old.winner_team_id is not distinct from new.winner_team_id then return new; end if;
  v_max:=ceil(log(2::numeric,greatest(new.bracket_size,2)::numeric))::integer;
  if new.winner_team_id is not null then
    v_loser:=case when new.team1_id=new.winner_team_id then new.team2_id when new.team2_id=new.winner_team_id then new.team1_id else null end;
    if v_loser is not null then update public.tournament_doubles_teams set status=case when status='withdrawn' then 'withdrawn' else 'eliminated' end,updated_at=now() where id=v_loser; end if;
  end if;
  if new.round_number<v_max then
    v_next_no:=(new.match_number+1)/2;
    select id into v_next_id from public.tournament_doubles_matches where competition_id=new.competition_id and round_number=new.round_number+1 and match_number=v_next_no;
    if v_next_id is null then
      insert into public.tournament_doubles_matches(competition_id,round_number,round_label,match_number,bracket_size,scheduled_season_week,scheduled_day,status)
      values(new.competition_id,new.round_number+1,public.doubles_round_label_v1(new.bracket_size,new.round_number+1),v_next_no,new.bracket_size,new.scheduled_season_week,least(7,new.scheduled_day+1),'scheduled')
      on conflict(competition_id,round_number,match_number) do nothing returning id into v_next_id;
      if v_next_id is null then select id into v_next_id from public.tournament_doubles_matches where competition_id=new.competition_id and round_number=new.round_number+1 and match_number=v_next_no; end if;
    end if;
    if new.winner_team_id is not null then
      if mod(new.match_number,2)=1 then update public.tournament_doubles_matches set team1_id=new.winner_team_id,updated_at=now() where id=v_next_id;
      else update public.tournament_doubles_matches set team2_id=new.winner_team_id,updated_at=now() where id=v_next_id; end if;
    end if;
    select count(*) into v_feeders from public.tournament_doubles_matches f
    where f.competition_id=new.competition_id and f.round_number=new.round_number and f.match_number in (v_next_no*2-1,v_next_no*2)
      and f.status in ('completed','walkover','bye','cancelled');
    if v_feeders=2 then
      select team1_id,team2_id into v_t1,v_t2 from public.tournament_doubles_matches where id=v_next_id;
      if v_t1 is null and v_t2 is null then
        update public.tournament_doubles_matches set status='cancelled',completed_at=now(),updated_at=now() where id=v_next_id and status='scheduled';
      elsif (v_t1 is null)<>(v_t2 is null) then
        update public.tournament_doubles_matches set status='bye',winner_team_id=coalesce(v_t1,v_t2),completed_at=now(),updated_at=now() where id=v_next_id and status='scheduled';
      else
        select status into v_s1 from public.tournament_doubles_teams where id=v_t1;select status into v_s2 from public.tournament_doubles_teams where id=v_t2;
        if v_s1='withdrawn' and v_s2<>'withdrawn' then update public.tournament_doubles_matches set status='walkover',winner_team_id=v_t2,completion_reason='team_withdrawal',completed_at=now(),updated_at=now() where id=v_next_id;
        elsif v_s2='withdrawn' and v_s1<>'withdrawn' then update public.tournament_doubles_matches set status='walkover',winner_team_id=v_t1,completion_reason='team_withdrawal',completed_at=now(),updated_at=now() where id=v_next_id;
        elsif v_s1='withdrawn' and v_s2='withdrawn' then update public.tournament_doubles_matches set status='cancelled',completion_reason='both_teams_withdrawn',completed_at=now(),updated_at=now() where id=v_next_id;
        else perform public.schedule_doubles_match_v1(v_next_id); end if;
      end if;
    end if;
  elsif new.winner_team_id is not null then
    update public.tournament_doubles_teams set status='champion',updated_at=now() where id=new.winner_team_id;
  end if;
  return new;
end;$function$
;
