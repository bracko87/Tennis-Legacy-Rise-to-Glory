-- Preserve current RPC signatures, permissions and user-facing behavior
-- while limiting automated write floods. Database-level budgets cannot fully
-- identify anonymous callers (UUIDs can be rotated); edge controls remain needed.
CREATE OR REPLACE FUNCTION public.record_site_analytics_event_v1(p_visitor_id uuid, p_session_id uuid, p_path text, p_country_code text DEFAULT NULL::text, p_device_type text DEFAULT 'desktop'::text, p_referrer_host text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := now();
  v_date date := (now() at time zone 'Europe/Berlin')::date;
  v_user_id uuid := auth.uid();
  v_path text;
  v_country_code text;
  v_device_type text;
  v_referrer_host text;
begin
  if p_visitor_id is null or p_session_id is null then
    return;
  end if;

  -- A forged UUID can evade the per-visitor limit; the global budget is
  -- independent and limits aggregate table-write amplification.
  if not control_center_private.tennis_allow_public_rpc_v1('analytics_global','all',60,20000)
     or not control_center_private.tennis_allow_public_rpc_v1(
       'analytics_visitor',p_visitor_id::text,60,120) then
    return; -- Analytics must never prevent website navigation.
  end if;

  v_path := left(coalesce(nullif(trim(p_path), ''), '/'), 240);
  if left(v_path, 1) <> '/' then
    v_path := '/' || v_path;
  end if;

  v_country_code := upper(coalesce(nullif(trim(p_country_code), ''), 'XX'));
  if v_country_code <> 'XX' and v_country_code !~ '^[A-Z]{2}$' then
    v_country_code := 'XX';
  end if;

  v_device_type := lower(coalesce(nullif(trim(p_device_type), ''), 'desktop'));
  if v_device_type not in ('desktop', 'tablet', 'mobile') then
    v_device_type := 'desktop';
  end if;

  v_referrer_host := nullif(left(lower(trim(coalesce(p_referrer_host, ''))), 160), '');
  if v_referrer_host in ('tennislegacygame.com', 'www.tennislegacygame.com') then
    v_referrer_host := null;
  end if;

  insert into public.site_analytics_daily_visitors(
    analytics_date,
    visitor_id,
    user_id,
    country_code,
    device_type,
    first_seen_at,
    last_seen_at,
    pageview_count
  )
  values (
    v_date,
    p_visitor_id,
    v_user_id,
    v_country_code,
    v_device_type,
    v_now,
    v_now,
    1
  )
  on conflict (analytics_date, visitor_id) do update
  set user_id = coalesce(v_user_id, public.site_analytics_daily_visitors.user_id),
      country_code = case
        when v_country_code <> 'XX' then v_country_code
        else public.site_analytics_daily_visitors.country_code
      end,
      device_type = v_device_type,
      last_seen_at = v_now,
      pageview_count = public.site_analytics_daily_visitors.pageview_count + 1;

  insert into public.site_analytics_daily_sessions(
    analytics_date,
    session_id,
    visitor_id,
    user_id,
    country_code,
    device_type,
    referrer_host,
    started_at,
    last_seen_at,
    pageview_count
  )
  values (
    v_date,
    p_session_id,
    p_visitor_id,
    v_user_id,
    v_country_code,
    v_device_type,
    v_referrer_host,
    v_now,
    v_now,
    1
  )
  on conflict (analytics_date, session_id) do update
  set user_id = coalesce(v_user_id, public.site_analytics_daily_sessions.user_id),
      country_code = case
        when v_country_code <> 'XX' then v_country_code
        else public.site_analytics_daily_sessions.country_code
      end,
      device_type = v_device_type,
      referrer_host = coalesce(public.site_analytics_daily_sessions.referrer_host, v_referrer_host),
      last_seen_at = v_now,
      pageview_count = public.site_analytics_daily_sessions.pageview_count + 1;

  insert into public.site_analytics_daily_pages(
    analytics_date,
    visitor_id,
    path,
    pageview_count,
    first_seen_at,
    last_seen_at
  )
  values (
    v_date,
    p_visitor_id,
    v_path,
    1,
    v_now,
    v_now
  )
  on conflict (analytics_date, visitor_id, path) do update
  set pageview_count = public.site_analytics_daily_pages.pageview_count + 1,
      last_seen_at = v_now;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.record_cross_game_referral_event_v1(p_event_type text, p_source_game text, p_destination_game text, p_surface text DEFAULT 'unknown'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_event_type not in ('outgoing_click','landing') then
    raise exception 'Unsupported cross-game event type.';
  end if;

  if not (
    (p_event_type='outgoing_click' and p_source_game='tennis_legacy' and p_destination_game='propeloton_manager')
    or
    (p_event_type='landing' and p_source_game='propeloton_manager' and p_destination_game='tennis_legacy')
  ) then
    raise exception 'Invalid cross-game referral direction.';
  end if;

  if not control_center_private.tennis_allow_public_rpc_v1(
       'cross_game_global','all',60,5000) then
     return;
  end if;

  insert into public.cross_game_referral_events(
    event_type,source_game,destination_game,surface,local_user_id
  )
  values(
    p_event_type,
    p_source_game,
    p_destination_game,
    left(coalesce(nullif(trim(p_surface),''),'unknown'),80),
    auth.uid()
  );
end;
$function$
;
CREATE OR REPLACE FUNCTION public.register_referral_click_v1(p_code text, p_browser_hash text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_referrer uuid;
  v_code text := upper(btrim(coalesce(p_code,'')));
begin
  select user_id into v_referrer from public.referral_codes where code=v_code and revoked_at is null;
  if v_referrer is null then return false; end if;
  if not control_center_private.tennis_allow_public_rpc_v1(
       'referral_global','all',60,5000)
     or not control_center_private.tennis_allow_public_rpc_v1(
       'referral_code',v_code,3600,2000) then
    return false;
  end if;
  insert into public.referral_clicks(referral_code,referrer_user_id,browser_hash) values(v_code,v_referrer,nullif(btrim(coalesce(p_browser_hash,'')),''));
  return true;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.submit_public_homepage_review_v1(p_reviewer_name text, p_reviewer_email text, p_rating integer, p_review_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_name text := btrim(coalesce(p_reviewer_name,''));
  v_email text := lower(btrim(coalesce(p_reviewer_email,'')));
  v_text text := btrim(coalesce(p_review_text,''));
  v_user uuid := auth.uid();
  v_player public.players%rowtype;
  v_country text;
  v_source text := 'guest';
  v_review_id uuid;
begin
  if char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'Please enter a name between 2 and 80 characters.';
  end if;

  if char_length(v_email) < 5 or char_length(v_email) > 254
     or position('@' in v_email) <= 1
     or position('.' in split_part(v_email,'@',2)) <= 0 then
    raise exception 'Please enter a valid email address.';
  end if;

  if p_rating not between 1 and 5 then
    raise exception 'Rating must be between 1 and 5.';
  end if;

  if char_length(v_text) < 20 then
    raise exception 'Review must contain at least 20 characters.';
  end if;

  if char_length(v_text) > 700 then
    raise exception 'Review cannot exceed 700 characters.';
  end if;

  if exists (
    select 1
    from public.player_homepage_reviews r
    where lower(r.reviewer_email)=v_email
      and r.status in ('pending','approved')
  ) then
    raise exception 'A review from this email is already pending or published.';
  end if;

  if not control_center_private.tennis_allow_public_rpc_v1(
      'review_global','all',3600,500)
     or not control_center_private.tennis_allow_public_rpc_v1(
      'review_email',v_email,86400,5) then
    return jsonb_build_object(
      'status','rate_limited',
      'message','Too many review submissions. Please try again later.'
    );
  end if;

  if v_user is not null then
    select * into v_player
    from public.players
    where owner_user_id=v_user
      and player_type='human'
    order by created_at desc
    limit 1;

    if v_player.id is not null then
      v_source:='player';
      v_country:=v_player.country_code;
    else
      v_source:='account';
    end if;
  end if;

  insert into public.player_homepage_reviews(
    player_id,user_id,reviewer_name,reviewer_email,reviewer_country_code,
    submission_source,rating,review_text,status
  )
  values(
    v_player.id,v_user,v_name,v_email,v_country,
    v_source,p_rating,v_text,'pending'
  )
  returning id into v_review_id;

  return jsonb_build_object(
    'status','pending',
    'review_id',v_review_id,
    'message','Review submitted for administrator approval.'
  );
exception
  when unique_violation then
    raise exception 'A review from this email is already pending or published.';
end;
$function$
;
