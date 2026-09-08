create or replace function public.reprice_player_sponsor_open_offers_v1(p_player_id uuid)
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
  v_rank:=greatest(1,coalesce(public.player_current_rank_position_v1(p_player_id),9999)::integer);

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

  update public.player_sponsor_offers o
  set offer_rule_code=v_rule.code,
      player_rank=v_rank,
      first_payment_absolute_day=v_first_payment,
      full_season_value=calc.full_value,
      weekly_payment_amount=calc.weekly_value,
      scheduled_payment_count=v_payment_count,
      total_contract_value=calc.weekly_value*v_payment_count,
      updated_at=now()
  from lateral (
    select
      greatest(v_rule.full_season_value_min,
        least(v_rule.full_season_value_max,
          round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(
            concat_ws(':','value',p_player_id::text,gd.season::text,o.offer_week_start_absolute_day::text,o.sponsor_company_id::text)
          )))/100::numeric)*100
        )
      )::bigint as full_value
  ) fv
  cross join lateral (
    select greatest(50::bigint,(round((fv.full_value::numeric/52::numeric)/10::numeric)*10)::bigint) as weekly_value
  ) calc
  where o.player_id=p_player_id
    and o.season=gd.season
    and o.status='open'
    and o.expires_absolute_day>=v_abs;

  get diagnostics v_updated=row_count;
  return jsonb_build_object('status','repriced','updated',v_updated,'player_rank',v_rank,'offer_rule_code',v_rule.code,'first_payment_absolute_day',v_first_payment);
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

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  perform public.reprice_player_sponsor_open_offers_v1(v_player);

  select * into v_offer from public.player_sponsor_offers where id=p_offer_id and player_id=v_player for update;
  if v_offer.id is null then raise exception 'Sponsor offer not found.'; end if;
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
    v_player,v_offer.sponsor_company_id,v_offer.id,v_offer.season,v_abs,v_abs,v_offer.first_payment_absolute_day,
    public.game_day_absolute_v1(v_offer.season,12::smallint,31::smallint),v_offer.player_rank,v_offer.player_market_group_code,v_offer.source_pool,
    v_offer.full_season_value,v_offer.weekly_payment_amount,v_offer.scheduled_payment_count,v_offer.total_contract_value,'active'
  ) returning * into v_contract;

  update public.player_sponsor_offers set status='accepted',updated_at=now() where id=v_offer.id;
  update public.player_sponsor_offers set status='expired',updated_at=now()
  where player_id=v_player and season=v_offer.season and status='open' and id<>v_offer.id;
  perform public.process_player_sponsor_payments_v1(v_player,v_abs);

  return jsonb_build_object('status','signed','contract_id',v_contract.id,'sponsor_company_id',v_contract.sponsor_company_id,
    'player_rank_at_sign',v_contract.player_rank_at_sign,'weekly_payment_amount',v_contract.weekly_payment_amount,
    'total_contract_value',v_contract.total_contract_value,'end_absolute_day',v_contract.end_absolute_day);
end;
$$;

create or replace function public.get_player_sponsor_dashboard_v2()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_base jsonb;
  v_contract uuid;
  v_objectives jsonb;
  v_bonus_total bigint:=0;
  v_bonus_earned bigint:=0;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;
  select id into v_player from public.players where owner_user_id=v_uid and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;

  perform public.reprice_player_sponsor_open_offers_v1(v_player);
  v_base:=public.get_player_sponsor_dashboard_v1();
  v_contract:=nullif(v_base#>>'{active_contract,id}','')::uuid;

  if v_contract is null then
    return v_base || jsonb_build_object('objectives','[]'::jsonb,'bonus_pool_total',0,'bonus_earned',0);
  end if;

  perform public.sponsor_refresh_player_objectives_v1(v_player,(v_base->>'current_absolute_day')::integer);

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'objective_code',o.objective_code,'title',o.title,'description',o.description,
    'target_value',o.target_value,'current_value',o.current_value,'reward_amount',o.reward_amount,
    'status',o.status,'achieved_absolute_day',o.achieved_absolute_day
  ) order by case o.objective_code when 'appearances' then 1 when 'match_wins' then 2 else 3 end),'[]'::jsonb),
  coalesce(sum(o.reward_amount),0),coalesce(sum(o.reward_amount) filter(where o.status='achieved'),0)
  into v_objectives,v_bonus_total,v_bonus_earned
  from public.player_sponsor_objectives o where o.contract_id=v_contract;

  return jsonb_set(
    jsonb_set(
      jsonb_set(v_base,'{active_contract,objectives}',v_objectives,true),
      '{active_contract,bonus_pool_total}',to_jsonb(v_bonus_total),true
    ),
    '{active_contract,bonus_earned}',to_jsonb(v_bonus_earned),true
  );
end;
$$;

revoke execute on function public.reprice_player_sponsor_open_offers_v1(uuid) from public,anon,authenticated;
grant execute on function public.get_player_sponsor_dashboard_v2() to authenticated;
grant execute on function public.sign_player_sponsor_offer_v1(uuid) to authenticated;
