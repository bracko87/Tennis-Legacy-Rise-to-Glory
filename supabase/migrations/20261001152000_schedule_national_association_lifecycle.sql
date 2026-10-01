do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'process-national-association-lifecycle'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'process-national-association-lifecycle',
  '*/5 * * * *',
  $cron$
    select public.process_national_association_lifecycle_v1();
  $cron$
);

select public.process_national_association_lifecycle_v1();
