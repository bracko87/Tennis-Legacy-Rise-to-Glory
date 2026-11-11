-- Opt-in main-sponsor renewals: do not activate before the next season.
-- Existing season-specific contracts and current-year payment rules remain.
CREATE OR REPLACE FUNCTION public.create_player_sponsor_objectives_v1(p_contract_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  c public.player_sponsor_contracts%rowtype;
  o public.player_sponsor_offers%rowtype;
  item jsonb;
  v_count integer:=0;
  v_status text;
begin
  select * into c from public.player_sponsor_contracts where id=p_contract_id;
  if c.id is null then raise exception 'Sponsor contract not found.'; end if;

  select * into o from public.player_sponsor_offers where id=c.offer_id;
  if o.id is null then raise exception 'Sponsor offer not found.'; end if;

  if jsonb_array_length(coalesce(o.objective_plan,'[]'::jsonb))=0 then
    -- Accepted future-year renewals are intentionally unplanned until activation.
    -- Build the objectives for the new season, not the December offer date.
    declare v_plan jsonb;
    begin
      v_plan:=public.build_sponsor_objective_plan_v2(o.id);
      update public.player_sponsor_offers
      set performance_bonus_pool=coalesce((v_plan->>'bonus_pool')::bigint,0),
          objective_plan=coalesce(v_plan->'objectives','[]'::jsonb),
          objective_plan_version=2,updated_at=now()
      where id=o.id;
    end;
    select * into o from public.player_sponsor_offers where id=c.offer_id;
  end if;

  for item in select value from jsonb_array_elements(coalesce(o.objective_plan,'[]'::jsonb))
  loop
    v_status:=case
      when nullif(item->>'start_absolute_day','')::integer>c.start_absolute_day then 'upcoming'
      else 'active'
    end;

    insert into public.player_sponsor_objectives(
      contract_id,player_id,sponsor_company_id,season,
      objective_key,objective_code,title,description,
      target_value,current_value,reward_amount,status,
      competition_id,tournament_series_id,tournament_name,requirement_label,
      start_absolute_day,deadline_absolute_day,metadata
    ) values (
      c.id,c.player_id,c.sponsor_company_id,c.season,
      item->>'objective_key',item->>'objective_code',item->>'title',item->>'description',
      greatest(1,coalesce((item->>'target_value')::integer,1)),0,
      greatest(0,coalesce((item->>'reward_amount')::bigint,0)),v_status,
      nullif(item->>'competition_id','')::uuid,
      nullif(item->>'tournament_series_id','')::uuid,
      nullif(item->>'tournament_name',''),
      nullif(item->>'requirement_label',''),
      nullif(item->>'start_absolute_day','')::integer,
      coalesce(nullif(item->>'deadline_absolute_day','')::integer,c.end_absolute_day),
      (item - array[
        'objective_key','objective_code','title','description','target_value','reward_amount',
        'competition_id','tournament_series_id','tournament_name','requirement_label',
        'start_absolute_day','deadline_absolute_day'
      ]::text[])
    )
    on conflict(contract_id,objective_key) do nothing;
    v_count:=v_count+1;
  end loop;

  update public.player_sponsor_contracts
  set performance_bonus_pool=o.performance_bonus_pool,
      objective_plan_version=2,
      updated_at=now()
  where id=c.id;

  return jsonb_build_object(
    'status','ready',
    'created',v_count,
    'bonus_pool',o.performance_bonus_pool,
    'objective_plan_version',2
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_player_sponsor_offers_v1(p_player_id uuid, p_force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  gd record;
  v_abs integer;
  v_season_start integer;
  v_season_end integer;
  v_week_start integer;
  v_week_end integer;
  v_group_code text;
  v_rank integer;
  v_rule public.sponsor_offer_rules%rowtype;
  v_offer_count integer;
  v_progress numeric;
  v_local_share numeric;
  v_local_target integer;
  v_local_inserted integer:=0;
  v_world_target integer:=0;
  v_world_inserted integer:=0;
  v_value_progress numeric;
  v_base_full_value numeric;
  v_first_payment integer;
  v_payment_count integer;
  v_existing integer;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  if v_player.player_type<>'human' or v_player.owner_user_id is null then raise exception 'Sponsor offers are available to human players only.'; end if;
  if v_uid is not null and v_player.owner_user_id<>v_uid then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_season_start:=public.game_day_absolute_v1(gd.season,1::smallint,1::smallint);
  v_season_end:=public.game_day_absolute_v1(gd.season,12::smallint,31::smallint);
  v_week_start:=v_season_start + ((v_abs-v_season_start)/7)*7;
  v_week_end:=least(v_week_start+6,v_season_end);

  update public.player_sponsor_offers
  set status='expired',updated_at=now()
  where player_id=p_player_id and status='open' and expires_absolute_day<v_abs;

  if exists(select 1 from public.player_sponsor_contracts where player_id=p_player_id and season=gd.season and status='active') then
    return jsonb_build_object('status','active_contract','generated',0,'week_start_absolute_day',v_week_start);
  end if;

  select gm.group_code into v_group_code
  from public.sponsor_market_group_members gm
  where gm.country_code=v_player.country_code;
  if v_group_code is null then raise exception 'No sponsor market group is configured for player country %.',v_player.country_code; end if;

  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(p_player_id,gd.season),9999)::integer);
  select * into v_rule
  from public.sponsor_offer_rules r
  where r.is_active and v_rank>=r.rank_min and (r.rank_max is null or v_rank<=r.rank_max)
  order by r.rank_min desc limit 1;
  if v_rule.code is null then raise exception 'No sponsor offer rule for ranking %.',v_rank; end if;

  select count(*) into v_existing
  from public.player_sponsor_offers
  where player_id=p_player_id and season=gd.season and offer_week_start_absolute_day=v_week_start
    and is_renewal=false;
  if v_existing>0 and not p_force then
    return jsonb_build_object('status','already_generated','generated',v_existing,'week_start_absolute_day',v_week_start);
  end if;

  if p_force then
    delete from public.player_sponsor_offers o
    where o.player_id=p_player_id and o.season=gd.season and o.offer_week_start_absolute_day=v_week_start
      and o.status in ('open','declined','expired')
      and not exists(select 1 from public.player_sponsor_contracts c where c.offer_id=o.id);
  end if;

  v_offer_count:=v_rule.offer_count_min + floor(
    public.sponsor_hash_unit_v1(concat_ws(':','count',p_player_id::text,gd.season::text,v_week_start::text,v_rank::text))
    *(v_rule.offer_count_max-v_rule.offer_count_min+1)
  )::integer;
  v_offer_count:=least(v_rule.offer_count_max,greatest(v_rule.offer_count_min,v_offer_count));

  if v_rule.rank_max is null or v_rule.rank_max=v_rule.rank_min then
    v_progress:=case when v_rule.rank_max is null then least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/699::numeric)) else 0 end;
  else
    v_progress:=least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/(v_rule.rank_max-v_rule.rank_min)::numeric));
  end if;
  v_local_share:=v_rule.local_share_start + v_progress*(v_rule.local_share_end-v_rule.local_share_start);
  v_local_target:=least(v_offer_count,greatest(0,round(v_offer_count*v_local_share)::integer));
  v_value_progress:=v_progress;
  v_base_full_value:=v_rule.full_season_value_max - v_value_progress*(v_rule.full_season_value_max-v_rule.full_season_value_min);
  v_first_payment:=least(v_abs+6,v_season_end);
  v_payment_count:=floor((v_season_end-v_first_payment)::numeric/7)::integer+1;

  with candidates as (
    select s.id,
      row_number() over(order by public.sponsor_hash_unit_v1(concat_ws(':','local',p_player_id::text,gd.season::text,v_week_start::text,s.id::text)),s.id) rn
    from public.sponsor_companies s
    join public.sponsor_market_group_members gm on gm.country_code=s.country_code
    where s.sponsor_kind='main' and s.is_active and NOT s.is_worldwide and gm.group_code=v_group_code
  ), picked as (
    select id from candidates where rn<=v_local_target
  ), valued as (
    select p.id,
      greatest(v_rule.full_season_value_min,
        least(v_rule.full_season_value_max,
          round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(concat_ws(':','value',p_player_id::text,gd.season::text,v_week_start::text,p.id::text))))/100::numeric)*100
        )
      )::bigint full_value
    from picked p
  ), money as (
    select id,full_value,
      greatest(50::bigint,(round((full_value::numeric/52::numeric)/10::numeric)*10)::bigint) weekly_value
    from valued
  )
  insert into public.player_sponsor_offers(
    player_id,sponsor_company_id,season,offer_rule_code,offer_week_start_absolute_day,generated_absolute_day,
    expires_absolute_day,first_payment_absolute_day,player_rank,player_market_group_code,source_pool,
    full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value
  )
  select p_player_id,m.id,gd.season,v_rule.code,v_week_start,v_abs,v_week_end,v_first_payment,v_rank,v_group_code,'market',
    m.full_value,m.weekly_value,v_payment_count,m.weekly_value*v_payment_count
  from money m
  on conflict do nothing;
  get diagnostics v_local_inserted=row_count;

  v_world_target:=case when v_rank<=300 then greatest(0,v_offer_count-v_local_inserted) else 0 end;

  if v_world_target>0 then
    with candidates as (
      select s.id,
        row_number() over(order by public.sponsor_hash_unit_v1(concat_ws(':','worldwide',p_player_id::text,gd.season::text,v_week_start::text,s.id::text)),s.id) rn
      from public.sponsor_companies s
      where s.sponsor_kind='main' and s.is_active and s.is_worldwide
        and not exists(
          select 1 from public.player_sponsor_offers o
          where o.player_id=p_player_id and o.season=gd.season and o.offer_week_start_absolute_day=v_week_start and o.sponsor_company_id=s.id
        )
    ), picked as (
      select id from candidates where rn<=v_world_target
    ), valued as (
      select p.id,
        greatest(v_rule.full_season_value_min,
          least(v_rule.full_season_value_max,
            round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(concat_ws(':','value',p_player_id::text,gd.season::text,v_week_start::text,p.id::text))))/100::numeric)*100
          )
        )::bigint full_value
      from picked p
    ), money as (
      select id,full_value,
        greatest(50::bigint,(round((full_value::numeric/52::numeric)/10::numeric)*10)::bigint) weekly_value
      from valued
    )
    insert into public.player_sponsor_offers(
      player_id,sponsor_company_id,season,offer_rule_code,offer_week_start_absolute_day,generated_absolute_day,
      expires_absolute_day,first_payment_absolute_day,player_rank,player_market_group_code,source_pool,
      full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value
    )
    select p_player_id,m.id,gd.season,v_rule.code,v_week_start,v_abs,v_week_end,v_first_payment,v_rank,v_group_code,'worldwide',
      m.full_value,m.weekly_value,v_payment_count,m.weekly_value*v_payment_count
    from money m
    on conflict do nothing;
    get diagnostics v_world_inserted=row_count;
  end if;

  return jsonb_build_object(
    'status','generated','generated',v_local_inserted+v_world_inserted,'requested',v_offer_count,
    'local',v_local_inserted,'worldwide',v_world_inserted,'rank',v_rank,'market_group_code',v_group_code,
    'local_share',v_local_share,'week_start_absolute_day',v_week_start,'expires_absolute_day',v_week_end
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_player_sponsor_payments_v1(p_player_id uuid, p_through_absolute_day integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_owner uuid;
  gd record;
  v_through integer;
  c record;
  v_due integer;
  v_post jsonb;
  v_posted integer:=0;
  v_seen integer:=0;
begin
  select owner_user_id into v_owner from public.players where id=p_player_id and player_type='human';
  if v_owner is null then raise exception 'Human player not found.'; end if;
  if v_uid is not null and v_uid<>v_owner then raise exception 'Not authorized for this player.'; end if;
  select * into gd from public.get_current_game_day_internal_v1();
  v_through:=coalesce(p_through_absolute_day,public.game_day_absolute_v1(gd.season,gd.month,gd.day));
  -- Activate an accepted opt-in renewal on Jan 1, never before.
  perform public.activate_player_main_sponsor_renewal_v1(p_player_id,v_through);

  for c in
    select pc.*,sc.name sponsor_name
    from public.player_sponsor_contracts pc
    join public.sponsor_companies sc on sc.id=pc.sponsor_company_id
    where pc.player_id=p_player_id and pc.status='active' and pc.first_payment_absolute_day<=v_through
    order by pc.season,pc.signed_absolute_day
  loop
    for v_due in
      select generate_series(c.first_payment_absolute_day,least(c.end_absolute_day,v_through),7)
    loop
      v_post:=public.post_career_finance_transaction_v1(
        p_player_id,
        c.weekly_payment_amount,
        'sponsorship',
        'weekly_guaranteed_payment',
        format('%s weekly sponsor payment',c.sponsor_name),
        'sponsor_contract',
        c.id::text,
        format('sponsor-contract:%s:payment:%s',c.id,v_due),
        jsonb_build_object(
          'taxable',true,
          'sponsor_company_id',c.sponsor_company_id,
          'sponsor_name',c.sponsor_name,
          'contract_id',c.id,
          'contract_total_value',c.total_contract_value,
          'weekly_payment_amount',c.weekly_payment_amount
        ),
        false,
        v_due
      );
      v_seen:=v_seen+1;
      if v_post->>'status'='posted' then v_posted:=v_posted+1; end if;
    end loop;

    if v_through>=c.end_absolute_day then
      update public.player_sponsor_contracts set status='completed',updated_at=now() where id=c.id and status='active';
    end if;
  end loop;

  return jsonb_build_object('status','processed','through_absolute_day',v_through,'payments_checked',v_seen,'payments_posted',v_posted);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.refresh_player_sponsor_offer_plans_v2(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  x record;
  v_plan jsonb;
  v_count integer:=0;
begin
  for x in
    select id
    from public.player_sponsor_offers
    where player_id=p_player_id and status='open'
      and season<=(select season from public.game_clock where id=1)
    order by created_at,id
  loop
    v_plan:=public.build_sponsor_objective_plan_v2(x.id);
    update public.player_sponsor_offers
    set performance_bonus_pool=coalesce((v_plan->>'bonus_pool')::bigint,0),
        objective_plan=coalesce(v_plan->'objectives','[]'::jsonb),
        objective_plan_version=2,
        updated_at=now()
    where id=x.id;
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('status','ready','offers_updated',v_count);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reprice_player_sponsor_open_offers_v1(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player public.players%rowtype;
  gd record;
  v_abs integer;
  v_season_end integer;
  v_rank integer;
  v_rule public.sponsor_offer_rules%rowtype;
  v_progress numeric;
  v_base_full_value numeric;
  v_first_payment integer;
  v_payment_count integer;
  v_updated integer:=0;
begin
  select * into v_player from public.players where id=p_player_id;
  if v_player.id is null then raise exception 'Player not found.'; end if;
  if v_player.player_type<>'human' or v_player.owner_user_id is null then raise exception 'Sponsor offers are available to human players only.'; end if;
  if v_uid is not null and v_player.owner_user_id<>v_uid then raise exception 'Not authorized for this player.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);
  v_season_end:=public.game_day_absolute_v1(gd.season,12::smallint,31::smallint);
  v_rank:=greatest(1,coalesce(public.sponsor_offer_rank_v1(p_player_id,gd.season),9999)::integer);

  select * into v_rule
  from public.sponsor_offer_rules r
  where r.is_active and v_rank>=r.rank_min and (r.rank_max is null or v_rank<=r.rank_max)
  order by r.rank_min desc limit 1;
  if v_rule.code is null then raise exception 'No sponsor offer rule for ranking %.',v_rank; end if;

  if v_rule.rank_max is null or v_rule.rank_max=v_rule.rank_min then
    v_progress:=case when v_rule.rank_max is null
      then least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/699::numeric))
      else 0 end;
  else
    v_progress:=least(1::numeric,greatest(0::numeric,(v_rank-v_rule.rank_min)::numeric/(v_rule.rank_max-v_rule.rank_min)::numeric));
  end if;

  v_base_full_value:=v_rule.full_season_value_max - v_progress*(v_rule.full_season_value_max-v_rule.full_season_value_min);
  v_first_payment:=least(v_abs+6,v_season_end);
  v_payment_count:=floor((v_season_end-v_first_payment)::numeric/7)::integer+1;

  with priced as (
    select o.id,
      greatest(v_rule.full_season_value_min,
        least(v_rule.full_season_value_max,
          round((v_base_full_value*(0.85 + 0.30*public.sponsor_hash_unit_v1(
            concat_ws(':','value',p_player_id::text,gd.season::text,o.offer_week_start_absolute_day::text,o.sponsor_company_id::text)
          )))/100::numeric)*100
        )
      )::bigint as full_value
    from public.player_sponsor_offers o
    where o.player_id=p_player_id
      and o.season=gd.season
      and o.is_renewal=false
      and o.status='open'
      and o.expires_absolute_day>=v_abs
  ), money as (
    select id,full_value,
      greatest(50::bigint,(round((full_value::numeric/52::numeric)/10::numeric)*10)::bigint) as weekly_value
    from priced
  )
  update public.player_sponsor_offers o
  set offer_rule_code=v_rule.code,
      player_rank=v_rank,
      first_payment_absolute_day=v_first_payment,
      full_season_value=m.full_value,
      weekly_payment_amount=m.weekly_value,
      scheduled_payment_count=v_payment_count,
      total_contract_value=m.weekly_value*v_payment_count,
      updated_at=now()
  from money m
  where o.id=m.id;

  get diagnostics v_updated=row_count;
  return jsonb_build_object('status','repriced','updated',v_updated,'player_rank',v_rank,'offer_rule_code',v_rule.code,'first_payment_absolute_day',v_first_payment);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sign_player_sponsor_offer_v1(p_offer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid:=auth.uid();
  v_player uuid;
  v_offer public.player_sponsor_offers%rowtype;
  v_contract public.player_sponsor_contracts%rowtype;
  gd record;
  v_abs integer;
begin
  if v_uid is null then raise exception 'Authentication required.'; end if;

  select id into v_player
  from public.players
  where owner_user_id=v_uid and player_type='human';

  if v_player is null then raise exception 'Player not found.'; end if;

  select * into gd from public.get_current_game_day_internal_v1();
  v_abs:=public.game_day_absolute_v1(gd.season,gd.month,gd.day);

  perform public.reprice_player_sponsor_open_offers_v1(v_player);
  perform public.refresh_player_sponsor_offer_plans_v2(v_player);

  select * into v_offer
  from public.player_sponsor_offers
  where id=p_offer_id and player_id=v_player
  for update;

  if v_offer.id is null then raise exception 'Sponsor offer not found.'; end if;
  if v_offer.status<>'open' then raise exception 'This sponsor offer is no longer open.'; end if;

  if v_offer.expires_absolute_day<v_abs then
    update public.player_sponsor_offers set status='expired',updated_at=now() where id=v_offer.id;
    raise exception 'This sponsor offer has expired.';
  end if;

  IF v_offer.season=gd.season+1 AND v_offer.is_renewal THEN
    IF gd.month<>12 OR gd.day<>31
      OR v_offer.renewal_previous_contract_id IS NULL
      OR NOT EXISTS(SELECT 1 FROM public.player_sponsor_contracts c
        WHERE c.id=v_offer.renewal_previous_contract_id
          AND c.player_id=v_player AND c.season=gd.season
          AND c.status IN('active','completed'))
    THEN RAISE EXCEPTION 'Next-season renewal is not eligible yet'; END IF;
    IF EXISTS(SELECT 1 FROM public.player_sponsor_contracts c
      WHERE c.player_id=v_player AND c.season=v_offer.season)
    THEN RAISE EXCEPTION 'A next-season main sponsorship is already signed'; END IF;
    INSERT INTO public.player_sponsor_renewal_reservations_v1(
      player_id,target_season,offer_id,accepted_absolute_day)
    VALUES(v_player,v_offer.season,v_offer.id,v_abs);
    UPDATE public.player_sponsor_offers
      SET status='accepted',updated_at=now() WHERE id=v_offer.id;
    UPDATE public.player_sponsor_offers
      SET status='expired',updated_at=now()
      WHERE player_id=v_player AND season=v_offer.season
        AND status='open' AND id<>v_offer.id;
    RETURN jsonb_build_object('status','scheduled','offer_id',v_offer.id,
      'target_season',v_offer.season,'starts_on_absolute_day',
      public.game_day_absolute_v1(v_offer.season,1::smallint,1::smallint));
  END IF;
  IF v_offer.season<>gd.season THEN
    RAISE EXCEPTION 'This sponsor offer belongs to another season'; END IF;

  if exists(
    select 1 from public.player_sponsor_contracts
    where player_id=v_player and season=gd.season
  ) then
    raise exception 'A main sponsor agreement already exists for this season.';
  end if;

  insert into public.player_sponsor_contracts(
    player_id,sponsor_company_id,offer_id,season,
    signed_absolute_day,start_absolute_day,first_payment_absolute_day,end_absolute_day,
    player_rank_at_sign,player_market_group_code,source_pool,
    full_season_value,weekly_payment_amount,scheduled_payment_count,total_contract_value,
    performance_bonus_pool,objective_plan_version,status
  ) values (
    v_player,v_offer.sponsor_company_id,v_offer.id,v_offer.season,
    v_abs,v_abs,v_offer.first_payment_absolute_day,
    public.game_day_absolute_v1(v_offer.season,12::smallint,31::smallint),
    v_offer.player_rank,v_offer.player_market_group_code,v_offer.source_pool,
    v_offer.full_season_value,v_offer.weekly_payment_amount,v_offer.scheduled_payment_count,v_offer.total_contract_value,
    v_offer.performance_bonus_pool,2,'active'
  )
  returning * into v_contract;

  update public.player_sponsor_offers set status='accepted',updated_at=now() where id=v_offer.id;
  update public.player_sponsor_offers
  set status='expired',updated_at=now()
  where player_id=v_player and season=v_offer.season and status='open' and id<>v_offer.id;

  perform public.process_player_sponsor_payments_v1(v_player,v_abs);

  return jsonb_build_object(
    'status','signed',
    'contract_id',v_contract.id,
    'sponsor_company_id',v_contract.sponsor_company_id,
    'player_rank_at_sign',v_contract.player_rank_at_sign,
    'weekly_payment_amount',v_contract.weekly_payment_amount,
    'total_contract_value',v_contract.total_contract_value,
    'performance_bonus_pool',v_contract.performance_bonus_pool,
    'end_absolute_day',v_contract.end_absolute_day
  );
end;
$function$
;

