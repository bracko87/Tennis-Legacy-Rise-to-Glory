create table if not exists public.private_life_property_locations (
  code text primary key,
  country_code text not null,
  country_name text not null,
  city text not null,
  apartment_base_price bigint not null check (apartment_base_price > 0),
  house_base_price bigint not null check (house_base_price > 0),
  annual_value_rate_bps integer not null default 250 check (annual_value_rate_bps between -1000 and 2000),
  marketplace_enabled boolean not null default true,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(country_code,city)
);

alter table public.private_life_property_locations enable row level security;
revoke all on public.private_life_property_locations from public,anon,authenticated;

alter table public.private_life_player_assets
  add column if not exists location_code text,
  add column if not exists acquisition_type text not null default 'purchase',
  add column if not exists annual_running_cost_override bigint,
  add column if not exists annual_value_rate_bps_override integer,
  add column if not exists resale_discount_bps_override integer,
  add column if not exists prestige_override smallint;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.private_life_player_assets'::regclass and conname='private_life_player_assets_location_code_fkey') then
    alter table public.private_life_player_assets add constraint private_life_player_assets_location_code_fkey foreign key(location_code) references public.private_life_property_locations(code);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.private_life_player_assets'::regclass and conname='private_life_player_assets_acquisition_type_check') then
    alter table public.private_life_player_assets add constraint private_life_player_assets_acquisition_type_check check (acquisition_type in ('purchase','starter_home'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.private_life_player_assets'::regclass and conname='private_life_player_assets_override_cost_check') then
    alter table public.private_life_player_assets add constraint private_life_player_assets_override_cost_check check (annual_running_cost_override is null or annual_running_cost_override>=0);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.private_life_player_assets'::regclass and conname='private_life_player_assets_override_rate_check') then
    alter table public.private_life_player_assets add constraint private_life_player_assets_override_rate_check check (annual_value_rate_bps_override is null or annual_value_rate_bps_override between -5000 and 5000);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.private_life_player_assets'::regclass and conname='private_life_player_assets_override_resale_check') then
    alter table public.private_life_player_assets add constraint private_life_player_assets_override_resale_check check (resale_discount_bps_override is null or resale_discount_bps_override between 0 and 5000);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.private_life_player_assets'::regclass and conname='private_life_player_assets_override_prestige_check') then
    alter table public.private_life_player_assets add constraint private_life_player_assets_override_prestige_check check (prestige_override is null or prestige_override>=0);
  end if;
end $$;

create index if not exists private_life_player_assets_location_code_idx on public.private_life_player_assets(location_code) where location_code is not null;
drop index if exists public.private_life_player_assets_one_active_catalog_item_idx;
create unique index if not exists private_life_player_assets_one_active_catalog_location_idx on public.private_life_player_assets(player_id,catalog_code,coalesce(location_code,'')) where sold_absolute_day is null;

create table if not exists public.private_life_asset_sale_listings (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  player_asset_id uuid not null references public.private_life_player_assets(id) on delete cascade,
  sale_mode text not null check (sale_mode in ('urgent','standard','patient')),
  listed_absolute_day integer not null,
  settle_absolute_day integer not null,
  quoted_market_value bigint not null check (quoted_market_value > 0),
  quoted_sale_price bigint not null check (quoted_sale_price > 0),
  status text not null default 'pending' check (status in ('pending','completed','cancelled')),
  finance_transaction_id uuid references public.career_finance_transactions(id),
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.private_life_asset_sale_listings enable row level security;
revoke all on public.private_life_asset_sale_listings from public,anon,authenticated;
create unique index if not exists private_life_asset_sale_listings_one_pending_idx on public.private_life_asset_sale_listings(player_asset_id) where status='pending';
create index if not exists private_life_asset_sale_listings_due_idx on public.private_life_asset_sale_listings(status,settle_absolute_day);
create index if not exists private_life_asset_sale_listings_player_idx on public.private_life_asset_sale_listings(player_id,created_at desc);