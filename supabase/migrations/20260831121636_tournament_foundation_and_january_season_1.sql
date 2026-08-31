create table public.tournament_categories (
  code text primary key,
  label text not null,
  winner_points integer not null check (winner_points > 0),
  main_draw_capacity integer not null check (main_draw_capacity >= 32),
  qualifying_capacity_max integer not null check (qualifying_capacity_max >= 0),
  default_qualifier_slots integer not null check (default_qualifier_slots >= 0 and default_qualifier_slots < main_draw_capacity),
  sort_order smallint not null unique,
  created_at timestamptz not null default now()
);

insert into public.tournament_categories
  (code, label, winner_points, main_draw_capacity, qualifying_capacity_max, default_qualifier_slots, sort_order)
values
  ('grand_slam_2000', 'Grand Slam 2000', 2000, 128, 128, 16, 1),
  ('masters_1000', 'Masters 1000', 1000, 64, 64, 16, 2),
  ('tour_500', 'Tour 500', 500, 32, 64, 16, 3),
  ('tour_250', 'Tour 250', 250, 32, 64, 16, 4),
  ('challenger_125', 'Challenger 125', 125, 32, 64, 16, 5),
  ('challenger_100', 'Challenger 100', 100, 32, 64, 16, 6),
  ('challenger_75', 'Challenger 75', 75, 32, 64, 8, 7),
  ('challenger_50', 'Challenger 50', 50, 32, 32, 8, 8),
  ('futures_25', 'Futures 25', 25, 32, 32, 8, 9),
  ('futures_15', 'Futures 15', 15, 32, 32, 8, 10);

create table public.tournament_series (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  city text not null,
  country_code text not null references public.countries(code),
  category_code text not null references public.tournament_categories(code),
  surface text not null check (surface in ('hard', 'clay', 'grass')),
  environment text not null check (environment in ('indoor', 'outdoor')),
  latitude double precision,
  longitude double precision,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.tournament_editions (
  id uuid primary key default gen_random_uuid(),
  tournament_series_id uuid not null references public.tournament_series(id) on delete cascade,
  season_number integer not null check (season_number > 0),
  status text not null default 'scheduled' check (status in ('scheduled', 'registration_open', 'registration_closed', 'in_progress', 'completed', 'canceled')),
  created_at timestamptz not null default now(),
  unique (tournament_series_id, season_number)
);

create table public.tournament_schedule_slots (
  id uuid primary key default gen_random_uuid(),
  tournament_edition_id uuid not null references public.tournament_editions(id) on delete cascade,
  calendar_month smallint not null check (calendar_month between 1 and 12),
  month_week smallint not null check (month_week between 1 and 4),
  phase text not null default 'full' check (phase in ('full', 'qualification', 'main_draw')),
  slot_order smallint not null default 1 check (slot_order > 0),
  created_at timestamptz not null default now(),
  unique (tournament_edition_id, calendar_month, month_week, phase)
);

create table public.tournament_world_competitions (
  id uuid primary key default gen_random_uuid(),
  tournament_edition_id uuid not null references public.tournament_editions(id) on delete cascade,
  world text not null check (world in ('ATP', 'WTA')),
  status text not null default 'scheduled' check (status in ('scheduled', 'registration_open', 'registration_closed', 'in_progress', 'completed', 'canceled')),
  created_at timestamptz not null default now(),
  unique (tournament_edition_id, world)
);

create index tournament_editions_season_idx on public.tournament_editions(season_number);
create index tournament_schedule_slots_month_week_idx on public.tournament_schedule_slots(calendar_month, month_week);
create index tournament_world_competitions_world_idx on public.tournament_world_competitions(world);
create index tournament_series_category_idx on public.tournament_series(category_code);

alter table public.tournament_categories enable row level security;
alter table public.tournament_series enable row level security;
alter table public.tournament_editions enable row level security;
alter table public.tournament_schedule_slots enable row level security;
alter table public.tournament_world_competitions enable row level security;

create policy tournament_categories_authenticated_read on public.tournament_categories for select to authenticated using (true);
create policy tournament_series_authenticated_read on public.tournament_series for select to authenticated using (true);
create policy tournament_editions_authenticated_read on public.tournament_editions for select to authenticated using (true);
create policy tournament_schedule_slots_authenticated_read on public.tournament_schedule_slots for select to authenticated using (true);
create policy tournament_world_competitions_authenticated_read on public.tournament_world_competitions for select to authenticated using (true);

grant select on public.tournament_categories to authenticated;
grant select on public.tournament_series to authenticated;
grant select on public.tournament_editions to authenticated;
grant select on public.tournament_schedule_slots to authenticated;
grant select on public.tournament_world_competitions to authenticated;

insert into public.tournament_series (slug, name, city, country_code, category_code, surface, environment) values
  ('brisbane-pacific-open', 'Brisbane Pacific Open', 'Brisbane', 'AU', 'tour_500', 'hard', 'outdoor'),
  ('hong-kong-harbour-open', 'Hong Kong Harbour Open', 'Hong Kong', 'HK', 'tour_250', 'hard', 'outdoor'),
  ('auckland-southern-classic', 'Auckland Southern Classic', 'Auckland', 'NZ', 'tour_250', 'hard', 'outdoor'),
  ('canberra-capital-challenger', 'Canberra Capital Challenger', 'Canberra', 'AU', 'challenger_125', 'hard', 'outdoor'),
  ('bengaluru-city-challenger', 'Bengaluru City Challenger', 'Bengaluru', 'IN', 'challenger_125', 'hard', 'outdoor'),
  ('noumea-pacific-challenger', 'Nouméa Pacific Challenger', 'Nouméa', 'NC', 'challenger_75', 'hard', 'outdoor'),
  ('siam-challenger-i', 'Siam Challenger I', 'Nonthaburi', 'TH', 'challenger_50', 'hard', 'outdoor'),
  ('nottingham-winter-indoor', 'Nottingham Winter Indoor', 'Nottingham', 'GB', 'challenger_50', 'hard', 'indoor'),
  ('cape-summer-challenger', 'Cape Summer Challenger', 'Cape Town', 'ZA', 'challenger_75', 'hard', 'outdoor'),
  ('florida-sunshine-futures', 'Florida Sunshine Futures', 'Orlando', 'US', 'futures_25', 'hard', 'outdoor'),
  ('lima-pacific-challenger', 'Lima Pacific Challenger', 'Lima', 'PE', 'challenger_75', 'clay', 'outdoor'),
  ('southern-cross-grand-championship', 'Southern Cross Grand Championship', 'Melbourne', 'AU', 'grand_slam_2000', 'hard', 'outdoor'),
  ('adelaide-coast-open', 'Adelaide Coast Open', 'Adelaide', 'AU', 'tour_250', 'hard', 'outdoor'),
  ('hobart-island-open', 'Hobart Island Open', 'Hobart', 'AU', 'tour_250', 'hard', 'outdoor'),
  ('siam-challenger-ii', 'Siam Challenger II', 'Nonthaburi', 'TH', 'challenger_75', 'hard', 'outdoor'),
  ('buenos-aires-summer-challenger', 'Buenos Aires Summer Challenger', 'Buenos Aires', 'AR', 'challenger_50', 'clay', 'outdoor'),
  ('glasgow-indoor-challenger', 'Glasgow Indoor Challenger', 'Glasgow', 'GB', 'challenger_50', 'hard', 'indoor'),
  ('carolina-winter-futures', 'Carolina Winter Futures', 'Winston-Salem', 'US', 'futures_25', 'hard', 'indoor'),
  ('mallorca-academy-futures', 'Mallorca Academy Futures', 'Manacor', 'ES', 'futures_15', 'hard', 'outdoor'),
  ('atlas-winter-challenger', 'Atlas Winter Challenger', 'Marrakech', 'MA', 'challenger_75', 'clay', 'outdoor'),
  ('oeiras-atlantic-challenger', 'Oeiras Atlantic Challenger', 'Oeiras', 'PT', 'challenger_100', 'hard', 'indoor'),
  ('itajai-coast-challenger', 'Itajaí Coast Challenger', 'Itajaí', 'BR', 'challenger_75', 'clay', 'outdoor'),
  ('red-sea-challenger', 'Red Sea Challenger', 'Soma Bay', 'EG', 'challenger_75', 'hard', 'outdoor'),
  ('vietnam-coast-challenger-i', 'Vietnam Coast Challenger I', 'Phan Thiết', 'VN', 'challenger_50', 'hard', 'outdoor'),
  ('andes-futures', 'Andes Futures', 'Santiago', 'CL', 'futures_25', 'clay', 'outdoor'),
  ('antalya-mediterranean-futures', 'Antalya Mediterranean Futures', 'Antalya', 'TR', 'futures_25', 'clay', 'outdoor'),
  ('north-africa-futures', 'North Africa Futures', 'Monastir', 'TN', 'futures_15', 'hard', 'outdoor'),
  ('california-desert-challenger', 'California Desert Challenger', 'Palm Springs', 'US', 'challenger_100', 'hard', 'outdoor'),
  ('gulf-crown-challenger', 'Gulf Crown Challenger', 'Manama', 'BH', 'challenger_125', 'hard', 'outdoor'),
  ('brittany-indoor-challenger', 'Brittany Indoor Challenger', 'Quimper', 'FR', 'challenger_125', 'hard', 'indoor'),
  ('concepcion-pacific-challenger', 'Concepción Pacific Challenger', 'Concepción', 'CL', 'challenger_100', 'clay', 'outdoor'),
  ('san-diego-coast-challenger', 'San Diego Coast Challenger', 'San Diego', 'US', 'challenger_100', 'hard', 'outdoor'),
  ('fujairah-gulf-challenger', 'Fujairah Gulf Challenger', 'Fujairah', 'AE', 'challenger_100', 'hard', 'outdoor'),
  ('porto-atlantic-indoor', 'Porto Atlantic Indoor', 'Porto', 'PT', 'challenger_75', 'hard', 'indoor'),
  ('vietnam-coast-challenger-ii', 'Vietnam Coast Challenger II', 'Phan Thiết', 'VN', 'challenger_50', 'hard', 'outdoor'),
  ('sinai-red-sea-futures', 'Sinai Red Sea Futures', 'Sharm El-Sheikh', 'EG', 'futures_15', 'hard', 'outdoor'),
  ('christchurch-southern-challenger', 'Christchurch Southern Challenger', 'Christchurch', 'NZ', 'challenger_75', 'hard', 'outdoor');

insert into public.tournament_editions (tournament_series_id, season_number)
select id, 1 from public.tournament_series
where slug in (
  'brisbane-pacific-open','hong-kong-harbour-open','auckland-southern-classic','canberra-capital-challenger','bengaluru-city-challenger','noumea-pacific-challenger','siam-challenger-i','nottingham-winter-indoor','cape-summer-challenger','florida-sunshine-futures','lima-pacific-challenger',
  'southern-cross-grand-championship','adelaide-coast-open','hobart-island-open','siam-challenger-ii','buenos-aires-summer-challenger','glasgow-indoor-challenger','carolina-winter-futures','mallorca-academy-futures','atlas-winter-challenger',
  'oeiras-atlantic-challenger','itajai-coast-challenger','red-sea-challenger','vietnam-coast-challenger-i','andes-futures','antalya-mediterranean-futures','north-africa-futures','california-desert-challenger',
  'gulf-crown-challenger','brittany-indoor-challenger','concepcion-pacific-challenger','san-diego-coast-challenger','fujairah-gulf-challenger','porto-atlantic-indoor','vietnam-coast-challenger-ii','sinai-red-sea-futures','christchurch-southern-challenger'
);

insert into public.tournament_world_competitions (tournament_edition_id, world)
select e.id, w.world
from public.tournament_editions e
cross join (values ('ATP'), ('WTA')) as w(world)
where e.season_number = 1;

insert into public.tournament_schedule_slots (tournament_edition_id, calendar_month, month_week, phase, slot_order)
select e.id, 1, x.month_week, x.phase, x.slot_order
from (values
  ('brisbane-pacific-open',1,'full',1),('hong-kong-harbour-open',1,'full',1),('auckland-southern-classic',1,'full',1),('canberra-capital-challenger',1,'full',1),('bengaluru-city-challenger',1,'full',1),('noumea-pacific-challenger',1,'full',1),('siam-challenger-i',1,'full',1),('nottingham-winter-indoor',1,'full',1),('cape-summer-challenger',1,'full',1),('florida-sunshine-futures',1,'full',1),('lima-pacific-challenger',1,'full',1),
  ('southern-cross-grand-championship',2,'qualification',1),('adelaide-coast-open',2,'full',1),('hobart-island-open',2,'full',1),('siam-challenger-ii',2,'full',1),('buenos-aires-summer-challenger',2,'full',1),('glasgow-indoor-challenger',2,'full',1),('carolina-winter-futures',2,'full',1),('mallorca-academy-futures',2,'full',1),('atlas-winter-challenger',2,'full',1),
  ('southern-cross-grand-championship',3,'main_draw',2),('oeiras-atlantic-challenger',3,'full',1),('itajai-coast-challenger',3,'full',1),('red-sea-challenger',3,'full',1),('vietnam-coast-challenger-i',3,'full',1),('andes-futures',3,'full',1),('antalya-mediterranean-futures',3,'full',1),('north-africa-futures',3,'full',1),('california-desert-challenger',3,'full',1),
  ('gulf-crown-challenger',4,'full',1),('brittany-indoor-challenger',4,'full',1),('concepcion-pacific-challenger',4,'full',1),('san-diego-coast-challenger',4,'full',1),('fujairah-gulf-challenger',4,'full',1),('porto-atlantic-indoor',4,'full',1),('vietnam-coast-challenger-ii',4,'full',1),('sinai-red-sea-futures',4,'full',1),('christchurch-southern-challenger',4,'full',1)
) as x(slug, month_week, phase, slot_order)
join public.tournament_series s on s.slug = x.slug
join public.tournament_editions e on e.tournament_series_id = s.id and e.season_number = 1;

create or replace function public.get_tournament_calendar_v1(
  p_season_number integer,
  p_calendar_month integer,
  p_world text
)
returns table (
  competition_id uuid,
  tournament_id uuid,
  edition_id uuid,
  schedule_slot_id uuid,
  world text,
  season_number integer,
  calendar_month smallint,
  month_week smallint,
  phase text,
  tournament_name text,
  city text,
  country_code text,
  country_name text,
  category_code text,
  category_label text,
  winner_points integer,
  main_draw_capacity integer,
  qualifying_capacity_max integer,
  default_qualifier_slots integer,
  surface text,
  environment text
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    wc.id,
    s.id,
    e.id,
    sl.id,
    wc.world,
    e.season_number,
    sl.calendar_month,
    sl.month_week,
    sl.phase,
    s.name,
    s.city,
    s.country_code,
    co.name,
    c.code,
    c.label,
    c.winner_points,
    c.main_draw_capacity,
    c.qualifying_capacity_max,
    c.default_qualifier_slots,
    s.surface,
    s.environment
  from public.tournament_schedule_slots sl
  join public.tournament_editions e on e.id = sl.tournament_edition_id
  join public.tournament_series s on s.id = e.tournament_series_id and s.is_active
  join public.tournament_categories c on c.code = s.category_code
  join public.countries co on co.code = s.country_code
  join public.tournament_world_competitions wc on wc.tournament_edition_id = e.id
  where e.season_number = p_season_number
    and sl.calendar_month = p_calendar_month
    and wc.world = p_world
    and e.status <> 'canceled'
    and wc.status <> 'canceled'
  order by sl.month_week, c.sort_order, s.name, sl.slot_order;
$$;

revoke all on function public.get_tournament_calendar_v1(integer, integer, text) from public;
grant execute on function public.get_tournament_calendar_v1(integer, integer, text) to authenticated;
