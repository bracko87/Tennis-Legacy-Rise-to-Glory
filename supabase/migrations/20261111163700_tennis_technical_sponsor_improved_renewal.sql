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
      -- A returning sponsor may improve its terms when the player has risen
      -- since signing. Never exceed the eligibility tier's maximum.
      if v_active.id is not null and r.id=v_active.brand_id
          and v_active.player_rank_at_sign is not null
          and v_rank<v_active.player_rank_at_sign then
        v_bonus:=least((g->>'bonus_max')::bigint,greatest(v_bonus,
          round(coalesce(v_active.signing_bonus_usd,0)::numeric*
            (1+least(0.35::numeric,
               (v_active.player_rank_at_sign-v_rank)::numeric/
               greatest(1,v_active.player_rank_at_sign)::numeric*0.35)))::bigint));
        v_discount:=least((g->>'discount_max')::numeric,greatest(v_discount,
          coalesce(v_active.discount_pct,0)+least(8::numeric,
            (v_active.player_rank_at_sign-v_rank)::numeric/
            greatest(1,v_active.player_rank_at_sign)::numeric*8)));
      end if;
      insert into public.player_technical_sponsor_offers(player_id,brand_id,category,offer_round_start_absolute_day,generated_absolute_day,available_from_absolute_day,expires_absolute_day,contract_weeks,discount_pct,premium_discount_bonus_pct,free_equipment_allowance,free_replacement_allowance,maintenance_discount_pct,player_rank,player_reputation,recent_win_pct,requirements,is_renewal,current_contract_id,status,signing_bonus_usd,updated_at)
      values(p_player_id,r.id,v_cat,v_round,v_abs,v_available,v_expiry,v_weeks,v_discount,v_premium,0,0,0,v_rank,0,0,jsonb_build_object('rank_group',g->>'code','rank_group_label',g->>'label','rank_best',(g->>'rank_best')::integer,'rank_worst',(g->>'rank_worst')::integer,'eligibility_basis','current_ranking_only','equipment_benefit_model','discount_only'),(v_active.id is not null and r.id=v_active.brand_id),v_active.id,'open',v_bonus,now())
      on conflict(player_id,category,brand_id,offer_round_start_absolute_day) do update set generated_absolute_day=excluded.generated_absolute_day,available_from_absolute_day=excluded.available_from_absolute_day,expires_absolute_day=excluded.expires_absolute_day,contract_weeks=excluded.contract_weeks,discount_pct=excluded.discount_pct,premium_discount_bonus_pct=excluded.premium_discount_bonus_pct,free_equipment_allowance=0,free_replacement_allowance=0,maintenance_discount_pct=0,player_rank=excluded.player_rank,player_reputation=0,recent_win_pct=0,requirements=excluded.requirements,is_renewal=excluded.is_renewal,current_contract_id=excluded.current_contract_id,status='open',signing_bonus_usd=excluded.signing_bonus_usd,updated_at=now();
    end loop;
  end loop;
  return jsonb_build_object('status','ok','rank',v_rank,'rank_group',g->>'code','rank_group_label',g->>'label','offer_count_per_open_slot',v_offer_count,'equipment_benefit_model','discount_only');
end;
$function$
;