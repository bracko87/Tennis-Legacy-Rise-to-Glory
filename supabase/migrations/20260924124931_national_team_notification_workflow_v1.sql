CREATE OR REPLACE FUNCTION public.process_national_association_lifecycle_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  v_deadline_label text;
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

      select format('Season %s · %s %s',g.season,g.day,
                    (array['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'])[g.month])
      into v_deadline_label
      from public.absolute_game_day_v1(e.voting_end_game_day) g;

      perform public.notify_national_association_members_v1(
        e.association_id,
        'national.captain.election',
        'National captain election — voting is open',
        format(
          'Voting is open until %s. As an active association member, you may cast exactly one final vote in this round for any registered candidate.',
          coalesce(v_deadline_label,'the election deadline')
        ),
        '/game/national-team?tab=elections',
        format('national-election-voting:%s:%s',e.id,e.current_round),
        jsonb_build_object(
          'election_id',e.id,
          'phase','voting',
          'round',e.current_round,
          'voting_start_game_day',coalesce(e.voting_start_game_day,e.registration_end_game_day+1),
          'voting_end_game_day',e.voting_end_game_day,
          'voting_deadline_label',v_deadline_label,
          'one_vote_per_round',true,
          'vote_is_final',true,
          'notification_category','national_team',
          'notification_label','Captain election',
          'action_url','/game/national-team?tab=elections'
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
$function$;

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
  v_captain_name text;
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

  select trim(concat_ws(' ',p.first_name,p.last_name))
  into v_captain_name
  from public.players p
  where p.id=v_candidate.player_id;

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
    format('%s is the new national captain',coalesce(v_captain_name,'New captain')),
    format(
      '%s has won the national captain election and is now in office for the association.',
      coalesce(v_captain_name,'The winning candidate')
    ),
    '/game/national-team?tab=elections',
    format('national-election-winner:%s',v_e.id),
    jsonb_build_object(
      'election_id',v_e.id,
      'candidate_id',v_candidate.id,
      'player_id',v_candidate.player_id,
      'captain_name',v_captain_name,
      'related_player_id',v_candidate.player_id::text,
      'notification_category','national_team',
      'notification_label','New national captain',
      'action_url','/game/national-team?tab=elections'
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.send_national_team_callup_v1(p_fixture_id uuid, p_player_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  p public.players%rowtype;
  a public.national_associations%rowtype;
  v_callup uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_opponent_name text;
  v_captain_name text;
  v_owner uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found.'; end if;
  if f.status not in ('announced','lineups_pending') then raise exception 'Call-ups are not open for this fixture.'; end if;
  if v_day>f.response_deadline_absolute_day then raise exception 'The call-up response deadline has passed.'; end if;

  v_assoc:=public.national_fixture_association_for_captain_v1(p_fixture_id,v_uid);
  if v_assoc is null then raise exception 'Only the elected captain may send call-ups.'; end if;

  select * into w from public.national_team_windows where id=f.window_id;
  select * into p from public.players where id=p_player_id;
  select * into a from public.national_associations where id=v_assoc;

  if p.id is null then raise exception 'Player not found.'; end if;
  if p.world<>a.world or p.country_code<>a.country_code then
    raise exception 'Player is not eligible for this national association.';
  end if;
  if not exists(
    select 1 from public.national_association_memberships m
    where m.association_id=v_assoc and m.player_id=p_player_id and m.status='active'
  ) then
    raise exception 'Player is not an active member of this national association.';
  end if;

  insert into public.national_team_callups(
    fixture_id,association_id,player_id,invited_by_user_id,status,
    response_deadline_absolute_day,expected_compensation_usd,invited_game_day
  )
  values(
    f.id,v_assoc,p_player_id,v_uid,'pending',
    f.response_deadline_absolute_day,f.expected_appearance_fee_usd,v_day
  )
  on conflict(fixture_id,player_id) do update
  set association_id=excluded.association_id,
      invited_by_user_id=excluded.invited_by_user_id,
      status=case when public.national_team_callups.status in ('declined','withdrawn','expired')
                  then 'pending' else public.national_team_callups.status end,
      response_deadline_absolute_day=excluded.response_deadline_absolute_day,
      expected_compensation_usd=excluded.expected_compensation_usd,
      invited_game_day=case when public.national_team_callups.status in ('declined','withdrawn','expired')
                            then excluded.invited_game_day else public.national_team_callups.invited_game_day end,
      updated_at=now()
  returning id into v_callup;

  select owner_user_id into v_owner from public.players where id=p_player_id;
  select trim(concat_ws(' ',cp.first_name,cp.last_name))
  into v_captain_name
  from public.players cp
  where cp.owner_user_id=v_uid
  limit 1;

  select name into v_opponent_name
  from public.national_associations
  where id=case when v_assoc=f.home_association_id then f.away_association_id else f.home_association_id end;

  if v_owner is not null then
    perform public.emit_notification_v1(
      v_owner,
      p_player_id,
      'national_team.callup',
      'National-team call-up — response required',
      format(
        '%s%s has selected you for the national-team tie against %s in %s. Open the Competition tab and accept or decline before the response deadline.',
        case when v_captain_name is not null then 'Captain '||v_captain_name||' of ' else '' end,
        a.name,v_opponent_name,f.host_city
      ),
      '/game/national-team?tab=competition',
      jsonb_build_object(
        'fixture_id',f.id,
        'association_id',a.id,
        'association_name',a.name,
        'captain_name',v_captain_name,
        'opponent_name',v_opponent_name,
        'host_city',f.host_city,
        'host_country_code',f.host_country_code,
        'window_start_absolute_day',w.start_absolute_day,
        'window_end_absolute_day',w.end_absolute_day,
        'response_deadline_absolute_day',f.response_deadline_absolute_day,
        'expected_compensation_usd',f.expected_appearance_fee_usd,
        'notification_category','national_team',
        'notification_label','National-team call-up',
        'action_url','/game/national-team?tab=competition'
      ),
      format('national-callup:%s:%s',f.id,p_player_id)
    );
  end if;

  return v_callup;
end;
$function$;