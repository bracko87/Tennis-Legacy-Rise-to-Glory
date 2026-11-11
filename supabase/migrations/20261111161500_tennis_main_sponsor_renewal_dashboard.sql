CREATE OR REPLACE FUNCTION public.get_player_sponsor_dashboard_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_base jsonb;
  v_contract uuid;
  v_objectives jsonb:='[]'::jsonb;
  v_offers jsonb:='[]'::jsonb;
  v_renewals jsonb:='[]'::jsonb;
  v_scheduled jsonb:='null'::jsonb;
  v_current_season integer;
  v_current_abs integer;
  v_bonus_total bigint:=0;
  v_bonus_earned bigint:=0;
  v_bonus_available bigint:=0;
  v_bonus_missed bigint:=0;
  v_first_payment integer;
  v_last_payment integer;
  v_week_start integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human';

  if v_player is null then raise exception 'Player not found.'; end if;

  perform public.ensure_player_main_sponsor_renewal_v1(v_player);
  perform public.reprice_player_sponsor_open_offers_v1(v_player);
  v_base:=public.get_player_sponsor_dashboard_v1();
  perform public.refresh_player_sponsor_offer_plans_v2(v_player);

  v_week_start:=coalesce((v_base->>'offer_week_start_absolute_day')::integer,0);
  v_current_season:=(v_base->>'season')::integer;
  v_current_abs:=(v_base->>'current_absolute_day')::integer;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,
    'sponsor_company_id',o.sponsor_company_id,
    'sponsor_name',s.name,
    'sponsor_country_code',s.country_code,
    'logo_url',s.logo_url,
    'is_worldwide',s.is_worldwide,
    'source_pool',o.source_pool,
    'market_group_code',o.player_market_group_code,
    'player_rank',o.player_rank,
    'generated_absolute_day',o.generated_absolute_day,
    'expires_absolute_day',o.expires_absolute_day,
    'first_payment_absolute_day',o.first_payment_absolute_day,
    'full_season_value',o.full_season_value,
    'weekly_payment_amount',o.weekly_payment_amount,
    'scheduled_payment_count',o.scheduled_payment_count,
    'total_contract_value',o.total_contract_value,
    'performance_bonus_pool',o.performance_bonus_pool,
    'maximum_total_value',o.total_contract_value+o.performance_bonus_pool,
    'objective_plan',o.objective_plan,
    'status',o.status
  ) order by o.total_contract_value+o.performance_bonus_pool desc,s.name),'[]'::jsonb)
  into v_offers
  from public.player_sponsor_offers o
  join public.sponsor_companies s on s.id=o.sponsor_company_id
  where o.player_id=v_player
    and o.season=(v_base->>'season')::integer
    and o.offer_week_start_absolute_day=v_week_start
    and o.is_renewal=false
    and o.status='open';

  v_base:=jsonb_set(v_base,'{offers}',v_offers,true);

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',o.id,'target_season',o.season,'is_renewal',true,
    'sponsor_company_id',o.sponsor_company_id,'sponsor_name',s.name,
    'sponsor_country_code',s.country_code,'logo_url',s.logo_url,
    'is_worldwide',s.is_worldwide,'source_pool',o.source_pool,
    'market_group_code',o.player_market_group_code,'player_rank',o.player_rank,
    'generated_absolute_day',o.generated_absolute_day,
    'expires_absolute_day',o.expires_absolute_day,
    'first_payment_absolute_day',o.first_payment_absolute_day,
    'full_season_value',o.full_season_value,
    'weekly_payment_amount',o.weekly_payment_amount,
    'scheduled_payment_count',o.scheduled_payment_count,
    'total_contract_value',o.total_contract_value,
    'performance_bonus_pool',o.performance_bonus_pool,
    'maximum_total_value',o.total_contract_value+o.performance_bonus_pool,
    'objective_plan',o.objective_plan,'status',o.status
  ) ORDER BY o.total_contract_value DESC),'[]'::jsonb)
  INTO v_renewals
  FROM public.player_sponsor_offers o
  JOIN public.sponsor_companies s ON s.id=o.sponsor_company_id
  WHERE o.player_id=v_player AND o.is_renewal AND o.status='open'
    AND o.season IN(v_current_season,v_current_season+1)
    AND o.expires_absolute_day>=v_current_abs;

  SELECT jsonb_build_object(
    'target_season',r.target_season,'sponsor_name',s.name,
    'sponsor_company_id',o.sponsor_company_id,'total_contract_value',o.total_contract_value,
    'first_payment_absolute_day',o.first_payment_absolute_day,
    'starts_absolute_day',public.game_day_absolute_v1(r.target_season,1::smallint,1::smallint)
  ) INTO v_scheduled
  FROM public.player_sponsor_renewal_reservations_v1 r
  JOIN public.player_sponsor_offers o ON o.id=r.offer_id
  JOIN public.sponsor_companies s ON s.id=o.sponsor_company_id
  WHERE r.player_id=v_player AND r.target_season>v_current_season
    AND r.activated_contract_id IS NULL
  LIMIT 1;

  v_base:=v_base||jsonb_build_object('renewal_offers',v_renewals,
    'scheduled_renewal',v_scheduled);
  v_contract:=nullif(v_base#>>'{active_contract,id}','')::uuid;

  if v_contract is null then
    return v_base;
  end if;

  perform public.sponsor_refresh_player_objectives_v1(
    v_player,
    (v_base->>'current_absolute_day')::integer
  );

  select first_payment_absolute_day,
         first_payment_absolute_day+greatest(0,scheduled_payment_count::integer-1)*7
  into v_first_payment,v_last_payment
  from public.player_sponsor_contracts
  where id=v_contract;

  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id',o.id,
      'objective_key',o.objective_key,
      'objective_code',o.objective_code,
      'title',o.title,
      'description',o.description,
      'target_value',o.target_value,
      'current_value',o.current_value,
      'reward_amount',o.reward_amount,
      'status',o.status,
      'achieved_absolute_day',o.achieved_absolute_day,
      'competition_id',o.competition_id,
      'tournament_series_id',o.tournament_series_id,
      'tournament_name',o.tournament_name,
      'requirement_label',o.requirement_label,
      'start_absolute_day',o.start_absolute_day,
      'deadline_absolute_day',o.deadline_absolute_day,
      'metadata',o.metadata
    ) order by coalesce(o.start_absolute_day,o.deadline_absolute_day),o.created_at,o.id),'[]'::jsonb),
    coalesce(sum(o.reward_amount),0),
    coalesce(sum(o.reward_amount) filter(where o.status='completed'),0),
    coalesce(sum(o.reward_amount) filter(where o.status in ('upcoming','active')),0),
    coalesce(sum(o.reward_amount) filter(where o.status in ('failed','expired')),0)
  into v_objectives,v_bonus_total,v_bonus_earned,v_bonus_available,v_bonus_missed
  from public.player_sponsor_objectives o
  where o.contract_id=v_contract;

  v_base:=jsonb_set(v_base,'{active_contract,first_payment_absolute_day}',to_jsonb(v_first_payment),true);
  v_base:=jsonb_set(v_base,'{active_contract,last_payment_absolute_day}',to_jsonb(v_last_payment),true);
  v_base:=jsonb_set(v_base,'{active_contract,payment_frequency_days}',to_jsonb(7),true);
  v_base:=jsonb_set(v_base,'{active_contract,objectives}',v_objectives,true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_pool_total}',to_jsonb(v_bonus_total),true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_earned}',to_jsonb(v_bonus_earned),true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_available}',to_jsonb(v_bonus_available),true);
  v_base:=jsonb_set(v_base,'{active_contract,bonus_missed}',to_jsonb(v_bonus_missed),true);
  v_base:=jsonb_set(v_base,'{active_contract,maximum_total_value}',
    to_jsonb(coalesce((v_base#>>'{active_contract,total_contract_value}')::bigint,0)+v_bonus_total),true);

  return v_base;
end;
$function$
;