-- Preserve current match engine, staff and custom setup support.
CREATE OR REPLACE FUNCTION public.get_match_engine_profile_for_match_v2(p_player_id uuid, p_surface text, p_match_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  b jsonb;
  e jsonb;
  eq jsonb;
  m numeric:=1;
  eq_serve numeric:=0;
  eq_return numeric:=0;
  eq_rally numeric:=0;
  eq_net numeric:=0;
  climate numeric:=0;
  temp numeric;
  eq_avg numeric:=0;
  v_competition_id uuid;
  v_missing_racket boolean:=false;
  v_missing_shoes boolean:=false;
  v_missing_apparel boolean:=false;
  v_human boolean:=false;
  v_rating text;
  v_mult numeric;
begin
  b:=public.get_match_engine_profile_for_match_base_v2(p_player_id,p_surface,p_match_id);
  eq:=public.get_equipment_match_modifiers_for_match_v3(p_player_id,p_surface,p_match_id);
  begin
    temp:=nullif(b->'weather'->>'temperature_c','')::numeric;
  exception when others then
    temp:=null;
  end;

  if temp is not null and temp>=28 then
    climate:=coalesce((eq->>'heat_resistance_pct')::numeric,0)*.35;
  elsif temp is not null and temp<=12 then
    climate:=coalesce((eq->>'cold_resistance_pct')::numeric,0)*.35;
  end if;

  eq_serve:=greatest(-4,least(4,coalesce((eq->>'serve_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.10));
  eq_return:=greatest(-4,least(4,coalesce((eq->>'return_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.12+climate));
  eq_rally:=greatest(-4,least(4,coalesce((eq->>'rally_pct')::numeric,0)+coalesce((eq->>'stamina_pct')::numeric,0)*.22+climate));
  eq_net:=greatest(-4,least(4,coalesce((eq->>'net_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.10));
  eq_avg:=(eq_serve+eq_return+eq_rally+eq_net)/4.0;

  b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*(1+eq_serve/100.0),2)));
  b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*(1+eq_return/100.0),2)));
  b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*(1+eq_rally/100.0),2)));
  b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*(1+eq_net/100.0),2)));
  b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*(1+eq_avg/100.0),2)));

  select competition_id into v_competition_id
  from public.tournament_matches
  where id=p_match_id;

  if v_competition_id is not null then
    e:=public.get_tournament_staff_effects_v1(p_player_id,v_competition_id,null);
  else
    e:=jsonb_build_object('match_staff_multiplier',1,'match_execution_bonus_pct',0);
  end if;

  m:=greatest(1,least(1.02,coalesce((e->>'match_staff_multiplier')::numeric,1)));
  if m>1 then
    b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*m,2)));
    b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*m,2)));
  end if;


  -- Apply penalties only to humans; AI players have no owned equipment inventory.
  select exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id is not null)
    into v_human;
  if v_human then
    select not exists(
      select 1 from public.player_equipment_loadouts l
      join public.player_equipment_inventory i on i.id=l.racket_inventory_id
      where l.player_id=p_player_id and i.player_id=p_player_id and i.condition>0
    ) into v_missing_racket;
    select not exists(
      select 1 from public.player_equipment_loadouts l
      join public.player_equipment_inventory i on i.id=l.shoes_inventory_id
      where l.player_id=p_player_id and i.player_id=p_player_id and i.condition>0
    ) into v_missing_shoes;
    select not exists(
      select 1 from public.player_equipment_loadouts l
      join public.player_equipment_inventory i on i.id=l.apparel_inventory_id
      where l.player_id=p_player_id and i.player_id=p_player_id and i.condition>0
    ) into v_missing_apparel;
    -- Use the selected named match setup when this match uses one.
    if exists(select 1 from public.player_tournament_match_equipment_setups ms where ms.player_id=p_player_id and ms.match_id=p_match_id and ms.setup_slot>0) then
      select not exists(select 1 from public.resolve_player_equipment_setup_v1(p_player_id,
        (select ms.setup_slot from public.player_tournament_match_equipment_setups ms where ms.player_id=p_player_id and ms.match_id=p_match_id)) z
        join public.player_equipment_inventory i on i.id=z.racket_inventory_id and i.condition>0)
        into v_missing_racket;
      select not exists(select 1 from public.resolve_player_equipment_setup_v1(p_player_id,
        (select ms.setup_slot from public.player_tournament_match_equipment_setups ms where ms.player_id=p_player_id and ms.match_id=p_match_id)) z
        join public.player_equipment_inventory i on i.id=z.shoes_inventory_id and i.condition>0)
        into v_missing_shoes;
      select not exists(select 1 from public.resolve_player_equipment_setup_v1(p_player_id,
        (select ms.setup_slot from public.player_tournament_match_equipment_setups ms where ms.player_id=p_player_id and ms.match_id=p_match_id)) z
        join public.player_equipment_inventory i on i.id=z.apparel_inventory_id and i.condition>0)
        into v_missing_apparel;
    end if;
    foreach v_rating in array array['serve','return','rally','net','effective_overall'] loop
      v_mult:=1;
      if v_missing_racket then v_mult:=v_mult*0.65;end if;
      if v_missing_shoes then
        v_mult:=v_mult*(case when v_rating='serve' then 1 when v_rating='effective_overall' then 0.95 else 0.93 end);
      end if;
      if v_missing_apparel then v_mult:=v_mult*0.97;end if;
      b:=jsonb_set(b,array['ratings',v_rating],
        to_jsonb(round((b->'ratings'->>v_rating)::numeric*v_mult,2)));
    end loop;
  end if;

  return b||jsonb_build_object(
    'equipment_support',eq||jsonb_build_object(
      'effective_serve_pct',round(eq_serve,2),
      'effective_return_pct',round(eq_return,2),
      'effective_rally_pct',round(eq_rally,2),
      'effective_net_pct',round(eq_net,2),
      'climate_support_pct',round(climate,2)
    ),
    'equipment_missing',jsonb_build_object('racket',v_missing_racket,'shoes',v_missing_shoes,'apparel',v_missing_apparel),
    'staff_support',jsonb_build_object(
      'source','travelling_tournament_staff',
      'match_multiplier',round(m,4),
      'bonus_percent',round((m-1)*100,2),
      'global_cap_percent',2.0
    )
  );
end;
$function$

