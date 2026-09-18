alter table public.bug_reports
  drop constraint if exists bug_reports_status_check;

update public.bug_reports
set status='in_progress',
    updated_at=now()
where status='reviewing';
