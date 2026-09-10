create or replace function public.cancel_avatar_replacement_request_v1(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
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
    set status = 'closed'
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
$function$;

revoke all on function public.cancel_avatar_replacement_request_v1(uuid) from public;
grant execute on function public.cancel_avatar_replacement_request_v1(uuid) to authenticated;
