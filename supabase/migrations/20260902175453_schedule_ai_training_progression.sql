create extension if not exists pg_cron;

do $$
declare j record;
begin
  for j in select jobid from cron.job where jobname='tennis_legacy_ai_training_progression' loop
    perform cron.unschedule(j.jobid);
  end loop;
end $$;

select cron.schedule(
  'tennis_legacy_ai_training_progression',
  '7 * * * *',
  $cron$select public.process_ai_training_to_current_day_v1();$cron$
);
