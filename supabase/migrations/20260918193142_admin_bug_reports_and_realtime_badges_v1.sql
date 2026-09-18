alter table public.bug_reports
  add column if not exists priority text not null default 'medium',
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists resolved_at timestamptz;

alter table public.bug_reports
  drop constraint if exists bug_reports_status_admin_chk,
  drop constraint if exists bug_reports_priority_admin_chk;

alter table public.bug_reports
  add constraint bug_reports_status_admin_chk
    check (status in ('new','open','in_progress','resolved','closed')),
  add constraint bug_reports_priority_admin_chk
    check (priority in ('low','medium','high','critical'));

create table if not exists public.bug_report_admin_reads (
  bug_report_id uuid not null references public.bug_reports(id) on delete cascade,
  admin_user_id uuid not null,
  read_at timestamptz not null default now(),
  primary key (bug_report_id, admin_user_id)
);

create table if not exists public.bug_report_notes (
  id uuid primary key default gen_random_uuid(),
  bug_report_id uuid not null references public.bug_reports(id) on delete cascade,
  admin_user_id uuid not null,
  note text not null,
  created_at timestamptz not null default now(),
  constraint bug_report_notes_note_chk check (char_length(btrim(note)) between 1 and 4000)
);

create index if not exists bug_report_admin_reads_admin_idx
  on public.bug_report_admin_reads(admin_user_id, read_at desc);

create index if not exists bug_report_notes_report_idx
  on public.bug_report_notes(bug_report_id, created_at desc);

create index if not exists bug_reports_status_created_idx
  on public.bug_reports(status, created_at desc);

alter table public.bug_report_admin_reads enable row level security;
alter table public.bug_report_notes enable row level security;

revoke all on table public.bug_report_admin_reads from anon, authenticated;
revoke all on table public.bug_report_notes from anon, authenticated;

drop policy if exists "app admins can read bug reports" on public.bug_reports;
create policy "app admins can read bug reports"
on public.bug_reports
for select
to authenticated
using (public.is_app_admin_v1(auth.uid()));

grant select on public.bug_reports to authenticated;

drop policy if exists "app admins can read homepage reviews" on public.player_homepage_reviews;
create policy "app admins can read homepage reviews"
on public.player_homepage_reviews
for select
to authenticated
using (public.is_app_admin_v1(auth.uid()));

grant select on public.player_homepage_reviews to authenticated;

update storage.buckets
set public=false,
    file_size_limit=5242880,
    allowed_mime_types=array['image/png','image/jpeg','image/webp','image/gif']::text[]
where id='bug-report-screenshots';

drop policy if exists "app admins can read bug screenshots" on storage.objects;
create policy "app admins can read bug screenshots"
on storage.objects
for select
to authenticated
using (
  bucket_id='bug-report-screenshots'
  and public.is_app_admin_v1(auth.uid())
);

create or replace function public.get_admin_bug_report_unread_count_v1()
returns integer
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_count integer;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  select count(*)::integer
  into v_count
  from public.bug_reports b
  where not exists (
    select 1
    from public.bug_report_admin_reads r
    where r.bug_report_id=b.id
      and r.admin_user_id=auth.uid()
  );

  return coalesce(v_count,0);
end;
$$;

revoke all on function public.get_admin_bug_report_unread_count_v1() from public, anon, authenticated;
grant execute on function public.get_admin_bug_report_unread_count_v1() to authenticated;

create or replace function public.get_admin_homepage_review_pending_count_v1()
returns integer
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_count integer;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  select count(*)::integer
  into v_count
  from public.player_homepage_reviews
  where status='pending';

  return coalesce(v_count,0);
end;
$$;

revoke all on function public.get_admin_homepage_review_pending_count_v1() from public, anon, authenticated;
grant execute on function public.get_admin_homepage_review_pending_count_v1() to authenticated;

create or replace function public.get_admin_bug_reports_v1(p_status text default 'all')
returns jsonb
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_status text := lower(coalesce(p_status,'all'));
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if v_status not in ('all','new','open','in_progress','resolved','closed') then
    raise exception 'Invalid bug report status filter.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',b.id,
        'created_at',b.created_at,
        'updated_at',b.updated_at,
        'user_id',b.user_id,
        'player_id',b.player_id,
        'reporter_email',u.email,
        'player_name',case
          when p.id is null then null
          else concat_ws(' ',p.first_name,p.last_name)
        end,
        'world',p.world,
        'country_code',p.country_code,
        'page_label',b.page_label,
        'page_path',b.page_path,
        'page_url',b.page_url,
        'bug_type',b.bug_type,
        'severity',b.severity,
        'priority',b.priority,
        'description',b.description,
        'expected_result',b.expected_result,
        'actual_result',b.actual_result,
        'steps_to_reproduce',b.steps_to_reproduce,
        'browser',b.browser,
        'viewport',b.viewport,
        'screenshot_path',b.screenshot_path,
        'reported_from',b.reported_from,
        'status',b.status,
        'resolved_at',b.resolved_at,
        'is_unread',not exists (
          select 1
          from public.bug_report_admin_reads rr
          where rr.bug_report_id=b.id
            and rr.admin_user_id=auth.uid()
        )
      )
      order by
        case when exists (
          select 1 from public.bug_report_admin_reads rr
          where rr.bug_report_id=b.id
            and rr.admin_user_id=auth.uid()
        ) then 1 else 0 end,
        b.created_at desc
    ),
    '[]'::jsonb
  )
  into v_result
  from public.bug_reports b
  left join public.players p on p.id=b.player_id
  left join auth.users u on u.id=b.user_id
  where v_status='all' or b.status=v_status;

  return v_result;
end;
$$;

revoke all on function public.get_admin_bug_reports_v1(text) from public, anon, authenticated;
grant execute on function public.get_admin_bug_reports_v1(text) to authenticated;

create or replace function public.mark_admin_bug_report_read_v1(p_bug_report_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if not exists(select 1 from public.bug_reports where id=p_bug_report_id) then
    raise exception 'Bug report not found.';
  end if;

  insert into public.bug_report_admin_reads(bug_report_id,admin_user_id,read_at)
  values(p_bug_report_id,auth.uid(),now())
  on conflict(bug_report_id,admin_user_id)
  do update set read_at=excluded.read_at;
end;
$$;

revoke all on function public.mark_admin_bug_report_read_v1(uuid) from public, anon, authenticated;
grant execute on function public.mark_admin_bug_report_read_v1(uuid) to authenticated;

create or replace function public.get_admin_bug_report_notes_v1(p_bug_report_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',n.id,
        'admin_user_id',n.admin_user_id,
        'admin_email',u.email,
        'note',n.note,
        'created_at',n.created_at
      )
      order by n.created_at asc
    ),
    '[]'::jsonb
  )
  into v_result
  from public.bug_report_notes n
  left join auth.users u on u.id=n.admin_user_id
  where n.bug_report_id=p_bug_report_id;

  return v_result;
end;
$$;

revoke all on function public.get_admin_bug_report_notes_v1(uuid) from public, anon, authenticated;
grant execute on function public.get_admin_bug_report_notes_v1(uuid) to authenticated;

create or replace function public.admin_add_bug_report_note_v1(
  p_bug_report_id uuid,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_note text := btrim(coalesce(p_note,''));
  v_id uuid;
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if char_length(v_note)<1 or char_length(v_note)>4000 then
    raise exception 'Note must contain between 1 and 4000 characters.';
  end if;

  if not exists(select 1 from public.bug_reports where id=p_bug_report_id) then
    raise exception 'Bug report not found.';
  end if;

  insert into public.bug_report_notes(bug_report_id,admin_user_id,note)
  values(p_bug_report_id,auth.uid(),v_note)
  returning id into v_id;

  return jsonb_build_object('id',v_id,'created_at',now());
end;
$$;

revoke all on function public.admin_add_bug_report_note_v1(uuid,text) from public, anon, authenticated;
grant execute on function public.admin_add_bug_report_note_v1(uuid,text) to authenticated;

create or replace function public.admin_update_bug_report_v1(
  p_bug_report_id uuid,
  p_status text,
  p_priority text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_status text := lower(btrim(coalesce(p_status,'')));
  v_priority text := lower(btrim(coalesce(p_priority,'')));
begin
  if auth.uid() is null or not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Administrator access required' using errcode='42501';
  end if;

  if v_status not in ('new','open','in_progress','resolved','closed') then
    raise exception 'Invalid bug report status.';
  end if;

  if v_priority not in ('low','medium','high','critical') then
    raise exception 'Invalid bug report priority.';
  end if;

  update public.bug_reports
  set status=v_status,
      priority=v_priority,
      updated_at=now(),
      resolved_at=case
        when v_status in ('resolved','closed') then coalesce(resolved_at,now())
        else null
      end
  where id=p_bug_report_id;

  if not found then
    raise exception 'Bug report not found.';
  end if;

  return jsonb_build_object(
    'id',p_bug_report_id,
    'status',v_status,
    'priority',v_priority
  );
end;
$$;

revoke all on function public.admin_update_bug_report_v1(uuid,text,text) from public, anon, authenticated;
grant execute on function public.admin_update_bug_report_v1(uuid,text,text) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='bug_reports'
  ) then
    alter publication supabase_realtime add table public.bug_reports;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='player_homepage_reviews'
  ) then
    alter publication supabase_realtime add table public.player_homepage_reviews;
  end if;
end
$$;
