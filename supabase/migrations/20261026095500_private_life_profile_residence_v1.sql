-- Preserve nationality and original player birthplace; expose selected residence in the profile summary.
CREATE OR REPLACE FUNCTION public.get_player_private_life_summary_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_abs integer; gd record; v_prestige integer:=0; v_asset_count integer:=0; v_asset_value bigint:=0; v_possessions jsonb:='[]'::jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id) then raise exception 'Player not found.'; end if;
  perform public.ensure_private_life_starter_home_v1(p_player_id);
  select * into gd from public.get_current_game_day_internal_v1(); v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  select coalesce(sum(coalesce(o.prestige_override,c.prestige)),0)::integer,count(*)::integer,coalesce(sum(public.private_life_owned_asset_market_value_v2(o.id,v_abs)),0)::bigint
  into v_prestige,v_asset_count,v_asset_value
  from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code where o.player_id=p_player_id and o.sold_absolute_day is null;
  select coalesce(jsonb_agg(x order by x.prestige desc,x.name),'[]'::jsonb) into v_possessions
  from (
    select o.id,c.category,case when l.code is not null then c.name||' · '||l.city else c.name end as name,
      coalesce(o.prestige_override,c.prestige)::integer as prestige,o.acquisition_type,o.trade_locked,l.city,l.country_code,l.country_name,
      public.private_life_owned_asset_market_value_v2(o.id,v_abs) as current_market_value
    from public.private_life_player_assets o join public.private_life_asset_catalog c on c.code=o.catalog_code
    left join public.private_life_property_locations l on l.code=o.location_code
    where o.player_id=p_player_id and o.sold_absolute_day is null
  ) x;
  return jsonb_build_object('player_id',p_player_id,'prestige_points',v_prestige,'asset_count',v_asset_count,'asset_value',v_asset_value, 'possessions',v_possessions,'residence',public.get_player_home_base_v1(p_player_id));
end;
$function$
;
