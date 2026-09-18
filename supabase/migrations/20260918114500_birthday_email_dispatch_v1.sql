create or replace function public.claim_birthday_email_outbox_v1(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $function$
declare
  v_rows jsonb;
begin
  with candidates as (
    select bo.id
    from public.birthday_email_outbox bo
    where bo.status in ('pending','failed')
      and bo.next_attempt_at<=now()
      and bo.attempts<10
    order by bo.created_at
    for update skip locked
    limit greatest(1,least(coalesce(p_limit,20),50))
  ), claimed as (
    update public.birthday_email_outbox bo
    set status='sending',
        attempts=bo.attempts+1,
        last_attempt_at=now(),
        last_error=null,
        updated_at=now()
    from candidates c
    where bo.id=c.id
    returning bo.id,bo.birthday_reward_id,bo.user_id,bo.recipient_email,bo.subject,bo.text_body,bo.html_body,bo.attempts
  )
  select coalesce(jsonb_agg(to_jsonb(claimed)),'[]'::jsonb)
  into v_rows
  from claimed;

  return v_rows;
end;
$function$;

revoke all on function public.claim_birthday_email_outbox_v1(integer) from public,anon,authenticated;
grant execute on function public.claim_birthday_email_outbox_v1(integer) to service_role;

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
    body := '{"cron_token":"birthday-email-cron-v1-2026"}'::jsonb
  );$$
);
