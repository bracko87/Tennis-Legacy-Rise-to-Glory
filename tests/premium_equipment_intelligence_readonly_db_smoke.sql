-- Regression for the original HTTP 405 / SQLSTATE 25006 defect:
-- PostgREST runs STABLE Premium RPCs in a read-only transaction.
-- Formerly get_premium_equipment_intelligence_v1 called the mutable
-- get_equipment_dashboard_v1 -> sync_player_technical_sponsor_contracts_v1.
-- This test MUST pass under SET TRANSACTION READ ONLY.
begin;
set transaction read only;
do $test$
declare
 p record;
 v_report jsonb;
 v_inventory_count integer;
 v_worlds text[]:='{}';
 v_tested integer:=0;
begin
 for p in
   select x.id,x.owner_user_id,x.world
   from public.players x
   where x.player_type='human' and x.owner_user_id is not null
     and (exists(select 1 from public.premium_memberships m
       where m.user_id=x.owner_user_id and m.status='active'
         and m.plan_code='premium'
         and (m.current_period_end is null or m.current_period_end>now()))
     or exists(select 1 from public.tennis_premium_trials_v1 trial
       where trial.user_id=x.owner_user_id and trial.expires_at>now()))
 loop
   perform set_config('request.jwt.claim.sub',p.owner_user_id::text,true);
   -- The call itself reproduces the real PostgREST read-only context.
   v_report:=public.get_premium_equipment_intelligence_v1(p.id);
   select count(*)::integer into v_inventory_count
   from public.player_equipment_inventory i
   join public.equipment_catalog_items c on c.id=i.catalog_item_id
     and c.is_active and c.item_type in ('racket','shoes','apparel','accessory')
   where i.player_id=p.id;
   if v_report->>'player_id' <> p.id::text
     or v_report->>'world'<>p.world
     or (v_report->>'owned_count')::integer<>v_inventory_count
     or jsonb_array_length(v_report->'items')<>v_inventory_count
     or jsonb_typeof(v_report->'replacement_candidates')<>'array'
   then raise exception 'Read-only Premium report or inventory reconciliation failed for %',p.world;
   end if;
   v_worlds:=array_append(v_worlds,p.world);
   v_tested:=v_tested+1;
 end loop;
 if v_tested<2 or not ('ATP'=any(v_worlds)) or not ('WTA'=any(v_worlds)) then
   raise exception 'Insufficient ATP/WTA Premium test fixtures';
 end if;
 if has_function_privilege('anon'::regrole,
   'public.get_premium_equipment_intelligence_v1(uuid)','EXECUTE') then
   raise exception 'Anonymous execution grant not revoked';
 end if;
end
$test$;
rollback;
