create table if not exists public.avatar_replacement_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  contact_request_id uuid null references public.contact_requests(id) on delete set null,
  submission_type text not null check (submission_type in ('reference_photo','candidate_avatar')),
  reference_storage_path text not null unique,
  original_file_name text not null,
  reference_mime_type text not null check (reference_mime_type in ('image/jpeg','image/png','image/webp')),
  reference_size_bytes bigint not null check (reference_size_bytes > 0 and reference_size_bytes <= 8388608),
  reason text not null check (char_length(reason) between 3 and 200),
  details text not null default '' check (char_length(details) <= 4000),
  jersey_type text not null check (jersey_type in ('sport_jersey','polo_shirt')),
  jersey_colors text[] not null default '{}'::text[] check (cardinality(jersey_colors) <= 3),
  appearance_instructions text not null default '' check (char_length(appearance_instructions) <= 2000),
  status text not null default 'submitted' check (status in ('submitted','under_review','preparing','ready_for_review','completed','revision_requested','rejected')),
  previous_avatar_path text null,
  review_image_path text null,
  admin_public_message text null,
  admin_internal_note text null,
  user_revision_message text null,
  revision_count smallint not null default 0 check (revision_count between 0 and 2),
  ready_for_review_at timestamptz null,
  user_decision_at timestamptz null,
  completed_at timestamptz null,
  rejected_at timestamptz null,
  reference_delete_after timestamptz null,
  reference_deleted_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists avatar_replacement_one_active_per_user
  on public.avatar_replacement_requests(user_id)
  where status not in ('completed','rejected');

create index if not exists avatar_replacement_requests_player_idx
  on public.avatar_replacement_requests(player_id, created_at desc);
create index if not exists avatar_replacement_requests_status_idx
  on public.avatar_replacement_requests(status, created_at);
create index if not exists avatar_replacement_requests_retention_idx
  on public.avatar_replacement_requests(reference_delete_after)
  where reference_deleted_at is null;

create table if not exists public.avatar_replacement_request_history (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.avatar_replacement_requests(id) on delete cascade,
  status text not null,
  actor_type text not null check (actor_type in ('user','admin','system')),
  public_message text null,
  internal_note text null,
  created_at timestamptz not null default now()
);

create index if not exists avatar_replacement_history_request_idx
  on public.avatar_replacement_request_history(request_id, created_at);

alter table public.avatar_replacement_requests enable row level security;
alter table public.avatar_replacement_request_history enable row level security;

revoke all on public.avatar_replacement_requests from anon, authenticated;
grant select on public.avatar_replacement_requests to authenticated;

create policy avatar_replacement_requests_select_own
on public.avatar_replacement_requests for select
to authenticated
using ((select auth.uid()) = user_id);

revoke all on public.avatar_replacement_request_history from anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatar-replacement-submissions',
  'avatar-replacement-submissions',
  false,
  8388608,
  array['image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy avatar_replacement_submission_insert_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'avatar-replacement-submissions'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and lower(storage.extension(name)) in ('jpg','jpeg','png','webp')
);

create policy avatar_replacement_submission_delete_orphan_or_closed_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'avatar-replacement-submissions'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and not exists (
    select 1
    from public.avatar_replacement_requests r
    where r.user_id = (select auth.uid())
      and r.reference_storage_path = name
      and r.status not in ('completed','rejected')
  )
);

insert into public.notification_catalog (
  code, category, label, reason, trigger_event, trigger_condition, trigger_mechanism,
  source_name, title_template, message_template, default_route, severity,
  default_in_app, default_email, default_push, is_user_configurable, is_active
) values
(
  'avatar.request.submitted','account','Avatar request submitted',
  'Confirms that a private avatar replacement request was received.',
  'Avatar request submitted','A signed-in player submits a valid private avatar request.',
  'database','Avatar replacement','Avatar request submitted',
  'Your private avatar replacement request was received.',
  '/game/player-account','info',true,false,false,false,true
),
(
  'avatar.request.ready','account','Avatar replacement ready',
  'Tells the player that a prepared replacement is ready for review.',
  'Admin marks replacement ready','A replacement preview has been prepared by an administrator.',
  'database','Avatar replacement','Avatar replacement ready for review',
  'Your replacement avatar is ready. Review it before applying it.',
  '/game/player-account','success',true,false,false,false,true
),
(
  'avatar.request.revision','account','Avatar revision requested',
  'Confirms a player revision request.',
  'Player requests revision','The player asks for a limited revision to a prepared replacement.',
  'database','Avatar replacement','Avatar revision requested',
  'Your revision request was recorded and sent back for review.',
  '/game/player-account','warning',true,false,false,false,true
),
(
  'avatar.request.completed','account','Avatar replacement completed',
  'Confirms that the player approved and applied a replacement.',
  'Player approves replacement','The player approves the prepared replacement image.',
  'database','Avatar replacement','Avatar replacement completed',
  'Your approved replacement avatar is now active.',
  '/game/player-account','success',true,false,false,false,true
),
(
  'avatar.request.rejected','account','Avatar request unable to process',
  'Tells the player when an administrator cannot process the request.',
  'Admin rejects request','An administrator marks the request as unable to process.',
  'database','Avatar replacement','Avatar request unable to process',
  'Your avatar replacement request could not be processed. Open Player & account for details.',
  '/game/player-account','warning',true,false,false,false,true
)
on conflict (code) do update set
  category = excluded.category,
  label = excluded.label,
  reason = excluded.reason,
  trigger_event = excluded.trigger_event,
  trigger_condition = excluded.trigger_condition,
  trigger_mechanism = excluded.trigger_mechanism,
  source_name = excluded.source_name,
  title_template = excluded.title_template,
  message_template = excluded.message_template,
  default_route = excluded.default_route,
  severity = excluded.severity,
  default_in_app = excluded.default_in_app,
  is_user_configurable = excluded.is_user_configurable,
  is_active = excluded.is_active,
  updated_at = now();

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
) returns uuid
language plpgsql
security definer
set search_path to 'public','storage','auth','pg_temp'
as $function$
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

  v_colors := array(
    select nullif(trim(x),'')
    from unnest(coalesce(p_jersey_colors,'{}'::text[])) x
    where nullif(trim(x),'') is not null
    limit 3
  );

  if cardinality(coalesce(v_colors,'{}'::text[])) > 3 then raise exception 'Up to three jersey colors are allowed'; end if;

  select * into v_player
  from public.players
  where owner_user_id = v_user_id and player_type = 'human'
  order by created_at
  limit 1;

  if not found then raise exception 'Human player not found for this account'; end if;

  if exists(
    select 1 from public.avatar_replacement_requests
    where user_id = v_user_id and status not in ('completed','rejected')
  ) then
    raise exception 'You already have an active avatar replacement request';
  end if;

  v_expected_prefix := v_user_id::text || '/' || p_request_id::text || '/';
  if p_storage_path is null or left(p_storage_path,char_length(v_expected_prefix)) <> v_expected_prefix then
    raise exception 'Invalid private storage path';
  end if;
  if lower(storage.extension(p_storage_path)) not in ('jpg','jpeg','png','webp') then raise exception 'Unsupported image extension'; end if;

  select exists(
    select 1 from storage.objects
    where bucket_id = 'avatar-replacement-submissions'
      and name = p_storage_path
      and (storage.foldername(name))[1] = v_user_id::text
  ) into v_object_exists;
  if not v_object_exists then raise exception 'Uploaded private image was not found'; end if;

  select email into v_email from auth.users where id = v_user_id;
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

  insert into public.contact_requests(
    user_id, player_id, account_email, player_name, world, country_code,
    category, subject, message, page_url
  ) values (
    v_user_id, v_player.id, coalesce(v_email,''), v_player_name, v_player.world, v_player.country_code,
    'Other', 'Avatar replacement request — ' || v_player_name, v_support_message, p_page_url
  ) returning id into v_contact_id;

  insert into public.avatar_replacement_requests(
    id, user_id, player_id, contact_request_id, submission_type, reference_storage_path,
    original_file_name, reference_mime_type, reference_size_bytes, reason, details,
    jersey_type, jersey_colors, appearance_instructions, previous_avatar_path
  ) values (
    p_request_id, v_user_id, v_player.id, v_contact_id, p_submission_type, p_storage_path,
    left(coalesce(p_original_file_name,''),255), p_mime_type, p_size_bytes, trim(p_reason),
    coalesce(p_details,''), p_jersey_type, coalesce(v_colors,'{}'::text[]),
    coalesce(p_appearance_instructions,''), v_player.image_path
  );

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message)
  values(p_request_id,'submitted','user','Private avatar request submitted.');

  perform public.emit_notification_v1(
    v_user_id, v_player.id, 'avatar.request.submitted', 'Avatar request submitted',
    'Your private avatar replacement request was received. Your current avatar remains unchanged while the request is reviewed.',
    '/game/player-account', jsonb_build_object('request_id',p_request_id,'status','submitted'),
    'avatar-request-submitted:' || p_request_id::text
  );

  return p_request_id;
end;
$function$;

revoke all on function public.submit_avatar_replacement_request_v1(uuid,text,text,text,text,bigint,text,text,text,text[],text,text) from public, anon;
grant execute on function public.submit_avatar_replacement_request_v1(uuid,text,text,text,text,bigint,text,text,text,text[],text,text) to authenticated;

create or replace function public.request_avatar_replacement_revision_v1(p_request_id uuid,p_message text)
returns void
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_req public.avatar_replacement_requests%rowtype;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;

  select * into v_req
  from public.avatar_replacement_requests
  where id = p_request_id and user_id = v_user_id
  for update;

  if not found then raise exception 'Avatar request not found'; end if;
  if v_req.status <> 'ready_for_review' then raise exception 'A revision can only be requested while a replacement is ready for review'; end if;
  if v_req.revision_count >= 2 then raise exception 'Maximum of two revision requests reached'; end if;
  if char_length(trim(coalesce(p_message,''))) < 5 or char_length(p_message) > 1000 then raise exception 'Revision message must be between 5 and 1000 characters'; end if;

  update public.avatar_replacement_requests set
    status = 'revision_requested',
    user_revision_message = trim(p_message),
    revision_count = revision_count + 1,
    user_decision_at = now(),
    updated_at = now()
  where id = p_request_id;

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message)
  values(p_request_id,'revision_requested','user',trim(p_message));

  perform public.emit_notification_v1(
    v_req.user_id, v_req.player_id, 'avatar.request.revision', 'Avatar revision requested',
    'Your revision request was recorded. Your current avatar stays active while the replacement is revised.',
    '/game/player-account', jsonb_build_object('request_id',p_request_id,'revision_count',v_req.revision_count+1),
    'avatar-request-revision:' || p_request_id::text || ':' || (v_req.revision_count+1)::text
  );
end;
$function$;

revoke all on function public.request_avatar_replacement_revision_v1(uuid,text) from public, anon;
grant execute on function public.request_avatar_replacement_revision_v1(uuid,text) to authenticated;

create or replace function public.approve_avatar_replacement_v1(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public','storage','pg_temp'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_req public.avatar_replacement_requests%rowtype;
  v_exists boolean;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;

  select * into v_req
  from public.avatar_replacement_requests
  where id = p_request_id and user_id = v_user_id
  for update;

  if not found then raise exception 'Avatar request not found'; end if;
  if v_req.status <> 'ready_for_review' or v_req.review_image_path is null then raise exception 'No replacement is ready for approval'; end if;

  select exists(
    select 1 from storage.objects
    where bucket_id = 'player-avatars' and name = v_req.review_image_path
  ) into v_exists;
  if not v_exists then raise exception 'Prepared avatar image is missing'; end if;

  update public.players
  set image_path = v_req.review_image_path, updated_at = now()
  where id = v_req.player_id and owner_user_id = v_user_id;

  if not found then raise exception 'Player ownership validation failed'; end if;

  update public.avatar_replacement_requests set
    status = 'completed',
    completed_at = now(),
    user_decision_at = now(),
    reference_delete_after = now() + interval '30 days',
    updated_at = now()
  where id = p_request_id;

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message)
  values(p_request_id,'completed','user','Replacement approved and applied.');

  perform public.emit_notification_v1(
    v_req.user_id, v_req.player_id, 'avatar.request.completed', 'Avatar replacement completed',
    'Your approved replacement avatar is now active. The private reference photo is scheduled for deletion after the retention period.',
    '/game/player-account', jsonb_build_object('request_id',p_request_id,'status','completed'),
    'avatar-request-completed:' || p_request_id::text
  );
end;
$function$;

revoke all on function public.approve_avatar_replacement_v1(uuid) from public, anon;
grant execute on function public.approve_avatar_replacement_v1(uuid) to authenticated;

create or replace function public.admin_update_avatar_replacement_status_v1(
  p_request_id uuid,
  p_status text,
  p_public_message text default null,
  p_internal_note text default null
) returns void
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_req public.avatar_replacement_requests%rowtype;
begin
  if current_user not in ('service_role','postgres') then raise exception 'Admin service role required'; end if;
  if p_status not in ('under_review','preparing','rejected') then raise exception 'Unsupported admin status'; end if;

  select * into v_req
  from public.avatar_replacement_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'Avatar request not found'; end if;
  if v_req.status in ('completed','rejected') then raise exception 'Closed avatar request cannot be changed'; end if;

  update public.avatar_replacement_requests set
    status = p_status,
    admin_public_message = coalesce(p_public_message,admin_public_message),
    admin_internal_note = coalesce(p_internal_note,admin_internal_note),
    rejected_at = case when p_status='rejected' then now() else rejected_at end,
    reference_delete_after = case when p_status='rejected' then now()+interval '30 days' else reference_delete_after end,
    updated_at = now()
  where id = p_request_id;

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message,internal_note)
  values(p_request_id,p_status,'admin',p_public_message,p_internal_note);

  if p_status = 'rejected' then
    perform public.emit_notification_v1(
      v_req.user_id, v_req.player_id, 'avatar.request.rejected', 'Avatar request unable to process',
      coalesce(nullif(trim(p_public_message),''),'Your avatar replacement request could not be processed. Open Player & account for details.'),
      '/game/player-account', jsonb_build_object('request_id',p_request_id,'status','rejected'),
      'avatar-request-rejected:' || p_request_id::text
    );
  end if;
end;
$function$;

revoke all on function public.admin_update_avatar_replacement_status_v1(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.admin_update_avatar_replacement_status_v1(uuid,text,text,text) to service_role;

create or replace function public.admin_set_avatar_replacement_review_v1(
  p_request_id uuid,
  p_review_image_path text,
  p_public_message text default null,
  p_internal_note text default null
) returns void
language plpgsql
security definer
set search_path to 'public','storage','pg_temp'
as $function$
declare
  v_req public.avatar_replacement_requests%rowtype;
  v_exists boolean;
begin
  if current_user not in ('service_role','postgres') then raise exception 'Admin service role required'; end if;
  if p_review_image_path is null or trim(p_review_image_path) = '' then raise exception 'Review image path is required'; end if;

  select exists(
    select 1 from storage.objects
    where bucket_id = 'player-avatars' and name = p_review_image_path
  ) into v_exists;
  if not v_exists then raise exception 'Review image must already exist in player-avatars storage'; end if;

  select * into v_req
  from public.avatar_replacement_requests
  where id = p_request_id
  for update;

  if not found then raise exception 'Avatar request not found'; end if;
  if v_req.status in ('completed','rejected') then raise exception 'Closed avatar request cannot be changed'; end if;

  update public.avatar_replacement_requests set
    status = 'ready_for_review',
    review_image_path = p_review_image_path,
    admin_public_message = coalesce(p_public_message,admin_public_message),
    admin_internal_note = coalesce(p_internal_note,admin_internal_note),
    ready_for_review_at = now(),
    user_revision_message = null,
    updated_at = now()
  where id = p_request_id;

  insert into public.avatar_replacement_request_history(request_id,status,actor_type,public_message,internal_note)
  values(p_request_id,'ready_for_review','admin',p_public_message,p_internal_note);

  perform public.emit_notification_v1(
    v_req.user_id, v_req.player_id, 'avatar.request.ready', 'Avatar replacement ready for review',
    coalesce(nullif(trim(p_public_message),''),'Your replacement avatar is ready. Review it in Player & account before applying it.'),
    '/game/player-account', jsonb_build_object('request_id',p_request_id,'status','ready_for_review'),
    'avatar-request-ready:' || p_request_id::text || ':' || coalesce(v_req.revision_count,0)::text
  );
end;
$function$;

revoke all on function public.admin_set_avatar_replacement_review_v1(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.admin_set_avatar_replacement_review_v1(uuid,text,text,text) to service_role;

create or replace function public.admin_mark_avatar_reference_deleted_v1(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
begin
  if current_user not in ('service_role','postgres') then raise exception 'Admin service role required'; end if;

  update public.avatar_replacement_requests
  set reference_deleted_at = now(), updated_at = now()
  where id = p_request_id;

  if not found then raise exception 'Avatar request not found'; end if;
end;
$function$;

revoke all on function public.admin_mark_avatar_reference_deleted_v1(uuid) from public, anon, authenticated;
grant execute on function public.admin_mark_avatar_reference_deleted_v1(uuid) to service_role;
