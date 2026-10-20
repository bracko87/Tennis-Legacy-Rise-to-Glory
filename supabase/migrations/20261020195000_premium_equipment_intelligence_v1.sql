-- Premium Equipment Intelligence v1 — analytical, read-only.
-- Based on the existing Free equipment dashboard so resale values, sponsor
-- prices, type restrictions, inventory and catalog obey authoritative rules.
create or replace function public.get_premium_equipment_intelligence_v1(p_player_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path='public','pg_temp'
as $fn$
declare
  v_player public.players%rowtype;
  v_data jsonb;
  v_owned jsonb;
  v_candidates jsonb;
  v_count integer;
  v_equipped integer;
  v_worn integer;
  v_paid bigint;
  v_resale bigint;
  v_resale_eligible integer;
begin
  if auth.uid() is null or not public.has_active_premium_v1() then
    raise exception 'Premium membership required' using errcode='42501';
  end if;
  select * into v_player from public.players p
   where p.id=p_player_id and p.owner_user_id=auth.uid()
      and p.player_type='human' and p.moderation_status<>'rejected';
  if not found then
    raise exception 'Equipment report restricted to your own career'
      using errcode='42501';
  end if;

  -- Existing Free backend is authoritative for condition, sponsorship,
  -- resale eligibility and price. It makes no gameplay updates.
  v_data:=public.get_equipment_dashboard_v1();
  if (v_data->>'player_id')::uuid is distinct from p_player_id then
    raise exception 'Player equipment mismatch' using errcode='42501';
  end if;

  with owned as (
    select x.value as e, x.value->'item' as item
    from jsonb_array_elements(coalesce(v_data->'inventory','[]'::jsonb)) x
  ), sized as (
    select
      o.e->>'inventory_id' inventory_id,
      o.item->>'id' catalog_item_id,
      concat_ws(' ',o.item->>'brand',o.item->>'model') item_name,
      o.item->>'item_type' item_type,
      o.item->>'accessory_kind' accessory_kind,
      o.item->>'surface' surface,
      o.item->>'product_profile' product_profile,
      coalesce((o.item->>'tier')::integer,0) tier,
      coalesce((o.e->>'condition')::numeric,0) current_condition,
      nullif((o.item->>'wear_per_match')::numeric,0) nominal_wear_per_match,
      nullif((o.item->>'estimated_uses')::integer,0) advertised_uses,
      coalesce((o.e->>'purchase_price_usd')::bigint,0) paid_price,
      coalesce((o.e->>'resale_value_usd')::bigint,0) resale_value,
      coalesce((o.e->>'resell_supported')::boolean,false) resell_supported,
      coalesce((o.e->>'can_sell')::boolean,false) can_sell_now,
      o.e->>'acquired_source' acquisition,
      coalesce((o.e->>'is_equipped')::boolean,false) is_equipped,
      coalesce((o.item->>'durability')::integer,0) durability
    from owned o
  ), enriched as (
    select s.*,
      -- Never claim exact lifespan: surface, boosts and match types vary.
      case when nominal_wear_per_match>0
       then floor(current_condition/nominal_wear_per_match)::integer
       else null end as nominal_uses_remaining,
      case when acquisition='purchase' and paid_price>0 and resell_supported
       then round(resale_value::numeric*100/paid_price,1)
       else null end as retained_purchase_value_pct
    from sized s
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'inventory_id',inventory_id,
      'catalog_item_id',catalog_item_id,
      'name',item_name,'type',item_type,'accessory_kind',accessory_kind,
      'surface',surface,'product_profile',product_profile,
      'tier',tier,'condition',current_condition,
      'wear_per_match',nominal_wear_per_match,'catalog_estimated_uses',advertised_uses,
      'nominal_uses_remaining',nominal_uses_remaining,
      'durability',durability,
      'purchase_price_usd',paid_price,'resale_value_usd',resale_value,
      'resell_supported',resell_supported,'can_sell_now',can_sell_now,
      'acquisition',acquisition,'is_equipped',is_equipped,
      'retained_purchase_value_pct',retained_purchase_value_pct
    ) order by current_condition asc,item_type,item_name),'[]'::jsonb),
    count(*)::integer,
    count(*) filter(where is_equipped)::integer,
    count(*) filter(where current_condition<40)::integer,
    coalesce(sum(paid_price),0)::bigint,
    coalesce(sum(resale_value),0)::bigint,
    count(*) filter(where resell_supported)::integer
  into v_owned,v_count,v_equipped,v_worn,v_paid,v_resale,v_resale_eligible
  from enriched;

  with raw as (
    select x.value item from jsonb_array_elements(coalesce(v_data->'catalog','[]'::jsonb)) x
    where coalesce(x.value->>'availability_status','') in ('available','limited')
      and coalesce((x.value->>'is_active')::boolean,true)
  ), offerings as (
    select
      item->>'id' id,concat_ws(' ',item->>'brand',item->>'model') name,
      item->>'item_type' item_type,item->>'accessory_kind' accessory_kind,
      item->>'surface' surface,
      coalesce((item->>'tier')::integer,0) tier,
      coalesce((item->>'durability')::integer,0) durability,
      nullif((item->>'estimated_uses')::integer,0) nominal_total_uses,
      nullif((item->>'wear_per_match')::numeric,0) wear_per_match,
      coalesce((item->>'price_usd')::bigint,0) list_price,
      greatest(0,coalesce((item->>'sponsor_final_price_usd')::bigint,
        (item->>'price_usd')::bigint,0)) effective_price,
      coalesce((item->>'sponsor_free_claim_available')::boolean,false) free_claim_available,
      item->>'availability_status' availability,
      item->>'effect_scope' effect_scope,
      coalesce(item->'effective_gameplay_effects',item->'gameplay_effects','{}'::jsonb) effect_map
    from raw
  ), priced as (
    select o.*,
      case when nominal_total_uses>0
       then round(effective_price::numeric/nominal_total_uses,2)
       else null end as nominal_cost_per_use,
      row_number() over(partition by item_type,coalesce(accessory_kind,'')
        order by
          (case when nominal_total_uses>0 then
            effective_price::numeric/nominal_total_uses else 999999999::numeric end),
          effective_price,id
        ) rank_within_type
    from offerings o
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',id,'name',name,'type',item_type,'accessory_kind',accessory_kind,
    'surface',surface,'tier',tier,'durability',durability,
    'nominal_total_uses',nominal_total_uses,'wear_per_match',wear_per_match,
    'list_price_usd',list_price,'current_price_usd',effective_price,
    'nominal_cost_per_use_usd',nominal_cost_per_use,
    'free_claim_available',free_claim_available,
    'availability',availability,'effect_scope',effect_scope,
    'configured_effects',effect_map
  ) order by item_type,accessory_kind nulls first,nominal_cost_per_use nulls last,name),'[]'::jsonb)
  into v_candidates from priced where rank_within_type<=5;

  return jsonb_build_object(
    'player_id',p_player_id,'world',v_player.world,
    'owned_count',v_count,'equipped_count',v_equipped,'below_40_condition',v_worn,
    'owned_purchase_spend_usd',v_paid,
    'owned_resale_estimate_usd',v_resale,'resell_supported_count',v_resale_eligible,
    'items',v_owned,'replacement_candidates',v_candidates,
    'currency','USD',
    'methodology','Inventory spend covers currently owned items, not lifetime equipment expense. Resale is the Free game estimate, not guaranteed cash; starter/sponsor/reward items may be unsellable. Nominal remaining uses = floor(current condition / configured wear per match) and is not a prediction: surface mismatches, weather, protective accessories and game actions may alter wear. Marketplace ranking uses currently advertised price divided by catalog estimated uses, NOT actual performance, ROI, predicted match outcomes or a guarantee of item suitability. Effects are configured catalog data; all original equipment stats, purchases, maintenance and bonuses remain Free.'
  );
end
$fn$;
revoke all on function public.get_premium_equipment_intelligence_v1(uuid)
 from public,anon,authenticated;
grant execute on function public.get_premium_equipment_intelligence_v1(uuid)
 to authenticated;
