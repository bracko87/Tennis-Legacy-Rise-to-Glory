create or replace function public.country_flag_emoji_v1(p_country_code text)
returns text
language plpgsql immutable
set search_path to 'public'
as $$
declare c text:=upper(coalesce(p_country_code,''));
begin
  if length(c)<>2 or c !~ '^[A-Z]{2}$' then return ''; end if;
  return chr(ascii(substr(c,1,1))+127397)||chr(ascii(substr(c,2,1))+127397);
end;
$$;

create or replace function public.quote_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star'::text)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_user uuid:=auth.uid(); v_player public.players%rowtype; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_hotel public.training_camp_accommodation_tiers%rowtype;
  v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_training_total integer; v_hotel_weekly integer; v_hotel_total integer; v_travel integer; v_total integer;
  v_origin jsonb; v_travel_quote jsonb; v_origin_city text; v_origin_country text;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where owner_user_id=v_user; if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if;
  select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active;
  select * into v_hotel from public.training_camp_accommodation_tiers where slug=p_accommodation_slug and is_active; if v_hotel.id is null then raise exception 'Accommodation option not found.'; end if;
  if p_duration_weeks not between 1 and 4 then raise exception 'Training camp duration must be between 1 and 4 weeks.'; end if;
  if p_start_week not between 1 and 52 then raise exception 'Start week must be between 1 and 52.'; end if;
  if p_start_week+p_duration_weeks-1>52 then raise exception 'Training camp cannot extend beyond Season Week 52.'; end if;
  v_start_abs:=public.training_camp_week_start_absolute_v1(p_start_season,p_start_week); v_end_abs:=v_start_abs+p_duration_weeks*7-1;
  select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1(); if v_start_abs<v_current_abs then raise exception 'Training camp must begin at the start of a current or future competition week.'; end if;
  select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);

  v_origin:=public.resolve_player_origin_before_day_v1(v_player.id,v_start_abs);
  v_origin_city:=nullif(v_origin->>'city','');
  v_origin_country:=v_origin->>'country_code';
  v_training_total:=v_program.weekly_cost*p_duration_weeks;
  v_hotel_weekly:=round((v_hotel.base_weekly_cost*v_location.cost_index)/10.0)::integer*10; v_hotel_total:=v_hotel_weekly*p_duration_weeks;
  v_travel_quote:=public.training_camp_travel_quote_v2(v_origin_city,v_origin_country,v_location.city,v_location.country_code);
  v_travel:=(v_travel_quote->>'cost')::integer; v_total:=v_training_total+v_hotel_total+v_travel;
  return jsonb_build_object(
    'program_id',v_program.id,'camp_name',v_program.name,'training_quality',jsonb_build_object('tier',v_program.quality_tier,'multiplier',v_program.quality_multiplier),'quality_tier',v_program.quality_tier,'facility_rating',v_program.rating,'quality_multiplier',v_program.quality_multiplier,
    'start_season',p_start_season,'start_week',p_start_week,'start_absolute_day',v_start_abs,'end_absolute_day',v_end_abs,'start',jsonb_build_object('season',v_start.season,'month',v_start.month,'day',v_start.day),'end',jsonb_build_object('season',v_end.season,'month',v_end.month,'day',v_end.day),'duration_weeks',p_duration_weeks,
    'origin',(v_origin - 'city' - 'country_code') || jsonb_build_object(
      'city',coalesce(v_origin_city,'Home base not set'),
      'country_code',public.country_flag_emoji_v1(v_origin_country),
      'raw_city',v_origin_city,
      'raw_country_code',v_origin_country
    ),
    'destination',jsonb_build_object(
      'city',v_location.city,'country',v_location.country,
      'country_code',public.country_flag_emoji_v1(v_location.country_code),
      'raw_country_code',v_location.country_code,
      'continent',v_location.continent,'cost_index',v_location.cost_index
    ),
    'training_fee_weekly',v_program.weekly_cost,'training_fee_total',v_training_total,
    'accommodation',jsonb_build_object('id',v_hotel.id,'slug',v_hotel.slug,'name',v_hotel.name,'stars',v_hotel.star_rating,'base_weekly_cost',v_hotel.base_weekly_cost,'destination_cost_index',v_location.cost_index,'weekly_cost',v_hotel_weekly,'total',v_hotel_total,'rest_quality',v_hotel.rest_quality,'fatigue_mitigation',v_hotel.fatigue_mitigation,'weekly_morale_bonus',v_hotel.weekly_morale_bonus,'weekly_focus_bonus',v_hotel.weekly_focus_bonus,'description',v_hotel.description),
    'travel',v_travel_quote,'travel_cost',v_travel,'travel_type','Round-trip estimate','staff_count',0,'staff_cost',0,'grand_total',v_total
  );
end;
$$;

create or replace function public.book_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star'::text)
returns jsonb
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_user uuid:=auth.uid(); v_player_id uuid; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype;
  v_quote jsonb; v_hotel_id uuid; v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_booking public.player_training_camp_bookings%rowtype; d record;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=v_user;
  if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into v_program from public.training_camp_programs where id=p_program_id and is_active;
  if v_program.id is null then raise exception 'Training camp program not found.'; end if;
  select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active;
  v_quote:=public.quote_training_camp_v2(p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug);
  v_start_abs:=(v_quote->>'start_absolute_day')::integer; v_end_abs:=(v_quote->>'end_absolute_day')::integer;
  v_hotel_id:=(v_quote->'accommodation'->>'id')::uuid;
  select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1();
  if v_start_abs<v_current_abs then raise exception 'Training camp cannot start in the past.'; end if;
  if exists(select 1 from public.player_training_camp_bookings b where b.player_id=v_player_id and b.status in ('booked','active') and int4range(b.start_absolute_day,b.end_absolute_day,'[]') && int4range(v_start_abs,v_end_abs,'[]')) then raise exception 'Another training camp overlaps the selected weeks.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_daily_activity a on a.player_id=v_player_id and a.season=gd.season and a.month=gd.month and a.day=gd.day where ((a.activity_type<>'home' and not (a.activity_type='travel' and a.source='travel_plan' and a.effects_applied_at is null)) or a.effects_applied_at is not null)) then raise exception 'The selected weeks contain travel, tournament, injury, another camp, or an already processed activity.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_training_sessions s on s.player_id=v_player_id and s.season=gd.season and s.month=gd.month and s.day=gd.day) then raise exception 'Regular training has already been processed during one of the selected weeks.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.tournament_editions te on te.season_number=gd.season join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id join public.tournament_applications ta on ta.competition_id=wc.id and ta.player_id=v_player_id where gd.season_week>0 and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')) then raise exception 'A tournament application or commitment overlaps the selected camp weeks.'; end if;
  select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);

  insert into public.player_training_camp_bookings(
    player_id,program_id,start_absolute_day,end_absolute_day,start_season,start_month,start_day,end_season,end_month,end_day,duration_weeks,weekly_cost,total_cost,status,start_season_week,accommodation_tier_id,
    training_fee_total,accommodation_weekly_cost,accommodation_total,travel_cost,staff_count,staff_travel_cost,staff_accommodation_cost,staff_total_cost,origin_city,origin_country_code,origin_continent,
    travel_distance_km,travel_round_trip_km,travel_band,travel_basis,travel_arrival_fatigue
  ) values(
    v_player_id,v_program.id,v_start_abs,v_end_abs,v_start.season,v_start.month,v_start.day,v_end.season,v_end.month,v_end.day,p_duration_weeks,v_program.weekly_cost,(v_quote->>'grand_total')::integer,'booked',p_start_week,v_hotel_id,
    (v_quote->>'training_fee_total')::integer,(v_quote->'accommodation'->>'weekly_cost')::integer,(v_quote->'accommodation'->>'total')::integer,(v_quote->>'travel_cost')::integer,0,0,0,0,
    nullif(v_quote->'origin'->>'raw_city',''),v_quote->'origin'->>'raw_country_code',v_quote->'origin'->>'continent',
    nullif(v_quote->'travel'->>'one_way_km','')::integer,nullif(v_quote->'travel'->>'round_trip_km','')::integer,v_quote->'travel'->>'band',v_quote->'travel'->>'basis',nullif(v_quote->'travel'->>'arrival_fatigue','')::smallint
  ) returning * into v_booking;

  for d in select gd.* from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd loop
    insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note)
    values(v_player_id,d.season,d.month,d.day,'training_camp','training_camp_booking',v_booking.id::text,v_program.name)
    on conflict(player_id,season,month,day) do update set activity_type='training_camp',source='training_camp_booking',reference_id=v_booking.id::text,note=v_program.name,updated_at=now();
  end loop;

  perform public.emit_notification_v1(v_user,v_player_id,'training.camp.booked','Training camp booked',format('%s in %s is booked for Season Week %s for %s week%s.',v_program.name,v_location.city,p_start_week,p_duration_weeks,case when p_duration_weeks=1 then '' else 's' end),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost),'training-camp-booked:'||v_booking.id::text);
  return jsonb_build_object('status','booked','booking_id',v_booking.id,'camp_name',v_program.name,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost,'quote',v_quote);
end;
$$;
