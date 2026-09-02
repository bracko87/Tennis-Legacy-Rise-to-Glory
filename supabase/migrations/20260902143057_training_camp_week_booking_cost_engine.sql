alter table public.players add column if not exists home_city text;

alter table public.training_camp_locations
  add column if not exists cost_index numeric(6,3) not null default 1.000;

create table if not exists public.training_camp_accommodation_tiers (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  star_rating smallint not null check (star_rating between 2 and 5),
  base_weekly_cost integer not null check (base_weekly_cost >= 0),
  rest_quality numeric(5,3) not null default 1.000,
  fatigue_mitigation smallint not null default 0,
  weekly_morale_bonus smallint not null default 0,
  weekly_focus_bonus smallint not null default 0,
  description text not null,
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.training_camp_accommodation_tiers
  (slug,name,star_rating,base_weekly_cost,rest_quality,fatigue_mitigation,weekly_morale_bonus,weekly_focus_bonus,description,sort_order)
values
  ('budget-2-star','Budget Hotel',2,350,0.950,0,0,0,'Simple two-star accommodation. Lowest price, basic recovery environment and no additional fatigue-recovery bonus.',1),
  ('standard-3-star','Standard Hotel',3,560,1.000,0,0,0,'Reliable three-star accommodation with normal rest quality. This is the neutral baseline for camp recovery.',2),
  ('comfort-4-star','Comfort Hotel',4,840,1.080,1,1,0,'Higher-comfort four-star accommodation. Better rest reduces daily camp fatigue slightly and adds a small weekly morale benefit.',3),
  ('premium-5-star','Premium Hotel',5,1260,1.150,2,1,1,'Premium five-star accommodation. Best rest quality, stronger daily fatigue mitigation and small weekly morale and focus benefits.',4)
on conflict (slug) do update set
  name=excluded.name, star_rating=excluded.star_rating, base_weekly_cost=excluded.base_weekly_cost,
  rest_quality=excluded.rest_quality, fatigue_mitigation=excluded.fatigue_mitigation,
  weekly_morale_bonus=excluded.weekly_morale_bonus, weekly_focus_bonus=excluded.weekly_focus_bonus,
  description=excluded.description, sort_order=excluded.sort_order, is_active=true, updated_at=now();

alter table public.training_camp_accommodation_tiers enable row level security;
drop policy if exists training_camp_accommodation_tiers_read on public.training_camp_accommodation_tiers;
create policy training_camp_accommodation_tiers_read on public.training_camp_accommodation_tiers for select to authenticated using (is_active);
grant select on public.training_camp_accommodation_tiers to authenticated;

create or replace function public.country_continent_v1(p_code text)
returns text language sql immutable as $$
  select case upper(coalesce(p_code,''))
    when 'US' then 'North America' when 'CA' then 'North America' when 'MX' then 'North America' when 'CR' then 'North America' when 'PA' then 'North America' when 'BS' then 'North America' when 'JM' then 'North America' when 'DO' then 'North America' when 'PR' then 'North America' when 'GT' then 'North America'
    when 'AR' then 'South America' when 'BR' then 'South America' when 'CL' then 'South America' when 'CO' then 'South America' when 'PE' then 'South America' when 'VE' then 'South America' when 'EC' then 'South America' when 'UY' then 'South America' when 'PY' then 'South America' when 'BO' then 'South America' when 'GY' then 'South America' when 'SR' then 'South America' when 'GF' then 'South America'
    when 'AU' then 'Oceania' when 'NZ' then 'Oceania' when 'FJ' then 'Oceania' when 'PG' then 'Oceania' when 'NC' then 'Oceania'
    when 'ZA' then 'Africa' when 'NG' then 'Africa' when 'EG' then 'Africa' when 'MA' then 'Africa' when 'TN' then 'Africa' when 'KE' then 'Africa' when 'RW' then 'Africa' when 'ET' then 'Africa' when 'GH' then 'Africa' when 'SN' then 'Africa' when 'CI' then 'Africa' when 'ZM' then 'Africa' when 'NA' then 'Africa' when 'MU' then 'Africa' when 'SC' then 'Africa'
    when 'AE' then 'Asia' when 'SA' then 'Asia' when 'IN' then 'Asia' when 'PK' then 'Asia' when 'BD' then 'Asia' when 'CN' then 'Asia' when 'JP' then 'Asia' when 'KR' then 'Asia' when 'HK' then 'Asia' when 'SG' then 'Asia' when 'ID' then 'Asia' when 'MY' then 'Asia' when 'TH' then 'Asia' when 'VN' then 'Asia' when 'PH' then 'Asia' when 'IL' then 'Asia' when 'QA' then 'Asia' when 'KZ' then 'Asia' when 'UZ' then 'Asia' when 'KG' then 'Asia' when 'NP' then 'Asia' when 'OM' then 'Asia' when 'TW' then 'Asia' when 'MN' then 'Asia' when 'TR' then 'Asia'
    when 'GB' then 'Europe' when 'IE' then 'Europe' when 'FR' then 'Europe' when 'DE' then 'Europe' when 'ES' then 'Europe' when 'IT' then 'Europe' when 'PT' then 'Europe' when 'NL' then 'Europe' when 'BE' then 'Europe' when 'LU' then 'Europe' when 'SE' then 'Europe' when 'NO' then 'Europe' when 'DK' then 'Europe' when 'FI' then 'Europe' when 'CH' then 'Europe' when 'AT' then 'Europe' when 'PL' then 'Europe' when 'CZ' then 'Europe' when 'HU' then 'Europe' when 'RO' then 'Europe' when 'BG' then 'Europe' when 'GR' then 'Europe' when 'RU' then 'Europe' when 'UA' then 'Europe' when 'RS' then 'Europe' when 'HR' then 'Europe' when 'SI' then 'Europe' when 'BA' then 'Europe' when 'MK' then 'Europe' when 'AL' then 'Europe' when 'LV' then 'Europe' when 'LT' then 'Europe' when 'EE' then 'Europe' when 'IS' then 'Europe' else null end;
$$;

create table if not exists public.player_location_state (
  player_id uuid primary key references public.players(id) on delete cascade,
  current_city text,
  current_country_code text not null,
  current_continent text,
  location_type text not null default 'home' check (location_type in ('home','travel','tournament','training_camp')),
  source_reference_id text,
  updated_at timestamptz not null default now()
);
alter table public.player_location_state enable row level security;
drop policy if exists player_location_state_read_own on public.player_location_state;
create policy player_location_state_read_own on public.player_location_state for select to authenticated using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));
grant select on public.player_location_state to authenticated;
insert into public.player_location_state(player_id,current_city,current_country_code,current_continent,location_type)
select p.id,p.home_city,p.country_code,public.country_continent_v1(p.country_code),'home' from public.players p on conflict (player_id) do nothing;

alter table public.player_training_camp_bookings
  add column if not exists start_season_week smallint,
  add column if not exists accommodation_tier_id uuid references public.training_camp_accommodation_tiers(id),
  add column if not exists training_fee_total integer not null default 0,
  add column if not exists accommodation_weekly_cost integer not null default 0,
  add column if not exists accommodation_total integer not null default 0,
  add column if not exists travel_cost integer not null default 0,
  add column if not exists staff_count smallint not null default 0,
  add column if not exists staff_travel_cost integer not null default 0,
  add column if not exists staff_accommodation_cost integer not null default 0,
  add column if not exists staff_total_cost integer not null default 0,
  add column if not exists origin_city text,
  add column if not exists origin_country_code text,
  add column if not exists origin_continent text;

update public.training_camp_locations set cost_index=case continent when 'Europe' then 1.10 when 'Asia' then 0.95 when 'Africa' then 0.80 when 'North America' then 1.05 when 'South America' then 0.85 when 'Oceania' then 1.00 else 1.00 end;
update public.training_camp_locations set cost_index=case city when 'London' then 1.40 when 'Geneva' then 1.40 when 'Dubai' then 1.35 when 'Singapore' then 1.35 when 'Cannes' then 1.25 when 'Tokyo' then 1.25 when 'Sydney' then 1.25 when 'Abu Dhabi' then 1.25 when 'Nice' then 1.20 when 'Melbourne' then 1.20 when 'Doha' then 1.20 when 'Barcelona' then 1.15 when 'Mallorca' then 1.10 else cost_index end;

update public.training_camp_locations l set description=case l.city
 when 'Barcelona' then 'Barcelona is a major Mediterranean training base in Spain with a strong tennis identity, extensive sporting infrastructure and a busy international atmosphere. In Tennis Legacy it is positioned as a premium destination for players who want focused court work while staying in a large professional-sport city.'
 when 'Mallorca' then 'Mallorca provides an island training environment in Spain with a strong racket-sport tradition and a quieter camp rhythm than a major capital city. It is designed as a balanced destination where technical training can be combined with effective recovery between sessions.'
 when 'Nice' then 'Nice is a French Riviera training destination with an international sporting environment and higher local living costs. In Tennis Legacy it is treated as an advanced European base suited to players who want intensive court development with comfortable recovery options.'
 when 'Dubai' then 'Dubai is a high-cost international sports hub in the United Arab Emirates with modern facilities and strong long-haul transport connections. In Tennis Legacy it is positioned as a premium hard-court destination where accommodation choice has a noticeable effect on the final camp budget.'
 else format('%s is a Tennis Legacy training destination in %s. This location is part of the %s camp network and provides a dedicated base for structured training, recovery and multi-week player development. Local accommodation prices and transfer costs are calculated separately from the training program itself.',l.city,l.country,l.continent) end,updated_at=now();

update public.training_camp_programs p set description=case
 when p.category='tennis_skills' then format('%s %s-court program in %s. The camp concentrates development on surface-relevant racket skills, with the strongest gains assigned to the listed technical attributes. Training intensity is driven by the program quality tier while accommodation mainly affects rest and fatigue recovery.',initcap(p.quality_tier),initcap(coalesce(p.surface,'hard')),l.city)
 when p.category='physical' then format('%s physical-performance program in %s. The camp prioritizes Fitness, Stamina, Recovery and Movement. Higher program quality increases development efficiency; hotel quality is calculated separately and influences rest and fatigue management rather than permanent skill gain.',initcap(p.quality_tier),l.city)
 else format('%s recovery and mindset program in %s. The schedule is designed to reduce Fatigue and rebuild Morale, Confidence, Sharpness and Focus. Program quality controls the recovery profile, while higher hotel categories can add further rest-quality benefits.',initcap(p.quality_tier),l.city) end,updated_at=now()
from public.training_camp_locations l where l.id=p.location_id;

create or replace function public.training_camp_week_start_absolute_v1(p_season integer,p_season_week smallint) returns integer language plpgsql immutable as $$
begin if p_season<1 then raise exception 'Season must be positive.'; end if; if p_season_week not between 1 and 52 then raise exception 'Season week must be between 1 and 52.'; end if; return (p_season-1)*366+2+(p_season_week-1)*7; end; $$;

create or replace function public.training_camp_travel_cost_v1(p_origin_city text,p_origin_country_code text,p_origin_continent text,p_destination_city text,p_destination_country_code text,p_destination_continent text)
returns integer language plpgsql immutable as $$
declare v_cost integer; begin
 if upper(coalesce(p_origin_country_code,''))=upper(coalesce(p_destination_country_code,'')) then if lower(trim(coalesce(p_origin_city,'')))<>'' and lower(trim(coalesce(p_origin_city,'')))=lower(trim(coalesce(p_destination_city,''))) then return 40; end if; return 120; end if;
 if coalesce(p_origin_continent,'')<>'' and p_origin_continent=p_destination_continent then v_cost:=case p_destination_continent when 'Europe' then 240 when 'Asia' then 280 when 'Africa' then 260 when 'North America' then 280 when 'South America' then 250 when 'Oceania' then 260 else 300 end; return v_cost; end if;
 v_cost:=650; if p_origin_continent='Oceania' or p_destination_continent='Oceania' then v_cost:=v_cost+300; end if; if (p_origin_continent='Asia' and p_destination_continent='North America') or (p_origin_continent='North America' and p_destination_continent='Asia') then v_cost:=v_cost+180; end if; if (p_origin_continent='Europe' and p_destination_continent='Asia') or (p_origin_continent='Asia' and p_destination_continent='Europe') then v_cost:=v_cost+80; end if; if p_origin_continent is null or p_destination_continent is null then v_cost:=700; end if; return v_cost; end; $$;

create or replace function public.quote_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star') returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_user uuid:=auth.uid(); v_player public.players%rowtype; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_hotel public.training_camp_accommodation_tiers%rowtype; v_state public.player_location_state%rowtype; v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_training_total integer; v_hotel_weekly integer; v_hotel_total integer; v_travel integer; v_total integer; v_origin_city text; v_origin_country text; v_origin_continent text; v_origin_precision text;
begin
 if v_user is null then raise exception 'Authentication required.'; end if; select * into v_player from public.players where owner_user_id=v_user; if v_player.id is null then raise exception 'Player not found.'; end if; select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if; select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active; select * into v_hotel from public.training_camp_accommodation_tiers where slug=p_accommodation_slug and is_active; if v_hotel.id is null then raise exception 'Accommodation option not found.'; end if; if p_duration_weeks not between 1 and 4 then raise exception 'Training camp duration must be between 1 and 4 weeks.'; end if; if p_start_week not between 1 and 52 then raise exception 'Start week must be between 1 and 52.'; end if; if p_start_week+p_duration_weeks-1>52 then raise exception 'Training camp cannot extend beyond Season Week 52.'; end if;
 v_start_abs:=public.training_camp_week_start_absolute_v1(p_start_season,p_start_week); v_end_abs:=v_start_abs+p_duration_weeks*7-1; select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs<v_current_abs then raise exception 'Training camp must begin at the start of a current or future competition week.'; end if; select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs); select * into v_state from public.player_location_state where player_id=v_player.id;
 v_origin_city:=coalesce(nullif(v_state.current_city,''),nullif(v_player.home_city,''),'Home base'); v_origin_country:=coalesce(nullif(v_state.current_country_code,''),v_player.country_code); v_origin_continent:=coalesce(nullif(v_state.current_continent,''),public.country_continent_v1(v_origin_country)); v_origin_precision:=case when coalesce(nullif(v_state.current_city,''),nullif(v_player.home_city,'')) is null then 'country_estimate' else 'city' end;
 v_training_total:=v_program.weekly_cost*p_duration_weeks; v_hotel_weekly:=round((v_hotel.base_weekly_cost*v_location.cost_index)/10.0)::integer*10; v_hotel_total:=v_hotel_weekly*p_duration_weeks; v_travel:=public.training_camp_travel_cost_v1(v_origin_city,v_origin_country,v_origin_continent,v_location.city,v_location.country_code,v_location.continent); v_total:=v_training_total+v_hotel_total+v_travel;
 return jsonb_build_object('program_id',v_program.id,'camp_name',v_program.name,'quality_tier',v_program.quality_tier,'facility_rating',v_program.rating,'quality_multiplier',v_program.quality_multiplier,'start_season',p_start_season,'start_week',p_start_week,'start_absolute_day',v_start_abs,'end_absolute_day',v_end_abs,'start',jsonb_build_object('season',v_start.season,'month',v_start.month,'day',v_start.day),'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),'duration_weeks',p_duration_weeks,'origin',jsonb_build_object('city',v_origin_city,'country_code',v_origin_country,'continent',v_origin_continent,'precision',v_origin_precision),'destination',jsonb_build_object('city',v_location.city,'country',v_location.country,'country_code',v_location.country_code,'continent',v_location.continent),'training_fee_weekly',v_program.weekly_cost,'training_fee_total',v_training_total,'accommodation',jsonb_build_object('id',v_hotel.id,'slug',v_hotel.slug,'name',v_hotel.name,'stars',v_hotel.star_rating,'weekly_cost',v_hotel_weekly,'total',v_hotel_total,'rest_quality',v_hotel.rest_quality,'fatigue_mitigation',v_hotel.fatigue_mitigation,'weekly_morale_bonus',v_hotel.weekly_morale_bonus,'weekly_focus_bonus',v_hotel.weekly_focus_bonus,'description',v_hotel.description),'travel_cost',v_travel,'travel_type','Round-trip estimate','staff_count',0,'staff_cost',0,'grand_total',v_total);
end; $$;
grant execute on function public.quote_training_camp_v2(uuid,integer,smallint,smallint,text) to authenticated;

create or replace function public.book_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star') returns jsonb language plpgsql security definer set search_path='public' as $$
declare v_user uuid:=auth.uid(); v_player_id uuid; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_quote jsonb; v_hotel_id uuid; v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_booking public.player_training_camp_bookings%rowtype; d record;
begin
 if v_user is null then raise exception 'Authentication required.'; end if; select id into v_player_id from public.players where owner_user_id=v_user; if v_player_id is null then raise exception 'Player not found.'; end if; select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if; select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active; v_quote:=public.quote_training_camp_v2(p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug); v_start_abs:=(v_quote->>'start_absolute_day')::integer; v_end_abs:=(v_quote->>'end_absolute_day')::integer; v_hotel_id:=(v_quote->'accommodation'->>'id')::uuid; select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs<v_current_abs then raise exception 'Training camp cannot start in the past.'; end if;
 if exists(select 1 from public.player_training_camp_bookings b where b.player_id=v_player_id and b.status in ('booked','active') and int4range(b.start_absolute_day,b.end_absolute_day,'[]')&&int4range(v_start_abs,v_end_abs,'[]')) then raise exception 'Another training camp overlaps the selected weeks.'; end if;
 if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_daily_activity a on a.player_id=v_player_id and a.season=gd.season and a.month=gd.month and a.day=gd.day where a.activity_type<>'home' or a.effects_applied_at is not null) then raise exception 'The selected weeks contain travel, tournament, injury, another camp, or an already processed activity.'; end if;
 if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_training_sessions s on s.player_id=v_player_id and s.season=gd.season and s.month=gd.month and s.day=gd.day) then raise exception 'Regular training has already been processed during one of the selected weeks.'; end if;
 if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.tournament_editions te on te.season_number=gd.season join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id join public.tournament_applications ta on ta.competition_id=wc.id and ta.player_id=v_player_id where gd.season_week>0 and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')) then raise exception 'A tournament application or commitment overlaps the selected camp weeks.'; end if;
 select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);
 insert into public.player_training_camp_bookings(player_id,program_id,start_absolute_day,end_absolute_day,start_season,start_month,start_day,end_season,end_month,end_day,duration_weeks,weekly_cost,total_cost,status,start_season_week,accommodation_tier_id,training_fee_total,accommodation_weekly_cost,accommodation_total,travel_cost,staff_count,staff_travel_cost,staff_accommodation_cost,staff_total_cost,origin_city,origin_country_code,origin_continent)
 values(v_player_id,v_program.id,v_start_abs,v_end_abs,v_start.season,v_start.month,v_start.day,v_end.season,v_end.month,v_end.day,p_duration_weeks,v_program.weekly_cost,(v_quote->>'grand_total')::integer,'booked',p_start_week,v_hotel_id,(v_quote->>'training_fee_total')::integer,(v_quote->'accommodation'->>'weekly_cost')::integer,(v_quote->'accommodation'->>'total')::integer,(v_quote->>'travel_cost')::integer,0,0,0,0,v_quote->'origin'->>'city',v_quote->'origin'->>'country_code',v_quote->'origin'->>'continent') returning * into v_booking;
 for d in select gd.* from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd loop insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note) values(v_player_id,d.season,d.month,d.day,'training_camp','training_camp_booking',v_booking.id::text,v_program.name) on conflict(player_id,season,month,day) do update set activity_type='training_camp',source='training_camp_booking',reference_id=v_booking.id::text,note=v_program.name,updated_at=now(); end loop;
 perform public.emit_notification_v1(v_user,v_player_id,'training.camp.booked','Training camp booked',format('%s in %s is booked for Season Week %s for %s week%s.',v_program.name,v_location.city,p_start_week,p_duration_weeks,case when p_duration_weeks=1 then '' else 's' end),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost),'training-camp-booked:'||v_booking.id::text);
 return jsonb_build_object('status','booked','booking_id',v_booking.id,'camp_name',v_program.name,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost,'quote',v_quote); end; $$;
grant execute on function public.book_training_camp_v2(uuid,integer,smallint,smallint,text) to authenticated;

create or replace function public.apply_training_camp_accommodation_effects_v1() returns trigger language plpgsql security definer set search_path='public' as $$
declare v_tier public.training_camp_accommodation_tiers%rowtype; v_fatigue_before smallint; v_fatigue_after smallint; v_morale_bonus smallint:=0; v_focus_bonus smallint:=0;
begin select t.* into v_tier from public.player_training_camp_bookings b join public.training_camp_accommodation_tiers t on t.id=b.accommodation_tier_id where b.id=new.booking_id; if v_tier.id is null then return new; end if; select fatigue into v_fatigue_before from public.player_skills where player_id=new.player_id; if mod(new.camp_day_number,7)=0 then v_morale_bonus:=v_tier.weekly_morale_bonus; v_focus_bonus:=v_tier.weekly_focus_bonus; end if; update public.player_skills set fatigue=greatest(0,fatigue-v_tier.fatigue_mitigation),morale=least(100,morale+v_morale_bonus),focus=least(100,focus+v_focus_bonus),updated_at=now() where player_id=new.player_id; select fatigue into v_fatigue_after from public.player_skills where player_id=new.player_id; update public.player_training_camp_days set condition_changes=coalesce(condition_changes,'{}'::jsonb)||jsonb_build_object('accommodation',jsonb_build_object('tier',v_tier.slug,'stars',v_tier.star_rating,'fatigue_mitigation',v_tier.fatigue_mitigation,'fatigue_before_hotel',v_fatigue_before,'fatigue_after_hotel',v_fatigue_after,'morale_bonus',v_morale_bonus,'focus_bonus',v_focus_bonus)) where id=new.id; update public.player_daily_activity set effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object('accommodation_effects',jsonb_build_object('tier',v_tier.slug,'stars',v_tier.star_rating,'fatigue_mitigation',v_tier.fatigue_mitigation,'morale_bonus',v_morale_bonus,'focus_bonus',v_focus_bonus)),updated_at=now() where player_id=new.player_id and season=new.season and month=new.month and day=new.day; return new; end; $$;

drop trigger if exists trg_training_camp_accommodation_effects on public.player_training_camp_days;
create trigger trg_training_camp_accommodation_effects after insert on public.player_training_camp_days for each row execute function public.apply_training_camp_accommodation_effects_v1();
