revoke all on function public.quote_staff_negotiation_v1(uuid,smallint,numeric) from public, anon;
grant execute on function public.quote_staff_negotiation_v1(uuid,smallint,numeric) to authenticated;

revoke all on function public.negotiate_staff_offer_v1(uuid,smallint,numeric) from public, anon;
grant execute on function public.negotiate_staff_offer_v1(uuid,smallint,numeric) to authenticated;

revoke all on function public.confirm_staff_offer_v1(uuid) from public, anon;
grant execute on function public.confirm_staff_offer_v1(uuid) to authenticated;

revoke all on function public.quote_staff_termination_v1(uuid) from public, anon;
grant execute on function public.quote_staff_termination_v1(uuid) to authenticated;

revoke all on function public.terminate_staff_contract_v1(uuid) from public, anon;
grant execute on function public.terminate_staff_contract_v1(uuid) to authenticated;

-- Legacy one-step hiring bypasses the accepted-offer confirmation flow and is no
-- longer part of the client contract.
revoke all on function public.hire_staff_v1(uuid,smallint) from public, anon, authenticated;
