
alter table public.national_captain_elections
  add column if not exists voting_start_game_day integer,
  add column if not exists runoff_start_game_day integer;

update public.national_captain_elections
set voting_start_game_day = coalesce(voting_start_game_day, campaign_end_game_day + 1)
where voting_start_game_day is null;

create or replace function public.open_national_captain_election_v2(
  p_association_id uuid,
  p_season_number integer,
  p_election_kind text,
  p_reason text,
  p_start_game_day integer,
  p_first_round_end_game_day integer
)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
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
  v_reg_end:=p_start_game_day+9;
  v_voting_start:=p_start_game_day+10;

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
$$;

create or replace function public.ensure_national_captain_election_v1(
  p_association_id uuid,
  p_season_number integer
)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_day integer:=public.national_team_current_abs_day_v1();
  v_current_season integer:=public.national_team_current_season_v1();
  v_assoc public.national_associations%rowtype;
  v_existing uuid;
  v_jan1 integer;
  v_jan20 integer;
begin
  select * into v_assoc
  from public.national_associations
  where id=p_association_id;

  if not found or p_season_number<>v_current_season then return null; end if;

  select id into v_existing
  from public.national_captain_elections
  where association_id=p_association_id
    and status in ('candidate_registration','campaign','voting','runoff')
  order by created_at desc
  limit 1;

  if v_existing is not null then return v_existing; end if;

  -- First activation: 10 game days candidate registration, then 10 game days main vote.
  if v_assoc.activated_season=v_current_season
     and not exists(
       select 1 from public.national_captain_elections
       where association_id=p_association_id
     ) then
    return public.open_national_captain_election_v2(
      p_association_id,
      v_current_season,
      'activation',
      'association_activated',
      v_day,
      v_day+20
    );
  end if;

  v_jan1:=public.game_day_absolute_v1(v_current_season,1,1);
  v_jan20:=public.game_day_absolute_v1(v_current_season,1,20);

  -- Annual process begins on 1 January with candidate registration.
  if v_day>=v_jan1
     and v_assoc.activated_season<v_current_season
     and not exists(
       select 1
       from public.national_captain_elections
       where association_id=p_association_id
         and season_number=v_current_season
         and election_kind='annual'
     ) then
    return public.open_national_captain_election_v2(
      p_association_id,
      v_current_season,
      'annual',
      'annual_january_election',
      case when v_day<=v_jan20 then v_jan1 else v_day end,
      case when v_day<=v_jan20 then v_jan20 else v_day+20 end
    );
  end if;

  return null;
end;
$$;

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
  v_runoff_start integer;
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

  if v_candidate_count=0 or v_max_votes<=0 or v_top_count<>1 then
    v_next_round:=v_e.current_round+1;
    v_runoff_start:=v_day;
    v_runoff_end:=v_day+6;
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
        runoff_start_game_day=v_runoff_start,
        runoff_end_game_day=v_runoff_end,
        runoff_registration_open=v_open_registration,
        updated_at=now()
    where id=v_e.id;

    if v_candidate_count=0 then
      v_title:='Captain election extended';
      v_message:='No candidates were available. A new seven-day election round is open with candidate registration enabled.';
    elsif v_max_votes<=0 then
      v_title:='Captain election continues';
      v_message:='No candidate received a vote. The same candidates continue into another seven-day runoff round.';
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
        'runoff_start_game_day',v_runoff_start,
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
        'runoff_start_game_day',v_runoff_start,
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
      'The previous captain is no longer eligible. Candidate registration for a replacement election is now open.',
      '/game/national-team?tab=elections',
      format('national-captain-inactive:%s:%s',t.association_id,v_day),
      jsonb_build_object('player_id',t.player_id,'reason','captain_inactive')
    );

    perform public.open_national_captain_election_v2(
      t.association_id,v_season,'special','captain_inactive',v_day,v_day+20
    );
    v_vacated:=v_vacated+1;
  end loop;

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

  -- Annual election process begins on 1 January with candidate registration.
  if v_day>=v_jan1 then
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
          case when v_day<=v_jan20 then v_jan1 else v_day end,
          case when v_day<=v_jan20 then v_jan20 else v_day+20 end
        );
      end if;
    end loop;
  end if;

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

  -- Three-stage election lifecycle:
  -- candidate_registration -> voting -> runoff (only if needed).
  for e in
    select *
    from public.national_captain_elections
    where status in ('candidate_registration','campaign','voting','runoff')
  loop
    if e.status='candidate_registration' and v_day>e.registration_end_game_day then
      update public.national_captain_elections
      set status='voting',
          voting_start_game_day=coalesce(voting_start_game_day,e.registration_end_game_day+1),
          updated_at=now()
      where id=e.id;

      perform public.notify_national_association_members_v1(
        e.association_id,
        'national.captain.election',
        'National captain voting is open',
        'Candidate registration has closed. Association members can now vote in the main captain election round.',
        '/game/national-team?tab=elections',
        format('national-election-voting:%s:%s',e.id,e.current_round),
        jsonb_build_object(
          'election_id',e.id,
          'phase','voting',
          'voting_start_game_day',coalesce(e.voting_start_game_day,e.registration_end_game_day+1),
          'voting_end_game_day',e.voting_end_game_day
        )
      );

      v_transitioned:=v_transitioned+1;
    elsif e.status='campaign' then
      update public.national_captain_elections
      set status='voting',
          voting_start_game_day=coalesce(voting_start_game_day,v_day),
          updated_at=now()
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

-- Update the page context with explicit phase boundaries.
create or replace function public.get_my_national_association_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player record;
  v_assoc public.national_associations%rowtype;
  v_membership public.national_association_memberships%rowtype;
  v_cfg public.national_team_config%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_season integer:=public.national_team_current_season_v1();
  v_member_count integer;
  v_activation jsonb;
  v_renewal jsonb;
  v_division jsonb;
  v_captain jsonb;
  v_election jsonb;
  v_roster jsonb;
  v_history jsonb;
  v_my_total integer;
  v_election_row public.national_captain_elections%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select p.id,p.world,p.country_code,p.first_name,p.last_name,p.player_type,p.moderation_status
  into v_player
  from public.players p
  where p.owner_user_id=v_uid
  limit 1;

  if not found then
    return jsonb_build_object('available',false,'reason','player_required');
  end if;

  select * into v_assoc
  from public.national_associations a
  where a.country_code=v_player.country_code
    and a.world=v_player.world
  limit 1;

  if not found then
    return jsonb_build_object('available',false,'reason','association_missing');
  end if;

  select * into v_membership
  from public.national_association_memberships m
  where m.player_id=v_player.id
    and m.association_id=v_assoc.id
    and m.status='active'
  order by m.joined_game_day desc,m.created_at desc
  limit 1;

  select * into v_cfg from public.national_team_config where id=1;

  select count(*)::integer into v_member_count
  from public.national_association_memberships
  where association_id=v_assoc.id and status='active';

  select jsonb_build_object(
    'id',f.id,
    'target',f.target_amount,
    'contributed',f.contributed_amount,
    'status',f.status,
    'completed_game_day',f.completed_game_day
  )
  into v_activation
  from public.national_association_funds f
  where f.association_id=v_assoc.id
    and f.fund_type='activation'
  limit 1;

  select jsonb_build_object(
    'id',f.id,
    'season_number',f.season_number,
    'target',f.target_amount,
    'contributed',f.contributed_amount,
    'status',f.status,
    'opens_game_day',f.opens_game_day,
    'deadline_game_day',f.deadline_game_day,
    'deadline_date',(
      select jsonb_build_object('season',g.season,'month',g.month,'day',g.day)
      from public.absolute_game_day_v1(f.deadline_game_day) g
    )
  )
  into v_renewal
  from public.national_association_funds f
  where f.association_id=v_assoc.id
    and f.fund_type='season_renewal'
  order by f.season_number desc,f.created_at desc
  limit 1;

  select jsonb_build_object(
    'entry_id',e.id,
    'division_id',d.id,
    'division_code',d.division_code,
    'label',d.label,
    'tier_level',d.tier_level,
    'region_code',d.region_code,
    'entry_reason',e.entry_reason,
    'status',e.status,
    'final_position',e.final_position
  )
  into v_division
  from public.national_team_division_entries e
  join public.national_team_divisions d on d.id=e.division_id
  where e.association_id=v_assoc.id
    and e.season_number=v_season
  order by e.created_at desc
  limit 1;

  select jsonb_build_object(
    'term_id',t.id,
    'season_number',t.season_number,
    'player_id',p.id,
    'first_name',p.first_name,
    'last_name',p.last_name,
    'status',t.status,
    'term_kind',t.term_kind,
    'is_me',t.user_id=v_uid,
    'term_start_game_day',t.term_start_game_day,
    'term_end_game_day',t.term_end_game_day
  )
  into v_captain
  from public.national_captain_terms t
  join public.players p on p.id=t.player_id
  where t.association_id=v_assoc.id
    and t.status='active'
  order by t.term_start_game_day desc,t.created_at desc
  limit 1;

  select *
  into v_election_row
  from public.national_captain_elections e
  where e.association_id=v_assoc.id
    and (
      e.status in ('candidate_registration','campaign','voting','runoff')
      or e.season_number=v_season
    )
  order by
    case when e.status in ('candidate_registration','campaign','voting','runoff') then 0 else 1 end,
    e.created_at desc
  limit 1;

  if v_election_row.id is not null then
    select jsonb_build_object(
      'id',v_election_row.id,
      'season_number',v_election_row.season_number,
      'status',v_election_row.status,
      'current_round',v_election_row.current_round,
      'election_kind',v_election_row.election_kind,
      'reason',v_election_row.reason,
      'runoff_registration_open',v_election_row.runoff_registration_open,
      'registration_start_game_day',v_election_row.registration_start_game_day,
      'registration_end_game_day',v_election_row.registration_end_game_day,
      'voting_start_game_day',v_election_row.voting_start_game_day,
      'voting_end_game_day',v_election_row.voting_end_game_day,
      'runoff_start_game_day',v_election_row.runoff_start_game_day,
      'runoff_end_game_day',v_election_row.runoff_end_game_day,
      'winning_candidate_id',v_election_row.winning_candidate_id,
      'my_candidate_id',(
        select c.id
        from public.national_captain_candidates c
        where c.election_id=v_election_row.id and c.user_id=v_uid
        limit 1
      ),
      'my_vote_candidate_id',(
        select vote.candidate_id
        from public.national_captain_votes vote
        where vote.election_id=v_election_row.id
          and vote.round_number=v_election_row.current_round
          and vote.voter_user_id=v_uid
        limit 1
      ),
      'candidates',coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'candidate_id',c.id,
            'player_id',p.id,
            'first_name',p.first_name,
            'last_name',p.last_name,
            'manifesto',c.manifesto,
            'in_current_runoff',case
              when v_election_row.status<>'runoff' then true
              else exists(
                select 1
                from public.national_captain_runoff_candidates rc
                where rc.election_id=v_election_row.id
                  and rc.round_number=v_election_row.current_round
                  and rc.candidate_id=c.id
              )
            end,
            'vote_total',case
              when v_election_row.status='completed' then (
                select count(*)::integer
                from public.national_captain_votes vote
                where vote.election_id=v_election_row.id
                  and vote.round_number=v_election_row.current_round
                  and vote.candidate_id=c.id
              )
              else null
            end
          )
          order by p.last_name,p.first_name
        )
        from public.national_captain_candidates c
        join public.players p on p.id=c.player_id
        where c.election_id=v_election_row.id
          and c.status='active'
      ),'[]'::jsonb)
    )
    into v_election;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'membership_id',m.id,
      'player_id',p.id,
      'first_name',p.first_name,
      'last_name',p.last_name,
      'captain_eligible',m.captain_eligible,
      'joined_game_day',m.joined_game_day,
      'national_appearances',(
        select count(distinct na.fixture_id)::integer
        from public.national_team_player_appearances na
        where na.player_id=p.id
      )
    )
    order by p.last_name,p.first_name
  ),'[]'::jsonb)
  into v_roster
  from public.national_association_memberships m
  join public.players p on p.id=m.player_id
  where m.association_id=v_assoc.id
    and m.status='active';

  select coalesce(jsonb_agg(x.item order by x.game_day desc),'[]'::jsonb)
  into v_history
  from (
    select
      event.game_day,
      jsonb_build_object(
        'id',event.id,
        'season_number',event.season_number,
        'game_day',event.game_day,
        'event_type',event.event_type,
        'details',event.details
      ) item
    from public.national_association_events event
    where event.association_id=v_assoc.id
    order by event.game_day desc,event.created_at desc
    limit 20
  ) x;

  select coalesce(sum(c.amount),0)::integer into v_my_total
  from public.national_association_contributions c
  where c.association_id=v_assoc.id
    and c.user_id=v_uid;

  return jsonb_build_object(
    'available',true,
    'game_day',v_day,
    'season_number',v_season,
    'association',jsonb_build_object(
      'id',v_assoc.id,
      'name',v_assoc.name,
      'country_code',v_assoc.country_code,
      'world',v_assoc.world,
      'region_code',v_assoc.region_code,
      'status',v_assoc.status,
      'activated_game_day',v_assoc.activated_game_day,
      'activated_season',v_assoc.activated_season,
      'member_count',v_member_count,
      'minimum_activation_members',v_cfg.activation_min_members,
      'is_member',v_membership.id is not null,
      'can_join',
        v_membership.id is null
        and v_player.player_type='human'
        and v_player.moderation_status<>'rejected',
      'captain_eligible',coalesce(v_membership.captain_eligible,false)
    ),
    'activation_fund',coalesce(v_activation,'{}'::jsonb),
    'renewal_fund',coalesce(v_renewal,'{}'::jsonb),
    'division',coalesce(v_division,'{}'::jsonb),
    'captain',coalesce(v_captain,'{}'::jsonb),
    'election',coalesce(v_election,'{}'::jsonb),
    'roster',v_roster,
    'history',v_history,
    'my_total_contributions',v_my_total,
    'rules',jsonb_build_object(
      'activation_cost',v_cfg.activation_cost,
      'activation_min_members',v_cfg.activation_min_members,
      'renewal_cost',v_cfg.renewal_cost,
      'runoff_days',7,
      'renewal_opens_game_day',public.game_day_absolute_v1(v_season,1,1),
      'renewal_deadline_game_day',public.game_day_absolute_v1(v_season,1,31),
      'annual_candidate_registration_start_game_day',public.game_day_absolute_v1(v_season,1,1),
      'annual_voting_start_game_day',public.game_day_absolute_v1(v_season,1,10),
      'annual_voting_end_game_day',public.game_day_absolute_v1(v_season,1,20)
    )
  );
end;
$$;

-- Re-shape the currently open Serbia activation election to the new three-stage schedule.
update public.national_captain_elections
set registration_end_game_day = registration_start_game_day + 9,
    campaign_end_game_day = registration_start_game_day + 9,
    voting_start_game_day = registration_start_game_day + 10,
    voting_end_game_day = registration_start_game_day + 20,
    runoff_start_game_day = null,
    runoff_end_game_day = null,
    status = case
      when public.national_team_current_abs_day_v1() <= registration_start_game_day + 9 then 'candidate_registration'
      when public.national_team_current_abs_day_v1() <= registration_start_game_day + 20 then 'voting'
      else status
    end,
    updated_at=now()
where id='9f3357da-dcf2-42c0-967d-1516d8cd4820'
  and election_kind='activation'
  and status in ('candidate_registration','campaign','voting');

revoke all on function public.open_national_captain_election_v2(uuid,integer,text,text,integer,integer)
  from public,anon,authenticated;
revoke all on function public.ensure_national_captain_election_v1(uuid,integer)
  from public,anon,authenticated;
revoke all on function public.resolve_national_captain_election_v1(uuid)
  from public,anon,authenticated;
revoke all on function public.process_national_association_lifecycle_v1()
  from public,anon,authenticated;
revoke all on function public.get_my_national_association_v1()
  from public,anon,authenticated;
grant execute on function public.get_my_national_association_v1() to authenticated;
