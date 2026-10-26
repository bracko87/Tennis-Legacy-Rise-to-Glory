-- Read-only/negative cross-user checks for the actual SECURITY DEFINER RPCs.
-- Entire script uses fake users in the disposable PostgreSQL database.
\set ON_ERROR_STOP on
begin;
insert into public.players(id,owner_user_id,player_type,country_code,home_city)
values('88888888-8888-8888-8888-888888888888',
 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','human','DE','Berlin');
insert into public.player_location_state(player_id,current_city,current_country_code,location_type)
values('88888888-8888-8888-8888-888888888888','Berlin','DE','home');
insert into public.tournament_entries(player_id,competition_id)
values('88888888-8888-8888-8888-888888888888',
 '44444444-4444-4444-4444-444444444444');
insert into public.player_tournament_preparation_plans(player_id,competition_id)
values('88888888-8888-8888-8888-888888888888',
 '44444444-4444-4444-4444-444444444444');

do $auth_isolation$
declare
 v_quote jsonb; v_count integer;
 v_foreign_jet uuid:='77777777-7777-7777-7777-777777777777';
 v_comp uuid:='44444444-4444-4444-4444-444444444444';
begin
 perform set_config('app.test_uid','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',true);
 v_quote:=public.quote_my_private_life_jet_v1(v_comp,v_foreign_jet,0);
 if coalesce((v_quote->>'active')::boolean,false) then
  raise exception 'IDOR: second player quoted the first player private jet: %',v_quote;end if;
 begin
  perform public.set_private_life_tournament_travel_v1(v_comp,'private_jet',v_foreign_jet);
  raise exception 'IDOR: second player booked the first player jet';
 exception when others then
  if SQLERRM like 'IDOR:%' then raise;end if;
  if SQLERRM not like '%owned travel-capable private jet%' then
   raise exception 'Unexpected authorization failure: %',SQLERRM;
  end if;
 end;
 select count(*) into v_count from public.player_tournament_travel_selection
  where player_id='88888888-8888-8888-8888-888888888888';
 if v_count<>0 then raise exception 'Foreign booking created despite rejection';end if;
 select count(*) into v_count from public.player_tournament_travel_selection
  where player_id='11111111-1111-1111-1111-111111111111'
    and competition_id=v_comp and travel_mode='private_jet'
    and owned_jet_asset_id=v_foreign_jet;
 if v_count<>1 then raise exception 'Second player mutated legitimate owner booking';end if;
 raise notice 'PASS: actual authenticated travel quote and booking RPCs reject foreign owned jets and preserve owner state';
end;$auth_isolation$;
rollback;
