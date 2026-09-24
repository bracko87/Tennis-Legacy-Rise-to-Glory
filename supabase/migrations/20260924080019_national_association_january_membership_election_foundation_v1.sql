
-- National Association January lifecycle, explicit membership opt-in and resilient captain elections.

alter table public.national_captain_elections
  add column if not exists election_kind text not null default 'annual',
  add column if not exists reason text,
  add column if not exists runoff_registration_open boolean not null default false;

alter table public.national_captain_elections
  drop constraint if exists national_captain_elections_association_id_season_number_key;

alter table public.national_captain_elections
  drop constraint if exists national_captain_elections_election_kind_check;

alter table public.national_captain_elections
  add constraint national_captain_elections_election_kind_check
  check (election_kind in ('annual','activation','special'));

create unique index if not exists national_captain_elections_annual_uq
  on public.national_captain_elections(association_id,season_number)
  where election_kind='annual';

create index if not exists national_captain_elections_assoc_open_idx
  on public.national_captain_elections(association_id,season_number,status,created_at desc);

alter table public.national_captain_terms
  add column if not exists term_kind text not null default 'elected';

alter table public.national_captain_terms
  drop constraint if exists national_captain_terms_association_id_season_number_key;

alter table public.national_captain_terms
  drop constraint if exists national_captain_terms_term_kind_check;

alter table public.national_captain_terms
  add constraint national_captain_terms_term_kind_check
  check (term_kind in ('elected','carryover'));

create unique index if not exists national_captain_terms_one_active_assoc_uq
  on public.national_captain_terms(association_id)
  where status='active';

update public.national_team_config
set renewal_open_day_of_season=0,
    renewal_deadline_day_of_season=30,
    candidate_registration_days=3,
    campaign_days=1,
    voting_days=10,
    runoff_days=7,
    updated_at=now()
where id=1;

insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,
  title_template,message_template,default_route,severity,
  default_in_app,default_email,default_push,is_user_configurable,is_active
) values
(
  'national.association.renewal',
  'national_team',
  'National association renewal',
  'Inform association members that the annual 30-coin renewal is open and must be completed in January.',
  'Annual national association renewal opens.',
  'An activated association reaches 1 January of a new season and its renewal fund is created.',
  'daily_game_engine',
  'public.process_national_association_lifecycle_v1',
  'National association renewal is open',
  'The association must complete its January renewal before 1 February.',
  '/game/national-team?tab=overview',
  'warning',
  true,false,false,true,true
),
(
  'national.captain.election',
  'national_team',
  'National captain election',
  'Invite every association member to participate when a captain election opens.',
  'A national captain election opens.',
  'An annual, activation or special captain election is created.',
  'daily_game_engine',
  'public.open_national_captain_election_v2',
  'National captain election is open',
  'Register, read manifestos and vote for the association captain.',
  '/game/national-team?tab=elections',
  'info',
  true,false,false,true,true
),
(
  'national.captain.runoff',
  'national_team',
  'National captain runoff',
  'Inform members when no candidate has a unique lead and another seven-day round is required.',
  'A captain election round ends without a unique winner.',
  'A tie, zero-vote round or empty election requires another seven-day round.',
  'daily_game_engine',
  'public.resolve_national_captain_election_v1',
  'Captain election continues',
  'No candidate has a unique winning lead. Another seven-day election round is open.',
  '/game/national-team?tab=elections',
  'warning',
  true,false,false,true,true
),
(
  'national.captain.vacancy',
  'national_team',
  'National captain vacancy',
  'Inform association members when the captain resigns or becomes unavailable and a replacement election is required.',
  'Captain seat becomes vacant.',
  'The active captain resigns or no longer has an eligible active association membership.',
  'system_event',
  'public.process_national_association_lifecycle_v1',
  'National captain position is vacant',
  'A replacement captain election is being opened.',
  '/game/national-team?tab=elections',
  'warning',
  true,false,false,true,true
),
(
  'national.captain.elected',
  'national_team',
  'National captain elected',
  'Inform association members when a captain election produces a unique winner.',
  'Captain election completes.',
  'One candidate finishes a round with strictly more votes than every other candidate and at least one vote.',
  'daily_game_engine',
  'public.resolve_national_captain_election_v1',
  'National captain elected',
  'The association has elected its captain.',
  '/game/national-team?tab=elections',
  'success',
  true,false,false,true,true
)
on conflict(code) do update set
  category=excluded.category,
  label=excluded.label,
  reason=excluded.reason,
  trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,
  trigger_mechanism=excluded.trigger_mechanism,
  source_name=excluded.source_name,
  title_template=excluded.title_template,
  message_template=excluded.message_template,
  default_route=excluded.default_route,
  severity=excluded.severity,
  default_in_app=excluded.default_in_app,
  default_email=excluded.default_email,
  default_push=excluded.default_push,
  is_user_configurable=excluded.is_user_configurable,
  is_active=excluded.is_active,
  updated_at=now();

create or replace function public.notify_national_association_members_v1(
  p_association_id uuid,
  p_notification_code text,
  p_title text,
  p_message text,
  p_route text,
  p_event_key_prefix text,
  p_payload jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  m record;
  v_count integer:=0;
begin
  for m in
    select distinct on (membership.user_id)
      membership.user_id,
      membership.player_id
    from public.national_association_memberships membership
    where membership.association_id=p_association_id
      and membership.status='active'
      and membership.user_id is not null
    order by membership.user_id,membership.joined_game_day desc,membership.created_at desc
  loop
    perform public.emit_notification_v1(
      m.user_id,
      m.player_id,
      p_notification_code,
      p_title,
      p_message,
      p_route,
      coalesce(p_payload,'{}'::jsonb) || jsonb_build_object('association_id',p_association_id),
      p_event_key_prefix
    );
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

revoke all on function public.notify_national_association_members_v1(uuid,text,text,text,text,text,jsonb)
  from public,anon,authenticated;

-- Membership synchronization now maintains eligibility but does NOT auto-enrol a new player.
create or replace function public.sync_national_association_membership_for_player_v1(
  p_player_id uuid
)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_player record;
  v_target uuid;
  v_existing record;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_eligible boolean;
begin
  select p.id,p.owner_user_id,p.world,p.country_code,p.player_type,p.moderation_status
  into v_player
  from public.players p
  where p.id=p_player_id;

  if not found then return; end if;

  v_eligible :=
    v_player.owner_user_id is not null
    and v_player.player_type='human'
    and v_player.world in ('ATP','WTA')
    and v_player.moderation_status<>'rejected';

  select *
  into v_existing
  from public.national_association_memberships
  where player_id=p_player_id and status='active'
  order by created_at desc
  limit 1;

  if not v_eligible then
    if v_existing.id is not null then
      update public.national_association_memberships
      set status='inactive',left_game_day=v_day,left_at=now()
      where id=v_existing.id;
    end if;
    return;
  end if;

  select a.id into v_target
  from public.national_associations a
  where a.country_code=v_player.country_code
    and a.world=v_player.world
  limit 1;

  if v_existing.id is null then
    -- Explicit opt-in: eligible players choose Join Association in the UI.
    return;
  end if;

  if v_existing.association_id<>v_target then
    update public.national_association_memberships
    set status='inactive',left_game_day=v_day,left_at=now()
    where id=v_existing.id;
    return;
  end if;

  if v_existing.user_id is distinct from v_player.owner_user_id then
    update public.national_association_memberships
    set user_id=v_player.owner_user_id
    where id=v_existing.id;
  end if;
end;
$$;

revoke all on function public.sync_national_association_membership_for_player_v1(uuid)
  from public,anon,authenticated;

create or replace function public.join_my_national_association_v1()
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_assoc public.national_associations%rowtype;
  v_membership uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_season integer:=public.national_team_current_season_v1();
  v_election record;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid
  limit 1;

  if not found
     or v_player.player_type<>'human'
     or v_player.world not in ('ATP','WTA')
     or v_player.moderation_status='rejected' then
    raise exception 'Your player is not eligible to join a national association.';
  end if;

  select * into v_assoc
  from public.national_associations
  where country_code=v_player.country_code
    and world=v_player.world
  limit 1;

  if not found then raise exception 'National association not found.'; end if;

  select id into v_membership
  from public.national_association_memberships
  where association_id=v_assoc.id
    and player_id=v_player.id
    and status='active'
  limit 1;

  if v_membership is null then
    insert into public.national_association_memberships(
      association_id,player_id,user_id,status,captain_eligible,joined_game_day
    )
    values(v_assoc.id,v_player.id,v_uid,'active',true,v_day)
    returning id into v_membership;

    perform public.national_team_record_event_v1(
      v_assoc.id,
      'association_member_joined',
      jsonb_build_object('player_id',v_player.id),
      v_season
    );
  end if;

  perform public.maybe_activate_national_association_v1(v_assoc.id);

  -- If the fifth member completes an already-funded activation, immediately open the first captain election.
  if exists(
    select 1
    from public.national_associations a
    where a.id=v_assoc.id
      and a.status='active'
      and a.activated_season=v_season
  ) then
    perform public.ensure_national_captain_election_v1(v_assoc.id,v_season);
  end if;

  select e.id,e.status,e.current_round
  into v_election
  from public.national_captain_elections e
  where e.association_id=v_assoc.id
    and e.status in ('candidate_registration','campaign','voting','runoff')
  order by e.created_at desc
  limit 1;

  if v_election.id is not null then
    perform public.emit_notification_v1(
      v_uid,
      v_player.id,
      'national.captain.election',
      'National captain election is in progress',
      'You joined the association while a captain election is active. You can participate immediately.',
      '/game/national-team?tab=elections',
      jsonb_build_object('association_id',v_assoc.id,'election_id',v_election.id),
      format('national-election-join:%s:%s:%s',v_assoc.id,v_election.id,v_uid)
    );
  end if;

  return jsonb_build_object(
    'status','joined',
    'association_id',v_assoc.id,
    'association_name',v_assoc.name,
    'membership_id',v_membership,
    'eligible_for_callups',true,
    'eligible_for_captain_elections',true
  );
end;
$$;

revoke all on function public.join_my_national_association_v1() from public,anon,authenticated;
grant execute on function public.join_my_national_association_v1() to authenticated;

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
  v_campaign_end integer;
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

  v_reg_end:=least(p_first_round_end_game_day,p_start_game_day+2);
  v_campaign_end:=least(p_first_round_end_game_day,p_start_game_day+3);

  insert into public.national_captain_elections(
    association_id,season_number,status,
    registration_start_game_day,registration_end_game_day,
    campaign_end_game_day,voting_end_game_day,
    runoff_end_game_day,current_round,winning_candidate_id,completed_game_day,
    election_kind,reason,runoff_registration_open
  )
  values(
    p_association_id,p_season_number,'candidate_registration',
    p_start_game_day,v_reg_end,v_campaign_end,p_first_round_end_game_day,
    null,1,null,null,p_election_kind,p_reason,false
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
      'first_round_end_game_day',p_first_round_end_game_day
    ),
    p_season_number
  );

  if p_reason='captain_resigned' then
    v_title:='Captain resigned — election opened';
    v_message:='The captain has resigned. A replacement election is now open for association members.';
  elsif p_reason='captain_inactive' then
    v_title:='Captain unavailable — election opened';
    v_message:='The previous captain is no longer eligible. A replacement election is now open.';
  elsif p_election_kind='annual' then
    v_title:='Annual captain election is open';
    v_message:='The annual national captain election has started. The first round runs from 10 January through 20 January.';
  else
    v_title:='First national captain election is open';
    v_message:='The association is active. Members can now register candidates and elect the first captain.';
  end if;

  perform public.notify_national_association_members_v1(
    p_association_id,
    'national.captain.election',
    v_title,
    v_message,
    '/game/national-team?tab=elections',
    format('national-election-open:%s:%s',p_association_id,v_id),
    jsonb_build_object('election_id',v_id,'election_kind',p_election_kind,'reason',p_reason)
  );

  return v_id;
end;
$$;

revoke all on function public.open_national_captain_election_v2(uuid,integer,text,text,integer,integer)
  from public,anon,authenticated;

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
      v_day+9
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
      case when v_day<=v_jan20 then v_jan20 else v_day+9 end
    );
  end if;

  return null;
end;
$$;

revoke all on function public.ensure_national_captain_election_v1(uuid,integer)
  from public,anon,authenticated;

create or replace function public.carry_forward_national_captain_v1(
  p_association_id uuid,
  p_season_number integer
)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_previous public.national_captain_terms%rowtype;
  v_id uuid;
  v_start integer:=public.game_day_absolute_v1(p_season_number,1,1);
  v_end integer:=public.game_day_absolute_v1(p_season_number,12,31);
begin
  if exists(
    select 1 from public.national_captain_terms
    where association_id=p_association_id
      and season_number=p_season_number
  ) then return null; end if;

  select t.*
  into v_previous
  from public.national_captain_terms t
  join public.national_association_memberships m
    on m.id=t.membership_id
   and m.status='active'
  join public.players p
    on p.id=t.player_id
   and p.owner_user_id=t.user_id
   and p.player_type='human'
   and p.moderation_status<>'rejected'
  where t.association_id=p_association_id
    and t.season_number<p_season_number
    and t.status in ('active','completed')
  order by t.season_number desc,t.term_start_game_day desc,t.created_at desc
  limit 1;

  if v_previous.id is null then return null; end if;

  insert into public.national_captain_terms(
    association_id,election_id,candidate_id,membership_id,user_id,player_id,
    season_number,term_start_game_day,term_end_game_day,status,term_kind
  )
  values(
    p_association_id,v_previous.election_id,v_previous.candidate_id,
    v_previous.membership_id,v_previous.user_id,v_previous.player_id,
    p_season_number,v_start,v_end,'active','carryover'
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.carry_forward_national_captain_v1(uuid,integer)
  from public,anon,authenticated;
