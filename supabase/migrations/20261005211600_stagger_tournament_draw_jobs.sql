-- Spread draw processing, repair, and health checks across a five-minute cycle.
-- The minute-0 boundary starts 17-21 jobs and has produced intermittent
-- "connection failed" pg_cron starts. Keep the repair after publication.
select cron.alter_job(
  (select jobid from cron.job where jobname='tennis-draw-publication-v1'),
  schedule := '1-56/5 * * * *'
);
select cron.alter_job(
  (select jobid from cron.job where jobname='tennis-tournament-draw-auto-repair-v1'),
  schedule := '3-58/5 * * * *'
);
select cron.alter_job(
  (select jobid from cron.job where jobname='tennis-tournament-draw-health-v1'),
  schedule := '4-59/5 * * * *'
);
