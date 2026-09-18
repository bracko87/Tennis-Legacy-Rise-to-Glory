create table if not exists public.app_admins (
  email text primary key,
  user_id uuid unique,
  role text not null default 'admin',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint app_admins_email_normalized_chk check (email = lower(email)),
  constraint app_admins_role_chk check (role in ('admin'))
);

alter table public.app_admins enable row level security;
revoke all on table public.app_admins from anon, authenticated;

insert into public.app_admins(email, user_id, role, is_active)
values
  ('aleksandarlevnajic@gmail.com', (select id from auth.users where lower(email)='aleksandarlevnajic@gmail.com' limit 1), 'admin', true),
  ('levnajic.aleksandar@gmail.com', (select id from auth.users where lower(email)='levnajic.aleksandar@gmail.com' limit 1), 'admin', true)
on conflict (email) do update
set user_id=coalesce(excluded.user_id, public.app_admins.user_id),
    role=excluded.role,
    is_active=excluded.is_active;

create or replace function public.is_app_admin_v1(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.app_admins a
    where a.is_active
      and (
        a.user_id=p_user_id
        or (p_user_id=auth.uid() and a.email=lower(coalesce(auth.jwt()->>'email','')))
      )
  );
$$;

revoke all on function public.is_app_admin_v1(uuid) from public;
grant execute on function public.is_app_admin_v1(uuid) to authenticated;

create table if not exists public.site_analytics_daily_visitors (
  analytics_date date not null,
  visitor_id uuid not null,
  user_id uuid,
  country_code text not null default 'XX',
  device_type text not null default 'desktop',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  pageview_count integer not null default 1,
  primary key (analytics_date, visitor_id),
  constraint site_analytics_daily_visitors_country_chk check (country_code='XX' or country_code~'^[A-Z]{2}$'),
  constraint site_analytics_daily_visitors_device_chk check (device_type in ('desktop','tablet','mobile')),
  constraint site_analytics_daily_visitors_pageviews_chk check (pageview_count>=1)
);

create index if not exists site_analytics_daily_visitors_user_date_idx
  on public.site_analytics_daily_visitors(user_id, analytics_date) where user_id is not null;
create index if not exists site_analytics_daily_visitors_country_date_idx
  on public.site_analytics_daily_visitors(country_code, analytics_date);

create table if not exists public.site_analytics_daily_sessions (
  analytics_date date not null,
  session_id uuid not null,
  visitor_id uuid not null,
  user_id uuid,
  country_code text not null default 'XX',
  device_type text not null default 'desktop',
  referrer_host text,
  started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  pageview_count integer not null default 1,
  primary key (analytics_date, session_id),
  constraint site_analytics_daily_sessions_country_chk check (country_code='XX' or country_code~'^[A-Z]{2}$'),
  constraint site_analytics_daily_sessions_device_chk check (device_type in ('desktop','tablet','mobile')),
  constraint site_analytics_daily_sessions_pageviews_chk check (pageview_count>=1)
);

create index if not exists site_analytics_daily_sessions_visitor_date_idx
  on public.site_analytics_daily_sessions(visitor_id, analytics_date);
create index if not exists site_analytics_daily_sessions_referrer_date_idx
  on public.site_analytics_daily_sessions(referrer_host, analytics_date);

create table if not exists public.site_analytics_daily_pages (
  analytics_date date not null,
  visitor_id uuid not null,
  path text not null,
  pageview_count integer not null default 1,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (analytics_date, visitor_id, path),
  constraint site_analytics_daily_pages_path_chk check (char_length(path) between 1 and 240),
  constraint site_analytics_daily_pages_pageviews_chk check (pageview_count>=1)
);

create index if not exists site_analytics_daily_pages_path_date_idx
  on public.site_analytics_daily_pages(path, analytics_date);

alter table public.site_analytics_daily_visitors enable row level security;
alter table public.site_analytics_daily_sessions enable row level security;
alter table public.site_analytics_daily_pages enable row level security;

revoke all on table public.site_analytics_daily_visitors from anon, authenticated;
revoke all on table public.site_analytics_daily_sessions from anon, authenticated;
revoke all on table public.site_analytics_daily_pages from anon, authenticated;

create or replace function public.record_site_analytics_event_v1(
  p_visitor_id uuid,
  p_session_id uuid,
  p_path text,
  p_country_code text default null,
  p_device_type text default 'desktop',
  p_referrer_host text default null
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_now timestamptz:=now();
  v_date date:=(now() at time zone 'Europe/Berlin')::date;
  v_user_id uuid:=auth.uid();
  v_path text;
  v_country_code text;
  v_device_type text;
  v_referrer_host text;
begin
  if p_visitor_id is null or p_session_id is null then return; end if;

  v_path:=left(coalesce(nullif(trim(p_path),''),'/'),240);
  if left(v_path,1)<>'/' then v_path:='/'||v_path; end if;

  v_country_code:=upper(coalesce(nullif(trim(p_country_code),''),'XX'));
  if v_country_code<>'XX' and v_country_code!~'^[A-Z]{2}$' then v_country_code:='XX'; end if;

  v_device_type:=lower(coalesce(nullif(trim(p_device_type),''),'desktop'));
  if v_device_type not in ('desktop','tablet','mobile') then v_device_type:='desktop'; end if;

  v_referrer_host:=nullif(left(lower(trim(coalesce(p_referrer_host,''))),160),'');
  if v_referrer_host in ('tennislegacygame.com','www.tennislegacygame.com') then v_referrer_host:=null; end if;

  insert into public.site_analytics_daily_visitors(
    analytics_date,visitor_id,user_id,country_code,device_type,first_seen_at,last_seen_at,pageview_count
  ) values(v_date,p_visitor_id,v_user_id,v_country_code,v_device_type,v_now,v_now,1)
  on conflict (analytics_date,visitor_id) do update
  set user_id=coalesce(v_user_id,public.site_analytics_daily_visitors.user_id),
      country_code=case when v_country_code<>'XX' then v_country_code else public.site_analytics_daily_visitors.country_code end,
      device_type=v_device_type,
      last_seen_at=v_now,
      pageview_count=public.site_analytics_daily_visitors.pageview_count+1;

  insert into public.site_analytics_daily_sessions(
    analytics_date,session_id,visitor_id,user_id,country_code,device_type,referrer_host,started_at,last_seen_at,pageview_count
  ) values(v_date,p_session_id,p_visitor_id,v_user_id,v_country_code,v_device_type,v_referrer_host,v_now,v_now,1)
  on conflict (analytics_date,session_id) do update
  set user_id=coalesce(v_user_id,public.site_analytics_daily_sessions.user_id),
      country_code=case when v_country_code<>'XX' then v_country_code else public.site_analytics_daily_sessions.country_code end,
      device_type=v_device_type,
      referrer_host=coalesce(public.site_analytics_daily_sessions.referrer_host,v_referrer_host),
      last_seen_at=v_now,
      pageview_count=public.site_analytics_daily_sessions.pageview_count+1;

  insert into public.site_analytics_daily_pages(
    analytics_date,visitor_id,path,pageview_count,first_seen_at,last_seen_at
  ) values(v_date,p_visitor_id,v_path,1,v_now,v_now)
  on conflict (analytics_date,visitor_id,path) do update
  set pageview_count=public.site_analytics_daily_pages.pageview_count+1,last_seen_at=v_now;
end;
$$;

revoke all on function public.record_site_analytics_event_v1(uuid,uuid,text,text,text,text) from public;
grant execute on function public.record_site_analytics_event_v1(uuid,uuid,text,text,text,text) to anon, authenticated;

create or replace function public.get_admin_analytics_dashboard_v1(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_end_date date:=(now() at time zone 'Europe/Berlin')::date;
  v_start_date date;
  v_days integer;
  v_result jsonb;
begin
  if not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  v_days:=case when p_days is null then 30 else greatest(0,least(p_days,3650)) end;
  if v_days=0 then
    select coalesce(min(analytics_date),v_end_date) into v_start_date from public.site_analytics_daily_visitors;
  else
    v_start_date:=v_end_date-(v_days-1);
  end if;

  select jsonb_build_object(
    'generated_at',now(),
    'timezone','Europe/Berlin',
    'period',jsonb_build_object('start_date',v_start_date,'end_date',v_end_date,'days',(v_end_date-v_start_date)+1),
    'summary',jsonb_build_object(
      'unique_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_visitors where analytics_date between v_start_date and v_end_date),
      'pageviews',(select coalesce(sum(pageview_count),0) from public.site_analytics_daily_visitors where analytics_date between v_start_date and v_end_date),
      'sessions',(select count(*) from public.site_analytics_daily_sessions where analytics_date between v_start_date and v_end_date),
      'registered_active_users',(select count(distinct user_id) from public.site_analytics_daily_visitors where analytics_date between v_start_date and v_end_date and user_id is not null),
      'anonymous_visitors',(select count(distinct visitor_id) from public.site_analytics_daily_visitors where analytics_date between v_start_date and v_end_date and user_id is null),
      'new_registrations',(select count(*) from public.profiles where (created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date),
      'total_registered_users',(select count(*) from public.profiles),
      'dau',(select count(distinct user_id) from public.site_analytics_daily_visitors where analytics_date=v_end_date and user_id is not null),
      'wau',(select count(distinct user_id) from public.site_analytics_daily_visitors where analytics_date between v_end_date-6 and v_end_date and user_id is not null),
      'mau',(select count(distinct user_id) from public.site_analytics_daily_visitors where analytics_date between v_end_date-29 and v_end_date and user_id is not null)
    ),
    'daily',coalesce((
      select jsonb_agg(jsonb_build_object(
        'date',d.day,
        'unique_visitors',coalesce(v.unique_visitors,0),
        'pageviews',coalesce(v.pageviews,0),
        'sessions',coalesce(s.sessions,0),
        'registered_active_users',coalesce(v.registered_active_users,0),
        'new_registrations',coalesce(r.new_registrations,0)
      ) order by d.day)
      from generate_series(v_start_date::timestamp,v_end_date::timestamp,interval '1 day') d(day)
      left join (
        select analytics_date,count(*) unique_visitors,coalesce(sum(pageview_count),0) pageviews,
               count(distinct user_id) filter(where user_id is not null) registered_active_users
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by analytics_date
      ) v on v.analytics_date=d.day::date
      left join (
        select analytics_date,count(*) sessions
        from public.site_analytics_daily_sessions
        where analytics_date between v_start_date and v_end_date
        group by analytics_date
      ) s on s.analytics_date=d.day::date
      left join (
        select (created_at at time zone 'Europe/Berlin')::date analytics_date,count(*) new_registrations
        from public.profiles
        where (created_at at time zone 'Europe/Berlin')::date between v_start_date and v_end_date
        group by 1
      ) r on r.analytics_date=d.day::date
    ),'[]'::jsonb),
    'countries',coalesce((
      select jsonb_agg(jsonb_build_object(
        'country_code',x.country_code,
        'country_name',coalesce(c.name,case when x.country_code='XX' then 'Unknown' else x.country_code end),
        'unique_visitors',x.unique_visitors,
        'pageviews',x.pageviews
      ) order by x.unique_visitors desc,x.pageviews desc,x.country_code)
      from (
        select country_code,count(distinct visitor_id) unique_visitors,coalesce(sum(pageview_count),0) pageviews
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by country_code
        order by unique_visitors desc,pageviews desc
        limit 30
      ) x
      left join public.countries c on c.code=x.country_code
    ),'[]'::jsonb),
    'pages',coalesce((
      select jsonb_agg(jsonb_build_object('path',x.path,'pageviews',x.pageviews,'unique_visitors',x.unique_visitors)
                       order by x.pageviews desc,x.unique_visitors desc,x.path)
      from (
        select path,coalesce(sum(pageview_count),0) pageviews,count(distinct visitor_id) unique_visitors
        from public.site_analytics_daily_pages
        where analytics_date between v_start_date and v_end_date
        group by path
        order by pageviews desc,unique_visitors desc
        limit 25
      ) x
    ),'[]'::jsonb),
    'devices',coalesce((
      select jsonb_agg(jsonb_build_object('device_type',x.device_type,'unique_visitors',x.unique_visitors,'pageviews',x.pageviews)
                       order by x.unique_visitors desc,x.device_type)
      from (
        select device_type,count(distinct visitor_id) unique_visitors,coalesce(sum(pageview_count),0) pageviews
        from public.site_analytics_daily_visitors
        where analytics_date between v_start_date and v_end_date
        group by device_type
      ) x
    ),'[]'::jsonb),
    'sources',coalesce((
      select jsonb_agg(jsonb_build_object('source',x.source,'sessions',x.sessions,'unique_visitors',x.unique_visitors)
                       order by x.sessions desc,x.source)
      from (
        select coalesce(nullif(referrer_host,''),'Direct') source,count(*) sessions,count(distinct visitor_id) unique_visitors
        from public.site_analytics_daily_sessions
        where analytics_date between v_start_date and v_end_date
        group by coalesce(nullif(referrer_host,''),'Direct')
        order by sessions desc
        limit 20
      ) x
    ),'[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_admin_analytics_dashboard_v1(integer) from public;
grant execute on function public.get_admin_analytics_dashboard_v1(integer) to authenticated;
