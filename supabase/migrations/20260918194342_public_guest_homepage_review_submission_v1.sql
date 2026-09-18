alter table public.player_homepage_reviews
  alter column player_id drop not null,
  alter column user_id drop not null,
  add column if not exists reviewer_name text,
  add column if not exists reviewer_email text,
  add column if not exists reviewer_country_code text,
  add column if not exists submission_source text not null default 'player';

alter table public.player_homepage_reviews
  drop constraint if exists player_homepage_reviews_name_chk,
  drop constraint if exists player_homepage_reviews_email_chk,
  drop constraint if exists player_homepage_reviews_country_chk,
  drop constraint if exists player_homepage_reviews_source_chk;

alter table public.player_homepage_reviews
  add constraint player_homepage_reviews_name_chk
    check (reviewer_name is null or char_length(btrim(reviewer_name)) between 2 and 80),
  add constraint player_homepage_reviews_email_chk
    check (reviewer_email is null or (char_length(btrim(reviewer_email)) between 5 and 254 and position('@' in reviewer_email)>1)),
  add constraint player_homepage_reviews_country_chk
    check (reviewer_country_code is null or reviewer_country_code ~ '^[A-Z]{2}$'),
  add constraint player_homepage_reviews_source_chk
    check (submission_source in ('player','account','guest'));

update public.player_homepage_reviews r
set
  reviewer_name=coalesce(
    r.reviewer_name,
    (select concat_ws(' ',p.first_name,p.last_name) from public.players p where p.id=r.player_id),
    'Tennis Legacy Reviewer'
  ),
  reviewer_email=coalesce(
    r.reviewer_email,
    (select u.email from auth.users u where u.id=r.user_id)
  ),
  reviewer_country_code=coalesce(
    r.reviewer_country_code,
    (select p.country_code from public.players p where p.id=r.player_id)
  ),
  submission_source=case when r.player_id is not null then 'player'
                         when r.user_id is not null then 'account'
                         else 'guest' end;

create unique index if not exists player_homepage_reviews_active_email_uidx
on public.player_homepage_reviews(lower(reviewer_email))
where reviewer_email is not null and status in ('pending','approved');

create or replace function public.submit_public_homepage_review_v1(
  p_reviewer_name text,
  p_reviewer_email text,
  p_rating integer,
  p_review_text text
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
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
$$;

revoke all on function public.submit_public_homepage_review_v1(text,text,integer,text) from public;
grant execute on function public.submit_public_homepage_review_v1(text,text,integer,text) to anon,authenticated;

create or replace function public.get_public_homepage_reviews_v1(p_limit integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_limit integer := greatest(1,least(coalesce(p_limit,30),60));
  v_result jsonb;
begin
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',x.id,
        'player_name',x.reviewer_name,
        'country_code',x.country_code,
        'world',x.world,
        'reviewer_type',x.reviewer_type,
        'rating',x.rating,
        'review_text',x.review_text,
        'approved_at',x.reviewed_at
      )
      order by x.reviewed_at desc,x.submitted_at desc
    ),
    '[]'::jsonb
  )
  into v_result
  from (
    select
      r.id,
      coalesce(nullif(btrim(r.reviewer_name),''),concat_ws(' ',p.first_name,p.last_name),'Tennis Legacy Reviewer') as reviewer_name,
      coalesce(r.reviewer_country_code,p.country_code) as country_code,
      p.world,
      case when p.id is not null then 'player' else 'community' end as reviewer_type,
      r.rating,
      r.review_text,
      r.reviewed_at,
      r.submitted_at
    from public.player_homepage_reviews r
    left join public.players p on p.id=r.player_id
    where r.status='approved'
    order by r.reviewed_at desc nulls last,r.submitted_at desc
    limit v_limit
  ) x;

  return v_result;
end;
$$;

revoke all on function public.get_public_homepage_reviews_v1(integer) from public;
grant execute on function public.get_public_homepage_reviews_v1(integer) to anon,authenticated;

create or replace function public.get_admin_homepage_reviews_v1(p_status text default 'pending')
returns jsonb
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_status text := lower(coalesce(p_status,'pending'));
  v_result jsonb;
begin
  if not public.is_app_admin_v1(auth.uid()) then
    raise exception 'Admin access required' using errcode='42501';
  end if;

  if v_status not in ('pending','approved','rejected','all') then
    raise exception 'Invalid review status filter.';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',r.id,
        'user_id',r.user_id,
        'player_id',r.player_id,
        'player_name',coalesce(nullif(btrim(r.reviewer_name),''),concat_ws(' ',p.first_name,p.last_name),'Unknown reviewer'),
        'reviewer_email',coalesce(r.reviewer_email,u.email),
        'country_code',coalesce(r.reviewer_country_code,p.country_code),
        'world',p.world,
        'submission_source',r.submission_source,
        'rating',r.rating,
        'review_text',r.review_text,
        'status',r.status,
        'submitted_at',r.submitted_at,
        'reviewed_at',r.reviewed_at
      )
      order by case when r.status='pending' then 0 else 1 end,r.submitted_at desc
    ),
    '[]'::jsonb
  )
  into v_result
  from public.player_homepage_reviews r
  left join public.players p on p.id=r.player_id
  left join auth.users u on u.id=r.user_id
  where v_status='all' or r.status=v_status;

  return v_result;
end;
$$;

revoke all on function public.get_admin_homepage_reviews_v1(text) from public,anon;
grant execute on function public.get_admin_homepage_reviews_v1(text) to authenticated;
