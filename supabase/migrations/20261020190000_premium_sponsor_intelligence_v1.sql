-- Premium Sponsor Intelligence v1
-- Pure read-only analysis. No sponsor repricing, signing, objective refresh,
-- payouts, income posting, or gameplay changes.
create or replace function public.get_premium_sponsor_intelligence_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path='public','pg_temp'
as $fn$
declare
  v_player public.players%rowtype;
  v_season integer;
  v_today integer;
  v_week_start integer;
  v_contract public.player_sponsor_contracts%rowtype;
  v_name text;
  v_paid_guaranteed bigint:=0;
  v_paid_bonus bigint:=0;
  v_earned_bonus bigint:=0;
  v_unresolved_bonus bigint:=0;
  v_lost_bonus bigint:=0;
  v_objective_count integer:=0;
  v_completed integer:=0;
  v_attention jsonb:='[]'::jsonb;
  v_offers jsonb:='[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  if not public.has_active_premium_v1() then
    raise exception 'Premium membership required' using errcode='42501';
  end if;
  select * into v_player from public.players p
   where p.id=p_player_id and p.owner_user_id=auth.uid()
     and p.player_type='human' and p.moderation_status<>'rejected';
  if not found then
    raise exception 'Sponsor Intelligence is limited to your career'
      using errcode='42501';
  end if;
  select g.season,public.game_day_absolute_v1(g.season,g.month,g.day)
    into v_season,v_today from public.get_current_game_day_internal_v1() g;
  v_week_start:=public.game_day_absolute_v1(v_season,1::smallint,1::smallint)
    + ((v_today-public.game_day_absolute_v1(v_season,1::smallint,1::smallint))/7)*7;

  select c.* into v_contract from public.player_sponsor_contracts c
   where c.player_id=p_player_id and c.season=v_season
     and c.status='active'
   order by c.signed_absolute_day desc,c.id limit 1;

  if v_contract.id is not null then
    select s.name into v_name from public.sponsor_companies s
      where s.id=v_contract.sponsor_company_id;
    select coalesce(sum(x.amount),0)::bigint into v_paid_guaranteed
      from public.career_finance_transactions x
      where x.player_id=p_player_id
        and x.source_type='sponsor_contract'
        and x.source_id=v_contract.id::text
        and x.amount>0;
    select coalesce(sum(x.amount),0)::bigint into v_paid_bonus
      from public.career_finance_transactions x
      join public.player_sponsor_objectives o
        on o.id::text=x.source_id and o.contract_id=v_contract.id
      where x.player_id=p_player_id
        and x.source_type='sponsor_objective' and x.amount>0;
    select
      coalesce(sum(o.reward_amount) filter(where o.status='completed'),0),
      coalesce(sum(o.reward_amount) filter(where o.status in ('active','upcoming')),0),
      coalesce(sum(o.reward_amount) filter(where o.status in ('failed','expired')),0),
      count(*)::integer,count(*) filter(where o.status='completed')::integer
    into v_earned_bonus,v_unresolved_bonus,v_lost_bonus,v_objective_count,v_completed
    from public.player_sponsor_objectives o where o.contract_id=v_contract.id;

    select coalesce(jsonb_agg(jsonb_build_object(
       'id',o.id,
       'objective_code',o.objective_code,
       'title',o.title,
       'status',o.status,
       'tournament_name',o.tournament_name,
       'current_value',o.current_value,
       'target_value',o.target_value,
       'reward_amount',o.reward_amount,
       'start_absolute_day',o.start_absolute_day,
       'deadline_absolute_day',o.deadline_absolute_day,
       'days_to_deadline',case when o.deadline_absolute_day is not null
         then o.deadline_absolute_day-v_today else null end,
       -- Rank-peak and season-finish milestones are binary and must NOT
       -- be shown as linear rank-percentage progress.
       'progress_percent',case
         when o.objective_code in ('ranking_peak','season_finish_rank') then null
         when o.target_value>0 then round(least(100,greatest(0,
           o.current_value::numeric*100/o.target_value)),1)
         else null end,
       'milestone_achieved',case
         when o.objective_code in ('ranking_peak','season_finish_rank')
           then o.current_value>=1 else null end
    ) order by
       case when o.status='active' then 0 else 1 end,
       o.deadline_absolute_day nulls last,o.reward_amount desc,o.id),'[]'::jsonb)
    into v_attention
    from public.player_sponsor_objectives o
    where o.contract_id=v_contract.id
      and o.status in ('active','upcoming')
      and (o.deadline_absolute_day is null or o.deadline_absolute_day>=v_today);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id',o.id,'name',s.name,'source_pool',o.source_pool,
      'expires_absolute_day',o.expires_absolute_day,
      'days_until_expiry',o.expires_absolute_day-v_today,
      'guaranteed_usd',o.total_contract_value,
      'weekly_usd',o.weekly_payment_amount,
      'installments',o.scheduled_payment_count,
      'conditional_bonus_pool_usd',o.performance_bonus_pool,
      'maximum_if_all_objectives_met_usd',o.total_contract_value+o.performance_bonus_pool,
      'conditional_share_percent',case when
        o.total_contract_value+o.performance_bonus_pool>0
        then round(o.performance_bonus_pool::numeric*100/
          (o.total_contract_value+o.performance_bonus_pool),1)
        else 0 end,
      'objective_count',coalesce(jsonb_array_length(
        case when jsonb_typeof(o.objective_plan)='array' then o.objective_plan else '[]'::jsonb end),0)
    ) order by o.total_contract_value desc,s.name),'[]'::jsonb)
  into v_offers
  from public.player_sponsor_offers o
  join public.sponsor_companies s on s.id=o.sponsor_company_id
  where o.player_id=p_player_id and o.season=v_season
    and o.offer_week_start_absolute_day=v_week_start
    and o.status='open' and o.expires_absolute_day>=v_today;

  return jsonb_build_object(
    'player_id',p_player_id,'season',v_season,
    'current_absolute_day',v_today,
    'active_contract',case when v_contract.id is null then null
      else jsonb_build_object(
        'id',v_contract.id,'name',v_name,
        'guaranteed_total_usd',v_contract.total_contract_value,
        'guaranteed_received_usd',v_paid_guaranteed,
        'guaranteed_remaining_usd',greatest(0,
          v_contract.total_contract_value-v_paid_guaranteed),
        'weekly_payment_usd',v_contract.weekly_payment_amount,
        'scheduled_installments',v_contract.scheduled_payment_count,
        'end_absolute_day',v_contract.end_absolute_day,
        'bonus_pool_usd',v_contract.performance_bonus_pool,
        'bonus_earned_by_objectives_usd',v_earned_bonus,
        'bonus_posted_usd',v_paid_bonus,
        'bonus_unresolved_usd',v_unresolved_bonus,
        'bonus_failed_or_expired_usd',v_lost_bonus,
        'objectives_total',v_objective_count,
        'objectives_completed',v_completed,
        'attention_objectives',v_attention
      ) end,
    'offers',v_offers,'offer_count',jsonb_array_length(v_offers),
    'currency','USD',
    'methodology','This report only compares stored offer terms, posted ledger receipts, and current objective status. Unresolved objectives are conditional bonus possibilities, never guaranteed or probability-weighted. Guaranteed remaining is contract value minus ledger receipts, not an assurance of settlement. Rank objectives are binary milestones, not linear progress. Offers can expire/change; the Free Sponsors interface is authoritative for signing and official status. No forecast or gameplay advantage is granted.'
  );
end
$fn$;
revoke all on function public.get_premium_sponsor_intelligence_v1(uuid) from public,anon,authenticated;
grant execute on function public.get_premium_sponsor_intelligence_v1(uuid) to authenticated;
comment on function public.get_premium_sponsor_intelligence_v1(uuid) is
 'Premium owner-only read-only comparison of current main sponsor offers and current-season contract objectives.';
