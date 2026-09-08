create or replace function public.ensure_player_sponsor_offers_v1(p_player_id uuid, p_force boolean default false)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
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

  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);
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
    where s.sponsor_kind='main' and s.is_active and gm.group_code=v_group_code
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
$$;

create or replace function public.sign_player_sponsor_offer_v1(p_offer_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_offer public.player_sponsor_offers%rowtype;
  v_contract public.player_sponsor_contracts%rowtype;
  gd record;
  v_abs integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;
  select * into v_offer from public.player_sponsor_offers where id=p_offer_id and player_id=v_player for update;
  if v_offer.id is null then raise exception 'Sponsor offer not found.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  if v_offer.status<>'open' then raise exception 'This sponsor offer is no longer open.'; end if;
  if v_offer.expires_absolute_day<v_abs then
    update public.player_sponsor_offers set status='expired',updated_at=now() where id=v_offer.id;
    raise exception 'This sponsor offer has expired.';
  end if;
  if v_offer.season<>gd.season then raise exception 'This sponsor offer belongs to another season.'; end if;
  if exists(select 1 from public.player_sponsor_contracts where player_id=v_player and season=gd.season) then
    raise exception 'A main sponsor agreement already exists for this season.';
  end if;

  insert into public.player_sponsor_contracts(
    player_id,sponsor_company_id,offer_id,season,signed_absolute_day,start_absolute_day,first_payment_absolute_day,end_absolute_day,
    player_rank_at_sign,player_market_group_code,source_pool,full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value,status
  ) values(
    v_player,v_offer.sponsor_company_id,v_offer.id,v_offer.season,v_abs,v_offer.generated_absolute_day,v_offer.first_payment_absolute_day,
    public.game_day_absolute_v1(v_offer.season,12::smallint,31::smallint),v_offer.player_rank,v_offer.player_market_group_code,v_offer.source_pool,
    v_offer.full_season_value,v_offer.weekly_payment_amount,v_offer.scheduled_payment_count,v_offer.total_contract_value,'active'
  ) returning * into v_contract;

  update public.player_sponsor_offers set status='accepted',updated_at=now() where id=v_offer.id;
  update public.player_sponsor_offers set status='expired',updated_at=now()
  where player_id=v_player and season=v_offer.season and status='open' and id<>v_offer.id;
  perform public.process_player_sponsor_payments_v1(v_player,v_abs);

  return jsonb_build_object('status','signed','contract_id',v_contract.id,'sponsor_company_id',v_contract.sponsor_company_id,
    'weekly_payment_amount',v_contract.weekly_payment_amount,'total_contract_value',v_contract.total_contract_value,
    'end_absolute_day',v_contract.end_absolute_day);
end;
$$;

create or replace function public.get_player_sponsor_dashboard_v1()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
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

  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(v_player.id),9999)::integer);
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
$$;
