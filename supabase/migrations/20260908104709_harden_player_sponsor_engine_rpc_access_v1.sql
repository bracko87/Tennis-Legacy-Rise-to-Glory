revoke execute on function public.ensure_player_sponsor_offers_v1(uuid,boolean) from public, anon, authenticated;
revoke execute on function public.process_player_sponsor_payments_v1(uuid,integer) from public, anon, authenticated;
revoke execute on function public.sponsor_hash_unit_v1(text) from public, anon, authenticated;

grant execute on function public.get_player_sponsor_dashboard_v1() to authenticated;
grant execute on function public.sign_player_sponsor_offer_v1(uuid) to authenticated;
grant execute on function public.decline_player_sponsor_offer_v1(uuid) to authenticated;

do $$
begin
  if has_function_privilege('anon','public.ensure_player_sponsor_offers_v1(uuid,boolean)','EXECUTE') then
    raise exception 'anon must not execute internal sponsor offer generator';
  end if;
  if has_function_privilege('authenticated','public.ensure_player_sponsor_offers_v1(uuid,boolean)','EXECUTE') then
    raise exception 'authenticated must not directly execute internal sponsor offer generator';
  end if;
  if has_function_privilege('anon','public.process_player_sponsor_payments_v1(uuid,integer)','EXECUTE') then
    raise exception 'anon must not execute internal sponsor payment processor';
  end if;
  if not has_function_privilege('authenticated','public.get_player_sponsor_dashboard_v1()','EXECUTE') then
    raise exception 'authenticated sponsor dashboard access is missing';
  end if;
  if not has_function_privilege('authenticated','public.sign_player_sponsor_offer_v1(uuid)','EXECUTE') then
    raise exception 'authenticated sponsor signing access is missing';
  end if;
end $$;
