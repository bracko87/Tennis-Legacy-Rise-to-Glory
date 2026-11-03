-- Missing core equipment penalties, applied to the authoritative match-engine profile.
-- No production deployment without the owner's explicit release approval.
create or replace function public.get_match_engine_profile_for_match_v2(p_player_id uuid,p_surface text,p_match_id uuid) returns jsonb language plpgsql stable security definer set search_path='public' as $$
declare b jsonb;e jsonb;eq jsonb;m numeric:=1;eq_serve numeric:=0;eq_return numeric:=0;eq_rally numeric:=0;eq_net numeric:=0;climate numeric:=0;temp numeric;eq_avg numeric:=0;missing_racket boolean;missing_shoes boolean;missing_apparel boolean;v_human boolean:=false;
begin
 b:=public.get_match_engine_profile_for_match_base_v2(p_player_id,p_surface,p_match_id);eq:=public.get_equipment_match_modifiers_readonly_v2(p_player_id,p_surface);
 begin temp:=nullif(b->'weather'->>'temperature_c','')::numeric;exception when others then temp:=null;end;
 if temp is not null and temp>=28 then climate:=coalesce((eq->>'heat_resistance_pct')::numeric,0)*.35;elsif temp is not null and temp<=12 then climate:=coalesce((eq->>'cold_resistance_pct')::numeric,0)*.35;end if;
 eq_serve:=greatest(-4,least(4,coalesce((eq->>'serve_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.10));eq_return:=greatest(-4,least(4,coalesce((eq->>'return_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.12+climate));eq_rally:=greatest(-4,least(4,coalesce((eq->>'rally_pct')::numeric,0)+coalesce((eq->>'stamina_pct')::numeric,0)*.22+climate));eq_net:=greatest(-4,least(4,coalesce((eq->>'net_pct')::numeric,0)+coalesce((eq->>'focus_pct')::numeric,0)*.10));eq_avg:=(eq_serve+eq_return+eq_rally+eq_net)/4.0;
 b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*(1+eq_serve/100.0),2)));b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*(1+eq_return/100.0),2)));b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*(1+eq_rally/100.0),2)));b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*(1+eq_net/100.0),2)));b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*(1+eq_avg/100.0),2)));

 -- Missing essential equipment directly reduces match-engine ratings (not just bonuses).
 select not exists(
   select 1 from public.player_equipment_loadouts l
   join public.player_equipment_inventory i on i.id=l.racket_inventory_id
   where l.player_id=p_player_id and i.player_id=p_player_id and i.condition>0
 ) into missing_racket;
 select not exists(
   select 1 from public.player_equipment_loadouts l
   join public.player_equipment_inventory i on i.id=l.shoes_inventory_id
   where l.player_id=p_player_id and i.player_id=p_player_id and i.condition>0
 ) into missing_shoes;
 select not exists(
   select 1 from public.player_equipment_loadouts l
   join public.player_equipment_inventory i on i.id=l.apparel_inventory_id
   where l.player_id=p_player_id and i.player_id=p_player_id and i.condition>0
 ) into missing_apparel;
 -- AI opponents do not own equipment; never apply human inventory penalties to AI.
 select exists(select 1 from public.players p where p.id=p_player_id and p.owner_user_id is not null)
   into v_human;
 missing_racket:=missing_racket and v_human;
 missing_shoes:=missing_shoes and v_human;
 missing_apparel:=missing_apparel and v_human;
 -- Racket is essential. Shoes mainly affect court movement and endurance;
 -- clothing contributes a smaller all-round comfort penalty.
 if missing_racket then
   b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b#>>'{ratings,serve}')::numeric*.65,2)));
   b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b#>>'{ratings,return}')::numeric*.65,2)));
   b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b#>>'{ratings,rally}')::numeric*.65,2)));
   b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b#>>'{ratings,net}')::numeric*.65,2)));
   b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b#>>'{ratings,effective_overall}')::numeric*.65,2)));
 end if;
 if missing_shoes then
   b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b#>>'{ratings,return}')::numeric*.93,2)));
   b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b#>>'{ratings,rally}')::numeric*.93,2)));
   b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b#>>'{ratings,net}')::numeric*.93,2)));
   b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b#>>'{ratings,effective_overall}')::numeric*.95,2)));
 end if;
 if missing_apparel then
   b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b#>>'{ratings,serve}')::numeric*.97,2)));
   b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b#>>'{ratings,return}')::numeric*.97,2)));
   b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b#>>'{ratings,rally}')::numeric*.97,2)));
   b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b#>>'{ratings,net}')::numeric*.97,2)));
   b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b#>>'{ratings,effective_overall}')::numeric*.97,2)));
 end if;
 e:=public.get_player_staff_effects_v1(p_player_id);m:=greatest(1,least(1.02,coalesce((e->>'match_staff_multiplier')::numeric,1)));if m>1 then b:=jsonb_set(b,'{ratings,serve}',to_jsonb(round((b->'ratings'->>'serve')::numeric*m,2)));b:=jsonb_set(b,'{ratings,return}',to_jsonb(round((b->'ratings'->>'return')::numeric*m,2)));b:=jsonb_set(b,'{ratings,rally}',to_jsonb(round((b->'ratings'->>'rally')::numeric*m,2)));b:=jsonb_set(b,'{ratings,net}',to_jsonb(round((b->'ratings'->>'net')::numeric*m,2)));b:=jsonb_set(b,'{ratings,effective_overall}',to_jsonb(round((b->'ratings'->>'effective_overall')::numeric*m,2)));end if;
 return b||jsonb_build_object('equipment_support',eq||jsonb_build_object('effective_serve_pct',round(eq_serve,2),'effective_return_pct',round(eq_return,2),'effective_rally_pct',round(eq_rally,2),'effective_net_pct',round(eq_net,2),'climate_support_pct',round(climate,2)),'equipment_missing',jsonb_build_object('racket',missing_racket,'shoes',missing_shoes,'apparel',missing_apparel),'staff_support',jsonb_build_object('match_multiplier',round(m,4),'bonus_percent',round((m-1)*100,2),'global_cap_percent',2.0));
end; $$;
