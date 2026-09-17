-- Technical sponsors are discount-only. Retain signing bonuses and premium-tier discount bonuses,
-- but retire free item/replacement/maintenance allowances from current and future deals.

update public.player_technical_sponsor_offers
set free_equipment_allowance = 0,
    free_replacement_allowance = 0,
    maintenance_discount_pct = 0,
    updated_at = now()
where free_equipment_allowance <> 0
   or free_replacement_allowance <> 0
   or maintenance_discount_pct <> 0;

update public.player_technical_sponsor_contracts
set free_equipment_allowance_total = 0,
    free_equipment_allowance_used = 0,
    free_replacements_total = 0,
    free_replacements_used = 0,
    maintenance_discount_pct = 0,
    updated_at = now()
where free_equipment_allowance_total <> 0
   or free_equipment_allowance_used <> 0
   or free_replacements_total <> 0
   or free_replacements_used <> 0
   or maintenance_discount_pct <> 0;

create or replace function public.ensure_player_technical_sponsor_offers_v1(p_player_id uuid, p_force boolean default false)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  gd record;v_abs integer;v_season_end integer;v_rank integer;g jsonb;v_cat text;
  v_active public.player_technical_sponsor_contracts%rowtype;v_available integer;v_target_end integer;v_target_season integer;
  v_offer_count integer;v_existing integer;v_round integer;v_tiers text[];v_expiry integer;r record;
  v_discount numeric;v_premium numeric;v_bonus bigint;v_weeks smallint;
begin
  if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_season_end:=public.game_day_absolute_v1(gd.season,12::smallint,31::smallint);
  perform public.sync_player_technical_sponsor_contracts_v1(p_player_id,v_abs);
  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);
  g:=public.technical_sponsor_rank_group_v2(v_rank);v_offer_count:=(g->>'offer_count')::integer;
  update public.player_technical_sponsor_offers set status='expired',updated_at=now() where player_id=p_player_id and status='open' and expires_absolute_day<v_abs;
  foreach v_cat in array array['apparel','shoes','racket'] loop
    v_active:=null;
    select * into v_active from public.player_technical_sponsor_contracts where player_id=p_player_id and category=v_cat and status='active' and start_absolute_day<=v_abs and end_absolute_day>=v_abs order by end_absolute_day desc limit 1;
    if exists(select 1 from public.player_technical_sponsor_contracts where player_id=p_player_id and category=v_cat and status='scheduled') then continue; end if;
    if v_active.id is not null and v_active.end_absolute_day-v_abs>28 then continue; end if;
    v_available:=case when v_active.id is null then v_abs else v_active.end_absolute_day+1 end;
    v_target_season:=case when v_active.id is null then gd.season else gd.season+1 end;
    v_target_end:=public.game_day_absolute_v1(v_target_season,12::smallint,31::smallint);
    v_weeks:=greatest(1,ceil((v_target_end-v_available+1)/7.0))::smallint;
    v_expiry:=least(v_abs+13,case when v_active.id is null then v_season_end else v_active.end_absolute_day end);v_round:=v_abs;
    if p_force then update public.player_technical_sponsor_offers set status='expired',updated_at=now() where player_id=p_player_id and category=v_cat and status='open'; end if;
    select count(*) into v_existing from public.player_technical_sponsor_offers where player_id=p_player_id and category=v_cat and available_from_absolute_day=v_available and generated_absolute_day>=v_abs-13 and status in ('open','declined','accepted');
    if v_existing>0 and not p_force then continue; end if;
    v_tiers:=case g->>'code' when 'group_1' then array['elite','premium'] when 'group_2' then array['elite','premium','established'] when 'group_3' then array['premium','established'] when 'group_4' then array['established','entry'] else array['entry','established'] end;
    for r in
      select b.*,bc.category from public.technical_sponsor_brands b join public.technical_sponsor_brand_categories bc on bc.brand_id=b.id and bc.category=v_cat
      where b.is_active and b.tier=any(v_tiers)
      order by (v_active.id is not null and b.id=v_active.brand_id) desc,md5(b.id::text||':'||p_player_id::text||':'||v_cat||':'||v_abs::text)
      limit v_offer_count
    loop
      v_discount:=round(((g->>'discount_min')::numeric+((g->>'discount_max')::numeric-(g->>'discount_min')::numeric)*(coalesce(r.generosity,50)::numeric/100.0))::numeric,1);
      v_premium:=round(((g->>'premium_min')::numeric+((g->>'premium_max')::numeric-(g->>'premium_min')::numeric)*(coalesce(r.contract_strength,50)::numeric/100.0))::numeric,1);
      v_bonus:=round((g->>'bonus_min')::numeric+((g->>'bonus_max')::numeric-(g->>'bonus_min')::numeric)*((coalesce(r.prestige,50)+coalesce(r.generosity,50))::numeric/200.0))::bigint;
      insert into public.player_technical_sponsor_offers(player_id,brand_id,category,offer_round_start_absolute_day,generated_absolute_day,available_from_absolute_day,expires_absolute_day,contract_weeks,discount_pct,premium_discount_bonus_pct,free_equipment_allowance,free_replacement_allowance,maintenance_discount_pct,player_rank,player_reputation,recent_win_pct,requirements,is_renewal,current_contract_id,status,signing_bonus_usd,updated_at)
      values(p_player_id,r.id,v_cat,v_round,v_abs,v_available,v_expiry,v_weeks,v_discount,v_premium,0,0,0,v_rank,0,0,jsonb_build_object('rank_group',g->>'code','rank_group_label',g->>'label','rank_best',(g->>'rank_best')::integer,'rank_worst',(g->>'rank_worst')::integer,'eligibility_basis','current_ranking_only','equipment_benefit_model','discount_only'),(v_active.id is not null and r.id=v_active.brand_id),v_active.id,'open',v_bonus,now())
      on conflict(player_id,category,brand_id,offer_round_start_absolute_day) do update set generated_absolute_day=excluded.generated_absolute_day,available_from_absolute_day=excluded.available_from_absolute_day,expires_absolute_day=excluded.expires_absolute_day,contract_weeks=excluded.contract_weeks,discount_pct=excluded.discount_pct,premium_discount_bonus_pct=excluded.premium_discount_bonus_pct,free_equipment_allowance=0,free_replacement_allowance=0,maintenance_discount_pct=0,player_rank=excluded.player_rank,player_reputation=0,recent_win_pct=0,requirements=excluded.requirements,is_renewal=excluded.is_renewal,current_contract_id=excluded.current_contract_id,status='open',signing_bonus_usd=excluded.signing_bonus_usd,updated_at=now();
    end loop;
  end loop;
  return jsonb_build_object('status','ok','rank',v_rank,'rank_group',g->>'code','rank_group_label',g->>'label','offer_count_per_open_slot',v_offer_count,'equipment_benefit_model','discount_only');
end;
$function$;

create or replace function public.sign_player_technical_sponsor_offer_v1(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  o public.player_technical_sponsor_offers%rowtype;
  c public.player_technical_sponsor_contracts%rowtype;
  a public.player_technical_sponsor_contracts%rowtype;
  b public.technical_sponsor_brands%rowtype;
  gd record;
  v_abs integer;
  v_start integer;
  v_end integer;
  v_season integer;
  v_status text;
  v_weeks smallint;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  perform public.sync_player_technical_sponsor_contracts_v1(v_player,v_abs);

  select * into o from public.player_technical_sponsor_offers where id=p_offer_id and player_id=v_player for update;
  if o.id is null then raise exception 'Technical sponsor offer not found.'; end if;
  if o.status<>'open' then raise exception 'This technical sponsor offer is no longer open.'; end if;
  if o.expires_absolute_day<v_abs then
    update public.player_technical_sponsor_offers set status='expired',updated_at=now() where id=o.id;
    raise exception 'This technical sponsor offer has expired.';
  end if;

  select * into a from public.player_technical_sponsor_contracts
  where player_id=v_player and category=o.category and status='active'
    and start_absolute_day<=v_abs and end_absolute_day>=v_abs
  order by end_absolute_day desc limit 1;

  if exists(select 1 from public.player_technical_sponsor_contracts where player_id=v_player and category=o.category and status='scheduled') then
    raise exception 'A future technical sponsor is already signed for this category.';
  end if;

  if a.id is null then
    v_start:=v_abs;
    v_season:=gd.season;
    v_status:='active';
  else
    if a.end_absolute_day-v_abs>28 then raise exception 'Your current technical sponsor contract must reach its final 28 days before a next deal can be signed.'; end if;
    v_start:=a.end_absolute_day+1;
    v_season:=gd.season+1;
    v_status:='scheduled';
  end if;
  v_end:=public.game_day_absolute_v1(v_season,12::smallint,31::smallint);
  v_weeks:=greatest(1,ceil((v_end-v_start+1)/7.0))::smallint;

  insert into public.player_technical_sponsor_contracts(
    player_id,brand_id,category,offer_id,signed_absolute_day,start_absolute_day,end_absolute_day,contract_weeks,
    discount_pct,premium_discount_bonus_pct,free_equipment_allowance_total,free_equipment_allowance_used,
    free_replacements_total,free_replacements_used,maintenance_discount_pct,player_rank_at_sign,player_reputation_at_sign,
    status,is_renewal,signing_bonus_usd
  ) values(
    v_player,o.brand_id,o.category,o.id,v_abs,v_start,v_end,v_weeks,
    o.discount_pct,o.premium_discount_bonus_pct,0,0,
    0,0,0,o.player_rank,0,
    v_status,o.is_renewal,o.signing_bonus_usd
  ) returning * into c;

  update public.player_technical_sponsor_offers set status='accepted',free_equipment_allowance=0,free_replacement_allowance=0,maintenance_discount_pct=0,updated_at=now() where id=o.id;
  update public.player_technical_sponsor_offers set status='expired',updated_at=now()
  where player_id=v_player and category=o.category and status='open' and id<>o.id;

  select * into b from public.technical_sponsor_brands where id=o.brand_id;
  if o.signing_bonus_usd>0 then
    perform public.post_career_finance_transaction_v1(
      v_player,o.signing_bonus_usd,'sponsorship','technical_signing_bonus',
      coalesce(b.name,'Technical sponsor')||' technical sponsorship signing bonus',
      'technical_sponsor_contract',c.id::text,'technical-sponsor-signing:'||c.id::text,
      jsonb_build_object('contract_id',c.id,'brand_id',o.brand_id,'category',o.category,'taxable',true),false,v_abs
    );
  end if;

  return jsonb_build_object('status',v_status,'contract_id',c.id,'brand_id',c.brand_id,'category',c.category,
    'start_absolute_day',c.start_absolute_day,'end_absolute_day',c.end_absolute_day,'signing_bonus_usd',c.signing_bonus_usd,
    'discount_pct',c.discount_pct,'equipment_benefit_model','discount_only');
end;
$function$;

create or replace function public.claim_technical_sponsor_equipment_v1(p_catalog_item_id uuid, p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  raise exception 'Free technical-sponsor equipment has been retired. Sponsored equipment is purchased through the Marketplace at the contract discount.';
end;
$function$;

create or replace function public.claim_technical_sponsor_replacement_v1(p_inventory_id uuid, p_request_key text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  raise exception 'Free technical-sponsor replacements have been retired. Replace worn equipment through normal Marketplace purchases.';
end;
$function$;
