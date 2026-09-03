create table if not exists public.staff_negotiations (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  staff_id uuid not null references public.staff_members(id) on delete cascade,
  status text not null default 'active' check (status in ('active','accepted','failed','cancelled')),
  round_count smallint not null default 0 check (round_count between 0 and 3),
  started_absolute_day integer not null,
  cooldown_until_absolute_day integer,
  accepted_contract_id uuid references public.player_staff_contracts(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_negotiation_offers (
  id uuid primary key default gen_random_uuid(),
  negotiation_id uuid not null references public.staff_negotiations(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  staff_id uuid not null references public.staff_members(id) on delete cascade,
  round_number smallint not null check (round_number between 1 and 3),
  duration_weeks smallint not null check (duration_weeks in (13,26,52)),
  base_contract_weekly_salary integer not null check (base_contract_weekly_salary >= 0),
  offered_weekly_salary integer not null check (offered_weekly_salary >= 0),
  salary_multiplier numeric(5,2) not null check (salary_multiplier between 1.00 and 2.00),
  signing_fee integer not null check (signing_fee >= 0),
  player_rank_position bigint,
  acceptance_chance smallint not null check (acceptance_chance between 0 and 95),
  acceptance_roll numeric(6,2),
  result text not null check (result in ('accepted','rejected')),
  game_absolute_day integer not null,
  created_at timestamptz not null default now(),
  unique(negotiation_id, round_number)
);

create index if not exists idx_staff_negotiations_player_staff on public.staff_negotiations(player_id,staff_id,created_at desc);
create index if not exists idx_staff_negotiation_offers_negotiation on public.staff_negotiation_offers(negotiation_id,round_number desc);

alter table public.staff_negotiations enable row level security;
alter table public.staff_negotiation_offers enable row level security;
revoke all on public.staff_negotiations from anon, authenticated;
revoke all on public.staff_negotiation_offers from anon, authenticated;
grant select on public.staff_negotiations to authenticated;
grant select on public.staff_negotiation_offers to authenticated;

create policy staff_negotiations_owner_select on public.staff_negotiations
for select to authenticated using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));
create policy staff_negotiation_offers_owner_select on public.staff_negotiation_offers
for select to authenticated using (exists(select 1 from public.players p where p.id=player_id and p.owner_user_id=auth.uid()));

create or replace function public.staff_contract_base_salary_v1(p_base integer,p_duration smallint)
returns integer language sql immutable as $$
  select greatest(100,round((p_base * case p_duration when 13 then 1.00 when 26 then 0.93 else 0.86 end)/10.0)*10)::integer;
$$;

create or replace function public.staff_acceptance_chance_v1(
  p_quality text,
  p_rating smallint,
  p_rank bigint,
  p_salary_multiplier numeric,
  p_duration smallint
) returns smallint
language plpgsql immutable as $$
declare
  r bigint := coalesce(p_rank,999999);
  base numeric := 0;
  money_bonus numeric;
  duration_bonus numeric;
  rating_penalty numeric := 0;
begin
  if p_quality='world_class' then
    if r>500 then return 0; end if;
    base:=case when r<=10 then 82 when r<=25 then 75 when r<=50 then 65 when r<=100 then 48 when r<=150 then 35 when r<=250 then 20 when r<=400 then 8 else 3 end;
    rating_penalty:=greatest(0,p_rating-95)*0.8;
  elsif p_quality='elite' then
    if r>1500 then return 0; end if;
    base:=case when r<=25 then 86 when r<=50 then 80 when r<=100 then 70 when r<=200 then 58 when r<=400 then 42 when r<=700 then 28 when r<=1000 then 15 else 5 end;
    rating_penalty:=greatest(0,p_rating-85)*0.35;
  elsif p_quality='advanced' then
    base:=case when r<=100 then 85 when r<=300 then 75 when r<=600 then 65 when r<=1000 then 52 when r<=2000 then 40 else 30 end;
    rating_penalty:=greatest(0,p_rating-70)*0.25;
  elsif p_quality='professional' then
    base:=case when r<=500 then 90 when r<=1000 then 84 when r<=2000 then 76 else 68 end;
    rating_penalty:=greatest(0,p_rating-55)*0.15;
  else
    base:=92;
    rating_penalty:=greatest(0,p_rating-40)*0.10;
  end if;

  money_bonus:=greatest(0,p_salary_multiplier-1)*45;
  duration_bonus:=case p_duration when 13 then -4 when 26 then 0 else 5 end;
  return greatest(0,least(95,round(base-rating_penalty+money_bonus+duration_bonus)))::smallint;
end;
$$;

create or replace function public.staff_chance_label_v1(p_chance integer)
returns text language sql immutable as $$
 select case when p_chance=0 then 'No chance' when p_chance<20 then 'Very unlikely' when p_chance<40 then 'Unlikely' when p_chance<60 then 'Possible' when p_chance<80 then 'Good chance' else 'Strong chance' end;
$$;

create or replace function public.quote_staff_negotiation_v1(
  p_staff_id uuid,
  p_duration_weeks smallint,
  p_salary_multiplier numeric default 1.00
) returns jsonb
language plpgsql stable security definer set search_path='public' as $$
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
  v_last_mult numeric;
  v_min_mult numeric:=1.00;
  v_round smallint:=1;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if p_duration_weeks not in (13,26,52) then raise exception 'Contract duration must be 13, 26 or 52 weeks.'; end if;
  select * into v_player from public.players where owner_user_id=auth.uid() and player_type='human';
  if v_player.id is null then raise exception 'Player not found.'; end if;
  select * into s from public.staff_members where id=p_staff_id;
  if s.id is null then raise exception 'Staff member not found.'; end if;
  if s.status<>'available' or s.current_player_id is not null then raise exception 'This staff member is no longer available.'; end if;
  if exists(select 1 from public.player_staff_contracts where player_id=v_player.id and role=s.role and status='active') then raise exception 'You already employ a staff member in this role.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  select * into n from public.staff_negotiations where player_id=v_player.id and staff_id=s.id order by created_at desc limit 1;
  if n.id is not null and n.status='failed' and coalesce(n.cooldown_until_absolute_day,0)>v_abs then
    return jsonb_build_object('available',false,'reason','Negotiations ended after three rejected offers.','cooldown_until_absolute_day',n.cooldown_until_absolute_day,'cooldown_days_remaining',n.cooldown_until_absolute_day-v_abs,'chance',0,'chance_label','No chance');
  end if;
  if n.id is not null and n.status='active' then
    v_round:=n.round_count+1;
    select salary_multiplier into v_last_mult from public.staff_negotiation_offers where negotiation_id=n.id order by round_number desc limit 1;
    if v_last_mult is not null then v_min_mult:=least(2.00,round((v_last_mult+0.10)::numeric,2)); end if;
  end if;
  v_rank:=public.player_current_rank_position_v1(v_player.id);
  v_base:=public.staff_contract_base_salary_v1(s.base_weekly_salary,p_duration_weeks);
  v_offer:=round((v_base*v_mult)/10.0)*10;
  v_chance:=public.staff_acceptance_chance_v1(s.quality_tier,s.overall_rating,v_rank,v_mult,p_duration_weeks);
  return jsonb_build_object(
    'available',true,'staff_id',s.id,'quality_tier',s.quality_tier,'overall_rating',s.overall_rating,
    'player_rank_position',v_rank,'duration_weeks',p_duration_weeks,'round_number',v_round,'max_rounds',3,
    'base_contract_weekly_salary',v_base,'salary_multiplier',v_mult,'offered_weekly_salary',v_offer,
    'minimum_next_multiplier',v_min_mult,'signing_fee',s.signing_fee,'acceptance_chance',v_chance,
    'chance_label',public.staff_chance_label_v1(v_chance),'hard_refusal',v_chance=0,
    'explanation',case when v_chance=0 and s.quality_tier='world_class' and v_rank>500 then 'World Class staff will not negotiate with players ranked outside the Top 500, regardless of salary.' when v_chance=0 and s.quality_tier='elite' and v_rank>1500 then 'Elite staff will not negotiate with players ranked outside the Top 1500.' else 'Ranking reflects sporting reputation; salary and contract length can improve the offer.' end
  );
end;
$$;

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
  if not coalesce((q->>'available')::boolean,false) then raise exception '%',coalesce(q->>'reason','Negotiation unavailable.'); end if;
  if s.status<>'available' or s.current_player_id is not null then raise exception 'This staff member has just accepted another position.'; end if;
  select public.game_day_absolute_v1(d.season,d.month,d.day) into v_abs from public.get_current_game_day_internal_v1() d;
  select * into n from public.staff_negotiations where player_id=v_player.id and staff_id=s.id and status='active' order by created_at desc limit 1 for update;
  if n.id is null then insert into public.staff_negotiations(player_id,staff_id,status,round_count,started_absolute_day) values(v_player.id,s.id,'active',0,v_abs) returning * into n; end if;
  v_round:=n.round_count+1;
  if v_round>3 then raise exception 'This negotiation has already ended.'; end if;
  v_mult:=(q->>'salary_multiplier')::numeric;
  if v_round>1 then
    declare v_prev numeric; begin
      select salary_multiplier into v_prev from public.staff_negotiation_offers where negotiation_id=n.id order by round_number desc limit 1;
      if v_prev is not null and v_mult < least(2.00,v_prev+0.10) then raise exception 'A counter-offer must improve the previous salary offer by at least 10 percentage points.'; end if;
    end;
  end if;
  v_base:=(q->>'base_contract_weekly_salary')::integer;
  v_offer:=(q->>'offered_weekly_salary')::integer;
  v_chance:=(q->>'acceptance_chance')::smallint;
  v_roll:=round((random()*100)::numeric,2);
  v_result:=case when v_chance>0 and v_roll<=v_chance then 'accepted' else 'rejected' end;

  insert into public.staff_negotiation_offers(negotiation_id,player_id,staff_id,round_number,duration_weeks,base_contract_weekly_salary,offered_weekly_salary,salary_multiplier,signing_fee,player_rank_position,acceptance_chance,acceptance_roll,result,game_absolute_day)
  values(n.id,v_player.id,s.id,v_round,p_duration_weeks,v_base,v_offer,v_mult,s.signing_fee,(q->>'player_rank_position')::bigint,v_chance,v_roll,v_result,v_abs);

  if v_result='accepted' then
    insert into public.player_career_finance_accounts(player_id) values(v_player.id) on conflict(player_id) do nothing;
    select * into f from public.player_career_finance_accounts where player_id=v_player.id for update;
    if f.is_live then
      if f.balance is null or f.balance<s.signing_fee then raise exception 'The staff member accepted, but your career balance cannot cover the signing fee.'; end if;
      update public.player_career_finance_accounts set balance=balance-s.signing_fee where player_id=v_player.id;
      v_fin_status:='posted';
    end if;
    insert into public.player_staff_contracts(player_id,staff_id,role,start_absolute_day,end_absolute_day,duration_weeks,weekly_salary,signing_fee,finance_status)
    values(v_player.id,s.id,s.role,v_abs,v_abs+p_duration_weeks*7-1,p_duration_weeks,v_offer,s.signing_fee,v_fin_status) returning id into v_contract;
    update public.staff_members set status='employed',current_player_id=v_player.id where id=s.id;
    update public.staff_negotiations set status='accepted',round_count=v_round,accepted_contract_id=v_contract,updated_at=now() where id=n.id;
    insert into public.staff_financial_events(player_id,contract_id,event_type,amount,status,game_absolute_day,posted_at)
    values(v_player.id,v_contract,'signing_fee',s.signing_fee,v_fin_status,v_abs,case when v_fin_status='posted' then now() else null end);
    return jsonb_build_object('status','accepted','accepted',true,'contract_id',v_contract,'staff_id',s.id,'round_number',v_round,'acceptance_chance',v_chance,'roll',v_roll,'weekly_salary',v_offer,'salary_multiplier',v_mult,'signing_fee',s.signing_fee,'duration_weeks',p_duration_weeks,'finance_status',v_fin_status);
  end if;

  update public.staff_negotiations set round_count=v_round,status=case when v_round>=3 then 'failed' else 'active' end,cooldown_until_absolute_day=case when v_round>=3 then v_abs+14 else null end,updated_at=now() where id=n.id;
  return jsonb_build_object('status','rejected','accepted',false,'staff_id',s.id,'round_number',v_round,'acceptance_chance',v_chance,'roll',v_roll,'salary_multiplier',v_mult,'offered_weekly_salary',v_offer,'remaining_rounds',greatest(0,3-v_round),'minimum_next_multiplier',case when v_round<3 then least(2.00,v_mult+0.10) else null end,'cooldown_until_absolute_day',case when v_round>=3 then v_abs+14 else null end);
end;
$$;

create or replace function public.hire_staff_v1(p_staff_id uuid,p_duration_weeks smallint)
returns jsonb language plpgsql security definer set search_path='public' as $$
begin
  raise exception 'Direct staff hiring is disabled. Make a negotiated staff offer instead.';
end;
$$;

grant execute on function public.quote_staff_negotiation_v1(uuid,smallint,numeric) to authenticated;
grant execute on function public.negotiate_staff_offer_v1(uuid,smallint,numeric) to authenticated;
