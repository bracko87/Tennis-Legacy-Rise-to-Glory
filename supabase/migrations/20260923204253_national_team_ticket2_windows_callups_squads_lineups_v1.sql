
-- National Team Ticket 2: windows, fixtures, call-ups, squads, lineups, chat and treasury.

alter table public.national_team_divisions
  add column if not exists promotion_slots integer not null default 1 check (promotion_slots >= 0),
  add column if not exists relegation_slots integer not null default 1 check (relegation_slots >= 0);

alter table public.national_association_treasuries
  add column if not exists cash_balance_usd bigint not null default 0,
  add column if not exists lifetime_cash_income_usd bigint not null default 0 check (lifetime_cash_income_usd >= 0),
  add column if not exists lifetime_cash_spent_usd bigint not null default 0 check (lifetime_cash_spent_usd >= 0);

create table if not exists public.national_team_competition_config (
  id smallint primary key default 1 check (id = 1),
  announcement_lead_days integer not null default 45 check (announcement_lead_days between 30 and 60),
  callup_deadline_days_before_window integer not null default 21 check (callup_deadline_days_before_window > 0),
  squad_deadline_days_before_window integer not null default 7 check (squad_deadline_days_before_window > 0),
  appearance_fee_usd integer not null default 250 check (appearance_fee_usd >= 0),
  season_grant_usd integer not null default 25000 check (season_grant_usd >= 0),
  default_accommodation_nightly_usd integer not null default 140 check (default_accommodation_nightly_usd >= 0),
  default_max_squad_size integer not null default 5 check (default_max_squad_size between 4 and 10),
  updated_at timestamptz not null default now()
);

insert into public.national_team_competition_config(id)
values (1)
on conflict (id) do nothing;

create table if not exists public.national_team_fixture_formats (
  code text primary key,
  label text not null,
  matches_to_win integer not null check (matches_to_win > 0),
  max_squad_size integer not null check (max_squad_size >= 4),
  match_sequence jsonb not null,
  allow_dead_rubber_cancel boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.national_team_fixture_formats(
  code,label,matches_to_win,max_squad_size,match_sequence,allow_dead_rubber_cancel
)
values (
  'five_match_standard',
  'Five-match national tie',
  3,
  5,
  '[
    {"order":1,"discipline":"singles","slot":"S1"},
    {"order":2,"discipline":"singles","slot":"S2"},
    {"order":3,"discipline":"doubles","slot":"D1"},
    {"order":4,"discipline":"singles","slot":"S3"},
    {"order":5,"discipline":"singles","slot":"S4"}
  ]'::jsonb,
  true
)
on conflict (code) do update
set label=excluded.label,
    matches_to_win=excluded.matches_to_win,
    max_squad_size=excluded.max_squad_size,
    match_sequence=excluded.match_sequence,
    allow_dead_rubber_cancel=excluded.allow_dead_rubber_cancel,
    is_active=true;

create table if not exists public.national_team_windows (
  id uuid primary key default gen_random_uuid(),
  world text not null check (world in ('ATP','WTA')),
  season_number integer not null check (season_number > 0),
  window_code text not null,
  label text not null,
  season_week smallint not null check (season_week between 1 and 52),
  start_absolute_day integer not null,
  end_absolute_day integer not null check (end_absolute_day >= start_absolute_day),
  announcement_absolute_day integer not null,
  callup_deadline_absolute_day integer not null,
  squad_deadline_absolute_day integer not null,
  max_ties_per_association integer not null default 2 check (max_ties_per_association between 1 and 4),
  status text not null default 'planned'
    check (status in ('planned','announced','in_progress','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(world,season_number,window_code)
);

create index if not exists national_team_windows_timeline_idx
  on public.national_team_windows(world,season_number,start_absolute_day,status);

create table if not exists public.national_team_fixtures (
  id uuid primary key default gen_random_uuid(),
  window_id uuid not null references public.national_team_windows(id) on delete cascade,
  division_id uuid references public.national_team_divisions(id) on delete set null,
  home_association_id uuid not null references public.national_associations(id) on delete restrict,
  away_association_id uuid not null references public.national_associations(id) on delete restrict,
  host_association_id uuid references public.national_associations(id) on delete set null,
  central_event_key text,
  host_city text not null,
  host_country_code text not null references public.countries(code) on delete restrict,
  host_latitude double precision,
  host_longitude double precision,
  surface text not null default 'hard' check (surface in ('hard','clay','grass')),
  environment text not null default 'indoor' check (environment in ('indoor','outdoor')),
  tie_start_absolute_day integer not null,
  tie_end_absolute_day integer not null check (tie_end_absolute_day >= tie_start_absolute_day),
  response_deadline_absolute_day integer not null,
  squad_deadline_absolute_day integer not null,
  lineup_deadline_game_second bigint not null,
  format_code text not null default 'five_match_standard'
    references public.national_team_fixture_formats(code) on delete restrict,
  expected_appearance_fee_usd integer not null default 250 check (expected_appearance_fee_usd >= 0),
  status text not null default 'planned'
    check (status in ('planned','announced','lineups_pending','ready','in_progress','completed','cancelled','forfeit')),
  home_match_wins smallint not null default 0 check (home_match_wins between 0 and 5),
  away_match_wins smallint not null default 0 check (away_match_wins between 0 and 5),
  winner_association_id uuid references public.national_associations(id) on delete set null,
  completion_reason text,
  announced_game_day integer,
  completed_game_day integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (home_association_id <> away_association_id)
);

create index if not exists national_team_fixtures_window_idx
  on public.national_team_fixtures(window_id,status,tie_start_absolute_day);

create index if not exists national_team_fixtures_home_idx
  on public.national_team_fixtures(home_association_id,tie_start_absolute_day);

create index if not exists national_team_fixtures_away_idx
  on public.national_team_fixtures(away_association_id,tie_start_absolute_day);

create table if not exists public.national_team_callups (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.national_team_fixtures(id) on delete cascade,
  association_id uuid not null references public.national_associations(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  invited_by_user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending','accepted','declined','withdrawn','expired')),
  response_deadline_absolute_day integer not null,
  expected_compensation_usd integer not null default 0 check (expected_compensation_usd >= 0),
  invited_game_day integer not null,
  responded_game_day integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fixture_id,player_id)
);

create index if not exists national_team_callups_player_idx
  on public.national_team_callups(player_id,status,response_deadline_absolute_day);

create index if not exists national_team_callups_assoc_idx
  on public.national_team_callups(association_id,fixture_id,status);

create table if not exists public.national_team_squad_members (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.national_team_fixtures(id) on delete cascade,
  association_id uuid not null references public.national_associations(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  nominated_by_user_id uuid not null references auth.users(id) on delete restrict,
  nominated_game_day integer not null,
  created_at timestamptz not null default now(),
  unique(fixture_id,player_id)
);

create index if not exists national_team_squad_fixture_assoc_idx
  on public.national_team_squad_members(fixture_id,association_id);

create table if not exists public.national_team_lineups (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.national_team_fixtures(id) on delete cascade,
  association_id uuid not null references public.national_associations(id) on delete cascade,
  status text not null default 'draft'
    check (status in ('draft','locked','auto_locked')),
  submitted_by_user_id uuid references auth.users(id) on delete set null,
  locked_at_game_second bigint,
  revealed_at_game_second bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fixture_id,association_id)
);

create table if not exists public.national_team_lineup_slots (
  lineup_id uuid not null references public.national_team_lineups(id) on delete cascade,
  slot_code text not null check (slot_code in ('S1','S2','D1A','D1B','S3','S4')),
  discipline text not null check (discipline in ('singles','doubles')),
  player_id uuid not null references public.players(id) on delete restrict,
  primary key(lineup_id,slot_code)
);

create index if not exists national_team_lineup_slots_player_idx
  on public.national_team_lineup_slots(player_id);

create table if not exists public.national_team_fixture_match_slots (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.national_team_fixtures(id) on delete cascade,
  slot_order smallint not null check (slot_order between 1 and 9),
  discipline text not null check (discipline in ('singles','doubles')),
  status text not null default 'pending'
    check (status in ('pending','scheduled','completed','walkover','cancelled_dead_rubber','cancelled')),
  home_player1_id uuid references public.players(id) on delete set null,
  home_player2_id uuid references public.players(id) on delete set null,
  away_player1_id uuid references public.players(id) on delete set null,
  away_player2_id uuid references public.players(id) on delete set null,
  engine_match_id uuid references public.tournament_matches(id) on delete set null,
  engine_doubles_match_id uuid references public.tournament_doubles_matches(id) on delete set null,
  winner_association_id uuid references public.national_associations(id) on delete set null,
  completed_game_day integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fixture_id,slot_order)
);

create index if not exists national_fixture_match_engine_singles_idx
  on public.national_team_fixture_match_slots(engine_match_id)
  where engine_match_id is not null;

create index if not exists national_fixture_match_engine_doubles_idx
  on public.national_team_fixture_match_slots(engine_doubles_match_id)
  where engine_doubles_match_id is not null;

create table if not exists public.national_team_engine_competitions (
  fixture_id uuid primary key references public.national_team_fixtures(id) on delete cascade,
  tournament_series_id uuid not null references public.tournament_series(id) on delete cascade,
  tournament_edition_id uuid not null references public.tournament_editions(id) on delete cascade,
  competition_id uuid not null unique references public.tournament_world_competitions(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.national_team_player_appearances (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references public.national_team_fixtures(id) on delete cascade,
  association_id uuid not null references public.national_associations(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  singles_matches smallint not null default 0 check (singles_matches between 0 and 1),
  doubles_matches smallint not null default 0 check (doubles_matches between 0 and 1),
  singles_wins smallint not null default 0 check (singles_wins between 0 and 1),
  doubles_wins smallint not null default 0 check (doubles_wins between 0 and 1),
  appearance_fee_usd integer not null default 0 check (appearance_fee_usd >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(fixture_id,player_id)
);

create index if not exists national_team_appearances_player_idx
  on public.national_team_player_appearances(player_id,created_at desc);

create table if not exists public.national_team_division_standings (
  division_id uuid not null references public.national_team_divisions(id) on delete cascade,
  season_number integer not null check (season_number > 0),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  ties_played integer not null default 0 check (ties_played >= 0),
  ties_won integer not null default 0 check (ties_won >= 0),
  ties_lost integer not null default 0 check (ties_lost >= 0),
  matches_won integer not null default 0 check (matches_won >= 0),
  matches_lost integer not null default 0 check (matches_lost >= 0),
  standings_points integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key(division_id,season_number,association_id)
);

create table if not exists public.national_team_chat_messages (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  game_absolute_day integer not null,
  message text not null check (char_length(btrim(message)) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists national_team_chat_assoc_created_idx
  on public.national_team_chat_messages(association_id,created_at desc);

create table if not exists public.national_association_finance_transactions (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.national_associations(id) on delete cascade,
  season_number integer not null check (season_number > 0),
  game_absolute_day integer not null,
  category text not null,
  amount_usd bigint not null check (amount_usd <> 0),
  balance_after_usd bigint not null,
  description text not null,
  source_type text,
  source_id text,
  idempotency_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(association_id,idempotency_key)
);

create index if not exists national_assoc_finance_history_idx
  on public.national_association_finance_transactions(association_id,created_at desc);

alter table public.national_team_competition_config enable row level security;
alter table public.national_team_fixture_formats enable row level security;
alter table public.national_team_windows enable row level security;
alter table public.national_team_fixtures enable row level security;
alter table public.national_team_callups enable row level security;
alter table public.national_team_squad_members enable row level security;
alter table public.national_team_lineups enable row level security;
alter table public.national_team_lineup_slots enable row level security;
alter table public.national_team_fixture_match_slots enable row level security;
alter table public.national_team_engine_competitions enable row level security;
alter table public.national_team_player_appearances enable row level security;
alter table public.national_team_division_standings enable row level security;
alter table public.national_team_chat_messages enable row level security;
alter table public.national_association_finance_transactions enable row level security;

drop policy if exists national_windows_authenticated_read on public.national_team_windows;
create policy national_windows_authenticated_read
on public.national_team_windows for select to authenticated using (status <> 'cancelled');

drop policy if exists national_fixtures_authenticated_read on public.national_team_fixtures;
create policy national_fixtures_authenticated_read
on public.national_team_fixtures for select to authenticated using (status <> 'planned');

drop policy if exists national_fixture_match_slots_authenticated_read on public.national_team_fixture_match_slots;
create policy national_fixture_match_slots_authenticated_read
on public.national_team_fixture_match_slots for select to authenticated using (true);

drop policy if exists national_standings_authenticated_read on public.national_team_division_standings;
create policy national_standings_authenticated_read
on public.national_team_division_standings for select to authenticated using (true);

grant select on public.national_team_windows to authenticated;
grant select on public.national_team_fixtures to authenticated;
grant select on public.national_team_fixture_match_slots to authenticated;
grant select on public.national_team_division_standings to authenticated;

create or replace function public.post_national_association_finance_transaction_v1(
  p_association_id uuid,
  p_amount_usd bigint,
  p_category text,
  p_description text,
  p_source_type text,
  p_source_id text,
  p_idempotency_key text,
  p_metadata jsonb default '{}'::jsonb,
  p_game_absolute_day integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_existing public.national_association_finance_transactions%rowtype;
  v_day integer := coalesce(p_game_absolute_day, public.national_team_current_abs_day_v1());
  v_season integer := (coalesce(p_game_absolute_day, public.national_team_current_abs_day_v1()) / 366) + 1;
  v_before bigint;
  v_after bigint;
begin
  if p_amount_usd = 0 then raise exception 'Association finance amount cannot be zero.'; end if;
  if btrim(coalesce(p_idempotency_key,'')) = '' then raise exception 'Association finance idempotency key is required.'; end if;

  select * into v_existing
  from public.national_association_finance_transactions
  where association_id=p_association_id
    and idempotency_key=p_idempotency_key;

  if v_existing.id is not null then
    return jsonb_build_object(
      'status','already_posted',
      'transaction_id',v_existing.id,
      'amount_usd',v_existing.amount_usd,
      'balance_usd',v_existing.balance_after_usd
    );
  end if;

  insert into public.national_association_treasuries(association_id)
  values(p_association_id)
  on conflict(association_id) do nothing;

  select cash_balance_usd into v_before
  from public.national_association_treasuries
  where association_id=p_association_id
  for update;

  v_after:=coalesce(v_before,0)+p_amount_usd;

  update public.national_association_treasuries
  set cash_balance_usd=v_after,
      lifetime_cash_income_usd=lifetime_cash_income_usd+case when p_amount_usd>0 then p_amount_usd else 0 end,
      lifetime_cash_spent_usd=lifetime_cash_spent_usd+case when p_amount_usd<0 then abs(p_amount_usd) else 0 end,
      updated_at=now()
  where association_id=p_association_id;

  insert into public.national_association_finance_transactions(
    association_id,season_number,game_absolute_day,category,amount_usd,balance_after_usd,
    description,source_type,source_id,idempotency_key,metadata
  )
  values(
    p_association_id,v_season,v_day,lower(p_category),p_amount_usd,v_after,
    p_description,p_source_type,p_source_id,p_idempotency_key,coalesce(p_metadata,'{}'::jsonb)
  )
  returning * into v_existing;

  return jsonb_build_object(
    'status','posted',
    'transaction_id',v_existing.id,
    'amount_usd',p_amount_usd,
    'balance_before_usd',v_before,
    'balance_usd',v_after
  );
end;
$$;

create or replace function public.ensure_national_association_season_grant_v1(
  p_association_id uuid,
  p_season_number integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cfg public.national_team_competition_config%rowtype;
  v_result jsonb;
begin
  select * into v_cfg from public.national_team_competition_config where id=1;

  v_result:=public.post_national_association_finance_transaction_v1(
    p_association_id,
    v_cfg.season_grant_usd,
    'federation_grant',
    format('Season %s national association grant',p_season_number),
    'season_grant',
    p_season_number::text,
    format('national-season-grant:%s',p_season_number),
    jsonb_build_object('season_number',p_season_number),
    (p_season_number-1)*366
  );

  return v_result;
end;
$$;

create or replace function public.ensure_national_team_windows_v1(
  p_season_number integer
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cfg public.national_team_competition_config%rowtype;
  v_world text;
  v_week smallint;
  v_code text;
  v_label text;
  v_start integer;
  v_count integer:=0;
begin
  if p_season_number < 1 then raise exception 'Invalid season.'; end if;
  select * into v_cfg from public.national_team_competition_config where id=1;

  foreach v_world in array array['ATP'::text,'WTA'::text] loop
    foreach v_week in array array[22::smallint,47::smallint] loop
      v_code:=case when v_week=22 then 'national_week_1' else 'national_week_2' end;
      v_label:=case when v_week=22 then 'National Team Week I' else 'National Team Week II' end;
      v_start:=(p_season_number-1)*366+2+(v_week-1)*7;

      insert into public.national_team_windows(
        world,season_number,window_code,label,season_week,start_absolute_day,end_absolute_day,
        announcement_absolute_day,callup_deadline_absolute_day,squad_deadline_absolute_day,status
      )
      values(
        v_world,p_season_number,v_code,v_label,v_week,v_start,v_start+6,
        v_start-v_cfg.announcement_lead_days,
        v_start-v_cfg.callup_deadline_days_before_window,
        v_start-v_cfg.squad_deadline_days_before_window,
        case
          when public.national_team_current_abs_day_v1() >= v_start then 'in_progress'
          when public.national_team_current_abs_day_v1() >= v_start-v_cfg.announcement_lead_days then 'announced'
          else 'planned'
        end
      )
      on conflict(world,season_number,window_code) do nothing;

      if found then v_count:=v_count+1; end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

select public.ensure_national_team_windows_v1(1);
select public.ensure_national_team_windows_v1(2);

create or replace function public.is_national_team_engine_competition_v1(
  p_competition_id uuid
)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists(
    select 1
    from public.national_team_engine_competitions n
    where n.competition_id=p_competition_id
  );
$$;

create or replace function public.national_fixture_association_for_captain_v1(
  p_fixture_id uuid,
  p_user_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select t.association_id
  from public.national_team_fixtures f
  join public.national_team_windows w on w.id=f.window_id
  join public.national_captain_terms t
    on t.association_id in (f.home_association_id,f.away_association_id)
   and t.season_number=w.season_number
   and t.user_id=p_user_id
   and t.status in ('active','scheduled')
  where f.id=p_fixture_id
  limit 1;
$$;

create or replace function public.create_national_team_fixture_v1(
  p_window_id uuid,
  p_home_association_id uuid,
  p_away_association_id uuid,
  p_division_id uuid,
  p_host_association_id uuid,
  p_central_event_key text,
  p_host_city text,
  p_host_country_code text,
  p_host_latitude double precision,
  p_host_longitude double precision,
  p_surface text,
  p_environment text,
  p_tie_start_absolute_day integer,
  p_format_code text default 'five_match_standard'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_window public.national_team_windows%rowtype;
  v_home public.national_associations%rowtype;
  v_away public.national_associations%rowtype;
  v_cfg public.national_team_competition_config%rowtype;
  v_id uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_response integer;
  v_squad integer;
  v_lineup_second bigint;
begin
  select * into v_window from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;

  select * into v_home from public.national_associations where id=p_home_association_id;
  select * into v_away from public.national_associations where id=p_away_association_id;

  if v_home.id is null or v_away.id is null then raise exception 'National association not found.'; end if;
  if v_home.id=v_away.id then raise exception 'A national association cannot play itself.'; end if;
  if v_home.world<>v_window.world or v_away.world<>v_window.world then
    raise exception 'Fixture associations must belong to the same competition world as the national window.';
  end if;
  if p_tie_start_absolute_day < v_window.start_absolute_day
     or p_tie_start_absolute_day+1 > v_window.end_absolute_day then
    raise exception 'Tie must fit inside the national-team window.';
  end if;

  select * into v_cfg from public.national_team_competition_config where id=1;
  v_response:=least(v_window.callup_deadline_absolute_day,p_tie_start_absolute_day-7);
  v_squad:=least(v_window.squad_deadline_absolute_day,p_tie_start_absolute_day-2);
  v_lineup_second:=(p_tie_start_absolute_day::bigint-1)*86400 + 18*3600;

  insert into public.national_team_fixtures(
    window_id,division_id,home_association_id,away_association_id,host_association_id,
    central_event_key,host_city,host_country_code,host_latitude,host_longitude,
    surface,environment,tie_start_absolute_day,tie_end_absolute_day,
    response_deadline_absolute_day,squad_deadline_absolute_day,lineup_deadline_game_second,
    format_code,expected_appearance_fee_usd,status,announced_game_day
  )
  values(
    p_window_id,p_division_id,p_home_association_id,p_away_association_id,p_host_association_id,
    nullif(btrim(coalesce(p_central_event_key,'')),''),
    btrim(p_host_city),upper(p_host_country_code),p_host_latitude,p_host_longitude,
    lower(p_surface),lower(p_environment),p_tie_start_absolute_day,p_tie_start_absolute_day+1,
    v_response,v_squad,v_lineup_second,
    p_format_code,v_cfg.appearance_fee_usd,
    case when v_day>=v_window.announcement_absolute_day then 'announced' else 'planned' end,
    case when v_day>=v_window.announcement_absolute_day then v_day else null end
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.schedule_national_window_pairings_v1(
  p_window_id uuid
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  w public.national_team_windows%rowtype;
  d record;
  team record;
  pending uuid:=null;
  v_count integer:=0;
  v_country text;
  v_lat double precision;
  v_lon double precision;
begin
  select * into w from public.national_team_windows where id=p_window_id;
  if not found then raise exception 'National-team window not found.'; end if;

  for d in
    select id
    from public.national_team_divisions
    where world=w.world and is_active
    order by tier_level,sort_order,division_code
  loop
    pending:=null;
    for team in
      select e.association_id
      from public.national_team_division_entries e
      join public.national_associations a on a.id=e.association_id
      left join public.national_team_division_standings s
        on s.division_id=e.division_id
       and s.season_number=e.season_number
       and s.association_id=e.association_id
      where e.division_id=d.id
        and e.season_number=w.season_number
        and e.status='active'
        and a.status in ('active','renewal_required')
      order by coalesce(s.standings_points,0) desc,
               coalesce(s.ties_won,0) desc,
               a.country_code
    loop
      if pending is null then
        pending:=team.association_id;
      else
        select a.country_code into v_country
        from public.national_associations a where a.id=pending;

        select latitude::double precision,longitude::double precision
        into v_lat,v_lon
        from public.training_travel_country_reference
        where country_code=v_country;

        perform public.create_national_team_fixture_v1(
          w.id,
          pending,
          team.association_id,
          d.id,
          pending,
          null,
          coalesce((select name from public.countries where code=v_country),v_country),
          v_country,
          v_lat,
          v_lon,
          'hard',
          'indoor',
          w.start_absolute_day,
          'five_match_standard'
        );
        v_count:=v_count+1;
        pending:=null;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

create or replace function public.check_player_national_window_availability_v1(
  p_player_id uuid,
  p_fixture_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  p public.players%rowtype;
  v_block record;
  v_existing public.player_calendar_commitments%rowtype;
  v_location_key text;
begin
  select * into f from public.national_team_fixtures where id=p_fixture_id;
  if not found then return jsonb_build_object('available',false,'reason','fixture_missing'); end if;
  select * into w from public.national_team_windows where id=f.window_id;
  select * into p from public.players where id=p_player_id;

  if p.id is null or p.moderation_status='rejected' then
    return jsonb_build_object('available',false,'reason','player_unavailable');
  end if;
  if p.world<>w.world then
    return jsonb_build_object('available',false,'reason','different_world');
  end if;

  select c.* into v_existing
  from public.player_calendar_commitments c
  where c.player_id=p_player_id
    and c.source_type='national_team'
    and c.source_id=w.id
    and c.status='committed'
  limit 1;

  v_location_key:=format(
    'national:%s:%s:%s',
    w.id,
    f.host_country_code,
    lower(regexp_replace(f.host_city,'\s+','-','g'))
  );

  if v_existing.id is not null then
    if v_existing.location_key is distinct from v_location_key then
      return jsonb_build_object(
        'available',false,
        'reason','national_window_different_location',
        'existing_location_key',v_existing.location_key
      );
    end if;
    return jsonb_build_object(
      'available',true,
      'reason','already_committed_same_national_window',
      'window_id',w.id,
      'start_absolute_day',w.start_absolute_day,
      'end_absolute_day',w.end_absolute_day,
      'location_key',v_location_key
    );
  end if;

  select te.competition_id,ts.name,ts.city
  into v_block
  from public.tournament_entries te
  join public.tournament_world_competitions wc on wc.id=te.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(te.competition_id) cw
  where te.player_id=p_player_id
    and te.entry_status='active'
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
    and not public.is_national_team_engine_competition_v1(te.competition_id)
  order by cw.start_absolute_day
  limit 1;

  if v_block.competition_id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','singles_entry_overlap',
      'blocking_competition_id',v_block.competition_id,
      'blocking_tournament',v_block.name,
      'blocking_city',v_block.city
    );
  end if;

  v_block:=null;

  select a.competition_id,ts.name,ts.city
  into v_block
  from public.tournament_applications a
  join public.tournament_world_competitions wc on wc.id=a.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(a.competition_id) cw
  where a.player_id=p_player_id
    and a.status in ('accepted_main_draw','accepted_qualification')
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
  order by cw.start_absolute_day
  limit 1;

  if v_block.competition_id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','accepted_singles_overlap',
      'blocking_competition_id',v_block.competition_id,
      'blocking_tournament',v_block.name,
      'blocking_city',v_block.city
    );
  end if;

  v_block:=null;

  select dt.competition_id,ts.name,ts.city
  into v_block
  from public.tournament_doubles_teams dt
  join public.tournament_world_competitions wc on wc.id=dt.competition_id
  join public.tournament_editions ed on ed.id=wc.tournament_edition_id
  join public.tournament_series ts on ts.id=ed.tournament_series_id
  cross join lateral public.get_competition_window_v1(dt.competition_id) cw
  where (dt.player1_id=p_player_id or dt.player2_id=p_player_id)
    and dt.status in ('confirmed','active','alternate')
    and cw.start_absolute_day<=w.end_absolute_day
    and cw.end_absolute_day>=w.start_absolute_day
    and not public.is_national_team_engine_competition_v1(dt.competition_id)
  order by cw.start_absolute_day
  limit 1;

  if v_block.competition_id is not null then
    return jsonb_build_object(
      'available',false,
      'reason','doubles_entry_overlap',
      'blocking_competition_id',v_block.competition_id,
      'blocking_tournament',v_block.name,
      'blocking_city',v_block.city
    );
  end if;

  if exists(
    select 1
    from public.player_calendar_commitments c
    where c.player_id=p_player_id
      and c.status='committed'
      and not (c.source_type='national_team' and c.source_id=w.id)
      and c.starts_absolute_day<=w.end_absolute_day
      and c.ends_absolute_day>=w.start_absolute_day
  ) then
    return jsonb_build_object('available',false,'reason','calendar_commitment_overlap');
  end if;

  return jsonb_build_object(
    'available',true,
    'reason','available',
    'window_id',w.id,
    'start_absolute_day',w.start_absolute_day,
    'end_absolute_day',w.end_absolute_day,
    'location_key',v_location_key
  );
end;
$$;

create or replace function public.send_national_team_callup_v1(
  p_fixture_id uuid,
  p_player_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
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
  select name into v_opponent_name
  from public.national_associations
  where id=case when v_assoc=f.home_association_id then f.away_association_id else f.home_association_id end;

  if v_owner is not null then
    perform public.emit_notification_v1(
      v_owner,
      p_player_id,
      'national_team.callup',
      'National-team call-up',
      format(
        '%s has invited you for the national tie against %s in %s. Respond before game day %s.',
        a.name,v_opponent_name,f.host_city,f.response_deadline_absolute_day
      ),
      '/game/national-team',
      jsonb_build_object(
        'fixture_id',f.id,
        'association_id',a.id,
        'association_name',a.name,
        'opponent_name',v_opponent_name,
        'host_city',f.host_city,
        'host_country_code',f.host_country_code,
        'window_start_absolute_day',w.start_absolute_day,
        'window_end_absolute_day',w.end_absolute_day,
        'response_deadline_absolute_day',f.response_deadline_absolute_day,
        'expected_compensation_usd',f.expected_appearance_fee_usd
      ),
      format('national-callup:%s:%s',f.id,p_player_id)
    );
  end if;

  return v_callup;
end;
$$;

create or replace function public.respond_national_team_callup_v1(
  p_callup_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  c public.national_team_callups%rowtype;
  f public.national_team_fixtures%rowtype;
  w public.national_team_windows%rowtype;
  p public.players%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_availability jsonb;
  v_location_key text;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into c from public.national_team_callups where id=p_callup_id for update;
  if not found then raise exception 'Call-up not found.'; end if;

  select * into p from public.players where id=c.player_id;
  if p.owner_user_id is distinct from v_uid then raise exception 'This call-up belongs to another player.'; end if;
  if c.status<>'pending' then raise exception 'This call-up has already been answered.'; end if;
  if v_day>c.response_deadline_absolute_day then
    update public.national_team_callups set status='expired',updated_at=now() where id=c.id;
    raise exception 'The call-up response deadline has passed.';
  end if;

  select * into f from public.national_team_fixtures where id=c.fixture_id;
  select * into w from public.national_team_windows where id=f.window_id;

  if not p_accept then
    update public.national_team_callups
    set status='declined',responded_game_day=v_day,updated_at=now()
    where id=c.id;

    return jsonb_build_object('status','declined','callup_id',c.id);
  end if;

  v_availability:=public.check_player_national_window_availability_v1(c.player_id,c.fixture_id);
  if not coalesce((v_availability->>'available')::boolean,false) then
    return jsonb_build_object(
      'status','blocked',
      'callup_id',c.id,
      'availability',v_availability
    );
  end if;

  v_location_key:=v_availability->>'location_key';

  update public.national_team_callups
  set status='accepted',responded_game_day=v_day,updated_at=now()
  where id=c.id;

  insert into public.player_calendar_commitments(
    player_id,source_type,source_id,competition_id,event_key,
    starts_absolute_day,ends_absolute_day,location_key,status
  )
  values(
    c.player_id,'national_team',w.id,null,
    'national-team:'||w.id::text,
    w.start_absolute_day,w.end_absolute_day,v_location_key,'committed'
  )
  on conflict do nothing;

  perform public.rebuild_player_travel_plan_v1(c.player_id);

  return jsonb_build_object(
    'status','accepted',
    'callup_id',c.id,
    'window_id',w.id,
    'commitment_start_absolute_day',w.start_absolute_day,
    'commitment_end_absolute_day',w.end_absolute_day
  );
end;
$$;

create unique index if not exists national_calendar_commitment_one_window_idx
  on public.player_calendar_commitments(player_id,source_type,source_id)
  where source_type='national_team' and status='committed';

create or replace function public.set_national_team_squad_v1(
  p_fixture_id uuid,
  p_player_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  f public.national_team_fixtures%rowtype;
  fmt public.national_team_fixture_formats%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_count integer;
  v_distinct integer;
  v_player uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found.'; end if;
  if v_day>f.squad_deadline_absolute_day then raise exception 'Squad nomination deadline has passed.'; end if;

  v_assoc:=public.national_fixture_association_for_captain_v1(p_fixture_id,v_uid);
  if v_assoc is null then raise exception 'Only the elected captain may nominate the squad.'; end if;

  select * into fmt from public.national_team_fixture_formats where code=f.format_code;
  v_count:=coalesce(cardinality(p_player_ids),0);
  select count(distinct x)::integer into v_distinct from unnest(coalesce(p_player_ids,array[]::uuid[])) x;

  if v_count<4 or v_count>fmt.max_squad_size then
    raise exception 'A five-match national tie requires 4 to % nominated players.',fmt.max_squad_size;
  end if;
  if v_count<>v_distinct then raise exception 'Squad players must be unique.'; end if;

  foreach v_player in array p_player_ids loop
    if not exists(
      select 1
      from public.national_team_callups c
      where c.fixture_id=f.id
        and c.association_id=v_assoc
        and c.player_id=v_player
        and c.status='accepted'
    ) then
      raise exception 'Every nominated squad player must have accepted the call-up.';
    end if;
  end loop;

  delete from public.national_team_squad_members
  where fixture_id=f.id and association_id=v_assoc;

  insert into public.national_team_squad_members(
    fixture_id,association_id,player_id,nominated_by_user_id,nominated_game_day
  )
  select f.id,v_assoc,x,v_uid,v_day
  from unnest(p_player_ids) x;

  return jsonb_build_object('status','saved','association_id',v_assoc,'squad_size',v_count);
end;
$$;

create or replace function public.save_national_team_lineup_v1(
  p_fixture_id uuid,
  p_s1 uuid,
  p_s2 uuid,
  p_d1a uuid,
  p_d1b uuid,
  p_s3 uuid,
  p_s4 uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  f public.national_team_fixtures%rowtype;
  l public.national_team_lineups%rowtype;
  v_now bigint:=public.current_game_second_v1();
  v_singles uuid[];
  v_all uuid[];
  v_player uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found.'; end if;
  if v_now>f.lineup_deadline_game_second then raise exception 'Lineup deadline has passed.'; end if;

  v_assoc:=public.national_fixture_association_for_captain_v1(p_fixture_id,v_uid);
  if v_assoc is null then raise exception 'Only the elected captain may submit the lineup.'; end if;

  v_singles:=array[p_s1,p_s2,p_s3,p_s4];
  v_all:=array[p_s1,p_s2,p_d1a,p_d1b,p_s3,p_s4];

  if exists(select 1 from unnest(v_all) x where x is null) then
    raise exception 'All lineup slots are required.';
  end if;
  if (select count(distinct x) from unnest(v_singles) x)<>4 then
    raise exception 'Each player may play at most one singles match in a national tie.';
  end if;
  if p_d1a=p_d1b then raise exception 'Doubles requires two different players.'; end if;

  foreach v_player in array v_all loop
    if not exists(
      select 1
      from public.national_team_squad_members s
      where s.fixture_id=f.id
        and s.association_id=v_assoc
        and s.player_id=v_player
    ) then
      raise exception 'Every lineup player must belong to the nominated squad.';
    end if;
  end loop;

  insert into public.national_team_lineups(
    fixture_id,association_id,status,submitted_by_user_id
  )
  values(f.id,v_assoc,'draft',v_uid)
  on conflict(fixture_id,association_id) do update
  set submitted_by_user_id=excluded.submitted_by_user_id,
      updated_at=now()
  where public.national_team_lineups.status='draft'
  returning * into l;

  if l.id is null then
    raise exception 'A locked lineup can no longer be edited.';
  end if;

  delete from public.national_team_lineup_slots where lineup_id=l.id;

  insert into public.national_team_lineup_slots(lineup_id,slot_code,discipline,player_id)
  values
    (l.id,'S1','singles',p_s1),
    (l.id,'S2','singles',p_s2),
    (l.id,'D1A','doubles',p_d1a),
    (l.id,'D1B','doubles',p_d1b),
    (l.id,'S3','singles',p_s3),
    (l.id,'S4','singles',p_s4);

  update public.national_team_fixtures
  set status=case when status='announced' then 'lineups_pending' else status end,
      updated_at=now()
  where id=f.id;

  return jsonb_build_object('status','saved','lineup_id',l.id,'association_id',v_assoc);
end;
$$;

create or replace function public.lock_national_team_lineup_v1(
  p_fixture_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
  f public.national_team_fixtures%rowtype;
  l public.national_team_lineups%rowtype;
  v_now bigint:=public.current_game_second_v1();
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found then raise exception 'Fixture not found.'; end if;
  if v_now>f.lineup_deadline_game_second then raise exception 'Lineup deadline has passed.'; end if;

  v_assoc:=public.national_fixture_association_for_captain_v1(p_fixture_id,v_uid);
  if v_assoc is null then raise exception 'Only the elected captain may lock the lineup.'; end if;

  select * into l
  from public.national_team_lineups
  where fixture_id=f.id and association_id=v_assoc
  for update;

  if l.id is null then raise exception 'Save a complete lineup before locking it.'; end if;
  if (select count(*) from public.national_team_lineup_slots where lineup_id=l.id)<>6 then
    raise exception 'A complete six-slot lineup is required.';
  end if;

  update public.national_team_lineups
  set status='locked',locked_at_game_second=v_now,updated_at=now()
  where id=l.id and status='draft';

  if (
    select count(*)
    from public.national_team_lineups
    where fixture_id=f.id and status in ('locked','auto_locked')
  )=2 then
    perform public.reveal_national_team_lineups_v1(f.id);
  end if;

  return jsonb_build_object('status','locked','lineup_id',l.id);
end;
$$;

create or replace function public.autofill_national_team_lineup_v1(
  p_fixture_id uuid,
  p_association_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  ids uuid[];
  v_lineup uuid;
  v_now bigint:=public.current_game_second_v1();
begin
  select array_agg(player_id order by rank_position nulls last, player_id)
  into ids
  from (
    select s.player_id,
           public.get_player_world_rank_position_v1(s.player_id) rank_position
    from public.national_team_squad_members s
    where s.fixture_id=p_fixture_id
      and s.association_id=p_association_id
    order by public.get_player_world_rank_position_v1(s.player_id) nulls last,s.player_id
    limit 5
  ) q;

  if coalesce(array_length(ids,1),0)<4 then return null; end if;

  insert into public.national_team_lineups(
    fixture_id,association_id,status,submitted_by_user_id,locked_at_game_second
  )
  values(p_fixture_id,p_association_id,'auto_locked',null,v_now)
  on conflict(fixture_id,association_id) do update
  set status='auto_locked',
      submitted_by_user_id=null,
      locked_at_game_second=v_now,
      updated_at=now()
  returning id into v_lineup;

  delete from public.national_team_lineup_slots where lineup_id=v_lineup;

  insert into public.national_team_lineup_slots(lineup_id,slot_code,discipline,player_id)
  values
    (v_lineup,'S1','singles',ids[1]),
    (v_lineup,'S2','singles',ids[2]),
    (v_lineup,'D1A','doubles',ids[1]),
    (v_lineup,'D1B','doubles',ids[2]),
    (v_lineup,'S3','singles',ids[3]),
    (v_lineup,'S4','singles',ids[4]);

  return v_lineup;
end;
$$;

create or replace function public.finalize_national_fixture_forfeit_v1(
  p_fixture_id uuid,
  p_home_ready boolean,
  p_away_ready boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  f public.national_team_fixtures%rowtype;
  v_winner uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
begin
  select * into f from public.national_team_fixtures where id=p_fixture_id for update;
  if not found or f.status in ('completed','cancelled','forfeit') then return; end if;

  if p_home_ready and not p_away_ready then v_winner:=f.home_association_id;
  elsif p_away_ready and not p_home_ready then v_winner:=f.away_association_id;
  else v_winner:=null;
  end if;

  update public.national_team_fixtures
  set status=case when v_winner is null then 'cancelled' else 'forfeit' end,
      winner_association_id=v_winner,
      home_match_wins=case when v_winner=f.home_association_id then 3 else 0 end,
      away_match_wins=case when v_winner=f.away_association_id then 3 else 0 end,
      completion_reason=case when v_winner is null then 'both_teams_incomplete' else 'incomplete_squad_or_lineup' end,
      completed_game_day=v_day,
      updated_at=now()
  where id=f.id;
end;
$$;

create or replace function public.process_national_team_deadlines_v1()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_day integer:=public.national_team_current_abs_day_v1();
  v_now bigint:=public.current_game_second_v1();
  w record;
  f record;
  v_home_ready boolean;
  v_away_ready boolean;
  v_announced integer:=0;
  v_lineups integer:=0;
begin
  perform public.ensure_national_team_windows_v1((v_day/366)+1);
  perform public.ensure_national_team_windows_v1((v_day/366)+2);

  for w in
    select *
    from public.national_team_windows
    where status in ('planned','announced','in_progress')
  loop
    if w.status='planned' and v_day>=w.announcement_absolute_day then
      update public.national_team_windows set status='announced',updated_at=now() where id=w.id;
      perform public.schedule_national_window_pairings_v1(w.id);
      v_announced:=v_announced+1;
    elsif w.status='announced' and v_day>=w.start_absolute_day then
      update public.national_team_windows set status='in_progress',updated_at=now() where id=w.id;
    elsif w.status='in_progress' and v_day>w.end_absolute_day then
      update public.national_team_windows set status='completed',updated_at=now() where id=w.id;
    end if;
  end loop;

  update public.national_team_callups c
  set status='expired',updated_at=now()
  where c.status='pending'
    and v_day>c.response_deadline_absolute_day;

  for f in
    select *
    from public.national_team_fixtures
    where status in ('planned','announced','lineups_pending')
  loop
    if f.status='planned' and exists(
      select 1 from public.national_team_windows w
      where w.id=f.window_id and v_day>=w.announcement_absolute_day
    ) then
      update public.national_team_fixtures
      set status='announced',announced_game_day=v_day,updated_at=now()
      where id=f.id;
    end if;

    if v_now>=f.lineup_deadline_game_second then
      if not exists(
        select 1 from public.national_team_lineups
        where fixture_id=f.id and association_id=f.home_association_id
          and status in ('locked','auto_locked')
      ) then
        perform public.autofill_national_team_lineup_v1(f.id,f.home_association_id);
      end if;

      if not exists(
        select 1 from public.national_team_lineups
        where fixture_id=f.id and association_id=f.away_association_id
          and status in ('locked','auto_locked')
      ) then
        perform public.autofill_national_team_lineup_v1(f.id,f.away_association_id);
      end if;

      v_home_ready:=exists(
        select 1 from public.national_team_lineups
        where fixture_id=f.id and association_id=f.home_association_id
          and status in ('locked','auto_locked')
      );
      v_away_ready:=exists(
        select 1 from public.national_team_lineups
        where fixture_id=f.id and association_id=f.away_association_id
          and status in ('locked','auto_locked')
      );

      if v_home_ready and v_away_ready then
        perform public.reveal_national_team_lineups_v1(f.id);
        v_lineups:=v_lineups+1;
      else
        perform public.finalize_national_fixture_forfeit_v1(f.id,v_home_ready,v_away_ready);
      end if;
    end if;
  end loop;

  for f in
    select a.id
    from public.national_associations a
    where a.status in ('active','renewal_required')
  loop
    perform public.ensure_national_association_season_grant_v1(f.id,(v_day/366)+1);
  end loop;

  return jsonb_build_object(
    'game_day',v_day,
    'windows_announced',v_announced,
    'lineups_processed',v_lineups
  );
end;
$$;

create or replace function public.send_national_team_chat_message_v1(
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_assoc uuid;
  v_id uuid;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_message text:=btrim(coalesce(p_message,''));
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  if char_length(v_message)<1 or char_length(v_message)>1000 then
    raise exception 'Message must contain between 1 and 1000 characters.';
  end if;

  select m.player_id,m.association_id
  into v_player,v_assoc
  from public.national_association_memberships m
  where m.user_id=v_uid and m.status='active'
  order by m.joined_game_day desc
  limit 1;

  if v_player is null then raise exception 'National association membership required.'; end if;

  insert into public.national_team_chat_messages(
    association_id,player_id,user_id,game_absolute_day,message
  )
  values(v_assoc,v_player,v_uid,v_day,v_message)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.get_my_national_team_chat_v1(
  p_limit integer default 100
)
returns table(
  message_id uuid,
  player_id uuid,
  player_name text,
  game_absolute_day integer,
  message text,
  created_at timestamptz,
  is_mine boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select association_id into v_assoc
  from public.national_association_memberships
  where user_id=v_uid and status='active'
  order by joined_game_day desc
  limit 1;

  if v_assoc is null then return; end if;

  return query
  select
    c.id,
    c.player_id,
    trim(p.first_name||' '||p.last_name),
    c.game_absolute_day,
    c.message,
    c.created_at,
    c.user_id=v_uid
  from public.national_team_chat_messages c
  join public.players p on p.id=c.player_id
  where c.association_id=v_assoc
  order by c.created_at desc
  limit greatest(1,least(coalesce(p_limit,100),200));
end;
$$;

create or replace function public.get_my_national_team_competition_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  v_assoc public.national_associations%rowtype;
  v_membership public.national_association_memberships%rowtype;
  v_day integer:=public.national_team_current_abs_day_v1();
  v_season integer:=(public.national_team_current_abs_day_v1()/366)+1;
  v_is_captain boolean:=false;
  v_windows jsonb;
  v_fixtures jsonb;
  v_callups jsonb;
  v_members jsonb;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human'
  limit 1;

  if v_player.id is null then
    return jsonb_build_object('available',false,'reason','player_required');
  end if;

  select * into v_assoc
  from public.national_associations
  where world=v_player.world and country_code=v_player.country_code
  limit 1;

  select * into v_membership
  from public.national_association_memberships
  where player_id=v_player.id and association_id=v_assoc.id and status='active'
  limit 1;

  v_is_captain:=exists(
    select 1
    from public.national_captain_terms t
    where t.association_id=v_assoc.id
      and t.user_id=v_uid
      and t.status in ('active','scheduled')
      and t.season_number in (v_season,v_season+1)
  );

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',w.id,
      'season_number',w.season_number,
      'window_code',w.window_code,
      'label',w.label,
      'season_week',w.season_week,
      'start_absolute_day',w.start_absolute_day,
      'end_absolute_day',w.end_absolute_day,
      'announcement_absolute_day',w.announcement_absolute_day,
      'callup_deadline_absolute_day',w.callup_deadline_absolute_day,
      'squad_deadline_absolute_day',w.squad_deadline_absolute_day,
      'status',w.status
    )
    order by w.start_absolute_day
  ),'[]'::jsonb)
  into v_windows
  from public.national_team_windows w
  where w.world=v_player.world
    and w.season_number in (v_season,v_season+1)
    and w.status<>'cancelled';

  select coalesce(jsonb_agg(item order by tie_start_absolute_day),'[]'::jsonb)
  into v_fixtures
  from (
    select
      f.tie_start_absolute_day,
      jsonb_build_object(
        'id',f.id,
        'window_id',f.window_id,
        'status',f.status,
        'home_association_id',f.home_association_id,
        'home_name',ha.name,
        'home_country_code',ha.country_code,
        'away_association_id',f.away_association_id,
        'away_name',aa.name,
        'away_country_code',aa.country_code,
        'opponent_association_id',case when f.home_association_id=v_assoc.id then f.away_association_id else f.home_association_id end,
        'opponent_name',case when f.home_association_id=v_assoc.id then aa.name else ha.name end,
        'opponent_country_code',case when f.home_association_id=v_assoc.id then aa.country_code else ha.country_code end,
        'host_city',f.host_city,
        'host_country_code',f.host_country_code,
        'surface',f.surface,
        'environment',f.environment,
        'central_event_key',f.central_event_key,
        'tie_start_absolute_day',f.tie_start_absolute_day,
        'tie_end_absolute_day',f.tie_end_absolute_day,
        'response_deadline_absolute_day',f.response_deadline_absolute_day,
        'squad_deadline_absolute_day',f.squad_deadline_absolute_day,
        'lineup_deadline_game_second',f.lineup_deadline_game_second,
        'expected_appearance_fee_usd',f.expected_appearance_fee_usd,
        'home_match_wins',f.home_match_wins,
        'away_match_wins',f.away_match_wins,
        'winner_association_id',f.winner_association_id,
        'is_captain_fixture',public.national_fixture_association_for_captain_v1(f.id,v_uid)=v_assoc.id,
        'my_callup',(
          select jsonb_build_object(
            'id',c.id,
            'status',c.status,
            'expected_compensation_usd',c.expected_compensation_usd,
            'response_deadline_absolute_day',c.response_deadline_absolute_day
          )
          from public.national_team_callups c
          where c.fixture_id=f.id and c.player_id=v_player.id
          limit 1
        ),
        'my_squad_member',exists(
          select 1 from public.national_team_squad_members s
          where s.fixture_id=f.id and s.player_id=v_player.id
        ),
        'squad',coalesce((
          select jsonb_agg(jsonb_build_object(
            'player_id',s.player_id,
            'first_name',p.first_name,
            'last_name',p.last_name
          ) order by p.last_name,p.first_name)
          from public.national_team_squad_members s
          join public.players p on p.id=s.player_id
          where s.fixture_id=f.id and s.association_id=v_assoc.id
        ),'[]'::jsonb),
        'our_lineup_status',(
          select l.status from public.national_team_lineups l
          where l.fixture_id=f.id and l.association_id=v_assoc.id
        ),
        'lineups_revealed',(
          select count(*)=2
          from public.national_team_lineups l
          where l.fixture_id=f.id and l.revealed_at_game_second is not null
        ),
        'our_lineup',case
          when exists(
            select 1 from public.national_team_lineups l
            where l.fixture_id=f.id and l.association_id=v_assoc.id
          )
          then (
            select jsonb_object_agg(ls.slot_code,ls.player_id)
            from public.national_team_lineups l
            join public.national_team_lineup_slots ls on ls.lineup_id=l.id
            where l.fixture_id=f.id and l.association_id=v_assoc.id
          )
          else '{}'::jsonb
        end,
        'opponent_lineup',case
          when (
            select count(*)=2
            from public.national_team_lineups l
            where l.fixture_id=f.id and l.revealed_at_game_second is not null
          )
          then coalesce((
            select jsonb_object_agg(ls.slot_code,ls.player_id)
            from public.national_team_lineups l
            join public.national_team_lineup_slots ls on ls.lineup_id=l.id
            where l.fixture_id=f.id
              and l.association_id<>v_assoc.id
          ),'{}'::jsonb)
          else '{}'::jsonb
        end,
        'matches',coalesce((
          select jsonb_agg(jsonb_build_object(
            'slot_id',ms.id,
            'slot_order',ms.slot_order,
            'discipline',ms.discipline,
            'status',ms.status,
            'home_player1_id',ms.home_player1_id,
            'home_player2_id',ms.home_player2_id,
            'away_player1_id',ms.away_player1_id,
            'away_player2_id',ms.away_player2_id,
            'engine_match_id',ms.engine_match_id,
            'engine_doubles_match_id',ms.engine_doubles_match_id,
            'winner_association_id',ms.winner_association_id
          ) order by ms.slot_order)
          from public.national_team_fixture_match_slots ms
          where ms.fixture_id=f.id
        ),'[]'::jsonb)
      ) item
    from public.national_team_fixtures f
    join public.national_associations ha on ha.id=f.home_association_id
    join public.national_associations aa on aa.id=f.away_association_id
    join public.national_team_windows w on w.id=f.window_id
    where v_assoc.id in (f.home_association_id,f.away_association_id)
      and w.season_number in (v_season,v_season+1)
      and f.status<>'planned'
  ) q;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,
    'fixture_id',c.fixture_id,
    'status',c.status,
    'response_deadline_absolute_day',c.response_deadline_absolute_day,
    'expected_compensation_usd',c.expected_compensation_usd
  ) order by c.created_at desc),'[]'::jsonb)
  into v_callups
  from public.national_team_callups c
  where c.player_id=v_player.id
    and c.status in ('pending','accepted');

  select coalesce(jsonb_agg(jsonb_build_object(
    'player_id',p.id,
    'first_name',p.first_name,
    'last_name',p.last_name,
    'rank_position',public.get_player_world_rank_position_v1(p.id),
    'callups',coalesce((
      select jsonb_agg(jsonb_build_object(
        'fixture_id',c.fixture_id,
        'status',c.status
      ))
      from public.national_team_callups c
      where c.player_id=p.id
        and c.association_id=v_assoc.id
        and c.status in ('pending','accepted')
    ),'[]'::jsonb)
  ) order by public.get_player_world_rank_position_v1(p.id) nulls last,p.last_name,p.first_name),'[]'::jsonb)
  into v_members
  from public.national_association_memberships m
  join public.players p on p.id=m.player_id
  where m.association_id=v_assoc.id
    and m.status='active';

  return jsonb_build_object(
    'available',true,
    'game_day',v_day,
    'season_number',v_season,
    'association_id',v_assoc.id,
    'association_name',v_assoc.name,
    'country_code',v_assoc.country_code,
    'world',v_assoc.world,
    'is_captain',v_is_captain,
    'is_member',v_membership.id is not null,
    'windows',v_windows,
    'fixtures',v_fixtures,
    'my_callups',v_callups,
    'eligible_members',v_members,
    'treasury',(
      select jsonb_build_object(
        'cash_balance_usd',t.cash_balance_usd,
        'lifetime_cash_income_usd',t.lifetime_cash_income_usd,
        'lifetime_cash_spent_usd',t.lifetime_cash_spent_usd
      )
      from public.national_association_treasuries t
      where t.association_id=v_assoc.id
    )
  );
end;
$$;

create or replace function public.get_national_team_calendar_windows_v1(
  p_season_number integer,
  p_world text
)
returns table(
  window_id uuid,
  window_code text,
  label text,
  season_week smallint,
  start_absolute_day integer,
  end_absolute_day integer,
  announcement_absolute_day integer,
  status text,
  my_fixture_id uuid,
  opponent_name text,
  opponent_country_code text,
  host_city text,
  host_country_code text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid:=auth.uid();
  v_assoc uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select a.id into v_assoc
  from public.players p
  join public.national_associations a
    on a.world=p.world and a.country_code=p.country_code
  where p.owner_user_id=v_uid
  limit 1;

  return query
  select
    w.id,w.window_code,w.label,w.season_week,w.start_absolute_day,w.end_absolute_day,
    w.announcement_absolute_day,w.status,
    f.id,
    case when f.home_association_id=v_assoc then aa.name else ha.name end,
    case when f.home_association_id=v_assoc then aa.country_code else ha.country_code end,
    f.host_city,
    f.host_country_code
  from public.national_team_windows w
  left join public.national_team_fixtures f
    on f.window_id=w.id
   and v_assoc in (f.home_association_id,f.away_association_id)
   and f.status<>'planned'
  left join public.national_associations ha on ha.id=f.home_association_id
  left join public.national_associations aa on aa.id=f.away_association_id
  where w.season_number=p_season_number
    and w.world=p_world
    and w.status<>'cancelled'
  order by w.start_absolute_day,f.tie_start_absolute_day;
end;
$$;

revoke execute on function public.post_national_association_finance_transaction_v1(uuid,bigint,text,text,text,text,text,jsonb,integer) from anon,authenticated;
revoke execute on function public.ensure_national_association_season_grant_v1(uuid,integer) from anon,authenticated;
revoke execute on function public.ensure_national_team_windows_v1(integer) from anon,authenticated;
revoke execute on function public.is_national_team_engine_competition_v1(uuid) from anon,authenticated;
revoke execute on function public.national_fixture_association_for_captain_v1(uuid,uuid) from anon,authenticated;
revoke execute on function public.create_national_team_fixture_v1(uuid,uuid,uuid,uuid,uuid,text,text,text,double precision,double precision,text,text,integer,text) from anon,authenticated;
revoke execute on function public.schedule_national_window_pairings_v1(uuid) from anon,authenticated;
revoke execute on function public.check_player_national_window_availability_v1(uuid,uuid) from anon,authenticated;
revoke execute on function public.send_national_team_callup_v1(uuid,uuid) from anon;
revoke execute on function public.respond_national_team_callup_v1(uuid,boolean) from anon;
revoke execute on function public.set_national_team_squad_v1(uuid,uuid[]) from anon;
revoke execute on function public.save_national_team_lineup_v1(uuid,uuid,uuid,uuid,uuid,uuid,uuid) from anon;
revoke execute on function public.lock_national_team_lineup_v1(uuid) from anon;
revoke execute on function public.autofill_national_team_lineup_v1(uuid,uuid) from anon,authenticated;
revoke execute on function public.finalize_national_fixture_forfeit_v1(uuid,boolean,boolean) from anon,authenticated;
revoke execute on function public.process_national_team_deadlines_v1() from anon,authenticated;
revoke execute on function public.send_national_team_chat_message_v1(text) from anon;
revoke execute on function public.get_my_national_team_chat_v1(integer) from anon;
revoke execute on function public.get_my_national_team_competition_v1() from anon;
revoke execute on function public.get_national_team_calendar_windows_v1(integer,text) from anon;

grant execute on function public.send_national_team_callup_v1(uuid,uuid) to authenticated;
grant execute on function public.respond_national_team_callup_v1(uuid,boolean) to authenticated;
grant execute on function public.set_national_team_squad_v1(uuid,uuid[]) to authenticated;
grant execute on function public.save_national_team_lineup_v1(uuid,uuid,uuid,uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.lock_national_team_lineup_v1(uuid) to authenticated;
grant execute on function public.send_national_team_chat_message_v1(text) to authenticated;
grant execute on function public.get_my_national_team_chat_v1(integer) to authenticated;
grant execute on function public.get_my_national_team_competition_v1() to authenticated;
grant execute on function public.get_national_team_calendar_windows_v1(integer,text) to authenticated;
