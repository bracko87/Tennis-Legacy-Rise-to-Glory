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

  -- H10 conversion stages are independently measured within the selected
  -- period. Until we have consent-safe cross-session attribution, these are
  -- NOT a single-person funnel or proof of a causal conversion rate.
  v_result := v_result || jsonb_build_object(
    'onboarding', jsonb_build_object(
      'landing_visitors', (
        select count(distinct visitor_id)
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date and path='/'
      ),
      'registration_opened_visitors', (
        select count(distinct visitor_id)
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date and path='/register'
      ),
      'registration_completed_accounts', (
        select count(*)
        from public.profiles
        where (created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
      ),
      'player_created_accounts', (
        select count(distinct owner_user_id)
        from public.players
        where player_type='human' and owner_user_id is not null
          and (created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
      ),
      'returned_registered_accounts', (
        select count(distinct s.user_id)
        from public.site_analytics_daily_sessions s
        join public.profiles p on p.id=s.user_id
        where s.analytics_date between v_start_date and v_end_date
          and s.user_id is not null
          and s.started_at >= p.created_at + interval '24 hours'
      ),
      'data_note', 'Independent stage totals for the selected period, not an attributed same-user funnel. Returning means a recorded session at least 24 hours after registration.'
    )
  );

  -- Authenticated, activity-gated heartbeats. Independent of page views.
  v_result := v_result || jsonb_build_object(
    'presence', jsonb_build_object(
      'active_players_2m', (
        select count(*) from control_center_private.tennis_active_player_presence_v1
        where last_activity_at >= now() - interval '2 minutes'
      ),
      'last_player_active_at', (
        select max(last_activity_at) from control_center_private.tennis_active_player_presence_v1
      ),
      'definition', 'Authenticated human players with a foreground interaction in the last 2 minutes. Not websocket-connected users; idle and hidden tabs do not count. This presence metric is separate from site navigation and account totals.'
    )
  );

  -- H10: Link browser navigation -> registration -> human player -> return.
  -- A browser identifier is not a person. Exclude browsers shared across
  -- multiple known accounts and use time ordering to avoid false claims.
  -- Aggregates only: visitor UUIDs and account IDs never leave the RPC.
  v_result := v_result || jsonb_build_object(
    'linked_funnel', (
      with
      homepage as (
        select distinct visitor_id
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date
          and path = '/'
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
        from public.site_analytics_daily_visitors v
        where v.analytics_date between v_start_date and v_end_date
          and v.user_id is not null
        group by v.visitor_id
        having count(distinct v.user_id) = 1
      ),
      registered as (
        select r.visitor_id, c.user_id, p.created_at
        from register_events r
        join homepage h on h.visitor_id=r.visitor_id
        join candidates c on c.visitor_id=r.visitor_id
        join public.profiles p on p.id=c.user_id
        where p.created_at >= r.opened_at
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
        'registration_browser_ids', (select count(*) from register_events r join homepage h using(visitor_id)),
        'linked_accounts', (select count(*) from registered),
        'linked_players', (select count(*) from characters),
        'returned_browser_ids', (select count(*) from returned),
        'shared_browser_exclusion', true,
        'definition', 'Pseudonymous browser-linked, ordered journey only. Shared browsers, blocked tracking and missing event history are excluded; this is not a definitive person-level conversion rate.'
      )
    )
  );

  return v_result;
end;
$function$;
