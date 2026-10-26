-- Real business-function execution on synthetic records, not just SQL parsing.
\set ON_ERROR_STOP on
begin;
do $$
declare p uuid:='11111111-1111-1111-1111-111111111111';
  v_morale integer; v_bonus integer; v_result jsonb; v_count integer;
  v_home jsonb;
begin
  insert into public.private_life_player_assets(id,player_id,catalog_code,acquisition_type,purchase_absolute_day)
   values('22222222-2222-2222-2222-222222222221',p,'watch_a','purchase',391);
  select morale into v_morale from public.player_skills where player_id=p;
  if v_morale<>51 then raise exception 'watch morale expected 51, got %',v_morale; end if;
  insert into public.private_life_player_assets(id,player_id,catalog_code,acquisition_type,purchase_absolute_day)
   values('22222222-2222-2222-2222-222222222222',p,'car_a','purchase',391);
  select morale into v_morale from public.player_skills where player_id=p;
  if v_morale<>53 then raise exception 'watch+car morale expected 53, got %',v_morale; end if;
  insert into public.private_life_player_assets(id,player_id,catalog_code,location_code,acquisition_type,purchase_absolute_day)
   values('22222222-2222-2222-2222-222222222223',p,'villa_a','barcelona','purchase',391);
  select morale into v_morale from public.player_skills where player_id=p;
  if v_morale<>53 then raise exception 'morale cap expected 53, got %',v_morale; end if;
  perform set_config('app.day','2',true);
  insert into public.private_life_player_assets(id,player_id,catalog_code,acquisition_type,purchase_absolute_day)
   values('22222222-2222-2222-2222-222222222224',p,'watch_b','purchase',392);
  select count(*) into v_count from public.player_lifestyle_morale_events where player_id=p;
  if v_count<>3 then raise exception 'category cooldown failed, expected 3 events, got %',v_count; end if;
  perform set_config('app.day','16',true);
  perform public.refresh_player_lifestyle_morale_v1(p);
  select morale into v_morale from public.player_skills where player_id=p;
  if v_morale<>51 then raise exception 'decay at day 16 expected 51, got %',v_morale; end if;
  perform set_config('app.day','24',true);
  perform public.refresh_player_lifestyle_morale_v1(p);
  select morale into v_morale from public.player_skills where player_id=p;
  if v_morale<>50 then raise exception 'decay expired expected 50, got %',v_morale; end if;
  v_result:=public.set_private_life_home_base_v1('22222222-2222-2222-2222-222222222223');
  if v_result->>'status'<>'scheduled' then raise exception 'Home move not scheduled'; end if;
  v_home:=public.get_player_home_base_v1(p);
  if v_home->>'city'<>'Belgrade' then raise exception 'Pending move must not instantly move home'; end if;
  perform set_config('app.day','26',true);
  select public.process_due_lifestyle_moves_v1() into v_count;
  if v_count<>1 then raise exception 'Expected one finalized move, got %',v_count; end if;
  v_home:=public.get_player_home_base_v1(p);
  if v_home->>'city'<>'Barcelona' or v_home->>'nationality'<>'RS' then
    raise exception 'Home / nationality mismatch: %',v_home; end if;
  select count(*) into v_count from public.test_career_transactions
    where player_id=p and amount=-5000;
  if v_count<>1 then raise exception 'Expected one move fee, got %',v_count; end if;
  select public.process_due_lifestyle_moves_v1() into v_count;
  if v_count<>0 then raise exception 'Repeated reconciliation processed move twice'; end if;
  begin
    insert into public.private_life_asset_sale_listings(player_id,player_asset_id,status)
     values(p,'22222222-2222-2222-2222-222222222223','pending');
    raise exception 'Active residence listing unexpectedly succeeded';
  exception when others then
    if SQLERRM='Active residence listing unexpectedly succeeded' then raise; end if;
    if SQLERRM not like '%Select a different Home Base%' then raise; end if;
  end;
  begin
    perform public.set_private_life_home_base_v1('22222222-2222-2222-2222-222222222223');
    raise exception 'Cooldown unexpectedly allowed another move';
  exception when others then
    if SQLERRM='Cooldown unexpectedly allowed another move' then raise; end if;
    if SQLERRM not like '%30 game days%' then raise; end if;
  end;
  raise notice 'PASS: purchases, cap, 14-day cooldown, decay, two-day move, nationality, fee idempotency, listing and 30-day cooldown';
end $$;
rollback;
