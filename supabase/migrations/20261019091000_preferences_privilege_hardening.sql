-- Supabase default privileges may grant authenticated users TRUNCATE/DELETE
-- on new public tables. Limit user interface settings to the three intended
-- operations; row-level security then scopes them to the signed-in account.
revoke all on table public.user_interface_preferences_v1 from public,anon,authenticated;
grant select,insert,update on table public.user_interface_preferences_v1 to authenticated;
