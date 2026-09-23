-- Doubles Ticket 1: core doubles competition, rankings, scheduling, fatigue,
-- equipment wear, match economy and withdrawal for ATP/WTA.

create table if not exists public.tournament_doubles_settings (
  tournament_series_id uuid primary key references public.tournament_series(id) on delete cascade,
  is_enabled boolean not null default false,
  draw_size smallint not null default 16 check (draw_size in (4,8,16,32,64)),
  minimum_teams smallint not null default 4 check (minimum_teams between 2 and 64),
  prize_money_multiplier numeric(5,3) not null default 0.350 check (prize_money_multiplier > 0 and prize_money_multiplier <= 1),
  fatigue_multiplier numeric(5,3) not null default 0.720 check (fatigue_multiplier > 0 and fatigue_multiplier <= 1),
  equipment_wear_multiplier numeric(5,3) not null default 0.700 check (equipment_wear_multiplier > 0 and equipment_wear_multiplier <= 1),
  minimum_recovery_minutes integer not null default 180 check (minimum_recovery_minutes between 30 and 720),
  estimated_match_duration_minutes smallint not null default 105 check (estimated_match_duration_minutes between 45 and 240),
  updated_at timestamptz not null default now()
);

insert into public.tournament_doubles_settings(
  tournament_series_id,is_enabled,draw_size,minimum_teams,prize_money_multiplier,
  fatigue_multiplier,equipment_wear_multiplier,minimum_recovery_minutes,estimated_match_duration_minutes
)
select ts.id,true,
  case ts.category_code when 'grand_slam_2000' then 64 when 'masters_1000' then 32 else 16 end::smallint,
  4,
  case ts.category_code when 'grand_slam_2000' then 0.350 when 'masters_1000' then 0.400 when 'tour_500' then 0.400 when 'tour_250' then 0.350 else 0.300 end,
  0.720,0.700,180,105
from public.tournament_series ts
where ts.category_code in ('grand_slam_2000','masters_1000','tour_500','tour_250','challenger_125','challenger_100')
on conflict(tournament_series_id) do update set
  is_enabled=excluded.is_enabled,draw_size=excluded.draw_size,minimum_teams=excluded.minimum_teams,
  prize_money_multiplier=excluded.prize_money_multiplier,fatigue_multiplier=excluded.fatigue_multiplier,
  equipment_wear_multiplier=excluded.equipment_wear_multiplier,minimum_recovery_minutes=excluded.minimum_recovery_minutes,
  estimated_match_duration_minutes=excluded.estimated_match_duration_minutes,updated_at=now();

create table if not exists public.player_calendar_commitments (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  source_type text not null check (source_type in ('national_team','other')),
  source_id uuid,
  competition_id uuid references public.tournament_world_competitions(id) on delete cascade,
  event_key text,
  starts_absolute_day integer not null,
  ends_absolute_day integer not null check (ends_absolute_day >= starts_absolute_day),
  location_key text,
  status text not null default 'committed' check (status in ('committed','released','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists player_calendar_commitments_player_window_idx
  on public.player_calendar_commitments(player_id,starts_absolute_day,ends_absolute_day,status);

create table if not exists public.tournament_doubles_teams (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  player1_id uuid not null references public.players(id) on delete cascade,
  player2_id uuid not null references public.players(id) on delete cascade,
  status text not null default 'confirmed' check (status in ('confirmed','active','alternate','eliminated','champion','withdrawn')),
  entry_source text not null default 'partner',
  combined_ranking_points_snapshot integer not null default 0,
  seed_number smallint,
  bracket_slot smallint,
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (player1_id <> player2_id),
  unique (competition_id,player1_id,player2_id)
);
create index if not exists tournament_doubles_teams_player1_idx on public.tournament_doubles_teams(player1_id,competition_id,status);
create index if not exists tournament_doubles_teams_player2_idx on public.tournament_doubles_teams(player2_id,competition_id,status);

create table if not exists public.tournament_doubles_draw_publications (
  competition_id uuid primary key references public.tournament_world_competitions(id) on delete cascade,
  bracket_size smallint not null check (bracket_size in (4,8,16,32,64)),
  team_count integer not null check (team_count >= 2),
  published_at timestamptz not null default now()
);

create table if not exists public.tournament_doubles_matches (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  round_number smallint not null check (round_number > 0),
  round_label text not null,
  match_number smallint not null check (match_number > 0),
  bracket_size smallint not null check (bracket_size in (4,8,16,32,64)),
  scheduled_season_week integer not null,
  scheduled_day smallint not null check (scheduled_day between 1 and 7),
  scheduled_start_minute smallint,
  court_number smallint,
  estimated_duration_minutes smallint not null default 105,
  actual_duration_minutes smallint,
  sets_played smallint,
  games_played integer,
  team1_id uuid references public.tournament_doubles_teams(id) on delete set null,
  team2_id uuid references public.tournament_doubles_teams(id) on delete set null,
  winner_team_id uuid references public.tournament_doubles_teams(id) on delete set null,
  status text not null default 'scheduled' check (status in ('scheduled','in_progress','bye','completed','walkover','cancelled')),
  schedule_reason text not null default 'standard',
  completion_reason text,
  simulation_metadata jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id,round_number,match_number),
  check (team1_id is null or team2_id is null or team1_id <> team2_id)
);
create index if not exists tournament_doubles_matches_schedule_idx on public.tournament_doubles_matches(competition_id,scheduled_season_week,scheduled_day,scheduled_start_minute,status);
create index if not exists tournament_doubles_matches_team1_idx on public.tournament_doubles_matches(team1_id,status);
create index if not exists tournament_doubles_matches_team2_idx on public.tournament_doubles_matches(team2_id,status);

create table if not exists public.tournament_doubles_ranking_point_rules (
  world text not null check (world in ('ATP','WTA')),
  category_code text not null references public.tournament_categories(code) on delete cascade,
  stage_code text not null,
  stage_label text not null,
  min_draw_size smallint not null check (min_draw_size in (2,4,8,16,32,64)),
  points integer not null check (points >= 0),
  sort_order integer not null,
  primary key(world,category_code,stage_code)
);

with worlds(world) as (values ('ATP'::text),('WTA'::text)),
rules(category_code,stage_code,stage_label,min_draw_size,points,sort_order) as (
  values
  ('grand_slam_2000','winner','Winner',2,2000,10),('grand_slam_2000','runner_up','Finalist',2,1200,20),('grand_slam_2000','semifinal','Semifinal',4,720,30),('grand_slam_2000','quarterfinal','Quarterfinal',8,360,40),('grand_slam_2000','round_16','Round of 16',16,180,50),('grand_slam_2000','round_32','Round of 32',32,90,60),('grand_slam_2000','round_64','Round of 64',64,45,70),
  ('masters_1000','winner','Winner',2,1000,10),('masters_1000','runner_up','Finalist',2,600,20),('masters_1000','semifinal','Semifinal',4,360,30),('masters_1000','quarterfinal','Quarterfinal',8,180,40),('masters_1000','round_16','Round of 16',16,90,50),('masters_1000','round_32','Round of 32',32,45,60),
  ('tour_500','winner','Winner',2,500,10),('tour_500','runner_up','Finalist',2,300,20),('tour_500','semifinal','Semifinal',4,180,30),('tour_500','quarterfinal','Quarterfinal',8,90,40),('tour_500','round_16','Round of 16',16,45,50),
  ('tour_250','winner','Winner',2,250,10),('tour_250','runner_up','Finalist',2,150,20),('tour_250','semifinal','Semifinal',4,90,30),('tour_250','quarterfinal','Quarterfinal',8,45,40),('tour_250','round_16','Round of 16',16,20,50),
  ('challenger_125','winner','Winner',2,125,10),('challenger_125','runner_up','Finalist',2,75,20),('challenger_125','semifinal','Semifinal',4,45,30),('challenger_125','quarterfinal','Quarterfinal',8,25,40),('challenger_125','round_16','Round of 16',16,12,50),
  ('challenger_100','winner','Winner',2,100,10),('challenger_100','runner_up','Finalist',2,60,20),('challenger_100','semifinal','Semifinal',4,36,30),('challenger_100','quarterfinal','Quarterfinal',8,20,40),('challenger_100','round_16','Round of 16',16,10,50)
)
insert into public.tournament_doubles_ranking_point_rules(world,category_code,stage_code,stage_label,min_draw_size,points,sort_order)
select w.world,r.category_code,r.stage_code,r.stage_label,r.min_draw_size,r.points,r.sort_order
from worlds w cross join rules r
on conflict(world,category_code,stage_code) do update set
  stage_label=excluded.stage_label,min_draw_size=excluded.min_draw_size,points=excluded.points,sort_order=excluded.sort_order;

create table if not exists public.tournament_doubles_prize_payouts (
  tournament_series_id uuid not null references public.tournament_series(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  stage_code text not null,
  stage_label text not null,
  team_prize_usd bigint not null check (team_prize_usd >= 0),
  sort_order integer not null,
  primary key(tournament_series_id,world,stage_code)
);

insert into public.tournament_doubles_prize_payouts(tournament_series_id,world,stage_code,stage_label,team_prize_usd,sort_order)
select ts.id,cw.world,p.stage_code,p.stage_label,
       greatest(0,(round((p.payout_per_player_usd::numeric * ds.prize_money_multiplier)/100.0)*100)::bigint),
       p.sort_order
from public.tournament_series ts
join public.tournament_doubles_settings ds on ds.tournament_series_id=ts.id and ds.is_enabled
join public.tournament_prize_payouts p on p.tournament_series_id=ts.id and p.draw_type='main_draw'
join (select distinct e.tournament_series_id,wc.world from public.tournament_editions e join public.tournament_world_competitions wc on wc.tournament_edition_id=e.id) cw
  on cw.tournament_series_id=ts.id
join public.tournament_doubles_ranking_point_rules rr on rr.world=cw.world and rr.category_code=ts.category_code and rr.stage_code=p.stage_code
where rr.min_draw_size <= ds.draw_size
on conflict(tournament_series_id,world,stage_code) do update set
  stage_label=excluded.stage_label,team_prize_usd=excluded.team_prize_usd,sort_order=excluded.sort_order;

create table if not exists public.player_doubles_tournament_results (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  team_id uuid not null references public.tournament_doubles_teams(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  result_code text not null,
  result_stage_code text not null,
  ranking_points_earned integer not null default 0 check (ranking_points_earned >= 0),
  team_prize_money_earned bigint not null default 0 check (team_prize_money_earned >= 0),
  player_prize_money_earned bigint not null default 0 check (player_prize_money_earned >= 0),
  ranking_publish_status text not null default 'pending' check (ranking_publish_status in ('pending','published')),
  ranking_publish_absolute_day integer,
  ranking_published_at timestamptz,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id,competition_id)
);

create table if not exists public.player_doubles_rankings (
  player_id uuid primary key references public.players(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  ranking_points integer not null default 0,
  seed_rating integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.player_doubles_rankings(player_id,world,ranking_points,seed_rating)
select p.id,p.world,0,coalesce(r.seed_rating,0) from public.players p left join public.player_rankings r on r.player_id=p.id
on conflict(player_id) do nothing;

create table if not exists public.player_doubles_ranking_contributions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  source_result_id uuid not null unique references public.player_doubles_tournament_results(id) on delete cascade,
  competition_id uuid not null references public.tournament_world_competitions(id) on delete cascade,
  tournament_series_id uuid not null references public.tournament_series(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  season_number integer not null,
  ranking_points integer not null check (ranking_points >= 0),
  awarded_absolute_day integer not null,
  expires_absolute_day integer not null,
  published_at timestamptz,
  is_active boolean not null default true,
  deactivated_absolute_day integer,
  deactivated_at timestamptz,
  replaced_by_result_id uuid references public.player_doubles_tournament_results(id) on delete set null,
  replaced_by_competition_id uuid references public.tournament_world_competitions(id) on delete set null,
  replacement_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists player_doubles_ranking_contributions_active_idx on public.player_doubles_ranking_contributions(player_id,is_active,expires_absolute_day);

create table if not exists public.player_doubles_ranking_snapshots (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  game_absolute_day integer not null,
  ranking_position integer not null,
  ranking_points integer not null,
  created_at timestamptz not null default now(),
  unique(player_id,game_absolute_day)
);
create index if not exists player_doubles_ranking_snapshots_world_day_idx on public.player_doubles_ranking_snapshots(world,game_absolute_day,ranking_position);

create table if not exists public.doubles_ranking_defence_cycles (
  competition_id uuid primary key references public.tournament_world_competitions(id) on delete cascade,
  tournament_series_id uuid not null references public.tournament_series(id) on delete cascade,
  world text not null check (world in ('ATP','WTA')),
  season_number integer not null,
  scheduled_publish_absolute_day integer not null,
  processed_absolute_day integer not null,
  published_results integer not null default 0,
  expired_contributions integer not null default 0,
  activated_contributions integer not null default 0,
  processed_at timestamptz not null default now()
);

create table if not exists public.doubles_ranking_publication_runs (
  game_absolute_day integer primary key,
  published_results integer not null default 0,
  defence_cycles_processed integer not null default 0,
  contributions_expired integer not null default 0,
  contributions_activated integer not null default 0,
  processed_at timestamptz not null default now()
);

create table if not exists public.player_doubles_match_condition_events (
  id uuid primary key default gen_random_uuid(),
  doubles_match_id uuid not null references public.tournament_doubles_matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  outcome text not null check (outcome in ('win','loss')),
  surface text not null,
  estimated_match_minutes integer not null,
  sets_played smallint not null,
  games_played integer not null,
  fatigue_before smallint not null,
  fatigue_after smallint not null,
  created_at timestamptz not null default now(),
  unique(doubles_match_id,player_id)
);

create table if not exists public.player_doubles_equipment_wear_events (
  id uuid primary key default gen_random_uuid(),
  doubles_match_id uuid not null references public.tournament_doubles_matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  surface text,
  wear_multiplier numeric(5,3) not null,
  racket_before numeric,
  racket_after numeric,
  shoes_before numeric,
  shoes_after numeric,
  apparel_before numeric,
  apparel_after numeric,
  accessories_before jsonb not null default '{}'::jsonb,
  accessories_after jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(doubles_match_id,player_id)
);