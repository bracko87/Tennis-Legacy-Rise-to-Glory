-- Rebalance staff weekly salaries to the intended weekly scale.
update public.staff_members
set base_weekly_salary = greatest(100, (round(base_weekly_salary::numeric / 40.0) * 10)::integer),
    updated_at = now();

-- Keep already-active contracts aligned with the new weekly scale.
update public.player_staff_contracts
set weekly_salary = greatest(100, (round(weekly_salary::numeric / 40.0) * 10)::integer)
where status = 'active';

-- Future market replenishment still uses the original generator scale, so normalize
-- new staff rows at insert time as well.
create or replace function public.normalize_new_staff_weekly_salary_v2()
returns trigger
language plpgsql
set search_path = 'public', 'pg_temp'
as $$
begin
  new.base_weekly_salary := greatest(100, (round(new.base_weekly_salary::numeric / 40.0) * 10)::integer);
  return new;
end;
$$;

revoke all on function public.normalize_new_staff_weekly_salary_v2() from public, anon, authenticated;

drop trigger if exists staff_members_weekly_salary_scale_v2 on public.staff_members;
create trigger staff_members_weekly_salary_scale_v2
before insert on public.staff_members
for each row execute function public.normalize_new_staff_weekly_salary_v2();

-- Negotiation quote now also exposes a previously accepted offer that is waiting
-- for explicit user confirmation. No contract is created until confirmation.
create or replace function public.quote_staff_negotiation_v1(
  p_staff_id uuid,
  p_duration_weeks smallint,
  p_salary_multiplier numeric default 1.00
)
returns jsonb
language plpgsql
stable security definer
set search_path = 'public'
as $$
declare
  v_player public.players%rowtype;
  s public.staff_members%rowtype;
  v_rank bigint;
  v_abs integer;
  v_base integer;
  v_offer integer;
  v_mult numeric:=round(greatest(1.00,least(2.00,coalesce(p_salary_multiplier,1.00)))::numeric,2);
  v_chance smallint;
  n public.staff_negotiations%rowtype;
  o public.staff_negotiation_offers%rowtype;
  v_last_mult numeric;
  v_min_mult numeric:=1.00;
  v_round smallint:=1;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_duration_weeks not in (13,26,52) then raise exception 'Contract duration must be 13, 26 or 52 weeks.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into s from public.staff_members where id=p_staff_id;
  if s.id is null then raise exception 'Staff member not found.'; end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  select * into n
  from public.staff_negotiations
  where player_id=v_player.id and staff_id=s.id
  order by created_at desc
  limit 1;

  if n.id is not null and n.status='accepted' and n.accepted_contract_id is null then
    select * into o
    from public.staff_negotiation_offers
    where negotiation_id=n.id and result='accepted'
    order by round_number desc
    limit 1;

    if o.id is not null then
      return jsonb_build_object(
        'available',false,
        'pending_confirmation',true,
        'reason','Your offer was accepted. Review and confirm the contract.',
        'negotiation_id',n.id,
        'staff_id',s.id,
        'quality_tier',s.quality_tier,
        'overall_rating',s.overall_rating,
        'player_rank_position',o.player_rank_position,
        'duration_weeks',o.duration_weeks,
        'round_number',o.round_number,
        'max_rounds',3,
        'base_contract_weekly_salary',o.base_contract_weekly_salary,
        'salary_multiplier',o.salary_multiplier,
        'offered_weekly_salary',o.offered_weekly_salary,
        'signing_fee',o.signing_fee,
        'salary_total',o.offered_weekly_salary * o.duration_weeks,
        'total_commitment',o.signing_fee + o.offered_weekly_salary * o.duration_weeks,
        'acceptance_chance',o.acceptance_chance,
        'chance_label','Accepted',
        'hard_refusal',false,
        'explanation','The staff member accepted these terms. The contract starts only after you confirm.'
      );
    end if;
  end if;

  if s.status<>'available' or s.current_player_id is not null then
    raise exception 'This staff member is no longer available.';
  end if;

  if exists(
    select 1 from public.player_staff_contracts
    where player_id=v_player.id and role=s.role and status='active'
  ) then
    raise exception 'You already employ a staff member in this role.';
  end if;

  if n.id is not null and n.status='failed' and coalesce(n.cooldown_until_absolute_day,0)>v_abs then
    return jsonb_build_object(
      'available',false,
      'reason','Negotiations ended after three rejected offers.',
      'cooldown_until_absolute_day',n.cooldown_until_absolute_day,
      'cooldown_days_remaining',n.cooldown_until_absolute_day-v_abs,
      'chance',0,
      'chance_label','No chance'
    );
  end if;

  if n.id is not null and n.status='active' then
    v_round:=n.round_count+1;
    select salary_multiplier into v_last_mult
    from public.staff_negotiation_offers
    where negotiation_id=n.id
    order by round_number desc
    limit 1;
    if v_last_mult is not null then
      v_min_mult:=least(2.00,round((v_last_mult+0.10)::numeric,2));
    end if;
  end if;

  v_rank:=public.player_current_rank_position_v1(v_player.id);
  v_base:=public.staff_contract_base_salary_v1(s.base_weekly_salary,p_duration_weeks);
  v_offer:=round((v_base*v_mult)/10.0)*10;
  v_chance:=public.staff_acceptance_chance_v1(s.quality_tier,s.overall_rating,v_rank,v_mult,p_duration_weeks);

  return jsonb_build_object(
    'available',true,
    'pending_confirmation',false,
    'staff_id',s.id,
    'quality_tier',s.quality_tier,
    'overall_rating',s.overall_rating,
    'player_rank_position',v_rank,
    'duration_weeks',p_duration_weeks,
    'round_number',v_round,
    'max_rounds',3,
    'base_contract_weekly_salary',v_base,
    'salary_multiplier',v_mult,
    'offered_weekly_salary',v_offer,
    'minimum_next_multiplier',v_min_mult,
    'signing_fee',s.signing_fee,
    'salary_total',v_offer*p_duration_weeks,
    'total_commitment',s.signing_fee+v_offer*p_duration_weeks,
    'acceptance_chance',v_chance,
    'chance_label',public.staff_chance_label_v1(v_chance),
    'hard_refusal',v_chance=0,
    'explanation',case
      when v_chance=0 and s.quality_tier='world_class' and v_rank>500 then 'World Class staff will not negotiate with players ranked outside the Top 500, regardless of salary.'
      when v_chance=0 and s.quality_tier='elite' and v_rank>1500 then 'Elite staff will not negotiate with players ranked outside the Top 1500.'
      else 'Ranking reflects sporting reputation; salary and contract length can improve the offer.'
    end
  );
end;
$$;

-- An accepted negotiation no longer creates a contract immediately. It records the
-- accepted offer and waits for explicit confirmation from the game-designed dialog.
create or replace function public.negotiate_staff_offer_v1(
  p_staff_id uuid,
  p_duration_weeks smallint,
  p_salary_multiplier numeric default 1.00
)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
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
  v_offer_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into s from public.staff_members where id=p_staff_id for update;
  if s.id is null then raise exception 'Staff member not found.'; end if;

  q:=public.quote_staff_negotiation_v1(p_staff_id,p_duration_weeks,p_salary_multiplier);
  if coalesce((q->>'pending_confirmation')::boolean,false) then
    raise exception 'This staff member already accepted your offer. Confirm or dismiss the pending contract first.';
  end if;
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
      if v_prev is not null and v_mult<least(2.00,v_prev+0.10) then
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
  ) returning id into v_offer_id;

  if v_result='accepted' then
    update public.staff_negotiations
    set status='accepted',round_count=v_round,updated_at=now()
    where id=n.id;

    return jsonb_build_object(
      'status','accepted_pending_confirmation',
      'accepted',true,
      'pending_confirmation',true,
      'negotiation_id',n.id,
      'offer_id',v_offer_id,
      'staff_id',s.id,
      'round_number',v_round,
      'acceptance_chance',v_chance,
      'roll',v_roll,
      'offered_weekly_salary',v_offer,
      'weekly_salary',v_offer,
      'salary_multiplier',v_mult,
      'signing_fee',s.signing_fee,
      'duration_weeks',p_duration_weeks,
      'salary_total',v_offer*p_duration_weeks,
      'total_commitment',s.signing_fee+v_offer*p_duration_weeks
    );
  end if;

  update public.staff_negotiations
  set round_count=v_round,
      status=case when v_round>=3 then 'failed' else 'active' end,
      cooldown_until_absolute_day=case when v_round>=3 then v_abs+14 else null end,
      updated_at=now()
  where id=n.id;

  return jsonb_build_object(
    'status','rejected',
    'accepted',false,
    'pending_confirmation',false,
    'negotiation_id',n.id,
    'staff_id',s.id,
    'round_number',v_round,
    'acceptance_chance',v_chance,
    'roll',v_roll,
    'salary_multiplier',v_mult,
    'offered_weekly_salary',v_offer,
    'remaining_rounds',greatest(0,3-v_round),
    'minimum_next_multiplier',case when v_round<3 then least(2.00,v_mult+0.10) else null end,
    'cooldown_until_absolute_day',case when v_round>=3 then v_abs+14 else null end
  );
end;
$$;

create or replace function public.confirm_staff_offer_v1(p_negotiation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_player public.players%rowtype;
  n public.staff_negotiations%rowtype;
  o public.staff_negotiation_offers%rowtype;
  s public.staff_members%rowtype;
  v_abs integer;
  v_contract uuid;
  v_fin jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;

  select * into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;

  select * into n
  from public.staff_negotiations
  where id=p_negotiation_id and player_id=v_player.id
  for update;
  if n.id is null then raise exception 'Accepted staff offer not found.'; end if;

  if n.accepted_contract_id is not null then
    return jsonb_build_object('status','already_confirmed','contract_id',n.accepted_contract_id);
  end if;
  if n.status<>'accepted' then raise exception 'This negotiation is not waiting for contract confirmation.'; end if;

  select * into o
  from public.staff_negotiation_offers
  where negotiation_id=n.id and result='accepted'
  order by round_number desc
  limit 1;
  if o.id is null then raise exception 'Accepted offer terms not found.'; end if;

  select * into s from public.staff_members where id=n.staff_id for update;
  if s.id is null then raise exception 'Staff member not found.'; end if;
  if s.status<>'available' or s.current_player_id is not null then
    raise exception 'This staff member is no longer available.';
  end if;
  if exists(
    select 1 from public.player_staff_contracts
    where player_id=v_player.id and role=s.role and status='active'
  ) then
    raise exception 'You already employ a staff member in this role.';
  end if;

  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  insert into public.player_staff_contracts(
    player_id,staff_id,role,start_absolute_day,end_absolute_day,duration_weeks,
    weekly_salary,signing_fee,finance_status
  ) values(
    v_player.id,s.id,s.role,v_abs,v_abs+o.duration_weeks*7-1,o.duration_weeks,
    o.offered_weekly_salary,o.signing_fee,'posted'
  ) returning id into v_contract;

  v_fin:=public.post_career_finance_transaction_v1(
    v_player.id,
    -o.signing_fee,
    'staff',
    'signing_fee',
    format('%s %s — signing fee',s.first_name,s.last_name),
    'staff_contract',
    v_contract::text,
    'staff-signing:'||v_contract::text,
    jsonb_build_object(
      'staff_id',s.id,
      'negotiation_id',n.id,
      'duration_weeks',o.duration_weeks,
      'weekly_salary',o.offered_weekly_salary,
      'salary_total',o.offered_weekly_salary*o.duration_weeks,
      'total_commitment',o.signing_fee+o.offered_weekly_salary*o.duration_weeks
    ),
    true,
    v_abs
  );

  update public.staff_members
  set status='employed',current_player_id=v_player.id
  where id=s.id;

  update public.staff_negotiations
  set accepted_contract_id=v_contract,updated_at=now()
  where id=n.id;

  insert into public.staff_financial_events(
    player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at
  ) values(
    v_player.id,v_contract,'signing_fee',o.signing_fee,'posted',v_abs,now()
  );

  return jsonb_build_object(
    'status','confirmed',
    'contract_id',v_contract,
    'staff_id',s.id,
    'weekly_salary',o.offered_weekly_salary,
    'signing_fee',o.signing_fee,
    'duration_weeks',o.duration_weeks,
    'salary_total',o.offered_weekly_salary*o.duration_weeks,
    'total_commitment',o.signing_fee+o.offered_weekly_salary*o.duration_weeks,
    'finance',v_fin
  );
end;
$$;

create or replace function public.quote_staff_termination_v1(p_contract_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_player uuid;
  c public.player_staff_contracts%rowtype;
  s public.staff_members%rowtype;
  v_abs integer;
  v_weeks integer;
  v_remaining bigint;
  v_fee bigint;
  v_balance bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;

  select * into c
  from public.player_staff_contracts
  where id=p_contract_id and player_id=v_player;
  if c.id is null or c.status<>'active' then raise exception 'Active contract not found.'; end if;

  select * into s from public.staff_members where id=c.staff_id;
  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  select count(*)::integer
  into v_weeks
  from generate_series(c.start_absolute_day+6,c.end_absolute_day,7) due(day)
  where due.day>=v_abs
    and not exists(
      select 1 from public.staff_financial_events e
      where e.contract_id=c.id and e.event_type='weekly_salary' and e.game_absolute_day=due.day
    );

  v_remaining:=c.weekly_salary*coalesce(v_weeks,0);
  v_fee:=round(v_remaining::numeric*0.65)::bigint;
  select balance into v_balance from public.player_career_finance_accounts where player_id=v_player;

  return jsonb_build_object(
    'contract_id',c.id,
    'staff_id',c.staff_id,
    'staff_name',format('%s %s',s.first_name,s.last_name),
    'weekly_salary',c.weekly_salary,
    'remaining_weeks',coalesce(v_weeks,0),
    'remaining_salary',v_remaining,
    'termination_rate',65,
    'termination_fee',v_fee,
    'balance',v_balance
  );
end;
$$;

create or replace function public.terminate_staff_contract_v1(p_contract_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public', 'pg_temp'
as $$
declare
  v_player uuid;
  c public.player_staff_contracts%rowtype;
  s public.staff_members%rowtype;
  v_abs integer;
  v_weeks integer;
  v_remaining bigint;
  v_fee bigint;
  v_fin jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  select id into v_player
  from public.players
  where owner_user_id=auth.uid() and player_type='human';
  if v_player is null then raise exception 'Player not found.'; end if;

  select * into c
  from public.player_staff_contracts
  where id=p_contract_id and player_id=v_player
  for update;
  if c.id is null or c.status<>'active' then raise exception 'Active contract not found.'; end if;

  select * into s from public.staff_members where id=c.staff_id;
  select public.game_day_absolute_v1(d.season,d.month,d.day)
  into v_abs
  from public.get_current_game_day_internal_v1() d;

  select count(*)::integer
  into v_weeks
  from generate_series(c.start_absolute_day+6,c.end_absolute_day,7) due(day)
  where due.day>=v_abs
    and not exists(
      select 1 from public.staff_financial_events e
      where e.contract_id=c.id and e.event_type='weekly_salary' and e.game_absolute_day=due.day
    );

  v_remaining:=c.weekly_salary*coalesce(v_weeks,0);
  v_fee:=round(v_remaining::numeric*0.65)::bigint;

  if v_fee>0 then
    v_fin:=public.post_career_finance_transaction_v1(
      v_player,
      -v_fee,
      'staff',
      'termination_fee',
      format('%s %s — contract termination',s.first_name,s.last_name),
      'staff_contract',
      c.id::text,
      'staff-termination:'||c.id::text,
      jsonb_build_object(
        'remaining_weeks',coalesce(v_weeks,0),
        'weekly_salary',c.weekly_salary,
        'remaining_salary',v_remaining,
        'termination_rate',65
      ),
      false,
      v_abs
    );
  else
    v_fin:=jsonb_build_object('status','no_fee','amount',0);
  end if;

  update public.player_staff_contracts
  set status='terminated',terminated_at=now(),finance_status='posted'
  where id=c.id;

  update public.staff_members
  set status='available',current_player_id=null
  where id=c.staff_id;

  insert into public.staff_financial_events(
    player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at
  ) values(
    v_player,c.id,'termination_fee',v_fee,'posted',v_abs,now()
  );

  return jsonb_build_object(
    'status','terminated',
    'contract_id',c.id,
    'remaining_weeks',coalesce(v_weeks,0),
    'weekly_salary',c.weekly_salary,
    'remaining_salary',v_remaining,
    'termination_rate',65,
    'termination_fee',v_fee,
    'finance_status','posted',
    'finance',v_fin
  );
end;
$$;

revoke all on function public.confirm_staff_offer_v1(uuid) from public, anon;
grant execute on function public.confirm_staff_offer_v1(uuid) to authenticated;
revoke all on function public.quote_staff_termination_v1(uuid) from public, anon;
grant execute on function public.quote_staff_termination_v1(uuid) to authenticated;
