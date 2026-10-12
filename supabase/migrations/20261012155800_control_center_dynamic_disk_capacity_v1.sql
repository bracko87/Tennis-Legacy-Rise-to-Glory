-- Keep Game Control Center capacity metrics tied to the provisioned Supabase disk.
alter table public.control_center_platform_metrics_cache
  add column if not exists disk_total_bytes numeric,
  add column if not exists disk_used_bytes numeric;

CREATE OR REPLACE FUNCTION public.control_center_disk_capacity_bytes_v1()
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select coalesce(
    (select disk_total_bytes from public.control_center_platform_metrics_cache where id=1),
    8589934592::numeric
  );
$function$;

CREATE OR REPLACE FUNCTION public.control_center_disk_used_bytes_v1()
 RETURNS numeric
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  select coalesce(
    (select disk_used_bytes from public.control_center_platform_metrics_cache where id=1),
    pg_database_size(current_database())::numeric + coalesce((select sum(size)::numeric from pg_ls_waldir()),0)
  );
$function$;

CREATE OR REPLACE FUNCTION public.control_center_resource_metrics_v1()
 RETURNS TABLE(metric_key text, metric_label text, used_value numeric, total_value numeric, unit text, status text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'auth', 'storage'
AS $function$
with
db as (
  select pg_database_size(current_database())::numeric db_bytes,
         coalesce((select sum(size)::numeric from pg_ls_waldir()),0) wal_bytes
),
st as (
  select coalesce(sum((metadata->>'size')::numeric),0) storage_bytes
  from storage.objects where metadata ? 'size'
),
au as (
  select
    count(*) filter(where last_sign_in_at>=date_trunc('month',now()))::numeric mau,
    (select count(*)::numeric from auth.sessions where created_at>=now()-interval '24 hours') auth24
  from auth.users
),
conn as (
  select (select count(*)::numeric from pg_stat_activity where datname=current_database()) conns,
         current_setting('max_connections')::numeric maxc
),
ds as (
  select coalesce(round(100.0*blks_hit/nullif(blks_hit+blks_read,0),2),100)::numeric cache_hit,
         coalesce(round(100.0*xact_commit/nullif(xact_commit+xact_rollback,0),2),100)::numeric tx_success
  from pg_stat_database where datname=current_database()
),
traffic as (
  select coalesce(sum(pageview_count),0)::numeric pageviews
  from public.site_analytics_daily_sessions
  where last_seen_at>=now()-interval '24 hours'
),
latest as (
  select distinct on(p.process_key)
    p.process_key,p.stale_after_minutes,r.status,
    coalesce(r.finished_at,r.started_at,r.created_at) observed_at
  from public.system_monitor_processes p
  left join public.system_monitor_runs r on r.process_key=p.process_key
  where p.is_enabled=true
  order by p.process_key,coalesce(r.finished_at,r.started_at,r.created_at) desc nulls last
),
ph as (
  select count(*)::numeric total,
         count(*) filter(where status in('success','running') and (stale_after_minutes is null or observed_at is null or observed_at>=now()-make_interval(mins=>stale_after_minutes)))::numeric healthy
  from latest
),
rh as (
  select count(*)::numeric total,count(*) filter(where status='success')::numeric good
  from public.system_monitor_runs where created_at>=now()-interval '24 hours'
),
inci as (
  select count(*) filter(where status<>'resolved')::numeric open_count,
         count(*) filter(where status<>'resolved' and lower(severity) in('critical','error'))::numeric critical_count
  from public.system_incidents
)
select 'database_size','Database size',db_bytes,public.control_center_disk_capacity_bytes_v1(),'bytes',
       case when db_bytes/public.control_center_disk_capacity_bytes_v1()>=.90 then 'critical' when db_bytes/public.control_center_disk_capacity_bytes_v1()>=.75 then 'warning' else 'healthy' end from db
union all
select 'disk_usage','Disk (DB + WAL)',db_bytes+wal_bytes,public.control_center_disk_capacity_bytes_v1(),'bytes',
       case when (db_bytes+wal_bytes)/public.control_center_disk_capacity_bytes_v1()>=.90 then 'critical' when (db_bytes+wal_bytes)/public.control_center_disk_capacity_bytes_v1()>=.75 then 'warning' else 'healthy' end from db
union all
select 'storage_usage','Object storage',storage_bytes,107374182400,'bytes',
       case when storage_bytes/107374182400>=.90 then 'critical' when storage_bytes/107374182400>=.75 then 'warning' else 'healthy' end from st
union all
select 'monthly_active_users','Monthly active users',mau,100000,'users',
       case when mau>=90000 then 'critical' when mau>=75000 then 'warning' else 'healthy' end from au
union all
select 'database_connections','DB connections',conns,maxc,'connections',
       case when conns/maxc>=.90 then 'critical' when conns/maxc>=.75 then 'warning' else 'healthy' end from conn
union all
select 'cache_hit_rate','Cache hit rate',cache_hit,100,'% ',
       case when cache_hit<70 then 'critical' when cache_hit<90 then 'warning' else 'healthy' end from ds
union all
select 'transaction_success','Transaction success',tx_success,100,'%',
       case when tx_success<85 then 'critical' when tx_success<90 then 'warning' else 'healthy' end from ds
union all
select 'system_process_health','Process health',case when total=0 then 0 else round(100*healthy/total,2) end,100,'%',
       case when total=0 or 100*healthy/nullif(total,0)<70 then 'critical' when 100*healthy/nullif(total,0)<95 then 'warning' else 'healthy' end from ph
union all
select 'monitor_run_success','Monitor run success',case when total=0 then 100 else round(100*good/total,2) end,100,'%',
       case when total>0 and 100*good/nullif(total,0)<80 then 'critical' when total>0 and 100*good/nullif(total,0)<95 then 'warning' else 'healthy' end from rh
union all
select 'pageviews_24h','Pageviews (24h)',pageviews,null,'pageviews','healthy' from traffic
union all
select 'auth_activity_24h','Auth sessions (24h)',auth24,null,'sessions','healthy' from au
union all
select 'open_incidents','Open incidents',open_count,null,'incidents',
       case when critical_count>0 then 'critical' when open_count>0 then 'warning' else 'healthy' end from inci;
$function$;

CREATE OR REPLACE FUNCTION control_center_private.build_hourly_telemetry_payload()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'storage', 'control_center_private'
AS $function$
declare
  v_db_size numeric;
  v_storage_size numeric;
  v_active_users numeric;
  v_connections numeric;
  v_max_connections numeric;
  v_cache_hit numeric;
  v_index_cache_hit numeric;
  v_open_incidents integer;
  v_critical_incidents integer;
  v_failed_monitors integer;
  v_project_status text;
begin
  select pg_database_size(current_database())::numeric into v_db_size;

  select coalesce(sum(
    case when (metadata->>'size') ~ '^[0-9]+$' then (metadata->>'size')::numeric else 0 end
  ),0)
  into v_storage_size
  from storage.objects;

  select count(*)::numeric into v_active_users
  from auth.users
  where last_sign_in_at >= now() - interval '30 days';

  select count(*)::numeric into v_connections
  from pg_stat_activity
  where datname = current_database();

  select current_setting('max_connections')::numeric into v_max_connections;

  select case when (blks_hit + blks_read) > 0
         then round((100.0 * blks_hit / (blks_hit + blks_read))::numeric,2)
         else 100 end
  into v_cache_hit
  from pg_stat_database
  where datname = current_database();

  select case when sum(idx_blks_hit + idx_blks_read) > 0
         then round((100.0 * sum(idx_blks_hit) / sum(idx_blks_hit + idx_blks_read))::numeric,2)
         else 100 end
  into v_index_cache_hit
  from pg_statio_user_indexes;

  select count(*)::int,
         count(*) filter (where severity = 'critical')::int
    into v_open_incidents, v_critical_incidents
  from public.system_incidents
  where status in ('open','investigating','acknowledged');

  select count(*)::int into v_failed_monitors
  from (
    select distinct on (process_key) process_key, status
    from public.system_monitor_runs
    order by process_key, coalesce(finished_at, started_at, created_at) desc
  ) x
  where lower(coalesce(status,'')) not in ('ok','healthy','success','succeeded','completed');

  v_project_status := case
    when v_critical_incidents > 0 then 'critical'
    when v_open_incidents > 0 or v_failed_monitors > 0 then 'warning'
    else 'healthy'
  end;

  return jsonb_build_object(
    'sourceProjectRef', 'cwfznmroiqcyhfkfcrow',
    'projectStatus', v_project_status,
    'metrics', jsonb_build_array(
      jsonb_build_object('key','database_size','label','Database size','used',v_db_size,'total',public.control_center_disk_capacity_bytes_v1(),'unit','bytes','status',
        case when v_db_size >= 0.8 * public.control_center_disk_capacity_bytes_v1() then 'critical' when v_db_size >= 0.6 * public.control_center_disk_capacity_bytes_v1() then 'warning' else 'healthy' end),
      jsonb_build_object('key','storage_usage','label','Object storage','used',v_storage_size,'total',107374182400,'unit','bytes','status',
        case when v_storage_size >= 0.8 * 107374182400 then 'critical' when v_storage_size >= 0.6 * 107374182400 then 'warning' else 'healthy' end),
      jsonb_build_object('key','monthly_active_users','label','Monthly active users','used',v_active_users,'total',100000,'unit','users','status',
        case when v_active_users >= 80000 then 'critical' when v_active_users >= 60000 then 'warning' else 'healthy' end),
      jsonb_build_object('key','database_connections','label','DB connections','used',v_connections,'total',v_max_connections,'unit','connections','status',
        case when v_max_connections > 0 and v_connections / v_max_connections >= 0.85 then 'critical'
             when v_max_connections > 0 and v_connections / v_max_connections >= 0.65 then 'warning'
             else 'healthy' end),
      jsonb_build_object('key','database_cache_hit','label','DB cache hit','used',v_cache_hit,'total',100,'unit','%','status',
        case when v_cache_hit < 90 then 'critical' when v_cache_hit < 95 then 'warning' else 'healthy' end),
      jsonb_build_object('key','index_cache_hit','label','Index cache hit','used',v_index_cache_hit,'total',100,'unit','%','status',
        case when v_index_cache_hit < 90 then 'critical' when v_index_cache_hit < 95 then 'warning' else 'healthy' end)
    ),
    'healthChecks', jsonb_build_array(
      jsonb_build_object('area','System Health','key','database_connectivity','label','Database connectivity','status','healthy','text','Online','message','Postgres responded to hourly telemetry collector'),
      jsonb_build_object('area','System Health','key','system_monitoring','label','System monitoring','status',
        case when v_failed_monitors > 0 then 'warning' else 'healthy' end,
        'value',v_failed_monitors,'unit','failing','message',v_failed_monitors || ' latest monitor runs are non-success'),
      jsonb_build_object('area','System Health','key','incident_count','label','Open system incidents','status',
        case when v_critical_incidents > 0 then 'critical' when v_open_incidents > 0 then 'warning' else 'healthy' end,
        'value',v_open_incidents,'unit','incidents')
    ),
    'incidents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'incidentKey','system:' || coalesce(dedupe_key,id::text),
        'area','System Health',
        'severity',case when severity in ('info','warning','critical') then severity else 'warning' end,
        'status',case when status='resolved' then 'resolved' else 'open' end,
        'title',title,
        'description',message
      ))
      from public.system_incidents
      where status in ('open','investigating','acknowledged')
    ), '[]'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION control_center_private.build_telemetry_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'storage', 'control_center_private'
AS $function$
declare
  v_db_bytes bigint := 0;
  v_wal_bytes bigint := 0;
  v_storage_bytes bigint := 0;
  v_mau bigint := 0;
  v_auth_24h bigint := 0;
  v_connections bigint := 0;
  v_max_connections bigint := 1;
  v_cache_hit numeric := 0;
  v_tx_success numeric := 0;
  v_pageviews_24h bigint := 0;
  v_sessions_today bigint := 0;
  v_visitors_today bigint := 0;
  v_process_total bigint := 0;
  v_process_healthy bigint := 0;
  v_runs_24h bigint := 0;
  v_runs_success_24h bigint := 0;
  v_open_incidents bigint := 0;
  v_critical_incidents bigint := 0;
  v_bugs_open bigint := 0;
  v_bugs_high bigint := 0;
  v_reviews_pending bigint := 0;
  v_process_health_pct numeric := 0;
  v_run_success_pct numeric := 100;
  v_project_status text := 'healthy';
  v_health_checks jsonb := '[]'::jsonb;
  v_process_checks jsonb := '[]'::jsonb;
  v_incidents jsonb := '[]'::jsonb;
  
begin
  select pg_database_size(current_database())::bigint into v_db_bytes;
  select coalesce(sum(size)::bigint,0) into v_wal_bytes from pg_ls_waldir();

  select coalesce(sum((metadata->>'size')::bigint),0)::bigint
  into v_storage_bytes
  from storage.objects
  where metadata ? 'size';

  select count(*) into v_mau from auth.users
  where last_sign_in_at >= date_trunc('month',now());

  select count(*) into v_auth_24h from auth.sessions
  where created_at >= now()-interval '24 hours';

  select count(*) into v_connections from pg_stat_activity
  where datname=current_database();

  v_max_connections := current_setting('max_connections')::bigint;

  select
    coalesce(round(100.0*blks_hit/nullif(blks_hit+blks_read,0),2),100),
    coalesce(round(100.0*xact_commit/nullif(xact_commit+xact_rollback,0),2),100)
  into v_cache_hit,v_tx_success
  from pg_stat_database where datname=current_database();

  select coalesce(sum(pageview_count),0)::bigint into v_pageviews_24h
  from public.site_analytics_daily_sessions
  where last_seen_at >= now()-interval '24 hours';

  select count(*) into v_sessions_today
  from public.site_analytics_daily_sessions where analytics_date=current_date;

  select count(*) into v_visitors_today
  from public.site_analytics_daily_visitors where analytics_date=current_date;

  with latest as (
    select distinct on (p.process_key)
      p.process_key,p.label,p.stale_after_minutes,r.status,
      coalesce(r.finished_at,r.started_at,r.created_at) as observed_at
    from public.system_monitor_processes p
    left join public.system_monitor_runs r on r.process_key=p.process_key
    where p.is_enabled=true
    order by p.process_key,coalesce(r.finished_at,r.started_at,r.created_at) desc nulls last
  )
  select
    count(*)::bigint,
    count(*) filter (
      where status in ('success','running')
        and (stale_after_minutes is null or observed_at is null
             or observed_at >= now()-make_interval(mins=>stale_after_minutes))
    )::bigint,
    coalesce(jsonb_agg(
      jsonb_build_object(
        'area','System Health',
        'key','process_'||process_key,
        'label',label,
        'status',case
          when status='error' then 'critical'
          when status='warning' then 'warning'
          when stale_after_minutes is not null and observed_at is not null
               and observed_at < now()-make_interval(mins=>stale_after_minutes) then 'warning'
          when status is null then 'pending'
          else 'healthy'
        end,
        'text',coalesce(status,'No run'),
        'message',case
          when status='error' then 'Latest monitored run failed'
          when status='warning' then 'Latest monitored run completed with warnings'
          when stale_after_minutes is not null and observed_at is not null
               and observed_at < now()-make_interval(mins=>stale_after_minutes) then 'Process heartbeat is stale'
          else 'Latest monitored run is within expected limits'
        end
      ) order by process_key
    ),'[]'::jsonb)
  into v_process_total,v_process_healthy,v_process_checks
  from latest;

  v_process_health_pct := case when v_process_total=0 then 0 else round(100.0*v_process_healthy/v_process_total,2) end;

  select count(*)::bigint,count(*) filter(where status='success')::bigint
  into v_runs_24h,v_runs_success_24h
  from public.system_monitor_runs
  where created_at >= now()-interval '24 hours';

  v_run_success_pct := case when v_runs_24h=0 then 100 else round(100.0*v_runs_success_24h/v_runs_24h,2) end;

  select
    count(*) filter(where status <> 'resolved')::bigint,
    count(*) filter(where status <> 'resolved' and lower(severity) in ('critical','error'))::bigint
  into v_open_incidents,v_critical_incidents
  from public.system_incidents;

  select
    count(*) filter(where status not in ('resolved','closed'))::bigint,
    count(*) filter(where status not in ('resolved','closed') and lower(coalesce(severity,'')) in ('critical','high'))::bigint
  into v_bugs_open,v_bugs_high
  from public.bug_reports;

  select count(*)::bigint into v_reviews_pending
  from public.player_homepage_reviews where status='pending';

  

  if v_critical_incidents > 0 or v_process_health_pct < 70 then
    v_project_status := 'critical';
  elsif v_open_incidents > 0 or  v_process_health_pct < 95 or v_run_success_pct < 95 then
    v_project_status := 'warning';
  else
    v_project_status := 'healthy';
  end if;

  v_health_checks :=
    v_process_checks ||
    jsonb_build_array(
      jsonb_build_object('area','System Health','key','overall_process_health','label','Overall process health','status',case when v_process_health_pct>=95 then 'healthy' when v_process_health_pct>=70 then 'warning' else 'critical' end,'value',v_process_health_pct,'text',v_process_health_pct::text||'% healthy','unit','%','message',v_process_healthy::text||' of '||v_process_total::text||' monitored processes healthy'),
      jsonb_build_object('area','Analytics','key','sessions_today','label','Sessions today','status','healthy','value',v_sessions_today,'text',v_sessions_today::text||' sessions','unit','sessions','message','Recorded website/game sessions today'),
      jsonb_build_object('area','Analytics','key','visitors_today','label','Visitors today','status','healthy','value',v_visitors_today,'text',v_visitors_today::text||' visitors','unit','visitors','message','Unique visitors recorded today'),
      jsonb_build_object('area','Analytics','key','pageviews_24h','label','Pageviews (24h)','status','healthy','value',v_pageviews_24h,'text',v_pageviews_24h::text||' pageviews','unit','pageviews','message','Pageviews recorded during the last 24 hours'),
      jsonb_build_object('area','Bug Reports','key','bug_reports_open','label','Open bug reports','status',case when v_bugs_high>0 then 'critical' when v_bugs_open>0 then 'warning' else 'healthy' end,'value',v_bugs_open,'text',v_bugs_open::text||' open','unit','reports','message',v_bugs_high::text||' high/critical unresolved reports'),
      jsonb_build_object('area','Player Reviews','key','reviews_pending','label','Pending player reviews','status',case when v_reviews_pending>0 then 'warning' else 'healthy' end,'value',v_reviews_pending,'text',v_reviews_pending::text||' pending','unit','reviews','message','Homepage reviews awaiting moderation')
      ,
      jsonb_build_object('area','System Health','key','monitoring_coverage','label','Monitoring coverage','status',case when v_process_total > 0 then 'healthy' else 'warning' end,'value',v_process_total,'text',v_process_total::text || ' monitored processes','unit','processes','message','Enabled system monitoring processes')
    );

  with source_incidents as (
    select
      coalesce(nullif(dedupe_key,''),id::text) as incident_key,
      'System Health'::text as area,
      case
        when lower(coalesce(severity,'')) in ('critical','error') then 'critical'
        when lower(coalesce(severity,'')) in ('warning','warn') then 'warning'
        else 'info'
      end as severity,
      case when status='resolved' then 'resolved'
           when status in ('acknowledged','investigating') then 'investigating'
           else 'open' end as status,
      title,message as description,last_seen_at,resolved_at
    from public.system_incidents
    where status <> 'resolved' or resolved_at >= now()-interval '2 hours'
    
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'incidentKey',incident_key,'area',area,'severity',severity,'status',status,
      'title',title,'description',description
    ) order by last_seen_at desc nulls last
  ),'[]'::jsonb)
  into v_incidents
  from source_incidents;

  return jsonb_build_object(
    'sourceProjectRef','cwfznmroiqcyhfkfcrow',
    'projectStatus',v_project_status,
    'metrics',jsonb_build_array(
      jsonb_build_object('key','database_size','label','Database size','used',v_db_bytes,'total',public.control_center_disk_capacity_bytes_v1(),'unit','bytes','status',case when v_db_bytes/public.control_center_disk_capacity_bytes_v1()>=.90 then 'critical' when v_db_bytes/public.control_center_disk_capacity_bytes_v1()>=.75 then 'warning' else 'healthy' end),
      jsonb_build_object('key','disk_usage','label','Disk (DB + WAL)','used',v_db_bytes+v_wal_bytes,'total',public.control_center_disk_capacity_bytes_v1(),'unit','bytes','status',case when (v_db_bytes+v_wal_bytes)/public.control_center_disk_capacity_bytes_v1()>=.90 then 'critical' when (v_db_bytes+v_wal_bytes)/public.control_center_disk_capacity_bytes_v1()>=.75 then 'warning' else 'healthy' end),
      jsonb_build_object('key','storage_usage','label','Object storage','used',v_storage_bytes,'total',107374182400,'unit','bytes','status',case when v_storage_bytes/107374182400.0>=.90 then 'critical' when v_storage_bytes/107374182400.0>=.75 then 'warning' else 'healthy' end),
      jsonb_build_object('key','monthly_active_users','label','Monthly active users','used',v_mau,'total',100000,'unit','users','status',case when v_mau>=90000 then 'critical' when v_mau>=75000 then 'warning' else 'healthy' end),
      jsonb_build_object('key','database_connections','label','DB connections','used',v_connections,'total',v_max_connections,'unit','connections','status',case when v_connections::numeric/v_max_connections>=.90 then 'critical' when v_connections::numeric/v_max_connections>=.75 then 'warning' else 'healthy' end),
      jsonb_build_object('key','cache_hit_rate','label','Cache hit rate','used',v_cache_hit,'total',100,'unit','%','status',case when v_cache_hit<70 then 'critical' when v_cache_hit<90 then 'warning' else 'healthy' end),
      jsonb_build_object('key','transaction_success','label','Transaction success','used',v_tx_success,'total',100,'unit','%','status',case when v_tx_success<85 then 'critical' when v_tx_success<90 then 'warning' else 'healthy' end),
      jsonb_build_object('key','system_process_health','label','Process health','used',v_process_health_pct,'total',100,'unit','%','status',case when v_process_health_pct<70 then 'critical' when v_process_health_pct<95 then 'warning' else 'healthy' end),
      jsonb_build_object('key','monitor_run_success','label','Monitor run success','used',v_run_success_pct,'total',100,'unit','%','status',case when v_run_success_pct<80 then 'critical' when v_run_success_pct<95 then 'warning' else 'healthy' end),
      jsonb_build_object('key','pageviews_24h','label','Pageviews (24h)','used',v_pageviews_24h,'total',null,'unit','pageviews','status','healthy'),
      jsonb_build_object('key','auth_activity_24h','label','Auth sessions (24h)','used',v_auth_24h,'total',null,'unit','sessions','status','healthy'),
      jsonb_build_object('key','open_incidents','label','Open incidents','used',v_open_incidents,'total',null,'unit','incidents','status',case when v_critical_incidents>0 then 'critical' when v_open_incidents>0 then 'warning' else 'healthy' end)
    ),
    'healthChecks',v_health_checks,
    'incidents',v_incidents
  );
end;
$function$;

CREATE OR REPLACE FUNCTION control_center_private.send_platform_telemetry()
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'vault', 'control_center_private'
AS $function$
declare
  v_endpoint text;
  v_token text;
  v_cache public.control_center_platform_metrics_cache%rowtype;
  v_payload jsonb;
  v_request_id bigint;
begin
  select decrypted_secret into v_endpoint from vault.decrypted_secrets where name='game_control_center_telemetry_endpoint';
  select decrypted_secret into v_token from vault.decrypted_secrets where name='game_control_center_telemetry_token';
  if v_endpoint is null or v_token is null then raise exception 'Game Control Center telemetry secrets are missing'; end if;

  select * into v_cache from public.control_center_platform_metrics_cache where id=1;
  if v_cache.id is null then raise exception 'Platform metrics cache is empty'; end if;

  v_payload := jsonb_build_object(
    'sourceProjectRef','cwfznmroiqcyhfkfcrow',
    'metrics',jsonb_build_array(
      jsonb_build_object('key','cpu_usage','label','CPU','used',v_cache.cpu_percent,'total',100,'unit','%','status',case when v_cache.cpu_percent is null then 'pending' when v_cache.cpu_percent >= 90 then 'critical' when v_cache.cpu_percent >= 75 then 'warning' else 'healthy' end),
      jsonb_build_object('key','ram_usage','label','RAM','used',v_cache.ram_percent,'total',100,'unit','%','status',case when v_cache.ram_percent is null then 'pending' when v_cache.ram_percent >= 90 then 'critical' when v_cache.ram_percent >= 75 then 'warning' else 'healthy' end),
      jsonb_build_object('key','platform_disk_usage','label','Disk','used',v_cache.disk_used_bytes,'total',v_cache.disk_total_bytes,'unit','bytes','status',case when v_cache.disk_percent is null then 'pending' when v_cache.disk_percent >= 90 then 'critical' when v_cache.disk_percent >= 75 then 'warning' else 'healthy' end)
    ),
    'healthChecks',jsonb_build_array(
      jsonb_build_object('area','System Health','key','platform_metrics','label','Supabase platform metrics','status','healthy','text','Connected','message','CPU, RAM and disk collected from Supabase Metrics API'),
      jsonb_build_object('area','System Health','key','compute_size','label','Compute size','status','healthy','text',coalesce(v_cache.compute_size,'Unknown'),'value',v_cache.max_connections,'unit','max DB connections','message','Compute tier inferred from the current database connection limit'),
      jsonb_build_object('area','System Health','key','database_platform_status','label','Database status','status',case when v_cache.database_status='healthy' then 'healthy' else 'warning' end,'text',case when v_cache.database_status='healthy' then 'Active & healthy' else initcap(coalesce(v_cache.database_status,'unknown')) end,'message','Supabase platform database status'),
      jsonb_build_object('area','System Health','key','project_region','label','Region','status','healthy','text','Central Europe (Zurich)','message','Supabase project region'),
      jsonb_build_object('area','System Health','key','backup_policy','label','Backup','status','healthy','text',initcap(coalesce(v_cache.backup_policy,'daily')),'message','Supabase-managed daily backup policy. Exact latest backup timestamp requires Management API backup access.')
    )
  );

  select net.http_post(url := v_endpoint, headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||v_token), body := v_payload, timeout_milliseconds := 30000)
  into v_request_id;
  return v_request_id;
end;
$function$;

