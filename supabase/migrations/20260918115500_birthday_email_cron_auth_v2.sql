create schema if not exists private;
revoke all on schema private from public,anon,authenticated;

create table if not exists private.internal_job_secrets (
  job_name text primary key,
  secret text not null default encode(gen_random_bytes(32),'hex'),
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now()
);

revoke all on private.internal_job_secrets from public,anon,authenticated;

insert into private.internal_job_secrets(job_name)
values('birthday_email_dispatch_v1')
on conflict(job_name) do nothing;

create or replace function public.validate_birthday_email_cron_token_v1(p_token text)
returns boolean
language sql
stable
security definer
set search_path=public,private,pg_temp
as $function$
  select exists(
    select 1
    from private.internal_job_secrets s
    where s.job_name='birthday_email_dispatch_v1'
      and s.secret=p_token
  );
$function$;

revoke all on function public.validate_birthday_email_cron_token_v1(text) from public,anon,authenticated;
grant execute on function public.validate_birthday_email_cron_token_v1(text) to service_role;

do $$
declare v_jobid bigint;
begin
  select jobid into v_jobid
  from cron.job
  where jobname='tennis-birthday-email-dispatch-v1'
  limit 1;
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end $$;

select cron.schedule(
  'tennis-birthday-email-dispatch-v1',
  '18 * * * *',
  $$select net.http_post(
    url := 'https://cwfznmroiqcyhfkfcrow.supabase.co/functions/v1/send-birthday-emails',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := jsonb_build_object(
      'cron_token',
      (select secret from private.internal_job_secrets where job_name='birthday_email_dispatch_v1')
    )
  );$$
);
