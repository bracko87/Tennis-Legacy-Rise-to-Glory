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
$$;

revoke execute on function public.reprice_player_sponsor_open_offers_v1(uuid) from public,anon,authenticated;
