-- Tennis Legacy player sponsor offer/contract foundation.
-- Production first received this version before the explicit smallint hotfix in
-- 20260908104017. This source-controlled mirror keeps the durable foundation
-- here; the following migration installs/replaces the three date-sensitive RPCs.

alter table public.sponsor_companies
  add column if not exists is_worldwide boolean not null default false;

comment on column public.sponsor_companies.is_worldwide is
  'True when the MAIN sponsor was marked worldwide in the source sponsor eligibility catalogue. Worldwide sponsors may appear outside their normal Tennis Legacy market group.';

update public.sponsor_companies
set is_worldwide = id = any(array[
'0039155d-68f9-4bf8-bb12-0d42878bceda','01e6366c-698d-4ae0-b0ad-374a328323fa','0430e714-b4ab-4a14-b6b5-69ad61ce63e0','044e4fbf-3baa-4d71-84b8-6bea26ea4892','05870751-2ef3-4c31-8e60-e5843637dd5f','05a676c6-6f93-4f15-97bc-7cc09df27911','0636ada3-6cf1-44cd-b6bf-f25d49303ccf','069f8662-7eff-47b3-8909-65f2666594e7','06feac4b-ab98-41ae-a005-defe191e48a6','082f1e04-5428-47d4-8033-5994ff5aeebc','0c6d337a-25f6-4bfc-a945-d481d9ad84f5','0c8aed15-4b87-46de-abf5-2b618cd2476a','0f12c48f-bf9e-4fdb-a1fa-81f386af2433','0f1d07da-49b9-4a8f-8cf8-e88e4f44ac28','11c3fd84-77d0-4d31-95a6-c14a8dd0fd3f','146a17bd-ff51-4bf1-8b95-50bdebd46430','14f8d4e5-4982-4f93-b55f-0332db4b064c','1634aca4-25ed-41b5-86ce-2f5cc3972a92','1a78ad94-dcbd-4554-98f7-3a351107b5e8','1e8434ec-ead2-4822-850c-ad68614a0fb4','1f42ba27-4503-4dd5-8281-79da6aeecb26','1f935f69-6e5f-42bb-b6ab-a3ac0f06be2c','23665131-9dc9-40e2-a35f-3b95187388de','237de1a8-b200-478a-80f8-a8f74c607633','23955e60-ad3d-4b75-a913-e9a8b31333e1','26e807e8-47b9-4b08-9d35-86fb19dde45a','28dacfb4-5a23-44af-a65b-8dc9449a2c9c','2971c59b-ccc5-4cd4-9432-acbab2df889c','2e062ff9-dddc-4779-9ac6-d60892c206f2','325081d2-9c3b-46b9-8f5d-7a9c826ebd1d','340da639-44c5-4e8c-bb1e-b80affe80be3','350b1897-0fcf-4ec6-8a1c-f0b07530366b','356ba20c-89ee-4330-8201-4d79fbc20853','38bfa08e-800e-49cf-9714-6d4cf42d160b','38f95c99-e50b-41f5-a46d-ebff3b2bb320','3b649146-3852-4622-937d-32084fbbbf01','43769632-4f44-4958-a64f-a09ca976bc06','454f41ca-bb59-4d45-9098-e301d767a45d','4640e052-b1a9-4f11-a8bf-fcbfcf9bc5cf','4685bc6a-4de0-4095-8553-aa866480c5c1','46a52ba7-dd04-4105-846b-5dc9db6138c2','470f5613-4b19-4b1f-ac9f-06d8bd5d31c4','4b8c0340-31a9-4ab5-8b79-5944bdfdf0d6','52515138-e007-42b6-bb57-3d9bd1e3c214','527c15f5-93ed-4a0b-97be-0bc83408dee6','56512045-79d3-4936-93eb-759be10efd25','5995dc13-c2f6-4466-a0a1-ebb457136798','5ae39fd3-0043-4e5f-be93-6cc1a1df28bf','5ba21a29-dd9c-4570-9853-9f245be38c95','5c8a5311-2fee-4297-a58a-82e607c18dfe','5d4dbefa-da74-46a3-ae09-3fc2fd79b4c8','5e09d3cb-5e82-47fa-b14d-d382e4ba67f7','6361ce03-08d3-46fe-8540-5c6c64ebdc50','64260e81-ed68-4d7c-95a9-c54ad0bf8355','64b491f9-9f60-436f-9f93-ebb32bcda587','64ec92e4-0e17-423e-8d56-1e51b5280458','67179c92-dc60-4430-9874-02bf90cf22fb','67435262-b15d-4534-ac9e-8e42b66e5d05','67911ae4-42da-4280-85c0-dee50ade054a','68757194-fe73-47a1-af82-74c249bdec22','699133e8-9f0b-48db-8a6c-ad33fbf79999','70934bd3-ec29-49b3-8202-d7dbdaf05e29','72bd460e-d0d5-4a48-90c6-359e82012fc8','75ff4342-11f1-455c-8301-375d8dd2571b','78e80aab-d7f9-47cb-82c1-861b68b830af','7981b2b1-2a71-4360-9ab4-37eaca5344d3','7a2510ab-541d-4f72-8352-c286477a9f00','7a3dae68-1cd1-45a2-9d1b-1d2e26d67672','7cc7a559-6b36-4ed4-988a-fe719ab2f334','85defe5a-061c-4554-a12e-8d38cd4b9b94','8645444a-2703-4b9a-90ea-8844f52f484e','8723cf87-f63f-4f71-9abb-29458ee3e6df','8c42e743-6988-42b3-b907-834a2a55ea35','8c601bb2-1bfd-4491-a3f3-67ab311ddece','9086db09-a5b5-4ce8-abe1-4951f959d50c','90cb9f6c-2929-40c0-bdc1-70c9d5f2ec68','91e5d6d9-6611-4d85-b3c6-3adbb2d53d4c','962f85de-3d1c-4111-86d3-6bf8abf879d6','9722fdb0-5bf3-4c92-bab8-f0448fe42479','98e9a61a-58b8-46ad-94ec-2debfb493e78','9b0a8ada-d808-4d25-bccb-65b6f64dc242','9b318e9e-d33b-48c4-8f8e-b8b5bdf052ea','9dc22433-3872-40ae-9b3f-1722c650a01d','9f8be3bb-0f13-431b-bb16-366baecc5ba4','a0439915-2d40-4a33-a8b6-e5cc21ed3299','a3ad9e79-0658-49d4-9b15-a145c582fc19','a43141f4-7f33-4c75-a46d-f4ce26bdfc77','a8c72708-02a1-4106-900e-373f55fbf9ec','a965d6e4-285e-4cff-b9a2-10fba169f2fc','ab54b566-e927-45d2-9211-c3f449e2a015','aeeacd4b-5596-40aa-a1f0-f795387e847e','afa83055-ad4c-4f19-9874-a3358e00337a','b1d1853e-b6eb-430c-9222-e467560fc109','b1fe12fd-e0fe-41f3-893e-df5a7a2e10d8','b24ccb92-003b-46b1-8a4b-9e5150dded33','b3852e57-0fd7-4034-b53a-a018f70da79c','b45c6b3f-a3f7-4237-a851-38bdb8a886a6','b58cb8a6-1329-4694-9b60-37b58644d9ae','b6af59a0-df1b-4e23-be97-b5dc7b5803b1','bb6e4f8e-3b5c-486f-b9ad-235dd4e85c55','beb3039c-4b9e-4718-a369-3e2dda42575d','c477649d-217c-40b3-8713-80b187442a8c','c525a432-9b09-439a-b833-4e6d1d360c44','c5cb7a8a-9d82-4576-af67-d29d4287752b','c644598c-c3f8-4912-93e7-70b68e07704b','c90aa8b7-318d-4ddc-95b3-a4b48190510f','c95d4d7d-abbd-4859-ab25-cc0b94dcc4d0','cd502933-7abd-4bf4-bf2d-342a7b27a3fe','cd73cae5-3986-4ef0-9646-7bfcad2734e3','cd8faf5c-b5c6-44a5-b8e6-ae2a2b83ea24','ce25b550-17c9-4cf5-9d66-dbdae9758852','d0ab7e97-ea31-4070-8488-af674edb78c7','d26a492b-437a-4cfa-9344-4592c48fe36d','d45a0c13-05fa-4ad0-b444-ac0c36a2d7c4','d4a3e271-b32c-4804-af73-b3e9dfc8ea04','d63b6530-3e22-4d8b-ade9-d3b8a7876896','d649d69b-3187-4d24-9c4d-c995bc8e337b','d72b7266-4972-4a77-91c7-d9a698722701','d940d19a-bcea-4b46-94ac-e7eb5c13edea','dd2db925-9731-44be-b696-551d402f5f35','dd7ba814-5032-4332-bb24-e8dde4128a46','df48a9ac-4243-4fb5-abf4-80e2608f70fb','e1898e8b-b972-470f-8f8b-38b6f4017ef4','e3cb657e-13dc-42e8-8fa5-d776b948aa23','e7d77dbb-8825-40eb-a131-3dbfabe0768f','e887de7b-5892-4be3-a017-a525a1ba795d','e8bf44e8-a5a5-4a2d-8f87-f1912ebdeb38','e98faee3-dd81-4ba3-b8de-1a3a5432a481','eafa6895-a2dd-41cb-85f0-e6a5997d7996','ec5b9a9b-193c-46be-8673-b480ee2ed482','ee8cfafb-256e-4c0b-b2a7-7a3ceccc372a','ee9a3d49-1968-43a0-8a2a-24ab26d573bb','f1168db2-80a7-43f5-9f4e-91eb9ecbe0ba','f52634ed-4811-48c1-8eec-d20f67efa43c','f73bdcb2-5c19-4975-b286-42c343bc6589','f86405bc-4c3a-4f0d-8e16-af17f1499f56','f8b2c433-4b91-426d-88fa-b985df7575d6','f99e116b-7d8a-4b5b-a91d-63fe98bc11f7','fab0286d-3ef5-4018-9613-c892265fde9d','fdc8fc0b-b46f-469c-a089-37f59792af98','fee251bf-3d2c-46ae-8504-3f60f8c60f16','ffa96d64-7f8a-41d8-8129-f8f79c7d74e7','fff547dd-e6ae-4305-9b52-820da2e3dbd9'
]::uuid[]);

create index if not exists sponsor_companies_worldwide_idx
  on public.sponsor_companies(is_worldwide)
  where sponsor_kind='main' and is_active and is_worldwide;

create table public.sponsor_offer_rules (
  code text primary key,
  rank_min integer not null,
  rank_max integer,
  offer_count_min smallint not null,
  offer_count_max smallint not null,
  local_share_start numeric(5,4) not null,
  local_share_end numeric(5,4) not null,
  full_season_value_min bigint not null,
  full_season_value_max bigint not null,
  sort_order smallint not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (rank_min >= 1),
  check (rank_max is null or rank_max >= rank_min),
  check (offer_count_min >= 1 and offer_count_max >= offer_count_min),
  check (local_share_start between 0 and 1 and local_share_end between 0 and 1),
  check (full_season_value_min > 0 and full_season_value_max >= full_season_value_min)
);

insert into public.sponsor_offer_rules(
  code,rank_min,rank_max,offer_count_min,offer_count_max,
  local_share_start,local_share_end,full_season_value_min,full_season_value_max,sort_order
) values
('rank_001_030',1,30,10,15,0.5000,0.5000,500000,2400000,1),
('rank_031_100',31,100,10,15,0.7000,0.7000,150000,800000,2),
('rank_101_300',101,300,6,10,0.8000,0.9000,30000,200000,3),
('rank_301_plus',301,null,2,5,1.0000,1.0000,5000,50000,4)
on conflict (code) do update set
  rank_min=excluded.rank_min,
  rank_max=excluded.rank_max,
  offer_count_min=excluded.offer_count_min,
  offer_count_max=excluded.offer_count_max,
  local_share_start=excluded.local_share_start,
  local_share_end=excluded.local_share_end,
  full_season_value_min=excluded.full_season_value_min,
  full_season_value_max=excluded.full_season_value_max,
  sort_order=excluded.sort_order,
  is_active=true,
  updated_at=now();

create table public.player_sponsor_offers (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  sponsor_company_id uuid not null references public.sponsor_companies(id) on delete restrict,
  season integer not null,
  offer_rule_code text not null references public.sponsor_offer_rules(code) on update cascade on delete restrict,
  offer_week_start_absolute_day integer not null,
  generated_absolute_day integer not null,
  expires_absolute_day integer not null,
  first_payment_absolute_day integer not null,
  player_rank integer not null,
  player_market_group_code text not null references public.sponsor_market_groups(code) on update cascade on delete restrict,
  source_pool text not null check (source_pool in ('market','worldwide')),
  full_season_value bigint not null check (full_season_value > 0),
  weekly_payment_amount bigint not null check (weekly_payment_amount > 0),
  scheduled_payment_count smallint not null check (scheduled_payment_count >= 1),
  total_contract_value bigint not null check (total_contract_value > 0),
  status text not null default 'open' check (status in ('open','accepted','declined','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id,sponsor_company_id,season,offer_week_start_absolute_day)
);

create index player_sponsor_offers_player_status_idx
  on public.player_sponsor_offers(player_id,season,status,offer_week_start_absolute_day desc);

create table public.player_sponsor_contracts (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  sponsor_company_id uuid not null references public.sponsor_companies(id) on delete restrict,
  offer_id uuid not null unique references public.player_sponsor_offers(id) on delete restrict,
  season integer not null,
  signed_absolute_day integer not null,
  start_absolute_day integer not null,
  first_payment_absolute_day integer not null,
  end_absolute_day integer not null,
  player_rank_at_sign integer not null,
  player_market_group_code text not null references public.sponsor_market_groups(code) on update cascade on delete restrict,
  source_pool text not null check (source_pool in ('market','worldwide')),
  full_season_value bigint not null check (full_season_value > 0),
  weekly_payment_amount bigint not null check (weekly_payment_amount > 0),
  scheduled_payment_count smallint not null check (scheduled_payment_count >= 1),
  total_contract_value bigint not null check (total_contract_value > 0),
  status text not null default 'active' check (status in ('active','completed','terminated')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id,season)
);

create index player_sponsor_contracts_player_status_idx
  on public.player_sponsor_contracts(player_id,status,season desc);

alter table public.sponsor_offer_rules enable row level security;
alter table public.player_sponsor_offers enable row level security;
alter table public.player_sponsor_contracts enable row level security;

create policy sponsor_offer_rules_authenticated_read
  on public.sponsor_offer_rules for select to authenticated using (true);
create policy player_sponsor_offers_owner_read
  on public.player_sponsor_offers for select to authenticated
  using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid() and p.player_type='human'));
create policy player_sponsor_contracts_owner_read
  on public.player_sponsor_contracts for select to authenticated
  using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid() and p.player_type='human'));

grant select on public.sponsor_offer_rules to authenticated;
grant select on public.player_sponsor_offers to authenticated;
grant select on public.player_sponsor_contracts to authenticated;

create or replace function public.sponsor_hash_unit_v1(p_seed text)
returns numeric
language sql
immutable
as $$
  select mod(abs(hashtextextended(coalesce(p_seed,''),0)::numeric),1000000::numeric)/1000000::numeric;
$$;

create or replace function public.process_player_sponsor_payments_v1(p_player_id uuid, p_through_absolute_day integer default null)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  v_through integer;
  c record;
  v_due integer;
  v_post jsonb;
  v_posted integer:=0;
  v_seen integer:=0;
begin
  select owner_user_id into v_owner from public.players where id=p_player_id and player_type='human';
  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_through:=coalesce(p_through_absolute_day,public.game_day_absolute_v1(gd.season,gd.month,gd.day));

  for c in
    select pc.*,sc.name sponsor_name
    from public.player_sponsor_contracts pc
    join public.sponsor_companies sc on sc.id=pc.sponsor_company_id
    where pc.player_id=p_player_id and pc.status='active' and pc.first_payment_absolute_day<=v_through
    order by pc.season,pc.signed_absolute_day
  loop
    for v_due in
      select generate_series(c.first_payment_absolute_day,least(c.end_absolute_day,v_through),7)
    loop
      v_post:=public.post_career_finance_transaction_v1(
        p_player_id,
        c.weekly_payment_amount,
        'sponsorship',
        'weekly_guaranteed_payment',
        format('%s weekly sponsor payment',c.sponsor_name),
        'sponsor_contract',
        c.id::text,
        format('sponsor-contract:%s:payment:%s',c.id,v_due),
        jsonb_build_object(
          'taxable',true,
          'sponsor_company_id',c.sponsor_company_id,
          'sponsor_name',c.sponsor_name,
          'contract_id',c.id,
          'contract_total_value',c.total_contract_value,
          'weekly_payment_amount',c.weekly_payment_amount
        ),
        false,
        v_due
      );
      v_seen:=v_seen+1;
      if v_post->>'status'='posted' then v_posted:=v_posted+1; end if;
    end loop;

    if v_through>=c.end_absolute_day then
      update public.player_sponsor_contracts set status='completed',updated_at=now() where id=c.id and status='active';
    end if;
  end loop;

  return jsonb_build_object('status','processed','through_absolute_day',v_through,'payments_checked',v_seen,'payments_posted',v_posted);
end;
$$;

create or replace function public.decline_player_sponsor_offer_v1(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_updated uuid;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  update public.player_sponsor_offers
  set status='declined',updated_at=now()
  where id=p_offer_id and player_id=v_player and status='open'
  returning id into v_updated;
  if v_updated is null then raise exception 'Sponsor offer is not open.'; end if;
  return jsonb_build_object('status','declined','offer_id',v_updated);
end;
$$;

create or replace function public.process_human_finance_to_current_day_v1(p_player_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  gd record;
  v_abs integer;
  p record;
  v_from integer;
  v_day integer;
  v_players integer:=0;
  v_days integer:=0;
  v_travel jsonb;
  v_tax jsonb;
  v_hotel jsonb;
  v_sponsors jsonb;
  v_reconcile jsonb;
begin
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  for p in
    select pl.id
    from public.players pl
    where pl.player_type='human'
      and pl.owner_user_id is not null
      and (p_player_id is null or pl.id=p_player_id)
    order by pl.created_at,pl.id
  loop
    perform public.ensure_player_career_finance_v1(p.id);
    v_travel:=public.process_due_travel_legs_v1(p.id,v_abs);
    v_tax:=public.process_due_career_tax_v1(p.id,v_abs);
    v_sponsors:=public.process_player_sponsor_payments_v1(p.id,v_abs);

    select coalesce(
      a.processed_through_absolute_day+1,
      (select min(t.game_absolute_day) from public.career_finance_transactions t where t.player_id=p.id and t.idempotency_key='career-opening-balance'),
      v_abs
    ) into v_from
    from public.player_career_finance_accounts a
    where a.player_id=p.id;

    if v_from<=v_abs then
      for v_day in select generate_series(v_from,v_abs)
      loop
        v_hotel:=public.process_tournament_hotel_day_v1(p.id,v_day);
        v_days:=v_days+1;
      end loop;
    else
      v_hotel:=public.process_tournament_hotel_day_v1(p.id,v_abs);
    end if;

    update public.player_career_finance_accounts
    set processed_through_absolute_day=v_abs,updated_at=now()
    where player_id=p.id;

    v_reconcile:=public.reconcile_career_finance_running_balances_v1(p.id);
    v_players:=v_players+1;
  end loop;

  return jsonb_build_object('status','processed','through_absolute_day',v_abs,'players',v_players,'hotel_days_checked',v_days);
end;
$$;

do $$
declare v_worldwide integer; v_rules integer; begin
  select count(*) into v_worldwide from public.sponsor_companies where sponsor_kind='main' and is_active and is_worldwide;
  if v_worldwide<>143 then raise exception 'Expected 143 worldwide MAIN sponsors, got %.',v_worldwide; end if;
  select count(*) into v_rules from public.sponsor_offer_rules where is_active;
  if v_rules<>4 then raise exception 'Expected 4 active sponsor offer rules, got %.',v_rules; end if;
end $$;
