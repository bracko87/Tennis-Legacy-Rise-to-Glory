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
 'game_activity',control_center_private.build_tennis_game_activity_v2(r.start_date,r.end_date),
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
