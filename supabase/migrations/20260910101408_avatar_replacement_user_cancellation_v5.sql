alter table public.avatar_replacement_requests
  add column if not exists cancelled_at timestamptz;

alter table public.avatar_replacement_requests
  drop constraint if exists avatar_replacement_requests_status_check;

alter table public.avatar_replacement_requests
  add constraint avatar_replacement_requests_status_check
  check (status in ('submitted','under_review','preparing','ready_for_review','completed','revision_requested','rejected','cancelled'));

drop index if exists public.avatar_replacement_one_active_per_user;
create unique index avatar_replacement_one_active_per_user
  on public.avatar_replacement_requests(user_id)
  where status not in ('completed','rejected','cancelled');

create or replace function public.cancel_avatar_replacement_request_v1(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_req public.avatar_replacement_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.avatar_replacement_requests
  where id = p_request_id
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Avatar request not found';
  end if;

  if v_req.status in ('completed','rejected','cancelled') then
    raise exception 'Closed avatar request cannot be cancelled';
  end if;

  update public.avatar_replacement_requests
  set status = 'cancelled',
      cancelled_at = now(),
      reference_delete_after = now(),
      admin_public_message = null,
      updated_at = now()
  where id = p_request_id;

  if v_req.contact_request_id is not null then
    update public.contact_requests
    set status = 'closed',
        updated_at = now()
    where id = v_req.contact_request_id;
  end if;

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message)
  values(p_request_id,'cancelled','user','Avatar replacement request cancelled by user.');

  perform public.emit_notification_v1(
    v_req.user_id,
    v_req.player_id,
    'avatar.request.cancelled',
    'Avatar request cancelled',
    'Your avatar replacement request was cancelled. Your current avatar remains unchanged and you can submit a new request.',
    '/game/player-account',
    jsonb_build_object('request_id',p_request_id,'status','cancelled'),
    'avatar-request-cancelled:'||p_request_id::text
  );
end;
$$;

revoke all on function public.cancel_avatar_replacement_request_v1(uuid) from public;
grant execute on function public.cancel_avatar_replacement_request_v1(uuid) to authenticated;

create or replace function public.avatar_replacement_close_retention_v1()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status in ('completed','rejected','cancelled')
     and (old.status is distinct from new.status or new.reference_delete_after is null) then
    new.reference_delete_after := now();
  end if;
  return new;
end;
$$;

create or replace function public.get_avatar_reference_cleanup_path_v1(p_request_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_path text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select reference_storage_path into v_path
  from public.avatar_replacement_requests
  where id = p_request_id
    and user_id = auth.uid()
    and status in ('completed','rejected','cancelled')
    and reference_deleted_at is null;

  return v_path;
end;
$$;

create or replace function public.confirm_avatar_reference_deleted_v1(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  update public.avatar_replacement_requests
  set reference_deleted_at = coalesce(reference_deleted_at, now()),
      updated_at = now()
  where id = p_request_id
    and user_id = auth.uid()
    and status in ('completed','rejected','cancelled');

  if not found then raise exception 'Closed avatar request not found'; end if;
end;
$$;

create or replace function public.submit_avatar_replacement_request_v1(
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
  p_page_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, storage, auth, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_player public.players%rowtype;
  v_email text;
  v_player_name text;
  v_contact_id uuid;
  v_expected_prefix text;
  v_object_exists boolean;
  v_colors text[];
  v_support_message text;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_request_id is null then raise exception 'Request id is required'; end if;
  if p_submission_type not in ('reference_photo','candidate_avatar') then raise exception 'Invalid submission type'; end if;
  if p_mime_type not in ('image/jpeg','image/png','image/webp') then raise exception 'Unsupported image type'; end if;
  if p_size_bytes is null or p_size_bytes <= 0 or p_size_bytes > 8388608 then raise exception 'Image must be 8 MB or smaller'; end if;
  if p_jersey_type not in ('sport_jersey','polo_shirt') then raise exception 'Invalid jersey type'; end if;
  if char_length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Reason is required'; end if;
  if char_length(coalesce(p_details,'')) > 4000 or char_length(coalesce(p_appearance_instructions,'')) > 2000 then raise exception 'Request text is too long'; end if;

  v_colors := array(select nullif(trim(x),'') from unnest(coalesce(p_jersey_colors,'{}'::text[])) x where nullif(trim(x),'') is not null limit 3);
  if cardinality(coalesce(v_colors,'{}'::text[])) > 3 then raise exception 'Up to three jersey colors are allowed'; end if;

  select * into v_player from public.players where owner_user_id=v_user_id and player_type='human' order by created_at limit 1;
  if not found then raise exception 'Human player not found for this account'; end if;

  if exists(select 1 from public.avatar_replacement_requests where user_id=v_user_id and status not in ('completed','rejected','cancelled')) then
    raise exception 'You already have an active avatar replacement request';
  end if;

  v_expected_prefix := v_user_id::text || '/' || p_request_id::text || '/';
  if p_storage_path is null or left(p_storage_path,char_length(v_expected_prefix)) <> v_expected_prefix then
    raise exception 'Invalid private storage path';
  end if;
  if lower(storage.extension(p_storage_path)) not in ('jpg','jpeg','png','webp') then raise exception 'Unsupported image extension'; end if;

  select exists(
    select 1 from storage.objects
    where bucket_id='avatar-replacement-submissions'
      and name=p_storage_path
      and (storage.foldername(name))[1]=v_user_id::text
  ) into v_object_exists;
  if not v_object_exists then raise exception 'Uploaded private image was not found'; end if;

  select email into v_email from auth.users where id=v_user_id;
  v_player_name := trim(v_player.first_name || ' ' || v_player.last_name);
  v_support_message := concat_ws(E'\n',
    'Private Tennis Legacy avatar replacement request',
    '',
    'Request ID: ' || p_request_id::text,
    'User ID: ' || v_user_id::text,
    'Player: ' || v_player_name,
    'Player ID: ' || v_player.id::text,
    'Account email: ' || coalesce(v_email,''),
    'Submission type: ' || p_submission_type,
    'Reason: ' || trim(p_reason),
    'Jersey type: ' || p_jersey_type,
    'Preferred colors: ' || coalesce(array_to_string(v_colors, ', '),'None specified'),
    'Private photo reference: avatar-replacement-submissions/' || p_storage_path,
    '',
    'Request details:', coalesce(nullif(trim(p_details),''),'None'),
    '',
    'Appearance instructions:', coalesce(nullif(trim(p_appearance_instructions),''),'None'),
    '',
    'Important: the private photo reference is not a public URL. Access it only through authorized Supabase Storage/admin tooling.'
  );

  insert into public.contact_requests(user_id,player_id,account_email,player_name,world,country_code,category,subject,message,page_url)
  values(v_user_id,v_player.id,coalesce(v_email,''),v_player_name,v_player.world,v_player.country_code,'Other','Avatar replacement request — '||v_player_name,v_support_message,p_page_url)
  returning id into v_contact_id;

  insert into public.avatar_replacement_requests(
    id,user_id,player_id,contact_request_id,submission_type,reference_storage_path,original_file_name,
    reference_mime_type,reference_size_bytes,reason,details,jersey_type,jersey_colors,
    appearance_instructions,previous_avatar_path
  ) values(
    p_request_id,v_user_id,v_player.id,v_contact_id,p_submission_type,p_storage_path,left(coalesce(p_original_file_name,''),255),
    p_mime_type,p_size_bytes,trim(p_reason),coalesce(p_details,''),p_jersey_type,coalesce(v_colors,'{}'::text[]),
    coalesce(p_appearance_instructions,''),v_player.image_path
  );

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message)
  values(p_request_id,'submitted','user','Private avatar request submitted.');

  perform public.emit_notification_v1(
    v_user_id,v_player.id,'avatar.request.submitted','Avatar request submitted',
    'Your private avatar replacement request was received. Your current avatar remains unchanged while the request is reviewed.',
    '/game/player-account',jsonb_build_object('request_id',p_request_id,'status','submitted'),
    'avatar-request-submitted:'||p_request_id::text
  );

  return p_request_id;
end;
$$;

create or replace function public.admin_update_avatar_replacement_status_v1(p_request_id uuid, p_status text, p_public_message text default null, p_internal_note text default null)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_req public.avatar_replacement_requests%rowtype;
begin
  if current_user not in ('service_role','postgres') then raise exception 'Admin service role required'; end if;
  if p_status not in ('under_review','preparing','rejected') then raise exception 'Unsupported admin status'; end if;
  select * into v_req from public.avatar_replacement_requests where id=p_request_id for update;
  if not found then raise exception 'Avatar request not found'; end if;
  if v_req.status in ('completed','rejected','cancelled') then raise exception 'Closed avatar request cannot be changed'; end if;

  update public.avatar_replacement_requests set
    status=p_status,
    admin_public_message=coalesce(p_public_message,admin_public_message),
    admin_internal_note=coalesce(p_internal_note,admin_internal_note),
    rejected_at=case when p_status='rejected' then now() else rejected_at end,
    reference_delete_after=case when p_status='rejected' then now()+interval '30 days' else reference_delete_after end,
    updated_at=now()
  where id=p_request_id;

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message,internal_note)
  values(p_request_id,p_status,'admin',p_public_message,p_internal_note);

  if p_status='rejected' then
    perform public.emit_notification_v1(
      v_req.user_id,v_req.player_id,'avatar.request.rejected','Avatar request unable to process',
      coalesce(nullif(trim(p_public_message),''),'Your avatar replacement request could not be processed. Open Player & account for details.'),
      '/game/player-account',jsonb_build_object('request_id',p_request_id,'status','rejected'),
      'avatar-request-rejected:'||p_request_id::text
    );
  end if;
end;
$$;