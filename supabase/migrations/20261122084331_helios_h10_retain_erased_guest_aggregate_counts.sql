-- Retain date-level counts of erased expired guests, never account identifiers.
create table control_center_private.tennis_guest_erased_daily_v1 (
 analytics_date date primary key,
 erased_trial_starts bigint not null default 0 check (erased_trial_starts>=0),
 erased_trials bigint not null default 0 check (erased_trials>=0)
);
alter table control_center_private.tennis_guest_erased_daily_v1 enable row level security;
revoke all on control_center_private.tennis_guest_erased_daily_v1 from public, anon, authenticated, service_role;
create function control_center_private.retain_erased_guest_counts_v1() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 if old.converted_at is null and old.retired_at is not null and old.expires_at <= now()
    and not exists(select 1 from public.app_admins a where a.is_active and a.user_id=old.user_id)
 then
  insert into control_center_private.tennis_guest_erased_daily_v1(analytics_date,erased_trial_starts)
  values((old.started_at at time zone 'Europe/Berlin')::date,1)
  on conflict(analytics_date) do update set erased_trial_starts=tennis_guest_erased_daily_v1.erased_trial_starts+1;
  insert into control_center_private.tennis_guest_erased_daily_v1(analytics_date,erased_trials)
  values((now() at time zone 'Europe/Berlin')::date,1)
  on conflict(analytics_date) do update set erased_trials=tennis_guest_erased_daily_v1.erased_trials+1;
 end if;
 return old;
end;
$$;
revoke all on function control_center_private.retain_erased_guest_counts_v1() from public,anon,authenticated,service_role;
create trigger retain_erased_guest_counts_v1 before delete on control_center_private.tennis_guest_trials_v1 for each row execute function control_center_private.retain_erased_guest_counts_v1();
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
      'guest_started_accounts',(select count(*) from accounts where not is_admin and (guest_started_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date + (select coalesce(sum(erased_trial_starts),0) from control_center_private.tennis_guest_erased_daily_v1 where analytics_date between v_start_date and v_end_date)),
      'erased_guest_accounts',(select coalesce(sum(erased_trials),0) from control_center_private.tennis_guest_erased_daily_v1 where analytics_date between v_start_date and v_end_date),
      'guest_converted_accounts',(select count(*) from accounts where not is_guest and not is_admin and (converted_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'active_guest_accounts',(select count(*) from accounts where is_guest and not is_admin and retired_at is null and expires_at>now()),
      'player_created_accounts',(select count(distinct p.owner_user_id) from public.players p join accounts a on a.id=p.owner_user_id where p.player_type='human' and not a.is_guest and not a.is_admin and (p.created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'guest_player_created_accounts',(select count(distinct p.owner_user_id) from public.players p join accounts a on a.id=p.owner_user_id where p.player_type='human' and not a.is_admin and a.guest_started_at is not null and (a.converted_at is null or p.created_at<a.converted_at) and (p.created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'returned_registered_accounts',(select count(distinct s.user_id) from public.site_analytics_daily_sessions s join accounts a on a.id=s.user_id where s.analytics_date between v_start_date and v_end_date and not a.is_guest and not a.is_admin and s.started_at>=a.registered_at+interval '24 hours'),
      'data_note','Independent period totals, not a causal funnel. Permanent registration date is conversion date for converted guests. Guest start and conversion can describe the same identity. Guest starts include aggregate counts of erased expired trials from the retention installation onward. Other account and career totals reflect surviving records. Active guests are current, irrespective of period. Returning means a session at least 24 hours after permanent registration.')
  ));

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
