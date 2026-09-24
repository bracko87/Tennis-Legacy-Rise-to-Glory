CREATE OR REPLACE FUNCTION public.resolve_national_captain_election_v1(p_election_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_e public.national_captain_elections%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_current_season integer:=public.national_team_current_season_v1();
  v_candidate_count integer:=0;
  v_max_votes integer:=0;
  v_top_count integer:=0;
  v_winner uuid;
  v_candidate record;
  v_next_round integer;
  v_runoff_end integer;
  v_open_registration boolean:=false;
  v_title text;
  v_message text;
begin
  select * into v_e
  from public.national_captain_elections
  where id=p_election_id
  for update;

  if not found or v_e.status not in ('voting','runoff') then return; end if;

  if v_e.status='voting' then
    select count(*)::integer into v_candidate_count
    from public.national_captain_candidates c
    where c.election_id=v_e.id and c.status='active';

    if v_candidate_count>0 then
      select coalesce(max(x.vote_count),0)::integer
      into v_max_votes
      from (
        select c.id,count(v.id)::integer vote_count
        from public.national_captain_candidates c
        left join public.national_captain_votes v
          on v.election_id=v_e.id
         and v.round_number=v_e.current_round
         and v.candidate_id=c.id
        where c.election_id=v_e.id and c.status='active'
        group by c.id
      ) x;

      select count(*)::integer,min(x.candidate_id::text)::uuid
      into v_top_count,v_winner
      from (
        select c.id candidate_id,count(v.id)::integer vote_count
        from public.national_captain_candidates c
        left join public.national_captain_votes v
          on v.election_id=v_e.id
         and v.round_number=v_e.current_round
         and v.candidate_id=c.id
        where c.election_id=v_e.id and c.status='active'
        group by c.id
      ) x
      where x.vote_count=v_max_votes;
    end if;
  else
    select count(*)::integer into v_candidate_count
    from public.national_captain_runoff_candidates rc
    join public.national_captain_candidates c on c.id=rc.candidate_id and c.status='active'
    where rc.election_id=v_e.id
      and rc.round_number=v_e.current_round;

    if v_candidate_count>0 then
      select coalesce(max(x.vote_count),0)::integer
      into v_max_votes
      from (
        select rc.candidate_id,count(v.id)::integer vote_count
        from public.national_captain_runoff_candidates rc
        join public.national_captain_candidates c on c.id=rc.candidate_id and c.status='active'
        left join public.national_captain_votes v
          on v.election_id=rc.election_id
         and v.round_number=rc.round_number
         and v.candidate_id=rc.candidate_id
        where rc.election_id=v_e.id
          and rc.round_number=v_e.current_round
        group by rc.candidate_id
      ) x;

      select count(*)::integer,min(x.candidate_id::text)::uuid
      into v_top_count,v_winner
      from (
        select rc.candidate_id,count(v.id)::integer vote_count
        from public.national_captain_runoff_candidates rc
        join public.national_captain_candidates c on c.id=rc.candidate_id and c.status='active'
        left join public.national_captain_votes v
          on v.election_id=rc.election_id
         and v.round_number=rc.round_number
         and v.candidate_id=rc.candidate_id
        where rc.election_id=v_e.id
          and rc.round_number=v_e.current_round
        group by rc.candidate_id
      ) x
      where x.vote_count=v_max_votes;
    end if;
  end if;

  -- A winner must have at least one vote AND strictly more votes than every other candidate.
  if v_candidate_count=0 or v_max_votes<=0 or v_top_count<>1 then
    v_next_round:=v_e.current_round+1;
    v_runoff_end:=v_day+6; -- seven in-game days including the opening day
    v_open_registration:=(v_candidate_count=0);

    if v_candidate_count>0 then
      if v_e.status='voting' then
        insert into public.national_captain_runoff_candidates(
          election_id,round_number,candidate_id
        )
        select
          v_e.id,
          v_next_round,
          c.id
        from public.national_captain_candidates c
        left join public.national_captain_votes v
          on v.election_id=v_e.id
         and v.round_number=v_e.current_round
         and v.candidate_id=c.id
        where c.election_id=v_e.id
          and c.status='active'
        group by c.id
        having
          case
            when v_max_votes<=0 then true
            else count(v.id)::integer=v_max_votes
          end
        on conflict do nothing;
      else
        insert into public.national_captain_runoff_candidates(
          election_id,round_number,candidate_id
        )
        select
          v_e.id,
          v_next_round,
          rc.candidate_id
        from public.national_captain_runoff_candidates rc
        join public.national_captain_candidates c on c.id=rc.candidate_id and c.status='active'
        left join public.national_captain_votes v
          on v.election_id=rc.election_id
         and v.round_number=rc.round_number
         and v.candidate_id=rc.candidate_id
        where rc.election_id=v_e.id
          and rc.round_number=v_e.current_round
        group by rc.candidate_id
        having
          case
            when v_max_votes<=0 then true
            else count(v.id)::integer=v_max_votes
          end
        on conflict do nothing;
      end if;
    end if;

    update public.national_captain_elections
    set status='runoff',
        current_round=v_next_round,
        runoff_end_game_day=v_runoff_end,
        runoff_registration_open=v_open_registration,
        updated_at=now()
    where id=v_e.id;

    if v_candidate_count=0 then
      v_title:='Captain election extended';
      v_message:='No captain was elected. A new seven-day election round is open for candidate registration and voting.';
    elsif v_max_votes<=0 then
      v_title:='Captain election continues';
      v_message:='No candidate received a vote. The same candidates continue into another seven-day round.';
    else
      v_title:='Captain runoff required';
      v_message:='The leading candidates are tied. Only the tied leaders continue into a seven-day runoff.';
    end if;

    perform public.notify_national_association_members_v1(
      v_e.association_id,
      'national.captain.runoff',
      v_title,
      v_message,
      '/game/national-team?tab=elections',
      format('national-election-runoff:%s:%s',v_e.id,v_next_round),
      jsonb_build_object(
        'election_id',v_e.id,
        'round',v_next_round,
        'runoff_end_game_day',v_runoff_end,
        'registration_open',v_open_registration
      )
    );

    perform public.national_team_record_event_v1(
      v_e.association_id,
      'captain_election_runoff',
      jsonb_build_object(
        'election_id',v_e.id,
        'round',v_next_round,
        'runoff_end_game_day',v_runoff_end,
        'registration_open',v_open_registration
      ),
      v_current_season
    );

    return;
  end if;

  select c.id,c.membership_id,c.user_id,c.player_id
  into v_candidate
  from public.national_captain_candidates c
  where c.id=v_winner;

  if v_candidate.id is null then return; end if;

  update public.national_captain_elections
  set status='completed',
      winning_candidate_id=v_winner,
      completed_game_day=v_day,
      runoff_registration_open=false,
      updated_at=now()
  where id=v_e.id;

  update public.national_captain_terms
  set status='completed',
      term_end_game_day=greatest(term_start_game_day,v_day-1)
  where association_id=v_e.association_id
    and status='active';

  insert into public.national_captain_terms(
    association_id,election_id,candidate_id,membership_id,user_id,player_id,
    season_number,term_start_game_day,term_end_game_day,status,term_kind
  )
  values(
    v_e.association_id,v_e.id,v_candidate.id,v_candidate.membership_id,
    v_candidate.user_id,v_candidate.player_id,v_current_season,
    v_day,public.game_day_absolute_v1(v_current_season,12,31),'active','elected'
  );

  perform public.national_team_record_event_v1(
    v_e.association_id,
    'captain_elected',
    jsonb_build_object(
      'election_id',v_e.id,
      'candidate_id',v_candidate.id,
      'player_id',v_candidate.player_id,
      'round',v_e.current_round
    ),
    v_current_season
  );

  perform public.notify_national_association_members_v1(
    v_e.association_id,
    'national.captain.elected',
    'National captain elected',
    'A captain election has produced a unique winner. The new captain is now in office.',
    '/game/national-team?tab=elections',
    format('national-election-winner:%s',v_e.id),
    jsonb_build_object(
      'election_id',v_e.id,
      'candidate_id',v_candidate.id,
      'player_id',v_candidate.player_id
    )
  );
end;
$function$
