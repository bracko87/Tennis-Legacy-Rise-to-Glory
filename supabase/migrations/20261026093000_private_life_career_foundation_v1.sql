-- Tennis Legacy Private Life / career link — additive foundation.
-- No existing player nationality, original home_city, completed travel or historical balances are rewritten.
create table if not exists public.player_lifestyle_state (
 player_id uuid primary key references public.players(id) on delete cascade,
 active_residence_asset_id uuid references public.private_life_player_assets(id),
 pending_residence_asset_id uuid references public.private_life_player_assets(id),
 pending_effective_absolute_day integer,
 last_relocation_absolute_day integer,
 preferred_travel_mode text not null default 'ask_every_time'
  check (preferred_travel_mode in ('cheapest','commercial','best_owned_jet','ask_every_time')),
 applied_morale_bonus smallint not null default 0 check (applied_morale_bonus between 0 and 3),
 updated_at timestamptz not null default now()
);
create table if not exists public.player_lifestyle_morale_events (
 id uuid primary key default gen_random_uuid(),
 player_id uuid not null references public.players(id) on delete cascade,
 owned_asset_id uuid not null unique references public.private_life_player_assets(id) on delete cascade,
 category text not null,
 purchased_absolute_day integer not null,
 boost_points smallint not null check(boost_points between 1 and 3),
 created_at timestamptz not null default now()
);
create index if not exists player_lifestyle_morale_player_day_idx
 on public.player_lifestyle_morale_events(player_id,purchased_absolute_day desc);
alter table public.player_lifestyle_state enable row level security;
alter table public.player_lifestyle_morale_events enable row level security;
revoke all on public.player_lifestyle_state,public.player_lifestyle_morale_events from anon,authenticated;
grant select on public.player_lifestyle_state,public.player_lifestyle_morale_events to authenticated;
drop policy if exists lifestyle_state_owner_read on public.player_lifestyle_state;
create policy lifestyle_state_owner_read on public.player_lifestyle_state for select to authenticated
 using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=(select auth.uid())));
drop policy if exists lifestyle_morale_owner_read on public.player_lifestyle_morale_events;
create policy lifestyle_morale_owner_read on public.player_lifestyle_morale_events for select to authenticated
 using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=(select auth.uid())));

create or replace function public.refresh_player_lifestyle_morale_v1(p_player_id uuid)
returns integer language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_day integer; v_desired integer; v_applied integer; v_before integer; v_after integer;
begin
 select public.game_day_absolute_v1(season,month,day) into v_day from public.get_current_game_day_internal_v1();
 insert into public.player_lifestyle_state(player_id) values(p_player_id) on conflict do nothing;
 select applied_morale_bonus into v_applied from public.player_lifestyle_state where player_id=p_player_id for update;
 select least(3,coalesce(sum(greatest(0,boost_points-((greatest(0,v_day-purchased_absolute_day)/7)) )),0))::integer
 into v_desired from public.player_lifestyle_morale_events where player_id=p_player_id;
 select morale into v_before from public.player_skills where player_id=p_player_id for update;
 if v_before is null then return 0; end if;
 v_after:=greatest(1,least(100,v_before+v_desired-v_applied));
 update public.player_skills set morale=v_after,updated_at=now() where player_id=p_player_id and morale<>v_after;
 update public.player_lifestyle_state
 set applied_morale_bonus=greatest(0,least(3,v_applied+v_after-v_before)),updated_at=now()
 where player_id=p_player_id;
 return v_after-v_before;
end; $$;
revoke all on function public.refresh_player_lifestyle_morale_v1(uuid) from public,anon,authenticated;

create or replace function public.lifestyle_purchase_morale_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_category text; v_day integer; v_points integer;
begin
 if new.acquisition_type<>'purchase' then return new; end if;
 select category into v_category from public.private_life_asset_catalog where code=new.catalog_code;
 if v_category not in ('watch','jewelry','car','apartment','house_villa','yacht','private_jet','art','collectible') then return new; end if;
 v_day:=new.purchase_absolute_day;
 -- A second purchase in the same category within 14 game days brings no additional morale.
 if exists(select 1 from public.player_lifestyle_morale_events e where e.player_id=new.player_id and e.category=v_category and e.purchased_absolute_day>v_day-14) then return new; end if;
 v_points:=case when v_category in ('house_villa','yacht','private_jet') then 3
                when v_category in ('car','apartment','art') then 2 else 1 end;
 insert into public.player_lifestyle_morale_events(player_id,owned_asset_id,category,purchased_absolute_day,boost_points)
 values(new.player_id,new.id,v_category,v_day,v_points);
 perform public.refresh_player_lifestyle_morale_v1(new.player_id);
 return new;
end; $$;
revoke all on function public.lifestyle_purchase_morale_v1() from public,anon,authenticated;
drop trigger if exists trg_lifestyle_purchase_morale on public.private_life_player_assets;
create trigger trg_lifestyle_purchase_morale after insert on public.private_life_player_assets
 for each row execute function public.lifestyle_purchase_morale_v1();

create or replace function public.lifestyle_prevent_active_home_sale_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $$
begin
 if old.sold_absolute_day is null and new.sold_absolute_day is not null and exists (
   select 1 from public.player_lifestyle_state s where s.player_id=old.player_id
   and (s.active_residence_asset_id=old.id or s.pending_residence_asset_id=old.id)
 ) then raise exception 'Change your Home Base before selling this residence.'; end if;
 return new;
end; $$;
revoke all on function public.lifestyle_prevent_active_home_sale_v1() from public,anon,authenticated;
drop trigger if exists trg_lifestyle_prevent_active_home_sale on public.private_life_player_assets;
create trigger trg_lifestyle_prevent_active_home_sale before update of sold_absolute_day on public.private_life_player_assets
 for each row execute function public.lifestyle_prevent_active_home_sale_v1();


-- Reject a sale at listing time instead of letting the settlement cron repeatedly fail.
create or replace function public.lifestyle_prevent_home_listing_v1()
returns trigger language plpgsql security definer set search_path='public','pg_temp' as $
begin
 if new.status='pending' and exists(
  select 1 from public.player_lifestyle_state s
  where s.player_id=new.player_id and
   (s.active_residence_asset_id=new.player_asset_id or s.pending_residence_asset_id=new.player_asset_id)
 ) then raise exception 'Select a different Home Base before listing this property.'; end if;
 return new;
end; $;
revoke all on function public.lifestyle_prevent_home_listing_v1() from public,anon,authenticated;
drop trigger if exists trg_lifestyle_prevent_home_listing on public.private_life_asset_sale_listings;
create trigger trg_lifestyle_prevent_home_listing
 before insert or update of status,player_asset_id on public.private_life_asset_sale_listings
 for each row execute function public.lifestyle_prevent_home_listing_v1();

create or replace function public.set_private_life_home_base_v1(p_owned_asset_id uuid)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_player uuid; v_asset record; v_state public.player_location_state%rowtype;
 v_current integer; v_last integer; v_pending uuid;
begin
 v_player:=public.private_life_current_player_v1();
 select a.id,l.city,l.country_code into v_asset
 from public.private_life_player_assets a
 join public.private_life_asset_catalog c on c.code=a.catalog_code
 join public.private_life_property_locations l on l.code=a.location_code
 where a.id=p_owned_asset_id and a.player_id=v_player and a.sold_absolute_day is null
 and c.category in ('apartment','house_villa');
 if v_asset.id is null then raise exception 'Select a residential property you currently own.'; end if;
 if exists(select 1 from public.private_life_asset_sale_listings x where x.player_asset_id=p_owned_asset_id and x.status='pending') then raise exception 'Cancel the sale listing before selecting this residence.'; end if;
 select public.game_day_absolute_v1(season,month,day) into v_current from public.get_current_game_day_internal_v1();
 insert into public.player_lifestyle_state(player_id) values(v_player) on conflict do nothing;
 select last_relocation_absolute_day,pending_residence_asset_id into v_last,v_pending from public.player_lifestyle_state where player_id=v_player for update;
 if v_pending is not null then raise exception 'A relocation is already pending.'; end if;
 if v_last is not null and v_current-v_last<30 then raise exception 'Home Base can change only once every 30 game days.'; end if;
 select * into v_state from public.player_location_state where player_id=v_player;
 if v_state.location_type<>'home' then raise exception 'You must be at home and not travelling to relocate.'; end if;
 if exists(select 1 from public.player_travel_legs t where t.player_id=v_player and t.status='planned' and t.departure_absolute_day<=v_current+2)
 then raise exception 'Your next scheduled journey is too close to relocate.'; end if;
 update public.player_lifestyle_state set pending_residence_asset_id=p_owned_asset_id,pending_effective_absolute_day=v_current+2,updated_at=now() where player_id=v_player;
 return jsonb_build_object('status','scheduled','city',v_asset.city,'country_code',v_asset.country_code,'effective_absolute_day',v_current+2,'relocation_fee',5000);
end; $$;
revoke all on function public.set_private_life_home_base_v1(uuid) from public,anon;
grant execute on function public.set_private_life_home_base_v1(uuid) to authenticated;

create or replace function public.get_player_home_base_v1(p_player_id uuid)
returns jsonb language sql stable security definer set search_path='public','pg_temp' as $$
 select jsonb_build_object('city',coalesce(l.city,p.home_city),'country_code',coalesce(l.country_code,p.country_code),
 'asset_id',s.active_residence_asset_id,'nationality',p.country_code)
 from public.players p
 left join public.player_lifestyle_state s on s.player_id=p.id
 left join public.private_life_player_assets a on a.id=s.active_residence_asset_id and a.sold_absolute_day is null
 left join public.private_life_property_locations l on l.code=a.location_code
 where p.id=p_player_id;
$$;
revoke all on function public.get_player_home_base_v1(uuid) from public,anon,authenticated;

create or replace function public.set_private_life_travel_preference_v1(p_mode text)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_player uuid;
begin
 if p_mode not in ('cheapest','commercial','best_owned_jet','ask_every_time') then raise exception 'Invalid travel preference.'; end if;
 v_player:=public.private_life_current_player_v1();
 insert into public.player_lifestyle_state(player_id,preferred_travel_mode)
 values(v_player,p_mode) on conflict(player_id) do update
 set preferred_travel_mode=excluded.preferred_travel_mode,updated_at=now();
 return jsonb_build_object('status','saved','preferred_travel_mode',p_mode);
end; $$;
revoke all on function public.set_private_life_travel_preference_v1(text) from public,anon;
grant execute on function public.set_private_life_travel_preference_v1(text) to authenticated;

-- Settlement runs in a trusted server context; it does not change nationality or original birthplace.
create or replace function public.process_due_lifestyle_moves_v1()
returns integer language plpgsql security definer set search_path='public','pg_temp' as $$
declare x record; v_current integer; v_state public.player_location_state%rowtype; v_home jsonb; v_coord jsonb; v_leg uuid; v_count integer:=0;
begin
 select public.game_day_absolute_v1(season,month,day) into v_current from public.get_current_game_day_internal_v1();
 for x in select s.player_id,s.pending_residence_asset_id,a.location_code,l.city,l.country_code,s.pending_effective_absolute_day
 from public.player_lifestyle_state s
 join public.private_life_player_assets a on a.id=s.pending_residence_asset_id and a.sold_absolute_day is null
 join public.private_life_property_locations l on l.code=a.location_code
 where s.pending_effective_absolute_day<=v_current
 loop
 select * into v_state from public.player_location_state where player_id=x.player_id;
 if v_state.location_type<>'home' or exists(
   select 1 from public.player_daily_activity d where d.player_id=x.player_id
   and public.game_day_absolute_v1(d.season,d.month,d.day)=v_current and d.activity_type<>'home'
 ) then continue; end if;
 v_coord:=public.resolve_location_coordinates_v1(x.city,x.country_code,null,null);
 -- Reuse the real travel / fatigue / finance engine to charge the relocation journey.
 v_leg:=public.insert_planned_travel_leg_v1(x.player_id,'other','home',v_state.current_city,v_state.current_country_code,
 v_state.current_latitude,v_state.current_longitude,null,'home',x.city,x.country_code,
 nullif(v_coord->>'latitude','')::double precision,nullif(v_coord->>'longitude','')::double precision,null,
 v_current,v_current,true);
 if v_leg is not null then perform public.process_travel_leg_v1(v_leg); end if;
 perform public.post_career_finance_transaction_v1(x.player_id,-5000,'private_life','relocation',
 'Private Life residence relocation','private_life_asset',x.pending_residence_asset_id::text,
 'lifestyle-move:'||x.player_id::text||':'||x.pending_effective_absolute_day::text,
 jsonb_build_object('city',x.city,'country_code',x.country_code),false,v_current);
 update public.player_lifestyle_state set active_residence_asset_id=x.pending_residence_asset_id,
 pending_residence_asset_id=null,pending_effective_absolute_day=null,
 last_relocation_absolute_day=v_current,updated_at=now() where player_id=x.player_id;
 perform public.rebuild_player_travel_plan_v1(x.player_id);
 v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;
revoke all on function public.process_due_lifestyle_moves_v1() from public,anon,authenticated;

create or replace function public.process_lifestyle_morale_due_v1()
returns integer language plpgsql security definer set search_path='public','pg_temp' as $$
declare x record; v_count integer:=0;
begin
 for x in select distinct player_id from public.player_lifestyle_morale_events loop
 perform public.refresh_player_lifestyle_morale_v1(x.player_id); v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;
revoke all on function public.process_lifestyle_morale_due_v1() from public,anon,authenticated;

-- An hourly scheduled reconciliation gradually expires morale and finalizes eligible moves.
select cron.schedule('tennis-private-life-career-hourly','0 * * * *',
 'select public.process_lifestyle_morale_due_v1(); select public.process_due_lifestyle_moves_v1();');
