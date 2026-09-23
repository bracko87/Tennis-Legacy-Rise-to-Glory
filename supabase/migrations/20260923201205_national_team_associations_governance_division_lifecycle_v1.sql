
create table if not exists public.national_team_config (
  id smallint primary key default 1 check (id = 1),
  activation_cost integer not null default 50 check (activation_cost > 0),
  activation_min_members integer not null default 5 check (activation_min_members > 0),
  renewal_cost integer not null default 30 check (renewal_cost > 0),
  renewal_open_day_of_season integer not null default 300 check (renewal_open_day_of_season between 0 and 365),
  renewal_deadline_day_of_season integer not null default 350 check (renewal_deadline_day_of_season between 0 and 365),
  candidate_registration_days integer not null default 3 check (candidate_registration_days > 0),
  campaign_days integer not null default 3 check (campaign_days > 0),
  voting_days integer not null default 7 check (voting_days between 7 and 10),
  runoff_days integer not null default 3 check (runoff_days > 0),
  updated_at timestamptz not null default now()
);

insert into public.national_team_config (id)
values (1)
on conflict (id) do nothing;

create table if not exists public.national_team_regions (
  code text primary key,
  label text not null,
  sort_order integer not null default 100
);

insert into public.national_team_regions (code, label, sort_order) values
  ('GLOBAL', 'Global', 100)
on conflict (code) do update set label = excluded.label, sort_order = excluded.sort_order;

create table if not exists public.national_team_country_regions (
  country_code text primary key references public.countries(code) on delete cascade,
  region_code text not null references public.national_team_regions(code) on delete restrict default 'GLOBAL'
);

insert into public.national_team_country_regions (country_code, region_code)
select c.code, 'GLOBAL'
from public.countries c
where c.is_active
on conflict (country_code) do nothing;

create table if not exists public.national_associations (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.countries(code) on delete restrict,
  world text not null check (world in ('ATP', 'WTA')),
  name text not null,
  region_code text not null references public.national_team_regions(code) on delete restrict default 'GLOBAL',
  status text not null default 'inactive'
    check (status in ('inactive', 'activation_funding', 'active', 'renewal_required', 'suspended')),
  activation_started_by_user_id uuid references auth.users(id) on delete set null,
  activated_game_day integer,
  activated_season integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (country_code, world)
);

create index if not exists national_associations_world_status_idx
  on public.national_associations(world, status, country_code);

create table if not exists public.national_association_memberships (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  captain_eligible boolean not null default true,
  joined_game_day integer not null,
  left_game_day integer,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists national_membership_one_active_player_idx
  on public.national_association_memberships(player_id)
  where status = 'active';

create index if not exists national_membership_association_active_idx
  on public.national_association_memberships(association_id, status, joined_game_day);

create table if not exists public.national_association_funds (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  fund_type text not null check (fund_type in ('activation', 'season_renewal')),
  season_number integer,
  target_amount integer not null check (target_amount > 0),
  contributed_amount integer not null default 0 check (contributed_amount >= 0),
  status text not null default 'open' check (status in ('open', 'completed', 'expired')),
  opens_game_day integer not null,
  deadline_game_day integer,
  completed_game_day integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (fund_type = 'activation' and season_number is null)
    or (fund_type = 'season_renewal' and season_number is not null)
  ),
  check (contributed_amount <= target_amount)
);

create unique index if not exists national_association_activation_fund_uq
  on public.national_association_funds(association_id)
  where fund_type = 'activation';

create unique index if not exists national_association_renewal_fund_uq
  on public.national_association_funds(association_id, season_number)
  where fund_type = 'season_renewal';

create index if not exists national_association_funds_open_idx
  on public.national_association_funds(status, fund_type, season_number, deadline_game_day);

create table if not exists public.national_association_contributions (
  id uuid primary key default gen_random_uuid(),
  fund_id uuid not null references public.national_association_funds(id) on delete restrict,
  association_id uuid not null references public.national_associations(id) on delete restrict,
  membership_id uuid not null references public.national_association_memberships(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  amount integer not null check (amount > 0),
  game_day integer not null,
  created_at timestamptz not null default now()
);

create index if not exists national_association_contributions_fund_idx
  on public.national_association_contributions(fund_id, created_at);

create index if not exists national_association_contributions_user_idx
  on public.national_association_contributions(user_id, created_at desc);

create table if not exists public.national_association_treasuries (
  association_id uuid primary key references public.national_associations(id) on delete cascade,
  coins_balance bigint not null default 0 check (coins_balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.national_association_recognitions (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid references public.players(id) on delete set null,
  recognition_code text not null check (recognition_code in ('founding_member')),
  granted_game_day integer not null,
  created_at timestamptz not null default now(),
  unique (association_id, user_id, recognition_code)
);

create table if not exists public.national_association_events (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  season_number integer,
  game_day integer not null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists national_association_events_history_idx
  on public.national_association_events(association_id, game_day desc, created_at desc);

create table if not exists public.national_team_divisions (
  id uuid primary key default gen_random_uuid(),
  world text not null check (world in ('ATP', 'WTA')),
  region_code text not null references public.national_team_regions(code) on delete restrict,
  division_code text not null,
  label text not null,
  tier_level integer not null check (tier_level > 0),
  capacity integer not null check (capacity > 0),
  sort_order integer not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (world, region_code, division_code)
);

create index if not exists national_team_divisions_tier_idx
  on public.national_team_divisions(world, region_code, tier_level, is_active, sort_order);

create table if not exists public.national_team_division_entries (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  division_id uuid not null references public.national_team_divisions(id) on delete restrict,
  season_number integer not null check (season_number > 0),
  status text not null default 'active' check (status in ('active', 'withdrawn', 'completed')),
  entry_reason text not null
    check (entry_reason in ('retained', 'promoted', 'relegated', 'cascade_promoted', 'new_association', 'reactivated')),
  sporting_outcome text check (sporting_outcome in ('retained', 'promoted', 'relegated')),
  final_position integer check (final_position is null or final_position > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (association_id, season_number)
);

create index if not exists national_team_division_entries_division_idx
  on public.national_team_division_entries(division_id, season_number, status, final_position);

create table if not exists public.national_captain_elections (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  season_number integer not null check (season_number > 0),
  status text not null default 'candidate_registration'
    check (status in ('candidate_registration', 'campaign', 'voting', 'runoff', 'completed', 'cancelled')),
  registration_start_game_day integer not null,
  registration_end_game_day integer not null,
  campaign_end_game_day integer not null,
  voting_end_game_day integer not null,
  runoff_end_game_day integer,
  current_round integer not null default 1 check (current_round > 0),
  winning_candidate_id uuid,
  completed_game_day integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (association_id, season_number)
);

create index if not exists national_captain_elections_stage_idx
  on public.national_captain_elections(status, registration_end_game_day, campaign_end_game_day, voting_end_game_day, runoff_end_game_day);

create table if not exists public.national_captain_candidates (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.national_captain_elections(id) on delete cascade,
  membership_id uuid not null references public.national_association_memberships(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  player_id uuid not null references public.players(id) on delete restrict,
  manifesto text not null check (char_length(manifesto) between 10 and 1000),
  status text not null default 'active' check (status in ('active', 'withdrawn')),
  registered_at timestamptz not null default now(),
  unique (election_id, user_id)
);

alter table public.national_captain_elections
  drop constraint if exists national_captain_elections_winning_candidate_id_fkey;

alter table public.national_captain_elections
  add constraint national_captain_elections_winning_candidate_id_fkey
  foreign key (winning_candidate_id) references public.national_captain_candidates(id) on delete set null;

create table if not exists public.national_captain_runoff_candidates (
  election_id uuid not null references public.national_captain_elections(id) on delete cascade,
  round_number integer not null check (round_number > 1),
  candidate_id uuid not null references public.national_captain_candidates(id) on delete cascade,
  primary key (election_id, round_number, candidate_id)
);

create table if not exists public.national_captain_votes (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.national_captain_elections(id) on delete cascade,
  round_number integer not null check (round_number > 0),
  membership_id uuid not null references public.national_association_memberships(id) on delete restrict,
  voter_user_id uuid not null references auth.users(id) on delete restrict,
  candidate_id uuid not null references public.national_captain_candidates(id) on delete restrict,
  cast_game_day integer not null,
  created_at timestamptz not null default now(),
  unique (election_id, round_number, membership_id)
);

create index if not exists national_captain_votes_tally_idx
  on public.national_captain_votes(election_id, round_number, candidate_id);

create table if not exists public.national_captain_terms (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  election_id uuid not null references public.national_captain_elections(id) on delete restrict,
  candidate_id uuid not null references public.national_captain_candidates(id) on delete restrict,
  membership_id uuid not null references public.national_association_memberships(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  player_id uuid not null references public.players(id) on delete restrict,
  season_number integer not null check (season_number > 0),
  term_start_game_day integer not null,
  term_end_game_day integer not null,
  status text not null check (status in ('scheduled', 'active', 'completed', 'vacated')),
  created_at timestamptz not null default now(),
  unique (association_id, season_number)
);

create index if not exists national_captain_terms_active_idx
  on public.national_captain_terms(association_id, status, season_number);

alter table public.national_team_config enable row level security;
alter table public.national_team_regions enable row level security;
alter table public.national_team_country_regions enable row level security;
alter table public.national_associations enable row level security;
alter table public.national_association_memberships enable row level security;
alter table public.national_association_funds enable row level security;
alter table public.national_association_contributions enable row level security;
alter table public.national_association_treasuries enable row level security;
alter table public.national_association_recognitions enable row level security;
alter table public.national_association_events enable row level security;
alter table public.national_team_divisions enable row level security;
alter table public.national_team_division_entries enable row level security;
alter table public.national_captain_elections enable row level security;
alter table public.national_captain_candidates enable row level security;
alter table public.national_captain_runoff_candidates enable row level security;
alter table public.national_captain_votes enable row level security;
alter table public.national_captain_terms enable row level security;

drop policy if exists national_associations_authenticated_read on public.national_associations;
create policy national_associations_authenticated_read
on public.national_associations for select to authenticated using (true);

drop policy if exists national_funds_authenticated_read on public.national_association_funds;
create policy national_funds_authenticated_read
on public.national_association_funds for select to authenticated using (true);

drop policy if exists national_divisions_authenticated_read on public.national_team_divisions;
create policy national_divisions_authenticated_read
on public.national_team_divisions for select to authenticated using (true);

drop policy if exists national_division_entries_authenticated_read on public.national_team_division_entries;
create policy national_division_entries_authenticated_read
on public.national_team_division_entries for select to authenticated using (true);

drop policy if exists national_elections_authenticated_read on public.national_captain_elections;
create policy national_elections_authenticated_read
on public.national_captain_elections for select to authenticated using (true);

drop policy if exists national_candidates_authenticated_read on public.national_captain_candidates;
create policy national_candidates_authenticated_read
on public.national_captain_candidates for select to authenticated using (true);

drop policy if exists national_terms_authenticated_read on public.national_captain_terms;
create policy national_terms_authenticated_read
on public.national_captain_terms for select to authenticated using (true);

drop policy if exists national_events_authenticated_read on public.national_association_events;
create policy national_events_authenticated_read
on public.national_association_events for select to authenticated using (true);

grant select on public.national_associations to authenticated;
grant select on public.national_association_funds to authenticated;
grant select on public.national_team_divisions to authenticated;
grant select on public.national_team_division_entries to authenticated;
grant select on public.national_captain_elections to authenticated;
grant select on public.national_captain_candidates to authenticated;
grant select on public.national_captain_terms to authenticated;
grant select on public.national_association_events to authenticated;

create or replace function public.national_team_current_abs_day_v1()
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select floor(game_total_seconds::numeric / 86400)::integer
  from public.get_game_clock_v1()
  limit 1;
$$;

create or replace function public.national_team_current_season_v1()
returns integer
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (public.national_team_current_abs_day_v1() / 366) + 1;
$$;

create or replace function public.national_team_record_event_v1(
  p_association_id uuid,
  p_event_type text,
  p_details jsonb default '{}'::jsonb,
  p_season_number integer default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_day integer := public.national_team_current_abs_day_v1();
  v_season integer := coalesce(p_season_number, (v_day / 366) + 1);
begin
  insert into public.national_association_events(
    association_id, season_number, game_day, event_type, details
  )
  values (
    p_association_id, v_season, v_day, p_event_type, coalesce(p_details, '{}'::jsonb)
  );
end;
$$;

insert into public.national_associations(country_code, world, name, region_code)
select
  c.code,
  w.world,
  c.name || ' Tennis Association',
  coalesce(r.region_code, 'GLOBAL')
from public.countries c
cross join (values ('ATP'::text), ('WTA'::text)) as w(world)
left join public.national_team_country_regions r on r.country_code = c.code
where c.is_active
on conflict (country_code, world) do update
set
  name = excluded.name,
  region_code = excluded.region_code,
  updated_at = now();

insert into public.national_association_treasuries(association_id)
select a.id
from public.national_associations a
on conflict (association_id) do nothing;

insert into public.national_association_funds(
  association_id, fund_type, season_number, target_amount, contributed_amount,
  status, opens_game_day, deadline_game_day
)
select
  a.id,
  'activation',
  null,
  cfg.activation_cost,
  0,
  'open',
  0,
  null
from public.national_associations a
cross join public.national_team_config cfg
where cfg.id = 1
on conflict do nothing;

create or replace function public.maybe_activate_national_association_v1(
  p_association_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_assoc public.national_associations%rowtype;
  v_cfg public.national_team_config%rowtype;
  v_fund public.national_association_funds%rowtype;
  v_members integer;
  v_day integer := public.national_team_current_abs_day_v1();
  v_season integer := (public.national_team_current_abs_day_v1() / 366) + 1;
  v_founder_player uuid;
begin
  select * into v_assoc
  from public.national_associations
  where id = p_association_id
  for update;

  if not found or v_assoc.activated_game_day is not null then
    return false;
  end if;

  select * into v_cfg from public.national_team_config where id = 1;

  select * into v_fund
  from public.national_association_funds
  where association_id = p_association_id and fund_type = 'activation'
  for update;

  select count(*)::integer into v_members
  from public.national_association_memberships
  where association_id = p_association_id and status = 'active';

  if coalesce(v_fund.contributed_amount, 0) < v_cfg.activation_cost
     or v_members < v_cfg.activation_min_members then
    return false;
  end if;

  update public.national_association_funds
  set status = 'completed',
      contributed_amount = target_amount,
      completed_game_day = coalesce(completed_game_day, v_day),
      updated_at = now()
  where id = v_fund.id;

  update public.national_associations
  set status = 'active',
      activated_game_day = v_day,
      activated_season = v_season,
      updated_at = now()
  where id = p_association_id;

  if v_assoc.activation_started_by_user_id is not null then
    select m.player_id into v_founder_player
    from public.national_association_memberships m
    where m.association_id = p_association_id
      and m.user_id = v_assoc.activation_started_by_user_id
      and m.status = 'active'
    order by m.joined_game_day, m.created_at
    limit 1;

    insert into public.national_association_recognitions(
      association_id, user_id, player_id, recognition_code, granted_game_day
    )
    values (
      p_association_id, v_assoc.activation_started_by_user_id, v_founder_player,
      'founding_member', v_day
    )
    on conflict (association_id, user_id, recognition_code) do nothing;
  end if;

  perform public.national_team_record_event_v1(
    p_association_id,
    'association_activated',
    jsonb_build_object(
      'member_count', v_members,
      'activation_cost', v_cfg.activation_cost
    ),
    v_season
  );

  return true;
end;
$$;

create or replace function public.sync_national_association_membership_for_player_v1(
  p_player_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_player record;
  v_target uuid;
  v_existing record;
  v_day integer := public.national_team_current_abs_day_v1();
  v_eligible boolean;
begin
  select
    p.id,
    p.owner_user_id,
    p.world,
    p.country_code,
    p.player_type,
    p.moderation_status
  into v_player
  from public.players p
  where p.id = p_player_id;

  if not found then
    return;
  end if;

  v_eligible :=
    v_player.owner_user_id is not null
    and v_player.player_type = 'human'
    and v_player.world in ('ATP', 'WTA')
    and v_player.moderation_status <> 'rejected';

  select *
  into v_existing
  from public.national_association_memberships
  where player_id = p_player_id and status = 'active'
  order by created_at desc
  limit 1;

  if not v_eligible then
    if v_existing.id is not null then
      update public.national_association_memberships
      set status = 'inactive',
          left_game_day = v_day,
          left_at = now()
      where id = v_existing.id;
    end if;
    return;
  end if;

  select a.id into v_target
  from public.national_associations a
  where a.country_code = v_player.country_code
    and a.world = v_player.world
  limit 1;

  if v_target is null then
    return;
  end if;

  if v_existing.id is not null and v_existing.association_id = v_target then
    if v_existing.user_id is distinct from v_player.owner_user_id then
      update public.national_association_memberships
      set user_id = v_player.owner_user_id
      where id = v_existing.id;
    end if;
    perform public.maybe_activate_national_association_v1(v_target);
    return;
  end if;

  if v_existing.id is not null then
    update public.national_association_memberships
    set status = 'inactive',
        left_game_day = v_day,
        left_at = now()
    where id = v_existing.id;
  end if;

  insert into public.national_association_memberships(
    association_id, player_id, user_id, status, captain_eligible, joined_game_day
  )
  values (
    v_target, p_player_id, v_player.owner_user_id, 'active', true, v_day
  );

  perform public.maybe_activate_national_association_v1(v_target);
end;
$$;

create or replace function public.trg_sync_national_association_membership_v1()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.sync_national_association_membership_for_player_v1(new.id);
  return new;
end;
$$;

drop trigger if exists trg_players_national_association_membership_v1 on public.players;
create trigger trg_players_national_association_membership_v1
after insert or update of owner_user_id, world, country_code, player_type, moderation_status
on public.players
for each row
execute function public.trg_sync_national_association_membership_v1();

do $$
declare
  r record;
begin
  for r in select id from public.players loop
    perform public.sync_national_association_membership_for_player_v1(r.id);
  end loop;
end;
$$;

create or replace function public.assign_national_association_bottom_entry_v1(
  p_association_id uuid,
  p_season_number integer,
  p_entry_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_assoc public.national_associations%rowtype;
  v_division uuid;
  v_entry uuid;
begin
  if p_entry_reason not in ('new_association', 'reactivated') then
    raise exception 'Invalid bottom-entry reason.';
  end if;

  select * into v_assoc
  from public.national_associations
  where id = p_association_id;

  if not found then
    return null;
  end if;

  select d.id into v_division
  from public.national_team_divisions d
  where d.world = v_assoc.world
    and d.region_code = v_assoc.region_code
    and d.is_active
  order by d.tier_level desc, d.sort_order, d.division_code
  limit 1;

  if v_division is null then
    return null;
  end if;

  insert into public.national_team_division_entries(
    association_id, division_id, season_number, status, entry_reason
  )
  values (
    p_association_id, v_division, p_season_number, 'active', p_entry_reason
  )
  on conflict (association_id, season_number) do nothing
  returning id into v_entry;

  if v_entry is not null then
    perform public.national_team_record_event_v1(
      p_association_id,
      case when p_entry_reason = 'reactivated' then 'association_reentered_bottom_tier' else 'association_entered_bottom_tier' end,
      jsonb_build_object('division_id', v_division, 'entry_reason', p_entry_reason),
      p_season_number
    );
  end if;

  return v_entry;
end;
$$;

create or replace function public.ensure_national_captain_election_v1(
  p_association_id uuid,
  p_season_number integer
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_existing uuid;
  v_day integer := public.national_team_current_abs_day_v1();
  v_cfg public.national_team_config%rowtype;
  v_reg_end integer;
  v_campaign_end integer;
  v_vote_end integer;
begin
  select id into v_existing
  from public.national_captain_elections
  where association_id = p_association_id
    and season_number = p_season_number;

  if v_existing is not null then
    return v_existing;
  end if;

  select * into v_cfg from public.national_team_config where id = 1;
  v_reg_end := v_day + v_cfg.candidate_registration_days - 1;
  v_campaign_end := v_reg_end + v_cfg.campaign_days;
  v_vote_end := v_campaign_end + v_cfg.voting_days;

  insert into public.national_captain_elections(
    association_id, season_number, status,
    registration_start_game_day, registration_end_game_day,
    campaign_end_game_day, voting_end_game_day
  )
  values (
    p_association_id, p_season_number, 'candidate_registration',
    v_day, v_reg_end, v_campaign_end, v_vote_end
  )
  returning id into v_existing;

  perform public.national_team_record_event_v1(
    p_association_id,
    'captain_election_opened',
    jsonb_build_object('election_id', v_existing, 'season_number', p_season_number),
    p_season_number
  );

  return v_existing;
end;
$$;

create or replace function public.resolve_national_captain_election_v1(
  p_election_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_e public.national_captain_elections%rowtype;
  v_cfg public.national_team_config%rowtype;
  v_day integer := public.national_team_current_abs_day_v1();
  v_max_votes integer;
  v_top_count integer;
  v_winner uuid;
  v_candidate record;
  v_term_start integer;
  v_term_end integer;
begin
  select * into v_e
  from public.national_captain_elections
  where id = p_election_id
  for update;

  if not found or v_e.status not in ('voting', 'runoff') then
    return;
  end if;

  if v_e.status = 'voting' then
    select max(vote_count) into v_max_votes
    from (
      select c.id, count(v.id)::integer as vote_count
      from public.national_captain_candidates c
      left join public.national_captain_votes v
        on v.candidate_id = c.id
       and v.election_id = v_e.id
       and v.round_number = v_e.current_round
      where c.election_id = v_e.id
        and c.status = 'active'
      group by c.id
    ) x;

    if v_max_votes is null then
      update public.national_captain_elections
      set status = 'completed',
          completed_game_day = v_day,
          updated_at = now()
      where id = v_e.id;
      return;
    end if;

    select count(*)::integer, min(candidate_id)
    into v_top_count, v_winner
    from (
      select c.id as candidate_id, count(v.id)::integer as vote_count
      from public.national_captain_candidates c
      left join public.national_captain_votes v
        on v.candidate_id = c.id
       and v.election_id = v_e.id
       and v.round_number = v_e.current_round
      where c.election_id = v_e.id
        and c.status = 'active'
      group by c.id
    ) x
    where vote_count = v_max_votes;
  else
    select max(vote_count) into v_max_votes
    from (
      select rc.candidate_id, count(v.id)::integer as vote_count
      from public.national_captain_runoff_candidates rc
      left join public.national_captain_votes v
        on v.candidate_id = rc.candidate_id
       and v.election_id = rc.election_id
       and v.round_number = rc.round_number
      where rc.election_id = v_e.id
        and rc.round_number = v_e.current_round
      group by rc.candidate_id
    ) x;

    select count(*)::integer, min(candidate_id)
    into v_top_count, v_winner
    from (
      select rc.candidate_id, count(v.id)::integer as vote_count
      from public.national_captain_runoff_candidates rc
      left join public.national_captain_votes v
        on v.candidate_id = rc.candidate_id
       and v.election_id = rc.election_id
       and v.round_number = rc.round_number
      where rc.election_id = v_e.id
        and rc.round_number = v_e.current_round
      group by rc.candidate_id
    ) x
    where vote_count = v_max_votes;
  end if;

  if coalesce(v_top_count, 0) > 1 then
    select * into v_cfg from public.national_team_config where id = 1;

    if v_e.status = 'voting' then
      insert into public.national_captain_runoff_candidates(election_id, round_number, candidate_id)
      select v_e.id, v_e.current_round + 1, c.id
      from public.national_captain_candidates c
      left join public.national_captain_votes v
        on v.candidate_id = c.id
       and v.election_id = v_e.id
       and v.round_number = v_e.current_round
      where c.election_id = v_e.id
        and c.status = 'active'
      group by c.id
      having count(v.id)::integer = v_max_votes;
    else
      insert into public.national_captain_runoff_candidates(election_id, round_number, candidate_id)
      select v_e.id, v_e.current_round + 1, rc.candidate_id
      from public.national_captain_runoff_candidates rc
      left join public.national_captain_votes v
        on v.candidate_id = rc.candidate_id
       and v.election_id = rc.election_id
       and v.round_number = rc.round_number
      where rc.election_id = v_e.id
        and rc.round_number = v_e.current_round
      group by rc.candidate_id
      having count(v.id)::integer = v_max_votes;
    end if;

    update public.national_captain_elections
    set status = 'runoff',
        current_round = current_round + 1,
        runoff_end_game_day = v_day + v_cfg.runoff_days,
        updated_at = now()
    where id = v_e.id;

    perform public.national_team_record_event_v1(
      v_e.association_id,
      'captain_election_runoff',
      jsonb_build_object('election_id', v_e.id, 'round', v_e.current_round + 1),
      v_e.season_number
    );
    return;
  end if;

  if v_winner is null then
    update public.national_captain_elections
    set status = 'completed',
        completed_game_day = v_day,
        updated_at = now()
    where id = v_e.id;
    return;
  end if;

  select
    c.id,
    c.membership_id,
    c.user_id,
    c.player_id
  into v_candidate
  from public.national_captain_candidates c
  where c.id = v_winner;

  update public.national_captain_elections
  set status = 'completed',
      winning_candidate_id = v_winner,
      completed_game_day = v_day,
      updated_at = now()
  where id = v_e.id;

  v_term_start := (v_e.season_number - 1) * 366;
  v_term_end := v_e.season_number * 366 - 1;

  insert into public.national_captain_terms(
    association_id, election_id, candidate_id, membership_id, user_id, player_id,
    season_number, term_start_game_day, term_end_game_day, status
  )
  values (
    v_e.association_id, v_e.id, v_candidate.id, v_candidate.membership_id,
    v_candidate.user_id, v_candidate.player_id, v_e.season_number,
    v_term_start, v_term_end,
    case when v_day < v_term_start then 'scheduled' else 'active' end
  )
  on conflict (association_id, season_number) do update
  set election_id = excluded.election_id,
      candidate_id = excluded.candidate_id,
      membership_id = excluded.membership_id,
      user_id = excluded.user_id,
      player_id = excluded.player_id,
      term_start_game_day = excluded.term_start_game_day,
      term_end_game_day = excluded.term_end_game_day,
      status = excluded.status;

  perform public.national_team_record_event_v1(
    v_e.association_id,
    'captain_elected',
    jsonb_build_object(
      'election_id', v_e.id,
      'candidate_id', v_candidate.id,
      'player_id', v_candidate.player_id,
      'round', v_e.current_round
    ),
    v_e.season_number
  );
end;
$$;

create or replace function public.fill_national_team_division_vacancies_v1(
  p_world text,
  p_region_code text,
  p_season_number integer
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  d record;
  lower_tier integer;
  vacancy_count integer;
  moved integer := 0;
  candidate_entry uuid;
begin
  for d in
    select id, tier_level, capacity
    from public.national_team_divisions
    where world = p_world
      and region_code = p_region_code
      and is_active
    order by tier_level asc, sort_order asc, division_code asc
  loop
    select d.capacity - count(*)::integer
    into vacancy_count
    from public.national_team_division_entries e
    where e.division_id = d.id
      and e.season_number = p_season_number
      and e.status = 'active';

    while vacancy_count > 0 loop
      select min(tier_level) into lower_tier
      from public.national_team_divisions
      where world = p_world
        and region_code = p_region_code
        and is_active
        and tier_level > d.tier_level;

      if lower_tier is null then
        exit;
      end if;

      select e.id into candidate_entry
      from public.national_team_division_entries e
      join public.national_team_divisions ld on ld.id = e.division_id
      join public.national_associations a on a.id = e.association_id
      left join public.national_team_division_entries prev
        on prev.association_id = e.association_id
       and prev.season_number = p_season_number - 1
      where e.season_number = p_season_number
        and e.status = 'active'
        and ld.world = p_world
        and ld.region_code = p_region_code
        and ld.tier_level = lower_tier
        and a.status in ('active', 'renewal_required')
      order by prev.final_position nulls last, a.country_code
      limit 1;

      if candidate_entry is null then
        exit;
      end if;

      update public.national_team_division_entries
      set division_id = d.id,
          entry_reason = 'cascade_promoted',
          updated_at = now()
      where id = candidate_entry;

      moved := moved + 1;
      vacancy_count := vacancy_count - 1;
      candidate_entry := null;
    end loop;
  end loop;

  return moved;
end;
$$;

create or replace function public.prepare_national_team_division_entries_v1(
  p_season_number integer
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  a record;
  prev record;
  target_division uuid;
  target_tier integer;
  created_count integer := 0;
  r record;
begin
  for a in
    select na.*
    from public.national_associations na
    where na.activated_game_day is not null
      and na.status in ('active', 'renewal_required')
      and (
        p_season_number = na.activated_season
        or exists (
          select 1
          from public.national_association_funds f
          where f.association_id = na.id
            and f.fund_type = 'season_renewal'
            and f.season_number = p_season_number
            and f.status = 'completed'
        )
      )
  loop
    if exists (
      select 1 from public.national_team_division_entries e
      where e.association_id = a.id
        and e.season_number = p_season_number
        and e.status = 'active'
    ) then
      continue;
    end if;

    select
      e.division_id,
      e.sporting_outcome,
      d.tier_level
    into prev
    from public.national_team_division_entries e
    join public.national_team_divisions d on d.id = e.division_id
    where e.association_id = a.id
      and e.season_number = p_season_number - 1
    order by e.created_at desc
    limit 1;

    if prev.division_id is null then
      target_tier := null;
      select d.id into target_division
      from public.national_team_divisions d
      where d.world = a.world
        and d.region_code = a.region_code
        and d.is_active
      order by d.tier_level desc, d.sort_order, d.division_code
      limit 1;

      if target_division is not null then
        insert into public.national_team_division_entries(
          association_id, division_id, season_number, status, entry_reason
        )
        values (a.id, target_division, p_season_number, 'active', 'new_association')
        on conflict (association_id, season_number) do nothing;
        if found then created_count := created_count + 1; end if;
      end if;
      continue;
    end if;

    target_tier := prev.tier_level
      + case prev.sporting_outcome
          when 'promoted' then -1
          when 'relegated' then 1
          else 0
        end;

    select d.id into target_division
    from public.national_team_divisions d
    where d.world = a.world
      and d.region_code = a.region_code
      and d.is_active
      and d.tier_level = target_tier
    order by d.sort_order, d.division_code
    limit 1;

    if target_division is null then
      select d.id into target_division
      from public.national_team_divisions d
      where d.world = a.world
        and d.region_code = a.region_code
        and d.is_active
      order by
        abs(d.tier_level - target_tier),
        d.sort_order,
        d.division_code
      limit 1;
    end if;

    if target_division is not null then
      insert into public.national_team_division_entries(
        association_id, division_id, season_number, status, entry_reason
      )
      values (
        a.id,
        target_division,
        p_season_number,
        'active',
        case prev.sporting_outcome
          when 'promoted' then 'promoted'
          when 'relegated' then 'relegated'
          else 'retained'
        end
      )
      on conflict (association_id, season_number) do nothing;
      if found then created_count := created_count + 1; end if;
    end if;
  end loop;

  for r in
    select distinct world, region_code
    from public.national_team_divisions
    where is_active
  loop
    perform public.fill_national_team_division_vacancies_v1(
      r.world, r.region_code, p_season_number
    );
  end loop;

  return created_count;
end;
$$;

create or replace function public.process_national_association_lifecycle_v1()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cfg public.national_team_config%rowtype;
  v_day integer := public.national_team_current_abs_day_v1();
  v_season integer := (public.national_team_current_abs_day_v1() / 366) + 1;
  v_day_of_season integer := public.national_team_current_abs_day_v1() % 366;
  v_next_season integer := ((public.national_team_current_abs_day_v1() / 366) + 1) + 1;
  v_open integer := 0;
  v_suspended integer := 0;
  v_transitioned integer := 0;
  a record;
  e record;
  v_fund_id uuid;
  v_was_suspended boolean;
begin
  select * into v_cfg from public.national_team_config where id = 1;

  update public.national_captain_terms
  set status = 'completed'
  where status = 'active'
    and term_end_game_day < v_day;

  update public.national_captain_terms
  set status = 'active'
  where status = 'scheduled'
    and term_start_game_day <= v_day
    and term_end_game_day >= v_day;

  for a in
    select id, status
    from public.national_associations
    where activated_game_day is not null
      and status in ('active', 'renewal_required')
  loop
    perform public.ensure_national_captain_election_v1(a.id, v_season);
  end loop;

  if v_day_of_season >= v_cfg.renewal_open_day_of_season then
    for a in
      select *
      from public.national_associations
      where activated_game_day is not null
        and status in ('active', 'renewal_required', 'suspended')
    loop
      insert into public.national_association_funds(
        association_id, fund_type, season_number, target_amount,
        contributed_amount, status, opens_game_day, deadline_game_day
      )
      values (
        a.id,
        'season_renewal',
        v_next_season,
        v_cfg.renewal_cost,
        0,
        'open',
        (v_season - 1) * 366 + v_cfg.renewal_open_day_of_season,
        (v_season - 1) * 366 + v_cfg.renewal_deadline_day_of_season
      )
      on conflict do nothing
      returning id into v_fund_id;

      if v_fund_id is not null then
        v_open := v_open + 1;
        if a.status = 'active' then
          update public.national_associations
          set status = 'renewal_required', updated_at = now()
          where id = a.id;
        end if;
        perform public.national_team_record_event_v1(
          a.id,
          'season_renewal_opened',
          jsonb_build_object('season_number', v_next_season, 'renewal_cost', v_cfg.renewal_cost),
          v_next_season
        );
        v_fund_id := null;
      end if;
    end loop;
  end if;

  if v_day_of_season > v_cfg.renewal_deadline_day_of_season then
    for a in
      select na.id, na.status, f.id as fund_id
      from public.national_associations na
      join public.national_association_funds f
        on f.association_id = na.id
       and f.fund_type = 'season_renewal'
       and f.season_number = v_next_season
      where na.activated_game_day is not null
        and f.status = 'open'
    loop
      update public.national_association_funds
      set status = 'expired', updated_at = now()
      where id = a.fund_id;

      update public.national_associations
      set status = 'suspended', updated_at = now()
      where id = a.id
        and status <> 'suspended';

      update public.national_team_division_entries
      set status = 'withdrawn', updated_at = now()
      where association_id = a.id
        and season_number = v_next_season
        and status = 'active';

      perform public.national_team_record_event_v1(
        a.id,
        'season_renewal_failed',
        jsonb_build_object('season_number', v_next_season),
        v_next_season
      );
      v_suspended := v_suspended + 1;
    end loop;

    perform public.prepare_national_team_division_entries_v1(v_next_season);
  end if;

  for e in
    select *
    from public.national_captain_elections
    where status in ('candidate_registration', 'campaign', 'voting', 'runoff')
  loop
    if e.status = 'candidate_registration' and v_day > e.registration_end_game_day then
      update public.national_captain_elections
      set status = 'campaign', updated_at = now()
      where id = e.id;
      v_transitioned := v_transitioned + 1;
    elsif e.status = 'campaign' and v_day > e.campaign_end_game_day then
      update public.national_captain_elections
      set status = 'voting', updated_at = now()
      where id = e.id;
      v_transitioned := v_transitioned + 1;
    elsif e.status = 'voting' and v_day > e.voting_end_game_day then
      perform public.resolve_national_captain_election_v1(e.id);
      v_transitioned := v_transitioned + 1;
    elsif e.status = 'runoff' and e.runoff_end_game_day is not null and v_day > e.runoff_end_game_day then
      perform public.resolve_national_captain_election_v1(e.id);
      v_transitioned := v_transitioned + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'game_day', v_day,
    'season', v_season,
    'renewal_funds_opened', v_open,
    'associations_suspended', v_suspended,
    'election_transitions', v_transitioned
  );
end;
$$;

create or replace function public.contribute_national_association_fund_v1(
  p_fund_id uuid,
  p_amount integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_fund public.national_association_funds%rowtype;
  v_assoc public.national_associations%rowtype;
  v_membership public.national_association_memberships%rowtype;
  v_wallet public.user_wallets%rowtype;
  v_remaining integer;
  v_accepted integer;
  v_day integer := public.national_team_current_abs_day_v1();
  v_balance bigint;
  v_was_suspended boolean;
  v_entry_season integer;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Contribution amount must be greater than zero.';
  end if;

  select * into v_fund
  from public.national_association_funds
  where id = p_fund_id
  for update;

  if not found then
    raise exception 'Association fund not found.';
  end if;

  if v_fund.status <> 'open' then
    raise exception 'This association fund is no longer open.';
  end if;

  if v_fund.deadline_game_day is not null and v_day > v_fund.deadline_game_day then
    raise exception 'The contribution deadline has passed.';
  end if;

  select * into v_assoc
  from public.national_associations
  where id = v_fund.association_id
  for update;

  select m.* into v_membership
  from public.national_association_memberships m
  where m.association_id = v_fund.association_id
    and m.user_id = v_uid
    and m.status = 'active'
  order by m.joined_game_day desc, m.created_at desc
  limit 1;

  if not found then
    raise exception 'Only active members of this national association may contribute.';
  end if;

  if v_fund.fund_type = 'activation' and v_assoc.activated_game_day is not null then
    raise exception 'This association is already activated.';
  end if;

  if v_fund.fund_type = 'season_renewal' and v_assoc.activated_game_day is null then
    raise exception 'An inactive association must complete activation first.';
  end if;

  select * into v_wallet
  from public.user_wallets
  where user_id = v_uid
  for update;

  if not found then
    raise exception 'Coin wallet not found.';
  end if;

  v_remaining := greatest(0, v_fund.target_amount - v_fund.contributed_amount);
  if v_remaining = 0 then
    raise exception 'This fund is already fully funded.';
  end if;

  v_accepted := least(p_amount, v_remaining);

  if v_wallet.coins_balance < v_accepted then
    raise exception 'Insufficient coin balance.';
  end if;

  v_balance := v_wallet.coins_balance - v_accepted;

  update public.user_wallets
  set coins_balance = v_balance,
      lifetime_coins_spent = lifetime_coins_spent + v_accepted,
      updated_at = now()
  where user_id = v_uid;

  insert into public.coin_ledger(
    user_id, amount, balance_after, entry_type, description, reference_id
  )
  values (
    v_uid,
    -v_accepted,
    v_balance,
    'spend',
    case v_fund.fund_type
      when 'activation' then 'National association activation contribution'
      else 'National association season renewal contribution'
    end,
    v_fund.id::text
  );

  insert into public.national_association_contributions(
    fund_id, association_id, membership_id, user_id, amount, game_day
  )
  values (
    v_fund.id, v_fund.association_id, v_membership.id, v_uid, v_accepted, v_day
  );

  update public.national_association_funds
  set contributed_amount = contributed_amount + v_accepted,
      status = case when contributed_amount + v_accepted >= target_amount then 'completed' else status end,
      completed_game_day = case
        when contributed_amount + v_accepted >= target_amount then coalesce(completed_game_day, v_day)
        else completed_game_day
      end,
      updated_at = now()
  where id = v_fund.id
  returning * into v_fund;

  if v_fund.fund_type = 'activation' then
    if v_assoc.activation_started_by_user_id is null then
      update public.national_associations
      set activation_started_by_user_id = v_uid,
          status = case when status = 'inactive' then 'activation_funding' else status end,
          updated_at = now()
      where id = v_assoc.id;
    elsif v_assoc.status = 'inactive' then
      update public.national_associations
      set status = 'activation_funding', updated_at = now()
      where id = v_assoc.id;
    end if;

    if v_fund.status = 'completed' then
      perform public.maybe_activate_national_association_v1(v_assoc.id);
      if exists (
        select 1 from public.national_associations
        where id = v_assoc.id and status = 'active'
      ) then
        v_entry_season := public.national_team_current_season_v1();
        perform public.assign_national_association_bottom_entry_v1(
          v_assoc.id, v_entry_season, 'new_association'
        );
        perform public.ensure_national_captain_election_v1(v_assoc.id, v_entry_season);
      end if;
    end if;
  else
    if v_fund.status = 'completed' then
      v_was_suspended := v_assoc.status = 'suspended';

      update public.national_associations
      set status = 'active', updated_at = now()
      where id = v_assoc.id;

      perform public.national_team_record_event_v1(
        v_assoc.id,
        case when v_was_suspended then 'association_reactivated' else 'season_renewal_completed' end,
        jsonb_build_object('season_number', v_fund.season_number, 'renewal_cost', v_fund.target_amount),
        v_fund.season_number
      );

      if v_was_suspended then
        perform public.assign_national_association_bottom_entry_v1(
          v_assoc.id, v_fund.season_number, 'reactivated'
        );
      end if;

      perform public.ensure_national_captain_election_v1(
        v_assoc.id, v_fund.season_number
      );
    end if;
  end if;

  return jsonb_build_object(
    'accepted_amount', v_accepted,
    'wallet_balance', v_balance,
    'fund_id', v_fund.id,
    'fund_type', v_fund.fund_type,
    'contributed_amount', v_fund.contributed_amount,
    'target_amount', v_fund.target_amount,
    'fund_status', v_fund.status,
    'association_status', (
      select status from public.national_associations where id = v_assoc.id
    )
  );
end;
$$;

create or replace function public.register_national_captain_candidate_v1(
  p_election_id uuid,
  p_manifesto text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_e public.national_captain_elections%rowtype;
  v_membership record;
  v_candidate uuid;
  v_day integer := public.national_team_current_abs_day_v1();
  v_manifesto text := btrim(coalesce(p_manifesto, ''));
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if char_length(v_manifesto) < 10 or char_length(v_manifesto) > 1000 then
    raise exception 'Manifesto must contain between 10 and 1000 characters.';
  end if;

  select * into v_e
  from public.national_captain_elections
  where id = p_election_id
  for update;

  if not found then raise exception 'Election not found.'; end if;
  if v_e.status <> 'candidate_registration' then
    raise exception 'Candidate registration is closed.';
  end if;
  if v_day < v_e.registration_start_game_day or v_day > v_e.registration_end_game_day then
    raise exception 'Candidate registration is not open today.';
  end if;

  select m.id as membership_id, m.player_id
  into v_membership
  from public.national_association_memberships m
  where m.association_id = v_e.association_id
    and m.user_id = v_uid
    and m.status = 'active'
    and m.captain_eligible
  order by m.joined_game_day desc
  limit 1;

  if not found then
    raise exception 'You are not eligible to stand in this association election.';
  end if;

  insert into public.national_captain_candidates(
    election_id, membership_id, user_id, player_id, manifesto
  )
  values (
    v_e.id, v_membership.membership_id, v_uid, v_membership.player_id, v_manifesto
  )
  on conflict (election_id, user_id) do update
  set manifesto = excluded.manifesto,
      status = 'active'
  returning id into v_candidate;

  return v_candidate;
end;
$$;

create or replace function public.cast_national_captain_vote_v1(
  p_election_id uuid,
  p_candidate_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_e public.national_captain_elections%rowtype;
  v_membership uuid;
  v_day integer := public.national_team_current_abs_day_v1();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_e
  from public.national_captain_elections
  where id = p_election_id;

  if not found then raise exception 'Election not found.'; end if;
  if v_e.status not in ('voting', 'runoff') then
    raise exception 'Voting is not currently open.';
  end if;

  if v_e.status = 'voting' and v_day > v_e.voting_end_game_day then
    raise exception 'Voting has closed.';
  end if;

  if v_e.status = 'runoff'
     and (v_e.runoff_end_game_day is null or v_day > v_e.runoff_end_game_day) then
    raise exception 'Runoff voting has closed.';
  end if;

  select m.id into v_membership
  from public.national_association_memberships m
  where m.association_id = v_e.association_id
    and m.user_id = v_uid
    and m.status = 'active'
  order by m.joined_game_day desc
  limit 1;

  if v_membership is null then
    raise exception 'Only active association members may vote.';
  end if;

  if not exists (
    select 1
    from public.national_captain_candidates c
    where c.id = p_candidate_id
      and c.election_id = v_e.id
      and c.status = 'active'
  ) then
    raise exception 'Candidate is not eligible in this election.';
  end if;

  if v_e.status = 'runoff' and not exists (
    select 1
    from public.national_captain_runoff_candidates rc
    where rc.election_id = v_e.id
      and rc.round_number = v_e.current_round
      and rc.candidate_id = p_candidate_id
  ) then
    raise exception 'Candidate is not part of the current runoff.';
  end if;

  insert into public.national_captain_votes(
    election_id, round_number, membership_id, voter_user_id,
    candidate_id, cast_game_day
  )
  values (
    v_e.id, v_e.current_round, v_membership, v_uid, p_candidate_id, v_day
  );
end;
$$;

create or replace function public.get_my_national_association_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_player record;
  v_assoc public.national_associations%rowtype;
  v_membership public.national_association_memberships%rowtype;
  v_cfg public.national_team_config%rowtype;
  v_day integer := public.national_team_current_abs_day_v1();
  v_season integer := (public.national_team_current_abs_day_v1() / 366) + 1;
  v_member_count integer;
  v_activation jsonb;
  v_renewal jsonb;
  v_division jsonb;
  v_captain jsonb;
  v_election jsonb;
  v_roster jsonb;
  v_history jsonb;
  v_treasury bigint;
  v_my_total integer;
begin
  if v_uid is null then
    raise exception 'Authentication required.';
  end if;

  select p.id, p.world, p.country_code, p.first_name, p.last_name
  into v_player
  from public.players p
  where p.owner_user_id = v_uid
  limit 1;

  if not found then
    return jsonb_build_object('available', false, 'reason', 'player_required');
  end if;

  select * into v_assoc
  from public.national_associations a
  where a.country_code = v_player.country_code
    and a.world = v_player.world
  limit 1;

  if not found then
    return jsonb_build_object('available', false, 'reason', 'association_missing');
  end if;

  select * into v_membership
  from public.national_association_memberships m
  where m.player_id = v_player.id
    and m.association_id = v_assoc.id
    and m.status = 'active'
  limit 1;

  select * into v_cfg from public.national_team_config where id = 1;

  select count(*)::integer into v_member_count
  from public.national_association_memberships
  where association_id = v_assoc.id and status = 'active';

  select jsonb_build_object(
    'id', f.id,
    'target', f.target_amount,
    'contributed', f.contributed_amount,
    'status', f.status,
    'completed_game_day', f.completed_game_day
  )
  into v_activation
  from public.national_association_funds f
  where f.association_id = v_assoc.id
    and f.fund_type = 'activation'
  limit 1;

  select jsonb_build_object(
    'id', f.id,
    'season_number', f.season_number,
    'target', f.target_amount,
    'contributed', f.contributed_amount,
    'status', f.status,
    'opens_game_day', f.opens_game_day,
    'deadline_game_day', f.deadline_game_day,
    'deadline_date', (
      select jsonb_build_object('season', g.season, 'month', g.month, 'day', g.day)
      from public.absolute_game_day_v1(f.deadline_game_day) g
    )
  )
  into v_renewal
  from public.national_association_funds f
  where f.association_id = v_assoc.id
    and f.fund_type = 'season_renewal'
  order by f.season_number desc
  limit 1;

  select jsonb_build_object(
    'entry_id', e.id,
    'division_id', d.id,
    'division_code', d.division_code,
    'label', d.label,
    'tier_level', d.tier_level,
    'region_code', d.region_code,
    'entry_reason', e.entry_reason,
    'status', e.status,
    'final_position', e.final_position
  )
  into v_division
  from public.national_team_division_entries e
  join public.national_team_divisions d on d.id = e.division_id
  where e.association_id = v_assoc.id
    and e.season_number = v_season
  order by e.created_at desc
  limit 1;

  select jsonb_build_object(
    'term_id', t.id,
    'season_number', t.season_number,
    'player_id', p.id,
    'first_name', p.first_name,
    'last_name', p.last_name,
    'status', t.status
  )
  into v_captain
  from public.national_captain_terms t
  join public.players p on p.id = t.player_id
  where t.association_id = v_assoc.id
    and t.status = 'active'
  order by t.season_number desc
  limit 1;

  select jsonb_build_object(
    'id', e.id,
    'season_number', e.season_number,
    'status', e.status,
    'current_round', e.current_round,
    'registration_start_game_day', e.registration_start_game_day,
    'registration_end_game_day', e.registration_end_game_day,
    'campaign_end_game_day', e.campaign_end_game_day,
    'voting_end_game_day', e.voting_end_game_day,
    'runoff_end_game_day', e.runoff_end_game_day,
    'winning_candidate_id', e.winning_candidate_id,
    'my_candidate_id', (
      select c.id
      from public.national_captain_candidates c
      where c.election_id = e.id and c.user_id = v_uid
      limit 1
    ),
    'my_vote_candidate_id', (
      select v.candidate_id
      from public.national_captain_votes v
      where v.election_id = e.id
        and v.round_number = e.current_round
        and v.voter_user_id = v_uid
      limit 1
    ),
    'candidates', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'candidate_id', c.id,
          'player_id', p.id,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'manifesto', c.manifesto,
          'in_current_runoff', case
            when e.status <> 'runoff' then true
            else exists (
              select 1
              from public.national_captain_runoff_candidates rc
              where rc.election_id = e.id
                and rc.round_number = e.current_round
                and rc.candidate_id = c.id
            )
          end,
          'vote_total', case
            when e.status = 'completed' then (
              select count(*)::integer
              from public.national_captain_votes v
              where v.election_id = e.id
                and v.round_number = e.current_round
                and v.candidate_id = c.id
            )
            else null
          end
        )
        order by p.last_name, p.first_name
      )
      from public.national_captain_candidates c
      join public.players p on p.id = c.player_id
      where c.election_id = e.id
        and c.status = 'active'
    ), '[]'::jsonb)
  )
  into v_election
  from public.national_captain_elections e
  where e.association_id = v_assoc.id
    and e.season_number = v_season
  limit 1;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'membership_id', m.id,
      'player_id', p.id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'captain_eligible', m.captain_eligible,
      'joined_game_day', m.joined_game_day,
      'national_appearances', 0
    )
    order by p.last_name, p.first_name
  ), '[]'::jsonb)
  into v_roster
  from public.national_association_memberships m
  join public.players p on p.id = m.player_id
  where m.association_id = v_assoc.id
    and m.status = 'active';

  select coalesce(jsonb_agg(x.item order by x.game_day desc), '[]'::jsonb)
  into v_history
  from (
    select
      e.game_day,
      jsonb_build_object(
        'id', e.id,
        'season_number', e.season_number,
        'game_day', e.game_day,
        'event_type', e.event_type,
        'details', e.details
      ) as item
    from public.national_association_events e
    where e.association_id = v_assoc.id
    order by e.game_day desc, e.created_at desc
    limit 12
  ) x;

  select coins_balance into v_treasury
  from public.national_association_treasuries
  where association_id = v_assoc.id;

  select coalesce(sum(c.amount), 0)::integer into v_my_total
  from public.national_association_contributions c
  where c.association_id = v_assoc.id
    and c.user_id = v_uid;

  return jsonb_build_object(
    'available', true,
    'game_day', v_day,
    'season_number', v_season,
    'association', jsonb_build_object(
      'id', v_assoc.id,
      'name', v_assoc.name,
      'country_code', v_assoc.country_code,
      'world', v_assoc.world,
      'region_code', v_assoc.region_code,
      'status', v_assoc.status,
      'activated_game_day', v_assoc.activated_game_day,
      'activated_season', v_assoc.activated_season,
      'member_count', v_member_count,
      'minimum_activation_members', v_cfg.activation_min_members,
      'is_member', v_membership.id is not null,
      'captain_eligible', coalesce(v_membership.captain_eligible, false)
    ),
    'activation_fund', coalesce(v_activation, '{}'::jsonb),
    'renewal_fund', coalesce(v_renewal, '{}'::jsonb),
    'division', coalesce(v_division, '{}'::jsonb),
    'captain', coalesce(v_captain, '{}'::jsonb),
    'election', coalesce(v_election, '{}'::jsonb),
    'roster', v_roster,
    'history', v_history,
    'treasury_balance', coalesce(v_treasury, 0),
    'my_total_contributions', v_my_total,
    'rules', jsonb_build_object(
      'activation_cost', v_cfg.activation_cost,
      'activation_min_members', v_cfg.activation_min_members,
      'renewal_cost', v_cfg.renewal_cost,
      'voting_days', v_cfg.voting_days,
      'runoff_days', v_cfg.runoff_days
    )
  );
end;
$$;

revoke all on function public.national_team_current_abs_day_v1() from public;
revoke all on function public.national_team_current_season_v1() from public;
revoke all on function public.national_team_record_event_v1(uuid, text, jsonb, integer) from public;
revoke all on function public.maybe_activate_national_association_v1(uuid) from public;
revoke all on function public.sync_national_association_membership_for_player_v1(uuid) from public;
revoke all on function public.trg_sync_national_association_membership_v1() from public;
revoke all on function public.assign_national_association_bottom_entry_v1(uuid, integer, text) from public;
revoke all on function public.ensure_national_captain_election_v1(uuid, integer) from public;
revoke all on function public.resolve_national_captain_election_v1(uuid) from public;
revoke all on function public.fill_national_team_division_vacancies_v1(text, text, integer) from public;
revoke all on function public.prepare_national_team_division_entries_v1(integer) from public;
revoke all on function public.process_national_association_lifecycle_v1() from public;
revoke all on function public.contribute_national_association_fund_v1(uuid, integer) from public;
revoke all on function public.register_national_captain_candidate_v1(uuid, text) from public;
revoke all on function public.cast_national_captain_vote_v1(uuid, uuid) from public;
revoke all on function public.get_my_national_association_v1() from public;

grant execute on function public.contribute_national_association_fund_v1(uuid, integer) to authenticated;
grant execute on function public.register_national_captain_candidate_v1(uuid, text) to authenticated;
grant execute on function public.cast_national_captain_vote_v1(uuid, uuid) to authenticated;
grant execute on function public.get_my_national_association_v1() to authenticated;

create or replace function public.process_current_game_day_for_all_players_internal_v1()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  d record;
  p record;
  v_count integer:=0;
begin
  perform public.process_national_association_lifecycle_v1();

  select * into d from public.get_current_game_day_internal_v1();
  for p in select id from public.players loop
    perform public.process_player_daily_activity_v1(p.id,d.season,d.month,d.day,'daily_engine');
    v_count:=v_count+1;
  end loop;
  return v_count;
end;
$$;

select public.process_national_association_lifecycle_v1();
