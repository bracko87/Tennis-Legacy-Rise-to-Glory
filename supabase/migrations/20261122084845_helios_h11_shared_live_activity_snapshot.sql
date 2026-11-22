CREATE FUNCTION control_center_private.build_tennis_live_page_activity_v1() RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $live$
WITH latest AS (
    SELECT DISTINCT ON (visitor_id)
      visitor_id, path, is_registered, is_guest, last_seen_at
    FROM control_center_private.tennis_live_page_sessions_v1
    WHERE last_seen_at >= now() - interval '2 minutes'
    ORDER BY visitor_id, last_seen_at DESC, path
  ), grouped AS (
    SELECT path,
           count(*)::integer AS visitors,
           count(*) FILTER (WHERE is_registered)::integer AS registered,
           count(*) FILTER (WHERE NOT is_registered)::integer AS anonymous,
           count(*) FILTER (WHERE is_guest)::integer AS guests,
           count(*) FILTER (WHERE NOT is_registered AND NOT is_guest)::integer AS signed_out
    FROM latest
    GROUP BY path
  )
  SELECT jsonb_build_object(
    'generated_at', now(),
    'window_seconds', 120,
    'active_visitors', (SELECT count(*) FROM latest),
    'registered', (SELECT count(*) FROM latest WHERE is_registered),
    'anonymous', (SELECT count(*) FROM latest WHERE NOT is_registered),
    'guests', (SELECT count(*) FROM latest WHERE is_guest),
    'signed_out', (SELECT count(*) FROM latest WHERE NOT is_registered AND NOT is_guest),
    'pages', coalesce(
       (SELECT jsonb_agg(
          jsonb_build_object('path', path, 'visitors', visitors,
                             'registered', registered, 'anonymous', anonymous, 'guests', guests, 'signed_out', signed_out)
          ORDER BY visitors DESC, path)
        FROM grouped),
       '[]'::jsonb
    ),
    'definition', 'Recently interactive, visible browser sessions on the official site in the last 2 minutes; a visitor is counted once on their latest page. Idle or hidden tabs expire. Permanent, guest and signed-out browser categories derive from current server-side identity at each heartbeat. Legacy anonymous totals include guests. Not a websocket online count.'
  )
$live$;
REVOKE ALL ON FUNCTION control_center_private.build_tennis_live_page_activity_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION control_center_private.build_tennis_active_players_v1() RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $presence$
WITH eligible AS (
 SELECT p.user_id,p.last_activity_at,u.is_anonymous
 FROM control_center_private.tennis_active_player_presence_v1 p
 JOIN auth.users u ON u.id=p.user_id AND u.deleted_at IS NULL
 WHERE EXISTS (SELECT 1 FROM public.players x WHERE x.owner_user_id=u.id AND x.player_type='human' AND x.moderation_status IS DISTINCT FROM 'rejected')
 AND NOT EXISTS (SELECT 1 FROM public.app_admins a WHERE a.is_active AND (a.user_id=u.id OR lower(a.email)=lower(u.email)))
 AND (NOT u.is_anonymous OR EXISTS (SELECT 1 FROM control_center_private.tennis_guest_trials_v1 g WHERE g.user_id=u.id AND g.converted_at IS NULL AND g.retired_at IS NULL AND g.expires_at>now()))
)
SELECT jsonb_build_object('active_players_2m',count(*) FILTER(WHERE NOT is_anonymous AND last_activity_at>=now()-interval '2 minutes'),'active_guest_players_2m',count(*) FILTER(WHERE is_anonymous AND last_activity_at>=now()-interval '2 minutes'),'active_total_players_2m',count(*) FILTER(WHERE last_activity_at>=now()-interval '2 minutes'),'last_player_active_at',max(last_activity_at),'definition','Unique eligible human player accounts with a recent foreground heartbeat in the last 2 minutes. Administrators excluded. Not a websocket connection count.') FROM eligible;
$presence$;
REVOKE ALL ON FUNCTION control_center_private.build_tennis_active_players_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION public.get_admin_live_page_activity_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'control_center_private', 'pg_temp'
AS $function$
DECLARE
  v_report jsonb;
BEGIN
  IF NOT public.is_app_admin_v1(auth.uid()) THEN
    RAISE EXCEPTION 'Administrator access required' USING errcode = '42501';
  END IF;

  RETURN control_center_private.build_tennis_live_page_activity_v1();
END;
$function$;

CREATE OR REPLACE FUNCTION control_center_private.build_admin_analytics_dashboard_snapshot_v3()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with settings as (
 select (now() at time zone 'Europe/Berlin')::date as today
), ranges as (
 select k,start_date,end_date from settings s cross join lateral (values ('today',s.today,s.today),('yesterday',s.today-1,s.today-1),('7d',s.today-6,s.today),('30d',s.today-29,s.today)) r(k,start_date,end_date)
), accounts as materialized (
 select u.id, coalesce(u.is_anonymous,false) as is_guest,
 exists(select 1 from public.app_admins a where a.is_active and (a.user_id=u.id or lower(a.email)=lower(u.email))) as is_admin,
 (coalesce(g.converted_at,u.created_at) at time zone 'Europe/Berlin')::date as registration_date
 from auth.users u left join control_center_private.tennis_guest_trials_v1 g on g.user_id=u.id
 where u.deleted_at is null and lower(coalesce(u.email,'')) not like 'deleted_%@deleted.local'
), period_payloads as (
 select r.k,jsonb_build_object(
 'timezone','Europe/Berlin','period',jsonb_build_object('start_date',r.start_date,'end_date',r.end_date,'days',r.end_date-r.start_date+1),
 'summary',jsonb_build_object(
 'unique_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_visitors where analytics_date between r.start_date and r.end_date),
 'pageviews',(select coalesce(sum(pageview_count),0) from public.site_analytics_daily_visitors where analytics_date between r.start_date and r.end_date),
 'sessions',(select count(distinct session_id) from public.site_analytics_daily_sessions where analytics_date between r.start_date and r.end_date),
 'registered_active_users',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id where v.analytics_date between r.start_date and r.end_date and not a.is_guest and not a.is_admin),
 'active_guest_users',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id where v.analytics_date between r.start_date and r.end_date and a.is_guest and not a.is_admin),
 'active_admin_users',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id where v.analytics_date between r.start_date and r.end_date and a.is_admin),
 'new_registrations',(select count(*) from accounts a where not a.is_admin and not a.is_guest and a.registration_date between r.start_date and r.end_date),
 'total_registered_accounts',(select count(*) from accounts a where not a.is_admin and not a.is_guest),
 'total_human_players',(select count(distinct p.owner_user_id) from public.players p join accounts a on a.id=p.owner_user_id where p.player_type='human' and not a.is_admin and not a.is_guest),
 'anonymous_visitors',(select count(distinct v.visitor_id) from public.site_analytics_daily_visitors v where v.analytics_date between r.start_date and r.end_date and not exists(select 1 from public.site_analytics_daily_visitors x where x.visitor_id=v.visitor_id and x.analytics_date between r.start_date and r.end_date and x.user_id is not null)),
 'dau',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id cross join settings s where v.analytics_date=s.today and not a.is_admin and not a.is_guest),
 'wau',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id cross join settings s where v.analytics_date between s.today-6 and s.today and not a.is_admin and not a.is_guest),
 'mau',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id cross join settings s where v.analytics_date between s.today-29 and s.today and not a.is_admin and not a.is_guest)
 ),
 'daily',(select coalesce(jsonb_agg(jsonb_build_object('date',d.day::date,
 'unique_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_visitors where analytics_date=d.day::date),
 'pageviews',(select coalesce(sum(pageview_count),0) from public.site_analytics_daily_visitors where analytics_date=d.day::date),
 'sessions',(select count(distinct session_id) from public.site_analytics_daily_sessions where analytics_date=d.day::date),
 'active_registered_users',(select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id where v.analytics_date=d.day::date and not a.is_admin and not a.is_guest),
 'new_registrations',(select count(*) from accounts a where not a.is_admin and not a.is_guest and a.registration_date=d.day::date)
 ) order by d.day),'[]'::jsonb) from generate_series(r.start_date::timestamp,r.end_date::timestamp,interval '1 day') d(day)),
 'countries',(select coalesce(jsonb_agg(to_jsonb(x) order by x.unique_visitors desc,x.country_code),'[]'::jsonb) from (select country_code,count(distinct visitor_id) unique_visitors,coalesce(sum(pageview_count),0) pageviews from public.site_analytics_daily_visitors where analytics_date between r.start_date and r.end_date group by country_code order by unique_visitors desc,country_code limit 50) x),
 'top_pages',(select coalesce(jsonb_agg(to_jsonb(x) order by x.pageviews desc,x.path),'[]'::jsonb) from (select path,count(distinct visitor_id) unique_visitors,coalesce(sum(pageview_count),0) pageviews from public.site_analytics_daily_pages where analytics_date between r.start_date and r.end_date group by path order by pageviews desc,path limit 50) x),
 'devices',(select coalesce(jsonb_agg(to_jsonb(x) order by x.visitors desc,x.device_type),'[]'::jsonb) from (select device_type,count(distinct visitor_id) visitors,coalesce(sum(pageview_count),0) pageviews from public.site_analytics_daily_visitors where analytics_date between r.start_date and r.end_date group by device_type) x),
 'traffic_sources',(select coalesce(jsonb_agg(to_jsonb(x) order by x.sessions desc,x.referrer_host),'[]'::jsonb) from (select coalesce(nullif(referrer_host,''),'Direct') referrer_host,count(distinct session_id) sessions,count(distinct visitor_id) unique_visitors from public.site_analytics_daily_sessions where analytics_date between r.start_date and r.end_date group by 1 order by sessions desc,referrer_host limit 50) x),
 'reconciliation',(select jsonb_build_object('visitor_pageviews',v,'session_pageviews',s,'path_pageviews',p,'totals_match',v=s and v=p) from (select (select coalesce(sum(pageview_count),0) from public.site_analytics_daily_visitors where analytics_date between r.start_date and r.end_date) v,(select coalesce(sum(pageview_count),0) from public.site_analytics_daily_sessions where analytics_date between r.start_date and r.end_date) s,(select coalesce(sum(pageview_count),0) from public.site_analytics_daily_pages where analytics_date between r.start_date and r.end_date) p) t)
 ) payload from ranges r
), combined as (select jsonb_object_agg(k,payload) periods from period_payloads)
select jsonb_build_object(
 'schema_version',3,'generated_at',now(),'timezone','Europe/Berlin','periods',periods,'dashboard',periods->'30d',
 'coverage',jsonb_build_object('first_recorded_date',(select min(analytics_date) from public.site_analytics_daily_visitors),'definition','Recorded browser IDs, not people. Missing records do not prove that no one visited. Historical day boundaries are retained.'),
 'freshness',jsonb_build_object('last_pageview_at',(select max(last_seen_at) from public.site_analytics_daily_pages),'recent_visitors_5m',(select count(distinct visitor_id) from public.site_analytics_daily_visitors where last_seen_at>=now()-interval '5 minutes')),
 'presence',control_center_private.build_tennis_active_players_v1(),
 'live_page_activity',control_center_private.build_tennis_live_page_activity_v1(),
 'account_definition','Current non-deleted permanent auth accounts excluding identified admins. Historical registrations use surviving accounts; deleted accounts are not recoverable. Visits include unidentifiable and admin browsers; active player/account counts exclude identified admins. Human player total counts distinct owners.'
) from combined;
$function$;

CREATE OR REPLACE FUNCTION public.get_admin_analytics_dashboard_v1(p_days integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_end_date date := (now() at time zone 'Europe/Berlin')::date;
  v_start_date date;
  v_days integer;
  v_result jsonb;
begin
  if not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if p_days is null then
    v_days := 30;
  else
    v_days := greatest(0, least(p_days, 3650));
  end if;

  if v_days = 0 then
    select coalesce(min(analytics_date), v_end_date)
      into v_start_date
    from public.site_analytics_daily_visitors;
  else
    v_start_date := v_end_date - (v_days - 1);
  end if;

  with accounts as materialized (select u.id, u.is_anonymous as is_guest, exists(select 1 from public.app_admins a where a.is_active and (a.user_id=u.id or lower(a.email)=lower(u.email))) as is_admin, coalesce(g.converted_at,u.created_at) as registered_at from auth.users u left join control_center_private.tennis_guest_trials_v1 g on g.user_id=u.id where u.deleted_at is null and lower(coalesce(u.email,'')) not like 'deleted_%@deleted.local')
  select jsonb_build_object(
    'generated_at', now(),
    'timezone', 'Europe/Berlin',
    'period', jsonb_build_object(
      'start_date', v_start_date,
      'end_date', v_end_date,
      'days', (v_end_date - v_start_date) + 1
    ),
    'summary', jsonb_build_object(
      'unique_visitors', (
        select count(distinct v.visitor_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
      ),
      'pageviews', (
        select coalesce(sum(v.pageview_count), 0)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
      ),
      'sessions', (
        select count(distinct s.session_id)
        from public.site_analytics_daily_sessions s
        where s.analytics_date between v_start_date and v_end_date
      ),
      'registered_active_users', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
          and v.user_id in (select id from accounts where not is_guest and not is_admin)
      ),
      'anonymous_visitors', (
        select count(distinct v.visitor_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
          and not exists (select 1 from public.site_analytics_daily_visitors x where x.visitor_id=v.visitor_id and x.analytics_date between v_start_date and v_end_date and x.user_id is not null)
      ),
      'new_registrations', (
        select count(*)
        from accounts p
        where not p.is_guest and not p.is_admin and (p.registered_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
      ),
      'active_guest_users', (select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id where v.analytics_date between v_start_date and v_end_date and a.is_guest and not a.is_admin),
      'active_admin_users', (select count(distinct v.user_id) from public.site_analytics_daily_visitors v join accounts a on a.id=v.user_id where v.analytics_date between v_start_date and v_end_date and a.is_admin),
      'total_registered_users', (
        select count(*) from accounts where not is_guest and not is_admin
      ),
      'dau', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date = v_end_date
          and v.user_id in (select id from accounts where not is_guest and not is_admin)
      ),
      'wau', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_end_date - 6 and v_end_date
          and v.user_id in (select id from accounts where not is_guest and not is_admin)
      ),
      'mau', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_end_date - 29 and v_end_date
          and v.user_id in (select id from accounts where not is_guest and not is_admin)
      )
    ),
    'daily', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'date', d.day,
          'unique_visitors', coalesce(v.unique_visitors, 0),
          'pageviews', coalesce(v.pageviews, 0),
          'sessions', coalesce(s.sessions, 0),
          'registered_active_users', coalesce(v.registered_active_users, 0),
          'new_registrations', coalesce(r.new_registrations, 0)
        )
        order by d.day
      )
      from generate_series(v_start_date::timestamp, v_end_date::timestamp, interval '1 day') as d(day)
      left join (
        select
          analytics_date,
          count(*) as unique_visitors,
          coalesce(sum(pageview_count), 0) as pageviews,
          count(distinct user_id) filter (where user_id in (select id from accounts where not is_guest and not is_admin)) as registered_active_users
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by analytics_date
      ) v on v.analytics_date = d.day::date
      left join (
        select analytics_date, count(distinct session_id) as sessions
        from public.site_analytics_daily_sessions
        where analytics_date between v_start_date and v_end_date
        group by analytics_date
      ) s on s.analytics_date = d.day::date
      left join (
        select
          (registered_at at time zone 'Europe/Berlin')::date as analytics_date,
          count(*) as new_registrations
        from accounts
        where not is_guest and not is_admin and (registered_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
        group by 1
      ) r on r.analytics_date = d.day::date
    ), '[]'::jsonb),
    'countries', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'country_code', x.country_code,
          'country_name', coalesce(c.name, case when x.country_code = 'XX' then 'Unknown' else x.country_code end),
          'unique_visitors', x.unique_visitors,
          'pageviews', x.pageviews
        )
        order by x.unique_visitors desc, x.pageviews desc, x.country_code
      )
      from (
        select
          country_code,
          count(distinct visitor_id) as unique_visitors,
          coalesce(sum(pageview_count), 0) as pageviews
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by country_code
        order by unique_visitors desc, pageviews desc
        limit 30
      ) x
      left join public.countries c on c.code = x.country_code
    ), '[]'::jsonb),
    'pages', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'path', x.path,
          'pageviews', x.pageviews,
          'unique_visitors', x.unique_visitors
        )
        order by x.pageviews desc, x.unique_visitors desc, x.path
      )
      from (
        select
          path,
          coalesce(sum(pageview_count), 0) as pageviews,
          count(distinct visitor_id) as unique_visitors
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date
        group by path
        order by pageviews desc, unique_visitors desc
        limit 25
      ) x
    ), '[]'::jsonb),
    'devices', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'device_type', x.device_type,
          'unique_visitors', x.unique_visitors,
          'pageviews', x.pageviews
        )
        order by x.unique_visitors desc, x.device_type
      )
      from (
        select
          device_type,
          count(distinct visitor_id) as unique_visitors,
          coalesce(sum(pageview_count), 0) as pageviews
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by device_type
      ) x
    ), '[]'::jsonb),
    'sources', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'source', x.source,
          'sessions', x.sessions,
          'unique_visitors', x.unique_visitors
        )
        order by x.sessions desc, x.source
      )
      from (
        select
          coalesce(nullif(referrer_host, ''), 'Direct') as source,
          count(distinct session_id) as sessions,
          count(distinct visitor_id) as unique_visitors
        from public.site_analytics_daily_sessions
        where analytics_date between v_start_date and v_end_date
        group by coalesce(nullif(referrer_host, ''), 'Direct')
        order by sessions desc
        limit 20
      ) x
    ), '[]'::jsonb)
  )
  into v_result;

  -- Helios H09: no inferred or estimated visitors; all readings come
  -- directly from the first-party event tables. Five-minute activity is
  -- a last-navigation signal, NOT a persistent websocket connection.
  v_result := v_result || jsonb_build_object(
    'freshness', jsonb_build_object(
      'last_pageview_at', (
        select max(last_seen_at) from public.site_analytics_daily_pages
      ),
      'last_session_at', (
        select max(last_seen_at) from public.site_analytics_daily_sessions
      ),
      'recent_sessions_5m', (
        select count(distinct session_id)
        from public.site_analytics_daily_sessions
        where last_seen_at >= now() - interval '5 minutes'
      ),
      'recent_visitors_5m', (
        select count(distinct visitor_id)
        from public.site_analytics_daily_visitors
        where last_seen_at >= now() - interval '5 minutes'
      ),
      'recent_registered_5m', (
        select count(distinct user_id)
        from public.site_analytics_daily_visitors
        where user_id in (select id from (select u.id, u.is_anonymous as is_guest, exists(select 1 from public.app_admins a where a.is_active and (a.user_id=u.id or lower(a.email)=lower(u.email))) as is_admin, coalesce(g.converted_at,u.created_at) as registered_at from auth.users u left join control_center_private.tennis_guest_trials_v1 g on g.user_id=u.id where u.deleted_at is null and lower(coalesce(u.email,'')) not like 'deleted_%@deleted.local') a where not is_guest and not is_admin)
          and last_seen_at >= now() - interval '5 minutes'
      )
    ),
    'reconciliation', jsonb_build_object(
      'visitor_pageviews', (
        select coalesce(sum(pageview_count),0)
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
      ),
      'session_pageviews', (
        select coalesce(sum(pageview_count),0)
        from public.site_analytics_daily_sessions
        where analytics_date between v_start_date and v_end_date
      ),
      'path_pageviews', (
        select coalesce(sum(pageview_count),0)
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date
      ),
      'totals_match', (
        (select coalesce(sum(pageview_count),0)
         from public.site_analytics_daily_visitors
         where analytics_date between v_start_date and v_end_date)
        =
        (select coalesce(sum(pageview_count),0)
         from public.site_analytics_daily_sessions
         where analytics_date between v_start_date and v_end_date)
        and
        (select coalesce(sum(pageview_count),0)
         from public.site_analytics_daily_visitors
         where analytics_date between v_start_date and v_end_date)
        =
        (select coalesce(sum(pageview_count),0)
         from public.site_analytics_daily_pages
         where analytics_date between v_start_date and v_end_date)
      )
    )
  );

  -- H10 independent period counts from surviving identities and trials.
  v_result := v_result || jsonb_build_object('onboarding', (
    with accounts as materialized (select u.id, u.is_anonymous as is_guest, exists(select 1 from public.app_admins a where a.is_active and (a.user_id=u.id or lower(a.email)=lower(u.email))) as is_admin, coalesce(g.converted_at,u.created_at) as registered_at, g.started_at as guest_started_at, g.converted_at, g.expires_at, g.retired_at from auth.users u left join control_center_private.tennis_guest_trials_v1 g on g.user_id=u.id where u.deleted_at is null and lower(coalesce(u.email,'')) not like 'deleted_%@deleted.local')
    select jsonb_build_object(
      'landing_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_pages where analytics_date between v_start_date and v_end_date and path='/'),
      'registration_opened_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_pages where analytics_date between v_start_date and v_end_date and path='/register'),
      'guest_opened_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_pages where analytics_date between v_start_date and v_end_date and path='/try-as-guest'),
      'registration_completed_accounts',(select count(*) from accounts where not is_guest and not is_admin and (registered_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'direct_registration_accounts',(select count(*) from accounts where not is_guest and not is_admin and guest_started_at is null and (registered_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'guest_started_accounts',(select count(*) from accounts where not is_admin and (guest_started_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date) + (select coalesce(sum(erased_trial_starts),0) from control_center_private.tennis_guest_erased_daily_v1 where analytics_date between v_start_date and v_end_date),
      'erased_guest_accounts',(select coalesce(sum(erased_trials),0) from control_center_private.tennis_guest_erased_daily_v1 where analytics_date between v_start_date and v_end_date),
      'guest_converted_accounts',(select count(*) from accounts where not is_guest and not is_admin and (converted_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'active_guest_accounts',(select count(*) from accounts where is_guest and not is_admin and retired_at is null and expires_at>now()),
      'player_created_accounts',(select count(distinct p.owner_user_id) from public.players p join accounts a on a.id=p.owner_user_id where p.player_type='human' and not a.is_guest and not a.is_admin and (p.created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'guest_player_created_accounts',(select count(distinct p.owner_user_id) from public.players p join accounts a on a.id=p.owner_user_id where p.player_type='human' and not a.is_admin and a.guest_started_at is not null and (a.converted_at is null or p.created_at<a.converted_at) and (p.created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'returned_registered_accounts',(select count(distinct s.user_id) from public.site_analytics_daily_sessions s join accounts a on a.id=s.user_id where s.analytics_date between v_start_date and v_end_date and not a.is_guest and not a.is_admin and s.started_at>=a.registered_at+interval '24 hours'),
      'data_note','Independent period totals, not a causal funnel. Permanent registration date is conversion date for converted guests. Guest start and conversion can describe the same identity. Guest starts include aggregate counts of erased expired trials from the retention installation onward. Other account and career totals reflect surviving records. Active guests are current, irrespective of period. Returning means a session at least 24 hours after permanent registration.')
  ));

  v_result := v_result || jsonb_build_object('presence',control_center_private.build_tennis_active_players_v1());

  -- H10: Link browser navigation -> registration -> human player -> return.
  -- A browser identifier is not a person. Exclude browsers shared across
  -- multiple known accounts and use time ordering to avoid false claims.
  -- Aggregates only: visitor UUIDs and account IDs never leave the RPC.
  v_result := v_result || jsonb_build_object(
    'linked_funnel', (
      with
      homepage as (
        select visitor_id,min(first_seen_at) as first_home_at
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date
          and path = '/'
        group by visitor_id
      ),
      register_events as (
        select visitor_id,min(first_seen_at) as opened_at
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date
          and path = '/register'
        group by visitor_id
      ),
      candidates as (
        select v.visitor_id, max(v.user_id::text)::uuid as user_id
        from (select visitor_id,user_id from public.site_analytics_daily_visitors where analytics_date between v_start_date and v_end_date union select visitor_id,user_id from public.site_analytics_daily_sessions where analytics_date between v_start_date and v_end_date) v
        where v.user_id is not null
        group by v.visitor_id
        having count(distinct v.user_id) = 1
      ),
      registered as (
        select r.visitor_id, c.user_id, p.created_at
        from register_events r
        join homepage h on h.visitor_id=r.visitor_id
        join candidates c on c.visitor_id=r.visitor_id
        join auth.users p on p.id=c.user_id
        where h.first_home_at<=r.opened_at and p.created_at >= r.opened_at
          and not p.is_anonymous and p.deleted_at is null
          and not exists(select 1 from control_center_private.tennis_guest_trials_v1 g where g.user_id=p.id)
          and not exists(select 1 from public.app_admins a where a.is_active and (a.user_id=p.id or lower(a.email)=lower(p.email)))
          and (p.created_at at time zone 'Europe/Berlin')::date
            between v_start_date and v_end_date
          and exists (
            select 1 from public.site_analytics_daily_visitors v
            where v.visitor_id=r.visitor_id and v.user_id=c.user_id
              and v.analytics_date between v_start_date and v_end_date
              and v.last_seen_at >= p.created_at
          )
      ),
      characters as (
        select distinct r.visitor_id,r.user_id,r.created_at
        from registered r
        join public.players p on p.owner_user_id=r.user_id
        where p.player_type='human' and p.created_at >= r.created_at
      ),
      returned as (
        select distinct c.visitor_id
        from characters c
        join public.site_analytics_daily_sessions s
          on s.user_id=c.user_id and s.visitor_id=c.visitor_id
        where s.analytics_date between v_start_date and v_end_date
          and s.started_at >= c.created_at + interval '24 hours'
      )
      select jsonb_build_object(
        'homepage_browser_ids', (select count(*) from homepage),
        'registration_browser_ids', (select count(*) from register_events r join homepage h using(visitor_id) where h.first_home_at<=r.opened_at),
        'linked_accounts', (select count(*) from registered),
        'linked_players', (select count(*) from characters),
        'returned_browser_ids', (select count(*) from returned),
        'shared_browser_exclusion', true,
        'definition', 'Direct registration journey only (guest conversions excluded). Observed shared browser IDs excluded; same-day overwritten identity associations, blocked tracking and missing events limit attribution. Not a definitive person-level conversion rate.'
      )
    )
  );

  return v_result;
end;
$function$;
