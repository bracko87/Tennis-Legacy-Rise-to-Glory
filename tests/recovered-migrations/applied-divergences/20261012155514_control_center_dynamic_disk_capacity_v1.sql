
alter table public.control_center_platform_metrics_cache
  add column if not exists disk_total_bytes numeric,
  add column if not exists disk_used_bytes numeric;
