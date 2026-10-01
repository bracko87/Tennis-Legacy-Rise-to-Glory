create or replace function public.avatar_replacement_close_retention_v1()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_24h_deadline timestamptz;
begin
  v_24h_deadline := coalesce(new.created_at, now()) + interval '24 hours';

  if tg_op = 'INSERT' then
    new.reference_delete_after := least(
      coalesce(new.reference_delete_after, v_24h_deadline),
      v_24h_deadline
    );
    return new;
  end if;

  if new.status in ('completed','rejected','cancelled')
     and (old.status is distinct from new.status or new.reference_delete_after is null) then
    new.reference_delete_after := now();
  else
    new.reference_delete_after := least(
      coalesce(new.reference_delete_after, v_24h_deadline),
      v_24h_deadline
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_avatar_replacement_close_retention_v1 on public.avatar_replacement_requests;
create trigger trg_avatar_replacement_close_retention_v1
before insert or update of status, reference_delete_after, created_at
on public.avatar_replacement_requests
for each row
execute function public.avatar_replacement_close_retention_v1();

update public.avatar_replacement_requests
set reference_delete_after = case
  when status in ('completed','rejected','cancelled') then least(coalesce(reference_delete_after, now()), now())
  else least(coalesce(reference_delete_after, created_at + interval '24 hours'), created_at + interval '24 hours')
end,
updated_at = now()
where reference_deleted_at is null;

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'cleanup-avatar-reference-photos'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
end;
$$;

select cron.schedule(
  'cleanup-avatar-reference-photos',
  '*/5 * * * *',
  $cron$
    select net.http_post(
      url := 'https://cwfznmroiqcyhfkfcrow.supabase.co/functions/v1/cleanup-avatar-reference-photos',
      headers := '{"Content-Type":"application/json"}'::jsonb,
      body := '{}'::jsonb
    );
  $cron$
);
