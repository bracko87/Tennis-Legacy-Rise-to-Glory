alter table public.avatar_replacement_requests
  add column if not exists identity_attestation boolean not null default false,
  add column if not exists privacy_consent boolean not null default false,
  add column if not exists policy_version text null,
  add column if not exists policy_accepted_at timestamptz null;

create or replace function public.avatar_replacement_close_retention_v1()
returns trigger
language plpgsql
set search_path to 'public','pg_temp'
as $function$
begin
  if new.status in ('completed','rejected')
     and (old.status is distinct from new.status or new.reference_delete_after is null) then
    new.reference_delete_after := now();
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_avatar_replacement_close_retention_v1 on public.avatar_replacement_requests;
create trigger trg_avatar_replacement_close_retention_v1
before update of status, reference_delete_after on public.avatar_replacement_requests
for each row execute function public.avatar_replacement_close_retention_v1();

create or replace function public.submit_avatar_replacement_request_v2(
  p_request_id uuid,
  p_submission_type text,
  p_storage_path text,
  p_original_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_reason text,
  p_details text,
  p_jersey_type text,
  p_jersey_colors text[],
  p_appearance_instructions text,
  p_identity_attestation boolean,
  p_privacy_consent boolean,
  p_page_url text default null
) returns uuid
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_request_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(p_identity_attestation,false) is not true then
    raise exception 'You must confirm that the submitted image is you or is based only on your own appearance';
  end if;
  if coalesce(p_privacy_consent,false) is not true then
    raise exception 'You must accept the limited avatar-image processing notice';
  end if;

  v_request_id := public.submit_avatar_replacement_request_v1(
    p_request_id,
    p_submission_type,
    p_storage_path,
    p_original_file_name,
    p_mime_type,
    p_size_bytes,
    p_reason,
    p_details,
    p_jersey_type,
    p_jersey_colors,
    p_appearance_instructions,
    p_page_url
  );

  update public.avatar_replacement_requests
  set identity_attestation = true,
      privacy_consent = true,
      policy_version = 'avatar-rules-2026-09-10-v1',
      policy_accepted_at = now(),
      updated_at = now()
  where id = v_request_id and user_id = auth.uid();

  return v_request_id;
end;
$function$;

revoke all on function public.submit_avatar_replacement_request_v1(uuid,text,text,text,text,bigint,text,text,text,text[],text,text) from authenticated;
revoke all on function public.submit_avatar_replacement_request_v2(uuid,text,text,text,text,bigint,text,text,text,text[],text,boolean,boolean,text) from public, anon;
grant execute on function public.submit_avatar_replacement_request_v2(uuid,text,text,text,text,bigint,text,text,text,text[],text,boolean,boolean,text) to authenticated;

create or replace function public.get_avatar_reference_cleanup_path_v1(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_path text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select reference_storage_path into v_path
  from public.avatar_replacement_requests
  where id = p_request_id
    and user_id = auth.uid()
    and status in ('completed','rejected')
    and reference_deleted_at is null;

  return v_path;
end;
$function$;
revoke all on function public.get_avatar_reference_cleanup_path_v1(uuid) from public, anon;
grant execute on function public.get_avatar_reference_cleanup_path_v1(uuid) to authenticated;

create or replace function public.confirm_avatar_reference_deleted_v1(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  update public.avatar_replacement_requests
  set reference_deleted_at = coalesce(reference_deleted_at, now()),
      updated_at = now()
  where id = p_request_id
    and user_id = auth.uid()
    and status in ('completed','rejected');

  if not found then raise exception 'Closed avatar request not found'; end if;
end;
$function$;
revoke all on function public.confirm_avatar_reference_deleted_v1(uuid) from public, anon;
grant execute on function public.confirm_avatar_reference_deleted_v1(uuid) to authenticated;

grant select (identity_attestation, privacy_consent, policy_version, policy_accepted_at)
on public.avatar_replacement_requests to authenticated;
