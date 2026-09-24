
create unique index if not exists national_captain_votes_one_user_per_round_uidx
  on public.national_captain_votes(election_id,round_number,voter_user_id);

create or replace function public.cast_national_captain_vote_v1(
  p_election_id uuid,
  p_candidate_id uuid
)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_e public.national_captain_elections%rowtype;
  v_membership uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_e
  from public.national_captain_elections
  where id=p_election_id;

  if not found then raise exception 'Election not found.'; end if;

  if v_e.status not in ('voting','runoff') then
    raise exception 'Voting is not currently open.';
  end if;

  if v_e.status='voting' and v_day>v_e.voting_end_game_day then
    raise exception 'Voting has closed.';
  end if;

  if v_e.status='runoff'
     and (v_e.runoff_end_game_day is null or v_day>v_e.runoff_end_game_day) then
    raise exception 'Runoff voting has closed.';
  end if;

  if exists(
    select 1
    from public.national_captain_votes vote
    where vote.election_id=v_e.id
      and vote.round_number=v_e.current_round
      and vote.voter_user_id=v_uid
  ) then
    raise exception 'You have already voted in this round. A captain-election vote is final and cannot be changed or withdrawn.';
  end if;

  select m.id into v_membership
  from public.national_association_memberships m
  where m.association_id=v_e.association_id
    and m.user_id=v_uid
    and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if v_membership is null then
    raise exception 'Only active association members may vote.';
  end if;

  if not exists(
    select 1
    from public.national_captain_candidates c
    where c.id=p_candidate_id
      and c.election_id=v_e.id
      and c.status='active'
  ) then
    raise exception 'Candidate is not eligible in this election.';
  end if;

  if v_e.status='runoff' and not exists(
    select 1
    from public.national_captain_runoff_candidates rc
    where rc.election_id=v_e.id
      and rc.round_number=v_e.current_round
      and rc.candidate_id=p_candidate_id
  ) then
    raise exception 'Candidate is not part of the current runoff.';
  end if;

  insert into public.national_captain_votes(
    election_id,round_number,membership_id,voter_user_id,
    candidate_id,cast_game_day
  )
  values(
    v_e.id,v_e.current_round,v_membership,v_uid,p_candidate_id,v_day
  );
end;
$$;

create or replace function public.withdraw_national_captain_candidate_v1(
  p_election_id uuid
)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_e public.national_captain_elections%rowtype;
  v_candidate public.national_captain_candidates%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_e
  from public.national_captain_elections
  where id=p_election_id
  for update;

  if not found then raise exception 'Election not found.'; end if;

  if not (
    (v_e.status='candidate_registration'
      and v_day between v_e.registration_start_game_day and v_e.registration_end_game_day)
    or
    (v_e.status='runoff'
      and v_e.runoff_registration_open
      and v_e.runoff_end_game_day is not null
      and v_day<=v_e.runoff_end_game_day)
  ) then
    raise exception 'Candidate withdrawal is closed. Once voting begins, the candidate list is locked for that round.';
  end if;

  select * into v_candidate
  from public.national_captain_candidates c
  where c.election_id=v_e.id
    and c.user_id=v_uid
    and c.status='active'
  limit 1
  for update;

  if not found then
    raise exception 'You do not have an active candidacy in this election.';
  end if;

  update public.national_captain_candidates
  set status='withdrawn'
  where id=v_candidate.id;

  delete from public.national_captain_runoff_candidates
  where election_id=v_e.id
    and candidate_id=v_candidate.id
    and round_number=v_e.current_round;

  perform public.national_team_record_event_v1(
    v_e.association_id,
    'captain_candidate_withdrew',
    jsonb_build_object(
      'election_id',v_e.id,
      'candidate_id',v_candidate.id,
      'player_id',v_candidate.player_id,
      'round',v_e.current_round
    ),
    v_e.season_number
  );
end;
$$;

revoke all on function public.cast_national_captain_vote_v1(uuid,uuid) from public,anon,authenticated;
grant execute on function public.cast_national_captain_vote_v1(uuid,uuid) to authenticated;

revoke all on function public.withdraw_national_captain_candidate_v1(uuid) from public,anon,authenticated;
grant execute on function public.withdraw_national_captain_candidate_v1(uuid) to authenticated;

-- Direct table mutation is unnecessary: all writes go through the security-definer RPCs.
revoke insert,update,delete,truncate on public.national_captain_votes from anon,authenticated;
