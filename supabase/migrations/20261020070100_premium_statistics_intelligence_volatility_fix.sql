-- Follow-up for projects that already applied the first Premium Intelligence migration.
-- Existing get_world_statistics_v1() refreshes snapshots and is VOLATILE.
alter function public.get_premium_statistics_intelligence_v1(text,text) volatile;
