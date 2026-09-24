
create or replace function public.register_national_captain_candidate_v1(
  p_election_id uuid,
  p_manifesto text
)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_e public.national_captain_elections%rowtype;
  v_membership record;
  v_candidate uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_manifesto text:=btrim(coalesce(p_manifesto,''));
  v_registration_allowed boolean:=false;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if char_length(v_manifesto)<10 or char_length(v_manifesto)>1000 then
    raise exception 'Manifesto must contain between 10 and 1000 characters.';
  end if;

  select * into v_e
  from public.national_captain_elections
  where id=p_election_id
  for update;

  if not found then raise exception 'Election not found.'; end if;

  if v_e.status='candidate_registration'
     and v_day between v_e.registration_start_game_day and v_e.registration_end_game_day then
    v_registration_allowed:=true;
  elsif v_e.status='runoff'
        and v_e.runoff_registration_open
        and v_e.runoff_end_game_day is not null
        and v_day<=v_e.runoff_end_game_day then
    v_registration_allowed:=true;
  end if;

  if not v_registration_allowed then
    raise exception 'Candidate registration is closed.';
  end if;

  select m.id as membership_id,m.player_id
  into v_membership
  from public.national_association_memberships m
  where m.association_id=v_e.association_id
    and m.user_id=v_uid
    and m.status='active'
    and m.captain_eligible
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  if not found then
    raise exception 'You are not eligible to stand in this association election.';
  end if;

  insert into public.national_captain_candidates(
    election_id,membership_id,user_id,player_id,manifesto,status
  )
  values(
    v_e.id,v_membership.membership_id,v_uid,v_membership.player_id,v_manifesto,'active'
  )
  on conflict(election_id,user_id) do update
  set manifesto=excluded.manifesto,status='active'
  returning id into v_candidate;

  if v_e.status='runoff' and v_e.runoff_registration_open then
    insert into public.national_captain_runoff_candidates(
      election_id,round_number,candidate_id
    )
    values(v_e.id,v_e.current_round,v_candidate)
    on conflict do nothing;
  end if;

  return v_candidate;
end;
$$;

revoke all on function public.register_national_captain_candidate_v1(uuid,text)
  from public,anon,authenticated;
grant execute on function public.register_national_captain_candidate_v1(uuid,text)
  to authenticated;

create or replace function public.resolve_national_captain_election_v1(
  p_election_id uuid
)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
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

      select count(*)::integer,min(x.candidate_id)
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

      select count(*)::integer,min(x.candidate_id)
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
$$;

revoke all on function public.resolve_national_captain_election_v1(uuid)
  from public,anon,authenticated;

create or replace function public.resign_national_captain_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_term public.national_captain_terms%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_season integer:=public.national_team_current_season_v1();
  v_election uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_term
  from public.national_captain_terms
  where user_id=v_uid
    and status='active'
  order by term_start_game_day desc
  limit 1
  for update;

  if not found then raise exception 'You are not the active national captain.'; end if;

  update public.national_captain_terms
  set status='vacated',
      term_end_game_day=greatest(term_start_game_day,v_day)
  where id=v_term.id;

  perform public.national_team_record_event_v1(
    v_term.association_id,
    'captain_resigned',
    jsonb_build_object('player_id',v_term.player_id,'term_id',v_term.id),
    v_season
  );

  perform public.notify_national_association_members_v1(
    v_term.association_id,
    'national.captain.vacancy',
    'National captain resigned',
    'The captain has resigned. A replacement election is now required.',
    '/game/national-team?tab=elections',
    format('national-captain-resigned:%s:%s',v_term.association_id,v_day),
    jsonb_build_object('player_id',v_term.player_id,'reason','captain_resigned')
  );

  v_election:=public.open_national_captain_election_v2(
    v_term.association_id,
    v_season,
    'special',
    'captain_resigned',
    v_day,
    v_day+9
  );

  return jsonb_build_object(
    'status','resigned',
    'association_id',v_term.association_id,
    'election_id',v_election
  );
end;
$$;

revoke all on function public.resign_national_captain_v1()
  from public,anon,authenticated;
grant execute on function public.resign_national_captain_v1()
  to authenticated;

create or replace function public.process_national_association_lifecycle_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_cfg public.national_team_config%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_season integer:=public.national_team_current_season_v1();
  v_jan1 integer:=public.game_day_absolute_v1(public.national_team_current_season_v1(),1,1);
  v_jan10 integer:=public.game_day_absolute_v1(public.national_team_current_season_v1(),1,10);
  v_jan20 integer:=public.game_day_absolute_v1(public.national_team_current_season_v1(),1,20);
  v_jan31 integer:=public.game_day_absolute_v1(public.national_team_current_season_v1(),1,31);
  v_open integer:=0;
  v_suspended integer:=0;
  v_transitioned integer:=0;
  v_vacated integer:=0;
  a record;
  e record;
  t record;
  v_fund_id uuid;
  v_election_id uuid;
begin
  select * into v_cfg from public.national_team_config where id=1;

  -- Close prior-season terms, then retain the previous elected captain as acting captain
  -- until the current season produces a unique winner.
  update public.national_captain_terms
  set status='completed'
  where status='active'
    and term_end_game_day<v_day;

  for a in
    select id,activated_season,status
    from public.national_associations
    where activated_game_day is not null
      and activated_season<v_season
      and status in ('active','renewal_required','suspended')
  loop
    perform public.carry_forward_national_captain_v1(a.id,v_season);
  end loop;

  -- If the acting/elected captain becomes ineligible, vacate immediately and trigger a replacement election.
  for t in
    select term.*
    from public.national_captain_terms term
    left join public.national_association_memberships m
      on m.id=term.membership_id
     and m.status='active'
    left join public.players p
      on p.id=term.player_id
    where term.status='active'
      and term.season_number=v_season
      and (
        m.id is null
        or p.id is null
        or p.owner_user_id is distinct from term.user_id
        or p.player_type<>'human'
        or p.moderation_status='rejected'
      )
  loop
    update public.national_captain_terms
    set status='vacated',
        term_end_game_day=greatest(term_start_game_day,v_day)
    where id=t.id;

    perform public.national_team_record_event_v1(
      t.association_id,
      'captain_became_inactive',
      jsonb_build_object('player_id',t.player_id,'term_id',t.id),
      v_season
    );

    perform public.notify_national_association_members_v1(
      t.association_id,
      'national.captain.vacancy',
      'National captain is no longer active',
      'The previous captain is no longer eligible. A replacement election is now required.',
      '/game/national-team?tab=elections',
      format('national-captain-inactive:%s:%s',t.association_id,v_day),
      jsonb_build_object('player_id',t.player_id,'reason','captain_inactive')
    );

    perform public.open_national_captain_election_v2(
      t.association_id,v_season,'special','captain_inactive',v_day,v_day+9
    );
    v_vacated:=v_vacated+1;
  end loop;

  -- January renewal: same-season fund, open 1 January, deadline 31 January.
  for a in
    select *
    from public.national_associations
    where activated_game_day is not null
      and activated_season<v_season
      and status in ('active','renewal_required','suspended')
  loop
    insert into public.national_association_funds(
      association_id,fund_type,season_number,target_amount,contributed_amount,
      status,opens_game_day,deadline_game_day
    )
    values(
      a.id,'season_renewal',v_season,v_cfg.renewal_cost,0,
      'open',v_jan1,v_jan31
    )
    on conflict do nothing
    returning id into v_fund_id;

    if v_fund_id is not null then
      v_open:=v_open+1;

      if a.status='active' then
        update public.national_associations
        set status='renewal_required',updated_at=now()
        where id=a.id;
      end if;

      perform public.national_team_record_event_v1(
        a.id,
        'season_renewal_opened',
        jsonb_build_object(
          'season_number',v_season,
          'renewal_cost',v_cfg.renewal_cost,
          'deadline_game_day',v_jan31
        ),
        v_season
      );

      if v_day<=v_jan31 then
        perform public.notify_national_association_members_v1(
          a.id,
          'national.association.renewal',
          'National association renewal is open',
          format('Season %s renewal requires %s community coins by 31 January. If it is not completed, the association becomes inactive from 1 February.',v_season,v_cfg.renewal_cost),
          '/game/national-team?tab=overview',
          format('national-renewal-open:%s:%s',a.id,v_season),
          jsonb_build_object('season_number',v_season,'renewal_cost',v_cfg.renewal_cost,'deadline_game_day',v_jan31)
        );
      end if;

      v_fund_id:=null;
    end if;
  end loop;

  -- Annual election begins 10 January and first round closes after 20 January.
  if v_day>=v_jan10 then
    for a in
      select id
      from public.national_associations
      where activated_game_day is not null
        and activated_season<v_season
        and status in ('active','renewal_required','suspended')
    loop
      if not exists(
        select 1
        from public.national_captain_elections ce
        where ce.association_id=a.id
          and ce.season_number=v_season
          and ce.election_kind='annual'
      )
      and not exists(
        select 1
        from public.national_captain_terms ct
        where ct.association_id=a.id
          and ct.status='active'
          and ct.term_kind='elected'
          and ct.term_start_game_day>=v_jan1
      ) then
        v_election_id:=public.open_national_captain_election_v2(
          a.id,
          v_season,
          'annual',
          'annual_january_election',
          case when v_day<=v_jan20 then v_jan10 else v_day end,
          case when v_day<=v_jan20 then v_jan20 else v_day+9 end
        );
      end if;
    end loop;
  end if;

  -- On 1 February, unpaid renewal funds expire and the association loses its sporting place.
  if v_day>v_jan31 then
    for a in
      select na.id,na.status,f.id fund_id
      from public.national_associations na
      join public.national_association_funds f
        on f.association_id=na.id
       and f.fund_type='season_renewal'
       and f.season_number=v_season
      where na.activated_game_day is not null
        and f.status='open'
    loop
      update public.national_association_funds
      set status='expired',updated_at=now()
      where id=a.fund_id;

      update public.national_associations
      set status='suspended',updated_at=now()
      where id=a.id;

      update public.national_team_division_entries
      set status='withdrawn',updated_at=now()
      where association_id=a.id
        and season_number=v_season
        and status='active';

      perform public.national_team_record_event_v1(
        a.id,
        'season_renewal_failed',
        jsonb_build_object('season_number',v_season,'deadline_game_day',v_jan31),
        v_season
      );

      perform public.notify_national_association_members_v1(
        a.id,
        'national.association.renewal',
        'National association is inactive',
        'The January renewal was not completed before 1 February. The association has lost its sporting place and must re-enter through the lower competition structure when renewed.',
        '/game/national-team?tab=overview',
        format('national-renewal-failed:%s:%s',a.id,v_season),
        jsonb_build_object('season_number',v_season,'status','suspended')
      );

      v_suspended:=v_suspended+1;
    end loop;

    perform public.prepare_national_team_division_entries_v1(v_season);
  end if;

  -- Election stages advance from registration -> campaign -> voting, then repeated 7-day runoffs.
  for e in
    select *
    from public.national_captain_elections
    where status in ('candidate_registration','campaign','voting','runoff')
  loop
    if e.status='candidate_registration' and v_day>e.registration_end_game_day then
      update public.national_captain_elections
      set status='campaign',updated_at=now()
      where id=e.id;
      v_transitioned:=v_transitioned+1;
    elsif e.status='campaign' and v_day>e.campaign_end_game_day then
      update public.national_captain_elections
      set status='voting',updated_at=now()
      where id=e.id;
      v_transitioned:=v_transitioned+1;
    elsif e.status='voting' and v_day>e.voting_end_game_day then
      perform public.resolve_national_captain_election_v1(e.id);
      v_transitioned:=v_transitioned+1;
    elsif e.status='runoff'
      and e.runoff_end_game_day is not null
      and v_day>e.runoff_end_game_day then
      perform public.resolve_national_captain_election_v1(e.id);
      v_transitioned:=v_transitioned+1;
    end if;
  end loop;

  return jsonb_build_object(
    'game_day',v_day,
    'season',v_season,
    'renewal_funds_opened',v_open,
    'associations_suspended',v_suspended,
    'captain_vacancies',v_vacated,
    'election_transitions',v_transitioned
  );
end;
$$;

revoke all on function public.process_national_association_lifecycle_v1()
  from public,anon,authenticated;
