
insert into public.system_monitor_processes(
  process_key,label,category,description,source_kind,source_ref,user_sensitive,
  incident_severity,expected_interval_minutes,stale_after_minutes,email_alerts_enabled,sort_order
)
values
('cron:tennis-system-alert-email-dispatch-v1','System alert email dispatch','Core','Dispatches administrator incident emails through Resend.','cron','tennis-system-alert-email-dispatch-v1',true,'critical',2,8,true,2)
on conflict(process_key) do update set
  label=excluded.label,category=excluded.category,description=excluded.description,
  source_kind=excluded.source_kind,source_ref=excluded.source_ref,user_sensitive=excluded.user_sensitive,
  incident_severity=excluded.incident_severity,expected_interval_minutes=excluded.expected_interval_minutes,
  stale_after_minutes=excluded.stale_after_minutes,email_alerts_enabled=excluded.email_alerts_enabled,
  is_enabled=true,sort_order=excluded.sort_order,updated_at=now();

create or replace function public.get_admin_system_incidents_v1(
  p_status text default 'active',
  p_limit integer default 200
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_status text:=lower(trim(coalesce(p_status,'active')));
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if v_status not in ('active','open','acknowledged','resolved','all') then
    raise exception 'Invalid incident status filter.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',x.id,'process_key',x.process_key,'process_label',x.label,'category',x.category,
    'severity',x.severity,'status',x.status,'title',x.title,'message',x.message,
    'details',x.details,'first_seen_at',x.first_seen_at,'last_seen_at',x.last_seen_at,
    'occurrence_count',x.occurrence_count,'last_emailed_at',x.last_emailed_at,
    'acknowledged_at',x.acknowledged_at,'resolved_at',x.resolved_at,
    'resolution_note',x.resolution_note,
    'is_unread',not exists(
      select 1 from public.system_incident_admin_reads rr
      where rr.incident_id=x.id and rr.admin_user_id=auth.uid()
    )
  ) order by
    case x.severity when 'critical' then 1 when 'high' then 2 else 3 end,
    x.last_seen_at desc),'[]'::jsonb)
  into v_result
  from (
    select i.*,p.label,p.category
    from public.system_incidents i
    join public.system_monitor_processes p on p.process_key=i.process_key
    where
      v_status='all'
      or (v_status='active' and i.status in ('open','acknowledged'))
      or i.status=v_status
    order by i.last_seen_at desc
    limit greatest(1,least(coalesce(p_limit,200),1000))
  ) x;

  return v_result;
end;
$$;

revoke all on function public.get_admin_system_incidents_v1(text,integer) from public,anon,authenticated;
grant execute on function public.get_admin_system_incidents_v1(text,integer) to authenticated;
