CREATE OR REPLACE FUNCTION public.ensure_national_captain_election_v1(p_association_id uuid, p_season_number integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_day integer:=public.national_team_current_abs_day_v1();
  v_current_season integer:=public.national_team_current_season_v1();
  v_assoc public.national_associations%rowtype;
  v_existing uuid;
  v_jan10 integer;
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

  -- First activation always gets an immediate 10-day election.
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
      v_day+10
    );
  end if;

  v_jan10:=public.game_day_absolute_v1(v_current_season,1,10);
  v_jan20:=public.game_day_absolute_v1(v_current_season,1,20);

  if v_day>=v_jan10
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
      case when v_day<=v_jan20 then v_jan10 else v_day end,
      case when v_day<=v_jan20 then v_jan20 else v_day+10 end
    );
  end if;

  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.resign_national_captain_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    v_day+10
  );

  return jsonb_build_object(
    'status','resigned',
    'association_id',v_term.association_id,
    'election_id',v_election
  );
end;
$function$;

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
      t.association_id,v_season,'special','captain_inactive',v_day,v_day+10
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
          case when v_day<=v_jan20 then v_jan20 else v_day+10 end
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
$function$;