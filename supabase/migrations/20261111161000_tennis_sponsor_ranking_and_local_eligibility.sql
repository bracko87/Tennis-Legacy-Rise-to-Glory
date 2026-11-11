-- Ranking-grade sponsorship for new seasons; no changes to paused game data.
-- Exact final-season snapshot wins on the last day / next-season opening week.
CREATE OR REPLACE FUNCTION public.sponsor_offer_rank_v1(p_player_id uuid,p_target_season integer)
RETURNS integer LANGUAGE sql STABLE SET search_path TO 'public'
AS $fn$
 SELECT greatest(1,coalesce(
   CASE WHEN p_target_season>1 AND
      EXISTS(SELECT 1 FROM public.game_clock g WHERE g.id=1 AND
        ((g.season=p_target_season AND g.month=1 AND g.day<=7) OR
         (g.season=p_target_season-1 AND g.month=12 AND g.day=31)))
      THEN (SELECT h.ranking_position FROM public.player_ranking_snapshots h
        WHERE h.player_id=p_player_id AND h.season=p_target_season-1
          AND h.game_absolute_day=public.game_day_absolute_v1((p_target_season-1),12::smallint,31::smallint)
        ORDER BY h.created_at DESC LIMIT 1)
      ELSE NULL::integer END,
   public.player_current_rank_position_v1(p_player_id)::integer,9999));
$fn$;
REVOKE ALL ON FUNCTION public.sponsor_offer_rank_v1(uuid,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.ensure_player_sponsor_offers_v1(p_player_id uuid, p_force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  gd record;
  v_abs integer;
  v_season_start integer;
  v_season_end integer;
  v_week_start integer;
  v_week_end integer;
  v_group_code text;
  v_rank integer;
  v_rule public.sponsor_offer_rules%rowtype;
  v_offer_count integer;
  v_progress numeric;
  v_local_share numeric;
  v_local_target integer;
  v_local_inserted integer:=0;
  v_world_target integer:=0;
  v_world_inserted integer:=0;
  v_value_progress numeric;
  v_base_full_value numeric;
  v_first_payment integer;
  v_payment_count integer;
  v_existing integer;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  if v_player.player_type<>'human' or v_player.owner_user_id is null then raise exception 'Sponsor offers are available to human players only.'; end if;
  if v_uid is not null and v_player.owner_user_id<>v_uid then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_season_start:=public.game_day_absolute_v1(gd.season,1::smallint,1::smallint);
  v_season_end:=public.game_day_absolute_v1(gd.season,12::smallint,31::smallint);
  v_week_start:=v_season_start + ((v_abs-v_season_start)/7)*7;
  v_week_end:=least(v_week_start+6,v_season_end);

  update public.player_sponsor_offers
  set status='expired',updated_at=now()
  where player_id=p_player_id and status='open' and expires_absolute_day<v_abs;

  if exists(select 1 from public.player_sponsor_contracts where player_id=p_player_id and season=gd.season and status='active') then
    return jsonb_build_object('status','active_contract','generated',0,'week_start_absolute_day',v_week_start);
  end if;

  select gm.group_code into v_group_code
  from public.sponsor_market_group_members gm
  where gm.country_code=v_player.country_code;
  if v_group_code is null then raise exception 'No sponsor market group is configured for player country %.',v_player.country_code; end if;

  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(p_player_id,gd.season),9999)::integer);
  select * into v_rule
  from public.sponsor_offer_rules r
  where r.is_active and v_rank>=r.rank_min and (r.rank_max is null or v_rank<=r.rank_max)
  order by r.rank_min desc limit 1;
  if v_rule.code is null then raise exception 'No sponsor offer rule for ranking %.',v_rank; end if;

  select count(*) into v_existing
  from public.player_sponsor_offers
  where player_id=p_player_id and season=gd.season and offer_week_start_absolute_day=v_week_start;
  if v_existing>0 and not p_force then
    return jsonb_build_object('status','already_generated','generated',v_existing,'week_start_absolute_day',v_week_start);
  end if;

  if p_force then
    delete from public.player_sponsor_offers o
    where o.player_id=p_player_id and o.season=gd.season and o.offer_week_start_absolute_day=v_week_start
      and o.status in ('open','declined','expired')
      and not exists(select 1 from public.player_sponsor_contracts c where c.offer_id=o.id);
  end if;

  v_offer_count:=v_rule.offer_count_min + floor(
    public.sponsor_hash_unit_v1(concat_ws(':','count',p_player_id::text,gd.season::text,v_week_start::text,v_rank::text))
    *(v_rule.offer_count_max-v_rule.offer_count_min+1)
  )::integer;
  v_offer_count:=least(v_rule.offer_count_max,greatest(v_rule.offer_count_min,v_offer_count));

  if v_rule.rank_max is null or v_rule.rank_max=v_rule.rank_min then
    v_progress:=case when v_rule.rank_max is null then least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/699::numeric)) else 0 end;
  else
    v_progress:=least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/(v_rule.rank_max-v_rule.rank_min)::numeric));
  end if;
  v_local_share:=v_rule.local_share_start + v_progress*(v_rule.local_share_end-v_rule.local_share_start);
  v_local_target:=least(v_offer_count,greatest(0,round(v_offer_count*v_local_share)::integer));
  v_value_progress:=v_progress;
  v_base_full_value:=v_rule.full_season_value_max - v_value_progress*(v_rule.full_season_value_max-v_rule.full_season_value_min);
  v_first_payment:=least(v_abs+6,v_season_end);
  v_payment_count:=floor((v_season_end-v_first_payment)::numeric/7)::integer+1;

  with candidates as (
    select s.id,
      row_number() over(order by public.sponsor_hash_unit_v1(concat_ws(':','local',p_player_id::text,gd.season::text,v_week_start::text,s.id::text)),s.id) rn
    from public.sponsor_companies s
    join public.sponsor_market_group_members gm on gm.country_code=s.country_code
    where s.sponsor_kind='main' and s.is_active and NOT s.is_worldwide and gm.group_code=v_group_code
  ), picked as (
    select id from candidates where rn<=v_local_target
  ), valued as (
    select p.id,
      greatest(v_rule.full_season_value_min,
        least(v_rule.full_season_value_max,
          round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(concat_ws(':','value',p_player_id::text,gd.season::text,v_week_start::text,p.id::text))))/100::numeric)*100
        )
      )::bigint full_value
    from picked p
  ), money as (
    select id,full_value,
      greatest(50::bigint,(round((full_value::numeric/52::numeric)/10::numeric)*10)::bigint) weekly_value
    from valued
  )
  insert into public.player_sponsor_offers(
    player_id,sponsor_company_id,season,offer_rule_code,offer_week_start_absolute_day,generated_absolute_day,
    expires_absolute_day,first_payment_absolute_day,player_rank,player_market_group_code,source_pool,
    full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value
  )
  select p_player_id,m.id,gd.season,v_rule.code,v_week_start,v_abs,v_week_end,v_first_payment,v_rank,v_group_code,'market',
    m.full_value,m.weekly_value,v_payment_count,m.weekly_value*v_payment_count
  from money m
  on conflict do nothing;
  get diagnostics v_local_inserted=row_count;

  v_world_target:=case when v_rank<=300 then greatest(0,v_offer_count-v_local_inserted) else 0 end;

  if v_world_target>0 then
    with candidates as (
      select s.id,
        row_number() over(order by public.sponsor_hash_unit_v1(concat_ws(':','worldwide',p_player_id::text,gd.season::text,v_week_start::text,s.id::text)),s.id) rn
      from public.sponsor_companies s
      where s.sponsor_kind='main' and s.is_active and s.is_worldwide
        and not exists(
          select 1 from public.player_sponsor_offers o
          where o.player_id=p_player_id and o.season=gd.season and o.offer_week_start_absolute_day=v_week_start and o.sponsor_company_id=s.id
        )
    ), picked as (
      select id from candidates where rn<=v_world_target
    ), valued as (
      select p.id,
        greatest(v_rule.full_season_value_min,
          least(v_rule.full_season_value_max,
            round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(concat_ws(':','value',p_player_id::text,gd.season::text,v_week_start::text,p.id::text))))/100::numeric)*100
          )
        )::bigint full_value
      from picked p
    ), money as (
      select id,full_value,
        greatest(50::bigint,(round((full_value::numeric/52::numeric)/10::numeric)*10)::bigint) weekly_value
      from valued
    )
    insert into public.player_sponsor_offers(
      player_id,sponsor_company_id,season,offer_rule_code,offer_week_start_absolute_day,generated_absolute_day,
      expires_absolute_day,first_payment_absolute_day,player_rank,player_market_group_code,source_pool,
      full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value
    )
    select p_player_id,m.id,gd.season,v_rule.code,v_week_start,v_abs,v_week_end,v_first_payment,v_rank,v_group_code,'worldwide',
      m.full_value,m.weekly_value,v_payment_count,m.weekly_value*v_payment_count
    from money m
    on conflict do nothing;
    get diagnostics v_world_inserted=row_count;
  end if;

  return jsonb_build_object(
    'status','generated','generated',v_local_inserted+v_world_inserted,'requested',v_offer_count,
    'local',v_local_inserted,'worldwide',v_world_inserted,'rank',v_rank,'market_group_code',v_group_code,
    'local_share',v_local_share,'week_start_absolute_day',v_week_start,'expires_absolute_day',v_week_end
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_player_technical_sponsor_offers_v1(p_player_id uuid, p_force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(p_player_id,gd.season),9999)::integer);
  g:=public.technical_sponsor_rank_group_v2(v_rank);v_offer_count:=(g->>'offer_count')::integer;
  update public.player_technical_sponsor_offers set status='expired',updated_at=now() where player_id=p_player_id and status='open' and expires_absolute_day<v_abs;
  foreach v_cat in array array['apparel','shoes','racket'] loop
    v_active:=null;
    select * into v_active from public.player_technical_sponsor_contracts where player_id=p_player_id and category=v_cat and status='active' and start_absolute_day<=v_abs and end_absolute_day>=v_abs order by end_absolute_day desc limit 1;
    if exists(select 1 from public.player_technical_sponsor_contracts where player_id=p_player_id and category=v_cat and status='scheduled') then continue; end if;
    if v_active.id is not null and v_active.end_absolute_day-v_abs>28 then continue; end if;
    v_available:=case when v_active.id is null then v_abs else v_active.end_absolute_day+1 end;
    v_target_season:=case when v_active.id is null then gd.season else gd.season+1 end;
    v_rank:=public.sponsor_offer_rank_v1(p_player_id,v_target_season);
    g:=public.technical_sponsor_rank_group_v2(v_rank);
    v_offer_count:=(g->>'offer_count')::integer;
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_sponsor_dashboard_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  gd record;
  v_abs integer;
  v_season_start integer;
  v_season_end integer;
  v_rank integer;
  v_group_code text;
  v_group_name text;
  v_macro text;
  v_rule public.sponsor_offer_rules%rowtype;
  v_progress numeric;
  v_local_share numeric;
  v_contract_row public.player_sponsor_contracts%rowtype;
  v_contract jsonb;
  v_offers jsonb;
  v_next_payment integer;
  v_received bigint:=0;
  v_week_start integer;
  v_next_refresh integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_season_start:=public.game_day_absolute_v1(gd.season,1::smallint,1::smallint);
  v_season_end:=public.game_day_absolute_v1(gd.season,12::smallint,31::smallint);
  v_week_start:=v_season_start+((v_abs-v_season_start)/7)*7;
  v_next_refresh:=least(v_week_start+7,v_season_end);

  perform public.process_player_sponsor_payments_v1(v_player.id,v_abs);
  perform public.ensure_player_sponsor_offers_v1(v_player.id,false);

  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(v_player.id,gd.season),9999)::integer);
  select gm.group_code,g.name,g.macro_region into v_group_code,v_group_name,v_macro
  from public.sponsor_market_group_members gm join public.sponsor_market_groups g on g.code=gm.group_code
  where gm.country_code=v_player.country_code;

  select * into v_rule from public.sponsor_offer_rules r
  where r.is_active and v_rank>=r.rank_min and (r.rank_max is null or v_rank<=r.rank_max)
  order by r.rank_min desc limit 1;
  if v_rule.rank_max is null or v_rule.rank_max=v_rule.rank_min then
    v_progress:=case when v_rule.rank_max is null then least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/699::numeric)) else 0 end;
  else
    v_progress:=least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/(v_rule.rank_max-v_rule.rank_min)::numeric));
  end if;
  v_local_share:=v_rule.local_share_start + v_progress*(v_rule.local_share_end-v_rule.local_share_start);

  select * into v_contract_row from public.player_sponsor_contracts
  where player_id=v_player.id and season=gd.season and status='active'
  order by signed_absolute_day desc limit 1;

  if v_contract_row.id is not null then
    select coalesce(sum(amount),0) into v_received from public.career_finance_transactions
    where player_id=v_player.id and source_type='sponsor_contract' and source_id=v_contract_row.id::text and amount>0;
    select min(x) into v_next_payment from generate_series(v_contract_row.first_payment_absolute_day,v_contract_row.end_absolute_day,7) x where x>v_abs;
    select jsonb_build_object(
      'id',c.id,'sponsor_company_id',c.sponsor_company_id,'sponsor_name',s.name,'sponsor_country_code',s.country_code,
      'logo_url',s.logo_url,'is_worldwide',s.is_worldwide,'source_pool',c.source_pool,'market_group_code',c.player_market_group_code,
      'signed_absolute_day',c.signed_absolute_day,'start_absolute_day',c.start_absolute_day,'end_absolute_day',c.end_absolute_day,
      'full_season_value',c.full_season_value,'weekly_payment_amount',c.weekly_payment_amount,'scheduled_payment_count',c.scheduled_payment_count,
      'total_contract_value',c.total_contract_value,'income_received',v_received,'next_payment_absolute_day',v_next_payment,'status',c.status
    ) into v_contract
    from public.player_sponsor_contracts c join public.sponsor_companies s on s.id=c.sponsor_company_id where c.id=v_contract_row.id;
  else
    v_contract:='null'::jsonb;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'sponsor_company_id',o.sponsor_company_id,'sponsor_name',s.name,'sponsor_country_code',s.country_code,
    'logo_url',s.logo_url,'is_worldwide',s.is_worldwide,'source_pool',o.source_pool,'market_group_code',o.player_market_group_code,
    'player_rank',o.player_rank,'generated_absolute_day',o.generated_absolute_day,'expires_absolute_day',o.expires_absolute_day,
    'first_payment_absolute_day',o.first_payment_absolute_day,'full_season_value',o.full_season_value,
    'weekly_payment_amount',o.weekly_payment_amount,'scheduled_payment_count',o.scheduled_payment_count,
    'total_contract_value',o.total_contract_value,'status',o.status
  ) order by o.total_contract_value desc,s.name),'[]'::jsonb) into v_offers
  from public.player_sponsor_offers o join public.sponsor_companies s on s.id=o.sponsor_company_id
  where o.player_id=v_player.id and o.season=gd.season and o.offer_week_start_absolute_day=v_week_start and o.status='open';

  return jsonb_build_object(
    'player_id',v_player.id,'season',gd.season,'current_absolute_day',v_abs,'season_end_absolute_day',v_season_end,
    'player_rank',v_rank,'player_country_code',v_player.country_code,
    'market',jsonb_build_object('code',v_group_code,'name',v_group_name,'macro_region',v_macro),
    'offer_rule',jsonb_build_object('code',v_rule.code,'offer_count_min',v_rule.offer_count_min,'offer_count_max',v_rule.offer_count_max,
      'local_share_percent',round(v_local_share*100)::integer,'worldwide_share_percent',round((1-v_local_share)*100)::integer,
      'full_season_value_min',v_rule.full_season_value_min,'full_season_value_max',v_rule.full_season_value_max),
    'offer_week_start_absolute_day',v_week_start,'next_offer_refresh_absolute_day',v_next_refresh,
    'active_contract',v_contract,'offers',v_offers
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reprice_player_sponsor_open_offers_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  gd record;
  v_abs integer;
  v_season_end integer;
  v_rank integer;
  v_rule public.sponsor_offer_rules%rowtype;
  v_progress numeric;
  v_base_full_value numeric;
  v_first_payment integer;
  v_payment_count integer;
  v_updated integer:=0;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  if v_player.player_type<>'human' or v_player.owner_user_id is null then raise exception 'Sponsor offers are available to human players only.'; end if;
  if v_uid is not null and v_player.owner_user_id<>v_uid then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_season_end:=public.game_day_absolute_v1(gd.season,12::smallint,31::smallint);
  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(p_player_id,gd.season),9999)::integer);

  select * into v_rule
  from public.sponsor_offer_rules r
  where r.is_active and v_rank>=r.rank_min and (r.rank_max is null or v_rank<=r.rank_max)
  order by r.rank_min desc limit 1;
  if v_rule.code is null then raise exception 'No sponsor offer rule for ranking %.',v_rank; end if;

  if v_rule.rank_max is null or v_rule.rank_max=v_rule.rank_min then
    v_progress:=case when v_rule.rank_max is null
      then least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/699::numeric))
      else 0 end;
  else
    v_progress:=least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/(v_rule.rank_max-v_rule.rank_min)::numeric));
  end if;

  v_base_full_value:=v_rule.full_season_value_max - v_progress*(v_rule.full_season_value_max-v_rule.full_season_value_min);
  v_first_payment:=least(v_abs+6,v_season_end);
  v_payment_count:=floor((v_season_end-v_first_payment)::numeric/7)::integer+1;

  with priced as (
    select o.id,
      greatest(v_rule.full_season_value_min,
        least(v_rule.full_season_value_max,
          round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(
            concat_ws(':','value',p_player_id::text,gd.season::text,o.offer_week_start_absolute_day::text,o.sponsor_company_id::text)
          )))/100::numeric)*100
        )
      )::bigint as full_value
    from public.player_sponsor_offers o
    where o.player_id=p_player_id
      and o.season=gd.season
      and o.status='open'
      and o.expires_absolute_day>=v_abs
  ), money as (
    select id,full_value,
      greatest(50::bigint,(round((full_value::numeric/52::numeric)/10::numeric)*10)::bigint) as weekly_value
    from priced
  )
  update public.player_sponsor_offers o
  set offer_rule_code=v_rule.code,
      player_rank=v_rank,
      first_payment_absolute_day=v_first_payment,
      full_season_value=m.full_value,
      weekly_payment_amount=m.weekly_value,
      scheduled_payment_count=v_payment_count,
      total_contract_value=m.weekly_value*v_payment_count,
      updated_at=now()
  from money m
  where o.id=m.id;

  get diagnostics v_updated=row_count;
  return jsonb_build_object('status','repriced','updated',v_updated,'player_rank',v_rank,'offer_rule_code',v_rule.code,'first_payment_absolute_day',v_first_payment);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.technical_sponsor_player_profile_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_rank integer;
  v_group jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found.'; end if;
  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(p_player_id,(select season from public.game_clock where id=1)),9999)::integer);
  v_group:=public.technical_sponsor_rank_group_v2(v_rank);
  return jsonb_build_object(
    'rank',v_rank,
    'rank_group',v_group->>'code',
    'rank_group_label',v_group->>'label',
    'offer_count',(v_group->>'offer_count')::integer,
    'reputation',0,
    'recent_win_pct',0,
    'eligibility_basis','current_ranking_only'
  );
end;
$function$
;
