-- Project Helios (Tennis Legacy only): augment existing admin-only website analytics.
-- Count recorded sessions and visitors rather than estimating true online presence.
-- Compare independent pageview aggregations to detect event ingestion discrepancies.
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
        select count(*)
        from public.site_analytics_daily_sessions s
        where s.analytics_date between v_start_date and v_end_date
      ),
      'registered_active_users', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
          and v.user_id is not null
      ),
      'anonymous_visitors', (
        select count(distinct v.visitor_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
          and v.user_id is null
      ),
      'new_registrations', (
        select count(*)
        from public.profiles p
        where (p.created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
      ),
      'total_registered_users', (
        select count(*) from public.profiles
      ),
      'dau', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date = v_end_date
          and v.user_id is not null
      ),
      'wau', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_end_date - 6 and v_end_date
          and v.user_id is not null
      ),
      'mau', (
        select count(distinct v.user_id)
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_end_date - 29 and v_end_date
          and v.user_id is not null
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
          count(distinct user_id) filter (where user_id is not null) as registered_active_users
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by analytics_date
      ) v on v.analytics_date = d.day::date
      left join (
        select analytics_date, count(*) as sessions
        from public.site_analytics_daily_sessions
        where analytics_date between v_start_date and v_end_date
        group by analytics_date
      ) s on s.analytics_date = d.day::date
      left join (
        select
          (created_at at time zone 'Europe/Berlin')::date as analytics_date,
          count(*) as new_registrations
        from public.profiles
        where (created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
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
          count(*) as sessions,
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
        where user_id is not null
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

  return v_result;
end;
$function$
;
