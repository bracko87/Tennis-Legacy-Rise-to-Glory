create or replace function public.post_tournament_hotel_night_v1(
  p_player_id uuid,
  p_competition_id uuid,
  p_absolute_day integer
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_plan public.player_tournament_preparation_plans%rowtype;
  v_city text; v_country text; v_tier text:='Standard'; v_staff_count integer:=0; v_party integer:=1;
  v_base integer; v_label text; q jsonb; v_total integer;
begin
  if not exists(select 1 from public.players where id=p_player_id and player_type='human' and owner_user_id is not null) then return jsonb_build_object('status','skipped','reason','not_human_player'); end if;
  select * into v_plan from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_competition_id;
  if found then v_tier:=v_plan.hotel_tier; v_staff_count:=coalesce(cardinality(v_plan.selected_staff_contract_ids),0); end if;
  v_party:=1+v_staff_count;
  select ts.city,ts.country_code into v_city,v_country from public.tournament_world_competitions wc join public.tournament_editions te on te.id=wc.tournament_edition_id join public.tournament_series ts on ts.id=te.tournament_series_id where wc.id=p_competition_id;
  if v_city is null then return jsonb_build_object('status','skipped','reason','tournament_not_found'); end if;
  select base_nightly_cost,label into v_base,v_label from public.travel_stay_tiers where tier_name=v_tier;
  q:=public.quote_accommodation_v1(v_city,v_country,v_base,1,v_party,'night'); v_total:=(q->>'total')::integer;
  return public.post_career_finance_transaction_v1(p_player_id,-v_total,'hotel','tournament_hotel',format('%s — %s (%s traveller%s)',v_label,v_city,v_party,case when v_party=1 then '' else 's' end),'tournament',p_competition_id::text,format('tournament-hotel:%s:%s',p_competition_id,p_absolute_day),jsonb_build_object('competition_id',p_competition_id,'city',v_city,'country_code',v_country,'hotel_tier',v_tier,'party_size',v_party,'quote',q),false,p_absolute_day);
end; $$;
revoke all on function public.post_tournament_hotel_night_v1(uuid,uuid,integer) from public,anon,authenticated;

create or replace function public.process_tournament_hotel_day_v1(p_player_id uuid,p_absolute_day integer)
returns jsonb language plpgsql security definer set search_path=public as $$
declare c record; v_result jsonb:='{}'::jsonb;
begin
  if not exists(select 1 from public.players where id=p_player_id and player_type='human' and owner_user_id is not null) then return jsonb_build_object('status','skipped'); end if;
  select * into c from public.player_commitment_locations_v1(p_player_id) where commitment_type='tournament' and p_absolute_day between start_absolute_day and end_absolute_day order by start_absolute_day limit 1;
  if c.reference_id is null then return jsonb_build_object('status','no_tournament'); end if;
  v_result:=public.post_tournament_hotel_night_v1(p_player_id,c.reference_id::uuid,p_absolute_day);
  return v_result;
end; $$;
revoke all on function public.process_tournament_hotel_day_v1(uuid,integer) from public,anon,authenticated;

create or replace function public.process_travel_leg_v1(p_leg_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare l public.player_travel_legs%rowtype; v_before smallint; v_after smallint; gd record; v_owner uuid; v_finance jsonb:='{}'::jsonb; v_hotel jsonb:='{}'::jsonb; v_human boolean:=false; v_comp uuid;
begin
  select * into l from public.player_travel_legs where id=p_leg_id for update;
  if l.id is null then raise exception 'Travel leg not found.'; end if;
  if l.status='completed' then return jsonb_build_object('status','already_processed','travel_leg_id',l.id); end if;
  if l.status='cancelled' then return jsonb_build_object('status','cancelled','travel_leg_id',l.id); end if;
  select owner_user_id,(player_type='human' and owner_user_id is not null) into v_owner,v_human from public.players where id=l.player_id;
  if v_human and coalesce(l.estimated_cost,0)>0 and coalesce(l.purpose,'')<>'training_camp' and coalesce(l.source_location_type,'')<>'training_camp' then
    v_finance:=public.post_career_finance_transaction_v1(l.player_id,-l.estimated_cost,'travel',coalesce(l.purpose,'travel'),format('%s → %s · %s',coalesce(l.source_city,l.source_country_code),coalesce(l.destination_city,l.destination_country_code),coalesce(l.travel_class,'Economy')),'travel_leg',l.id::text,'travel-leg:'||l.id::text,jsonb_build_object('distance_km',l.distance_km,'travel_class',l.travel_class,'purpose',l.purpose,'source_city',l.source_city,'destination_city',l.destination_city),false,l.departure_absolute_day);
  end if;
  select fatigue into v_before from public.player_skills where player_id=l.player_id for update;
  v_after:=least(100,coalesce(v_before,0)+l.arrival_fatigue)::smallint;
  update public.player_skills set fatigue=v_after,updated_at=now() where player_id=l.player_id;
  update public.player_location_state set current_city=l.destination_city,current_country_code=l.destination_country_code,current_continent=l.destination_continent,current_latitude=l.destination_latitude,current_longitude=l.destination_longitude,location_type=l.destination_location_type,source_reference_id=l.destination_reference_id,location_since_absolute_day=l.arrival_absolute_day,updated_at=now() where player_id=l.player_id;
  update public.player_travel_legs set status='completed',processed_at=now(),updated_at=now() where id=l.id;
  select * into gd from public.absolute_game_day_v1(l.departure_absolute_day);
  update public.player_daily_activity set effects_applied_at=coalesce(effects_applied_at,now()),effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object('travel_leg_id',l.id,'from',jsonb_build_object('city',l.source_city,'country_code',l.source_country_code),'to',jsonb_build_object('city',l.destination_city,'country_code',l.destination_country_code),'distance_km',l.distance_km,'fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before,'finance',v_finance),updated_at=now() where player_id=l.player_id and season=gd.season and month=gd.month and day=gd.day and source='travel_plan' and reference_id=l.id::text;
  if v_human and coalesce(l.destination_location_type,'')='tournament' and l.destination_reference_id is not null then begin v_comp:=l.destination_reference_id::uuid; v_hotel:=public.post_tournament_hotel_night_v1(l.player_id,v_comp,l.arrival_absolute_day); exception when invalid_text_representation then v_hotel:=jsonb_build_object('status','skipped','reason','invalid_tournament_reference'); end; end if;
  perform public.emit_notification_v1(v_owner,l.player_id,'travel.arrived','Travel completed',format('You arrived in %s. Travel fatigue: +%s.',coalesce(l.destination_city,l.destination_country_code),l.arrival_fatigue),'/game/schedule',jsonb_build_object('travel_leg_id',l.id,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'distance_km',l.distance_km,'fatigue_change',l.arrival_fatigue,'finance',v_finance),'travel-arrived:'||l.id::text);
  return jsonb_build_object('status','completed','travel_leg_id',l.id,'distance_km',l.distance_km,'estimated_cost',l.estimated_cost,'fatigue_before',v_before,'fatigue_after',v_after,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'finance',v_finance,'arrival_hotel',v_hotel);
end; $$;

create or replace function public.process_player_daily_activity_v1(p_player_id uuid,p_season integer,p_month smallint,p_day smallint,p_processed_by text default 'daily_engine')
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_activity text; v_row public.player_daily_activity%rowtype; v_abs integer; v_travel jsonb; v_hotel jsonb;
begin
  v_abs:=public.game_day_absolute_v1(p_season,p_month,p_day); v_travel:=public.process_due_travel_legs_v1(p_player_id,v_abs); v_hotel:=public.process_tournament_hotel_day_v1(p_player_id,v_abs);
  select * into v_row from public.player_daily_activity where player_id=p_player_id and season=p_season and month=p_month and day=p_day for update; v_activity:=coalesce(v_row.activity_type,'home');
  if v_activity='home' then return public.process_regular_training_for_player_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('travel_processing',v_travel,'hotel_processing',v_hotel); end if;
  if v_activity='travel' then return jsonb_build_object('status','completed','activity_type','travel','travel_processing',v_travel,'hotel_processing',v_hotel,'effect_summary',v_row.effect_summary); end if;
  if v_activity='training_camp' then return public.process_training_camp_day_v1(p_player_id,p_season,p_month,p_day,p_processed_by)||jsonb_build_object('travel_processing',v_travel,'hotel_processing',v_hotel); end if;
  return jsonb_build_object('status','delegated','activity_type',v_activity,'travel_processing',v_travel,'hotel_processing',v_hotel,'reason',case v_activity when 'tournament' then 'Tournament/match engine owns this day; regular training is blocked.' when 'injured' then 'Injury/recovery engine owns this day; regular training is blocked.' else 'Regular training is blocked.' end);
end; $$;

-- Training-camp booking now posts prepaid package costs to the central ledger.
create or replace function public.book_training_camp_v2(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star')
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_player_id uuid; v_program public.training_camp_programs%rowtype; v_location public.training_camp_locations%rowtype; v_quote jsonb; v_hotel_id uuid; v_start_abs integer; v_end_abs integer; v_current_abs integer; v_start record; v_end record; v_booking public.player_training_camp_bookings%rowtype; d record; v_fin jsonb;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;
  select id into v_player_id from public.players where owner_user_id=v_user; if v_player_id is null then raise exception 'Player not found.'; end if;
  select * into v_program from public.training_camp_programs where id=p_program_id and is_active; if v_program.id is null then raise exception 'Training camp program not found.'; end if;
  select * into v_location from public.training_camp_locations where id=v_program.location_id and is_active;
  v_quote:=public.quote_training_camp_v2(p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug); v_start_abs:=(v_quote->>'start_absolute_day')::integer; v_end_abs:=(v_quote->>'end_absolute_day')::integer; v_hotel_id:=(v_quote->'accommodation'->>'id')::uuid;
  select public.game_day_absolute_v1(season,month,day) into v_current_abs from public.get_current_game_day_internal_v1();
  if v_start_abs<v_current_abs then raise exception 'Training camp cannot start in the past.'; end if;
  if exists(select 1 from public.player_training_camp_bookings b where b.player_id=v_player_id and b.status in ('booked','active') and int4range(b.start_absolute_day,b.end_absolute_day,'[]') && int4range(v_start_abs,v_end_abs,'[]')) then raise exception 'Another training camp overlaps the selected weeks.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_daily_activity a on a.player_id=v_player_id and a.season=gd.season and a.month=gd.month and a.day=gd.day where ((a.activity_type<>'home' and not (a.activity_type='travel' and a.source='travel_plan' and a.effects_applied_at is null)) or a.effects_applied_at is not null)) then raise exception 'The selected weeks contain travel, tournament, injury, another camp, or an already processed activity.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.player_training_sessions s on s.player_id=v_player_id and s.season=gd.season and s.month=gd.month and s.day=gd.day) then raise exception 'Regular training has already been processed during one of the selected weeks.'; end if;
  if exists(select 1 from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd join public.tournament_editions te on te.season_number=gd.season join public.tournament_schedule_slots ss on ss.tournament_edition_id=te.id and ss.season_week=gd.season_week join public.tournament_world_competitions wc on wc.tournament_edition_id=te.id join public.tournament_applications ta on ta.competition_id=wc.id and ta.player_id=v_player_id where gd.season_week>0 and lower(coalesce(ta.status,'')) not in ('withdrawn','declined','rejected','cancelled')) then raise exception 'A tournament application or commitment overlaps the selected camp weeks.'; end if;
  select * into v_start from public.absolute_game_day_v1(v_start_abs); select * into v_end from public.absolute_game_day_v1(v_end_abs);
  insert into public.player_training_camp_bookings(player_id,program_id,start_absolute_day,end_absolute_day,start_season,start_month,start_day,end_season,end_month,end_day,duration_weeks,weekly_cost,total_cost,status,start_season_week,accommodation_tier_id,training_fee_total,accommodation_weekly_cost,accommodation_total,travel_cost,staff_count,staff_travel_cost,staff_accommodation_cost,staff_total_cost,origin_city,origin_country_code,origin_continent,travel_distance_km,travel_round_trip_km,travel_band,travel_basis,travel_arrival_fatigue)
  values(v_player_id,v_program.id,v_start_abs,v_end_abs,v_start.season,v_start.month,v_start.day,v_end.season,v_end.month,v_end.day,p_duration_weeks,v_program.weekly_cost,(v_quote->>'grand_total')::integer,'booked',p_start_week,v_hotel_id,(v_quote->>'training_fee_total')::integer,(v_quote->'accommodation'->>'weekly_cost')::integer,(v_quote->'accommodation'->>'total')::integer,(v_quote->>'travel_cost')::integer,0,0,0,0,nullif(v_quote->'origin'->>'raw_city',''),v_quote->'origin'->>'raw_country_code',v_quote->'origin'->>'continent',nullif(v_quote->'travel'->>'one_way_km','')::integer,nullif(v_quote->'travel'->>'round_trip_km','')::integer,v_quote->'travel'->>'band',v_quote->'travel'->>'basis',nullif(v_quote->'travel'->>'arrival_fatigue','')::smallint) returning * into v_booking;
  v_fin:=public.post_career_finance_transaction_v1(v_player_id,-v_booking.total_cost,'training','training_camp',format('%s — %s',v_program.name,v_location.city),'training_camp_booking',v_booking.id::text,'training-camp-base:'||v_booking.id::text,jsonb_build_object('program_id',v_program.id,'city',v_location.city,'duration_weeks',p_duration_weeks,'quote',v_quote),true,v_current_abs);
  for d in select gd.* from generate_series(v_start_abs,v_end_abs) g(abs_day) cross join lateral public.absolute_game_day_v1(g.abs_day) gd loop insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note) values(v_player_id,d.season,d.month,d.day,'training_camp','training_camp_booking',v_booking.id::text,v_program.name) on conflict(player_id,season,month,day) do update set activity_type='training_camp',source='training_camp_booking',reference_id=v_booking.id::text,note=v_program.name,updated_at=now(); end loop;
  perform public.emit_notification_v1(v_user,v_player_id,'training.camp.booked','Training camp booked',format('%s in %s is booked for Season Week %s for %s week%s.',v_program.name,v_location.city,p_start_week,p_duration_weeks,case when p_duration_weeks=1 then '' else 's' end),'/game/training',jsonb_build_object('booking_id',v_booking.id,'program_id',v_program.id,'camp_name',v_program.name,'city',v_location.city,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost,'finance',v_fin),'training-camp-booked:'||v_booking.id::text);
  return jsonb_build_object('status','booked','booking_id',v_booking.id,'camp_name',v_program.name,'start_week',p_start_week,'duration_weeks',p_duration_weeks,'total_cost',v_booking.total_cost,'quote',v_quote,'finance',v_fin);
end; $$;

create or replace function public.book_training_camp_v3(p_program_id uuid,p_start_season integer,p_start_week smallint,p_duration_weeks smallint,p_accommodation_slug text default 'standard-3-star',p_staff_contract_ids uuid[] default '{}'::uuid[])
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_quote jsonb; v_base jsonb; v_booking uuid; v_player uuid; r record; v_extra integer; v_fin jsonb:='{}'::jsonb; v_abs integer;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if; select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  v_quote:=public.quote_training_camp_v3(p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug,p_staff_contract_ids); v_base:=public.book_training_camp_v2(p_program_id,p_start_season,p_start_week,p_duration_weeks,p_accommodation_slug); v_booking:=(v_base->>'booking_id')::uuid; v_extra:=(v_quote->>'grand_total')::integer-(v_base->>'total_cost')::integer; select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  if v_extra>0 then v_fin:=public.post_career_finance_transaction_v1(v_player,-v_extra,'training','training_camp_staff','Travelling staff — training camp','training_camp_booking',v_booking::text,'training-camp-staff:'||v_booking::text,jsonb_build_object('staff_contract_ids',to_jsonb(coalesce(p_staff_contract_ids,'{}'::uuid[])),'extra_cost',v_extra),true,v_abs); end if;
  update public.player_training_camp_bookings set staff_count=(v_quote->>'staff_count')::smallint,staff_travel_cost=(v_quote->>'staff_travel_cost')::integer,staff_accommodation_cost=(v_quote->>'staff_accommodation_cost')::integer,staff_total_cost=(v_quote->>'staff_cost')::integer,total_cost=(v_quote->>'grand_total')::integer,updated_at=now() where id=v_booking and player_id=v_player;
  for r in select c.id contract_id,c.staff_id,c.role from unnest(coalesce(p_staff_contract_ids,'{}'::uuid[])) x join public.player_staff_contracts c on c.id=x where c.player_id=v_player and c.status='active' loop insert into public.player_training_camp_staff(booking_id,contract_id,staff_id,role,travel_cost,accommodation_cost,total_cost) values(v_booking,r.contract_id,r.staff_id,r.role,(v_quote->'travel'->>'cost')::integer,(v_quote->'accommodation'->>'total')::integer,(v_quote->'travel'->>'cost')::integer+(v_quote->'accommodation'->>'total')::integer); end loop;
  return v_base || jsonb_build_object('total_cost',(v_quote->>'grand_total')::integer,'quote',v_quote,'staff_finance',v_fin);
end; $$;

create or replace function public.process_staff_weekly_salary_events_v1()
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_abs integer; c record; v_due integer; v_created integer:=0; v_posted integer:=0; v_fin jsonb;
begin
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  for c in select pc.id contract_id,pc.player_id,pc.start_absolute_day,pc.end_absolute_day,pc.weekly_salary,s.first_name,s.last_name from public.player_staff_contracts pc join public.staff_members s on s.id=pc.staff_id where pc.status in ('active','expired') and pc.start_absolute_day<=v_abs loop
    v_due:=c.start_absolute_day+6;
    while v_due<=least(v_abs,c.end_absolute_day) loop
      if not exists(select 1 from public.staff_financial_events e where e.contract_id=c.contract_id and e.event_type='weekly_salary' and e.game_absolute_day=v_due) then
        v_fin:=public.post_career_finance_transaction_v1(c.player_id,-c.weekly_salary,'staff','weekly_salary',format('%s %s — weekly salary',c.first_name,c.last_name),'staff_contract',c.contract_id::text,format('staff-salary:%s:%s',c.contract_id,v_due),jsonb_build_object('contract_id',c.contract_id),false,v_due);
        insert into public.staff_financial_events(player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at) values(c.player_id,c.contract_id,'weekly_salary',c.weekly_salary,'posted',v_due,now()) on conflict do nothing; v_created:=v_created+1; v_posted:=v_posted+1;
      end if; v_due:=v_due+7;
    end loop;
  end loop;
  return jsonb_build_object('status','processed','current_absolute_day',v_abs,'salary_events_created',v_created,'posted',v_posted,'pending',0);
end; $$;

create or replace function public.terminate_staff_contract_v1(p_contract_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player uuid; c public.player_staff_contracts%rowtype; s public.staff_members%rowtype; v_abs integer; v_weeks integer; v_fee integer; v_fin jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if; select id into v_player from public.players where owner_user_id=auth.uid() and player_type='human'; if v_player is null then raise exception 'Player not found.'; end if;
  select * into c from public.player_staff_contracts where id=p_contract_id and player_id=v_player for update; if c.id is null or c.status<>'active' then raise exception 'Active contract not found.'; end if; select * into s from public.staff_members where id=c.staff_id; select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d; v_weeks:=least(4,greatest(1,ceil((c.end_absolute_day-v_abs+1)::numeric/7)::integer)); v_fee:=c.weekly_salary*v_weeks;
  v_fin:=public.post_career_finance_transaction_v1(v_player,-v_fee,'staff','termination_fee',format('%s %s — contract termination',s.first_name,s.last_name),'staff_contract',c.id::text,'staff-termination:'||c.id::text,jsonb_build_object('weeks',v_weeks),false,v_abs);
  update public.player_staff_contracts set status='terminated',terminated_at=now(),finance_status='posted' where id=c.id; update public.staff_members set status='available',current_player_id=null where id=c.staff_id; insert into public.staff_financial_events(player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at) values(v_player,c.id,'termination_fee',v_fee,'posted',v_abs,now());
  return jsonb_build_object('status','terminated','contract_id',c.id,'termination_fee',v_fee,'finance_status','posted','finance',v_fin);
end; $$;

create or replace function public.negotiate_staff_offer_v1(p_staff_id uuid,p_duration_weeks smallint,p_salary_multiplier numeric default 1.00)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_player public.players%rowtype; s public.staff_members%rowtype; q jsonb; n public.staff_negotiations%rowtype; v_abs integer; v_round smallint; v_mult numeric; v_offer integer; v_base integer; v_chance smallint; v_roll numeric; v_result text; v_contract uuid; v_fin jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if; select * into v_player from public.players where owner_user_id=auth.uid() and player_type='human'; if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into s from public.staff_members where id=p_staff_id for update; if s.id is null then raise exception 'Staff member not found.'; end if; q:=public.quote_staff_negotiation_v1(p_staff_id,p_duration_weeks,p_salary_multiplier); if not coalesce((q->>'available')::boolean,false) then raise exception '%',coalesce(q->>'reason','Negotiation unavailable.'); end if; if coalesce((q->>'hard_refusal')::boolean,false) then raise exception '%',coalesce(q->>'explanation','This staff member will not negotiate at your current sporting reputation.'); end if; if s.status<>'available' or s.current_player_id is not null then raise exception 'This staff member has just accepted another position.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d; select * into n from public.staff_negotiations where player_id=v_player.id and staff_id=s.id and status='active' order by created_at desc limit 1 for update; if n.id is null then insert into public.staff_negotiations(player_id,staff_id,status,round_count,started_absolute_day) values(v_player.id,s.id,'active',0,v_abs) returning * into n; end if; v_round:=n.round_count+1; if v_round>3 then raise exception 'This negotiation has already ended.'; end if; v_mult:=(q->>'salary_multiplier')::numeric;
  if v_round>1 then declare v_prev numeric; begin select salary_multiplier into v_prev from public.staff_negotiation_offers where negotiation_id=n.id order by round_number desc limit 1; if v_prev is not null and v_mult<least(2.00,v_prev+0.10) then raise exception 'A counter-offer must improve the previous salary offer by at least 10 percentage points.'; end if; end; end if;
  v_base:=(q->>'base_contract_weekly_salary')::integer; v_offer:=(q->>'offered_weekly_salary')::integer; v_chance:=(q->>'acceptance_chance')::smallint; v_roll:=round((random()*100)::numeric,2); v_result:=case when v_chance>0 and v_roll<=v_chance then 'accepted' else 'rejected' end;
  insert into public.staff_negotiation_offers(negotiation_id,player_id,staff_id,round_number,duration_weeks,base_contract_weekly_salary,offered_weekly_salary,salary_multiplier,signing_fee,player_rank_position,acceptance_chance,acceptance_roll,result,game_absolute_day) values(n.id,v_player.id,s.id,v_round,p_duration_weeks,v_base,v_offer,v_mult,s.signing_fee,(q->>'player_rank_position')::bigint,v_chance,v_roll,v_result,v_abs);
  if v_result='accepted' then
    insert into public.player_staff_contracts(player_id,staff_id,role,start_absolute_day,end_absolute_day,duration_weeks,weekly_salary,signing_fee,finance_status) values(v_player.id,s.id,s.role,v_abs,v_abs+p_duration_weeks*7-1,p_duration_weeks,v_offer,s.signing_fee,'posted') returning id into v_contract;
    v_fin:=public.post_career_finance_transaction_v1(v_player.id,-s.signing_fee,'staff','signing_fee',format('%s %s — signing fee',s.first_name,s.last_name),'staff_contract',v_contract::text,'staff-signing:'||v_contract::text,jsonb_build_object('staff_id',s.id,'duration_weeks',p_duration_weeks,'weekly_salary',v_offer),true,v_abs);
    update public.staff_members set status='employed',current_player_id=v_player.id where id=s.id; update public.staff_negotiations set status='accepted',round_count=v_round,accepted_contract_id=v_contract,updated_at=now() where id=n.id; insert into public.staff_financial_events(player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at) values(v_player.id,v_contract,'signing_fee',s.signing_fee,'posted',v_abs,now());
    return jsonb_build_object('status','accepted','accepted',true,'contract_id',v_contract,'staff_id',s.id,'round_number',v_round,'acceptance_chance',v_chance,'roll',v_roll,'weekly_salary',v_offer,'salary_multiplier',v_mult,'signing_fee',s.signing_fee,'duration_weeks',p_duration_weeks,'finance_status','posted','finance',v_fin);
  end if;
  update public.staff_negotiations set round_count=v_round,status=case when v_round>=3 then 'failed' else 'active' end,cooldown_until_absolute_day=case when v_round>=3 then v_abs+14 else null end,updated_at=now() where id=n.id;
  return jsonb_build_object('status','rejected','accepted',false,'staff_id',s.id,'round_number',v_round,'acceptance_chance',v_chance,'roll',v_roll,'salary_multiplier',v_mult,'offered_weekly_salary',v_offer,'remaining_rounds',greatest(0,3-v_round),'minimum_next_multiplier',case when v_round<3 then least(2.00,v_mult+0.10) else null end,'cooldown_until_absolute_day',case when v_round>=3 then v_abs+14 else null end);
end; $$;