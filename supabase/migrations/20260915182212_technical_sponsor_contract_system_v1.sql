create table if not exists public.player_technical_sponsor_offers (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  brand_id uuid not null references public.technical_sponsor_brands(id) on delete cascade,
  category text not null check (category in ('racket','shoes','apparel')),
  offer_round_start_absolute_day integer not null,
  generated_absolute_day integer not null,
  available_from_absolute_day integer not null,
  expires_absolute_day integer not null,
  contract_weeks smallint not null check (contract_weeks between 1 and 104),
  discount_pct numeric(5,2) not null check (discount_pct between 0 and 90),
  premium_discount_bonus_pct numeric(5,2) not null default 0 check (premium_discount_bonus_pct between 0 and 25),
  free_equipment_allowance smallint not null default 0 check (free_equipment_allowance >= 0),
  free_replacement_allowance smallint not null default 0 check (free_replacement_allowance >= 0),
  maintenance_discount_pct numeric(5,2) not null default 0 check (maintenance_discount_pct between 0 and 90),
  player_rank integer not null,
  player_reputation smallint not null check (player_reputation between 0 and 100),
  recent_win_pct numeric(5,2) not null default 50 check (recent_win_pct between 0 and 100),
  requirements jsonb not null default '{}'::jsonb,
  is_renewal boolean not null default false,
  current_contract_id uuid,
  status text not null default 'open' check (status in ('open','accepted','declined','expired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(player_id,category,brand_id,offer_round_start_absolute_day)
);

create table if not exists public.player_technical_sponsor_contracts (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  brand_id uuid not null references public.technical_sponsor_brands(id) on delete restrict,
  category text not null check (category in ('racket','shoes','apparel')),
  offer_id uuid unique references public.player_technical_sponsor_offers(id) on delete set null,
  signed_absolute_day integer not null,
  start_absolute_day integer not null,
  end_absolute_day integer not null,
  contract_weeks smallint not null,
  discount_pct numeric(5,2) not null check (discount_pct between 0 and 90),
  premium_discount_bonus_pct numeric(5,2) not null default 0 check (premium_discount_bonus_pct between 0 and 25),
  free_equipment_allowance_total smallint not null default 0 check (free_equipment_allowance_total >= 0),
  free_equipment_allowance_used smallint not null default 0 check (free_equipment_allowance_used >= 0),
  free_replacements_total smallint not null default 0 check (free_replacements_total >= 0),
  free_replacements_used smallint not null default 0 check (free_replacements_used >= 0),
  maintenance_discount_pct numeric(5,2) not null default 0 check (maintenance_discount_pct between 0 and 90),
  player_rank_at_sign integer not null,
  player_reputation_at_sign smallint not null,
  status text not null check (status in ('active','scheduled','completed','terminated')),
  is_renewal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_absolute_day >= start_absolute_day),
  check (free_equipment_allowance_used <= free_equipment_allowance_total),
  check (free_replacements_used <= free_replacements_total)
);

create unique index if not exists player_technical_sponsor_contracts_one_current_category_idx
on public.player_technical_sponsor_contracts(player_id,category)
where status in ('active','scheduled');

create index if not exists player_technical_sponsor_offers_player_status_idx
on public.player_technical_sponsor_offers(player_id,status,category,expires_absolute_day);

create index if not exists player_technical_sponsor_contracts_player_status_idx
on public.player_technical_sponsor_contracts(player_id,status,category,end_absolute_day);

create table if not exists public.technical_sponsor_equipment_claims (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  contract_id uuid not null references public.player_technical_sponsor_contracts(id) on delete restrict,
  catalog_item_id uuid not null references public.equipment_catalog_items(id) on delete restrict,
  inventory_id uuid not null references public.player_equipment_inventory(id) on delete restrict,
  source_inventory_id uuid references public.player_equipment_inventory(id) on delete set null,
  claim_type text not null check (claim_type in ('allowance','replacement')),
  request_key text not null,
  claimed_absolute_day integer not null,
  created_at timestamptz not null default now(),
  unique(player_id,request_key)
);

alter table public.player_technical_sponsor_offers enable row level security;
alter table public.player_technical_sponsor_contracts enable row level security;
alter table public.technical_sponsor_equipment_claims enable row level security;
revoke all on public.player_technical_sponsor_offers from anon, authenticated;
revoke all on public.player_technical_sponsor_contracts from anon, authenticated;
revoke all on public.technical_sponsor_equipment_claims from anon, authenticated;

insert into public.notification_catalog(code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active)
values
('equipment.technical_sponsor.offer','equipment','Technical sponsor offers','New technical-equipment sponsorship proposals are available.','technical_sponsor_offer_generated','Eligible technical sponsor offers were generated.','database','Technical Sponsors','New technical sponsor offers','New technical sponsor proposals are available in Equipment.','/game/equipment','info',true,false,false,true,true),
('equipment.technical_sponsor.expiring','equipment','Technical sponsor expiring','An active technical sponsorship is approaching expiry.','technical_sponsor_contract_expiring','Technical sponsor contract has 28 or fewer days remaining.','database','Technical Sponsors','Technical sponsor contract expiring','A technical sponsor contract is approaching expiry. Review renewal and competing offers.','/game/equipment','warning',true,false,false,true,true),
('equipment.technical_sponsor.expired','equipment','Technical sponsor expired','A technical sponsorship has completed.','technical_sponsor_contract_expired','Technical sponsor contract end date has passed.','database','Technical Sponsors','Technical sponsor contract completed','A technical sponsor contract has ended and its equipment benefits are no longer active.','/game/equipment','info',true,false,false,true,true),
('equipment.technical_sponsor.signed','equipment','Technical sponsor signed','A technical sponsorship agreement has been signed.','technical_sponsor_contract_signed','Player accepts a technical sponsor offer.','database','Technical Sponsors','Technical sponsor agreement signed','A new technical sponsor agreement has been signed.','/game/equipment','success',true,false,false,true,true)
on conflict (code) do update set
  category=excluded.category,label=excluded.label,reason=excluded.reason,trigger_event=excluded.trigger_event,
  trigger_condition=excluded.trigger_condition,trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,
  title_template=excluded.title_template,message_template=excluded.message_template,default_route=excluded.default_route,
  severity=excluded.severity,default_in_app=excluded.default_in_app,is_active=true,updated_at=now();

create or replace function public.technical_sponsor_player_profile_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_rank integer:=9999;
  v_recent_total integer:=0;
  v_recent_wins integer:=0;
  v_career_wins integer:=0;
  v_recent_pct numeric:=50;
  v_base integer:=15;
  v_form_bonus integer:=0;
  v_win_bonus integer:=0;
  v_reputation integer:=15;
begin
  if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found.'; end if;
  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);

  select count(*),count(*) filter(where won)
  into v_recent_total,v_recent_wins
  from (
    select f.won
    from public.statistics_player_match_facts_v1 f
    where f.player_id=p_player_id
    order by f.season desc,f.scheduled_season_week desc,f.scheduled_day desc,f.match_id desc
    limit 12
  ) recent;

  select count(*) filter(where won) into v_career_wins
  from public.statistics_player_match_facts_v1 f where f.player_id=p_player_id;

  if v_recent_total>0 then v_recent_pct:=round((v_recent_wins::numeric/v_recent_total::numeric)*100,2); end if;

  v_base:=case
    when v_rank<=10 then 90
    when v_rank<=25 then 82
    when v_rank<=50 then 75
    when v_rank<=100 then 65
    when v_rank<=250 then 55
    when v_rank<=500 then 45
    when v_rank<=1000 then 35
    when v_rank<=2500 then 25
    else 15 end;
  v_form_bonus:=round(greatest(-5::numeric,least(10::numeric,(v_recent_pct-50)/5)))::integer;
  v_win_bonus:=least(10,floor(sqrt(greatest(0,v_career_wins)))::integer);
  v_reputation:=least(100,greatest(0,v_base+v_form_bonus+v_win_bonus));

  return jsonb_build_object('rank',v_rank,'reputation',v_reputation,'recent_win_pct',v_recent_pct,'recent_matches',v_recent_total,'career_wins',v_career_wins);
end;
$$;

create or replace function public.sync_player_technical_sponsor_contracts_v1(p_player_id uuid,p_absolute_day integer default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_abs integer:=p_absolute_day;
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  r record;
  v_completed integer:=0;
  v_activated integer:=0;
begin
  select owner_user_id into v_owner from public.players where id=p_player_id and player_type='human';
  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;
  if v_abs is null then select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day); end if;

  update public.player_technical_sponsor_offers set status='expired',updated_at=now()
  where player_id=p_player_id and status='open' and expires_absolute_day<v_abs;

  for r in
    select c.id,c.category,c.brand_id,b.name
    from public.player_technical_sponsor_contracts c join public.technical_sponsor_brands b on b.id=c.brand_id
    where c.player_id=p_player_id and c.status='active' and c.end_absolute_day<v_abs
    for update of c
  loop
    update public.player_technical_sponsor_contracts set status='completed',updated_at=now() where id=r.id;
    v_completed:=v_completed+1;
    perform public.emit_notification_v1(v_owner,p_player_id,'equipment.technical_sponsor.expired',
      r.name||' technical sponsorship completed',
      'Your '||case r.category when 'apparel' then 'Clothing' when 'shoes' then 'Shoe' else 'Racquet' end||' sponsorship with '||r.name||' has ended. Sponsor discounts are no longer active.',
      '/game/equipment',jsonb_build_object('contract_id',r.id,'category',r.category,'brand_id',r.brand_id),
      'technical-sponsor-expired:'||r.id::text);
  end loop;

  for r in
    select c.id,c.category,c.brand_id,b.name
    from public.player_technical_sponsor_contracts c join public.technical_sponsor_brands b on b.id=c.brand_id
    where c.player_id=p_player_id and c.status='scheduled' and c.start_absolute_day<=v_abs
      and not exists(select 1 from public.player_technical_sponsor_contracts a where a.player_id=c.player_id and a.category=c.category and a.status='active')
    for update of c
  loop
    update public.player_technical_sponsor_contracts set status='active',updated_at=now() where id=r.id;
    v_activated:=v_activated+1;
    perform public.emit_notification_v1(v_owner,p_player_id,'equipment.technical_sponsor.signed',
      r.name||' technical sponsorship started',
      'Your new '||case r.category when 'apparel' then 'Clothing' when 'shoes' then 'Shoe' else 'Racquet' end||' sponsorship with '||r.name||' is now active.',
      '/game/equipment',jsonb_build_object('contract_id',r.id,'category',r.category,'brand_id',r.brand_id),
      'technical-sponsor-started:'||r.id::text);
  end loop;

  for r in
    select c.id,c.category,c.brand_id,c.end_absolute_day,b.name
    from public.player_technical_sponsor_contracts c join public.technical_sponsor_brands b on b.id=c.brand_id
    where c.player_id=p_player_id and c.status='active' and c.end_absolute_day>=v_abs and c.end_absolute_day-v_abs<=28
  loop
    perform public.emit_notification_v1(v_owner,p_player_id,'equipment.technical_sponsor.expiring',
      r.name||' technical sponsorship expiring',
      'Your '||case r.category when 'apparel' then 'Clothing' when 'shoes' then 'Shoe' else 'Racquet' end||' deal with '||r.name||' has '||(r.end_absolute_day-v_abs+1)::text||' days remaining. Renewal and competing offers may be available.',
      '/game/equipment',jsonb_build_object('contract_id',r.id,'category',r.category,'brand_id',r.brand_id,'days_remaining',r.end_absolute_day-v_abs+1),
      'technical-sponsor-expiring:'||r.id::text);
  end loop;

  return jsonb_build_object('completed',v_completed,'activated',v_activated,'absolute_day',v_abs);
end;
$$;

create or replace function public.ensure_player_technical_sponsor_offers_v1(p_player_id uuid,p_force boolean default false)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  v_abs integer;
  v_round integer;
  v_profile jsonb;
  v_rank integer;
  v_rep integer;
  v_recent numeric;
  v_category text;
  v_active_id uuid;
  v_active_brand uuid;
  v_active_end integer;
  v_scheduled_id uuid;
  v_existing integer;
  v_needed integer;
  v_inserted integer;
  v_total integer:=0;
begin
  select owner_user_id into v_owner from public.players where id=p_player_id and player_type='human';
  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  perform public.sync_player_technical_sponsor_contracts_v1(p_player_id,v_abs);
  v_profile:=public.technical_sponsor_player_profile_v1(p_player_id);
  v_rank:=(v_profile->>'rank')::integer;
  v_rep:=(v_profile->>'reputation')::integer;
  v_recent:=(v_profile->>'recent_win_pct')::numeric;
  v_round:=v_abs-((v_abs-1)%14);

  foreach v_category in array array['apparel','shoes','racket'] loop
    v_active_id:=null;v_active_brand:=null;v_active_end:=null;v_scheduled_id:=null;
    select c.id,c.brand_id,c.end_absolute_day into v_active_id,v_active_brand,v_active_end
    from public.player_technical_sponsor_contracts c
    where c.player_id=p_player_id and c.category=v_category and c.status='active' and c.start_absolute_day<=v_abs and c.end_absolute_day>=v_abs
    limit 1;
    select c.id into v_scheduled_id from public.player_technical_sponsor_contracts c where c.player_id=p_player_id and c.category=v_category and c.status='scheduled' limit 1;
    if v_scheduled_id is not null then continue; end if;
    if v_active_id is not null and v_active_end-v_abs>28 then continue; end if;

    if p_force then
      delete from public.player_technical_sponsor_offers o
      where o.player_id=p_player_id and o.category=v_category and o.offer_round_start_absolute_day=v_round
        and o.status in ('open','declined','expired')
        and not exists(select 1 from public.player_technical_sponsor_contracts c where c.offer_id=o.id);
    end if;

    select count(*) into v_existing from public.player_technical_sponsor_offers o
    where o.player_id=p_player_id and o.category=v_category and o.offer_round_start_absolute_day=v_round;
    if v_existing>=3 then continue; end if;
    v_needed:=3-v_existing;

    with candidates as (
      select b.*,
        (case when v_rank<b.target_rank_best then greatest(0.25::numeric,v_rank::numeric/greatest(1,b.target_rank_best)::numeric) else 1::numeric end)
        * greatest(0.05::numeric,b.offer_probability) * greatest(0.05::numeric,b.rarity_weight)
        * (0.75 + 0.50*public.sponsor_hash_unit_v1(concat_ws(':','tech-fit',p_player_id::text,v_round::text,v_category,b.id::text)))
        + case when b.id=v_active_brand then 100 else 0 end as offer_score
      from public.technical_sponsor_brand_categories bc
      join public.technical_sponsor_brands b on b.id=bc.brand_id and b.is_active
      where bc.category=v_category
        and v_rank<=b.target_rank_worst
        and v_rep>=b.min_reputation
        and not exists(select 1 from public.player_technical_sponsor_offers o where o.player_id=p_player_id and o.category=v_category and o.offer_round_start_absolute_day=v_round and o.brand_id=b.id)
    ), picked as (
      select * from candidates order by offer_score desc,name limit v_needed
    )
    insert into public.player_technical_sponsor_offers(
      player_id,brand_id,category,offer_round_start_absolute_day,generated_absolute_day,available_from_absolute_day,expires_absolute_day,
      contract_weeks,discount_pct,premium_discount_bonus_pct,free_equipment_allowance,free_replacement_allowance,maintenance_discount_pct,
      player_rank,player_reputation,recent_win_pct,requirements,is_renewal,current_contract_id,status
    )
    select
      p_player_id,p.id,v_category,v_round,v_abs,coalesce(v_active_end+1,v_abs),v_abs+13,
      least(p.contract_weeks_max,greatest(p.contract_weeks_min,p.contract_weeks_min+floor(public.sponsor_hash_unit_v1(concat_ws(':','tech-weeks',p_player_id::text,v_round::text,p.id::text,v_category))*(p.contract_weeks_max-p.contract_weeks_min+1))::integer))::smallint,
      round(least(p.discount_max_pct,p.discount_min_pct+(p.discount_max_pct-p.discount_min_pct)*least(1::numeric,0.40+0.35*(v_rep::numeric/100)+0.25*public.sponsor_hash_unit_v1(concat_ws(':','tech-discount',p_player_id::text,v_round::text,p.id::text,v_category))))*2)/2,
      case when p.generosity>=65 then case p.tier when 'elite' then 5 when 'premium' then 3 when 'established' then 1.5 else 0 end else 0 end,
      least(p.free_equipment_max,greatest(p.free_equipment_min,p.free_equipment_min+floor(public.sponsor_hash_unit_v1(concat_ws(':','tech-free',p_player_id::text,v_round::text,p.id::text,v_category))*(p.free_equipment_max-p.free_equipment_min+1))::integer))::smallint,
      case when p.free_replacements then case when p.tier in ('elite','premium') then 2 else 1 end else 0 end::smallint,
      round(least(p.maintenance_discount_max_pct,p.maintenance_discount_min_pct+(p.maintenance_discount_max_pct-p.maintenance_discount_min_pct)*(0.40+0.60*public.sponsor_hash_unit_v1(concat_ws(':','tech-maint',p_player_id::text,v_round::text,p.id::text,v_category))))*2)/2,
      v_rank,v_rep,v_recent,
      jsonb_build_object('target_rank_best',p.target_rank_best,'target_rank_worst',p.target_rank_worst,'min_reputation',p.min_reputation,'player_rank',v_rank,'player_reputation',v_rep,'target_player_level',p.target_player_level),
      p.id=v_active_brand,v_active_id,'open'
    from picked p;
    get diagnostics v_inserted=row_count;
    v_total:=v_total+v_inserted;
    if v_inserted>0 then
      perform public.emit_notification_v1(v_owner,p_player_id,'equipment.technical_sponsor.offer',
        case v_category when 'apparel' then 'Clothing' when 'shoes' then 'Shoe' else 'Racquet' end||' sponsor offers available',
        v_inserted::text||' new '||lower(case v_category when 'apparel' then 'Clothing' when 'shoes' then 'Shoe' else 'Racquet' end)||' technical sponsor offer'||case when v_inserted=1 then ' is' else 's are' end||' available.',
        '/game/equipment',jsonb_build_object('category',v_category,'offer_round',v_round),
        'technical-sponsor-offers:'||p_player_id::text||':'||v_category||':'||v_round::text);
    end if;
  end loop;

  return jsonb_build_object('generated',v_total,'absolute_day',v_abs,'offer_round_start_absolute_day',v_round,'rank',v_rank,'reputation',v_rep,'recent_win_pct',v_recent);
end;
$$;

create or replace function public.decline_player_technical_sponsor_offer_v1(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_player uuid;v_updated uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  update public.player_technical_sponsor_offers set status='declined',updated_at=now()
  where id=p_offer_id and player_id=v_player and status='open' returning id into v_updated;
  if v_updated is null then raise exception 'Technical sponsor offer is not open.'; end if;
  return jsonb_build_object('status','declined','offer_id',v_updated);
end;
$$;

create or replace function public.sign_player_technical_sponsor_offer_v1(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_player uuid;v_owner uuid;v_offer public.player_technical_sponsor_offers%rowtype;v_active public.player_technical_sponsor_contracts%rowtype;
  v_contract public.player_technical_sponsor_contracts%rowtype;gd record;v_abs integer;v_start integer;v_status text;v_brand text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id,owner_user_id into v_player,v_owner from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);
  select * into v_offer from public.player_technical_sponsor_offers where id=p_offer_id and player_id=v_player for update;
  if v_offer.id is null then raise exception 'Technical sponsor offer not found.'; end if;
  if v_offer.status<>'open' then raise exception 'This technical sponsor offer is no longer open.'; end if;
  if v_offer.expires_absolute_day<v_abs then update public.player_technical_sponsor_offers set status='expired',updated_at=now() where id=v_offer.id; raise exception 'This technical sponsor offer has expired.'; end if;
  if exists(select 1 from public.player_technical_sponsor_contracts where player_id=v_player and category=v_offer.category and status='scheduled') then raise exception 'A future technical sponsor is already scheduled for this category.'; end if;
  select * into v_active from public.player_technical_sponsor_contracts where player_id=v_player and category=v_offer.category and status='active' and end_absolute_day>=v_abs limit 1 for update;
  if v_active.id is not null then
    if v_active.end_absolute_day-v_abs>28 then raise exception 'The current technical sponsor contract must be closer to expiry before a new agreement can be scheduled.'; end if;
    v_start:=v_active.end_absolute_day+1;v_status:='scheduled';
  else
    v_start:=v_abs;v_status:='active';
  end if;
  select name into v_brand from public.technical_sponsor_brands where id=v_offer.brand_id;
  insert into public.player_technical_sponsor_contracts(
    player_id,brand_id,category,offer_id,signed_absolute_day,start_absolute_day,end_absolute_day,contract_weeks,discount_pct,premium_discount_bonus_pct,
    free_equipment_allowance_total,free_replacements_total,maintenance_discount_pct,player_rank_at_sign,player_reputation_at_sign,status,is_renewal
  ) values(
    v_player,v_offer.brand_id,v_offer.category,v_offer.id,v_abs,v_start,v_start+(v_offer.contract_weeks::integer*7)-1,v_offer.contract_weeks,v_offer.discount_pct,v_offer.premium_discount_bonus_pct,
    v_offer.free_equipment_allowance,v_offer.free_replacement_allowance,v_offer.maintenance_discount_pct,v_offer.player_rank,v_offer.player_reputation,v_status,v_offer.is_renewal
  ) returning * into v_contract;
  update public.player_technical_sponsor_offers set status='accepted',updated_at=now() where id=v_offer.id;
  update public.player_technical_sponsor_offers set status='expired',updated_at=now() where player_id=v_player and category=v_offer.category and status='open' and id<>v_offer.id;
  perform public.emit_notification_v1(v_owner,v_player,'equipment.technical_sponsor.signed',
    v_brand||' technical sponsorship signed',
    case when v_status='active' then 'Your new ' else 'Your next ' end||case v_offer.category when 'apparel' then 'Clothing' when 'shoes' then 'Shoe' else 'Racquet' end||' sponsorship with '||v_brand||case when v_status='scheduled' then ' will begin when the current agreement ends.' else ' is active now.' end,
    '/game/equipment',jsonb_build_object('contract_id',v_contract.id,'category',v_contract.category,'brand_id',v_contract.brand_id,'status',v_status),
    'technical-sponsor-signed:'||v_contract.id::text);
  return jsonb_build_object('status',v_status,'contract_id',v_contract.id,'brand_id',v_contract.brand_id,'category',v_contract.category,'start_absolute_day',v_contract.start_absolute_day,'end_absolute_day',v_contract.end_absolute_day,'discount_pct',v_contract.discount_pct);
end;
$$;

create or replace function public.get_player_technical_sponsor_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_player uuid;gd record;v_abs integer;v_profile jsonb;v_contracts jsonb;v_offers jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);
  perform public.ensure_player_technical_sponsor_offers_v1(v_player,false);
  v_profile:=public.technical_sponsor_player_profile_v1(v_player);

  select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object(
    'days_remaining',greatest(0,c.end_absolute_day-v_abs+1),
    'free_equipment_remaining',greatest(0,c.free_equipment_allowance_total-c.free_equipment_allowance_used),
    'free_replacements_remaining',greatest(0,c.free_replacements_total-c.free_replacements_used),
    'brand',jsonb_build_object('id',b.id,'code',b.code,'name',b.name,'logo_url',b.logo_url,'tier',b.tier,'country_code',b.country_code,'region',b.region,'philosophy',b.philosophy)
  ) order by case c.category when 'apparel' then 1 when 'shoes' then 2 else 3 end,c.start_absolute_day),'[]'::jsonb)
  into v_contracts
  from public.player_technical_sponsor_contracts c join public.technical_sponsor_brands b on b.id=c.brand_id
  where c.player_id=v_player and c.status in ('active','scheduled');

  select coalesce(jsonb_agg(to_jsonb(o)||jsonb_build_object(
    'days_until_expiry',greatest(0,o.expires_absolute_day-v_abs+1),
    'brand',jsonb_build_object('id',b.id,'code',b.code,'name',b.name,'logo_url',b.logo_url,'tier',b.tier,'country_code',b.country_code,'region',b.region,'philosophy',b.philosophy,'prestige',b.prestige,'generosity',b.generosity,'target_player_level',b.target_player_level)
  ) order by case o.category when 'apparel' then 1 when 'shoes' then 2 else 3 end,o.discount_pct desc,b.prestige desc),'[]'::jsonb)
  into v_offers
  from public.player_technical_sponsor_offers o join public.technical_sponsor_brands b on b.id=o.brand_id
  where o.player_id=v_player and o.status='open' and o.expires_absolute_day>=v_abs;

  return jsonb_build_object('player_id',v_player,'current_absolute_day',v_abs,'player_profile',v_profile,'contracts',v_contracts,'offers',v_offers,'categories',jsonb_build_array('apparel','shoes','racket'),'renewal_window_days',28);
end;
$$;

create or replace function public.claim_technical_sponsor_equipment_v1(p_catalog_item_id uuid,p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_player uuid;v_key text:=btrim(coalesce(p_request_key,''));v_existing record;c public.equipment_catalog_items%rowtype;tc public.player_technical_sponsor_contracts%rowtype;gd record;v_abs integer;v_inventory uuid:=gen_random_uuid();
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';if v_player is null then raise exception 'Player not found.';end if;
  if length(v_key)<8 or length(v_key)>128 then raise exception 'Invalid claim request key.';end if;
  perform pg_advisory_xact_lock(hashtextextended('technical-equipment-claim:'||v_player::text||':'||v_key,0));
  select cl.inventory_id,cl.contract_id into v_existing from public.technical_sponsor_equipment_claims cl where cl.player_id=v_player and cl.request_key=v_key limit 1;
  if v_existing.inventory_id is not null then return jsonb_build_object('status','already_claimed','inventory_id',v_existing.inventory_id,'contract_id',v_existing.contract_id);end if;
  select * into gd from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);
  select * into c from public.equipment_catalog_items where id=p_catalog_item_id and is_active and availability_status<>'unavailable' and item_type in ('racket','shoes','apparel');
  if c.id is null or c.technical_brand_id is null then raise exception 'This equipment is not eligible for a technical sponsor claim.';end if;
  select * into tc from public.player_technical_sponsor_contracts where player_id=v_player and brand_id=c.technical_brand_id and category=c.item_type and status='active' and start_absolute_day<=v_abs and end_absolute_day>=v_abs limit 1 for update;
  if tc.id is null then raise exception 'No matching active technical sponsor contract.';end if;
  if tc.free_equipment_allowance_used>=tc.free_equipment_allowance_total then raise exception 'No free equipment allowance remains on this contract.';end if;
  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source,purchase_price_usd,purchase_request_key) values(v_inventory,v_player,c.id,100,v_abs,'sponsor',0,null);
  update public.player_technical_sponsor_contracts set free_equipment_allowance_used=free_equipment_allowance_used+1,updated_at=now() where id=tc.id;
  insert into public.technical_sponsor_equipment_claims(player_id,contract_id,catalog_item_id,inventory_id,claim_type,request_key,claimed_absolute_day) values(v_player,tc.id,c.id,v_inventory,'allowance',v_key,v_abs);
  return jsonb_build_object('status','claimed','inventory_id',v_inventory,'contract_id',tc.id,'remaining',tc.free_equipment_allowance_total-tc.free_equipment_allowance_used-1);
end;
$$;

create or replace function public.claim_technical_sponsor_replacement_v1(p_inventory_id uuid,p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_player uuid;v_key text:=btrim(coalesce(p_request_key,''));v_existing record;i public.player_equipment_inventory%rowtype;c public.equipment_catalog_items%rowtype;tc public.player_technical_sponsor_contracts%rowtype;gd record;v_abs integer;v_new uuid:=gen_random_uuid();
begin
  if auth.uid() is null then raise exception 'Authentication required.';end if;
  select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';if v_player is null then raise exception 'Player not found.';end if;
  if length(v_key)<8 or length(v_key)>128 then raise exception 'Invalid replacement request key.';end if;
  perform pg_advisory_xact_lock(hashtextextended('technical-equipment-replacement:'||v_player::text||':'||v_key,0));
  select cl.inventory_id,cl.contract_id into v_existing from public.technical_sponsor_equipment_claims cl where cl.player_id=v_player and cl.request_key=v_key limit 1;
  if v_existing.inventory_id is not null then return jsonb_build_object('status','already_claimed','inventory_id',v_existing.inventory_id,'contract_id',v_existing.contract_id);end if;
  select * into gd from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);
  select * into i from public.player_equipment_inventory where id=p_inventory_id and player_id=v_player for update;if i.id is null then raise exception 'Inventory item not found.';end if;
  select * into c from public.equipment_catalog_items where id=i.catalog_item_id and is_active and item_type in ('racket','shoes','apparel');if c.id is null or c.technical_brand_id is null then raise exception 'This equipment is not eligible for sponsor replacement.';end if;
  if i.condition>35 then raise exception 'Free sponsor replacement is available only at 35%% condition or lower.';end if;
  select * into tc from public.player_technical_sponsor_contracts where player_id=v_player and brand_id=c.technical_brand_id and category=c.item_type and status='active' and start_absolute_day<=v_abs and end_absolute_day>=v_abs limit 1 for update;
  if tc.id is null then raise exception 'No matching active technical sponsor contract.';end if;
  if tc.free_replacements_used>=tc.free_replacements_total then raise exception 'No free replacements remain on this contract.';end if;
  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source,purchase_price_usd,purchase_request_key) values(v_new,v_player,c.id,100,v_abs,'sponsor',0,null);
  if c.item_type='racket' then update public.player_equipment_loadouts set racket_inventory_id=v_new,updated_at=now() where player_id=v_player and racket_inventory_id=i.id;
  elsif c.item_type='shoes' then update public.player_equipment_loadouts set shoes_inventory_id=v_new,updated_at=now() where player_id=v_player and shoes_inventory_id=i.id;
  elsif c.item_type='apparel' then update public.player_equipment_loadouts set apparel_inventory_id=v_new,updated_at=now() where player_id=v_player and apparel_inventory_id=i.id;
  end if;
  update public.player_technical_sponsor_contracts set free_replacements_used=free_replacements_used+1,updated_at=now() where id=tc.id;
  insert into public.technical_sponsor_equipment_claims(player_id,contract_id,catalog_item_id,inventory_id,source_inventory_id,claim_type,request_key,claimed_absolute_day) values(v_player,tc.id,c.id,v_new,i.id,'replacement',v_key,v_abs);
  return jsonb_build_object('status','replaced','inventory_id',v_new,'source_inventory_id',i.id,'contract_id',tc.id,'remaining',tc.free_replacements_total-tc.free_replacements_used-1);
end;
$$;

create or replace function public.purchase_equipment_item_v2(p_catalog_item_id uuid,p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_player uuid;c public.equipment_catalog_items%rowtype;v_inventory uuid:=gen_random_uuid();v_existing public.player_equipment_inventory%rowtype;v_abs integer;v_key text:=btrim(coalesce(p_request_key,''));v_balance bigint:=0;f jsonb;v_contract uuid;v_discount numeric:=0;v_final bigint;
begin
  select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;if v_player is null then raise exception 'Player not found.';end if;
  if length(v_key)<8 or length(v_key)>128 then raise exception 'Invalid purchase request key.';end if;
  perform pg_advisory_xact_lock(hashtextextended('equipment-purchase:'||v_player::text||':'||v_key,0));
  select * into v_existing from public.player_equipment_inventory where player_id=v_player and purchase_request_key=v_key limit 1;
  if v_existing.id is not null then perform public.ensure_player_career_finance_v1(v_player);select balance into v_balance from public.player_career_finance_accounts where player_id=v_player;return jsonb_build_object('status','already_purchased','inventory_id',v_existing.id,'price_usd',v_existing.purchase_price_usd,'balance',coalesce(v_balance,0));end if;
  select * into c from public.equipment_catalog_items where id=p_catalog_item_id and is_active and availability_status='available';if c.id is null then raise exception 'Equipment item not available.';end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);
  if c.item_type in ('racket','shoes','apparel') and c.technical_brand_id is not null then
    select tc.id,least(80::numeric,tc.discount_pct+case when c.tier>=4 then tc.premium_discount_bonus_pct else 0 end)
    into v_contract,v_discount
    from public.player_technical_sponsor_contracts tc
    where tc.player_id=v_player and tc.status='active' and tc.category=c.item_type and tc.brand_id=c.technical_brand_id and tc.start_absolute_day<=v_abs and tc.end_absolute_day>=v_abs limit 1;
  end if;
  v_discount:=coalesce(v_discount,0);v_final:=greatest(1,round(c.price_usd::numeric*(100-v_discount)/100)::bigint);
  f:=public.post_career_finance_transaction_v1(v_player,-v_final,'equipment',c.item_type,'Equipment purchase — '||c.brand||' '||c.model,'equipment_catalog',c.id::text,'equipment-purchase:'||v_player::text||':'||v_key,jsonb_build_object('catalog_item_id',c.id,'sku',c.sku,'brand',c.brand,'model',c.model,'item_type',c.item_type,'purchase_request_key',v_key,'list_price_usd',c.price_usd,'technical_sponsor_contract_id',v_contract,'technical_sponsor_discount_pct',v_discount,'final_price_usd',v_final),true,v_abs);
  insert into public.player_equipment_inventory(id,player_id,catalog_item_id,condition,acquired_absolute_day,acquired_source,purchase_price_usd,purchase_request_key) values(v_inventory,v_player,c.id,100,v_abs,'purchase',v_final,v_key);
  return jsonb_build_object('status','purchased','inventory_id',v_inventory,'item_type',c.item_type,'list_price_usd',c.price_usd,'technical_sponsor_contract_id',v_contract,'technical_sponsor_discount_pct',v_discount,'price_usd',v_final,'balance',f->'balance');
end;
$$;

create or replace function public.get_equipment_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_player uuid;v_balance bigint:=0;v_loadout jsonb;v_inventory jsonb;v_catalog jsonb;gd record;v_abs integer;
begin
 select p.id into v_player from public.players p where p.owner_user_id=auth.uid() order by p.created_at desc limit 1;if v_player is null then raise exception 'Player not found.';end if;
 select * into gd from public.get_current_game_day_internal_v1();v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);
 perform public.initialize_player_equipment_v1(v_player);perform public.ensure_player_career_finance_v1(v_player);select balance into v_balance from public.player_career_finance_accounts where player_id=v_player;
 select jsonb_build_object('apparel_brand',l.apparel_brand,'racket_sponsor_name',l.racket_sponsor_name,'apparel_sponsor_name',l.apparel_sponsor_name,'footwear_sponsor_name',l.footwear_sponsor_name,'racket',case when ri.id is null then null else jsonb_build_object('inventory_id',ri.id,'condition',ri.condition,'item',to_jsonb(rc)||jsonb_build_object('brand_logo_url',rb.logo_url,'technical_brand_tier',rb.tier,'technical_brand_code',rb.code,'effective_gameplay_effects',public.scale_equipment_effects_v1(rc.gameplay_effects,ri.condition))) end,'shoes',case when shi.id is null then null else jsonb_build_object('inventory_id',shi.id,'condition',shi.condition,'item',to_jsonb(shc)||jsonb_build_object('brand_logo_url',shb.logo_url,'technical_brand_tier',shb.tier,'technical_brand_code',shb.code,'effective_gameplay_effects',public.scale_equipment_effects_v1(shc.gameplay_effects,shi.condition))) end,'apparel',case when api.id is null then null else jsonb_build_object('inventory_id',api.id,'condition',api.condition,'item',to_jsonb(apc)||jsonb_build_object('brand_logo_url',apb.logo_url,'technical_brand_tier',apb.tier,'technical_brand_code',apb.code,'effective_gameplay_effects',public.scale_equipment_effects_v1(apc.gameplay_effects,api.condition))) end,'accessories',coalesce((select jsonb_agg(jsonb_build_object('accessory_kind',al.accessory_kind,'inventory_id',ai.id,'condition',ai.condition,'item',to_jsonb(ac)||jsonb_build_object('brand_logo_url',ab.logo_url,'technical_brand_tier',ab.tier,'technical_brand_code',ab.code,'effective_gameplay_effects',public.scale_equipment_effects_v1(ac.gameplay_effects,ai.condition))) order by al.accessory_kind) from public.player_equipment_accessory_loadout al join public.player_equipment_inventory ai on ai.id=al.inventory_id and ai.player_id=al.player_id join public.equipment_catalog_items ac on ac.id=ai.catalog_item_id and ac.is_active left join public.technical_sponsor_brands ab on ab.id=ac.technical_brand_id where al.player_id=l.player_id),'[]'::jsonb)) into v_loadout from public.player_equipment_loadouts l left join public.player_equipment_inventory ri on ri.id=l.racket_inventory_id and ri.player_id=l.player_id left join public.equipment_catalog_items rc on rc.id=ri.catalog_item_id and rc.is_active left join public.technical_sponsor_brands rb on rb.id=rc.technical_brand_id left join public.player_equipment_inventory shi on shi.id=l.shoes_inventory_id and shi.player_id=l.player_id left join public.equipment_catalog_items shc on shc.id=shi.catalog_item_id and shc.is_active left join public.technical_sponsor_brands shb on shb.id=shc.technical_brand_id left join public.player_equipment_inventory api on api.id=l.apparel_inventory_id and api.player_id=l.player_id left join public.equipment_catalog_items apc on apc.id=api.catalog_item_id and apc.is_active left join public.technical_sponsor_brands apb on apb.id=apc.technical_brand_id where l.player_id=v_player;
 select coalesce(jsonb_agg(jsonb_build_object('inventory_id',i.id,'condition',i.condition,'acquired_source',i.acquired_source,'acquired_absolute_day',i.acquired_absolute_day,'purchase_price_usd',i.purchase_price_usd,'is_equipped',(coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false) or coalesce(i.id=l.apparel_inventory_id,false) or exists(select 1 from public.player_equipment_accessory_loadout al where al.player_id=i.player_id and al.inventory_id=i.id)),'resell_supported',(i.acquired_source='purchase' and c.is_resellable),'can_sell',(i.acquired_source='purchase' and c.is_resellable and not (coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false) or coalesce(i.id=l.apparel_inventory_id,false) or exists(select 1 from public.player_equipment_accessory_loadout al where al.player_id=i.player_id and al.inventory_id=i.id)) and public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier)>0),'sell_block_reason',case when i.acquired_source<>'purchase' then 'Starter, sponsored and reward equipment cannot be sold.' when not c.is_resellable then 'This equipment item cannot be resold.' when coalesce(i.id=l.racket_inventory_id,false) or coalesce(i.id=l.shoes_inventory_id,false) or coalesce(i.id=l.apparel_inventory_id,false) or exists(select 1 from public.player_equipment_accessory_loadout al where al.player_id=i.player_id and al.inventory_id=i.id) then 'Equip a replacement before selling this item.' when public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier)<=0 then 'This equipment has no resale value.' else null end,'resale_value_usd',public.calculate_equipment_resale_value_v1(i.purchase_price_usd,i.condition,c.resale_modifier),'sponsor_replacements_remaining',coalesce(tc.free_replacements_total-tc.free_replacements_used,0),'sponsor_replacement_available',(tc.id is not null and i.condition<=35 and tc.free_replacements_used<tc.free_replacements_total),'item',to_jsonb(c)||jsonb_build_object('brand_logo_url',b.logo_url,'technical_brand_tier',b.tier,'technical_brand_code',b.code,'effective_gameplay_effects',public.scale_equipment_effects_v1(c.gameplay_effects,i.condition))) order by c.item_type,c.sort_order,i.created_at),'[]'::jsonb) into v_inventory from public.player_equipment_inventory i join public.equipment_catalog_items c on c.id=i.catalog_item_id and c.is_active and c.item_type in ('racket','shoes','apparel','accessory') left join public.technical_sponsor_brands b on b.id=c.technical_brand_id join public.player_equipment_loadouts l on l.player_id=i.player_id left join public.player_technical_sponsor_contracts tc on tc.player_id=i.player_id and tc.status='active' and tc.category=c.item_type and tc.brand_id=c.technical_brand_id and tc.start_absolute_day<=v_abs and tc.end_absolute_day>=v_abs where i.player_id=v_player;
 select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('brand_logo_url',b.logo_url,'technical_brand_tier',b.tier,'technical_brand_code',b.code,'technical_sponsor_contract_id',tc.id,'technical_sponsor_discount_pct',coalesce(least(80::numeric,tc.discount_pct+case when c.tier>=4 then tc.premium_discount_bonus_pct else 0 end),0),'sponsor_final_price_usd',case when tc.id is null then c.price_usd else greatest(1,round(c.price_usd::numeric*(100-least(80::numeric,tc.discount_pct+case when c.tier>=4 then tc.premium_discount_bonus_pct else 0 end))/100)::bigint) end,'sponsor_free_equipment_remaining',coalesce(tc.free_equipment_allowance_total-tc.free_equipment_allowance_used,0),'sponsor_free_claim_available',(tc.id is not null and tc.free_equipment_allowance_used<tc.free_equipment_allowance_total)) order by c.item_type,c.sort_order),'[]'::jsonb) into v_catalog from public.equipment_catalog_items c left join public.technical_sponsor_brands b on b.id=c.technical_brand_id left join public.player_technical_sponsor_contracts tc on tc.player_id=v_player and tc.status='active' and tc.category=c.item_type and tc.brand_id=c.technical_brand_id and tc.start_absolute_day<=v_abs and tc.end_absolute_day>=v_abs where c.is_active and c.availability_status<>'unavailable' and c.item_type in ('racket','shoes','apparel','accessory');
 return jsonb_build_object('player_id',v_player,'currency','USD','balance',coalesce(v_balance,0),'loadout',coalesce(v_loadout,'{}'::jsonb),'inventory',v_inventory,'catalog',v_catalog,'resale_base_percent',65,'effects',jsonb_build_object('hard',public.get_equipment_match_modifiers_internal_v1(v_player,'hard'),'clay',public.get_equipment_match_modifiers_internal_v1(v_player,'clay'),'grass',public.get_equipment_match_modifiers_internal_v1(v_player,'grass')),'wear_rules',jsonb_build_object('racket_default',1.50,'shoes_all_court',3.68,'shoes_surface_specific',2.60,'shoes_wrong_surface',4.68,'apparel_typical',1.40,'accessory_profiles',jsonb_build_object('bag',0.35,'cap',0.70,'towel',3.00,'bottle',12.50,'dampener',2.00,'overgrip',5.00,'wristband',1.50),'condition_precision',0.01));
end;
$$;

revoke execute on function public.technical_sponsor_player_profile_v1(uuid) from public,anon,authenticated;
revoke execute on function public.sync_player_technical_sponsor_contracts_v1(uuid,integer) from public,anon,authenticated;
revoke execute on function public.ensure_player_technical_sponsor_offers_v1(uuid,boolean) from public,anon,authenticated;

revoke execute on function public.get_player_technical_sponsor_dashboard_v1() from public,anon;
grant execute on function public.get_player_technical_sponsor_dashboard_v1() to authenticated;
revoke execute on function public.sign_player_technical_sponsor_offer_v1(uuid) from public,anon;
grant execute on function public.sign_player_technical_sponsor_offer_v1(uuid) to authenticated;
revoke execute on function public.decline_player_technical_sponsor_offer_v1(uuid) from public,anon;
grant execute on function public.decline_player_technical_sponsor_offer_v1(uuid) to authenticated;
revoke execute on function public.claim_technical_sponsor_equipment_v1(uuid,text) from public,anon;
grant execute on function public.claim_technical_sponsor_equipment_v1(uuid,text) to authenticated;
revoke execute on function public.claim_technical_sponsor_replacement_v1(uuid,text) from public,anon;
grant execute on function public.claim_technical_sponsor_replacement_v1(uuid,text) to authenticated;
revoke execute on function public.purchase_equipment_item_v2(uuid,text) from public,anon;
grant execute on function public.purchase_equipment_item_v2(uuid,text) to authenticated;
revoke execute on function public.get_equipment_dashboard_v1() from public,anon;
grant execute on function public.get_equipment_dashboard_v1() to authenticated;
