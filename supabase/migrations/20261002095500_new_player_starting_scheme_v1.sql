-- Tennis Legacy — definitive New Player Starting Scheme v1
-- Approved 2026-10-02.
--
-- Human career Day-1 package:
-- * $25,000 Career Cash
-- * 20 Coins exactly once per account
-- * existing balanced human skills/rankings
-- * no selected training plan, no staff, no sponsors, no club/association membership
-- * starter racket + shoes + tour-appropriate apparel at 100% condition, equipped
-- * no accessories
-- * Premium only: one trade-locked home-city starter apartment
-- * non-core property locations use a 10-tier country baseline; explicit city prices remain overrides

update public.career_finance_settings
set starting_balance=25000,
    currency='USD',
    updated_at=now()
where id=1;

-- ---------------------------------------------------------------------------
-- Property price tiers and country mapping
-- ---------------------------------------------------------------------------

create table if not exists public.private_life_property_price_tiers (
  tier smallint primary key check (tier between 1 and 10),
  label text not null,
  apartment_base_price bigint not null check (apartment_base_price > 0),
  house_base_price bigint not null check (house_base_price > 0),
  annual_value_rate_bps integer not null default 225,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.private_life_property_price_tiers(
  tier,label,apartment_base_price,house_base_price,annual_value_rate_bps
) values
  (1,'Very low cost',40000,100000,175),
  (2,'Low cost',60000,150000,185),
  (3,'Lower-mid',80000,200000,195),
  (4,'Mid',120000,300000,210),
  (5,'Upper-mid',160000,400000,220),
  (6,'High',220000,550000,230),
  (7,'Very high',300000,800000,240),
  (8,'Premium',450000,1200000,250),
  (9,'Ultra-high',700000,2000000,260),
  (10,'Exceptional luxury',1200000,4000000,275)
on conflict(tier) do update set
  label=excluded.label,
  apartment_base_price=excluded.apartment_base_price,
  house_base_price=excluded.house_base_price,
  annual_value_rate_bps=excluded.annual_value_rate_bps,
  updated_at=now();

create table if not exists public.private_life_country_property_tiers (
  country_code text primary key references public.countries(code) on update cascade on delete cascade,
  tier smallint not null references public.private_life_property_price_tiers(tier),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.private_life_country_property_tiers(country_code,tier)
select
  c.code,
  case
    when c.code in ('MC') then 10
    when c.code in ('CH','LI','LU','SG','HK','BM','KY','GG','JE') then 9
    when c.code in ('US','CA','GB','NO','DK','IS','AU','NZ','IE','NL','SE','AE','QA','FO','IM') then 8
    when c.code in ('DE','FR','AT','BE','FI','JP','KR','IL','IT','AD','SM','MT','CY','TW','PR','GI','BL','MF') then 7
    when c.code in ('ES','PT','CZ','SI','EE','BH','KW','OM','SA','BN','MO','AW','BS','BB','CL','UY','CR','PA','NC','PF') then 6
    when c.code in ('PL','SK','HR','LT','LV','GR','HU','RO','BG','TR','MY','MX','BR','AR','ZA','KZ','RU','CN','TH','MU','SC','TT','CW','BQ') then 5
    when c.code in ('RS','ME','BA','MK','AL','XK','MD','GE','AM','AZ','CO','PE','EC','DO','JM','DZ','MA','TN','ID','PH','VN','UA','BY','JO','LB','BW','NA','FJ','MV','SR','GY','PY','BZ','DM','GD','LC','VC','AG','KN','SX') then 4
    when c.code in ('BO','GT','HN','SV','NI','CU','IR','IQ','MN','UZ','TM','KG','TJ','LK','BT','KH','LA','PG','GH','CI','CM','CG','GA','KE','TZ','UG','RW','SN','CV','WS','TO','VU','FM','PW','MH') then 3
    when c.code in ('IN','PK','BD','NP','EG','NG','AO','BJ','TG','ZM','ZW','LS','SZ','MR','DJ','KM','ST','GQ','MM','PS','SY','KP','TL','SB','KI','TV','NR') then 2
    when c.code in ('AF','BI','BF','CF','CD','ER','ET','GM','GN','GW','HT','LR','MG','MW','ML','MZ','NE','SL','SO','SS','SD','TD','YE') then 1
    else 4
  end::smallint
from public.countries c
on conflict(country_code) do update set
  tier=excluded.tier,
  updated_at=now();

do $$
declare
  v_countries integer;
  v_mapped integer;
begin
  select count(*) into v_countries from public.countries;
  select count(*) into v_mapped from public.private_life_country_property_tiers;
  if v_countries<>v_mapped then
    raise exception 'Property tier mapping incomplete: countries %, mapped %',v_countries,v_mapped;
  end if;
end;
$$;

create or replace function public.private_life_country_property_baseline_v1(p_country_code text)
returns table(
  tier smallint,
  apartment_base_price bigint,
  house_base_price bigint,
  annual_value_rate_bps integer
)
language sql
stable
security definer
set search_path=public
as $$
  select
    pt.tier,
    pt.apartment_base_price,
    pt.house_base_price,
    pt.annual_value_rate_bps
  from public.private_life_country_property_tiers ct
  join public.private_life_property_price_tiers pt on pt.tier=ct.tier
  where ct.country_code=upper(coalesce(p_country_code,''))
  limit 1;
$$;

-- Convert only generated/non-marketplace home-city fallback rows from the old
-- universal $120k/$300k values to their country baseline. Explicit marketplace
-- cities (New York, London, Monaco, etc.) remain untouched.
update public.private_life_property_locations l
set apartment_base_price=b.apartment_base_price,
    house_base_price=b.house_base_price,
    annual_value_rate_bps=b.annual_value_rate_bps,
    updated_at=now()
from lateral public.private_life_country_property_baseline_v1(l.country_code) b
where l.marketplace_enabled=false
  and l.code like 'home_%';

-- ---------------------------------------------------------------------------
-- Premium-only starter apartment
-- ---------------------------------------------------------------------------

create or replace function public.ensure_private_life_starter_home_v1(p_player_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_player record;
  v_existing uuid;
  v_existing_location text;
  v_location public.private_life_property_locations%rowtype;
  v_location_code text;
  v_country_name text;
  v_price bigint;
  v_owned_id uuid:=gen_random_uuid();
  v_is_premium boolean:=false;
  v_baseline record;
begin
  select id,owner_user_id,player_type,country_code,home_city
  into v_player
  from public.players
  where id=p_player_id;

  if v_player.id is null or v_player.home_city is null or btrim(v_player.home_city)='' then
    return null;
  end if;

  if v_player.player_type='human' then
    if v_player.owner_user_id is null then return null; end if;

    select exists(
      select 1
      from public.premium_memberships pm
      where pm.user_id=v_player.owner_user_id
        and pm.plan_code='premium'
        and pm.status='active'
        and (pm.current_period_end is null or pm.current_period_end>now())
    ) into v_is_premium;

    if not v_is_premium then
      return null;
    end if;
  end if;

  select coalesce(c.name,upper(coalesce(v_player.country_code,'XX')))
  into v_country_name
  from public.countries c
  where upper(c.code)=upper(coalesce(v_player.country_code,''))
  limit 1;
  v_country_name:=coalesce(v_country_name,upper(coalesce(v_player.country_code,'XX')));

  select * into v_location
  from public.private_life_property_locations
  where active=true
    and upper(country_code)=upper(coalesce(v_player.country_code,''))
    and lower(city)=lower(v_player.home_city)
  order by marketplace_enabled desc,sort_order
  limit 1;

  if v_location.code is null then
    select * into v_baseline
    from public.private_life_country_property_baseline_v1(v_player.country_code);

    if v_baseline.tier is null then
      select * into v_baseline
      from public.private_life_property_price_tiers
      where tier=4;
    end if;

    v_location_code:='home_'||replace(p_player_id::text,'-','');
    insert into public.private_life_property_locations(
      code,country_code,country_name,city,apartment_base_price,house_base_price,
      annual_value_rate_bps,marketplace_enabled,active,sort_order
    ) values(
      v_location_code,
      upper(coalesce(v_player.country_code,'XX')),
      v_country_name,
      v_player.home_city,
      v_baseline.apartment_base_price,
      v_baseline.house_base_price,
      v_baseline.annual_value_rate_bps,
      false,true,9999
    )
    on conflict(code) do update set
      country_code=excluded.country_code,
      country_name=excluded.country_name,
      city=excluded.city,
      apartment_base_price=excluded.apartment_base_price,
      house_base_price=excluded.house_base_price,
      annual_value_rate_bps=excluded.annual_value_rate_bps,
      active=true,
      updated_at=now();

    select * into v_location
    from public.private_life_property_locations
    where code=v_location_code;
  elsif not v_location.marketplace_enabled and v_location.code like 'home_%' then
    select * into v_baseline
    from public.private_life_country_property_baseline_v1(v_player.country_code);

    if v_baseline.tier is not null then
      update public.private_life_property_locations
      set country_name=v_country_name,
          apartment_base_price=v_baseline.apartment_base_price,
          house_base_price=v_baseline.house_base_price,
          annual_value_rate_bps=v_baseline.annual_value_rate_bps,
          updated_at=now()
      where code=v_location.code
      returning * into v_location;
    end if;
  end if;

  select id,location_code into v_existing,v_existing_location
  from public.private_life_player_assets
  where player_id=p_player_id
    and catalog_code='apt_home_starter'
    and sold_absolute_day is null
  order by created_at
  limit 1;

  v_price:=greatest(1,round(v_location.apartment_base_price::numeric*0.60)::bigint);

  if v_existing is not null then
    update public.private_life_player_assets
    set location_code=v_location.code,
        purchase_price=v_price,
        annual_running_cost_override=0,
        annual_value_rate_bps_override=v_location.annual_value_rate_bps,
        prestige_override=0,
        trade_locked=true,
        updated_at=now()
    where id=v_existing;
    return v_existing;
  end if;

  insert into public.private_life_player_assets(
    id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day,purchase_price,
    annual_running_cost_override,annual_value_rate_bps_override,resale_discount_bps_override,
    prestige_override,trade_locked
  ) values(
    v_owned_id,p_player_id,'apt_home_starter',v_location.code,'starter_home',0,v_price,
    0,v_location.annual_value_rate_bps,1200,0,true
  );

  return v_owned_id;
end;
$$;

create or replace function public.trg_ensure_private_life_starter_home_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  perform public.ensure_private_life_starter_home_v1(new.id);
  return new;
end;
$$;

-- Existing Free careers should not retain the incorrectly granted starter home.
delete from public.private_life_player_assets a
using public.players p
left join public.premium_memberships pm on pm.user_id=p.owner_user_id
where a.player_id=p.id
  and p.player_type='human'
  and p.owner_user_id is not null
  and a.catalog_code='apt_home_starter'
  and a.acquisition_type='starter_home'
  and a.sold_absolute_day is null
  and a.purchase_transaction_id is null
  and not (
    pm.plan_code='premium'
    and pm.status='active'
    and (pm.current_period_end is null or pm.current_period_end>now())
  );

-- Existing Premium starter apartments become trade-locked and use the correct
-- location value.
update public.private_life_player_assets a
set purchase_price=greatest(1,round(l.apartment_base_price::numeric*0.60)::bigint),
    annual_running_cost_override=0,
    annual_value_rate_bps_override=l.annual_value_rate_bps,
    prestige_override=0,
    trade_locked=true,
    updated_at=now()
from public.players p
join public.premium_memberships pm on pm.user_id=p.owner_user_id
join public.private_life_property_locations l on true
where a.player_id=p.id
  and l.code=a.location_code
  and p.player_type='human'
  and a.catalog_code='apt_home_starter'
  and a.sold_absolute_day is null
  and pm.plan_code='premium'
  and pm.status='active'
  and (pm.current_period_end is null or pm.current_period_end>now());

create or replace function public.trg_premium_starter_home_entitlement_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  r record;
begin
  if new.plan_code='premium'
     and new.status='active'
     and (new.current_period_end is null or new.current_period_end>now()) then
    for r in
      select p.id
      from public.players p
      where p.owner_user_id=new.user_id
        and p.player_type='human'
    loop
      perform public.ensure_private_life_starter_home_v1(r.id);
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists ensure_premium_starter_home_entitlement_v1 on public.premium_memberships;
create trigger ensure_premium_starter_home_entitlement_v1
after insert or update of plan_code,status,current_period_end
on public.premium_memberships
for each row
execute function public.trg_premium_starter_home_entitlement_v1();

-- ---------------------------------------------------------------------------
-- Starting Coins — account-level, exactly once
-- ---------------------------------------------------------------------------

create unique index if not exists coin_ledger_new_career_starting_uidx
on public.coin_ledger(user_id,reference_id)
where entry_type='career_start_reward'
  and reference_id='new-career-starting-coins-v1';

create or replace function public.grant_new_career_starting_coins_v1(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_balance bigint;
begin
  if p_user_id is null then
    return jsonb_build_object('status','skipped','reason','missing_user');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('new-career-starting-coins:'||p_user_id::text,0));

  if exists(
    select 1
    from public.coin_ledger
    where user_id=p_user_id
      and entry_type='career_start_reward'
      and reference_id='new-career-starting-coins-v1'
  ) then
    select coins_balance into v_balance
    from public.user_wallets
    where user_id=p_user_id;

    return jsonb_build_object(
      'status','already_granted',
      'amount',20,
      'balance_after',coalesce(v_balance,0)
    );
  end if;

  insert into public.user_wallets(user_id)
  values(p_user_id)
  on conflict(user_id) do nothing;

  update public.user_wallets
  set coins_balance=coins_balance+20,
      lifetime_coins_earned=lifetime_coins_earned+20,
      updated_at=now()
  where user_id=p_user_id
  returning coins_balance into v_balance;

  insert into public.coin_ledger(
    user_id,amount,balance_after,entry_type,description,reference_id
  ) values(
    p_user_id,20,v_balance,'career_start_reward',
    'New career starting Coins',
    'new-career-starting-coins-v1'
  );

  return jsonb_build_object(
    'status','granted',
    'amount',20,
    'balance_after',v_balance
  );
exception when unique_violation then
  select coins_balance into v_balance
  from public.user_wallets
  where user_id=p_user_id;
  return jsonb_build_object('status','already_granted','amount',20,'balance_after',coalesce(v_balance,0));
end;
$$;

-- ---------------------------------------------------------------------------
-- Exact starter equipment
-- ---------------------------------------------------------------------------

create unique index if not exists player_equipment_inventory_one_starter_item_uidx
on public.player_equipment_inventory(player_id,catalog_item_id)
where acquired_source='starter';

create or replace function public.initialize_player_equipment_v1(p_player_id uuid)
returns void
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_abs integer;
  v_world text;
  v_racket uuid;
  v_shoes uuid;
  v_apparel uuid;
  v_apparel_sku text;
begin
  select p.world
  into v_world
  from public.players p
  where p.id=p_player_id
    and p.player_type='human'
    and p.owner_user_id is not null;

  if v_world not in ('ATP','WTA') then return; end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  v_apparel_sku:=case when v_world='WTA' then 'APP-WTA-BLOKUV-01' else 'APP-BLOKUV-01' end;

  insert into public.player_equipment_loadouts(player_id)
  values(p_player_id)
  on conflict(player_id) do nothing;

  insert into public.player_equipment_inventory(
    player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source,purchase_price_usd
  )
  select p_player_id,c.id,100,v_abs,'starter',0
  from public.equipment_catalog_items c
  where c.sku in ('RKT-ROSIGNOL-01','SHO-ANTTA-01',v_apparel_sku)
    and c.is_active
    and c.availability_status='available'
    and c.tour_scope in ('unisex',v_world)
  on conflict do nothing;

  select i.id into v_racket
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku='RKT-ROSIGNOL-01'
    and i.acquired_source='starter'
  order by i.created_at
  limit 1;

  select i.id into v_shoes
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku='SHO-ANTTA-01'
    and i.acquired_source='starter'
  order by i.created_at
  limit 1;

  select i.id into v_apparel
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and c.sku=v_apparel_sku
    and i.acquired_source='starter'
  order by i.created_at
  limit 1;

  if v_racket is null or v_shoes is null or v_apparel is null then
    raise exception 'Starter equipment catalog is incomplete for % player.',v_world;
  end if;

  update public.player_equipment_loadouts
  set racket_inventory_id=coalesce(racket_inventory_id,v_racket),
      shoes_inventory_id=coalesce(shoes_inventory_id,v_shoes),
      apparel_inventory_id=coalesce(apparel_inventory_id,v_apparel),
      string_inventory_id=null,
      updated_at=now()
  where player_id=p_player_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- One human-career orchestration point + audit
-- ---------------------------------------------------------------------------

create table if not exists public.new_player_initialization_audit (
  player_id uuid primary key references public.players(id) on delete cascade,
  user_id uuid not null,
  scheme_version text not null,
  initialized_at timestamptz not null default now(),
  finance_result jsonb not null default '{}'::jsonb,
  coins_result jsonb not null default '{}'::jsonb,
  equipment_result jsonb not null default '{}'::jsonb,
  private_life_result jsonb not null default '{}'::jsonb,
  validation_result jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.initialize_new_human_career_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_player record;
  v_finance jsonb;
  v_coins jsonb;
  v_home uuid;
  v_equipment_count integer:=0;
  v_accessory_count integer:=0;
  v_staff_count integer:=0;
  v_sponsor_count integer:=0;
  v_technical_sponsor_count integer:=0;
  v_assoc_count integer:=0;
  v_club_count integer:=0;
  v_calendar_count integer:=0;
  v_training_count integer:=0;
  v_skill_count integer:=0;
  v_rank_points bigint:=0;
  v_doubles_points bigint:=0;
  v_validation jsonb;
begin
  select p.id,p.owner_user_id,p.player_type,p.world,p.country_code,p.home_city
  into v_player
  from public.players p
  where p.id=p_player_id;

  if v_player.id is null
     or v_player.player_type<>'human'
     or v_player.owner_user_id is null then
    return jsonb_build_object('status','skipped','reason','not_owned_human_player');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('new-human-career:'||p_player_id::text,0));

  v_finance:=public.ensure_player_career_finance_v1(p_player_id);
  v_coins:=public.grant_new_career_starting_coins_v1(v_player.owner_user_id);

  perform public.initialize_player_equipment_v1(p_player_id);
  v_home:=public.ensure_private_life_starter_home_v1(p_player_id);

  select count(*) into v_equipment_count
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and i.acquired_source='starter'
    and c.item_type in ('racket','shoes','apparel');

  select count(*) into v_accessory_count
  from public.player_equipment_inventory i
  join public.equipment_catalog_items c on c.id=i.catalog_item_id
  where i.player_id=p_player_id
    and i.acquired_source='starter'
    and c.item_type='accessory';

  select count(*) into v_staff_count
  from public.player_staff_contracts
  where player_id=p_player_id and status='active';

  select count(*) into v_sponsor_count
  from public.player_sponsor_contracts
  where player_id=p_player_id and status='active';

  select count(*) into v_technical_sponsor_count
  from public.player_technical_sponsor_contracts
  where player_id=p_player_id and status='active';

  select count(*) into v_assoc_count
  from public.national_association_memberships
  where player_id=p_player_id and status='active';

  select count(*) into v_club_count
  from public.tennis_club_memberships
  where player_id=p_player_id;

  select count(*) into v_calendar_count
  from public.player_calendar_commitments
  where player_id=p_player_id and status='committed';

  select count(*) into v_training_count
  from public.player_training_plans
  where player_id=p_player_id;

  select count(*) into v_skill_count
  from public.player_skills
  where player_id=p_player_id;

  select coalesce(r.ranking_points,0)
  into v_rank_points
  from public.player_rankings r
  where r.player_id=p_player_id;

  select coalesce(r.ranking_points,0)
  into v_doubles_points
  from public.player_doubles_rankings r
  where r.player_id=p_player_id;

  v_validation:=jsonb_build_object(
    'starter_equipment_count',v_equipment_count,
    'starter_accessory_count',v_accessory_count,
    'active_staff_count',v_staff_count,
    'active_regular_sponsors',v_sponsor_count,
    'active_technical_sponsors',v_technical_sponsor_count,
    'active_association_memberships',v_assoc_count,
    'club_memberships',v_club_count,
    'calendar_commitments',v_calendar_count,
    'configured_training_plans',v_training_count,
    'skill_rows',v_skill_count,
    'singles_ranking_points',coalesce(v_rank_points,0),
    'doubles_ranking_points',coalesce(v_doubles_points,0)
  );

  insert into public.new_player_initialization_audit(
    player_id,user_id,scheme_version,finance_result,coins_result,
    equipment_result,private_life_result,validation_result,updated_at
  ) values(
    p_player_id,v_player.owner_user_id,'v1',coalesce(v_finance,'{}'::jsonb),coalesce(v_coins,'{}'::jsonb),
    jsonb_build_object('starter_items',v_equipment_count,'starter_accessories',v_accessory_count),
    jsonb_build_object('starter_home_id',v_home),
    v_validation,now()
  )
  on conflict(player_id) do update set
    user_id=excluded.user_id,
    scheme_version='v1',
    finance_result=excluded.finance_result,
    coins_result=excluded.coins_result,
    equipment_result=excluded.equipment_result,
    private_life_result=excluded.private_life_result,
    validation_result=excluded.validation_result,
    updated_at=now();

  if v_equipment_count<>3
     or v_accessory_count<>0
     or v_staff_count<>0
     or v_sponsor_count<>0
     or v_technical_sponsor_count<>0
     or v_assoc_count<>0
     or v_club_count<>0
     or v_calendar_count<>0
     or v_training_count<>0
     or v_skill_count<>1
     or coalesce(v_rank_points,0)<>0
     or coalesce(v_doubles_points,0)<>0 then
    raise exception 'New Player Starting Scheme validation failed for player %: %',p_player_id,v_validation;
  end if;

  return jsonb_build_object(
    'status','initialized',
    'scheme_version','v1',
    'player_id',p_player_id,
    'finance',v_finance,
    'coins',v_coins,
    'starter_home_id',v_home,
    'validation',v_validation
  );
end;
$$;

create or replace function public.trg_initialize_new_human_career_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  perform public.initialize_new_human_career_v1(new.id);
  return new;
end;
$$;

-- Remove the old independent human-only starter triggers. Skills/rankings and
-- other general player triggers remain authoritative and run before the master
-- career initializer.
drop trigger if exists initialize_new_human_player_equipment_v1 on public.players;
drop trigger if exists initialize_new_human_player_finance on public.players;
drop trigger if exists ensure_private_life_starter_home_v1 on public.players;

create trigger ensure_private_life_starter_home_v1
after update of owner_user_id,country_code,home_city,player_type
on public.players
for each row
execute function public.trg_ensure_private_life_starter_home_v1();

drop trigger if exists zz_initialize_new_human_career_v1 on public.players;
create trigger zz_initialize_new_human_career_v1
after insert or update of player_type,owner_user_id,world
on public.players
for each row
when (new.player_type='human' and new.owner_user_id is not null)
execute function public.trg_initialize_new_human_career_v1();

-- Sanity guards for the exact approved starter catalog.
do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from public.equipment_catalog_items
  where sku in ('RKT-ROSIGNOL-01','SHO-ANTTA-01','APP-BLOKUV-01','APP-WTA-BLOKUV-01')
    and is_active
    and availability_status='available';

  if v_count<>4 then
    raise exception 'Approved starter equipment catalog is incomplete: %/4 items available.',v_count;
  end if;

  if not exists(
    select 1 from public.equipment_catalog_items
    where sku='SHO-ANTTA-01'
      and tour_scope='unisex'
      and price_usd=80
      and tier=1
  ) then
    raise exception 'Approved shared starter shoe is not configured correctly.';
  end if;
end;
$$;
