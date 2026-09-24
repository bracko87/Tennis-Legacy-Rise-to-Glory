CREATE OR REPLACE FUNCTION public.open_national_captain_election_v2(p_association_id uuid, p_season_number integer, p_election_kind text, p_reason text, p_start_game_day integer, p_first_round_end_game_day integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_existing uuid;
  v_id uuid;
  v_reg_end integer;
  v_voting_start integer;
  v_title text;
  v_message text;
begin
  if p_election_kind not in ('annual','activation','special') then
    raise exception 'Invalid national captain election kind.';
  end if;

  select id into v_existing
  from public.national_captain_elections
  where association_id=p_association_id
    and status in ('candidate_registration','campaign','voting','runoff')
  order by created_at desc
  limit 1;

  if v_existing is not null then return v_existing; end if;

  if p_election_kind='annual' then
    select id into v_existing
    from public.national_captain_elections
    where association_id=p_association_id
      and season_number=p_season_number
      and election_kind='annual'
    limit 1;
    if v_existing is not null then return v_existing; end if;
  end if;

  -- Three-stage election model:
  -- 1) Candidate registration: 10 game days beginning at p_start_game_day.
  -- 2) Main voting round: starts immediately after registration and ends at p_first_round_end_game_day.
  -- 3) Runoff: generated only if needed, seven game days per round.
  if p_election_kind='annual' then
    -- Annual fixed calendar: candidate registration is 1–10 January,
    -- and the main vote opens on 10 January.
    v_voting_start:=p_start_game_day+9;
    v_reg_end:=v_voting_start-1;
  else
    -- First activation / replacement: give members a full 10 game days
    -- before the main vote opens.
    v_reg_end:=p_start_game_day+9;
    v_voting_start:=p_start_game_day+10;
  end if;

  if p_first_round_end_game_day < v_voting_start then
    raise exception 'Main election round must end after candidate registration closes.';
  end if;

  insert into public.national_captain_elections(
    association_id,season_number,status,
    registration_start_game_day,registration_end_game_day,
    campaign_end_game_day,voting_start_game_day,voting_end_game_day,
    runoff_start_game_day,runoff_end_game_day,
    current_round,winning_candidate_id,completed_game_day,
    election_kind,reason,runoff_registration_open
  )
  values(
    p_association_id,p_season_number,'candidate_registration',
    p_start_game_day,v_reg_end,
    v_reg_end,v_voting_start,p_first_round_end_game_day,
    null,null,
    1,null,null,p_election_kind,p_reason,false
  )
  returning id into v_id;

  perform public.national_team_record_event_v1(
    p_association_id,
    'captain_election_opened',
    jsonb_build_object(
      'election_id',v_id,
      'season_number',p_season_number,
      'election_kind',p_election_kind,
      'reason',p_reason,
      'registration_start_game_day',p_start_game_day,
      'registration_end_game_day',v_reg_end,
      'voting_start_game_day',v_voting_start,
      'voting_end_game_day',p_first_round_end_game_day
    ),
    p_season_number
  );

  if p_reason='captain_resigned' then
    v_title:='Captain resigned — candidate registration open';
    v_message:='The captain has resigned. Members have 10 game days to register candidates before the replacement vote opens.';
  elsif p_reason='captain_inactive' then
    v_title:='Captain unavailable — candidate registration open';
    v_message:='The previous captain is no longer eligible. Members have 10 game days to register replacement candidates before voting opens.';
  elsif p_election_kind='annual' then
    v_title:='Annual captain candidate registration is open';
    v_message:='Candidate registration runs from 1 January until voting opens on 10 January. The main election then runs through 20 January.';
  else
    v_title:='First captain candidate registration is open';
    v_message:='The association is active. Members now have 10 game days to register a candidacy and manifesto before the main election begins.';
  end if;

  perform public.notify_national_association_members_v1(
    p_association_id,
    'national.captain.election',
    v_title,
    v_message,
    '/game/national-team?tab=elections',
    format('national-election-open:%s:%s',p_association_id,v_id),
    jsonb_build_object(
      'election_id',v_id,
      'election_kind',p_election_kind,
      'reason',p_reason,
      'phase','candidate_registration',
      'registration_end_game_day',v_reg_end,
      'voting_start_game_day',v_voting_start,
      'voting_end_game_day',p_first_round_end_game_day
    )
  );

  return v_id;
end;
$function$
