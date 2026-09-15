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
      coalesce(p.id=v_active_brand,false),v_active_id,'open'
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
revoke execute on function public.ensure_player_technical_sponsor_offers_v1(uuid,boolean) from public,anon,authenticated;
