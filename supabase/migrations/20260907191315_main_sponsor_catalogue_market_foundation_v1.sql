insert into public.countries(code,name,is_active)
values ('XK','Kosovo',true)
on conflict (code) do nothing;

create table public.sponsor_market_groups (
  code text primary key,
  name text not null unique,
  macro_region text not null check (macro_region in ('europe','asia','africa','americas','oceania')),
  sort_order integer not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sponsor_market_group_members (
  country_code text primary key references public.countries(code) on update cascade on delete restrict,
  group_code text not null references public.sponsor_market_groups(code) on update cascade on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index sponsor_market_group_members_group_idx
  on public.sponsor_market_group_members(group_code);

create table public.sponsor_companies (
  id uuid primary key,
  name text not null unique,
  sponsor_kind text not null default 'main' check (sponsor_kind = 'main'),
  country_code text not null references public.countries(code) on update cascade on delete restrict,
  logo_url text,
  is_active boolean not null default true,
  is_test boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  home_group_code text,
  home_macro_region text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.sponsor_companies is 'Reusable Tennis Legacy main-sponsor catalogue imported from ProPeloton. No contracts, offers, economics or tier eligibility are stored here.';
comment on column public.sponsor_companies.home_group_code is 'Non-authoritative source hint retained from ProPeloton. Resolve sponsor geography through country_code -> sponsor_market_group_members.';
comment on column public.sponsor_companies.home_macro_region is 'Non-authoritative source hint retained from ProPeloton. Resolve sponsor geography through country_code -> sponsor_market_group_members -> sponsor_market_groups.';

create index sponsor_companies_country_idx on public.sponsor_companies(country_code);
create index sponsor_companies_active_idx on public.sponsor_companies(is_active) where is_active=true;

alter table public.sponsor_market_groups enable row level security;
alter table public.sponsor_market_group_members enable row level security;
alter table public.sponsor_companies enable row level security;

create policy sponsor_market_groups_authenticated_read
  on public.sponsor_market_groups for select to authenticated using (true);
create policy sponsor_market_group_members_authenticated_read
  on public.sponsor_market_group_members for select to authenticated using (true);
create policy sponsor_companies_authenticated_read
  on public.sponsor_companies for select to authenticated using (true);

grant select on public.sponsor_market_groups to authenticated;
grant select on public.sponsor_market_group_members to authenticated;
grant select on public.sponsor_companies to authenticated;

insert into public.sponsor_market_groups(code,name,macro_region,sort_order) values
('iberia','Iberia','europe',1),
('france_benelux','France & Benelux','europe',2),
('alpine_italy','Alpine Europe + Italy','europe',3),
('british_isles','British Isles','europe',4),
('nordics_baltics','Nordics + Baltics','europe',5),
('central_europe','Central Europe','europe',6),
('balkans','Balkans','europe',7),
('albania_kosovo','Albania + Kosovo','europe',8),
('eastern_europe_caucasus','Eastern Europe + Caucasus','europe',9),
('eastern_mediterranean','Eastern Mediterranean','europe',10),
('anatolia_azerbaijan','Anatolia + Azerbaijan','asia',11),
('levant_mesopotamia','Levant + Mesopotamia','asia',12),
('iran_syria','Iran + Syria','asia',13),
('arabian_peninsula','Arabian Peninsula','asia',14),
('central_asia','Central Asia','asia',15),
('indian_subcontinent_core','Indian Subcontinent Core','asia',16),
('himalayan_indian_ocean_south_asia','Himalayan + Indian Ocean South Asia','asia',17),
('mainland_southeast_asia','Mainland Southeast Asia','asia',18),
('maritime_southeast_asia','Maritime Southeast Asia','asia',19),
('china_mongolia','China + Mongolia','asia',20),
('japan_korea','Japan + Korea','asia',21),
('australia_new_zealand','Australia + New Zealand','oceania',22),
('pacific_islands','Pacific Islands','oceania',23),
('north_africa','North Africa','africa',24),
('upper_guinea_coast','Upper Guinea Coast','africa',25),
('sahel_inland_west_africa','Sahel + Inland West Africa','africa',26),
('gulf_of_guinea','Gulf of Guinea','africa',27),
('central_africa','Central Africa','africa',28),
('east_africa','East Africa','africa',29),
('southern_africa_mainland','Southern Africa Mainland','africa',30),
('indian_ocean_africa','Indian Ocean Africa','africa',31),
('us_canada','United States + Canada','americas',32),
('mexico_central_america','Mexico + Central America','americas',33),
('caribbean','Caribbean','americas',34),
('southern_cone_brazil','Southern Cone + Brazil','americas',35),
('andean_northern_south_america','Andean + Northern South America','americas',36);

insert into public.sponsor_market_group_members(country_code,group_code) values
('AD','iberia'),('ES','iberia'),('PT','iberia'),
('BE','france_benelux'),('FR','france_benelux'),('LU','france_benelux'),('NL','france_benelux'),
('AT','alpine_italy'),('CH','alpine_italy'),('DE','alpine_italy'),('IT','alpine_italy'),('LI','alpine_italy'),('SM','alpine_italy'),
('GB','british_isles'),('IE','british_isles'),
('DK','nordics_baltics'),('EE','nordics_baltics'),('FI','nordics_baltics'),('IS','nordics_baltics'),('LT','nordics_baltics'),('LV','nordics_baltics'),('NO','nordics_baltics'),('SE','nordics_baltics'),
('CZ','central_europe'),('HU','central_europe'),('PL','central_europe'),('RO','central_europe'),('SK','central_europe'),
('BA','balkans'),('BG','balkans'),('GR','balkans'),('HR','balkans'),('ME','balkans'),('MK','balkans'),('RS','balkans'),('SI','balkans'),
('AL','albania_kosovo'),('XK','albania_kosovo'),
('AM','eastern_europe_caucasus'),('BY','eastern_europe_caucasus'),('GE','eastern_europe_caucasus'),('MD','eastern_europe_caucasus'),('RU','eastern_europe_caucasus'),('UA','eastern_europe_caucasus'),
('CY','eastern_mediterranean'),('IL','eastern_mediterranean'),('MT','eastern_mediterranean'),
('AZ','anatolia_azerbaijan'),('TR','anatolia_azerbaijan'),
('IQ','levant_mesopotamia'),('JO','levant_mesopotamia'),('LB','levant_mesopotamia'),
('IR','iran_syria'),('SY','iran_syria'),
('AE','arabian_peninsula'),('BH','arabian_peninsula'),('KW','arabian_peninsula'),('OM','arabian_peninsula'),('QA','arabian_peninsula'),('SA','arabian_peninsula'),('YE','arabian_peninsula'),
('KG','central_asia'),('KZ','central_asia'),('TJ','central_asia'),('TM','central_asia'),('UZ','central_asia'),
('BD','indian_subcontinent_core'),('PK','indian_subcontinent_core'),
('BT','himalayan_indian_ocean_south_asia'),('IN','himalayan_indian_ocean_south_asia'),('LK','himalayan_indian_ocean_south_asia'),('MV','himalayan_indian_ocean_south_asia'),('NP','himalayan_indian_ocean_south_asia'),
('KH','mainland_southeast_asia'),('LA','mainland_southeast_asia'),('MM','mainland_southeast_asia'),('TH','mainland_southeast_asia'),('VN','mainland_southeast_asia'),
('BN','maritime_southeast_asia'),('ID','maritime_southeast_asia'),('MY','maritime_southeast_asia'),('PH','maritime_southeast_asia'),('SG','maritime_southeast_asia'),
('CN','china_mongolia'),('HK','china_mongolia'),('MN','china_mongolia'),
('JP','japan_korea'),('KR','japan_korea'),('TW','japan_korea'),
('AU','australia_new_zealand'),('NZ','australia_new_zealand'),
('FJ','pacific_islands'),('NC','pacific_islands'),('PF','pacific_islands'),('PG','pacific_islands'),('TO','pacific_islands'),('WS','pacific_islands'),
('DZ','north_africa'),('EG','north_africa'),('EH','north_africa'),('LY','north_africa'),('MA','north_africa'),('SD','north_africa'),('TN','north_africa'),
('CV','upper_guinea_coast'),('GM','upper_guinea_coast'),('GN','upper_guinea_coast'),('GW','upper_guinea_coast'),('LR','upper_guinea_coast'),('SL','upper_guinea_coast'),('SN','upper_guinea_coast'),
('BF','sahel_inland_west_africa'),('ML','sahel_inland_west_africa'),('MR','sahel_inland_west_africa'),('NE','sahel_inland_west_africa'),
('BJ','gulf_of_guinea'),('CI','gulf_of_guinea'),('GH','gulf_of_guinea'),('NG','gulf_of_guinea'),('TG','gulf_of_guinea'),
('AO','central_africa'),('CD','central_africa'),('CF','central_africa'),('CG','central_africa'),('CM','central_africa'),('GA','central_africa'),
('BI','east_africa'),('ER','east_africa'),('ET','east_africa'),('KE','east_africa'),('RW','east_africa'),('SS','east_africa'),('TZ','east_africa'),('UG','east_africa'),
('BW','southern_africa_mainland'),('LS','southern_africa_mainland'),('MW','southern_africa_mainland'),('MZ','southern_africa_mainland'),('NA','southern_africa_mainland'),('SZ','southern_africa_mainland'),('ZA','southern_africa_mainland'),('ZM','southern_africa_mainland'),('ZW','southern_africa_mainland'),
('MG','indian_ocean_africa'),('MU','indian_ocean_africa'),('SC','indian_ocean_africa'),
('CA','us_canada'),('US','us_canada'),
('BZ','mexico_central_america'),('CR','mexico_central_america'),('GT','mexico_central_america'),('MX','mexico_central_america'),('PA','mexico_central_america'),
('AW','caribbean'),('BB','caribbean'),('BS','caribbean'),('CU','caribbean'),('DM','caribbean'),('DO','caribbean'),('GP','caribbean'),('HT','caribbean'),('JM','caribbean'),('TT','caribbean'),
('AR','southern_cone_brazil'),('BR','southern_cone_brazil'),('CL','southern_cone_brazil'),('PY','southern_cone_brazil'),('UY','southern_cone_brazil'),
('BO','andean_northern_south_america'),('CO','andean_northern_south_america'),('EC','andean_northern_south_america'),('PE','andean_northern_south_america'),('VE','andean_northern_south_america');