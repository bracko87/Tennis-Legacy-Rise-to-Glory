create table if not exists public.player_homepage_reviews (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null unique references public.players(id) on delete cascade,
  user_id uuid not null,
  rating smallint not null,
  review_text text not null,
  status text not null default 'pending',
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  constraint player_homepage_reviews_rating_chk check (rating between 1 and 5),
  constraint player_homepage_reviews_text_chk check (char_length(btrim(review_text)) between 20 and 700),
  constraint player_homepage_reviews_status_chk check (status in ('pending','approved','rejected'))
);
create index if not exists player_homepage_reviews_status_submitted_idx on public.player_homepage_reviews(status, submitted_at desc);
create index if not exists player_homepage_reviews_approved_reviewed_idx on public.player_homepage_reviews(reviewed_at desc) where status='approved';
alter table public.player_homepage_reviews enable row level security;
revoke all on table public.player_homepage_reviews from anon, authenticated;

create or replace function public.submit_homepage_review_v1(p_rating integer,p_review_text text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player public.players%rowtype;v_existing public.player_homepage_reviews%rowtype;v_text text:=btrim(coalesce(p_review_text,''));v_review_id uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required.'; end if;
 if p_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5.'; end if;
 if char_length(v_text)<20 then raise exception 'Review must contain at least 20 characters.'; end if;
 if char_length(v_text)>700 then raise exception 'Review cannot exceed 700 characters.'; end if;
 select * into v_player from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
 if v_player.id is null then raise exception 'A Tennis Legacy player is required before submitting a review.'; end if;
 select * into v_existing from public.player_homepage_reviews where player_id=v_player.id for update;
 if v_existing.id is not null then
  if v_existing.status='pending' then raise exception 'Your review is already waiting for administrator approval.';
  elsif v_existing.status='approved' then raise exception 'Your approved review is already published.';
  else
   update public.player_homepage_reviews set rating=p_rating,review_text=v_text,status='pending',submitted_at=now(),updated_at=now(),reviewed_at=null,reviewed_by=null,user_id=auth.uid() where id=v_existing.id returning id into v_review_id;
   return jsonb_build_object('status','pending','review_id',v_review_id,'message','Review resubmitted for administrator approval.');
  end if;
 end if;
 insert into public.player_homepage_reviews(player_id,user_id,rating,review_text,status) values(v_player.id,auth.uid(),p_rating,v_text,'pending') returning id into v_review_id;
 return jsonb_build_object('status','pending','review_id',v_review_id,'message','Review submitted for administrator approval.');
end;$$;
revoke all on function public.submit_homepage_review_v1(integer,text) from public, anon;
grant execute on function public.submit_homepage_review_v1(integer,text) to authenticated;

create or replace function public.get_my_homepage_review_v1()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_player_id uuid;v_result jsonb;
begin
 if auth.uid() is null then return jsonb_build_object('exists',false); end if;
 select id into v_player_id from public.players where owner_user_id=auth.uid() and player_type='human' order by created_at desc limit 1;
 if v_player_id is null then return jsonb_build_object('exists',false); end if;
 select jsonb_build_object('exists',true,'id',r.id,'status',r.status,'rating',r.rating,'review_text',r.review_text,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at) into v_result from public.player_homepage_reviews r where r.player_id=v_player_id;
 return coalesce(v_result,jsonb_build_object('exists',false));
end;$$;
revoke all on function public.get_my_homepage_review_v1() from public, anon;
grant execute on function public.get_my_homepage_review_v1() to authenticated;

create or replace function public.get_public_homepage_reviews_v1(p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_limit integer:=greatest(1,least(coalesce(p_limit,30),60));v_result jsonb;
begin
 select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'player_name',x.player_name,'country_code',x.country_code,'world',x.world,'rating',x.rating,'review_text',x.review_text,'approved_at',x.reviewed_at) order by x.reviewed_at desc,x.submitted_at desc),'[]'::jsonb) into v_result
 from (select r.id,concat_ws(' ',p.first_name,p.last_name) player_name,p.country_code,p.world,r.rating,r.review_text,r.reviewed_at,r.submitted_at from public.player_homepage_reviews r join public.players p on p.id=r.player_id where r.status='approved' and p.player_type='human' order by r.reviewed_at desc nulls last,r.submitted_at desc limit v_limit) x;
 return v_result;
end;$$;
revoke all on function public.get_public_homepage_reviews_v1(integer) from public;
grant execute on function public.get_public_homepage_reviews_v1(integer) to anon, authenticated;

create or replace function public.get_admin_homepage_reviews_v1(p_status text default 'pending')
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_status text:=lower(coalesce(p_status,'pending'));v_result jsonb;
begin
 if not public.is_app_admin_v1(auth.uid()) then raise exception 'Admin access required' using errcode='42501'; end if;
 if v_status not in ('pending','approved','rejected','all') then raise exception 'Invalid review status filter.'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'player_id',p.id,'player_name',concat_ws(' ',p.first_name,p.last_name),'country_code',p.country_code,'world',p.world,'rating',r.rating,'review_text',r.review_text,'status',r.status,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at) order by case when r.status='pending' then 0 else 1 end,r.submitted_at desc),'[]'::jsonb) into v_result
 from public.player_homepage_reviews r join public.players p on p.id=r.player_id where v_status='all' or r.status=v_status;
 return v_result;
end;$$;
revoke all on function public.get_admin_homepage_reviews_v1(text) from public, anon;
grant execute on function public.get_admin_homepage_reviews_v1(text) to authenticated;

create or replace function public.moderate_homepage_review_v1(p_review_id uuid,p_decision text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_decision text:=lower(btrim(coalesce(p_decision,'')));v_status text;
begin
 if not public.is_app_admin_v1(auth.uid()) then raise exception 'Admin access required' using errcode='42501'; end if;
 if v_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected.'; end if;
 update public.player_homepage_reviews set status=v_decision,reviewed_at=now(),reviewed_by=auth.uid(),updated_at=now() where id=p_review_id returning status into v_status;
 if v_status is null then raise exception 'Review not found.'; end if;
 return jsonb_build_object('status',v_status,'review_id',p_review_id);
end;$$;
revoke all on function public.moderate_homepage_review_v1(uuid,text) from public, anon;
grant execute on function public.moderate_homepage_review_v1(uuid,text) to authenticated;
