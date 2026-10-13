CREATE OR REPLACE FUNCTION control_center_private.gcc_notify_new_system_incident_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'control_center_private'
AS $function$
begin
  if new.status not in ('open','investigating','acknowledged') then return null; end if;
  if TG_OP='UPDATE'
     and old.status in ('open','investigating','acknowledged')
     and old.severity is not distinct from new.severity
  then return null; end if;
  begin
    perform control_center_private.push_admin_change_event(
      'system-health',
      'incident:system-health:'||new.id::text||':'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSUS'),
      case when TG_OP='INSERT' then 'created' else 'updated' end,
      new.id::text,new.status,
      'Tennis Legacy: System Health issue',
      left(coalesce(new.title,'System issue')||' · '||coalesce(new.message,''),450)
    );
  exception when others then
    raise warning 'Unable to send Control Center incident push: %',sqlerrm;
  end;
  return null;
end;
$function$; 
revoke all on function control_center_private.gcc_notify_new_system_incident_v1() from public,anon,authenticated;
drop trigger if exists gcc_direct_system_issue_push_v1 on public.system_incidents;
create trigger gcc_direct_system_issue_push_v1 after insert or update of status,severity on public.system_incidents for each row execute function control_center_private.gcc_notify_new_system_incident_v1();
