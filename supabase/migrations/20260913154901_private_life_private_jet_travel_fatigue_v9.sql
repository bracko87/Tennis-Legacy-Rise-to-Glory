update public.private_life_asset_catalog
set metadata = jsonb_set(coalesce(metadata,'{}'::jsonb), '{travel_fatigue_reduction_bps}', '9000'::jsonb, true),
    description = case
      when description ilike '%travel fatigue%' then description
      else rtrim(description, ' .') || '. Ownership reduces tournament travel fatigue by 90% while the jet is owned.'
    end,
    updated_at = now()
where category='private_jet' and active=true;

create or replace function public.private_life_private_jet_travel_benefit_v1(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public','pg_temp'
as $$
declare
  r record;
begin
  select o.id as owned_asset_id,
         c.code as catalog_code,
         c.name,
         c.tier,
         greatest(0,least(9500,coalesce((c.metadata->>'travel_fatigue_reduction_bps')::integer,9000))) as reduction_bps
  into r
  from public.private_life_player_assets o
  join public.private_life_asset_catalog c on c.code=o.catalog_code
  where o.player_id=p_player_id
    and o.sold_absolute_day is null
    and c.category='private_jet'
    and c.active=true
  order by greatest(0,least(9500,coalesce((c.metadata->>'travel_fatigue_reduction_bps')::integer,9000))) desc,
           c.tier desc,
           o.purchase_price desc,
           o.created_at
  limit 1;

  if r.owned_asset_id is null then
    return jsonb_build_object('active',false,'reduction_bps',0,'reduction_percent',0);
  end if;

  return jsonb_build_object(
    'active',true,
    'owned_asset_id',r.owned_asset_id,
    'catalog_code',r.catalog_code,
    'name',r.name,
    'tier',r.tier,
    'reduction_bps',r.reduction_bps,
    'reduction_percent',round(r.reduction_bps::numeric/100,0)
  );
end;
$$;
revoke all on function public.private_life_private_jet_travel_benefit_v1(uuid) from public,anon,authenticated;

create or replace function public.insert_planned_travel_leg_v1(
  p_player_id uuid, p_purpose text, p_source_type text, p_source_city text, p_source_country text,
  p_source_lat double precision, p_source_lon double precision, p_source_ref text,
  p_dest_type text, p_dest_city text, p_dest_country text, p_dest_lat double precision, p_dest_lon double precision,
  p_dest_ref text, p_departure integer, p_arrival integer, p_embedded boolean default false
)
returns uuid
language plpgsql
security definer
set search_path='public'
as $$
declare
  q jsonb; v_id uuid; gd record; v_existing text; v_class text:='Economy';
  v_jet jsonb; v_reduction integer:=0; v_base_gross integer; v_base_net integer; v_jet_gross integer; v_jet_net integer; v_jet_recovery integer;
  v_jet_applies boolean:=false;
begin
  if upper(coalesce(p_source_country,''))=upper(coalesce(p_dest_country,'')) and lower(trim(coalesce(p_source_city,'')))<>'' and lower(trim(coalesce(p_source_city,'')))=lower(trim(coalesce(p_dest_city,''))) then return null; end if;
  if p_dest_type='tournament' and coalesce(p_dest_ref,'')~*'^[0-9a-f-]{36}$' then
    select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_dest_ref::uuid;
  elsif p_source_type='tournament' and coalesce(p_source_ref,'')~*'^[0-9a-f-]{36}$' then
    select player_travel_class into v_class from public.player_tournament_preparation_plans where player_id=p_player_id and competition_id=p_source_ref::uuid;
  end if;
  v_class:=coalesce(v_class,'Economy');
  q:=public.quote_travel_v2(p_source_city,p_source_country,p_source_lat,p_source_lon,p_dest_city,p_dest_country,p_dest_lat,p_dest_lon,v_class,'one_way');

  v_jet_applies := coalesce(p_purpose,'') in ('tournament','return_home') or p_source_type='tournament' or p_dest_type='tournament';
  if v_jet_applies and coalesce(q->>'band','')<>'same_city' then
    v_jet:=public.private_life_private_jet_travel_benefit_v1(p_player_id);
    if coalesce((v_jet->>'active')::boolean,false) then
      v_reduction:=coalesce((v_jet->>'reduction_bps')::integer,9000);
      v_base_gross:=greatest(1,coalesce((q->>'gross_arrival_fatigue')::integer,1));
      v_base_net:=greatest(1,coalesce((q->>'arrival_fatigue')::integer,1));
      v_jet_gross:=greatest(1,round(v_base_gross::numeric*(10000-v_reduction)::numeric/10000)::integer);
      v_jet_net:=greatest(1,round(v_base_net::numeric*(10000-v_reduction)::numeric/10000)::integer);
      v_jet_recovery:=greatest(0,v_jet_gross-v_jet_net);
      q:=q||jsonb_build_object(
        'gross_arrival_fatigue',v_jet_gross,
        'travel_day_recovery',v_jet_recovery,
        'arrival_fatigue',v_jet_net,
        'private_jet',v_jet,
        'private_jet_baseline_gross_fatigue',v_base_gross,
        'private_jet_baseline_net_fatigue',v_base_net
      );
    end if;
  end if;

  insert into public.player_travel_legs(
    player_id,purpose,source_location_type,source_city,source_country_code,source_continent,source_latitude,source_longitude,
    destination_location_type,destination_city,destination_country_code,destination_continent,destination_latitude,destination_longitude,
    source_reference_id,destination_reference_id,departure_absolute_day,arrival_absolute_day,distance_km,estimated_cost,
    gross_arrival_fatigue,travel_day_recovery,arrival_fatigue,travel_band,travel_basis,embedded_transition,status,travel_class,
    base_estimated_cost,price_multiplier,base_arrival_fatigue,fatigue_multiplier
  ) values(
    p_player_id,p_purpose,p_source_type,p_source_city,p_source_country,public.country_continent_v1(p_source_country),p_source_lat,p_source_lon,
    p_dest_type,p_dest_city,p_dest_country,public.country_continent_v1(p_dest_country),p_dest_lat,p_dest_lon,p_source_ref,p_dest_ref,
    p_departure,p_arrival,nullif(q->>'distance_km','')::integer,(q->>'cost')::integer,
    (q->>'gross_arrival_fatigue')::smallint,(q->>'travel_day_recovery')::smallint,(q->>'arrival_fatigue')::smallint,
    q->>'band',q->>'basis',p_embedded,'planned',v_class,(q->>'base_cost_one_way')::integer,(q->>'price_multiplier')::numeric,
    (q->>'base_arrival_fatigue')::smallint,(q->>'fatigue_multiplier')::numeric
  ) returning id into v_id;

  if not p_embedded then
    select * into gd from public.absolute_game_day_v1(p_departure);
    select activity_type into v_existing from public.player_daily_activity where player_id=p_player_id and season=gd.season and month=gd.month and day=gd.day;
    if v_existing is null or v_existing='home' then
      insert into public.player_daily_activity(player_id,season,month,day,activity_type,source,reference_id,note)
      values(p_player_id,gd.season,gd.month,gd.day,'travel','travel_plan',v_id::text,
        format('Travel to %s%s',coalesce(p_dest_city,p_dest_country),case when coalesce((v_jet->>'active')::boolean,false) and v_jet_applies then ' · private jet' else '' end))
      on conflict(player_id,season,month,day) do update set activity_type='travel',source='travel_plan',reference_id=v_id::text,note=excluded.note,updated_at=now()
      where public.player_daily_activity.effects_applied_at is null and public.player_daily_activity.activity_type='home';
    else
      update public.player_travel_legs set embedded_transition=true,updated_at=now() where id=v_id;
    end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.process_travel_leg_v1(p_leg_id uuid)
returns jsonb
language plpgsql
security definer
set search_path='public'
as $$
declare
  l public.player_travel_legs%rowtype;
  v_before smallint; v_after smallint; gd record; v_owner uuid; v_finance jsonb:='{}'::jsonb; v_hotel jsonb:='{}'::jsonb;
  v_human boolean:=false; v_comp uuid;
  v_baseline_gross integer; v_baseline_net integer; v_gross integer; v_recovery integer; v_net integer;
  v_jet jsonb:=jsonb_build_object('active',false,'reduction_bps',0,'reduction_percent',0); v_reduction integer:=0; v_jet_applies boolean:=false;
begin
  select * into l from public.player_travel_legs where id=p_leg_id for update;
  if l.id is null then raise exception 'Travel leg not found.'; end if;
  if l.status='completed' then return jsonb_build_object('status','already_processed','travel_leg_id',l.id); end if;
  if l.status='cancelled' then return jsonb_build_object('status','cancelled','travel_leg_id',l.id); end if;

  select owner_user_id,(player_type='human' and owner_user_id is not null) into v_owner,v_human from public.players where id=l.player_id;
  if v_human and coalesce(l.estimated_cost,0)>0 and coalesce(l.purpose,'')<>'training_camp' and coalesce(l.source_location_type,'')<>'training_camp' then
    v_finance:=public.post_career_finance_transaction_v1(l.player_id,-l.estimated_cost,'travel',coalesce(l.purpose,'travel'),
      format('%s → %s · %s',coalesce(l.source_city,l.source_country_code),coalesce(l.destination_city,l.destination_country_code),coalesce(l.travel_class,'Economy')),
      'travel_leg',l.id::text,'travel-leg:'||l.id::text,
      jsonb_build_object('distance_km',l.distance_km,'travel_class',l.travel_class,'purpose',l.purpose,'source_city',l.source_city,'destination_city',l.destination_city),false,l.departure_absolute_day);
  end if;

  v_baseline_gross:=greatest(1,round(coalesce(l.base_arrival_fatigue,l.gross_arrival_fatigue,l.arrival_fatigue,1)::numeric*coalesce(l.fatigue_multiplier,1))::integer);
  v_baseline_net:=greatest(1,v_baseline_gross-3);
  v_gross:=v_baseline_gross;
  v_net:=v_baseline_net;
  v_recovery:=greatest(0,v_gross-v_net);

  v_jet_applies := coalesce(l.purpose,'') in ('tournament','return_home') or l.source_location_type='tournament' or l.destination_location_type='tournament';
  if v_jet_applies and coalesce(l.travel_band,'')<>'same_city' then
    v_jet:=public.private_life_private_jet_travel_benefit_v1(l.player_id);
    if coalesce((v_jet->>'active')::boolean,false) then
      v_reduction:=coalesce((v_jet->>'reduction_bps')::integer,9000);
      v_gross:=greatest(1,round(v_baseline_gross::numeric*(10000-v_reduction)::numeric/10000)::integer);
      v_net:=greatest(1,round(v_baseline_net::numeric*(10000-v_reduction)::numeric/10000)::integer);
      v_recovery:=greatest(0,v_gross-v_net);
    end if;
  end if;

  select fatigue into v_before from public.player_skills where player_id=l.player_id for update;
  v_after:=least(100,coalesce(v_before,0)+v_net)::smallint;
  update public.player_skills set fatigue=v_after,updated_at=now() where player_id=l.player_id;
  update public.player_location_state set current_city=l.destination_city,current_country_code=l.destination_country_code,current_continent=l.destination_continent,current_latitude=l.destination_latitude,current_longitude=l.destination_longitude,location_type=l.destination_location_type,source_reference_id=l.destination_reference_id,location_since_absolute_day=l.arrival_absolute_day,updated_at=now() where player_id=l.player_id;
  update public.player_travel_legs set gross_arrival_fatigue=v_gross::smallint,travel_day_recovery=v_recovery::smallint,arrival_fatigue=v_net::smallint,status='completed',processed_at=now(),updated_at=now() where id=l.id;

  select * into gd from public.absolute_game_day_v1(l.departure_absolute_day);
  update public.player_daily_activity set effects_applied_at=coalesce(effects_applied_at,now()),effect_summary=coalesce(effect_summary,'{}'::jsonb)||jsonb_build_object(
    'travel_leg_id',l.id,'from',jsonb_build_object('city',l.source_city,'country_code',l.source_country_code),'to',jsonb_build_object('city',l.destination_city,'country_code',l.destination_country_code),
    'distance_km',l.distance_km,'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'fatigue_before',v_before,'fatigue_after',v_after,'fatigue_change',v_after-v_before,
    'private_jet',v_jet,'baseline_net_travel_fatigue',v_baseline_net,'finance',v_finance),updated_at=now()
  where player_id=l.player_id and season=gd.season and month=gd.month and day=gd.day and source='travel_plan' and reference_id=l.id::text;

  if v_human and coalesce(l.destination_location_type,'')='tournament' and l.destination_reference_id is not null then
    begin
      v_comp:=l.destination_reference_id::uuid;
      v_hotel:=public.post_tournament_hotel_night_v1(l.player_id,v_comp,l.arrival_absolute_day);
    exception when invalid_text_representation then
      v_hotel:=jsonb_build_object('status','skipped','reason','invalid_tournament_reference');
    end;
  end if;

  perform public.emit_notification_v1(v_owner,l.player_id,'travel.arrived','Travel completed',
    case when coalesce((v_jet->>'active')::boolean,false) then
      format('You arrived in %s by private jet. Travel fatigue was reduced by %s%%: +%s fatigue instead of +%s.',coalesce(l.destination_city,l.destination_country_code),coalesce(v_jet->>'reduction_percent','90'),v_net,v_baseline_net)
    else
      format('You arrived in %s. Gross travel fatigue: +%s. Travel-day rest: -%s. Net fatigue: +%s.',coalesce(l.destination_city,l.destination_country_code),v_gross,v_recovery,v_net)
    end,
    '/game/schedule',jsonb_build_object('travel_leg_id',l.id,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'distance_km',l.distance_km,'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'fatigue_change',v_net,'baseline_net_travel_fatigue',v_baseline_net,'private_jet',v_jet,'finance',v_finance),'travel-arrived:'||l.id::text);

  return jsonb_build_object('status','completed','travel_leg_id',l.id,'distance_km',l.distance_km,'estimated_cost',l.estimated_cost,
    'gross_travel_fatigue',v_gross,'travel_day_recovery',v_recovery,'net_travel_fatigue',v_net,'baseline_net_travel_fatigue',v_baseline_net,
    'private_jet',v_jet,'fatigue_before',v_before,'fatigue_after',v_after,'destination_city',l.destination_city,'destination_country_code',l.destination_country_code,'finance',v_finance,'arrival_hotel',v_hotel);
end;
$$;