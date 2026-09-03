create or replace function public.negotiate_staff_offer_v1(
  p_staff_id uuid,
  p_duration_weeks smallint,
  p_salary_multiplier numeric default 1.00
) returns jsonb
language plpgsql security definer set search_path='public' as $$
declare
  v_player public.players%rowtype;
  s public.staff_members%rowtype;
  q jsonb;
  n public.staff_negotiations%rowtype;
  v_abs integer;
  v_round smallint;
  v_mult numeric;
  v_offer integer;
  v_base integer;
  v_chance smallint;
  v_roll numeric;
  v_result text;
  v_contract uuid;
  f public.player_career_finance_accounts%rowtype;
  v_fin_status text:='pending';
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select * into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into s from public.staff_members where id=p_staff_id for update;
  if s.id is null then raise exception 'Staff member not found.'; end if;

  q:=public.quote_staff_negotiation_v1(p_staff_id,p_duration_weeks,p_salary_multiplier);
  if not coalesce((q->>'available')::boolean,false) then
    raise exception '%',coalesce(q->>'reason','Negotiation unavailable.');
  end if;
  if coalesce((q->>'hard_refusal')::boolean,false) then
    raise exception '%',coalesce(q->>'explanation','This staff member will not negotiate at your current sporting reputation.');
  end if;

  if s.status<>'available' or s.current_player_id is not null then
    raise exception 'This staff member has just accepted another position.';
  end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  select * into n
  from public.staff_negotiations
  where player_id=v_player.id and staff_id=s.id and status='active'
  order by created_at desc
  limit 1
  for update;

  if n.id is null then
    insert into public.staff_negotiations(player_id,staff_id,status,round_count,started_absolute_day)
    values(v_player.id,s.id,'active',0,v_abs)
    returning * into n;
  end if;

  v_round:=n.round_count+1;
  if v_round>3 then raise exception 'This negotiation has already ended.'; end if;
  v_mult:=(q->>'salary_multiplier')::numeric;

  if v_round>1 then
    declare v_prev numeric;
    begin
      select salary_multiplier into v_prev
      from public.staff_negotiation_offers
      where negotiation_id=n.id
      order by round_number desc
      limit 1;
      if v_prev is not null and v_mult < least(2.00,v_prev+0.10) then
        raise exception 'A counter-offer must improve the previous salary offer by at least 10 percentage points.';
      end if;
    end;
  end if;

  v_base:=(q->>'base_contract_weekly_salary')::integer;
  v_offer:=(q->>'offered_weekly_salary')::integer;
  v_chance:=(q->>'acceptance_chance')::smallint;
  v_roll:=round((random()*100)::numeric,2);
  v_result:=case when v_chance>0 and v_roll<=v_chance then 'accepted' else 'rejected' end;

  insert into public.staff_negotiation_offers(
    negotiation_id,player_id,staff_id,round_number,duration_weeks,
    base_contract_weekly_salary,offered_weekly_salary,salary_multiplier,
    signing_fee,player_rank_position,acceptance_chance,acceptance_roll,result,game_absolute_day
  ) values(
    n.id,v_player.id,s.id,v_round,p_duration_weeks,
    v_base,v_offer,v_mult,s.signing_fee,(q->>'player_rank_position')::bigint,
    v_chance,v_roll,v_result,v_abs
  );

  if v_result='accepted' then
    insert into public.player_career_finance_accounts(player_id)
    values(v_player.id)
    on conflict(player_id) do nothing;
    select * into f from public.player_career_finance_accounts where player_id=v_player.id for update;

    if f.is_live then
      if f.balance is null or f.balance<s.signing_fee then
        raise exception 'The staff member accepted, but your career balance cannot cover the signing fee.';
      end if;
      update public.player_career_finance_accounts
      set balance=balance-s.signing_fee
      where player_id=v_player.id;
      v_fin_status:='posted';
    end if;

    insert into public.player_staff_contracts(
      player_id,staff_id,role,start_absolute_day,end_absolute_day,duration_weeks,
      weekly_salary,signing_fee,finance_status
    ) values(
      v_player.id,s.id,s.role,v_abs,v_abs+p_duration_weeks*7-1,p_duration_weeks,
      v_offer,s.signing_fee,v_fin_status
    ) returning id into v_contract;

    update public.staff_members
    set status='employed',current_player_id=v_player.id
    where id=s.id;

    update public.staff_negotiations
    set status='accepted',round_count=v_round,accepted_contract_id=v_contract,updated_at=now()
    where id=n.id;

    insert into public.staff_financial_events(
      player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at
    ) values(
      v_player.id,v_contract,'signing_fee',s.signing_fee,v_fin_status,v_abs,
      case when v_fin_status='posted' then now() else null end
    );

    return jsonb_build_object(
      'status','accepted','accepted',true,'contract_id',v_contract,'staff_id',s.id,
      'round_number',v_round,'acceptance_chance',v_chance,'roll',v_roll,
      'weekly_salary',v_offer,'salary_multiplier',v_mult,'signing_fee',s.signing_fee,
      'duration_weeks',p_duration_weeks,'finance_status',v_fin_status
    );
  end if;

  update public.staff_negotiations
  set round_count=v_round,
      status=case when v_round>=3 then 'failed' else 'active' end,
      cooldown_until_absolute_day=case when v_round>=3 then v_abs+14 else null end,
      updated_at=now()
  where id=n.id;

  return jsonb_build_object(
    'status','rejected','accepted',false,'staff_id',s.id,'round_number',v_round,
    'acceptance_chance',v_chance,'roll',v_roll,'salary_multiplier',v_mult,
    'offered_weekly_salary',v_offer,'remaining_rounds',greatest(0,3-v_round),
    'minimum_next_multiplier',case when v_round<3 then least(2.00,v_mult+0.10) else null end,
    'cooldown_until_absolute_day',case when v_round>=3 then v_abs+14 else null end
  );
end;
$$;