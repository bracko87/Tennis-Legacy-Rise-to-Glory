do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job where jobname='tennis-private-life-stock-quotes-v1' limit 1;
  if v_job_id is not null then
    perform cron.alter_job(v_job_id, schedule := '*/15 11-22 * * 1-5');
  end if;
end $$;