revoke execute on function public.set_training_week_days_v1(jsonb) from public;
revoke execute on function public.set_training_week_days_v1(jsonb) from anon;
grant execute on function public.set_training_week_days_v1(jsonb) to authenticated;
