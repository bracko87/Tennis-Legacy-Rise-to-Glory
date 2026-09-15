revoke all on function public.get_referral_dashboard_v1() from public, anon;
grant execute on function public.get_referral_dashboard_v1() to authenticated;

revoke all on function public.record_referral_activity_v1(text) from public, anon;
grant execute on function public.record_referral_activity_v1(text) to authenticated;

revoke all on function public.register_referral_click_v1(text,text) from public;
grant execute on function public.register_referral_click_v1(text,text) to anon, authenticated;
